ALTER TABLE love_tree_water_log ADD COLUMN water_day DATE NULL AFTER points;
UPDATE love_tree_water_log SET water_day = DATE(CONVERT_TZ(created_at, '+00:00', '+08:00')) WHERE water_day IS NULL;
ALTER TABLE love_tree_water_log ADD UNIQUE KEY uniq_water_day (couple_key, user_id, water_day);
