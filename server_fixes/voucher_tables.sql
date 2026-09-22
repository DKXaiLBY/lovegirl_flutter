CREATE TABLE IF NOT EXISTS voucher_templates (
  id INT AUTO_INCREMENT PRIMARY KEY,
  creator_id INT NOT NULL,
  title VARCHAR(60) NOT NULL,
  cost_bean INT NOT NULL,
  emoji VARCHAR(16) NOT NULL DEFAULT '🎁',
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_creator (creator_id, is_active)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS voucher_redemptions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  template_id INT NOT NULL,
  redeemer_id INT NOT NULL,
  creator_id INT NOT NULL,
  cost_bean INT NOT NULL,
  status ENUM('pending','done','confirmed','cancelled') NOT NULL DEFAULT 'pending',
  proof_url VARCHAR(500) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  done_at DATETIME NULL,
  KEY idx_redeemer (redeemer_id, status),
  KEY idx_creator (creator_id, status)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
