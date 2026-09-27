-- 电子衣柜 M1 建表（幂等）— docs/implementation/wardrobe-m1-plan.md S1
-- 执行方式：UTF-8 文件 docker cp 进 lovegirl-mysql 后容器内执行（勿在 Windows shell 直发中文）
CREATE TABLE IF NOT EXISTS wardrobe_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  image_url VARCHAR(500) NOT NULL,
  thumbnail_url VARCHAR(500) DEFAULT NULL,
  category VARCHAR(20) NOT NULL,
  temperature VARCHAR(10) DEFAULT NULL,
  occasions JSON DEFAULT NULL,
  styles JSON DEFAULT NULL,
  extra_images JSON DEFAULT NULL,
  color VARCHAR(20) DEFAULT NULL,
  brand VARCHAR(60) DEFAULT NULL,
  price DECIMAL(10,2) DEFAULT NULL,
  status ENUM('在柜','退役') NOT NULL DEFAULT '在柜',
  favorite TINYINT(1) NOT NULL DEFAULT 0,
  wear_count INT NOT NULL DEFAULT 0,
  deleted_at DATETIME DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_deleted (user_id, deleted_at),
  INDEX idx_user_status (user_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS wardrobe_outfits (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  worn_date DATE NOT NULL,
  source ENUM('实拍','组合') NOT NULL,
  photo_url VARCHAR(500) DEFAULT NULL,
  thumbnail_url VARCHAR(500) DEFAULT NULL,
  item_ids JSON DEFAULT NULL,
  status ENUM('待确认','已通过') NOT NULL DEFAULT '待确认',
  note VARCHAR(300) DEFAULT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_date (user_id, worn_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
