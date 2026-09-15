-- LoveGirl rebuild migration
-- Run inside the LoveGirl MySQL database before deploying the new routes.

DELIMITER $$

DROP PROCEDURE IF EXISTS add_column_if_missing $$
CREATE PROCEDURE add_column_if_missing(
  IN table_name_in VARCHAR(64),
  IN column_name_in VARCHAR(64),
  IN column_definition_in TEXT
)
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = table_name_in
      AND COLUMN_NAME = column_name_in
  ) THEN
    SET @ddl = CONCAT('ALTER TABLE `', table_name_in, '` ADD COLUMN `', column_name_in, '` ', column_definition_in);
    PREPARE stmt FROM @ddl;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END IF;
END $$

DROP PROCEDURE IF EXISTS convert_table_charset_if_exists $$
CREATE PROCEDURE convert_table_charset_if_exists(
  IN table_name_in VARCHAR(64)
)
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = table_name_in
  ) THEN
    SET @ddl = CONCAT('ALTER TABLE `', table_name_in, '` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
    PREPARE stmt FROM @ddl;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END IF;
END $$

DELIMITER ;

ALTER DATABASE CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS feeding_shops (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  icon VARCHAR(10) DEFAULT 'shop',
  description VARCHAR(200) DEFAULT '',
  category VARCHAR(20) DEFAULT 'food',
  banner_color VARCHAR(20) DEFAULT '#E9856B',
  sort_order INT DEFAULT 0,
  is_active TINYINT(1) DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS feeding_products (
  id INT AUTO_INCREMENT PRIMARY KEY,
  shop_id INT NOT NULL,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  price INT NOT NULL DEFAULT 10,
  image VARCHAR(255),
  is_custom TINYINT(1) DEFAULT 0,
  created_by INT DEFAULT NULL,
  is_active TINYINT(1) DEFAULT 1,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_feeding_products_shop (shop_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS feeding_orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  sender_id INT NOT NULL,
  receiver_id INT DEFAULT NULL,
  shop_id INT DEFAULT NULL,
  product_id INT NOT NULL,
  product_name VARCHAR(100) NOT NULL,
  product_price INT NOT NULL DEFAULT 0,
  quantity INT NOT NULL DEFAULT 1,
  total_price INT NOT NULL DEFAULT 0,
  message TEXT,
  status VARCHAR(20) DEFAULT 'pending',
  urge_count INT DEFAULT 0,
  last_urge_at DATETIME DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_feeding_orders_user (sender_id, receiver_id),
  INDEX idx_feeding_orders_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CALL add_column_if_missing('feeding_products', 'shop_id', 'INT DEFAULT NULL');
CALL add_column_if_missing('feeding_products', 'description', 'TEXT DEFAULT NULL');
CALL add_column_if_missing('feeding_products', 'image', 'VARCHAR(255) DEFAULT NULL');
CALL add_column_if_missing('feeding_products', 'sort_order', 'INT DEFAULT 0');
CALL add_column_if_missing('feeding_products', 'category', "VARCHAR(30) DEFAULT 'custom'");
CALL add_column_if_missing('feeding_products', 'updated_at', 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');
CALL add_column_if_missing('feeding_shops', 'updated_at', 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');

CALL add_column_if_missing('feeding_orders', 'sender_id', 'INT DEFAULT NULL');
CALL add_column_if_missing('feeding_orders', 'receiver_id', 'INT DEFAULT NULL');
CALL add_column_if_missing('feeding_orders', 'shop_id', 'INT DEFAULT NULL');
CALL add_column_if_missing('feeding_orders', 'product_price', 'INT NOT NULL DEFAULT 0');
CALL add_column_if_missing('feeding_orders', 'message', 'TEXT DEFAULT NULL');
CALL add_column_if_missing('feeding_orders', 'urge_count', 'INT NOT NULL DEFAULT 0');
CALL add_column_if_missing('feeding_orders', 'last_urge_at', 'DATETIME DEFAULT NULL');
CALL add_column_if_missing('feeding_orders', 'platform', 'VARCHAR(30) DEFAULT NULL');
CALL add_column_if_missing('feeding_orders', 'actual_amount', 'DECIMAL(10,2) DEFAULT NULL');
CALL add_column_if_missing('feeding_orders', 'platform_order_no', 'VARCHAR(100) DEFAULT NULL');
CALL add_column_if_missing('feeding_orders', 'platform_order_id', 'VARCHAR(100) DEFAULT NULL');
CALL add_column_if_missing('feeding_orders', 'delivery_status', 'VARCHAR(50) DEFAULT NULL');
CALL add_column_if_missing('feeding_orders', 'delivery_eta', 'VARCHAR(50) DEFAULT NULL');
CALL add_column_if_missing('feeding_orders', 'delivery_note', 'TEXT DEFAULT NULL');
CALL add_column_if_missing('feeding_orders', 'cancel_reason', 'VARCHAR(255) DEFAULT NULL');

UPDATE feeding_orders
SET sender_id = COALESCE(sender_id, boy_user_id),
    receiver_id = COALESCE(receiver_id, girl_user_id),
    product_price = CASE
      WHEN COALESCE(product_price, 0) = 0 AND COALESCE(quantity, 0) > 0 THEN ROUND(total_price / quantity)
      ELSE product_price
    END,
    message = COALESCE(message, note)
WHERE sender_id IS NULL OR receiver_id IS NULL OR product_price = 0 OR message IS NULL;

UPDATE feeding_orders
SET platform_order_id = COALESCE(platform_order_id, platform_order_no),
    platform_order_no = COALESCE(platform_order_no, platform_order_id)
WHERE platform_order_id IS NULL OR platform_order_no IS NULL;

ALTER TABLE feeding_orders MODIFY COLUMN status VARCHAR(20) DEFAULT 'pending';

CALL add_column_if_missing('feeding_products', 'is_custom', 'TINYINT(1) DEFAULT 0');
CALL add_column_if_missing('feeding_products', 'created_by', 'INT DEFAULT NULL');

CALL add_column_if_missing('users', 'bean_balance', 'INT NOT NULL DEFAULT 0');

CREATE TABLE IF NOT EXISTS bean_transactions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  amount INT NOT NULL,
  balance_after INT NOT NULL,
  type VARCHAR(30) NOT NULL,
  title VARCHAR(100) NOT NULL,
  source_module VARCHAR(30) DEFAULT NULL,
  source_id INT DEFAULT NULL,
  reference_id INT DEFAULT NULL,
  description VARCHAR(255) DEFAULT '',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_bean_transactions_user (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CALL add_column_if_missing('bean_transactions', 'reference_id', 'INT DEFAULT NULL');
CALL add_column_if_missing('bean_transactions', 'description', "VARCHAR(255) DEFAULT ''");
CALL add_column_if_missing('bean_transactions', 'updated_at', 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');

CREATE TABLE IF NOT EXISTS notifications (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  type VARCHAR(40) NOT NULL,
  title VARCHAR(100) NOT NULL,
  content VARCHAR(255) NOT NULL,
  payload JSON DEFAULT NULL,
  read_at DATETIME DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_notifications_user (user_id, read_at, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CALL add_column_if_missing('notifications', 'updated_at', 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');

CREATE TABLE IF NOT EXISTS travel_spots (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  name VARCHAR(100) NOT NULL,
  city VARCHAR(50) DEFAULT '',
  address VARCHAR(255) DEFAULT '',
  lng DECIMAL(12,8) DEFAULT 0,
  lat DECIMAL(12,8) DEFAULT 0,
  emoji VARCHAR(10) DEFAULT 'pin',
  status VARCHAR(20) DEFAULT 'wish',
  note TEXT,
  diary TEXT,
  visited_date DATE DEFAULT NULL,
  rating INT DEFAULT NULL,
  mood VARCHAR(50) DEFAULT NULL,
  tags JSON DEFAULT NULL,
  reason TEXT DEFAULT NULL,
  desire INT DEFAULT NULL,
  planned_date DATE DEFAULT NULL,
  itinerary TEXT DEFAULT NULL,
  budget DECIMAL(10,2) DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_travel_spots_user (user_id, status),
  INDEX idx_travel_spots_city (city)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS travel_photos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  spot_id INT NOT NULL,
  user_id INT NOT NULL,
  url VARCHAR(255) NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_travel_photos_spot (spot_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CALL add_column_if_missing('travel_photos', 'updated_at', 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');

CREATE TABLE IF NOT EXISTS travel_routes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  title VARCHAR(100) NOT NULL,
  city VARCHAR(50) DEFAULT NULL,
  description TEXT,
  status VARCHAR(20) DEFAULT 'draft',
  mode VARCHAR(20) DEFAULT 'driving',
  distance INT DEFAULT NULL,
  duration INT DEFAULT NULL,
  path_json JSON DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_travel_routes_user (user_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS travel_route_spots (
  id INT AUTO_INCREMENT PRIMARY KEY,
  route_id INT NOT NULL,
  spot_id INT NOT NULL,
  sort_order INT DEFAULT 0,
  note TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_travel_route_spots_route (route_id, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CALL add_column_if_missing('travel_route_spots', 'created_at', 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP');
CALL add_column_if_missing('travel_route_spots', 'updated_at', 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');

CREATE TABLE IF NOT EXISTS travel_trips (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  created_by INT DEFAULT NULL,
  title VARCHAR(100) NOT NULL,
  city VARCHAR(50) DEFAULT NULL,
  description TEXT,
  status VARCHAR(20) DEFAULT 'draft',
  mode VARCHAR(20) DEFAULT 'driving',
  distance INT DEFAULT NULL,
  duration INT DEFAULT NULL,
  path_json JSON DEFAULT NULL,
  start_date DATE DEFAULT NULL,
  end_date DATE DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_travel_trips_user (user_id, status),
  INDEX idx_travel_trips_created_by (created_by)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS trip_spots (
  id INT AUTO_INCREMENT PRIMARY KEY,
  trip_id INT NOT NULL,
  spot_id INT NOT NULL,
  sort_order INT DEFAULT 0,
  note TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_trip_spot (trip_id, spot_id),
  INDEX idx_trip_spots_trip (trip_id, sort_order),
  INDEX idx_trip_spots_spot (spot_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS travel_expenses (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  spot_id INT DEFAULT NULL,
  route_id INT DEFAULT NULL,
  finance_record_id INT DEFAULT NULL,
  category VARCHAR(30) NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  description TEXT,
  record_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_travel_expenses_user (user_id, record_date),
  INDEX idx_travel_expenses_route (route_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS travel_tickets (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  spot_id INT DEFAULT NULL,
  route_id INT DEFAULT NULL,
  title VARCHAR(100) NOT NULL,
  subtitle VARCHAR(150) DEFAULT '',
  ticket_date DATE DEFAULT NULL,
  image_url VARCHAR(255) DEFAULT NULL,
  payload JSON DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_travel_tickets_user (user_id, ticket_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS travel_achievements (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  code VARCHAR(80) NOT NULL,
  title VARCHAR(100) NOT NULL,
  description VARCHAR(255) DEFAULT '',
  unlocked_at DATETIME NOT NULL,
  payload JSON DEFAULT NULL,
  UNIQUE KEY uk_travel_achievement_user_code (user_id, code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS achievements (
  id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(80) NOT NULL,
  category VARCHAR(30) NOT NULL,
  title VARCHAR(100) NOT NULL,
  description VARCHAR(255) DEFAULT '',
  target_value INT NOT NULL DEFAULT 1,
  reward_beans INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_achievements_code (code),
  INDEX idx_achievements_category (category, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS user_achievements (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  achievement_id INT NOT NULL,
  progress INT NOT NULL DEFAULT 0,
  unlocked_at DATETIME DEFAULT NULL,
  reward_claimed_at DATETIME DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_user_achievement (user_id, achievement_id),
  INDEX idx_user_achievements_user (user_id, unlocked_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO achievements (code, category, title, description, target_value, reward_beans, is_active)
VALUES
  ('travel_checkin_1', 'travel', 'First travel check-in', 'Complete 1 travel check-in', 1, 5, 1),
  ('travel_checkin_5', 'travel', 'Five travel check-ins', 'Complete 5 travel check-ins', 5, 10, 1),
  ('travel_checkin_10', 'travel', 'Ten travel check-ins', 'Complete 10 travel check-ins', 10, 20, 1),
  ('travel_checkin_20', 'travel', 'Twenty travel check-ins', 'Complete 20 travel check-ins', 20, 40, 1),
  ('travel_city_3', 'travel', 'Three travel cities', 'Visit spots in 3 cities', 3, 10, 1),
  ('travel_city_5', 'travel', 'Five travel cities', 'Visit spots in 5 cities', 5, 20, 1),
  ('feeding_complete_1', 'feeding', 'First feeding received', 'Complete 1 feeding order', 1, 5, 1),
  ('feeding_complete_10', 'feeding', 'Ten feedings received', 'Complete 10 feeding orders', 10, 20, 1),
  ('feeding_complete_50', 'feeding', 'Fifty feedings received', 'Complete 50 feeding orders', 50, 50, 1),
  ('checkin_7', 'checkin', 'Seven-day check-in streak', 'Check in for 7 consecutive days', 7, 15, 1),
  ('checkin_30', 'checkin', 'Thirty-day check-in streak', 'Check in for 30 consecutive days', 30, 60, 1),
  ('mood_record_30', 'mood', 'Thirty mood records', 'Record mood for 30 days', 30, 20, 1)
ON DUPLICATE KEY UPDATE
  category = VALUES(category),
  title = VALUES(title),
  description = VALUES(description),
  target_value = VALUES(target_value),
  reward_beans = VALUES(reward_beans),
  is_active = VALUES(is_active),
  updated_at = NOW();

CALL add_column_if_missing('travel_spots', 'weather', 'VARCHAR(100) DEFAULT NULL');
CALL add_column_if_missing('travel_spots', 'traffic', 'VARCHAR(200) DEFAULT NULL');
CALL add_column_if_missing('travel_spots', 'opening_hours', 'VARCHAR(200) DEFAULT NULL');
CALL add_column_if_missing('travel_spots', 'reason', 'TEXT DEFAULT NULL');
CALL add_column_if_missing('travel_spots', 'planned_date', 'DATE DEFAULT NULL');
CALL add_column_if_missing('travel_spots', 'budget', 'DECIMAL(10,2) DEFAULT NULL');
CALL add_column_if_missing('travel_spots', 'created_by', 'INT DEFAULT NULL');
CALL add_column_if_missing('travel_spots', 'owner_note', 'TEXT DEFAULT NULL');
CALL add_column_if_missing('travel_spots', 'partner_note', 'TEXT DEFAULT NULL');
CALL add_column_if_missing('travel_spots', 'transportation', 'TEXT DEFAULT NULL');
CALL add_column_if_missing('travel_spots', 'nearby', 'TEXT DEFAULT NULL');
CALL add_column_if_missing('travel_spots', 'tips', 'TEXT DEFAULT NULL');
CALL add_column_if_missing('travel_spots', 'checked_in_at', 'DATETIME DEFAULT NULL');
UPDATE travel_spots SET created_by = COALESCE(created_by, user_id) WHERE created_by IS NULL;

CALL add_column_if_missing('travel_routes', 'mode', "VARCHAR(20) DEFAULT 'driving'");
CALL add_column_if_missing('travel_routes', 'distance', 'INT DEFAULT NULL');
CALL add_column_if_missing('travel_routes', 'duration', 'INT DEFAULT NULL');
CALL add_column_if_missing('travel_routes', 'path_json', 'JSON DEFAULT NULL');

CALL add_column_if_missing('finance_records', 'source_module', 'VARCHAR(30) DEFAULT NULL');
CALL add_column_if_missing('finance_records', 'source_id', 'INT DEFAULT NULL');

ALTER TABLE push_messages
  MODIFY COLUMN type ENUM(
    'quote', 'weather', 'period', 'reminder', 'custom', 'todo', 'exam', 'course',
    'feeding_order', 'feeding_urge', 'feeding_status', 'feeding_delivery'
  ) NOT NULL;

CALL add_column_if_missing('love_timeline', 'source_module', 'VARCHAR(30) DEFAULT NULL');
CALL add_column_if_missing('love_timeline', 'source_id', 'INT DEFAULT NULL');

CALL convert_table_charset_if_exists('users');
CALL convert_table_charset_if_exists('feeding_shops');
CALL convert_table_charset_if_exists('feeding_products');
CALL convert_table_charset_if_exists('feeding_orders');
CALL convert_table_charset_if_exists('bean_transactions');
CALL convert_table_charset_if_exists('notifications');
CALL convert_table_charset_if_exists('travel_spots');
CALL convert_table_charset_if_exists('travel_photos');
CALL convert_table_charset_if_exists('travel_routes');
CALL convert_table_charset_if_exists('travel_route_spots');
CALL convert_table_charset_if_exists('travel_trips');
CALL convert_table_charset_if_exists('trip_spots');
CALL convert_table_charset_if_exists('achievements');
CALL convert_table_charset_if_exists('user_achievements');
CALL convert_table_charset_if_exists('mood_diary');
CALL convert_table_charset_if_exists('love_timeline');
CALL convert_table_charset_if_exists('finance_records');

DROP PROCEDURE IF EXISTS add_column_if_missing;
DROP PROCEDURE IF EXISTS convert_table_charset_if_exists;
