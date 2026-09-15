---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: 7e6ec0dc5eddcf69ad5503ef148481dd_1683056179d411f1b3d35254007bceed
    ReservedCode1: qgw4GYZaLiOSP4oCIVatUXUGESJdaM9L7JTRvfsuMcxEFknQo03Z/a77J4bDFzmoBS007UkTE3JzrgN8aQ/VBLRfEIPHfDjdK8xPpvx0EG73p2FxHXNKpAcyR3TQ5jQq88G0EW29TH4/gxTaXOilsxsVEPIXkj2fX8KrfP73rZfhM0YkPLZOwdZnHJ8=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: 7e6ec0dc5eddcf69ad5503ef148481dd_1683056179d411f1b3d35254007bceed
    ReservedCode2: qgw4GYZaLiOSP4oCIVatUXUGESJdaM9L7JTRvfsuMcxEFknQo03Z/a77J4bDFzmoBS007UkTE3JzrgN8aQ/VBLRfEIPHfDjdK8xPpvx0EG73p2FxHXNKpAcyR3TQ5jQq88G0EW29TH4/gxTaXOilsxsVEPIXkj2fX8KrfP73rZfhM0YkPLZOwdZnHJ8=
---



# LoveGirl 关键功能全面测试计划 (TEST_PLAN)

> 版本: 1.0 | 日期: 2026-07-07 | 覆盖: 6 大核心模块 | 测试用例总数: 78

---

## 目录

1. [投喂站下单履约全链路](#1-投喂站下单履约全链路)
2. [伴侣绑定/解绑](#2-伴侣绑定解绑)
3. [经期数据读写](#3-经期数据读写)
4. [记账记录](#4-记账记录)
5. [成就系统](#5-成就系统)
6. [版本更新检查](#6-版本更新检查)

---

## 1. 投喂站下单履约全链路

> **关键文件**: `feeding_v2.js`, `utils/lovegirl_rewards.js`
> **核心 API**: `POST /orders` → `PUT /orders/:id/status` / `POST /orders/:id/fulfill`
> **链路验证点**: 下单扣豆 → 订单状态流转 → 履约联动（记账 + 时间轴 + 成就 + 通知）

### 1.1 正常且结果正确

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| FEED-N-001 | 下单 | POST `/api/feeding/orders` body: `{product_id:1001, quantity:1}` | 1. HTTP 200, `status=pending` 2. `bean_balance` 减少 `productPrice*1` 3. `bean_transactions` 写入一条 `type=feeding_order, amount=-productPrice` 4. `feeding_orders` 写入一条 `status=pending` | `SELECT bean_balance FROM users WHERE id=?; SELECT COUNT(*) FROM bean_transactions WHERE user_id=? AND type='feeding_order' AND source_module='feeding';` |
| FEED-N-002 | 下单多件 | POST `/api/feeding/orders` body: `{product_id:1001, quantity:3}` | total_price = productPrice × 3；bean_balance 扣除等额豆子 | 同上，验证 `amount=-totalPrice, balance_after=原余额-totalPrice` |
| FEED-N-003 | 状态流转 pending→accepted | PUT `/api/feeding/orders/:id/status` body: `{status:'accepted'}` | 1. HTTP 200 2. `status='accepted'`, `accepted_at` 非空 3. notification 写入 receiver→sender | `SELECT status, accepted_at FROM feeding_orders WHERE id=?; SELECT * FROM notifications WHERE user_id=? AND type='feeding_status' ORDER BY created_at DESC LIMIT 1;` |
| FEED-N-004 | 状态流转 accepted→preparing | PUT body: `{status:'preparing'}` | 仅 receiver 可操作；status 变为 preparing | `SELECT status FROM feeding_orders WHERE id=?;` |
| FEED-N-005 | 状态流转 preparing→delivering | PUT body: `{status:'delivering'}` | 仅 receiver 可操作；status 变为 delivering | `SELECT status FROM feeding_orders WHERE id=?;` |
| FEED-N-006 | 一键履约 fulfilling | POST `/api/feeding/orders/:id/fulfill` body: `{platform:'美团', actual_amount:25.5, platform_order_id:'MT20260707'}` | 1. HTTP 200, `status='completed'` 2. `platform='美团'`, `actual_amount=25.5`, `platform_order_id='MT20260707'`, `delivered_at` 非空 3. `finance_records` 写入一条 `type=expense, category='feeding'` 4. `love_timeline` 写入一条 `icon='restaurant'` 5. `bean_transactions` 写入 `type='feeding_received', amount=1` 6. notification 写入 sender | `SELECT status, platform, actual_amount, delivered_at FROM feeding_orders WHERE id=?; SELECT * FROM finance_records WHERE user_id=? AND source_module='feeding' AND source_id=?; SELECT * FROM bean_transactions WHERE user_id=? AND type='feeding_received' AND source_id=?;` |
| FEED-N-007 | 履约 actual_amount 为空时取 total_price | POST `/api/feeding/orders/:id/fulfill` body: `{platform:'饿了么'}`（不传 actual_amount） | finance_records.amount = total_price | `SELECT amount FROM finance_records WHERE source_id=?` 解密后与 order.total_price 比较 |
| FEED-N-008 | 催单 | POST `/api/feeding/orders/:id/urge` | urge_count +1, last_urge_at 更新, notification 写入 receiver | `SELECT urge_count, last_urge_at FROM feeding_orders WHERE id=?;` |
| FEED-N-009 | 商店列表 | GET `/api/feeding/shops` | 返回 3 个默认商店（或 DB 中的活跃商店） | HTTP 200, data.length >= 3 |
| FEED-N-010 | 经期用户商品排序 | GET `/api/feeding/shops/1/products`（girl 用户处于经期） | Hot Brown Sugar Tea 排第一（period_recommended=1），Iced Lemon Tea 排末尾（period_recommended=-1） | 验证 products 数组的 period_recommended 排序逻辑 |

### 1.2 边界值

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| FEED-B-001 | quantity=0（自动矫正） | POST body: `{product_id:1001, quantity:0}` | 后端 `Math.max(1, ...)` 矫正为 1；正常扣款下单 | quantity 实际为 1 |
| FEED-B-002 | quantity=99（上限） | POST body: `{product_id:1001, quantity:99}` | 正常处理，total_price = 99 × price | quantity 被限制在 99 |
| FEED-B-003 | quantity=100（超过上限） | POST body: `{product_id:1001, quantity:100}` | 后端 `Math.min(99, ...)` 矫正为 99 | quantity 实际为 99 |
| FEED-B-004 | 负数额 quantity=-5 | POST body: `{product_id:1001, quantity:-5}` | 矫正为 1（Math.max(1,...)） | quantity 实际为 1 |
| FEED-B-005 | product_id 不存在 | POST body: `{product_id:99999}` | 从默认产品列表回退，name='Gift', price=10 | HTTP 200, product_name 可能为 'Gift' |
| FEED-B-006 | 余额刚好够最后一单 | 先扣到余额=price，再下单 | 下单成功，余额扣为 0 | `bean_balance` 恰好为 0 |
| FEED-B-007 | 重复催单 < 5分钟 | 连续两次 POST `/api/feeding/orders/:id/urge`（间隔小于 5 分钟） | 第二次返回 429, `"please wait 5 minutes before urging again"` | HTTP 429 |
| FEED-B-008 | 已完成订单不能催单 | 对 status='completed' 的订单催单 | HTTP 400, `"current status cannot be urged"` | 仅 pending/accepted/preparing 可催单 |
| FEED-B-009 | actual_amount=0 履约 | fulfill body: `{platform:'美团', actual_amount:0}` | 接受 -- 0 不是 null，`amount !== null && amount < 0` 不触发；finance 记录 amount=0 | `SELECT status FROM feeding_orders WHERE id=?` 为 completed |
| FEED-B-010 | 超大 actual_amount | fulfill body: `{platform:'美团', actual_amount:99999999}` | 正常接受写入 | finance_records.amount = 99999999 |
| FEED-B-011 | platform 超长字符串 | fulfill body: `{platform:'A'.repeat(1000)}` | 截断为 30 字符 | `SELECT platform FROM feeding_orders` LENGTH ≤ 30 |
| FEED-B-012 | platform_order_id 超长 | fulfill body: `{platform_order_id:'X'.repeat(200)}` | 截断为 100 字符 | LENGTH ≤ 100 |
| FEED-B-013 | note 超长 500+ | fulfill body: `{note:'N'.repeat(1000)}` | 截断为 500 字符 | LENGTH ≤ 500 |

### 1.3 异常与非法输入

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| FEED-E-001 | 未登录 | 无 Authorization Header 请求 POST `/orders` | HTTP 401 | authRequired 中间件拦截 |
| FEED-E-002 | Token 过期 | 过期 JWT Token | HTTP 401 | authRequired 中间件拦截 |
| FEED-E-003 | 无效 Token | 随机字符串作为 Bearer Token | HTTP 401 | authRequired 中间件拦截 |
| FEED-E-004 | product_id 缺失 | POST body: `{quantity:1}` 无 product_id | HTTP 400, `"product_id required"` | |
| FEED-E-005 | 未绑定伴侣下单 | 用户无 active 伴侣关系时下单 | HTTP 400, `"bind partner first"` | |
| FEED-E-006 | 爱心豆余额不足 | 余额=0 时下单 product_id=1001 | HTTP 400, `"爱心豆余额不足"`；事务回滚，无订单、无扣款记录 | `SELECT bean_balance FROM users WHERE id=?;` 未变化；`feeding_orders` 无新记录 |
| FEED-E-007 | 非法 status 流转 | PUT body: `{status:'pending'}` 对 pending 订单（回退） | HTTP 400, `"cannot change pending to pending"` | flow 规则拒绝非法跳转 |
| FEED-E-008 | 非订单参与者修改状态 | 第三方用户调用 PUT `/orders/:id/status` | HTTP 403, `"forbidden"` | sender_id / receiver_id 均不匹配 |
| FEED-E-009 | sender 尝试推进状态 | sender 调用 PUT body: `{status:'accepted'}` | HTTP 403, `"receiver only"` | 仅 receiver 可推进（非 cancel） |
| FEED-E-010 | 重复履约 | 对已 completed 订单再次 fulfill | HTTP 400, `"order already completed or cancelled"` | |
| FEED-E-011 | actual_amount 为负数履行 | fulfill body: `{platform:'美团', actual_amount:-10}` | HTTP 400, `"invalid amount"` | |
| FEED-E-012 | actual_amount 为 NaN/Infinity | fulfill body: `{platform:'美团', actual_amount:Infinity}` | HTTP 400, `"invalid amount"` | `!Number.isFinite(amount)` 拦截 |
| FEED-E-013 | SQL 注入 product_id | POST body: `{product_id:"1 OR 1=1"}` | HTTP 400（Number 转换后为 NaN）或正常查不到产品 | 参数化查询防护 |
| FEED-E-014 | XSS 注入 message | POST body: `{product_id:1001, message:"<script>alert('xss')</script>"}` | 正常写入（Db 层）；前端渲染时需转义 | 不阻断流程 |
| FEED-E-015 | 对已取消订单履约 | cancel 后再 fulfill | HTTP 400, `"order already completed or cancelled"` | |
| FEED-E-016 | 并发两单下单（豆子够） | 同时两个 POST `/orders` | 两单均成功或第二单因瞬时余额不足失败（取决于事务隔离） | 检查 bean_transactions 无重复扣款 / 无超扣 |
| FEED-E-017 | cancel 后不可再 cancel | 对 cancelled 订单再次 PUT status=cancelled | HTTP 400, cannot change cancelled to cancelled | flow 表拒绝 |

---

## 2. 伴侣绑定/解绑

> **关键文件**: `couple.js`
> **核心 API**: `POST /invite` → `POST /accept` → `GET /` → `DELETE /`
> **核心表**: `couples`, `couple_invites`

### 2.1 正常且结果正确

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| COUP-N-001 | 生成邀请码 | POST `/api/couple/invite`（未绑定用户） | HTTP 200, `invite_code=6位数字`, `expires_in=600`；`couple_invites` 写入一条记录 `used=0` | `SELECT code, used, creator_id FROM couple_invites WHERE creator_id=? ORDER BY created_at DESC LIMIT 1;` |
| COUP-N-002 | 接受邀请码绑定 | A 生成邀请码 → B 调用 POST `/api/couple/accept` body: `{code:'XXXXXX'}` | 1. HTTP 200, `"绑定成功！"` 2. `couples` 写入一条 `user1_id=min(A,B), user2_id=max(A,B), status='active'` 3. `couple_invites.used=1, used_by=B` | `SELECT * FROM couples WHERE user1_id=? OR user2_id=?; SELECT code, used, used_by FROM couple_invites WHERE code=?;` |
| COUP-N-003 | 查询绑定状态 | GET `/api/couple`（已绑定用户） | HTTP 200, `coupled=true`, `partner` 含 `id/nickname/avatar/role` | `SELECT * FROM couples WHERE (user1_id=? OR user2_id=?) AND status='active';` |
| COUP-N-004 | 查询未绑定状态 | GET `/api/couple`（未绑定用户） | HTTP 200, `coupled=false` | couples 表无 active 记录 |
| COUP-N-005 | 解绑 | DELETE `/api/couple`（已绑定用户） | 1. HTTP 200, `"已解除绑定"` 2. couples.status='broken', broken_at 非空 3. GET /api/couple 返回 coupled=false | `SELECT status, broken_at FROM couples WHERE user1_id=? OR user2_id=?;` |
| COUP-N-006 | 重新生成邀请码覆盖旧码 | 已生成但未使用的邀请码，再次 POST `/invite` | 旧未使用邀请码被删除，新邀请码生效 | `SELECT COUNT(*) FROM couple_invites WHERE creator_id=? AND used=0;` 仅 1 条 |

### 2.2 边界值

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| COUP-B-001 | 邀请码即将过期 | 生成邀请码后等待接近 10 分钟再使用 | 若已过期返回 400 `"邀请码已过期"` | `SELECT expires_at FROM couple_invites WHERE code=?` < NOW() |
| COUP-B-002 | 邀请码长度不足 | POST `/accept` body: `{code:'123'}` | HTTP 400, `"请输入6位邀请码"` | code.length !== 6 拦截 |
| COUP-B-003 | 邀请码长度过多 | POST `/accept` body: `{code:'1234567'}` | HTTP 400 | code.length !== 6 拦截 |
| COUP-B-004 | 空邀请码 | POST `/accept` body: `{code:''}` | HTTP 400, `"请输入6位邀请码"` | |
| COUP-B-005 | 缺失 code 字段 | POST `/accept` body: `{}` | HTTP 400 | |
| COUP-B-006 | code 传入数字类型 | POST `/accept` body: `{code:123456}` | 需验证 `code.length` 是否能正确判断——Number 无 .length。视 Node 版本可能 400 或 500 | 检查错误处理 |
| COUP-B-007 | 生成邀请码重试 10 次上限 | 极端并发下 code 重复，重试 10 次仍冲突 | HTTP 500, `"生成邀请码失败，请重试"` | 模拟 DUP_ENTRY 10 次后 |
| COUP-B-008 | 邀请码已使用后再被使用 | 第二个用户用同一 code accept | HTTP 400, `"邀请码无效或已使用"` | `used=1` 被拦截 |
| COUP-B-009 | 解绑后绑定新伴侣 | A-B 解绑 → A 生成新邀请码 → C 接受 | A 与 C 绑定成功，旧 couples 记录 status='broken'，新 active 记录建立 | 验证 couples 表两条记录各行其是 |

### 2.3 异常与非法输入

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| COUP-E-001 | 未登录生成邀请码 | 无 Token POST `/invite` | HTTP 401 | authRequired 拦截 |
| COUP-E-002 | 已绑定用户生成邀请码 | POST `/invite`（已有 active 绑定） | HTTP 400, `"你已经绑定过了"` | |
| COUP-E-003 | 已绑定用户接受邀请码 | POST `/accept`（已有 active 绑定） | HTTP 400, `"你已经绑定过了"` | |
| COUP-E-004 | 自己绑定自己 | A 生成 code → A 自己调用 accept | HTTP 400, `"不能和自己绑定哦"` | `invite.creator_id === userId` |
| COUP-E-005 | 接受时邀请方已被绑定（竞态） | A 生成 code → B 抢先与 A 绑定 → C 再用 code accept | HTTP 400, `"对方已经绑定了其他人"` | 二次查询 creator 的绑定状态 |
| COUP-E-006 | 未绑定用户直接解绑 | DELETE `/api/couple`（无 active 绑定） | HTTP 404, `"你还没有绑定"` | |
| COUP-E-007 | 重复解绑 | 解绑后再次 DELETE | HTTP 404, `"你还没有绑定"` | status='broken' 被过滤 |
| COUP-E-008 | SQL 注入 code | POST `/accept` body: `{code:"'; DROP TABLE couples;--"}` | HTTP 400（length !== 6）或参数化查询免疫 | |
| COUP-E-009 | code 包含非数字字符 | POST `/accept` body: `{code:'AB12CD'}` | 正常处理（code 是纯字符串，只判断长度=6） | 若 DB 中不存在则 `"邀请码无效或已使用"` |
| COUP-E-010 | 并发绑定 — 两人同时接受同一邀请码 | B 和 C 同时 POST `/accept` 同一 code | 仅一人成功绑定，另一人返回 "对方已经绑定了其他人" 或 "邀请码无效或已使用" | 事务隔离 + 重复检查双重保障 |
| COUP-E-011 | 并发绑定 — 两人同时与 A 互相接受 | A 向 B 发 code、B 向 A 发 code，同时 accept | 仅一对绑定成功（unique key uk_user1 / uk_user2） | UNIQUE KEY 约束触发 |

---

## 3. 经期数据读写

> **关键文件**: `period.js`
> **核心 API**: `POST /start` → `POST /end` → `POST /` (痛经) → `GET /status` → `GET /analysis`
> **安全特性**: 加密存储（`_encrypted` column）；解绑后隐私隔离（WHERE user_id = req.user.id）

### 3.1 正常且结果正确

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| PER-N-001 | 标记经期开始 | POST `/api/period/start` body: `{date:'2026-07-01'}` | HTTP 200；`period_records` 写入一条 `end_date_encrypted IS NULL`；`start_date_encrypted` 解密后为 `'2026-07-01'` | `SELECT start_date_encrypted, end_date_encrypted FROM period_records WHERE user_id=? ORDER BY created_at DESC LIMIT 1;` 解密验证 |
| PER-N-002 | 标记经期结束 | 有进行中经期 → POST `/api/period/end` body: `{date:'2026-07-05'}` | HTTP 200；`end_date_encrypted` 解密后为 `'2026-07-05'`；`duration_days_encrypted` 自动计算为 `5` | 解密验证 + 持续天数计算 |
| PER-N-003 | 经期状态 — 经期中 | GET `/api/period/status`（有 ongoing 记录） | `isInPeriod=true`, `phase.phaseKey='menstrual'`, `dayInPeriod` 正确 | 验证 phase 各字段 |
| PER-N-004 | 经期状态 — 安全期 | GET `/api/period/status`（最近经期结束 + 距预测 >16 天） | `isInPeriod=false`, `phase.phaseKey='safe'` | |
| PER-N-005 | 经期状态 — 排卵期 | GET `/api/period/status`（daysUntil ≈ 11-16） | `phase.phaseKey='ovulation'` | |
| PER-N-006 | 经期状态 — 经期临近 | GET `/api/period/status`（daysUntil ≤ 3） | `phase.phaseKey='luteal'`, label='经期临近' | |
| PER-N-007 | 周期分析 | GET `/api/period/analysis`（有 ≥2 条已完成经期） | `avgCycle` / `avgDuration` 正确计算；`cycles` 数组含相邻间隔；`durations` 数组含每次持续天数 | 手工验算均值 |
| PER-N-008 | 痛经记录 | POST `/api/period` body: `{painLevel:3, symptoms:['腹痛','腰酸'], medicine:'布洛芬', notes:'难受'}` | HTTP 200；新记录写入 pain_level_encrypted=3, symptoms_encrypted 解密为数组 | 解密验证 |
| PER-N-009 | 周期设置更新 | POST `/api/period` body: `{cycleDays:30, durationDays:6}` | 最近一条记录的 cycle_days_encrypted / duration_days_encrypted 更新 | 解密验证 |
| PER-N-010 | 单条记录详情 | GET `/api/period/:id` | 返回解密后的 startDate / endDate / painLevel / symptoms 等 | 与入库加密前值一致 |
| PER-N-011 | 编辑痛经记录 | PUT `/api/period/:id` body: `{painLevel:5}` | pain_level_encrypted 更新为加密的 '5' | 解密验证 |
| PER-N-012 | 删除记录 | DELETE `/api/period/:id` | HTTP 200；affectedRows=1；`period_records` 中该 id 不存在 | `SELECT COUNT(*) FROM period_records WHERE id=?;` 为 0 |

### 3.2 边界值

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| PER-B-001 | 重复标记开始 | 已有 ongoing 时再 POST `/start` | HTTP 400, `"已有进行中的经期，请先标记结束"` | |
| PER-B-002 | 无进行中经期时标记结束 | POST `/end`（无 ongoing） | HTTP 400, `"没有进行中的经期"` | |
| PER-B-003 | 经期持续 1 天 | start='2026-07-01', end='2026-07-01' | duration 计算为 1 | 边界测试 |
| PER-B-004 | 经期持续 15 天 | start='2026-07-01', end='2026-07-15' | duration 计算为 15；`actualDuration >=1 && <=15` 条件通过，写入 | |
| PER-B-005 | 经期持续 16 天 | start='2026-07-01', end='2026-07-16' | duration 计算为 16；不满足 `<=15` 条件，不更新 duration_days_encrypted | duration_days_encrypted 保留原值 |
| PER-B-006 | 只有 1 条经期记录时 analysis | GET `/analysis`（仅 1 条已完成） | count=1；intervals 为空数组；avgCycle 回退为 28 | |
| PER-B-007 | 只有 1 条记录时 status | GET `/status`（仅 1 条已完成） | avgCycle=28, avgDuration=该条持续天数 | 因为 intervals 空，avgCycle 未计算 |
| PER-B-008 | painLevel=0 | POST body: `{painLevel:0}` | 正常存入，解密后为 0；mapRecord 中 `isPain` 因 `painLevel>0` 为 false | |
| PER-B-009 | 空 symptoms 数组 | POST body: `{symptoms:[]}` | symptoms_encrypted 解密后为 `[]`；mapRecord 中 painLevel==0 + symptoms.length==0 → isCycle=true | |
| PER-B-010 | 经期 date 跨年 | start='2025-12-28', end='2026-01-03' | 正常存储，持续天数计算正确（7 天） | |

### 3.3 异常与非法输入

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| PER-E-001 | 未登录访问 | 无 Token 请求 GET `/api/period` | HTTP 401 | authRequired |
| PER-E-002 | Token 过期 | expired JWT | HTTP 401 | |
| PER-E-003 | 访问不存在的记录 | GET `/api/period/99999` | HTTP 404, `"记录不存在"` | |
| PER-E-004 | 删除他人记录 | DELETE `/api/period/:id` (id 属于其他 user) | HTTP 404, `"记录不存在"` | `WHERE id=? AND user_id=?` 双重过滤 |
| PER-E-005 | 编辑他人记录 | PUT `/api/period/:id` (id 属于其他 user) | HTTP 404 或无变化（affectedRows=0） | |
| PER-E-006 | 解绑后访问前任经期数据 | A 查看 B 的 period 数据（通过修改 user_id） | 无法访问 —— `WHERE user_id = req.user.id` 隔离 | 隐私隔离验证 |
| PER-E-007 | painLevel 传入字符串 | POST body: `{painLevel:'high'}` | `parseInt('high')` → NaN → 解密时可能异常或 `encrypt('high')` 被存储 | 边界容错 — 应验证 |
| PER-E-008 | 无更新字段 | PUT `/api/period/:id` body: `{}` | HTTP 400, `"没有要更新的字段"` | |
| PER-E-009 | SQL 注入 date | POST `/start` body: `{date:"'; DROP TABLE period_records;--"}` | 参数化查询免疫；date 被作为字符串加密存储 | |
| PER-E-010 | 大容量 symptoms 数组 | POST body: `{symptoms: Array(10000).fill('test')}` | symptoms JSON 序列化并加密写入（可能极大），读取解密时有 JSON.parse 风险 | 需验证超大数组不导致 OOM |
| PER-E-011 | cycleDays=0 / durationDays=0 | POST body: `{cycleDays:0, durationDays:0}` | 加密存为 '0'；分析时 `dur>0` 过滤，可能跳过 | 不应导致除零错误 |
| PER-E-012 | 非法 date 格式 | POST `/start` body: `{date:'not-a-date'}` | encrypt 接收字符串后存入；后续解密解析时 `new Date('not-a-date')` 返回 Invalid Date | 可能导致 calcPhase 等异常 |

---

## 4. 记账记录

> **关键文件**: `finance.js`
> **核心 API**: `GET /` → `POST /` → `PUT /:id` → `DELETE /:id` → `GET /stats`
> **安全特性**: amount 加密存储；财务隐私 `finance_privacy_enabled` 控制

### 4.1 正常且结果正确

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| FIN-N-001 | 添加支出记录 | POST `/api/finance` body: `{type:'expense', category:'餐饮', amount:25, description:'午餐', recordDate:'2026-07-07'}` | HTTP 200；`finance_records` 写入一条；`amount_encrypted` 解密后为 `'25'`；`description_encrypted` 解密后为 `'午餐'` | 解密字段验证 |
| FIN-N-002 | 添加收入记录 | POST body: `{type:'income', category:'工资', amount:5000}` | HTTP 200；正常写入 | |
| FIN-N-003 | 查询月度记录 | GET `/api/finance?month=2026-07` | 返回 2026-07 所有记录，amount/description 解密正常 | 验证返回条数 + 解密值 |
| FIN-N-004 | 月度统计 | GET `/api/finance/stats?month=2026-07` | `totalIncome/totalExpense/balance` 计算正确；`categoryBreakdown` 含分类 + 金额 + 百分比 | 手工验算 |
| FIN-N-005 | 编辑记录 | PUT `/api/finance/:id` body: `{amount:30, category:'饮品'}` | amount_encrypted 更新为加密的 '30'；category 更新 | 解密验证 |
| FIN-N-006 | 删除记录 | DELETE `/api/finance/:id` | HTTP 200；affectedRows=1 | `SELECT COUNT(*) FROM finance_records WHERE id=?;` 为 0 |
| FIN-N-007 | 卡路里联动 | POST body: `{..., calorieSynced:true, amount:25}` | `calorie_records` 写入一条 `source='finance', calories≈250` | `SELECT * FROM calorie_records WHERE source='finance' AND record_date=...;` |
| FIN-N-008 | 投喂联动记账 | 履约完成时自动创建 finance 记录 | `source_module='feeding'`, category='feeding' | `SELECT * FROM finance_records WHERE source_module='feeding' AND source_id=?;` |
| FIN-N-009 | 隐私模式 — girl 有隐私设置时查询 | girl 设置 `finance_privacy_enabled=1` → GET `/api/finance` | amount 显示 `'***'` | hideAmount=true 触发 |

### 4.2 边界值

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| FIN-B-001 | amount=0 | POST body: `{type:'expense', category:'其他', amount:0}` | 正常写入（未校验 amount>0） | |
| FIN-B-002 | amount 负数 | POST body: `{amount:-100}` | `encrypt(String(-100))` 加密后存储；统计时 `parseFloat` 为负数参与计算 | 统计可能异常（收支颠倒） |
| FIN-B-003 | amount 极大值 | POST body: `{amount:999999999.99}` | 加密字符串后存储；统计正常 | |
| FIN-B-004 | amount 浮点数精度 | POST body: `{amount:19.99}` | 加密后浮点精度保持 | 解密后为 '19.99' |
| FIN-B-005 | month 为空时默认当月 | GET `/api/finance`（不传 month） | `new Date().toISOString().substring(0,7)` 作为默认值 | |
| FIN-B-006 | month='2026-02'（非闰年 2 月） | 写入 `recordDate='2026-02-29'` | 需看 DB 是否接受非法日期 | MySQL 可能自动修正或报错 |
| FIN-B-007 | 编辑时只传一个字段 | PUT body: `{amount:100}` | 仅更新 amount_encrypted，其他字段不变 | |
| FIN-B-008 | description 为空 | POST body: `{..., description:''}` | encrypt('') 存储；decrypt 后为空字符串 | |
| FIN-B-009 | 空 category | POST body: `{..., category:''}` | 直接存储空字符串 | stats 中归入 "" 分类 |
| FIN-B-010 | boy 查看 girl 月统计 | GET `/stats?month=2026-07` (boy_id) | 正常返回（当前代码 boy 未强制隐藏） | 验证业务逻辑一致性 |

### 4.3 异常与非法输入

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| FIN-E-001 | 未登录 | 无 Token POST `/api/finance` | HTTP 401 | |
| FIN-E-002 | 必填参数缺失 | POST body: `{type:'expense'}` 无 category/amount | HTTP 400, `"请填写完整信息"` | |
| FIN-E-003 | 删除他人记录 | DELETE `/api/finance/:id` (id 属于他人) | affectedRows=0 → 未提示（当前无 404），静默成功 | 代码缺陷：建议补充 404 |
| FIN-E-004 | 编辑他人记录 | PUT `/api/finance/:id` (id 属于他人) | affectedRows=0 → 无提示 | 代码缺陷 |
| FIN-E-005 | SQL 注入 description | POST body: `{..., description:"'; DROP TABLE finance_records;--"}` | 参数化查询免疫；作为字符串加密存储 | |
| FIN-E-006 | XSS 注入 description | POST body: `{..., description:'<img src=x onerror=alert(1)>'}` | 加密存储原文；前端需转义 | |
| FIN-E-007 | type 非法值 | POST body: `{type:'transfer'}` | 写入 `type='transfer'`；stats 仅按 income/expense 分支，归入 expense | 非标准值不走 income 分支 |
| FIN-E-008 | 批量 Excel 导入 — 空文件 | POST `/api/finance/import` 上传空 .xlsx | imported=0 | |
| FIN-E-009 | 批量导入 — 非 Excel 文件 | POST `/import` 上传 .png | XLSX.read 报错 → 500 | |
| FIN-E-010 | 批量导入 — 空表头 | Excel 仅表头无数据 | rows.slice(1) 为空 → imported=0 | |
| FIN-E-011 | 老版本兼容路由 | GET `/api/finance/records` | 正常返回（兼容路由直接查加密字段，boy+隐私时返回 ***） | |
| FIN-E-012 | 老版本 POST records | POST `/api/finance/records` body: `{amount:50, type:'expense'}` | 直接存明文到 amount 字段（老表结构，新表无此字段可能报错） | ER_BAD_FIELD_ERROR 风险 |

---

## 5. 成就系统

> **关键文件**: `achievements.js`, `utils/lovegirl_rewards.js`
> **核心 API**: `GET /` → `POST /check`
> **内部逻辑**: `checkAchievements()` 由各模块联动触发（feeding/travel/mood/checkin 完成后）
> **种子成就**: travel(6), feeding(3), checkin(2), mood(1)

### 5.1 正常且结果正确

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| ACH-N-001 | 查询成就列表（新用户） | GET `/api/achievements` | 返回 12 条成就 seed；progress=0；unlocked=false；unlocked 计数=0 | 验证 list.length=12 |
| ACH-N-002 | 首次喂食完成解锁成就 | 下单 → 履约完成 → GET `/api/achievements` | `feeding_complete_1` unlocked=true；reward_beans=5 已发放；`bean_transactions` 有 `type='achievement_unlock'` | `SELECT * FROM user_achievements WHERE user_id=? AND achievement_id=(SELECT id FROM achievements WHERE code='feeding_complete_1');` |
| ACH-N-003 | 首个旅行打卡解锁 | 添加 1 个 visited 旅行点 → 触发 checkAchievements | `travel_checkin_1` unlocked；`love_timeline` 写入事件 | |
| ACH-N-004 | 手动触发成就检查 | POST `/api/achievements/check` body: `{category:'feeding'}` | 仅检查 feeding 类成就；返回新解锁成就列表 | |
| ACH-N-005 | 成就进度更新 | 已有 8 个喂食 → 再喂食 2 个（共 10） | `feeding_complete_10` 解锁；`feeding_complete_1` progress 更新但不重复发放 | `SELECT progress FROM user_achievements WHERE user_id=? AND achievement_id=?;` |
| ACH-N-006 | 跨类成就同时检查 | 全量调用 `checkAchievements(userId)` | 所有满足条件的成就一次性解锁；奖励分别发放 | 验证 user_achievements 新增行数 |
| ACH-N-007 | 旅行城市成就 | 打卡 3 个不同城市 | `travel_city_3` 解锁（progressForAchievement 走 `travel_city_progress`） | 验证 city 去重逻辑 |
| ACH-N-008 | 签到连续 7 天 | 连续 7 天每天签到 → 触发 checkAchievements | `checkin_7` 解锁 | `getCheckinStreak` 返回 7 |
| ACH-N-009 | 心情记录 30 条 | 添加 30 条 mood_diary → 触发 | `mood_record_30` 解锁 | |
| ACH-N-010 | 时间线沉淀 | 成就解锁后 | `love_timeline` 写入一条 `title='解锁成就：XXX'`, `icon='achievement'` | `SELECT * FROM love_timeline WHERE user_id=? AND source_module='achievement';` |

### 5.2 边界值

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| ACH-B-001 | progress 刚好等于 target | feeding_complete_10 的 target=10，progress=10 | 解锁触发 | `INSERT IGNORE` 写入 |
| ACH-B-002 | progress 略超 target | feeding_complete_1 target=1, progress=9（累积） | 因 `current < target` 为 false，不触发重复解锁 | `affectedRows===0` 仅 `UPDATE ... SET progress=GREATEST(progress,?)` |
| ACH-B-003 | 同时触发多个成就 | 第 10 个 feeding 完成时，feeding_complete_1 + feeding_complete_10 条件均满足 | feeding_complete_1 已解锁则跳过（INSERT IGNORE），feeding_complete_10 新解锁 | |
| ACH-B-004 | 奖励发放失败不应阻断 | awardBeans 抛出异常 | catch 后 `console.error` 但不影响其他成就循环 | 下一个成就继续检查 |
| ACH-B-005 | 旅行城市成就 — city 为空字符串 | travel_spots.city='' → `NULLIF(city,'')` 返回 NULL → `COUNT(DISTINCT NULL)` = 0 | 空 city 不计入统计 | |
| ACH-B-006 | 签到中断后成就 | 先签 6 天 → 断签 1 天 → 再签 7 天 | streak 重新从 1 开始；checkin_7 在 streak=7 时解锁 | `getCheckinStreak` 每日回退逻辑正确 |
| ACH-B-007 | 0 条记录时查询 | GET `/api/achievements`（数据库无任何活动记录） | 返回 12 条，progress=0 | |
| ACH-B-008 | category 过滤检查 | POST `/check` body: `{category:'mood'}` | 仅检查 mood 类成就；不触发 feeding/travel 等 | |

### 5.3 异常与非法输入

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| ACH-E-001 | 未登录 | 无 Token GET `/achievements` | HTTP 401 | |
| ACH-E-002 | 未登录 POST `/check` | 无 Token | HTTP 401 | |
| ACH-E-003 | userId=null 调用 checkAchievements | 内部调用 `checkAchievements(null)` | 提前返回 `[]`；不抛异常 | |
| ACH-E-004 | achievements 表不存在 | ensureAchievementsSeeded 时表不存在 | `INSERT ... ON DUPLICATE KEY UPDATE` 报错 → 可能 500 | |
| ACH-E-005 | user_achievements 表不存在 | checkAchievements 执行 INSERT IGNORE | 报错 500 | |
| ACH-E-006 | bean_transactions 写入被幂等拦截 | 同一 source_module + source_id 再次触发 | `addBeanTransaction` 检测到已存在 → return null；不重复发豆 | |
| ACH-E-007 | SQL 注入 category | POST `/check` body: `{category:"'; DROP TABLE--"}` | 参数化查询免疫 | |
| ACH-E-008 | 成就种子数据不存在 | `achievements` 表无数据 → GET `/` | `ensureAchievementsSeeded` 自动补种 → 返回正常列表 | |
| ACH-E-009 | 负面数与成就 | progressForAchievement 中负 travel count | `COUNT(*)` 不可能返回负数 | 安全 |

---

## 6. 版本更新检查

> **关键文件**: `version.js`
> **核心 API**: `GET /check` (公开), `GET /latest` (需认证)
> **核心逻辑**: version_code 整数比较；force_update 布尔判断；`is_active=1` 过滤

### 6.1 正常且结果正确

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| VER-N-001 | 客户端版本低于服务端 | GET `/api/version/check?version_code=100`（服务端最新=200） | `hasUpdate=true`, `needUpdate` 取决于 `force_update`；返回 `version.code/name/url/changelog/size` | 验证返回 JSON 字段完整性 |
| VER-N-002 | 客户端版本等于服务端 | GET `/check?version_code=200`（服务端最新=200） | `hasUpdate=false` | |
| VER-N-003 | 客户端版本高于服务端 | GET `/check?version_code=300`（服务端最新=200） | `hasUpdate=false`（`latest.version_code > clientCode` 为 false） | |
| VER-N-004 | force_update=1 且需更新 | GET `/check?version_code=100`（服务端 force_update=1, version_code=200） | `hasUpdate=true`, `needUpdate=true` | 强制更新判断 |
| VER-N-005 | force_update=0 且需更新 | GET `/check?version_code=100`（服务端 force_update=0, version_code=200） | `hasUpdate=true`, `needUpdate=false` | |
| VER-N-006 | 获取最新版本详情 | GET `/api/version/latest`（已认证） | HTTP 200；返回完整 `app_versions` 行 | |
| VER-N-007 | 无活跃版本 | `app_versions` 表 `is_active=1` 无记录 | `hasUpdate=false` | 不报错 |

### 6.2 边界值

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| VER-B-001 | version_code=0（新安装） | GET `/check?version_code=0` | `hasUpdate=true`（只要服务端有记录） | |
| VER-B-002 | 未传 version_code | GET `/check`（无参数） | `parseInt(undefined) → NaN → 0`；视为 version_code=0 | 默认行为 |
| VER-B-003 | version_code 负数 | GET `/check?version_code=-1` | `parseInt('-1') → -1`，服务端 version_code > -1 → hasUpdate=true | |
| VER-B-004 | version_code 极大值 | GET `/check?version_code=99999999` | hasUpdate=false | 不溢出 |
| VER-B-005 | version_code 字符串 | GET `/check?version_code=abc` | `parseInt('abc') → NaN → 0` | |
| VER-B-006 | version_code 浮点数 | GET `/check?version_code=1.5` | `parseInt('1.5') → 1` | 只取整数部分 |
| VER-B-007 | 多条 app_versions 活跃记录 | 手动插入两条 is_active=1 | `ORDER BY version_code DESC LIMIT 1` 取最大 version_code | |
| VER-B-008 | changelog 超长 | 版本变更日志很长（>10K） | 正常返回完整 changelog 字符串 | |

### 6.3 异常与非法输入

| 用例ID | 分类 | 输入 | 预期结果（含数据变化验证） | 验证 SQL / 验证方法 |
|--------|------|------|--------------------------|-------------------|
| VER-E-001 | 未登录访问 /latest | GET `/api/version/latest` 无 Token | HTTP 401 | authRequired 拦截 |
| VER-E-002 | /check 不限认证 | GET `/api/version/check` 无 Token | HTTP 200（公开接口） | 确认无 authRequired |
| VER-E-003 | SQL 注入 version_code | GET `/check?version_code=1;DROP TABLE app_versions;--` | `parseInt` 返回 NaN → 0；参数化查询免疫 | |
| VER-E-004 | app_versions 表不存在 | GET `/check` | 500 或 ER_NO_SUCH_TABLE 未被捕获 | 需检查是否有全局兜底 |
| VER-E-005 | DB 连接失败 | GET `/check`（DB 挂掉） | HTTP 500, `"Server error"` | catch 错误处理 |
| VER-E-006 | apk_url 包含特殊字符 | `apk_url` 含空格/中文 | 原样返回，由客户端处理 | |
| VER-E-007 | version_code 超大参数导致 DoS | GET `/check?version_code=1e308` | `parseInt('1e308')` 返回 1（科学计数 parseInt 只读到第一个非数字字符前） | 不崩溃 |

---

## 补充：跨模块联动验证矩阵

| 触发场景 | 期望联动 | 验证点 |
|----------|---------|--------|
| 履约完成 (feeding) | finance + timeline + bean(+1) + achievement check | 四表均有对应记录 |
| 成就解锁 (achievement) | bean(+reward) + timeline | 奖励发放 + 时间轴沉淀 |
| 伴侣解绑 (couple) | 前任 period 数据不可访问 | `WHERE user_id = req.user.id` 隔离 |
| 经期状态 (period) | 投喂站商品排序 | `annotatePeriodProducts` 中 `period_recommended` 排序 |
| 投喂下单 (feeding) | 爱心豆扣除 + transaction 记录 | `bean_transactions` type=feeding_order |

---

## 测试执行建议

1. **顺序**: 先执行正常用例，再边界值，最后异常用例
2. **事务隔离**: 每个异常用例测试后回滚或使用独立测试数据
3. **加密验证**: 经期 / 记账模块需在 SQL 层解密验证，不能仅看 API 返回
4. **并发测试**: FEED-E-016/017, COUP-E-010/011 需使用并发工具（如 JMeter / k6）
5. **幂等验证**: 投喂履约联动（finance/timeline/bean）均有 `source_module + source_id` 去重，需专项验证
*（内容由AI生成，仅供参考）*
*（内容由AI生成，仅供参考）*
