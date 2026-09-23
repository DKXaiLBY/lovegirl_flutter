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

async function addBeanTransaction(conn, {
  userId,
  amount,
  type,
  title,
  sourceModule = null,
  sourceId = null,
  description = '',
  oncePerDay = false,
}) {
  if (!userId || !amount || !type || !title) return null;

  if (sourceModule && sourceId) {
    const [existing] = await conn.query(
      `SELECT id FROM bean_transactions
       WHERE user_id = ? AND type = ? AND source_module = ? AND source_id = ?
       LIMIT 1`,
      [userId, type, sourceModule, sourceId]
    );
    if (existing.length > 0) return null;
  }

  if (oncePerDay) {
    const [existing] = await conn.query(
      `SELECT id FROM bean_transactions
       WHERE user_id = ? AND type = ? AND DATE(created_at) = CURDATE()
       LIMIT 1`,
      [userId, type]
    );
    if (existing.length > 0) return null;
  }

  if (amount < 0) {
    const deduct = Math.abs(amount);
    const [result] = await conn.query(
      'UPDATE users SET bean_balance = COALESCE(bean_balance, 0) - ? WHERE id = ? AND COALESCE(bean_balance, 0) >= ?',
      [deduct, userId, deduct]
    );
    if (result.affectedRows === 0) {
      const err = new Error('爱心豆余额不足');
      err.status = 400;
      throw err;
    }
  } else {
    await conn.query(
      'UPDATE users SET bean_balance = COALESCE(bean_balance, 0) + ? WHERE id = ?',
      [amount, userId]
    );
  }

  const [users] = await conn.query('SELECT bean_balance FROM users WHERE id = ?', [userId]);
  const balance = Number(users[0]?.bean_balance || 0);
  await conn.query(
    `INSERT INTO bean_transactions
     (user_id, amount, balance_after, type, title, source_module, source_id, reference_id, description)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [userId, amount, balance, type, title, sourceModule, sourceId, sourceId, description || title]
  );
  return { balance, amount };
}

async function awardBeans(opts) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const result = await addBeanTransaction(conn, opts);
    await conn.commit();
    return result;
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
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

async function unlockTravelAchievement(userId, code, title, description = '', payload = {}) {
  try {
    await pool.query(
      `INSERT IGNORE INTO travel_achievements
       (user_id, code, title, description, unlocked_at, payload)
       VALUES (?, ?, ?, ?, NOW(), ?)`,
      [userId, code, title, description, JSON.stringify(payload)]
    );
  } catch (err) {
    console.error('[Linkage] achievement unlock failed:', err.message);
  }
}

const achievementSeeds = [
  { code: 'travel_checkin_1', category: 'travel', title: '第一次旅行打卡', description: '完成 1 次旅行打卡', target: 1, reward: 5 },
  { code: 'travel_checkin_5', category: 'travel', title: '旅行探索者 I', description: '完成 5 次旅行打卡', target: 5, reward: 10 },
  { code: 'travel_checkin_10', category: 'travel', title: '旅行探索者 II', description: '完成 10 次旅行打卡', target: 10, reward: 20 },
  { code: 'travel_checkin_20', category: 'travel', title: '旅行探索者 III', description: '完成 20 次旅行打卡', target: 20, reward: 30 },
  { code: 'travel_city_3', category: 'travel', title: '三城记', description: '一起去过 3 座城市', target: 3, reward: 10 },
  { code: 'travel_city_5', category: 'travel', title: '五城之约', description: '一起去过 5 座城市', target: 5, reward: 20 },
  { code: 'feeding_complete_1', category: 'feeding', title: '第一次投喂', description: '完成 1 单投喂', target: 1, reward: 5 },
  { code: 'feeding_complete_10', category: 'feeding', title: '可靠投喂官 I', description: '完成 10 单投喂', target: 10, reward: 20 },
  { code: 'feeding_complete_50', category: 'feeding', title: '可靠投喂官 II', description: '完成 50 单投喂', target: 50, reward: 50 },
  { code: 'checkin_7', category: 'checkin', title: '七日之约', description: '连续签到 7 天', target: 7, reward: 15 },
  { code: 'checkin_30', category: 'checkin', title: '月满之约', description: '连续签到 30 天', target: 30, reward: 50 },
  { code: 'mood_record_30', category: 'mood', title: '心情守护者', description: '累计记录 30 篇心情', target: 30, reward: 20 },
  { code: 'cooking_1', category: 'cooking', title: '第一次下厨', description: '记录第 1 道拿手菜', target: 1, reward: 5 },
  { code: 'cooking_10', category: 'cooking', title: '家常菜大师 I', description: '累计记录 10 次下厨', target: 10, reward: 20 },
  { code: 'cooking_30', category: 'cooking', title: '家常菜大师 II', description: '累计记录 30 次下厨', target: 30, reward: 50 },
  { code: 'cooking_new_10', category: 'cooking', title: '尝新十道', description: '尝试了 10 道从没做过的新菜', target: 10, reward: 30 },
];

async function ensureAchievementsSeeded(conn = pool) {
  for (const item of achievementSeeds) {
    await conn.query(
      `INSERT INTO achievements
       (code, category, title, description, target_value, reward_beans, is_active)
       VALUES (?, ?, ?, ?, ?, ?, 1)
       ON DUPLICATE KEY UPDATE
         category = VALUES(category),
         title = VALUES(title),
         description = VALUES(description),
         target_value = VALUES(target_value),
         reward_beans = VALUES(reward_beans),
         is_active = 1`,
      [item.code, item.category, item.title, item.description, item.target, item.reward]
    );
  }
}

async function getCheckinStreak(userId) {
  const [rows] = await pool.query(
    `SELECT DISTINCT DATE(created_at) AS check_date
     FROM bean_transactions
     WHERE user_id = ? AND type = 'daily_check_in'
     ORDER BY check_date DESC
     LIMIT 60`,
    [userId]
  );
  const dates = new Set(rows.map((row) => todayStringFromDate(row.check_date)));
  let streak = 0;
  const cursor = new Date(`${todayString()}T00:00:00+08:00`);
  while (dates.has(todayStringFromDate(cursor))) {
    streak += 1;
    cursor.setDate(cursor.getDate() - 1);
  }
  return streak;
}

function todayStringFromDate(value) {
  if (!value) return '';
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(value instanceof Date ? value : new Date(value));
}

async function collectAchievementProgress(userId) {
  const [[travelCount], [cityCount], [feedingCount], [moodCount], [cookingCount], [cookingNewCount]] = await Promise.all([
    pool.query(
      "SELECT COUNT(*) AS value FROM travel_spots WHERE COALESCE(created_by, user_id) = ? AND status = 'visited'",
      [userId]
    ),
    pool.query(
      "SELECT COUNT(DISTINCT NULLIF(city, '')) AS value FROM travel_spots WHERE COALESCE(created_by, user_id) = ? AND status = 'visited'",
      [userId]
    ),
    pool.query(
      "SELECT COUNT(*) AS value FROM feeding_orders WHERE receiver_id = ? AND status = 'completed'",
      [userId]
    ),
    pool.query('SELECT COUNT(*) AS value FROM mood_diary WHERE user_id = ?', [userId]),
    pool.query('SELECT COUNT(*) AS value FROM cooking_logs WHERE chef_id = ?', [userId]),
    pool.query('SELECT COUNT(*) AS value FROM cooking_logs WHERE chef_id = ? AND is_new = 1', [userId]),
  ]);
  const checkinStreak = await getCheckinStreak(userId);
  return {
    travel: Number(travelCount[0]?.value || 0),
    travel_city: Number(cityCount[0]?.value || 0),
    feeding: Number(feedingCount[0]?.value || 0),
    checkin: checkinStreak,
    mood: Number(moodCount[0]?.value || 0),
    cooking: Number(cookingCount[0]?.value || 0),
    cooking_new: Number(cookingNewCount[0]?.value || 0),
  };
}

function progressForAchievement(achievement, progress) {
  if (achievement.code.startsWith('travel_city_')) return progress.travel_city;
  if (achievement.code.startsWith('cooking_new_')) return progress.cooking_new;
  if (achievement.category === 'travel') return progress.travel;
  return progress[achievement.category] || 0;
}

async function checkAchievements(userId, category = null) {
  if (!userId) return [];
  try {
    await ensureAchievementsSeeded(pool);
    const params = [];
    let where = 'is_active = 1';
    if (category) {
      where += ' AND category = ?';
      params.push(category);
    }
    const [achievements] = await pool.query(
      `SELECT id, code, category, title, description, target_value, reward_beans
       FROM achievements
       WHERE ${where}
       ORDER BY id ASC`,
      params
    );
    if (achievements.length === 0) return [];

    const progress = await collectAchievementProgress(userId);
    const unlocked = [];
    for (const achievement of achievements) {
      const current = progressForAchievement(achievement, progress);
      if (current < Number(achievement.target_value || 0)) continue;

      const [result] = await pool.query(
        `INSERT IGNORE INTO user_achievements
         (user_id, achievement_id, progress, unlocked_at)
         VALUES (?, ?, ?, NOW())`,
        [userId, achievement.id, current]
      );
      if (result.affectedRows === 0) {
        await pool.query(
          'UPDATE user_achievements SET progress = GREATEST(progress, ?) WHERE user_id = ? AND achievement_id = ?',
          [current, userId, achievement.id]
        );
        continue;
      }

      unlocked.push({ ...achievement, progress: current });
      try {
        await awardBeans({
          userId,
          amount: Number(achievement.reward_beans || 0),
          type: 'achievement_unlock',
          title: achievement.title,
          sourceModule: 'achievement',
          sourceId: achievement.id,
          description: achievement.description || achievement.title,
        });
      } catch (err) {
        console.error('[Achievement] bean reward failed:', err.message);
      }

      // 新解锁成就 → 沉淀到时光轴
      try {
        await createTimelineEvent({
          userId,
          title: `解锁成就：${achievement.title}`,
          description: achievement.description || achievement.title,
          eventDate: todayString(),
          icon: 'achievement',
          sourceModule: 'achievement',
          sourceId: achievement.id,
        });
      } catch (err) {
        console.error('[Achievement] timeline sync failed:', err.message);
      }
    }
    return unlocked;
  } catch (err) {
    console.error('[Achievement] check failed:', err.message);
    return [];
  }
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
