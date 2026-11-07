// Additive and resumable. Call with the intended database pool after backup.
async function migrateKitchenWorkflow(pool) {
  const applied = [];
  async function column(table, name, sql) {
    const [rows] = await pool.query(
      'SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
      [table, name]
    );
    if (!rows.length) { await pool.query(sql); applied.push(table + '.' + name); }
  }
  async function index(table, name, sql) {
    const [rows] = await pool.query(
      'SELECT INDEX_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?',
      [table, name]
    );
    if (!rows.length) { await pool.query(sql); applied.push(table + '.' + name); }
  }
  await column('kitchen_dishes', 'ingredients', 'ALTER TABLE kitchen_dishes ADD COLUMN ingredients TEXT NULL');
  await column('kitchen_dishes', 'recipe', 'ALTER TABLE kitchen_dishes ADD COLUMN recipe TEXT NULL');
  await column('kitchen_orders', 'partner_id', 'ALTER TABLE kitchen_orders ADD COLUMN partner_id INT NULL');
  await column('kitchen_orders', 'meal_date', 'ALTER TABLE kitchen_orders ADD COLUMN meal_date DATE NULL');
  await column('kitchen_orders', 'meal_slot', 'ALTER TABLE kitchen_orders ADD COLUMN meal_slot VARCHAR(16) NULL');
  await column('kitchen_orders', 'revision', 'ALTER TABLE kitchen_orders ADD COLUMN revision INT NOT NULL DEFAULT 1');
  await column('kitchen_orders', 'request_key', 'ALTER TABLE kitchen_orders ADD COLUMN request_key VARCHAR(64) NULL');
  await column('kitchen_orders', 'request_hash', 'ALTER TABLE kitchen_orders ADD COLUMN request_hash CHAR(64) NULL');
  await column('cooking_logs', 'kitchen_order_id', 'ALTER TABLE cooking_logs ADD COLUMN kitchen_order_id INT NULL');
  await index('kitchen_orders', 'uq_ko_request', 'ALTER TABLE kitchen_orders ADD UNIQUE KEY uq_ko_request (orderer_id, request_key)');
  await index('kitchen_orders', 'idx_ko_partner', 'ALTER TABLE kitchen_orders ADD KEY idx_ko_partner (partner_id)');
  await index('cooking_logs', 'uq_cl_kitchen_order', 'ALTER TABLE cooking_logs ADD UNIQUE KEY uq_cl_kitchen_order (kitchen_order_id)');
  return applied;
}

module.exports = migrateKitchenWorkflow;

if (require.main === module) {
  const pool = require('../config/database');
  migrateKitchenWorkflow(pool).then(applied => {
    console.log(JSON.stringify({ applied }));
  }).catch(() => {
    console.error('Kitchen migration failed; inspect the database before resuming');
    process.exitCode = 1;
  }).finally(() => pool.end());
}
