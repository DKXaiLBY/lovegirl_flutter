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

CALL add_column_if_missing('travel_routes', 'mode', "VARCHAR(20) DEFAULT 'driving'");
CALL add_column_if_missing('travel_routes', 'distance', 'INT DEFAULT NULL');
CALL add_column_if_missing('travel_routes', 'duration', 'INT DEFAULT NULL');
CALL add_column_if_missing('travel_routes', 'path_json', 'JSON DEFAULT NULL');

DROP PROCEDURE IF EXISTS add_column_if_missing;
