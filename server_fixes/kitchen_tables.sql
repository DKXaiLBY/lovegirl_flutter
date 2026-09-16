-- 情侣厨房表（v3.20 投喂站重构，2026-09-17）
-- 在 MySQL 中执行: docker exec -i lovegirl-mysql mysql -u root -p*** love_girl < kitchen_tables.sql

CREATE TABLE IF NOT EXISTS kitchen_dishes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL COMMENT '厨师（菜单主人）',
  name VARCHAR(100) NOT NULL,
  category VARCHAR(30) NOT NULL DEFAULT '家常菜',
  emoji VARCHAR(16) DEFAULT '🍳',
  photo_url VARCHAR(500) DEFAULT NULL,
  price INT DEFAULT 0 COMMENT '趣味心意价',
  description VARCHAR(300) DEFAULT NULL,
  is_active TINYINT(1) DEFAULT 1,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_kd_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS kitchen_orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  orderer_id INT NOT NULL COMMENT '下单的人',
  cook_id INT NOT NULL COMMENT '接单做饭的人',
  items JSON NOT NULL COMMENT '下单快照 [{dish_id,name,emoji,price,quantity}]',
  total_price INT DEFAULT 0,
  note VARCHAR(300) DEFAULT NULL,
  status VARCHAR(20) DEFAULT 'placed' COMMENT 'placed/accepted/done/cancelled',
  photo_url VARCHAR(500) DEFAULT NULL COMMENT '成品照',
  reply VARCHAR(200) DEFAULT NULL,
  beans_awarded TINYINT(1) DEFAULT 0,
  cancel_reason VARCHAR(255) DEFAULT NULL,
  accepted_at DATETIME DEFAULT NULL,
  done_at DATETIME DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_ko_cook (cook_id),
  KEY idx_ko_orderer (orderer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
