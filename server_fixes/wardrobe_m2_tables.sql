-- 电子衣柜 M2a 建表/迁移（幂等）— docs/implementation/wardrobe-m2-plan.md v1.1 S1
-- 执行方式：UTF-8 文件 docker cp 进 lovegirl-mysql 后容器内执行
ALTER TABLE wardrobe_outfits
  MODIFY source ENUM('实拍','组合','换装') NOT NULL;

ALTER TABLE wardrobe_items
  ADD COLUMN bg_removed TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN cutout_url VARCHAR(500) DEFAULT NULL,
  ADD COLUMN item_layout JSON DEFAULT NULL;

CREATE TABLE IF NOT EXISTS wardrobe_avatars (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  image_url VARCHAR(500) NOT NULL,
  thumbnail_url VARCHAR(500) DEFAULT NULL,
  cutout_url VARCHAR(500) DEFAULT NULL,
  is_default TINYINT(1) NOT NULL DEFAULT 0,
  deleted_at DATETIME DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_deleted (user_id, deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
