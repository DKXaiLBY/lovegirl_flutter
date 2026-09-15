SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('achievements', 'user_achievements', 'travel_trips', 'trip_spots')
ORDER BY TABLE_NAME;

SELECT TABLE_NAME, COLUMN_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND (
    (TABLE_NAME = 'feeding_orders' AND COLUMN_NAME IN ('platform_order_id', 'platform_order_no', 'actual_amount'))
    OR (TABLE_NAME IN ('feeding_shops', 'feeding_products', 'bean_transactions', 'travel_photos') AND COLUMN_NAME = 'updated_at')
  )
ORDER BY TABLE_NAME, COLUMN_NAME;

SELECT DEFAULT_CHARACTER_SET_NAME, DEFAULT_COLLATION_NAME
FROM information_schema.SCHEMATA
WHERE SCHEMA_NAME = DATABASE();

SELECT COUNT(*) AS achievement_count FROM achievements;
