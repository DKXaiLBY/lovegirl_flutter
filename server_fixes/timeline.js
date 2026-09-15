// 恋爱时光轴路由：记录恋爱中的纪念事件
const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authRequired } = require('../middleware/auth');

// ==================== GET /api/timeline — 获取所有时光轴事件（按 event_date 升序） ====================
router.get('/', authRequired, async (req, res) => {
  try {
    const [events] = await pool.query(
      'SELECT * FROM love_timeline WHERE user_id = ? ORDER BY event_date ASC, created_at ASC',
      [req.user.id]
    );

    // 计算距今天数和时间描述
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const data = events.map(event => {
      const eventDate = new Date(event.event_date);
      eventDate.setHours(0, 0, 0, 0);
      const diffTime = today - eventDate;
      const daysAgo = Math.floor(diffTime / (1000 * 60 * 60 * 24));

      let timeAgo;
      if (daysAgo === 0) timeAgo = '今天';
      else if (daysAgo < 0) {
        // 未来事件
        const daysUntil = Math.abs(daysAgo);
        if (daysUntil === 1) timeAgo = '明天';
        else if (daysUntil < 30) timeAgo = `${daysUntil} 天后`;
        else if (daysUntil < 365) timeAgo = `${Math.floor(daysUntil / 30)} 个月后`;
        else timeAgo = `${Math.floor(daysUntil / 365)} 年后`;
      }
      else if (daysAgo === 1) timeAgo = '昨天';
      else if (daysAgo < 30) timeAgo = `${daysAgo} 天前`;
      else if (daysAgo < 365) timeAgo = `${Math.floor(daysAgo / 30)} 个月前`;
      else timeAgo = `${Math.floor(daysAgo / 365)} 年前`;

      return {
        id: event.id,
        title: event.title,
        description: event.description,
        eventDate: event.event_date,
        imageUrl: event.image_url,
        icon: event.icon,
        daysAgo,
        timeAgo,
        createdAt: event.created_at
      };
    });

    res.json({ code: 200, data });
  } catch (err) {
    console.error('获取时光轴失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== POST /api/timeline — 添加时光轴事件 ====================
router.post('/', authRequired, async (req, res) => {
  try {
    const { title, description, eventDate, imageUrl, icon } = req.body;
    if (!title || !eventDate) {
      return res.status(400).json({ code: 400, message: '请填写标题和事件日期' });
    }

    const [result] = await pool.query(
      'INSERT INTO love_timeline (user_id, title, description, event_date, image_url, icon) VALUES (?, ?, ?, ?, ?, ?)',
      [req.user.id, title, description || '', eventDate, imageUrl || null, icon || 'heart']
    );

    res.json({ code: 200, message: '添加成功', data: { id: result.insertId } });
  } catch (err) {
    console.error('添加时光轴事件失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== PUT /api/timeline/:id — 更新时光轴事件 ====================
router.put('/:id', authRequired, async (req, res) => {
  try {
    const { title, description, eventDate, imageUrl, icon } = req.body;

    const updates = {};
    if (title !== undefined) updates.title = title;
    if (description !== undefined) updates.description = description;
    if (eventDate !== undefined) updates.event_date = eventDate;
    if (imageUrl !== undefined) updates.image_url = imageUrl;
    if (icon !== undefined) updates.icon = icon;

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ code: 400, message: '没有要更新的字段' });
    }

    const [result] = await pool.query(
      'UPDATE love_timeline SET ? WHERE id = ? AND user_id = ?',
      [updates, req.params.id, req.user.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ code: 404, message: '事件不存在或无权修改' });
    }

    res.json({ code: 200, message: '更新成功' });
  } catch (err) {
    console.error('更新时光轴事件失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== DELETE /api/timeline/:id — 删除时光轴事件 ====================
router.delete('/:id', authRequired, async (req, res) => {
  try {
    const [result] = await pool.query(
      'DELETE FROM love_timeline WHERE id = ? AND user_id = ?',
      [req.params.id, req.user.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ code: 404, message: '事件不存在或无权删除' });
    }

    res.json({ code: 200, message: '删除成功' });
  } catch (err) {
    console.error('删除时光轴事件失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
