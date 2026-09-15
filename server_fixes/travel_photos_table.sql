-- 旅行地点照片表
CREATE TABLE IF NOT EXISTS travel_photos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  spot_id INT NOT NULL,
  user_id INT NOT NULL,
  url VARCHAR(500) NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (spot_id) REFERENCES travel_spots(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id),
  INDEX idx_spot_id (spot_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 更新 travel_spots 表添加新字段（如果不存在）
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

DELIMITER ;

CALL add_column_if_missing('travel_spots', 'weather', 'VARCHAR(20) DEFAULT NULL COMMENT ''天气'' AFTER mood');
CALL add_column_if_missing('travel_spots', 'reason', 'TEXT DEFAULT NULL COMMENT ''想去的理由'' AFTER tags');
CALL add_column_if_missing('travel_spots', 'planned_date', 'DATE DEFAULT NULL COMMENT ''计划日期'' AFTER reason');
CALL add_column_if_missing('travel_spots', 'itinerary', 'TEXT DEFAULT NULL COMMENT ''行程安排'' AFTER planned_date');
CALL add_column_if_missing('travel_spots', 'budget', 'DECIMAL(10, 2) DEFAULT NULL COMMENT ''预算'' AFTER itinerary');

DROP PROCEDURE IF EXISTS add_column_if_missing;
