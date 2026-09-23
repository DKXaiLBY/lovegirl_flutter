const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authRequired } = require('../middleware/auth');
const { addBeanTransaction } = require('./utils/lovegirl_rewards');

function normalizeCategory(category) {
  return category || 'daily';
}

function nextRepeatDate(dueDate, repeatType) {
  if (!dueDate) return null;
  const next = new Date(dueDate);
  if (Number.isNaN(next.getTime())) return null;
  if (repeatType === 'weekly') next.setDate(next.getDate() + 7);
  else if (repeatType === 'monthly') next.setMonth(next.getMonth() + 1);
  else next.setDate(next.getDate() + 1);
  return next.toISOString().slice(0, 10);
}

async function rewardTodoCompleted(userId, todoId, title) {
  try {
    await addBeanTransaction(pool, {
      userId,
      amount: 3,
      type: 'todo_completed',
      title: 'Todo completed',
      sourceModule: 'todo',
      sourceId: todoId,
      description: title || '',
    });
  } catch (err) {
    console.error('Todo bean reward failed:', err.message);
  }
}

router.get('/', authRequired, async (req, res) => {
  try {
    const { category, status } = req.query;
    let sql = 'SELECT * FROM todos WHERE user_id = ?';
    const params = [req.user.id];
    if (category) {
      sql += ' AND category = ?';
      params.push(normalizeCategory(category));
    }
    if (status === 'completed') sql += ' AND completed = 1';
    else if (status === 'active') sql += ' AND completed = 0';
    sql += ' ORDER BY priority DESC, due_date ASC, created_at DESC';
    const [todos] = await pool.query(sql, params);
    res.json({ code: 200, data: todos });
  } catch (err) {
    console.error('List todos failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.post('/', authRequired, async (req, res) => {
  try {
    const { title, description, category, isRepeat, repeatType, priority, dueDate } = req.body;
    if (!title) return res.status(400).json({ code: 400, message: 'title is required' });
    const [result] = await pool.query(
      `INSERT INTO todos
       (user_id, title, description, category, is_repeat, repeat_type, priority, completed, due_date, boyfriend_help, version)
       VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, 0, 1)`,
      [
        req.user.id,
        title,
        description || '',
        normalizeCategory(category),
        isRepeat ? 1 : 0,
        repeatType || null,
        priority || 1,
        dueDate || null,
      ]
    );
    res.json({ code: 200, message: 'created', data: { id: result.insertId } });
  } catch (err) {
    console.error('Create todo failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.put('/:id', authRequired, async (req, res) => {
  try {
    const { title, description, category, isRepeat, repeatType, priority, dueDate } = req.body;
    const updates = {};
    if (title !== undefined) updates.title = title;
    if (description !== undefined) updates.description = description;
    if (category !== undefined) updates.category = normalizeCategory(category);
    if (isRepeat !== undefined) updates.is_repeat = isRepeat ? 1 : 0;
    if (repeatType !== undefined) updates.repeat_type = repeatType;
    if (priority !== undefined) updates.priority = priority;
    if (dueDate !== undefined) updates.due_date = dueDate || null;
    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ code: 400, message: 'no fields to update' });
    }
    const [result] = await pool.query(
      'UPDATE todos SET ?, version = version + 1 WHERE id = ? AND user_id = ?',
      [updates, req.params.id, req.user.id]
    );
    if (result.affectedRows === 0) return res.status(404).json({ code: 404, message: 'todo not found' });
    res.json({ code: 200, message: 'updated' });
  } catch (err) {
    console.error('Update todo failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.delete('/:id', authRequired, async (req, res) => {
  try {
    const [result] = await pool.query('DELETE FROM todos WHERE id = ? AND user_id = ?', [req.params.id, req.user.id]);
    if (result.affectedRows === 0) return res.status(404).json({ code: 404, message: 'todo not found' });
    res.json({ code: 200, message: 'deleted' });
  } catch (err) {
    console.error('Delete todo failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.put('/:id/toggle', authRequired, async (req, res) => {
  try {
    const [todos] = await pool.query('SELECT * FROM todos WHERE id = ? AND user_id = ?', [req.params.id, req.user.id]);
    if (todos.length === 0) return res.status(404).json({ code: 404, message: 'todo not found' });
    const todo = todos[0];
    const newCompleted = todo.completed ? 0 : 1;

    await pool.query(
      'UPDATE todos SET completed = ?, completed_at = ?, version = version + 1 WHERE id = ?',
      [newCompleted, newCompleted ? new Date() : null, todo.id]
    );

    if (newCompleted) {
      await rewardTodoCompleted(req.user.id, todo.id, todo.title);
    }

    if (newCompleted && todo.is_repeat) {
      await pool.query(
        `INSERT INTO todos
         (user_id, title, description, category, is_repeat, repeat_type, priority, completed, due_date, boyfriend_help, version)
         VALUES (?, ?, ?, ?, 1, ?, ?, 0, ?, 0, 1)`,
        [
          todo.user_id,
          todo.title,
          todo.description,
          todo.category,
          todo.repeat_type,
          todo.priority,
          nextRepeatDate(todo.due_date, todo.repeat_type),
        ]
      );
    }

    res.json({ code: 200, message: newCompleted ? 'completed' : 'uncompleted', data: { completed: newCompleted } });
  } catch (err) {
    console.error('Toggle todo failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.put('/:id/boyfriend-help', authRequired, async (req, res) => {
  try {
    if (req.user.role === 'girl') {
      const [result] = await pool.query(
        'UPDATE todos SET boyfriend_help = 1, version = version + 1 WHERE id = ? AND user_id = ?',
        [req.params.id, req.user.id]
      );
      if (result.affectedRows === 0) return res.status(404).json({ code: 404, message: 'todo not found' });
      return res.json({ code: 200, message: 'help requested' });
    }

    if (req.user.role === 'boy') {
      const [girls] = await pool.query("SELECT id FROM users WHERE role = 'girl' ORDER BY id ASC LIMIT 1");
      if (girls.length === 0) return res.status(404).json({ code: 404, message: 'girl user not found' });
      const [todos] = await pool.query(
        'SELECT * FROM todos WHERE id = ? AND user_id = ?',
        [req.params.id, girls[0].id]
      );
      if (todos.length === 0) return res.status(404).json({ code: 404, message: 'todo not found' });
      const todo = todos[0];
      const [result] = await pool.query(
        'UPDATE todos SET completed = 1, completed_at = COALESCE(completed_at, NOW()), boyfriend_help = 0, version = version + 1 WHERE id = ?',
        [req.params.id]
      );
      if (result.affectedRows === 0) return res.status(404).json({ code: 404, message: 'todo not found' });
      if (!todo.completed) await rewardTodoCompleted(todo.user_id, todo.id, todo.title);
      return res.json({ code: 200, message: 'help completed' });
    }

    res.status(403).json({ code: 403, message: 'unsupported role' });
  } catch (err) {
    console.error('Boyfriend help todo failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.get('/boyfriend/list', authRequired, async (req, res) => {
  try {
    if (req.user.role !== 'boy' && !req.user.isAdmin) {
      return res.status(403).json({ code: 403, message: 'boy only' });
    }
    const [girls] = await pool.query("SELECT id FROM users WHERE role = 'girl' ORDER BY id ASC LIMIT 1");
    if (girls.length === 0) return res.json({ code: 200, data: [] });
    const [todos] = await pool.query(
      'SELECT * FROM todos WHERE user_id = ? AND boyfriend_help = 1 AND completed = 0 ORDER BY priority DESC, due_date ASC',
      [girls[0].id]
    );
    res.json({ code: 200, data: todos });
  } catch (err) {
    console.error('List boyfriend help todos failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

module.exports = router;
