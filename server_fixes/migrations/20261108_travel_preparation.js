async function migrateTravelPreparation(pool) {
  const [columns] = await pool.query(
    "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'couples' AND COLUMN_NAME = 'preparation_epoch'"
  );
  if (!columns.length) {
    await pool.query('ALTER TABLE couples ADD COLUMN preparation_epoch INT NOT NULL DEFAULT 1');
  }
  await pool.query(`CREATE TABLE IF NOT EXISTS travel_preparation (
    trip_id INT NOT NULL,
    scope ENUM('private','shared') NOT NULL,
    scope_id INT NOT NULL,
    epoch INT NOT NULL DEFAULT 0,
    revision INT NOT NULL,
    trip_title VARCHAR(100) NOT NULL,
    trip_days INT NOT NULL,
    trip_start DATE NULL,
    document JSON NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (trip_id, scope, scope_id, epoch),
    KEY idx_preparation_scope (scope, scope_id, epoch, updated_at)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
}

module.exports = migrateTravelPreparation;

if (require.main === module) {
  const pool = require('../config/database');
  migrateTravelPreparation(pool).catch(() => {
    console.error('Travel preparation migration failed');
    process.exitCode = 1;
  }).finally(() => pool.end());
}
