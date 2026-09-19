CREATE TABLE IF NOT EXISTS slow_letters (
  id INT AUTO_INCREMENT PRIMARY KEY,
  sender_id INT NOT NULL,
  receiver_id INT NOT NULL,
  title VARCHAR(100) NOT NULL,
  content TEXT NOT NULL,
  unlock_date DATE NOT NULL,
  read_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_receiver (receiver_id, unlock_date),
  KEY idx_sender (sender_id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
