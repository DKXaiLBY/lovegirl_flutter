// 课程表路由：管理课程信息，支持 Excel 批量导入
const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const xlsx = require('xlsx');
const multer = require('multer');
const path = require('path');
const { authRequired } = require('../middleware/auth');

// multer 配置：用于 Excel 文件上传
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, path.join(__dirname, '..', 'uploads')),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `course-${Date.now()}-${Math.random().toString(36).substr(2, 9)}${ext}`);
  }
});
const upload = multer({ storage, limits: { fileSize: 5 * 1024 * 1024 } });

// GET /api/course - 获取所有课程（按 day_of_week, start_time 排序）
router.get('/', authRequired, async (req, res) => {
  try {
    const [courses] = await pool.query(
      'SELECT * FROM courses WHERE user_id = ? ORDER BY day_of_week ASC, start_time ASC',
      [req.user.id]
    );

    const data = courses.map(c => ({
      id: c.id,
      courseName: c.course_name,
      teacher: c.teacher,
      classroom: c.classroom,
      dayOfWeek: c.day_of_week,
      startTime: c.start_time,
      endTime: c.end_time,
      weekType: c.week_type,
      startWeek: c.start_week,
      endWeek: c.end_week,
      color: c.color,
      version: c.version
    }));

    res.json({ code: 200, data });
  } catch (err) {
    console.error('获取课程列表失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// POST /api/course - 添加课程
router.post('/', authRequired, async (req, res) => {
  try {
    // 同时支持驼峰和下划线命名（前端可能传任意一种）
    const courseName = req.body.courseName || req.body.course_name || '';
    const teacher = req.body.teacher || '';
    const classroom = req.body.classroom || '';
    const dayOfWeek = req.body.dayOfWeek !== undefined ? req.body.dayOfWeek : req.body.day_of_week;
    const startTime = req.body.startTime || req.body.start_time || '';
    const endTime = req.body.endTime || req.body.end_time || '';
    const weekType = req.body.weekType || req.body.week_type || 'every';
    const startWeek = req.body.startWeek !== undefined ? req.body.startWeek : (req.body.start_week || 1);
    const endWeek = req.body.endWeek !== undefined ? req.body.endWeek : (req.body.end_week || 20);
    const color = req.body.color || '#409EFF';

    if (!courseName || dayOfWeek == null || !startTime || !endTime) {
      return res.status(400).json({ code: 400, message: '请填写课程名称、星期和时间' });
    }

    const [result] = await pool.query(
      `INSERT INTO courses (user_id, course_name, teacher, classroom, day_of_week, start_time, end_time, week_type, start_week, end_week, color, version)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)`,
      [
        req.user.id,
        courseName,
        teacher || '',
        classroom || '',
        dayOfWeek,
        startTime,
        endTime,
        weekType || 'every',
        startWeek || 1,
        endWeek || 20,
        color || '#409EFF'
      ]
    );

    res.json({ code: 200, message: '添加成功', data: { id: result.insertId } });
  } catch (err) {
    console.error('添加课程失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// POST /api/course/import - Excel 导入课程
// 期望 Excel 格式：课程名称 | 教师 | 教室 | 星期 | 开始时间 | 结束时间 | 单双周 | 起始周 | 结束周
router.post('/import', authRequired, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ code: 400, message: '请上传Excel文件' });
    }

    // 读取 Excel 文件
    const workbook = xlsx.readFile(req.file.path);
    const sheetName = workbook.SheetNames[0];
    const sheet = workbook.Sheets[sheetName];
    const rows = xlsx.utils.sheet_to_json(sheet, { header: 1 });

    if (rows.length < 2) {
      return res.status(400).json({ code: 400, message: 'Excel文件为空或格式不正确' });
    }

    let imported = 0;
    let skipped = 0;

    // 跳过表头，从第2行开始
    for (let i = 1; i < rows.length; i++) {
      const row = rows[i];
      if (!row || !row[0]) continue; // 跳过空行

      const courseName = String(row[0] || '').trim();
      const teacher = String(row[1] || '').trim();
      const classroom = String(row[2] || '').trim();
      const dayOfWeek = parseInt(row[3]) || 1;
      const startTime = String(row[4] || '').trim();
      const endTime = String(row[5] || '').trim();
      const weekType = String(row[6] || 'every').trim();
      const startWeek = parseInt(row[7]) || 1;
      const endWeek = parseInt(row[8]) || 20;

      if (!courseName || !startTime || !endTime) {
        skipped++;
        continue;
      }

      // 映射单双周
      let weekTypeMapped = 'every';
      if (weekType.includes('单')) weekTypeMapped = 'odd';
      if (weekType.includes('双')) weekTypeMapped = 'even';

      try {
        await pool.query(
          `INSERT INTO courses (user_id, course_name, teacher, classroom, day_of_week, start_time, end_time, week_type, start_week, end_week, color, version)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)`,
          [
            req.user.id,
            courseName,
            teacher,
            classroom,
            dayOfWeek,
            startTime,
            endTime,
            weekTypeMapped,
            startWeek,
            endWeek,
            '#409EFF'
          ]
        );
        imported++;
      } catch (e) {
        console.error('导入课程行失败:', e.message);
        skipped++;
      }
    }

    res.json({
      code: 200,
      message: `导入完成：成功 ${imported} 条，跳过 ${skipped} 条`,
      data: { imported, skipped }
    });
  } catch (err) {
    console.error('Excel导入课程失败:', err);
    res.status(500).json({ code: 500, message: '导入失败，请检查Excel格式' });
  }
});

// PUT /api/course/:id - 更新课程
router.put('/:id', authRequired, async (req, res) => {
  try {
    // 同时支持驼峰和下划线命名
    const courseName = req.body.courseName !== undefined ? req.body.courseName : req.body.course_name;
    const teacher = req.body.teacher;
    const classroom = req.body.classroom;
    const dayOfWeek = req.body.dayOfWeek !== undefined ? req.body.dayOfWeek : req.body.day_of_week;
    const startTime = req.body.startTime !== undefined ? req.body.startTime : req.body.start_time;
    const endTime = req.body.endTime !== undefined ? req.body.endTime : req.body.end_time;
    const weekType = req.body.weekType !== undefined ? req.body.weekType : req.body.week_type;
    const startWeek = req.body.startWeek !== undefined ? req.body.startWeek : req.body.start_week;
    const endWeek = req.body.endWeek !== undefined ? req.body.endWeek : req.body.end_week;
    const color = req.body.color;

    const updates = {};
    if (courseName !== undefined) updates.course_name = courseName;
    if (teacher !== undefined) updates.teacher = teacher;
    if (classroom !== undefined) updates.classroom = classroom;
    if (dayOfWeek !== undefined) updates.day_of_week = dayOfWeek;
    if (startTime !== undefined) updates.start_time = startTime;
    if (endTime !== undefined) updates.end_time = endTime;
    if (weekType !== undefined) updates.week_type = weekType;
    if (startWeek !== undefined) updates.start_week = startWeek;
    if (endWeek !== undefined) updates.end_week = endWeek;
    if (color !== undefined) updates.color = color;

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ code: 400, message: '没有要更新的字段' });
    }

    await pool.query(
      'UPDATE courses SET ?, version = version + 1 WHERE id = ? AND user_id = ?',
      [updates, req.params.id, req.user.id]
    );

    res.json({ code: 200, message: '更新成功' });
  } catch (err) {
    console.error('更新课程失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// DELETE /api/course/:id - 删除课程
router.delete('/:id', authRequired, async (req, res) => {
  try {
    await pool.query('DELETE FROM courses WHERE id = ? AND user_id = ?', [req.params.id, req.user.id]);
    res.json({ code: 200, message: '删除成功' });
  } catch (err) {
    console.error('删除课程失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// GET /api/course/status — 获取当前上课状态（含下节课信息）
router.get('/status', authRequired, async (req, res) => {
  try {
    const now = new Date();
    // 星期几：JS getDay() 返回 0(周日)~6(周六)，映射为 1(周一)~7(周日)
    const jsDay = now.getDay();
    const dayOfWeek = jsDay === 0 ? 7 : jsDay;
    const currentTime = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;

    // 查询当前时间是否在上课
    const [courses] = await pool.query(
      'SELECT course_name, teacher, classroom, start_time, end_time, color FROM courses WHERE user_id = ? AND day_of_week = ? AND start_time <= ? AND end_time > ? ORDER BY start_time ASC LIMIT 1',
      [req.user.id, dayOfWeek, currentTime, currentTime]
    );

    if (courses.length > 0) {
      // 正在上课中
      const c = courses[0];
      return res.json({
        code: 200,
        data: {
          inClass: true,
          courseName: c.course_name,
          teacher: c.teacher,
          classroom: c.classroom,
          endTime: c.end_time,
          color: c.color
        }
      });
    }

    // 不在上课，查询下一节课（今天之后的时间或以后的星期）
    const [nextCourses] = await pool.query(
      `SELECT course_name, teacher, classroom, start_time, end_time, day_of_week, color
       FROM courses
       WHERE user_id = ?
       AND (
         (day_of_week = ? AND start_time > ?)
         OR day_of_week > ?
       )
       ORDER BY day_of_week ASC, start_time ASC
       LIMIT 1`,
      [req.user.id, dayOfWeek, currentTime, dayOfWeek]
    );

    // 如果今天后面没课，查下周
    let nextCourse = null;
    if (nextCourses.length > 0) {
      const nc = nextCourses[0];
      // 计算下节课是星期几的文本
      const weekDayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      const nextDayLabel = nc.day_of_week === dayOfWeek ? '今天' : weekDayNames[nc.day_of_week];
      nextCourse = {
        courseName: nc.course_name,
        startTime: nc.start_time,
        endTime: nc.end_time,
        teacher: nc.teacher,
        classroom: nc.classroom,
        dayOfWeek: nc.day_of_week,
        dayLabel: nextDayLabel,
        color: nc.color
      };
    } else {
      // 检查下周一的课程
      const [mondayCourses] = await pool.query(
        'SELECT course_name, start_time, end_time, teacher, classroom, color FROM courses WHERE user_id = ? ORDER BY day_of_week ASC, start_time ASC LIMIT 1',
        [req.user.id]
      );
      if (mondayCourses.length > 0) {
        const mc = mondayCourses[0];
        nextCourse = {
          courseName: mc.course_name,
          startTime: mc.start_time,
          endTime: mc.end_time,
          teacher: mc.teacher,
          classroom: mc.classroom,
          dayOfWeek: 1,
          dayLabel: '下周',
          color: mc.color
        };
      }
    }

    res.json({
      code: 200,
      data: { inClass: false, nextCourse }
    });
  } catch (err) {
    console.error('获取上课状态失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// GET /api/course/shared — 获取对方共享的课程
router.get('/shared', authRequired, async (req, res) => {
  try {
    if (req.user.role !== 'boy' && req.user.role !== 'girl') {
      return res.json({ code: 200, data: [] });
    }
    // 找对方
    const partnerRole = req.user.role === 'girl' ? 'boy' : 'girl';
    const [partners] = await pool.query("SELECT id FROM users WHERE role=? AND is_admin=0 LIMIT 1", [partnerRole]);
    if (partners.length === 0) return res.json({ code: 200, data: [] });

    // 直接返回对方课程（无需 settings 列，同行情侣默认共享）
    const [courses] = await pool.query('SELECT * FROM courses WHERE user_id=? ORDER BY day_of_week, start_time', [partners[0].id]);
    res.json({ code: 200, data: courses, sharedBy: partnerRole });
  } catch (err) { res.status(500).json({ code: 500, message: '服务器错误' }); }
});

module.exports = router;
