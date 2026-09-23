const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');
const {
  todayString,
  getPartnerId,
  addBeanTransaction,
  createTimelineEvent,
  checkAchievements,
} = require('./utils/lovegirl_rewards');

// 美食手账：共同的餐桌相册。谁做的记录（chef），对方品尝评分（eater），
// 新菜可一键挂上点单菜单（kitchen_dishes），自动沉淀时光轴 + 成就 + 豆子激励。

function cleanText(v, max) {
  return String(v ?? '').trim().slice(0, max);
}

function isValidDate(s) {
  return /^\d{4}-\d{2}-\d{2}$/.test(String(s)) && !Number.isNaN(Date.parse(`${s}T00:00:00Z`));
}

function rowToJson(r) {
  return {
    id: r.id,
    chefId: r.chef_id,
    title: r.title,
    emoji: r.emoji || '🍳',
    photoUrl: r.photo_url,
    recipe: r.recipe || null,
    story: r.story || null,
    isNew: r.is_new === 1,
    chefRating: r.chef_rating,
    eaterId: r.eater_id,
    eaterRating: r.eater_rating,
    eaterComment: r.eater_comment,
    cookedAt: r.cooked_at instanceof Date
      ? r.cooked_at.toISOString().slice(0, 10)
      : String(r.cooked_at || '').slice(0, 10),
    dishId: r.dish_id,
    createdAt: r.created_at,
  };
}

// 列表（两人的共同相册，按做的日期倒序）+ 图鉴统计
router.get('/list', authRequired, async (req, res) => {
  try {
    const partnerId = await getPartnerId(req.user.id);
    // 全部字面量 SQL，按绑定状态走两条分支
    let rows;
    let newRows;
    if (partnerId != null) {
      [rows] = await pool.query(
        'SELECT * FROM cooking_logs WHERE chef_id IN (?, ?) ORDER BY cooked_at DESC, id DESC LIMIT 200',
        [req.user.id, partnerId]
      );
      [newRows] = await pool.query(
        'SELECT id, title, emoji, cooked_at FROM cooking_logs WHERE chef_id IN (?, ?) AND is_new = 1 ORDER BY cooked_at DESC, id DESC LIMIT 200',
        [req.user.id, partnerId]
      );
    } else {
      [rows] = await pool.query(
        'SELECT * FROM cooking_logs WHERE chef_id = ? ORDER BY cooked_at DESC, id DESC LIMIT 200',
        [req.user.id]
      );
      [newRows] = await pool.query(
        'SELECT id, title, emoji, cooked_at FROM cooking_logs WHERE chef_id = ? AND is_new = 1 ORDER BY cooked_at DESC, id DESC LIMIT 200',
        [req.user.id]
      );
    }
    const month = todayString().slice(0, 7); // YYYY-MM（北京日）
    const logs = rows.map(rowToJson);
    const gallery = newRows.map((r) => ({
      id: r.id,
      title: r.title,
      emoji: r.emoji || '🍳',
      cookedAt: r.cooked_at instanceof Date
        ? r.cooked_at.toISOString().slice(0, 10)
        : String(r.cooked_at || '').slice(0, 10),
    }));

    res.json({
      code: 200,
      data: {
        hasPartner: partnerId != null,
        stats: {
          total: logs.length,
          newTotal: gallery.length,
          monthTotal: logs.filter((l) => String(l.cookedAt).startsWith(month)).length,
          monthNew: gallery.filter((l) => String(l.cookedAt).startsWith(month)).length,
        },
        logs,
        gallery,
      },
    });
  } catch (err) {
    console.error('[Cooking] list failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 记录一次下厨
router.post('/', authRequired, async (req, res) => {
  try {
    const partnerId = await getPartnerId(req.user.id);
    const title = cleanText(req.body.title, 100);
    if (!title) return res.status(400).json({ code: 400, message: '这道菜叫什么名字？' });

    const emoji = cleanText(req.body.emoji, 16) || '🍳';
    let photoUrl = cleanText(req.body.photoUrl, 500) || null;
    if (photoUrl != null && !(photoUrl.startsWith('http') || photoUrl.startsWith('/uploads'))) {
      photoUrl = null;
    }
    const recipe = cleanText(req.body.recipe, 3000) || null;
    const story = cleanText(req.body.story, 1000) || null;
    const isNew = req.body.isNew === true;
    const chefRating = [1, 2, 3, 4, 5].includes(req.body.chefRating) ? req.body.chefRating : null;
    const cookedAt = isValidDate(req.body.cookedAt) ? req.body.cookedAt : todayString();
    if (cookedAt > todayString()) {
      return res.status(400).json({ code: 400, message: '做的日期不能是未来哦' });
    }
    const addToMenu = req.body.addToMenu === true;

    const [result] = await pool.query(
      `INSERT INTO cooking_logs
       (chef_id, title, emoji, photo_url, recipe, story, is_new, chef_rating, cooked_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [req.user.id, title, emoji, photoUrl, recipe, story, isNew ? 1 : 0, chefRating, cookedAt]
    );
    const logId = result.insertId;

    // 一键挂上点单菜单（写到自己的菜单里，对方点单时可见）
    let dishId = null;
    if (addToMenu) {
      try {
        // 去重：同名菜已在菜单则复用，不重复插入
        const [existing] = await pool.query(
          'SELECT id FROM kitchen_dishes WHERE user_id = ? AND name = ? LIMIT 1',
          [req.user.id, title]
        );
        if (existing.length > 0) {
          dishId = existing[0].id;
        } else {
          const [dish] = await pool.query(
            `INSERT INTO kitchen_dishes (user_id, name, category, emoji, photo_url, description)
             VALUES (?, ?, '家常菜', ?, ?, ?)`,
            [req.user.id, title, emoji, photoUrl, story ? story.slice(0, 100) : null]
          );
          dishId = dish.insertId;
        }
        await pool.query('UPDATE cooking_logs SET dish_id = ? WHERE id = ?', [dishId, logId]);
      } catch (err) {
        console.error('[Cooking] add to menu failed:', err.message);
      }
    }

    // 新菜激励：+10 豆（每条记录一次，幂等）
    if (isNew) {
      try {
        await addBeanTransaction(pool, {
          userId: req.user.id,
          amount: 10,
          type: 'cooking_new',
          title: '尝试新菜',
          sourceModule: 'cooking',
          sourceId: logId,
          description: title,
        });
      } catch (err) {
        console.error('[Cooking] bean reward failed:', err.message);
      }
    }

    // 双人时光轴沉淀（各自一条，幂等）
    const tlTitle = `${isNew ? '新菜' : '复刻'}「${title}」`;
    const tlDesc = story || (recipe ? recipe.slice(0, 80) : '');
    const timelineTargets = partnerId != null ? [req.user.id, partnerId] : [req.user.id];
    for (const uid of timelineTargets) {
      try {
        await createTimelineEvent({
          userId: uid,
          title: tlTitle,
          description: tlDesc,
          eventDate: cookedAt,
          imageUrl: photoUrl,
          icon: 'restaurant',
          sourceModule: 'cooking',
          sourceId: logId,
        });
      } catch (err) {
        console.error('[Cooking] timeline failed:', err.message);
      }
    }

    // 通知对方来品尝打分
    if (partnerId != null) {
      try {
        await pool.query(
          'INSERT INTO notifications (user_id, type, title, content, payload) VALUES (?, ?, ?, ?, ?)',
          [partnerId, 'cooking', isNew ? 'TA 尝了道新菜' : 'TA 下厨啦', `「${title}」等你去品尝打分`, JSON.stringify({ cooking_id: logId })]
        );
      } catch (err) {
        console.error('[Cooking] notify failed:', err.message);
      }
    }

    // 成就检查（cooking 类别）
    let unlocked = [];
    try {
      unlocked = await checkAchievements(req.user.id, 'cooking');
    } catch (err) {
      console.error('[Cooking] achievement check failed:', err.message);
    }

    res.json({
      code: 200,
      data: { id: logId, dishId, unlocked: unlocked.map((a) => ({ title: a.title, reward: a.reward_beans })) },
    });
  } catch (err) {
    console.error('[Cooking] create failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 品尝评分（只有伴侣能评，一条一次）
router.put('/:id/taste', authRequired, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const rating = req.body.rating;
    const comment = cleanText(req.body.comment, 300) || null;
    if (![1, 2, 3, 4, 5].includes(rating)) {
      return res.status(400).json({ code: 400, message: '打 1-5 星哦' });
    }
    const [rows] = await pool.query(
      'SELECT id, chef_id, eater_id, title FROM cooking_logs WHERE id = ?',
      [id]
    );
    if (rows.length === 0) return res.status(404).json({ code: 404, message: '记录不存在' });
    const log = rows[0];
    if (log.chef_id === req.user.id) {
      return res.status(400).json({ code: 400, message: '自己做的自己打分可不行，等 TA 来尝' });
    }
    // P0 修复：只有掌勺的伴侣才能评分
    const myPartner = await getPartnerId(req.user.id);
    if (myPartner == null || myPartner !== log.chef_id) {
      return res.status(403).json({ code: 403, message: '只有 TA 的伴侣可以品尝打分' });
    }
    // P0 修复：原子条件更新，防并发重复评分/双发豆
    const [upd] = await pool.query(
      'UPDATE cooking_logs SET eater_id = ?, eater_rating = ?, eater_comment = ? WHERE id = ? AND eater_id IS NULL',
      [req.user.id, rating, comment, id]
    );
    if (upd.affectedRows === 0) {
      return res.status(403).json({ code: 403, message: '这道菜已经有人品尝打分啦' });
    }

    // 品尝互动 +2 豆
    try {
      await addBeanTransaction(pool, {
        userId: req.user.id,
        amount: 2,
        type: 'cooking_taste',
        title: '品尝评分',
        sourceModule: 'cooking_taste',
        sourceId: id,
        description: log.title,
      });
    } catch (err) {
      console.error('[Cooking] taste bean failed:', err.message);
    }

    try {
      await pool.query(
        'INSERT INTO notifications (user_id, type, title, content, payload) VALUES (?, ?, ?, ?, ?)',
        [log.chef_id, 'cooking_taste', '你的菜被评分啦', `「${log.title}」拿了 ${rating} 星${comment ? `：${comment.slice(0, 30)}` : ''}`, JSON.stringify({ cooking_id: id })]
      );
    } catch (err) {
      console.error('[Cooking] taste notify failed:', err.message);
    }

    res.json({ code: 200, message: '评分成功' });
  } catch (err) {
    console.error('[Cooking] taste failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 删除记录（仅掌勺本人）
router.delete('/:id', authRequired, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const [rows] = await pool.query(
      'SELECT id, dish_id FROM cooking_logs WHERE id = ? AND chef_id = ?',
      [id, req.user.id]
    );
    if (rows.length === 0) return res.status(404).json({ code: 404, message: '记录不存在' });
    const dishId = rows[0].dish_id;
    // 级联清理：挂上菜单的菜品、双人时光轴条目
    if (dishId) {
      await pool.query('DELETE FROM kitchen_dishes WHERE id = ?', [dishId]);
    }
    await pool.query(
      "DELETE FROM love_timeline WHERE source_module = 'cooking' AND source_id = ?",
      [id]
    );
    await pool.query('DELETE FROM cooking_logs WHERE id = ?', [id]);
    res.json({ code: 200, message: '已删除' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
