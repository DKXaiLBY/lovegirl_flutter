CREATE TABLE IF NOT EXISTS registration_invites (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  issuer_id INT NOT NULL,
  code_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  expires_at DATETIME NOT NULL,
  revoked_at DATETIME DEFAULT NULL,
  used_by INT DEFAULT NULL,
  used_at DATETIME DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY unique_registration_code (code_hash),
  KEY registration_issuer (issuer_id, used_at, revoked_at)
) ENGINE=InnoDB;
