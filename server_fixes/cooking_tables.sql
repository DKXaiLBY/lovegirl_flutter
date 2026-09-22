CREATE TABLE IF NOT EXISTS cooking_logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  chef_id INT NOT NULL,
  title VARCHAR(100) NOT NULL,
  emoji VARCHAR(16) NOT NULL DEFAULT '🍳',
  photo_url VARCHAR(500) NULL,
  recipe TEXT NULL,
  story VARCHAR(1000) NULL,
  is_new TINYINT(1) NOT NULL DEFAULT 1,
  chef_rating TINYINT NULL,
  eater_id INT NULL,
  eater_rating TINYINT NULL,
  eater_comment VARCHAR(300) NULL,
  cooked_at DATE NOT NULL,
  dish_id INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_chef_date (chef_id, cooked_at)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
