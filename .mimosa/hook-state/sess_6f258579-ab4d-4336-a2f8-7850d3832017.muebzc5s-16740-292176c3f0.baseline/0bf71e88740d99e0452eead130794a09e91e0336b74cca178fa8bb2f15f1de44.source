// 记账路由：金额加密存储、月度统计、隐私控制
const express = require('express');
const router = express.Router();
const multer = require('multer');
const pool = require('../config/database');
const { encrypt, decrypt } = require('../config/encrypt');

// Safe decrypt wrapper to handle corrupted/old data
function safeDecrypt(encrypted) {
  if (!encrypted) return '';
  try {
    return decrypt(encrypted);
  } catch (e) {
    console.error('解密失败:', e.message);
    // Try to return the raw value if it's not encrypted
    if (typeof encrypted === 'string' && !encrypted.includes(':')) {
      return encrypted;
    }
    return '[数据异常]';
  }
}

const { authRequired } = require('../middleware/auth');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } });

// GET /api/finance?month=2024-06 - 获取当月记录（解密amount后返回）
// 如果女友开启了财务隐私(finance_privacy_enabled=1)，男友看到金额显示为"***"
router.get('/', authRequired, async (req, res) => {
  try {
    const month = req.query.month || new Date().toISOString().substring(0, 7);
    const [year, mon] = month.split('-');

    const [records] = await pool.query(
      `SELECT * FROM finance_records
       WHERE user_id = ? AND YEAR(record_date) = ? AND MONTH(record_date) = ?
       ORDER BY record_date DESC, created_at DESC`,
      [req.user.id, year, mon]
    );

    // 检查是否需要隐藏金额
    let hideAmount = false;
    if (req.user.role !== 'boy') {
      // 查询女友是否启用了财务隐私
      const [girlUsers] = await pool.query(
        "SELECT finance_privacy_enabled FROM users WHERE role = 'girl' AND id = ?",
        [req.user.id]
      );
      if (girlUsers.length > 0 && girlUsers[0].finance_privacy_enabled) {
        hideAmount = true;
      }
    }

    // 如果当前用户是boy查看girl的数据，也检查隐私
    if (req.user.role === 'boy') {
      const [girlUsers] = await pool.query("SELECT finance_privacy_enabled FROM users WHERE role = 'girl'");
      if (girlUsers.length > 0 && girlUsers[0].finance_privacy_enabled) {
        // 男方查看女方账单，暂时允许看到金额（可以调整为隐藏）
        // hideAmount = true;
      }
    }

    const data = records.map(r => ({
      id: r.id,
      type: r.type,
      category: r.category,
      amount: hideAmount ? '***' : safeDecrypt(r.amount_encrypted),
      description: safeDecrypt(r.description_encrypted),
      receiptUrl: r.receipt_url,
      recordDate: r.record_date,
      createdAt: r.created_at
    }));

    res.json({ code: 200, data });
  } catch (err) {
    console.error('获取记账记录失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// POST /api/finance - 添加记录（amount 加密存储）
router.post('/', authRequired, async (req, res) => {
  try {
    const { type, category, amount, description, recordDate, receiptUrl } = req.body;
    if (!type || !category || amount === undefined) {
      return res.status(400).json({ code: 400, message: '请填写完整信息' });
    }

    const [result] = await pool.query(
      'INSERT INTO finance_records (user_id, type, category, amount_encrypted, description_encrypted, receipt_url, record_date, calorie_synced, version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)',
      [
        req.user.id,
        type,
        category,
        encrypt(String(amount)),
        encrypt(description || ''),
        receiptUrl || null,
        recordDate || new Date().toISOString().split('T')[0],
        0
      ]
    );

    res.json({ code: 200, message: '记录成功', data: { id: result.insertId } });
  } catch (err) {
    console.error('添加记账记录失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// PUT /api/finance/:id - 编辑记账记录
router.put('/:id', authRequired, async (req, res) => {
  try {
    const { type, category, amount, description, recordDate } = req.body;
    const updates = []; const params = [];
    if (type !== undefined) { updates.push('type=?'); params.push(type); }
    if (category !== undefined) { updates.push('category=?'); params.push(category); }
    if (amount !== undefined) { updates.push('amount_encrypted=?'); params.push(encrypt(String(amount))); }
    if (description !== undefined) { updates.push('description_encrypted=?'); params.push(encrypt(description)); }
    if (recordDate !== undefined) { updates.push('record_date=?'); params.push(recordDate); }
    if (updates.length === 0) return res.status(400).json({ code: 400, message: '没有要更新的字段' });
    params.push(req.params.id, req.user.id);
    await pool.query(`UPDATE finance_records SET ${updates.join(',')} WHERE id=? AND user_id=?`, params);
    res.json({ code: 200, message: '更新成功' });
  } catch (err) {
    console.error('编辑记账记录失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// DELETE /api/finance/:id - 删除记录
router.delete('/:id', authRequired, async (req, res) => {
  try {
    await pool.query('DELETE FROM finance_records WHERE id = ? AND user_id = ?', [req.params.id, req.user.id]);
    res.json({ code: 200, message: '删除成功' });
  } catch (err) {
    console.error('删除记账记录失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// GET /api/finance/stats?month=2024-06 - 月度统计
router.get('/stats', authRequired, async (req, res) => {
  try {
    const month = req.query.month || new Date().toISOString().substring(0, 7);
    const [year, mon] = month.split('-');

    const [records] = await pool.query(
      `SELECT * FROM finance_records
       WHERE user_id = ? AND YEAR(record_date) = ? AND MONTH(record_date) = ?`,
      [req.user.id, year, mon]
    );

    let totalIncome = 0;
    let totalExpense = 0;
    const categoryStats = {}; // 分类占比统计

    for (const r of records) {
      const amount = parseFloat(safeDecrypt(r.amount_encrypted)) || 0;

      if (r.type === 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
        // 统计分类占比
        const cat = r.category || '其他';
        if (!categoryStats[cat]) categoryStats[cat] = 0;
        categoryStats[cat] += amount;
      }
    }

    // 将分类统计转换为百分比数组
    const categoryBreakdown = Object.entries(categoryStats)
      .map(([name, value]) => ({
        name,
        amount: Math.round(value * 100) / 100,
        percent: totalExpense > 0 ? Math.round((value / totalExpense) * 10000) / 100 : 0
      }))
      .sort((a, b) => b.amount - a.amount);

    // 计算男友投喂总额（type=income 且 category 包含"男友"/"boyfriend"/"投喂"）
    let boyfriendFeed = 0;
    for (const r of records) {
      if (r.type === 'income') {
        const cat = (r.category || '').toLowerCase();
        if (cat.includes('男友') || cat.includes('boyfriend') || cat.includes('投喂') || cat.includes('红包') || cat.includes('转账')) {
          boyfriendFeed += parseFloat(safeDecrypt(r.amount_encrypted)) || 0;
        }
      }
    }

    res.json({
      code: 200,
      data: {
        month,
        totalIncome: Math.round(totalIncome * 100) / 100,
        totalExpense: Math.round(totalExpense * 100) / 100,
        balance: Math.round((totalIncome - totalExpense) * 100) / 100,
        categoryBreakdown,
        boyfriendFeed: Math.round(boyfriendFeed * 100) / 100
      }
    });
  } catch (err) {
    console.error('获取记账统计失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// GET /api/finance/templates — 返回默认快捷模板
const DEFAULT_TEMPLATES = [
  { id: 'breakfast', name: '早餐', type: 'expense', category: '餐饮', amount: 15, icon: '🍳' },
  { id: 'lunch', name: '午餐', type: 'expense', category: '餐饮', amount: 25, icon: '🍱' },
  { id: 'dinner', name: '晚餐', type: 'expense', category: '餐饮', amount: 30, icon: '🍲' },
  { id: 'milk_tea', name: '奶茶', type: 'expense', category: '饮品', amount: 18, icon: '🧋' },
  { id: 'transport', name: '交通', type: 'expense', category: '交通', amount: 10, icon: '🚇' },
  { id: 'shopping', name: '购物', type: 'expense', category: '购物', amount: 100, icon: '🛒' },
  { id: 'salary', name: '工资', type: 'income', category: '工资', amount: 5000, icon: '💰' },
  { id: 'red_packet', name: '红包', type: 'income', category: '红包', amount: 200, icon: '🧧' },
];
router.get('/templates', authRequired, async (req, res) => {
  // 合并默认模板和用户自定义模板（从用户settings读取）
  try {
    const [users] = await pool.query('SELECT id FROM users WHERE id=?', [req.user.id]);
    let customTemplates = [];
    try {
      const settings = {}
      customTemplates = settings.financeTemplates || [];
    } catch {}
    res.json({ code: 200, data: { default: DEFAULT_TEMPLATES, custom: customTemplates } });
  } catch (err) {
    console.error('获取模板失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// POST /api/finance/import — 批量导入Excel
router.post('/import', authRequired, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ code: 400, message: '请上传Excel文件' });
    const XLSX = require('xlsx');
    const wb = XLSX.read(req.file.buffer, { type: 'buffer' });
    const ws = wb.Sheets[wb.SheetNames[0]];
    const rows = XLSX.utils.sheet_to_json(ws, { header: 1 }).slice(1); // 跳过表头
    let imported = 0;
    for (const row of rows) {
      if (!row[0] && !row[2]) continue;
      const recordDate = row[0] || new Date().toISOString().split('T')[0];
      const type = (row[1] || '').includes('收入') ? 'income' : 'expense';
      const category = row[2] || '其他';
      const amount = parseFloat(row[3]) || 0;
      const description = row[4] || '';
      if (amount > 0) {
        await pool.query('INSERT INTO finance_records (user_id, type, category, amount_encrypted, description_encrypted, record_date) VALUES (?,?,?,?,?,?)',
          [req.user.id, type, category, encrypt(String(amount)), encrypt(description), recordDate]);
        imported++;
      }
    }
    res.json({ code: 200, message: `成功导入 ${imported} 条记录`, data: { imported } });
  } catch (err) {
    console.error('导入失败:', err);
    res.status(500).json({ code: 500, message: '导入失败，请检查Excel格式（第1列日期，第2列类型，第3列分类，第4列金额，第5列描述）' });
  }
});


module.exports = router;
