-- travel_trip_spots 表（2026-09-17 补建）
-- 背景：线上 routes/travel.js 引用 travel_trip_spots（行程-地点关联），
-- 但建库迁移从未包含该表，导致 DELETE /api/travel/spots/:id、行程读写等接口 500。
-- 在 MySQL 中执行: docker exec -i lovegirl-mysql mysql -u root -p*** love_girl < travel_trip_spots_table.sql

CREATE TABLE IF NOT EXISTS travel_trip_spots (
  id INT AUTO_INCREMENT PRIMARY KEY,
  trip_id INT NOT NULL,
  spot_id INT NOT NULL,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_tts_trip (trip_id),
  KEY idx_tts_spot (spot_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
