const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');

function isAdmin(user) {
  return user?.isAdmin || user?.is_admin || user?.role === 'admin' || user?.username === 'admin';
}

function requireAdmin(req, res, next) {
  if (!isAdmin(req.user)) {
    return res.status(403).json({ code: 403, message: 'admin only' });
  }
  next();
}

function numberOrNull(value) {
  if (value === undefined || value === null || value === '') return null;
  const next = Number(value);
  return Number.isFinite(next) ? next : null;
}

router.use(authRequired, requireAdmin);

router.get('/shops', async (req, res) => {
  try {
    const includeInactive = req.query.include_inactive === '1';
    const [rows] = await pool.query(
      `SELECT id, name, icon, description, category, banner_color, sort_order, is_active, created_at, updated_at
       FROM feeding_shops
       ${includeInactive ? '' : 'WHERE is_active = 1'}
       ORDER BY sort_order ASC, id ASC`
    );
    res.json({ code: 200, data: { list: rows, total: rows.length } });
  } catch (err) {
    console.error('[Admin] get shops failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.post('/shops', async (req, res) => {
  try {
    const name = (req.body.name || '').toString().trim();
    if (!name) return res.status(400).json({ code: 400, message: 'name is required' });
    const [result] = await pool.query(
      `INSERT INTO feeding_shops
       (name, icon, description, category, banner_color, sort_order, is_active)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        name,
        req.body.icon || 'shop',
        req.body.description || '',
        req.body.category || 'food',
        req.body.banner_color || '#E9856B',
        numberOrNull(req.body.sort_order) || 0,
        req.body.is_active === false ? 0 : 1,
      ]
    );
    res.json({ code: 200, message: 'shop created', data: { id: result.insertId } });
  } catch (err) {
    console.error('[Admin] create shop failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.put('/shops/:id', async (req, res) => {
  try {
    const fields = {};
    for (const key of ['name', 'icon', 'description', 'category', 'banner_color']) {
      if (req.body[key] !== undefined) fields[key] = req.body[key];
    }
    if (req.body.sort_order !== undefined) fields.sort_order = numberOrNull(req.body.sort_order) || 0;
    if (req.body.is_active !== undefined) fields.is_active = req.body.is_active ? 1 : 0;
    if (Object.keys(fields).length === 0) return res.status(400).json({ code: 400, message: 'no updates' });
    const [result] = await pool.query('UPDATE feeding_shops SET ? WHERE id = ?', [fields, Number(req.params.id)]);
    if (result.affectedRows === 0) return res.status(404).json({ code: 404, message: 'shop not found' });
    res.json({ code: 200, message: 'shop updated' });
  } catch (err) {
    console.error('[Admin] update shop failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.delete('/shops/:id', async (req, res) => {
  try {
    const shopId = Number(req.params.id);
    const [result] = await pool.query('UPDATE feeding_shops SET is_active = 0 WHERE id = ?', [shopId]);
    if (result.affectedRows === 0) return res.status(404).json({ code: 404, message: 'shop not found' });
    await pool.query('UPDATE feeding_products SET is_active = 0 WHERE shop_id = ?', [shopId]);
    res.json({ code: 200, message: 'shop disabled' });
  } catch (err) {
    console.error('[Admin] disable shop failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.get('/shops/:shopId/products', async (req, res) => {
  try {
    const includeInactive = req.query.include_inactive === '1';
    const [rows] = await pool.query(
      `SELECT id, shop_id, name, description, price, image, category, sort_order, is_active, is_custom, created_by, created_at, updated_at
       FROM feeding_products
       WHERE shop_id = ? ${includeInactive ? '' : 'AND is_active = 1'}
       ORDER BY sort_order ASC, id ASC`,
      [Number(req.params.shopId)]
    );
    res.json({ code: 200, data: { list: rows, total: rows.length } });
  } catch (err) {
    console.error('[Admin] get products failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.post('/shops/:shopId/products', async (req, res) => {
  try {
    const name = (req.body.name || '').toString().trim();
    const price = numberOrNull(req.body.price);
    if (!name || price === null || price < 0) {
      return res.status(400).json({ code: 400, message: 'valid name and price are required' });
    }
    const shopId = Number(req.params.shopId);
    const [shops] = await pool.query('SELECT id FROM feeding_shops WHERE id = ?', [shopId]);
    if (shops.length === 0) return res.status(404).json({ code: 404, message: 'shop not found' });
    const [result] = await pool.query(
      `INSERT INTO feeding_products
       (shop_id, name, description, price, image, category, sort_order, is_active, is_custom, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?)`,
      [
        shopId,
        name,
        req.body.description || '',
        price,
        req.body.image || null,
        req.body.category || 'custom',
        numberOrNull(req.body.sort_order) || 0,
        req.body.is_active === false ? 0 : 1,
        req.user.id,
      ]
    );
    res.json({ code: 200, message: 'product created', data: { id: result.insertId } });
  } catch (err) {
    console.error('[Admin] create product failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

router.put('/products/:id', async (req, res) => {
  try {
    const fields = {};
    for (const key of ['shop_id', 'name', 'description', 'image', 'category']) {
      if (req.body[key] !== undefined) fields[key] = req.body[key];
    }
    if (req.body.price !== undefined) {
      const price = numberOrNull(req.body.price);
      if (price === null || price < 0) return res.status(400).json({ code: 400, message: 'invalid price' });
      fields.price = price;
    }
    if (req.body.sort_order !== undefined) fields.sort_order = numberOrNull(req.body.sort_order) || 0;
    if (req.body.is_active !== undefined) fields.is_active = req.body.is_active ? 1 : 0;
    if (Object.keys(fields).length === 0) return res.status(400).json({ code: 400, message: 'no updates' });
    const [result] = await pool.query('UPDATE feeding_products SET ? WHERE id = ?', [fields, Number(req.params.id)]);
    if (result.affectedRows === 0) return res.status(404).json({ code: 404, message: 'product not found' });
    res.json({ code: 200, message: 'product updated' });
  } catch (err) {
    console.error('[Admin] update product failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

async function toggleProduct(req, res) {
  try {
    const isActive = req.body.is_active === undefined ? null : (req.body.is_active ? 1 : 0);
    const [result] = await pool.query(
      'UPDATE feeding_products SET is_active = COALESCE(?, 1 - is_active) WHERE id = ?',
      [isActive, Number(req.params.id)]
    );
    if (result.affectedRows === 0) return res.status(404).json({ code: 404, message: 'product not found' });
    res.json({ code: 200, message: 'product toggled' });
  } catch (err) {
    console.error('[Admin] toggle product failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
}

router.patch('/products/:id/toggle', toggleProduct);
router.put('/products/:id/toggle', toggleProduct);

router.delete('/products/:id', async (req, res) => {
  try {
    const [result] = await pool.query('UPDATE feeding_products SET is_active = 0 WHERE id = ?', [Number(req.params.id)]);
    if (result.affectedRows === 0) return res.status(404).json({ code: 404, message: 'product not found' });
    res.json({ code: 200, message: 'product disabled' });
  } catch (err) {
    console.error('[Admin] disable product failed:', err);
    res.status(500).json({ code: 500, message: 'server error' });
  }
});

module.exports = router;
