-- Additive migration: original photos, places and trip headers remain untouched.
CREATE TABLE IF NOT EXISTS creative_works (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  client_id VARCHAR(80) NOT NULL,
  kind VARCHAR(16) NOT NULL,
  title VARCHAR(100) NOT NULL,
  trip_id INT NULL,
  source_urls JSON NOT NULL,
  preview_url VARCHAR(500) NOT NULL,
  document_json JSON NOT NULL,
  revision INT NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,
  UNIQUE KEY uk_works_client (user_id, client_id),
  KEY idx_works_owner (user_id, deleted_at, updated_at),
  KEY idx_works_trip (trip_id, deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS travel_itinerary_state (
  trip_id INT NOT NULL PRIMARY KEY,
  client_key VARCHAR(120) NULL UNIQUE,
  revision INT NOT NULL DEFAULT 1,
  plan_json JSON NOT NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
