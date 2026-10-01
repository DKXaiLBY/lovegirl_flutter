-- W3 旅行清单置顶（2026-09-30 live 手工执行，此处补记录）
ALTER TABLE travel_spots ADD COLUMN pinned TINYINT(1) NOT NULL DEFAULT 0;
