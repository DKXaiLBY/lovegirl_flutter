const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { authRequired } = require('../middleware/auth');

function requireAdmin(req, res, next) {
  const user = req.user || {};
  const allowed =
    user.isAdmin === true ||
    user.is_admin === true ||
    user.is_admin === 1 ||
    user.role === 'admin' ||
    user.role === 'boy' ||
    user.username === 'admin';
  if (!allowed) {
    return res.status(403).json({ code: 403, message: 'admin only' });
  }
  next();
}

router.use(authRequired, requireAdmin);

router.get('/shops', async (req, res) => {
  try {
    const includeInactive = req.query.include_inactive === '1' || req.query.include_inactive === 'true';
    const [rows] = await pool.query(
      `SELECT id, name, icon, description, sort_order, is_active, created_at, updated_at
       FROM feeding_shops
       ${includeInactive ? '' : 'WHERE is_active = 1'}
       ORDER BY sort_order ASC, id ASC`
    );
    res.json({ code: 200, data: { list: rows, total: rows.length } });
  } catch (err) {
    console.error('[AdminProducts] get shops failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.post('/shops', async (req, res) => {
  try {
    const name = String(req.body.name || '').trim();
    if (!name) return res.status(400).json({ code: 400, message: 'name required' });

    const [result] = await pool.query(
      `INSERT INTO feeding_shops (name, icon, description, sort_order, is_active)
       VALUES (?, ?, ?, ?, ?)`,
      [
        name,
        req.body.icon || '🏪',
        req.body.description || '',
        Number(req.body.sort_order || 0),
        req.body.is_active === false ? 0 : 1,
      ]
    );
    res.json({ code: 200, message: 'shop created', data: { id: result.insertId } });
  } catch (err) {
    console.error('[AdminProducts] create shop failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.put('/shops/:id', async (req, res) => {
  try {
    const updates = {};
    for (const key of ['name', 'icon', 'description', 'sort_order', 'is_active']) {
      if (req.body[key] !== undefined) updates[key] = req.body[key];
    }
    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ code: 400, message: 'no updates' });
    }
    updates.updated_at = new Date();
    const [result] = await pool.query('UPDATE feeding_shops SET ? WHERE id = ?', [updates, req.params.id]);
    if (result.affectedRows === 0) return res.status(404).json({ code: 404, message: 'shop not found' });
    res.json({ code: 200, message: 'shop updated' });
  } catch (err) {
    console.error('[AdminProducts] update shop failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.delete('/shops/:id', async (req, res) => {
  try {
    await pool.query('UPDATE feeding_products SET is_active = 0, updated_at = NOW() WHERE shop_id = ?', [req.params.id]);
    const [result] = await pool.query('UPDATE feeding_shops SET is_active = 0, updated_at = NOW() WHERE id = ?', [req.params.id]);
    if (result.affectedRows === 0) return res.status(404).json({ code: 404, message: 'shop not found' });
    res.json({ code: 200, message: 'shop disabled' });
  } catch (err) {
    console.error('[AdminProducts] disable shop failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.get('/shops/:shopId/products', async (req, res) => {
  try {
    const includeInactive = req.query.include_inactive === '1' || req.query.include_inactive === 'true';
    const [rows] = await pool.query(
      `SELECT id, shop_id, name, description, price, image_url, category, sort_order, is_active, created_at, updated_at
       FROM feeding_products
       WHERE shop_id = ? ${includeInactive ? '' : 'AND is_active = 1'}
       ORDER BY sort_order ASC, id ASC`,
      [req.params.shopId]
    );
    res.json({ code: 200, data: { list: rows, total: rows.length } });
  } catch (err) {
    console.error('[AdminProducts] get products failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.post('/shops/:shopId/products', async (req, res) => {
  try {
    const name = String(req.body.name || '').trim();
    const price = Number(req.body.price);
    if (!name || !Number.isFinite(price) || price < 0) {
      return res.status(400).json({ code: 400, message: 'invalid product' });
    }
    const [result] = await pool.query(
      `INSERT INTO feeding_products
       (shop_id, name, description, price, image_url, category, sort_order, is_active)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        req.params.shopId,
        name,
        req.body.description || '',
        price,
        req.body.image_url || req.body.image || '',
        req.body.category || 'default',
        Number(req.body.sort_order || 0),
        req.body.is_active === false ? 0 : 1,
      ]
    );
    res.json({ code: 200, message: 'product created', data: { id: result.insertId } });
  } catch (err) {
    console.error('[AdminProducts] create product failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.put('/products/:id', async (req, res) => {
  try {
    const updates = {};
    for (const key of ['name', 'description', 'price', 'image_url', 'category', 'sort_order', 'is_active']) {
      if (req.body[key] !== undefined) updates[key] = req.body[key];
    }
    if (req.body.image !== undefined && updates.image_url === undefined) updates.image_url = req.body.image;
    if (updates.price !== undefined) {
      const price = Number(updates.price);
      if (!Number.isFinite(price) || price < 0) return res.status(400).json({ code: 400, message: 'invalid price' });
      updates.price = price;
    }
    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ code: 400, message: 'no updates' });
    }
    updates.updated_at = new Date();
    const [result] = await pool.query('UPDATE feeding_products SET ? WHERE id = ?', [updates, req.params.id]);
    if (result.affectedRows === 0) return res.status(404).json({ code: 404, message: 'product not found' });
    res.json({ code: 200, message: 'product updated' });
  } catch (err) {
    console.error('[AdminProducts] update product failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.patch('/products/:id/toggle', async (req, res) => toggleProduct(req, res));
router.put('/products/:id/toggle', async (req, res) => toggleProduct(req, res));

async function toggleProduct(req, res) {
  try {
    const active = req.body.is_active === undefined ? null : (req.body.is_active ? 1 : 0);
    const [current] = await pool.query('SELECT is_active FROM feeding_products WHERE id = ?', [req.params.id]);
    if (current.length === 0) return res.status(404).json({ code: 404, message: 'product not found' });
    const next = active === null ? (current[0].is_active ? 0 : 1) : active;
    await pool.query('UPDATE feeding_products SET is_active = ?, updated_at = NOW() WHERE id = ?', [next, req.params.id]);
    res.json({ code: 200, message: 'product toggled' });
  } catch (err) {
    console.error('[AdminProducts] toggle product failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
}

router.delete('/products/:id', async (req, res) => {
  try {
    const [result] = await pool.query('UPDATE feeding_products SET is_active = 0, updated_at = NOW() WHERE id = ?', [req.params.id]);
    if (result.affectedRows === 0) return res.status(404).json({ code: 404, message: 'product not found' });
    res.json({ code: 200, message: 'product disabled' });
  } catch (err) {
    console.error('[AdminProducts] disable product failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

module.exports = router;
