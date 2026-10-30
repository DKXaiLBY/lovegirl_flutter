const pool = require('../../config/database');
const { encrypt, decrypt } = require('../../config/encrypt');

function todayString() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

async function getPartnerId(userId) {
  try {
    const [rows] = await pool.query(
      `SELECT CASE WHEN user1_id = ? THEN user2_id ELSE user1_id END AS partner_id
       FROM couples
       WHERE (user1_id = ? OR user2_id = ?) AND status = 'active'
       LIMIT 1`,
      [userId, userId, userId]
    );
    return rows[0]?.partner_id || null;
  } catch (_) {
    return null;
  }
}

// Retired reward API: keep imports compatible, without reading or changing balances.
async function addBeanTransaction() {
  return null;
}

async function awardBeans() {
  return null;
}

async function createFinanceRecord({
  userId,
  type = 'expense',
  category,
  amount,
  description = '',
  sourceModule,
  sourceId,
  recordDate = todayString(),
}) {
  if (!userId || !category || amount === undefined || amount === null) return null;
  try {
    if (sourceModule && sourceId) {
      const [existing] = await pool.query(
        'SELECT id FROM finance_records WHERE user_id = ? AND source_module = ? AND source_id = ? LIMIT 1',
        [userId, sourceModule, sourceId]
      );
      if (existing.length > 0) return existing[0].id;
    }
    const [result] = await pool.query(
      `INSERT INTO finance_records
       (user_id, type, category, amount_encrypted, description_encrypted, record_date, source_module, source_id, version)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)`,
      [
        userId,
        type,
        category,
        encrypt(String(amount)),
        encrypt(description || ''),
        recordDate,
        sourceModule || null,
        sourceId || null,
      ]
    );
    return result.insertId;
  } catch (err) {
    console.error('[Linkage] finance sync failed:', err.message);
    return null;
  }
}

async function createTimelineEvent({
  userId,
  title,
  description = '',
  eventDate = todayString(),
  imageUrl = null,
  icon = 'heart',
  sourceModule,
  sourceId,
}) {
  if (!userId || !title || !eventDate) return null;
  try {
    if (sourceModule && sourceId) {
      const [existing] = await pool.query(
        'SELECT id FROM love_timeline WHERE user_id = ? AND source_module = ? AND source_id = ? LIMIT 1',
        [userId, sourceModule, sourceId]
      );
      if (existing.length > 0) return existing[0].id;
    }
    const [result] = await pool.query(
      `INSERT INTO love_timeline
       (user_id, title, description, event_date, image_url, icon, source_module, source_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [userId, title, description, eventDate, imageUrl, icon, sourceModule || null, sourceId || null]
    );
    return result.insertId;
  } catch (err) {
    console.error('[Linkage] timeline sync failed:', err.message);
    return null;
  }
}

// Historical achievement/check-in data is retained; active flows no longer use it.
async function unlockTravelAchievement() {}

const achievementSeeds = [];

async function ensureAchievementsSeeded() {}

async function getCheckinStreak() {
  return 0;
}

async function checkAchievements() {
  return [];
}

async function isUserInPeriod(userId) {
  if (!userId) return false;
  try {
    const [ongoing] = await pool.query(
      `SELECT id FROM period_records
       WHERE user_id = ? AND end_date_encrypted IS NULL
         AND pain_level_encrypted IS NULL AND symptoms_encrypted IS NULL
       LIMIT 1`,
      [userId]
    );
    return ongoing.length > 0;
  } catch (_) {
    return false;
  }
}

function safeDecrypt(value) {
  if (!value) return '';
  try {
    return decrypt(value);
  } catch (_) {
    return '';
  }
}

module.exports = {
  todayString,
  getPartnerId,
  addBeanTransaction,
  awardBeans,
  createFinanceRecord,
  createTimelineEvent,
  unlockTravelAchievement,
  achievementSeeds,
  ensureAchievementsSeeded,
  getCheckinStreak,
  checkAchievements,
  isUserInPeriod,
  safeDecrypt,
};
