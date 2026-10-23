-- 核对线上 photos.id / travel_photos.id 均为 INT 后执行一次。
-- 不复制媒体；删除相册原记录后自动清除引用。
ALTER TABLE travel_photos
  ADD COLUMN source_photo_id INT NULL,
  ADD UNIQUE KEY uq_travel_photo_source (spot_id, source_photo_id),
  ADD CONSTRAINT fk_travel_photo_source
    FOREIGN KEY (source_photo_id) REFERENCES photos(id) ON DELETE CASCADE;
