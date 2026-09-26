const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const pool = require('../config/database');
const {
  todayString,
  getPartnerId,
  addBeanTransaction,
} = require('./utils/lovegirl_rewards');

// 愿望兑换券：A 发行券（标题+豆价）→ B 花豆兑换 → A 现实兑现后标记完成（可拍凭证照）→ B 确认
// 豆的扣减走 addBeanTransaction 负数金额（内部有余额校验+流水）

function cleanText(v, max) {
  const s = String(v ?? '').trim();
  return s.slice(0, max);
}

async function partnerNameOf(partnerId) {
  const [u] = await pool.query('SELECT nickname FROM users WHERE id = ?', [partnerId]);
  return u.length > 0 ? u[0].nickname : null;
}

// ========== 券模板 ==========

// 列表：对方的券（可兑换的）+ 我发行的券
router.get('/list', authRequired, async (req, res) => {
  try {
    const partnerId = await getPartnerId(req.user.id);
    const [mine] = await pool.query(
      `SELECT v.id, v.title, v.cost_bean, v.emoji, v.is_active, v.created_at,
              (SELECT COUNT(*) FROM voucher_redemptions r WHERE r.template_id = v.id) AS redeemed_count
       FROM voucher_templates v
       WHERE v.creator_id = ?
       ORDER BY v.created_at DESC LIMIT 50`,
      [req.user.id]
    );
    let partner = [];
    if (partnerId != null) {
      [partner] = await pool.query(
        `SELECT v.id, v.title, v.cost_bean, v.emoji, v.is_active, v.created_at
         FROM voucher_templates v
         WHERE v.creator_id = ? AND v.is_active = 1
         ORDER BY v.created_at DESC LIMIT 50`,
        [partnerId]
      );
    }
    res.json({
      code: 200,
      data: {
        partnerName: partnerId != null ? await partnerNameOf(partnerId) : null,
        hasPartner: partnerId != null,
        myVouchers: mine,
        partnerVouchers: partner,
      },
    });
  } catch (err) {
    console.error('[Voucher] list failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 发行券
router.post('/', authRequired, async (req, res) => {
  try {
    const title = cleanText(req.body.title, 60);
    const emoji = cleanText(req.body.emoji, 16) || '🎁';
    const cost = parseInt(req.body.costBean);
    if (!title) return res.status(400).json({ code: 400, message: '给券起个名字吧' });
    if (!Number.isInteger(cost) || cost <= 0 || cost > 100000) {
      return res.status(400).json({ code: 400, message: '豆价要是 1-100000 的整数' });
    }
    const [result] = await pool.query(
      'INSERT INTO voucher_templates (creator_id, title, cost_bean, emoji) VALUES (?, ?, ?, ?)',
      [req.user.id, title, cost, emoji]
    );
    res.json({ code: 200, data: { id: result.insertId } });
  } catch (err) {
    console.error('[Voucher] create failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 下架/上架我的券
router.put('/:id/active', authRequired, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const active = req.body.active === true ? 1 : 0;
    const [r] = await pool.query(
      'UPDATE voucher_templates SET is_active = ? WHERE id = ? AND creator_id = ?',
      [active, id, req.user.id]
    );
    if (r.affectedRows === 0) return res.status(404).json({ code: 404, message: '券不存在' });
    res.json({ code: 200, message: active ? '已上架' : '已下架' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 删除我的券（仅发行人；仅已下架且无兑换记录——兑换记录承载豆流水追溯，不随券物理清除）
router.delete('/:id', authRequired, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    if (!Number.isInteger(id)) return res.status(400).json({ code: 400, message: '参数不对' });
    const [rows] = await pool.query(
      `SELECT is_active,
              (SELECT COUNT(*) FROM voucher_redemptions r WHERE r.template_id = voucher_templates.id) AS redeemed_count
       FROM voucher_templates WHERE id = ? AND creator_id = ?`,
      [id, req.user.id]
    );
    if (rows.length === 0) return res.status(404).json({ code: 404, message: '券不存在' });
    if (rows[0].is_active) return res.status(400).json({ code: 400, message: '先下架再删除' });
    if (rows[0].redeemed_count > 0) {
      return res.status(409).json({ code: 409, message: '这张券有兑换记录，不能删除' });
    }
    // 条件重查防竞态：下架/兑换状态在下决断瞬间再校验一次
    const [del] = await pool.query(
      `DELETE FROM voucher_templates
       WHERE id = ? AND creator_id = ? AND is_active = 0
         AND NOT EXISTS (SELECT 1 FROM voucher_redemptions r WHERE r.template_id = voucher_templates.id)`,
      [id, req.user.id]
    );
    if (del.affectedRows === 0) {
      return res.status(409).json({ code: 409, message: '状态刚有变化，刷新后再试' });
    }
    res.json({ code: 200, message: '已删除' });
  } catch (err) {
    console.error('[Voucher] delete failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// ========== 兑换与流转 ==========

// 兑换（花豆）；幂等由豆流水 source_id = redemption_id 保证回滚
router.post('/:id/redeem', authRequired, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const templateId = parseInt(req.params.id);
    const partnerId = await getPartnerId(req.user.id);
    if (partnerId == null) {
      conn.release();
      return res.status(400).json({ code: 400, message: '先绑定伴侣，才有券可兑' });
    }

    await conn.beginTransaction();

    const [tpl] = await conn.query(
      'SELECT id, creator_id, title, cost_bean, emoji, is_active FROM voucher_templates WHERE id = ? FOR UPDATE',
      [templateId]
    );
    if (tpl.length === 0 || tpl[0].creator_id !== partnerId) {
      await conn.rollback();
      conn.release();
      return res.status(404).json({ code: 404, message: '这张券不存在（只能兑换 TA 发行的券）' });
    }
    if (!tpl[0].is_active) {
      await conn.rollback();
      conn.release();
      return res.status(400).json({ code: 400, message: '这张券已下架' });
    }
    const cost = tpl[0].cost_bean;

    // 原子扣豆（余额不足直接失败）
    const [deduct] = await conn.query(
      'UPDATE users SET bean_balance = COALESCE(bean_balance,0) - ? WHERE id = ? AND COALESCE(bean_balance,0) >= ?',
      [cost, req.user.id, cost]
    );
    if (deduct.affectedRows === 0) {
      await conn.rollback();
      conn.release();
      return res.status(400).json({ code: 400, message: `爱心豆不够（还差 ${cost} 颗）` });
    }

    const [ins] = await conn.query(
      `INSERT INTO voucher_redemptions (template_id, redeemer_id, creator_id, cost_bean, status)
       VALUES (?, ?, ?, ?, 'pending')`,
      [templateId, req.user.id, partnerId, cost]
    );

    // 豆流水（负数）；balance_after 用扣完的值
    const [me] = await conn.query('SELECT bean_balance FROM users WHERE id = ?', [req.user.id]);
    await conn.query(
      `INSERT INTO bean_transactions
       (user_id, amount, balance_after, type, title, source_module, source_id, description)
       VALUES (?, ?, ?, 'voucher_redeem', ?, 'wish_voucher', ?, ?)`,
      [req.user.id, -cost, Number(me[0]?.bean_balance || 0), `兑换「${tpl[0].title}」`, ins.insertId, tpl[0].title]
    );

    await conn.commit();
    conn.release();

    // 通知出券人
    try {
      await pool.query(
        'INSERT INTO notifications (user_id, type, title, content, payload) VALUES (?, ?, ?, ?, ?)',
        [partnerId, 'voucher_redeem', '你的券被兑换啦', `TA 花了 ${cost} 颗爱心豆兑换「${tpl[0].title}」，快去兑现吧`, JSON.stringify({ redemption_id: ins.insertId })]
      );
    } catch (err) {
      console.error('[Voucher] notify failed:', err.message);
    }

    res.json({ code: 200, data: { id: ins.insertId, balance: Number(me[0]?.bean_balance || 0) } });
  } catch (err) {
    await conn.rollback().catch(() => {});
    conn.release();
    console.error('[Voucher] redeem failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 兑换记录列表（我兑的 + 兑了我发的券的）
router.get('/redemptions', authRequired, async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT r.id, r.template_id, r.redeemer_id, r.creator_id, r.cost_bean, r.status,
              r.proof_url, r.created_at, r.done_at,
              v.title, v.emoji
       FROM voucher_redemptions r
       JOIN voucher_templates v ON v.id = r.template_id
       WHERE r.redeemer_id = ? OR r.creator_id = ?
       ORDER BY r.created_at DESC LIMIT 60`,
      [req.user.id, req.user.id]
    );
    res.json({
      code: 200,
      data: rows.map((r) => ({
        ...r,
        iAmRedeemer: r.redeemer_id === req.user.id,
      })),
    });
  } catch (err) {
    console.error('[Voucher] redemptions failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 出券人标记"已兑现"（可带凭证照 URL，复用 kitchen 上传得到的地址）
router.put('/redemptions/:id/done', authRequired, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const proofUrl = cleanText(req.body.proofUrl, 500);
    const [r] = await pool.query(
      `UPDATE voucher_redemptions SET status = 'done', proof_url = ?, done_at = NOW()
       WHERE id = ? AND creator_id = ? AND status = 'pending'`,
      [proofUrl || null, id, req.user.id]
    );
    if (r.affectedRows === 0) return res.status(404).json({ code: 404, message: '记录不存在或已处理' });

    const [rows] = await pool.query('SELECT redeemer_id, cost_bean FROM voucher_redemptions WHERE id = ?', [id]);
    if (rows.length > 0) {
      await pool.query(
        'INSERT INTO notifications (user_id, type, title, content, payload) VALUES (?, ?, ?, ?, ?)',
        [rows[0].redeemer_id, 'voucher_done', '券已兑现', '快去看看兑现凭证吧', JSON.stringify({ redemption_id: id })]
      );
    }
    res.json({ code: 200, message: '已标记兑现' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 兑换人确认完成（终态）
router.put('/redemptions/:id/confirm', authRequired, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    const [r] = await pool.query(
      `UPDATE voucher_redemptions SET status = 'confirmed'
       WHERE id = ? AND redeemer_id = ? AND status = 'done'`,
      [id, req.user.id]
    );
    if (r.affectedRows === 0) return res.status(404).json({ code: 404, message: '记录不存在或状态不对' });
    res.json({ code: 200, message: '已确认，这张券完成啦' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// 取消（仅 pending；退豆给兑换人）
router.put('/redemptions/:id/cancel', authRequired, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const id = parseInt(req.params.id);
    await conn.beginTransaction();
    const [rows] = await conn.query(
      `SELECT r.*, v.title FROM voucher_redemptions r JOIN voucher_templates v ON v.id = r.template_id
       WHERE r.id = ? AND r.status = 'pending' FOR UPDATE`,
      [id]
    );
    if (rows.length === 0) {
      await conn.rollback();
      conn.release();
      return res.status(404).json({ code: 404, message: '记录不存在或已处理' });
    }
    const rec = rows[0];
    // 双方任一方可取消
    if (req.user.id !== rec.redeemer_id && req.user.id !== rec.creator_id) {
      await conn.rollback();
      conn.release();
      return res.status(403).json({ code: 403, message: '只有当事双方可以取消' });
    }
    // 退豆
    await conn.query(
      'UPDATE users SET bean_balance = COALESCE(bean_balance,0) + ? WHERE id = ?',
      [rec.cost_bean, rec.redeemer_id]
    );
    await conn.query(
      `INSERT INTO bean_transactions
       (user_id, amount, balance_after, type, title, source_module, source_id, description)
       VALUES (?, ?, 0, 'voucher_refund', ?, 'wish_voucher', ?, ?)`,
      [rec.redeemer_id, rec.cost_bean, `取消「${rec.title}」退款`, rec.id, rec.title]
    );
    // balance_after 修正
    const [u] = await conn.query('SELECT bean_balance FROM users WHERE id = ?', [rec.redeemer_id]);
    await conn.query(
      'UPDATE bean_transactions SET balance_after = ? WHERE source_module = ? AND source_id = ? AND type = ?',
      [Number(u[0]?.bean_balance || 0), 'wish_voucher', rec.id, 'voucher_refund']
    );
    await conn.query("UPDATE voucher_redemptions SET status = 'cancelled' WHERE id = ?", [id]);
    await conn.commit();
    conn.release();

    // 通知对方
    const other = req.user.id === rec.redeemer_id ? rec.creator_id : rec.redeemer_id;
    try {
      await pool.query(
        'INSERT INTO notifications (user_id, type, title, content, payload) VALUES (?, ?, ?, ?, ?)',
        [other, 'voucher_cancel', '兑换已取消', `「${rec.title}」已取消，豆子已退回`, JSON.stringify({ redemption_id: id })]
      );
    } catch (err) {
      console.error('[Voucher] cancel notify failed:', err.message);
    }
    res.json({ code: 200, message: '已取消并退豆' });
  } catch (err) {
    await conn.rollback().catch(() => {});
    conn.release();
    console.error('[Voucher] cancel failed:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
