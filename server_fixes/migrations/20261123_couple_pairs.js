async function migrateCouplePairs(pool) {
  const [rows] = await pool.query(
    "SELECT DISTINCT INDEX_NAME AS name FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'couples'"
  );
  const names = new Set(rows.map((row) => row.name));
  if (!names.has('uk_couple_pair')) {
    await pool.query('ALTER TABLE couples ADD UNIQUE KEY uk_couple_pair (user1_id, user2_id)');
  }
  if (!names.has('idx_couple_user2')) {
    await pool.query('ALTER TABLE couples ADD KEY idx_couple_user2 (user2_id)');
  }
  if (names.has('uk_user1')) await pool.query('ALTER TABLE couples DROP KEY uk_user1');
  if (names.has('uk_user2')) await pool.query('ALTER TABLE couples DROP KEY uk_user2');
}

module.exports = migrateCouplePairs;

if (require.main === module) {
  const pool = require('../config/database');
  migrateCouplePairs(pool).catch((error) => {
    console.error('Couple pairs migration failed:', error.code);
    process.exitCode = 1;
  }).finally(() => pool.end());
}
