CREATE TABLE IF NOT EXISTS daily_answers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  question_date DATE NOT NULL,
  user_id INT NOT NULL,
  answer_text VARCHAR(500) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_daily_answer (question_date, user_id),
  KEY idx_user (user_id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
