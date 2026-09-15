-- Add note (fulfillment remark) field to feeding_orders table
-- Non-destructive: uses stored procedure to check column existence

SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
  WHERE TABLE_SCHEMA='love_girl' AND TABLE_NAME='feeding_orders' AND COLUMN_NAME='note');

SET @sql = IF(@col_exists = 0,
  'ALTER TABLE feeding_orders ADD COLUMN note TEXT DEFAULT NULL COMMENT ''履约备注'' AFTER message',
  'SELECT ''note column already exists'' AS msg');

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
