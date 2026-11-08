const express = require('express');
const pool = require('../config/database');
const { authRequired } = require('../middleware/auth');
const { errorResponse } = require('../utils/creation_access');
const { fail, integer, json } = require('../utils/creation_contract');
const router = express.Router();
const categories = new Set(['clothes', 'toiletries', 'documents', 'electronics', 'other']);

function id(value, label) { return integer(value, 1, 2147483647, label); }
function text(value, max, label) {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > max) fail(label);
  return value.trim();
}

async function pair(db, userId, lock = false) {
  const args = [userId, userId];
  const [rows] = lock
    ? await db.query("SELECT id,user1_id,user2_id,preparation_epoch FROM couples WHERE (user1_id=? OR user2_id=?) AND status='active' LIMIT 1 FOR SHARE", args)
    : await db.query("SELECT id,user1_id,user2_id,preparation_epoch FROM couples WHERE (user1_id=? OR user2_id=?) AND status='active' LIMIT 1", args);
  return rows[0] || null;
}

function members(userId, relationship) {
  return relationship ? [relationship.user1_id, relationship.user2_id] : [userId, userId];
}

async function trip(db, tripId, userId, relationship, lock = false) {
  const args = [tripId, ...members(userId, relationship)];
  const [rows] = lock
    ? await db.query("SELECT t.id,t.title,DATE_FORMAT(t.start_date,'%Y-%m-%d') AS startDate,DATE_FORMAT(t.end_date,'%Y-%m-%d') AS endDate,s.plan_json FROM travel_trips t LEFT JOIN travel_itinerary_state s ON s.trip_id=t.id WHERE t.id=? AND t.user_id IN (?,?) FOR UPDATE", args)
    : await db.query("SELECT t.id,t.title,DATE_FORMAT(t.start_date,'%Y-%m-%d') AS startDate,DATE_FORMAT(t.end_date,'%Y-%m-%d') AS endDate,s.plan_json FROM travel_trips t LEFT JOIN travel_itinerary_state s ON s.trip_id=t.id WHERE t.id=? AND t.user_id IN (?,?)", args);
  if (!rows.length) return null;
  const row = rows[0];
  const legacyDays = row.startDate && row.endDate
    ? Math.round((new Date(row.endDate) - new Date(row.startDate)) / 86400000) + 1 : 1;
  return { id: row.id, title: row.title, startDate: row.startDate, days: Math.max(1, Math.min(90, json(row.plan_json, {}).days || legacyDays)) };
}

async function stored(db, tripId, scope, scopeId, epoch) {
  const [rows] = await db.query(
    'SELECT *,DATE_FORMAT(trip_start,\'%Y-%m-%d\') AS startDate FROM travel_preparation WHERE trip_id=? AND scope=? AND scope_id=? AND epoch=?',
    [tripId, scope, scopeId, epoch]
  );
  return rows[0] || null;
}

function itemsFrom(body, allowedAssignees) {
  if (!Array.isArray(body.items) || body.items.length > 120) fail('每份清单最多120项');
  const keys = new Set();
  return body.items.map(item => {
    if (!item || typeof item !== 'object') fail('行李项目不正确');
    const key = text(item.key, 64, '行李标识不正确');
    if (!/^[A-Za-z0-9_-]{8,64}$/.test(key) || keys.has(key)) fail('行李标识重复或不正确');
    keys.add(key);
    if (!categories.has(item.category) || typeof item.packed !== 'boolean') fail('分类或装包状态不正确');
    const assigneeId = item.assigneeId == null ? null : id(item.assigneeId, '携带人不正确');
    if (assigneeId != null && !allowedAssignees.includes(assigneeId)) fail('携带人不属于当前共同清单', 403);
    return { key, label: text(item.label, 100, '请填写不超过100字的物品名称'), category: item.category, packed: item.packed, assigneeId };
  });
}

async function wardrobe(db, userId, outfitIds, itemIds) {
  const [outfits] = outfitIds.length ? await db.query(
    'SELECT id,item_ids,note,photo_url,thumbnail_url FROM wardrobe_outfits WHERE user_id=? AND id IN (?)', [userId, outfitIds]) : [[]];
  const memberIds = outfits.flatMap(row => json(row.item_ids, []));
  const ids = [...new Set([...itemIds, ...memberIds])];
  const [items] = ids.length ? await db.query(
    'SELECT id,category,brand,color,thumbnail_url,image_url,status,deleted_at FROM wardrobe_items WHERE user_id=? AND id IN (?)', [userId, ids]) : [[]];
  return { outfits: new Map(outfits.map(row => [row.id, row])), items: new Map(items.map(row => [row.id, row])) };
}

function itemView(row, fallback) {
  const available = row && !row.deleted_at && row.status === '在柜';
  return { id: row?.id ?? fallback.id, label: row ? [row.color, row.category, row.brand].filter(Boolean).join(' ') : fallback.label,
    imageUrl: available ? row.thumbnail_url || row.image_url : null, available: !!available };
}

function outfitView(selection, source) {
  const outfit = source.outfits.get(selection.outfitId);
  const ids = selection.outfitId ? (outfit ? json(outfit.item_ids, []) : selection.snapshot.items.map(item => item.id)) : selection.itemIds;
  const old = new Map(selection.snapshot.items.map(item => [item.id, item]));
  const items = ids.map(id => itemView(source.items.get(id), old.get(id) || { id, label: '衣物已不可用' }));
  return { ...selection, label: outfit ? outfit.note || '衣橱搭配' : selection.snapshot.label,
    imageUrl: outfit ? outfit.thumbnail_url || outfit.photo_url : null,
    available: selection.outfitId ? !!outfit : items.some(item => item.available), items };
}

async function outfitsFrom(db, body, previous, userId, days) {
  if (!Array.isArray(body.outfits) || body.outfits.length > 90) fail('每日搭配格式不正确');
  const selectedDays = new Set();
  const old = new Map(previous.map(selection => [selection.day, selection]));
  const selections = body.outfits.map(selection => {
    if (!selection || typeof selection !== 'object') fail('搭配格式不正确');
    const day = integer(selection.day, 0, 89, '搭配所属天数不正确');
    if (selectedDays.has(day)) fail('同一天只能保存一份搭配');
    selectedDays.add(day);
    const outfitId = selection.outfitId == null ? null : id(selection.outfitId, '搭配不正确');
    const itemIds = selection.itemIds ?? [];
    if (!Array.isArray(itemIds) || itemIds.length > 8 || (outfitId ? itemIds.length !== 0 : itemIds.length === 0)) fail('请选择一套搭配或1至8件衣物');
    const normalized = itemIds.map(value => id(value, '衣物编号不正确'));
    if (new Set(normalized).size !== normalized.length) fail('请勿重复选择衣物');
    const existing = old.get(day);
    if (existing && existing.outfitId === outfitId && JSON.stringify(existing.itemIds) === JSON.stringify(normalized)) return existing;
    if (day >= days) fail('该天已移出当前行程，请调整日期后再选搭配', 409);
    return { day, outfitId, itemIds: normalized };
  });
  const added = selections.filter(selection => !selection.snapshot);
  const source = await wardrobe(db, userId, added.map(selection => selection.outfitId).filter(Boolean), added.flatMap(selection => selection.itemIds));
  for (const selection of added) {
    const outfit = source.outfits.get(selection.outfitId);
    if (selection.outfitId && !outfit) fail('搭配已不可用或不属于本人', 403);
    const ids = outfit ? json(outfit.item_ids, []) : selection.itemIds;
    const items = ids.map(itemId => itemView(source.items.get(itemId), { id: itemId, label: '衣物已不可用' }));
    if (!outfit && items.some(item => !item.available)) fail('部分衣物已不可用或不属于本人', 403);
    selection.snapshot = { label: outfit ? outfit.note || '衣橱搭配' : '自选衣物', items: items.map(item => ({ id: item.id, label: item.label })) };
  }
  return selections.sort((a, b) => a.day - b.day);
}

async function view(db, row, userId, days) {
  const doc = json(row?.document, { items: [], outfits: [] });
  const outfits = doc.outfits || [];
  const source = await wardrobe(db, userId, outfits.map(o => o.outfitId).filter(Boolean), outfits.flatMap(o => o.snapshot.items.map(item => item.id)));
  return { revision: row?.revision || 0, items: doc.items,
    outfits: outfits.map(selection => ({ ...outfitView(selection, source), outsideTrip: selection.day >= days })) };
}

router.get('/archives', authRequired, async (req, res) => {
  try {
    const userId = req.user.id, relationship = await pair(pool, userId);
    const [rows] = await pool.query(
      "SELECT p.trip_id AS id,p.trip_title AS title FROM travel_preparation p LEFT JOIN travel_trips t ON t.id=p.trip_id AND t.user_id IN (?,?) WHERE t.id IS NULL AND ((p.scope='private' AND p.scope_id=? AND p.epoch=0) OR (p.scope='shared' AND p.scope_id=? AND p.epoch=?)) ORDER BY p.updated_at DESC,p.trip_id DESC LIMIT 200",
      [...members(userId, relationship), userId, relationship?.id ?? null, relationship?.preparation_epoch ?? null]);
    const unique = new Map();
    for (const row of rows) if (!unique.has(row.id)) unique.set(row.id, row);
    res.json({ code: 200, data: [...unique.values()].slice(0, 100) });
  } catch (error) { errorResponse(res, error); }
});

router.get('/:id', authRequired, async (req, res) => {
  try {
    const tripId = id(req.params.id, '行程编号不正确'), userId = req.user.id;
    const relationship = await pair(pool, userId);
    const current = await trip(pool, tripId, userId, relationship);
    const own = await stored(pool, tripId, 'private', userId, 0);
    const shared = relationship ? await stored(pool, tripId, 'shared', relationship.id, relationship.preparation_epoch) : null;
    const archived = own || shared;
    if (!current && !archived) fail('准备记录不可见或不存在', 404);
    const info = current || { id: tripId, title: archived.trip_title, startDate: archived.startDate, days: archived.trip_days };
    const [people] = relationship ? await pool.query('SELECT id,nickname FROM users WHERE id IN (?,?)', members(userId, relationship)) : [[]];
    res.json({ code: 200, data: { trip: info, archived: !current, people,
      relationshipKey: relationship ? `${relationship.id}:${relationship.preparation_epoch}` : null,
      mine: await view(pool, own, userId, info.days), shared: relationship ? await view(pool, shared, userId, info.days) : null } });
  } catch (error) { errorResponse(res, error); }
});

router.put('/:id/:scope', authRequired, async (req, res) => {
  let conn;
  try {
    const tripId = id(req.params.id, '行程编号不正确'), userId = req.user.id, scope = req.params.scope;
    if (!['private', 'shared'].includes(scope)) fail('清单范围不正确');
    const body = req.body || {};
    const revision = integer(body.revision, 0, 2147483646, '请携带清单版本');
    conn = await pool.getConnection(); await conn.beginTransaction();
    const relationship = await pair(conn, userId, true);
    if (scope === 'shared' && !relationship) fail('请先绑定伴侣再准备共同物品', 403);
    if (scope === 'shared' && body.relationshipKey !== `${relationship.id}:${relationship.preparation_epoch}`) {
      fail('绑定关系已变化，请读取新的共同清单', 409);
    }
    const current = await trip(conn, tripId, userId, relationship, true);
    if (!current) fail('行程已取消或不可见，准备记录保留为归档', 409);
    const scopeId = scope === 'private' ? userId : relationship.id;
    const epoch = scope === 'private' ? 0 : relationship.preparation_epoch;
    const previous = await stored(conn, tripId, scope, scopeId, epoch);
    if (revision !== (previous?.revision || 0)) fail('这份清单已更新，请读取最新版本', 409);
    const items = itemsFrom(body, scope === 'shared' ? members(userId, relationship) : []);
    if (scope === 'shared' && body.outfits?.length) fail('每日搭配属于个人准备', 403);
    const outfits = scope === 'private' ? await outfitsFrom(conn, body, json(previous?.document, {}).outfits || [], userId, current.days) : [];
    const doc = { items, outfits };
    if (previous) {
      await conn.query('UPDATE travel_preparation SET revision=revision+1,trip_title=?,trip_days=?,trip_start=?,document=? WHERE trip_id=? AND scope=? AND scope_id=? AND epoch=?',
        [current.title, current.days, current.startDate, JSON.stringify(doc), tripId, scope, scopeId, epoch]);
    } else {
      await conn.query('INSERT INTO travel_preparation (trip_id,scope,scope_id,epoch,revision,trip_title,trip_days,trip_start,document) VALUES (?,?,?,?,1,?,?,?,?)',
        [tripId, scope, scopeId, epoch, current.title, current.days, current.startDate, JSON.stringify(doc)]);
    }
    const result = await view(conn, { revision: revision + 1, document: doc }, userId, current.days);
    await conn.commit();
    res.json({ code: 200, data: result });
  } catch (error) {
    if (conn) { try { await conn.rollback(); } catch (_) {} }
    errorResponse(res, error);
  } finally { conn?.release(); }
});

module.exports = router;
