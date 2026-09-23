// 后台管理路由：全部需要 authRequired + role=boy 检查
// 敏感数据（经期/体重/账单）通过 x-admin-secure 请求头控制是否返回明文
const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const pool = require('../config/database');
const { encrypt, decrypt } = require('../config/encrypt');
const { authRequired } = require('../middleware/auth');

// ==================== 中间件：检查是否为 boy 角色 ====================
function boyOnly(req, res, next) {
  if (req.user.role !== 'boy') {
    return res.status(403).json({ code: 403, message: '仅限男友访问' });
  }
  next();
}

// 所有管理路由都需要认证 + boy 角色
router.use(authRequired, boyOnly);

// ==================== multer 上传配置（照片上传） ====================
const uploadDir = path.join(__dirname, '..', 'uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dest = path.join(__dirname, '..', 'uploads');
    cb(null, dest);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, Date.now() + '-' + Math.random().toString(36).substr(2, 9) + ext);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 50 * 1024 * 1024 } // 最大50MB
});

// ==================== 辅助函数：获取 girl 用户信息 ====================
async function getGirlUser() {
  const [users] = await pool.query("SELECT * FROM users WHERE role = 'girl' LIMIT 1");
  return users.length > 0 ? users[0] : null;
}

// 检查是否有 x-admin-secure 权限
function hasSecureAccess(req) {
  const val = req.headers['x-admin-secure'];
  return val === 'true' || val === '1' || val === 'secure';
}

// ==================== GET /api/admin/dashboard — 仪表盘数据 ====================
router.get('/dashboard', async (req, res) => {
  try {
    const girl = await getGirlUser();
    if (!girl) {
      return res.json({ code: 200, data: { message: '还未创建女友账号' } });
    }

    // 并行查询各项数据
    const [
      [periodRecords],       // 经期记录（分析周期规律）
      [todoWeekStats],       // 本周待办统计
      [weightRecords],       // 本月体重记录
      [financeStats],        // 本月她支出 + 男友投喂
      [recentMoods],         // 最近心情
      [upcomingExams],       // 最近考试
      [unreadMessages]       // 未读消息
    ] = await Promise.all([
      // 经期记录（用于分析规律）
      pool.query(
        'SELECT * FROM period_records WHERE user_id = ? ORDER BY updated_at DESC LIMIT 12',
        [girl.id]
      ),
      // 本周待办统计
      pool.query(
        `SELECT
           COUNT(*) as total,
           SUM(CASE WHEN completed = 1 THEN 1 ELSE 0 END) as completed
         FROM todos
         WHERE user_id = ? AND WEEK(due_date, 1) = WEEK(CURDATE(), 1) AND YEAR(due_date) = YEAR(CURDATE())`,
        [girl.id]
      ),
      // 本月体重记录（最新3条）
      pool.query(
        `SELECT id, weight_encrypted, record_date
         FROM weight_records
         WHERE user_id = ? AND YEAR(record_date) = YEAR(CURDATE()) AND MONTH(record_date) = MONTH(CURDATE())
         ORDER BY record_date DESC LIMIT 10`,
        [girl.id]
      ),
      // 本月她支出总额、男友投喂总额
      pool.query(
        `SELECT * FROM finance_records
         WHERE user_id = ? AND YEAR(record_date) = YEAR(CURDATE()) AND MONTH(record_date) = MONTH(CURDATE())`,
        [girl.id]
      ),
      // 最近7天心情
      pool.query(
        `SELECT mood, note, record_date FROM mood_diary
         WHERE user_id = ? AND record_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
         ORDER BY record_date DESC LIMIT 7`,
        [girl.id]
      ),
      // 即将到来的考试
      pool.query(
        'SELECT id, subject, exam_date FROM exams WHERE user_id = ? AND exam_date >= CURDATE() ORDER BY exam_date ASC LIMIT 5',
        [girl.id]
      ),
      // 未读消息数
      pool.query(
        'SELECT COUNT(*) as count FROM chat_messages WHERE receiver_id = ? AND is_read = 0',
        [girl.id]
      )
    ]);

    // 分析经期周期是否规律
    let periodRegularity = { regular: true, message: '数据不足' };
    if (periodRecords.length >= 2) {
      const cycles = [];
      for (let i = 0; i < periodRecords.length; i++) {
        if (!periodRecords[i].cycle_days_encrypted) continue;
        const cycleDays = parseInt(decrypt(periodRecords[i].cycle_days_encrypted)) || 0;
        if (cycleDays > 0) cycles.push(cycleDays);
      }
      if (cycles.length >= 2) {
        const avg = cycles.reduce((a, b) => a + b, 0) / cycles.length;
        const variance = cycles.reduce((sum, c) => sum + Math.pow(c - avg, 2), 0) / cycles.length;
        const stdDev = Math.sqrt(variance);
        periodRegularity = {
          regular: stdDev <= 3,
          averageCycle: Math.round(avg),
          stdDev: Math.round(stdDev * 10) / 10,
          recordCount: cycles.length,
          message: stdDev <= 3 ? '周期规律，很好哦~' : `周期波动较大(±${Math.round(stdDev)}天)，注意休息`
        };
      }
    }

    // 体重最新值和趋势
    let weightInfo = { latest: null, trend: '暂无数据', records: [] };
    if (weightRecords.length > 0) {
      const weightList = weightRecords.map(r => ({
        weight: r.weight_encrypted ? (parseFloat(decrypt(r.weight_encrypted)) || 0) : 0,
        date: r.record_date
      })).reverse(); // 按日期升序

      const latest = weightList[weightList.length - 1];
      let trend = '持平';
      if (weightList.length >= 2) {
        const first = weightList[0].weight;
        const diff = latest.weight - first;
        if (diff > 0.5) trend = '上升';
        else if (diff < -0.5) trend = '下降';
        else trend = '持平';
      }
      weightInfo = {
        latest: latest ? latest.weight : null,
        latestDate: latest ? latest.date : null,
        trend,
        records: weightList
      };
    }

    // 本月她支出 + 男友投喂总额
    let herExpense = 0;
    let boyfriendFeed = 0;
    for (const r of financeStats) {
      if (!r.amount_encrypted) continue;
      const amount = parseFloat(decrypt(r.amount_encrypted)) || 0;
      if (r.type === 'expense') {
        herExpense += amount;
      } else if (r.type === 'income') {
        const cat = (r.category || '').toLowerCase();
        if (cat.includes('男友') || cat.includes('boyfriend') || cat.includes('投喂') || cat.includes('红包') || cat.includes('转账')) {
          boyfriendFeed += amount;
        }
      }
    }

    // 心情概览：统计最近心情分布
    const moodSummary = {};
    for (const m of recentMoods) {
      moodSummary[m.mood] = (moodSummary[m.mood] || 0) + 1;
    }

    res.json({
      code: 200,
      data: {
        girlNickname: girl.nickname,
        partnerNickname: girl.partner_nickname,
        avatarUrl: girl.avatar_url,
        loveStartDate: girl.love_start_date,
        periodRegularity,
        todoStats: {
          total: todoWeekStats[0] ? todoWeekStats[0].total : 0,
          completed: todoWeekStats[0] ? todoWeekStats[0].completed : 0
        },
        weightInfo,
        finance: {
          month: new Date().toISOString().substring(0, 7),
          herExpense: Math.round(herExpense * 100) / 100,
          boyfriendFeed: Math.round(boyfriendFeed * 100) / 100
        },
        moodOverview: {
          records: recentMoods,
          summary: moodSummary
        },
        upcomingExams,
        unreadMessages: unreadMessages[0] ? unreadMessages[0].count : 0
      }
    });
  } catch (err) {
    console.error('获取仪表盘数据失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== GET /api/admin/period — 查看经期记录 ====================
// 需要 x-admin-secure 头才能解密返回明文，否则敏感字段返回 ***
router.get('/period', async (req, res) => {
  try {
    const girl = await getGirlUser();
    if (!girl) return res.json({ code: 200, data: [] });

    const secure = hasSecureAccess(req);

    const [records] = await pool.query(
      'SELECT * FROM period_records WHERE user_id = ? ORDER BY updated_at DESC',
      [girl.id]
    );

    const data = records.map(r => ({
      id: r.id,
      startDate: secure ? decrypt(r.start_date_encrypted) : '***',
      cycleDays: secure ? parseInt(decrypt(r.cycle_days_encrypted)) || 28 : '***',
      durationDays: secure ? parseInt(decrypt(r.duration_days_encrypted)) || 5 : '***',
      painLevel: secure ? (r.pain_level_encrypted ? parseInt(decrypt(r.pain_level_encrypted)) : 0) : '***',
      symptoms: secure ? (r.symptoms_encrypted ? JSON.parse(decrypt(r.symptoms_encrypted)) : []) : '***',
      medicine: secure ? (r.medicine_encrypted ? decrypt(r.medicine_encrypted) : '') : '***',
      notes: secure ? (r.notes_encrypted ? decrypt(r.notes_encrypted) : '') : '***',
      version: r.version,
      createdAt: r.created_at,
      updatedAt: r.updated_at
    }));

    res.json({ code: 200, data, secure });
  } catch (err) {
    console.error('获取经期记录失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== GET /api/admin/weight — 查看体重记录 ====================
router.get('/weight', async (req, res) => {
  try {
    const girl = await getGirlUser();
    if (!girl) return res.json({ code: 200, data: [] });

    const [records] = await pool.query(
      'SELECT id, weight_encrypted, record_date, created_at FROM weight_records WHERE user_id = ? ORDER BY record_date DESC LIMIT 90',
      [girl.id]
    );

    const data = records.map(r => ({
      id: r.id,
      weight: parseFloat(decrypt(r.weight_encrypted)) || 0,
      recordDate: r.record_date,
      createdAt: r.created_at
    }));

    res.json({ code: 200, data });
  } catch (err) {
    console.error('获取体重记录失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== GET /api/admin/todos — 查看她的待办 ====================
router.get('/todos', async (req, res) => {
  try {
    const girl = await getGirlUser();
    if (!girl) return res.json({ code: 200, data: [] });

    const [todos] = await pool.query(
      'SELECT * FROM todos WHERE user_id = ? ORDER BY priority DESC, due_date ASC, created_at DESC',
      [girl.id]
    );

    res.json({ code: 200, data: todos });
  } catch (err) {
    console.error('获取待办失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== GET /api/admin/exams — 查看她的考试 ====================
router.get('/exams', async (req, res) => {
  try {
    const girl = await getGirlUser();
    if (!girl) return res.json({ code: 200, data: [] });

    const [exams] = await pool.query(
      `SELECT * FROM exams WHERE user_id = ?
       ORDER BY CASE WHEN exam_date >= CURDATE() THEN 0 ELSE 1 END, exam_date ASC`,
      [girl.id]
    );

    res.json({ code: 200, data: exams });
  } catch (err) {
    console.error('获取考试失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== GET /api/admin/courses — 查看她的课程表 ====================
router.get('/courses', async (req, res) => {
  try {
    const girl = await getGirlUser();
    if (!girl) return res.json({ code: 200, data: [] });

    const [courses] = await pool.query(
      'SELECT * FROM courses WHERE user_id = ? ORDER BY day_of_week ASC, start_time ASC',
      [girl.id]
    );

    res.json({ code: 200, data: courses });
  } catch (err) {
    console.error('获取课程失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== GET /api/admin/finance?month= — 查看账单 ====================
// finance_privacy_enabled=1 时，amount 返回 ***（除非有 x-admin-secure）
router.get('/finance', async (req, res) => {
  try {
    const girl = await getGirlUser();
    if (!girl) return res.json({ code: 200, data: [] });

    const month = req.query.month || new Date().toISOString().substring(0, 7);
    const [year, mon] = month.split('-');

    const [records] = await pool.query(
      `SELECT * FROM finance_records
       WHERE user_id = ? AND YEAR(record_date) = ? AND MONTH(record_date) = ?
       ORDER BY record_date DESC, created_at DESC`,
      [girl.id, year, mon]
    );

    // 隐私控制：finance_privacy_enabled=1 且没有 x-admin-secure 则隐藏金额
    const hideAmount = girl.finance_privacy_enabled === 1 && !hasSecureAccess(req);

    const data = records.map(r => ({
      id: r.id,
      type: r.type,
      category: r.category,
      amount: hideAmount ? '***' : decrypt(r.amount_encrypted),
      description: decrypt(r.description_encrypted),
      receiptUrl: r.receipt_url,
      recordDate: r.record_date,
      calorieSynced: !!r.calorie_synced,
      createdAt: r.created_at
    }));

    // 月度汇总统计
    let totalIncome = 0;
    let totalExpense = 0;
    if (!hideAmount) {
      for (const r of records) {
        const amount = parseFloat(decrypt(r.amount_encrypted)) || 0;
        if (r.type === 'income') totalIncome += amount;
        else totalExpense += amount;
      }
    }

    res.json({
      code: 200,
      data: {
        records: data,
        summary: {
          totalIncome: Math.round(totalIncome * 100) / 100,
          totalExpense: Math.round(totalExpense * 100) / 100,
          balance: Math.round((totalIncome - totalExpense) * 100) / 100
        },
        privacyEnabled: girl.finance_privacy_enabled === 1,
        secure: !hideAmount
      }
    });
  } catch (err) {
    console.error('获取账单失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== POST /api/admin/push — 手动推送消息 ====================
router.post('/push', async (req, res) => {
  try {
    const girl = await getGirlUser();
    if (!girl) return res.status(400).json({ code: 400, message: '女友账号不存在' });

    const { type, title, content } = req.body;
    if (!type || !title || !content) {
      return res.status(400).json({ code: 400, message: '请填写消息类型、标题和内容' });
    }

    const [result] = await pool.query(
      'INSERT INTO push_messages (user_id, type, title, content, is_read) VALUES (?, ?, ?, ?, 0)',
      [girl.id, type, title, content]
    );

    res.json({ code: 200, message: '推送成功', data: { id: result.insertId } });
  } catch (err) {
    console.error('推送消息失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== POST /api/admin/quotes/batch — 批量导入情话 ====================
router.post('/quotes/batch', async (req, res) => {
  try {
    const { quotes } = req.body;
    if (!quotes || !Array.isArray(quotes) || quotes.length === 0) {
      return res.status(400).json({ code: 400, message: '请提供情话列表' });
    }

    let imported = 0;
    for (const q of quotes) {
      if (q.content) {
        await pool.query(
          'INSERT INTO daily_quotes (content, source, is_custom, created_by) VALUES (?, ?, 1, ?)',
          [q.content, q.source || '男友专属', req.user.id]
        );
        imported++;
      }
    }

    res.json({ code: 200, message: `成功导入 ${imported} 条情话`, data: { imported } });
  } catch (err) {
    console.error('批量导入情话失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== POST /api/admin/foods/batch — 批量导入食物 ====================
router.post('/foods/batch', async (req, res) => {
  try {
    const { foods } = req.body;
    if (!foods || !Array.isArray(foods) || foods.length === 0) {
      return res.status(400).json({ code: 400, message: '请提供食物列表' });
    }

    let imported = 0;
    for (const f of foods) {
      if (f.name && f.category && f.caloriesPer100g !== undefined) {
        await pool.query(
          'INSERT INTO food_library (name, category, calories_per_100g, is_custom, created_by) VALUES (?, ?, ?, 1, ?)',
          [f.name, f.category, f.caloriesPer100g, req.user.id]
        );
        imported++;
      }
    }

    res.json({ code: 200, message: `成功导入 ${imported} 种食物`, data: { imported } });
  } catch (err) {
    console.error('批量导入食物失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== POST /api/admin/courses/batch — 批量导入课程（给 girl 用户） ====================
router.post('/courses/batch', async (req, res) => {
  try {
    const girl = await getGirlUser();
    if (!girl) return res.status(400).json({ code: 400, message: '女友账号不存在' });

    const { courses } = req.body;
    if (!courses || !Array.isArray(courses) || courses.length === 0) {
      return res.status(400).json({ code: 400, message: '请提供课程列表' });
    }

    let imported = 0;
    for (const c of courses) {
      if (c.courseName && c.dayOfWeek !== undefined && c.startTime && c.endTime) {
        await pool.query(
          `INSERT INTO courses (user_id, course_name, teacher, classroom, day_of_week, start_time, end_time, week_type, start_week, end_week, color, version)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)`,
          [
            girl.id,
            c.courseName,
            c.teacher || '',
            c.classroom || '',
            c.dayOfWeek,
            c.startTime,
            c.endTime,
            c.weekType || 'every',
            c.startWeek || 1,
            c.endWeek || 20,
            c.color || '#409EFF'
          ]
        );
        imported++;
      }
    }

    res.json({ code: 200, message: `成功导入 ${imported} 门课程`, data: { imported } });
  } catch (err) {
    console.error('批量导入课程失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== POST /api/admin/photo — 上传共享相册照片（multer 单文件） ====================
router.post('/photo', upload.single('photo'), async (req, res) => {
  try {
    const girl = await getGirlUser();
    if (!girl) return res.status(400).json({ code: 400, message: '女友账号不存在' });

    if (!req.file) {
      return res.status(400).json({ code: 400, message: '请选择照片' });
    }

    const { category, description } = req.body;
    const relativePath = path.relative(path.join(__dirname, '..'), req.file.path);
    const url = '/' + relativePath.replace(/\\/g, '/');

    const [result] = await pool.query(
      'INSERT INTO photos (user_id, url, thumbnail_url, category, visibility, description, is_bg) VALUES (?, ?, ?, ?, ?, ?, 0)',
      [girl.id, url, url, category || 'couple', 'shared', description || '']
    );

    res.json({ code: 200, message: '上传成功', data: { id: result.insertId, url } });
  } catch (err) {
    // 上传失败时清理文件
    if (req.file && fs.existsSync(req.file.path)) {
      try { fs.unlinkSync(req.file.path); } catch (e) { /* ignore */ }
    }
    console.error('上传照片失败:', err);
    res.status(500).json({ code: 500, message: '上传失败' });
  }
});

// ==================== GET /api/admin/splash — 获取当前启动页配置 ====================
router.get('/splash', async (req, res) => {
  try {
    const [configs] = await pool.query(
      'SELECT * FROM splash_config WHERE is_active = 1 LIMIT 1'
    );

    if (configs.length === 0) {
      return res.json({ code: 200, data: { imageUrl: '', title: 'LoveGirl', subtitle: '只为特别的你' } });
    }

    const config = configs[0];
    res.json({
      code: 200,
      data: {
        id: config.id,
        imageUrl: config.image_url,
        title: config.title,
        subtitle: config.subtitle,
        isActive: !!config.is_active,
        createdAt: config.created_at,
        updatedAt: config.updated_at
      }
    });
  } catch (err) {
    console.error('获取启动页配置失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== PUT /api/admin/splash — 修改启动页 ====================
router.put('/splash', async (req, res) => {
  try {
    const { imageUrl, title, subtitle } = req.body;

    // 查询当前激活的启动页配置
    const [existing] = await pool.query('SELECT id FROM splash_config WHERE is_active = 1 LIMIT 1');

    if (existing.length > 0) {
      // 更新现有配置
      const updates = {};
      if (imageUrl !== undefined) updates.image_url = imageUrl;
      if (title !== undefined) updates.title = title;
      if (subtitle !== undefined) updates.subtitle = subtitle;

      if (Object.keys(updates).length === 0) {
        return res.status(400).json({ code: 400, message: '没有要更新的字段' });
      }

      await pool.query('UPDATE splash_config SET ? WHERE id = ?', [updates, existing[0].id]);
    } else {
      // 创建新配置
      await pool.query(
        'INSERT INTO splash_config (image_url, title, subtitle, is_active) VALUES (?, ?, ?, 1)',
        [imageUrl || '', title || 'LoveGirl', subtitle || '只为特别的你']
      );
    }

    res.json({ code: 200, message: '启动页更新成功' });
  } catch (err) {
    console.error('更新启动页失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== GET /api/admin/boyfriend-status — 获取男友状态 ====================
router.get('/boyfriend-status', authRequired, async (req, res) => {
  try {
    // 查询 boyfriend_status 表
    const [statuses] = await pool.query(
      'SELECT * FROM boyfriend_status WHERE user_id = ?',
      [req.user.id]
    );

    // 同时查询 boy 用户的基本信息
    const [boys] = await pool.query(
      "SELECT id, nickname, avatar_url, love_start_date FROM users WHERE role = 'boy' LIMIT 1"
    );

    const boy = boys.length > 0 ? boys[0] : null;

    let statusData = {
      status: 'online',
      statusText: '陪伴中'
    };

    if (statuses.length > 0) {
      statusData = {
        status: statuses[0].status,
        statusText: statuses[0].status_text || '陪伴中',
        updatedAt: statuses[0].updated_at
      };
    }

    res.json({
      code: 200,
      data: {
        ...statusData,
        id: boy ? boy.id : null,
        nickname: boy ? boy.nickname : '男友',
        avatarUrl: boy ? boy.avatar_url : null,
        loveStartDate: boy ? boy.love_start_date : null
      }
    });
  } catch (err) {
    console.error('获取男友状态失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== PUT /api/admin/boyfriend-status — 更新男友状态 ====================
router.put('/boyfriend-status', authRequired, async (req, res) => {
  try {
    const { status, statusText } = req.body;

    if (!status || !['busy', 'missing', 'traveling', 'offline', 'online'].includes(status)) {
      return res.status(400).json({ code: 400, message: '无效的状态值' });
    }

    // 更新或插入 boyfriend_status
    const [existing] = await pool.query(
      'SELECT id FROM boyfriend_status WHERE user_id = ?',
      [req.user.id]
    );

    if (existing.length > 0) {
      await pool.query(
        'UPDATE boyfriend_status SET status = ?, status_text = ? WHERE user_id = ?',
        [status, statusText || '', req.user.id]
      );
    } else {
      await pool.query(
        'INSERT INTO boyfriend_status (user_id, status, status_text) VALUES (?, ?, ?)',
        [req.user.id, status, statusText || '']
      );
    }

    res.json({
      code: 200,
      message: '状态更新成功',
      data: { status, statusText: statusText || '' }
    });
  } catch (err) {
    console.error('更新男友状态失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== GET /api/admin/quotes — 获取情话列表（分页） ====================
router.get('/quotes', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const size = parseInt(req.query.size) || 20;
    const offset = (page - 1) * size;

    const [quotes] = await pool.query(
      'SELECT * FROM daily_quotes ORDER BY created_at DESC LIMIT ? OFFSET ?',
      [size, offset]
    );

    const [totalResult] = await pool.query('SELECT COUNT(*) as total FROM daily_quotes');

    res.json({
      code: 200,
      data: {
        list: quotes,
        total: totalResult[0].total,
        page,
        size
      }
    });
  } catch (err) {
    console.error('获取情话列表失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== GET /api/admin/users — 获取用户列表 ====================
router.get('/users', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const size = parseInt(req.query.size) || 20;
    const offset = (page - 1) * size;

    const [users] = await pool.query(
      'SELECT id, username, nickname, role, avatar_url, tagline, love_start_date, created_at FROM users ORDER BY created_at DESC LIMIT ? OFFSET ?',
      [size, offset]
    );

    const [totalResult] = await pool.query('SELECT COUNT(*) as total FROM users');

    res.json({
      code: 200,
      data: {
        list: users.map(u => ({
          id: u.id,
          username: u.username,
          nickname: u.nickname,
          role: u.role,
          avatarUrl: u.avatar_url,
          tagline: u.tagline,
          loveStartDate: u.love_start_date,
          createdAt: u.created_at
        })),
        total: totalResult[0].total,
        page,
        size
      }
    });
  } catch (err) {
    console.error('获取用户列表失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== PUT /api/admin/users/:id — 更新用户 ====================
router.put('/users/:id', async (req, res) => {
  try {
    const { role, nickname, tagline } = req.body;
    const updates = {};

    if (role !== undefined) updates.role = role;
    if (nickname !== undefined) updates.nickname = nickname;
    if (tagline !== undefined) updates.tagline = tagline;

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ code: 400, message: '没有要更新的字段' });
    }

    const [result] = await pool.query('UPDATE users SET ? WHERE id = ?', [updates, req.params.id]);

    if (result.affectedRows === 0) {
      return res.status(404).json({ code: 404, message: '用户不存在' });
    }

    res.json({ code: 200, message: '更新成功' });
  } catch (err) {
    console.error('更新用户失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== GET /api/admin/backups — 获取备份列表 ====================
router.get('/backups', async (req, res) => {
  try {
    const [backups] = await pool.query(
      'SELECT * FROM data_backups ORDER BY created_at DESC LIMIT 20'
    );

    res.json({
      code: 200,
      data: backups.map(b => ({
        id: b.id,
        backupType: b.backup_type,
        fileSize: b.file_size,
        recordCount: b.record_count,
        createdAt: b.created_at
      }))
    });
  } catch (err) {
    console.error('获取备份列表失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== PUT /api/admin/quotes/:id — 编辑情话 ====================
router.put('/quotes/:id', async (req, res) => {
  try {
    const { content, author, source, type } = req.body;
    const updates = []; const params = [];
    if (content !== undefined) { updates.push('content=?'); params.push(content); }
    if (author !== undefined) { updates.push('source=?'); params.push(author); }
    else if (source !== undefined) { updates.push('source=?'); params.push(source); }
    if (type !== undefined) { updates.push('type=?'); params.push(type); }
    if (updates.length === 0) return res.status(400).json({ code: 400, message: '没有要更新的字段' });
    params.push(req.params.id);
    await pool.query(`UPDATE daily_quotes SET ${updates.join(',')} WHERE id=?`, params);
    res.json({ code: 200, message: '更新成功' });
  } catch (err) {
    console.error('编辑情话失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== DELETE /api/admin/quotes/:id — 删除情话 ====================
router.delete('/quotes/:id', async (req, res) => {
  try {
    const [result] = await pool.query('DELETE FROM daily_quotes WHERE id = ?', [req.params.id]);

    if (result.affectedRows === 0) {
      return res.status(404).json({ code: 404, message: '情话不存在' });
    }

    res.json({ code: 200, message: '删除成功' });
  } catch (err) {
    console.error('删除情话失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== DELETE /api/admin/users/:id — 删除用户 ====================
router.delete('/users/:id', async (req, res) => {
  try {
    // 检查是否为管理员用户，禁止删除
    const [users] = await pool.query('SELECT is_admin FROM users WHERE id = ?', [req.params.id]);
    if (users.length === 0) {
      return res.status(404).json({ code: 404, message: '用户不存在' });
    }
    if (users[0].is_admin === 1) {
      return res.status(403).json({ code: 403, message: '禁止删除管理员用户' });
    }
    await pool.query('DELETE FROM users WHERE id = ?', [req.params.id]);
    res.json({ code: 200, message: '删除成功' });
  } catch (err) {
    console.error('删除用户失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== DELETE /api/admin/backups/:id — 删除备份记录 ====================
router.delete('/backups/:id', async (req, res) => {
  try {
    const [result] = await pool.query('DELETE FROM database_backups WHERE id = ?', [req.params.id]);
    if (result.affectedRows === 0) {
      return res.status(404).json({ code: 404, message: '备份记录不存在' });
    }
    res.json({ code: 200, message: '删除成功' });
  } catch (err) {
    console.error('删除备份记录失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
