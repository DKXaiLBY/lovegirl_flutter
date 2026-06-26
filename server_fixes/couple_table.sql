-- 伴侣绑定系统数据表
-- 在 MySQL 中执行: mysql -u lovegirl -p love_girl < couple_table.sql

CREATE TABLE IF NOT EXISTS couples (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user1_id INT NOT NULL,
  user2_id INT NOT NULL,
  status VARCHAR(20) DEFAULT 'active' COMMENT 'active/broken',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  broken_at DATETIME DEFAULT NULL,
  UNIQUE KEY uk_user1 (user1_id),
  UNIQUE KEY uk_user2 (user2_id),
  FOREIGN KEY (user1_id) REFERENCES users(id),
  FOREIGN KEY (user2_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS couple_invites (
  id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(6) NOT NULL UNIQUE,
  creator_id INT NOT NULL,
  expires_at DATETIME NOT NULL,
  used TINYINT(1) DEFAULT 0,
  used_by INT DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (creator_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
