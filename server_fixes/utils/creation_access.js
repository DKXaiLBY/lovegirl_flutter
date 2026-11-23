async function partnerId(pool, userId) {
  const [rows] = await pool.query(
    "SELECT CASE WHEN user1_id = ? THEN user2_id ELSE user1_id END AS partner_id FROM couples WHERE (user1_id = ? OR user2_id = ?) AND status = 'active' LIMIT 2",
    [userId, userId, userId]
  );
  if (rows.length !== 1) return null;
  const partner = Number(rows[0].partner_id);
  return Number.isSafeInteger(partner) && partner > 0 && partner !== Number(userId) ? partner : null;
}
async function visibleIds(pool, userId) {
  const partner = await partnerId(pool, userId);
  return partner === null ? [Number(userId)] : [Number(userId), partner];
}
const privacyDefaults = Object.freeze({
  photo_visible: false, mood_visible: false, travel_visible: true, chat_visible: true,
});
async function privacyFor(pool, userId) {
  const [rows] = await pool.query(
    'SELECT photo_visible,mood_visible,travel_visible,chat_visible FROM user_privacy WHERE user_id = ?',
    [userId]
  );
  return rows[0]
    ? Object.fromEntries(Object.keys(privacyDefaults).map((field) => [field, Boolean(rows[0][field])]))
    : privacyDefaults;
}
async function travelIds(pool, userId) {
  const ids = await visibleIds(pool, userId);
  if (ids.length === 2 && !(await privacyFor(pool, ids[1])).travel_visible) return ids.slice(0, 1);
  return ids;
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
module.exports = { visibleIds, partnerId, privacyFor, privacyDefaults, travelIds, slots, errorResponse };
