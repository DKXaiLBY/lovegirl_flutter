CREATE TABLE IF NOT EXISTS love_tree (
  couple_key VARCHAR(40) PRIMARY KEY,
  growth_points INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS love_tree_water_log (
  id INT AUTO_INCREMENT PRIMARY KEY,
  couple_key VARCHAR(40) NOT NULL,
  user_id INT NOT NULL,
  points INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_couple_date (couple_key, created_at)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
