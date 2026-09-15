// 姨妈助手路由（敏感数据加密存储）
// v2.15 重构：经期手动标记 + 痛经独立记录
const express = require('express');
const router = express.Router();
const pool = require('../config/database');
const { encrypt, decrypt } = require('../config/encrypt');
const { authRequired } = require('../middleware/auth');

// ==================== 辅助函数 ====================

function mapRecord(r) {
  const startDate = decrypt(r.start_date_encrypted);
  const endDate = r.end_date_encrypted ? decrypt(r.end_date_encrypted) : null;
  const painLevel = r.pain_level_encrypted ? parseInt(decrypt(r.pain_level_encrypted)) : 0;
  const symptoms = r.symptoms_encrypted ? JSON.parse(decrypt(r.symptoms_encrypted)) : [];
  // 从 notes_encrypted 解析 flowData（血量/颜色）
  let flowData = null;
  let notesText = r.notes_encrypted ? decrypt(r.notes_encrypted) : '';
  try {
    const parsed = JSON.parse(notesText);
    if (parsed && typeof parsed === 'object' && (parsed.flowLevel || parsed.flowColor)) {
      flowData = { flowLevel: parsed.flowLevel || 0, flowColor: parsed.flowColor || '' };
      notesText = parsed.note || parsed.notes || '';
    }
  } catch { /* notes 不是 JSON，保持原文本 */ }
  return {
    id: r.id,
    startDate,
    endDate,
    cycleDays: parseInt(decrypt(r.cycle_days_encrypted)) || 28,
    durationDays: parseInt(decrypt(r.duration_days_encrypted)) || 5,
    painLevel,
    symptoms,
    medicine: r.medicine_encrypted ? decrypt(r.medicine_encrypted) : '',
    notes: notesText,
    flowData,
    isCycle: painLevel === 0 && symptoms.length === 0,   // 纯经期记录（无痛经数据）
    isPain: painLevel > 0 || symptoms.length > 0,         // 含痛经数据
    isOngoing: !endDate && painLevel === 0 && symptoms.length === 0, // 进行中的经期
    createdAt: r.created_at,
    updatedAt: r.updated_at
  };
}

// 计算阶段 (周期天数用平均值)
function calcPhase(startDate, endDate, avgCycle, avgDuration) {
  const today = new Date(); today.setHours(0,0,0,0);
  const start = new Date(startDate); start.setHours(0,0,0,0);

  // 有进行中的经期（没有 endDate）
  if (!endDate) {
    const dayInPeriod = Math.floor((today - start) / 86400000) + 1;
    return { phaseKey: 'menstrual', label: '经期中', emoji: '🌸', color: 'red',
      subText: `经期第 ${dayInPeriod} 天`, isPeriod: true, dayInPeriod };
  }

  const end = new Date(endDate); end.setHours(0,0,0,0);
  // 如果今天还在经期范围内（endDate 是今天或今天之前）
  if (today >= start && today <= end) {
    const dayInPeriod = Math.floor((today - start) / 86400000) + 1;
    return { phaseKey: 'menstrual', label: '经期中', emoji: '🌸', color: 'red',
      subText: `经期第 ${dayInPeriod} 天`, isPeriod: true, dayInPeriod };
  }

  // 不在经期 → 计算预测
  const cycle = avgCycle || 28;
  const nextStart = new Date(start);
  nextStart.setDate(nextStart.getDate() + cycle);
  // 找到 first future start after end
  while (nextStart <= end) { nextStart.setDate(nextStart.getDate() + cycle); }
  while (nextStart <= today) { nextStart.setDate(nextStart.getDate() + cycle); }

  const daysUntil = Math.ceil((nextStart - today) / 86400000);
  const ovulationDay = new Date(nextStart); ovulationDay.setDate(ovulationDay.getDate() - 14);

  if (daysUntil <= 3 && daysUntil > 0) {
    return { phaseKey: 'luteal', label: '经期临近', emoji: '🌙', color: 'orange',
      subText: `预计 ${daysUntil} 天后来访`, isPeriod: false, daysUntil };
  }
  if (daysUntil >= 11 && daysUntil <= 16) {
    return { phaseKey: 'ovulation', label: '排卵期', emoji: '✨', color: 'blue',
      subText: '受孕高峰期', isPeriod: false, daysUntil };
  }
  return { phaseKey: 'safe', label: '安全期', emoji: '🛡', color: 'safe',
    subText: daysUntil > 16 ? '卵泡期·身体状态良好' : '黄体期·注意保养', isPeriod: false, daysUntil };
}

// ==================== GET /api/period — 获取全部记录 ====================
router.get('/', authRequired, async (req, res) => {
  try {
    const [records] = await pool.query(
      'SELECT * FROM period_records WHERE user_id = ? ORDER BY updated_at DESC',
      [req.user.id]
    );
    const data = records.map(mapRecord);
    res.json({ code: 200, data });
  } catch (err) {
    console.error('获取经期记录失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== GET /api/period/status — 当前经期状态 ====================
router.get('/status', authRequired, async (req, res) => {
  try {
    // 查找进行中的经期（最新一条没有 end_date 的纯经期记录）
    const [ongoing] = await pool.query(
      'SELECT * FROM period_records WHERE user_id = ? AND end_date_encrypted IS NULL AND pain_level_encrypted IS NULL AND symptoms_encrypted IS NULL ORDER BY created_at DESC LIMIT 1',
      [req.user.id]
    );

    // 获取历史已完成经期用于计算平均值
    const [history] = await pool.query(
      'SELECT * FROM period_records WHERE user_id = ? AND end_date_encrypted IS NOT NULL AND pain_level_encrypted IS NULL AND symptoms_encrypted IS NULL ORDER BY created_at DESC',
      [req.user.id]
    );

    let avgCycle = 28, avgDuration = 5;
    if (history.length >= 1) {
      // 从已完成经期计算实际平均值
      const durations = [];
      for (let i = 0; i < history.length; i++) {
        const s = new Date(decrypt(history[i].start_date_encrypted));
        const e = new Date(decrypt(history[i].end_date_encrypted));
        const dur = Math.ceil((e - s) / 86400000) + 1;
        if (dur > 0 && dur < 15) durations.push(dur);
      }
      if (durations.length > 0) {
        avgDuration = Math.round(durations.reduce((a,b)=>a+b,0) / durations.length);
      }
      // 周期 = 相邻两次开始日期的平均间隔
      if (history.length >= 2) {
        const intervals = [];
        for (let i = 0; i < history.length - 1; i++) {
          const s1 = new Date(decrypt(history[i].start_date_encrypted));
          const s2 = new Date(decrypt(history[i+1].start_date_encrypted));
          const interval = Math.abs(Math.round((s1 - s2) / 86400000));
          if (interval > 15 && interval < 60) intervals.push(interval);
        }
        if (intervals.length > 0) {
          avgCycle = Math.round(intervals.reduce((a,b)=>a+b,0) / intervals.length);
        }
      }
    }

    let phase = null;
    if (ongoing.length > 0) {
      const r = ongoing[0];
      const startDate = decrypt(r.start_date_encrypted);
      phase = calcPhase(startDate, null, avgCycle, avgDuration);
    } else if (history.length > 0) {
      // 用最近一次经期计算预测
      const lastStart = decrypt(history[0].start_date_encrypted);
      const lastEnd = decrypt(history[0].end_date_encrypted);
      phase = calcPhase(lastStart, lastEnd, avgCycle, avgDuration);
    }

    res.json({
      code: 200,
      data: {
        hasRecord: ongoing.length > 0 || history.length > 0,
        isInPeriod: phase?.isPeriod || false,
        phase,
        avgCycle,
        avgDuration,
        cycleCount: history.length + (ongoing.length > 0 ? 1 : 0),
        // 预测下次经期（基于最近一次经期+平均周期）
        nextPeriod: phase?.daysUntil ? new Date(Date.now() + phase.daysUntil * 86400000).toISOString().split('T')[0] : null
      }
    });
  } catch (err) {
    console.error('获取经期状态失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== POST /api/period/start — 标记经期开始 ====================
router.post('/start', authRequired, async (req, res) => {
  try {
    // 检查是否已有进行中的经期
    const [ongoing] = await pool.query(
      'SELECT id FROM period_records WHERE user_id = ? AND end_date_encrypted IS NULL AND pain_level_encrypted IS NULL AND symptoms_encrypted IS NULL',
      [req.user.id]
    );
    if (ongoing.length > 0) {
      return res.status(400).json({ code: 400, message: '已有进行中的经期，请先标记结束' });
    }

    const date = req.body.date || new Date().toISOString().split('T')[0];
    const [lastRec] = await pool.query(
      'SELECT cycle_days_encrypted, duration_days_encrypted FROM period_records WHERE user_id = ? ORDER BY updated_at DESC LIMIT 1',
      [req.user.id]
    );
    const cycle = lastRec.length > 0 ? decrypt(lastRec[0].cycle_days_encrypted) : '28';
    const duration = lastRec.length > 0 ? decrypt(lastRec[0].duration_days_encrypted) : '5';

    await pool.query(
      'INSERT INTO period_records (user_id, start_date_encrypted, end_date_encrypted, cycle_days_encrypted, duration_days_encrypted) VALUES (?, ?, NULL, ?, ?)',
      [req.user.id, encrypt(date), encrypt(cycle), encrypt(duration)]
    );
    res.json({ code: 200, message: '已记录经期开始 🌸', data: { date } });
  } catch (err) {
    console.error('标记经期开始失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== POST /api/period/end — 标记经期结束 ====================
router.post('/end', authRequired, async (req, res) => {
  try {
    const [ongoing] = await pool.query(
      'SELECT id, start_date_encrypted FROM period_records WHERE user_id = ? AND end_date_encrypted IS NULL AND pain_level_encrypted IS NULL AND symptoms_encrypted IS NULL ORDER BY created_at DESC LIMIT 1',
      [req.user.id]
    );
    if (ongoing.length === 0) {
      return res.status(400).json({ code: 400, message: '没有进行中的经期' });
    }

    const date = req.body.date || new Date().toISOString().split('T')[0];
    await pool.query(
      'UPDATE period_records SET end_date_encrypted = ? WHERE id = ? AND user_id = ?',
      [encrypt(date), ongoing[0].id, req.user.id]
    );

    // 计算实际持续天数，更新 duration_days_encrypted
    const startDate = new Date(decrypt(ongoing[0].start_date_encrypted));
    const endDate = new Date(date);
    const actualDuration = Math.ceil((endDate - startDate) / 86400000) + 1;
    if (actualDuration >= 1 && actualDuration <= 15) {
      await pool.query(
        'UPDATE period_records SET duration_days_encrypted = ? WHERE id = ?',
        [encrypt(String(actualDuration)), ongoing[0].id]
      );
    }

    res.json({ code: 200, message: '已记录经期结束，好好休息~', data: { duration: actualDuration } });
  } catch (err) {
    console.error('标记经期结束失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== POST /api/period — 保存痛经记录 ====================
router.post('/', authRequired, async (req, res) => {
  try {
    const body = req.body;
    const hasPain = body.painLevel !== undefined || body.symptoms || body.medicine || body.notes || body.note;

    if (!hasPain) {
      // 周期设置更新
      const fields = {};
      if (body.startDate || body.lastStart) {
        fields.start_date_encrypted = encrypt(body.startDate || body.lastStart);
      }
      if (body.cycleDays !== undefined) fields.cycle_days_encrypted = encrypt(String(body.cycleDays));
      if (body.durationDays !== undefined) fields.duration_days_encrypted = encrypt(String(body.durationDays));

      if (Object.keys(fields).length > 0) {
        const [existing] = await pool.query(
          'SELECT id FROM period_records WHERE user_id = ? ORDER BY updated_at DESC LIMIT 1',
          [req.user.id]
        );
        if (existing.length > 0) {
          await pool.query('UPDATE period_records SET ? WHERE id = ?', [fields, existing[0].id]);
        }
      }
      return res.json({ code: 200, message: '已保存' });
    }

    // 痛经记录 → 每次创建新记录
    const painLevel = body.painLevel !== undefined ? encrypt(String(body.painLevel)) : null;
    const symptoms = body.symptoms ? encrypt(JSON.stringify(body.symptoms)) : null;
    const medicine = body.medicine ? encrypt(body.medicine) : null;
    // 合并 notes/flowLevel/flowColor 为 JSON 后加密
    const hasFlow = body.flowLevel !== undefined || body.flowColor !== undefined;
    const noteText = body.notes || body.note || '';
    let note = null;
    if (hasFlow || noteText) {
      const noteObj = {};
      if (hasFlow) {
        noteObj.flowLevel = body.flowLevel || 0;
        noteObj.flowColor = body.flowColor || '';
      }
      if (noteText) noteObj.note = noteText;
      note = encrypt(JSON.stringify(noteObj));
    }

    // 从已有记录继承周期数据
    const [lastRec] = await pool.query(
      'SELECT start_date_encrypted, cycle_days_encrypted, duration_days_encrypted FROM period_records WHERE user_id = ? ORDER BY updated_at DESC LIMIT 1',
      [req.user.id]
    );
    const defStart = lastRec.length > 0 ? decrypt(lastRec[0].start_date_encrypted) : new Date().toISOString().split('T')[0];
    const defCycle = lastRec.length > 0 ? decrypt(lastRec[0].cycle_days_encrypted) : '28';
    const defDuration = lastRec.length > 0 ? decrypt(lastRec[0].duration_days_encrypted) : '5';

    await pool.query(
      'INSERT INTO period_records (user_id, start_date_encrypted, cycle_days_encrypted, duration_days_encrypted, pain_level_encrypted, symptoms_encrypted, medicine_encrypted, notes_encrypted) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [req.user.id, encrypt(defStart), encrypt(defCycle), encrypt(defDuration), painLevel, symptoms, medicine, note]
    );
    res.json({ code: 200, message: '痛经记录已保存' });
  } catch (err) {
    console.error('保存记录失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== GET /api/period/analysis — 周期分析 ====================
router.get('/analysis', authRequired, async (req, res) => {
  try {
    const [cycles] = await pool.query(
      'SELECT start_date_encrypted, end_date_encrypted FROM period_records WHERE user_id = ? AND end_date_encrypted IS NOT NULL ORDER BY created_at DESC LIMIT 12',
      [req.user.id]
    );
    if (cycles.length === 0) {
      return res.json({ code: 200, data: { count: 0, message: '暂无经期记录' } });
    }

    const durations = [], intervals = [];
    for (const c of cycles) {
      const s = new Date(decrypt(c.start_date_encrypted));
      const e = new Date(decrypt(c.end_date_encrypted));
      durations.push(Math.ceil((e - s) / 86400000) + 1);
    }
    for (let i = 0; i < cycles.length - 1; i++) {
      const s1 = new Date(decrypt(cycles[i].start_date_encrypted));
      const s2 = new Date(decrypt(cycles[i+1].start_date_encrypted));
      intervals.push(Math.abs(Math.round((s1 - s2) / 86400000)));
    }

    res.json({
      code: 200,
      data: {
        count: cycles.length,
        avgCycle: intervals.length > 0 ? Math.round(intervals.reduce((a,b)=>a+b,0) / intervals.length) : 28,
        avgDuration: Math.round(durations.reduce((a,b)=>a+b,0) / durations.length),
        months: cycles.map(c => decrypt(c.start_date_encrypted).slice(0, 7)).reverse(),
        cycles: intervals.reverse(),
        durations: durations.reverse()
      }
    });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== GET /api/period/diet-recommend — 饮食建议 ====================
router.get('/diet-recommend', authRequired, async (req, res) => {
  const DIET_MAP = {
    menstrual: { title: '经期饮食建议', foods: ['红糖姜茶', '热水', '菠菜', '黑巧克力', '坚果', '红枣茶', '桂圆汤'], avoid: ['冰饮', '辛辣', '咖啡', '酒精'] },
    follicular: { title: '卵泡期饮食建议', foods: ['鸡蛋', '鱼肉', '瘦肉', '豆制品', '西兰花', '牛油果'], avoid: [] },
    ovulation: { title: '排卵期饮食建议', foods: ['豆浆', '豆腐', '牡蛎', '南瓜籽', '全麦面包'], avoid: [] },
    luteal: { title: '黄体期饮食建议', foods: ['酸奶', '香蕉', '全谷物', '深色蔬菜', '镁含量高的食物'], avoid: ['高盐食物', '甜食'] },
    safe: { title: '安全期饮食建议', foods: ['均衡饮食', '水果', '蔬菜', '优质蛋白', '多喝水'], avoid: [] },
    pregnancy: { title: '孕期饮食建议', foods: ['叶酸', '铁质食物', '钙质食物', '优质蛋白', '新鲜蔬果', '全谷物', '坚果'], avoid: ['生食', '高汞鱼类', '酒精', '过量咖啡因', '未消毒奶制品'] }
  };
  try {
    const [records] = await pool.query('SELECT * FROM period_records WHERE user_id=? ORDER BY updated_at DESC LIMIT 1', [req.user.id]);
    let phase = 'safe';
    if (records.length > 0) {
      const r = records[0];
      if (!r.end_date_encrypted) phase = 'menstrual';
      else {
        const endDate = new Date(decrypt(r.end_date_encrypted));
        const daysSince = Math.floor((Date.now() - endDate.getTime()) / 86400000);
        if (daysSince <= 5) phase = 'follicular';
        else if (daysSince <= 16) phase = 'ovulation';
        else if (daysSince <= 28) phase = 'luteal';
        else phase = 'safe';
      }
    }
    res.json({ code: 200, data: { phase, ...DIET_MAP[phase] } });
  } catch (err) {
    console.error('获取饮食建议失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== GET /api/period/:id — 单条记录详情 ====================
router.get('/:id', authRequired, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT * FROM period_records WHERE id = ? AND user_id = ?',
      [req.params.id, req.user.id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ code: 404, message: '记录不存在' });
    }
    res.json({ code: 200, data: mapRecord(rows[0]) });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== PUT /api/period/:id — 编辑痛经记录 ====================
router.put('/:id', authRequired, async (req, res) => {
  try {
    const { painLevel, symptoms, medicine, notes } = req.body;
    const updates = []; const params = [];
    if (painLevel !== undefined) { updates.push('pain_level_encrypted=?'); params.push(encrypt(String(painLevel))); }
    if (symptoms !== undefined) { updates.push('symptoms_encrypted=?'); params.push(encrypt(JSON.stringify(symptoms))); }
    if (medicine !== undefined) { updates.push('medicine_encrypted=?'); params.push(encrypt(medicine)); }
    if (notes !== undefined) { updates.push('notes_encrypted=?'); params.push(encrypt(notes)); }
    if (updates.length === 0) return res.status(400).json({ code: 400, message: '没有要更新的字段' });
    params.push(req.params.id, req.user.id);
    await pool.query(`UPDATE period_records SET ${updates.join(',')} WHERE id=? AND user_id=?`, params);
    res.json({ code: 200, message: '更新成功' });
  } catch (err) {
    console.error('编辑痛经记录失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ==================== DELETE /api/period/:id ====================
router.delete('/:id', authRequired, async (req, res) => {
  try {
    const [result] = await pool.query(
      'DELETE FROM period_records WHERE id = ? AND user_id = ?',
      [req.params.id, req.user.id]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ code: 404, message: '记录不存在' });
    }
    res.json({ code: 200, message: '已删除' });
  } catch (err) {
    console.error('删除失败:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});
module.exports = router;
