async function visibleIds(pool, userId) {
  const [rows] = await pool.query(
    "SELECT CASE WHEN user1_id = ? THEN user2_id ELSE user1_id END AS partner_id FROM couples WHERE (user1_id = ? OR user2_id = ?) AND status = 'active' LIMIT 1",
    [userId, userId, userId]
  );
  return [Number(userId), ...rows.map(row => Number(row.partner_id))];
}
function slots(ids) {
  if (!ids.length || ids.length > 8) throw new Error('Invalid sharing scope');
  return [...ids, ...Array(8 - ids.length).fill(null)];
}
function errorResponse(res, error) {
  const status = error.status || 500;
  if (status === 500) console.error('[Creation]', error.message);
  res.status(status).json({ code: status, message: error.status ? error.message : '暂时保存失败，请重试' });
}
module.exports = { visibleIds, slots, errorResponse };
