const PAPERS = [
  'classic', 'carbon', 'cotton', 'linen', 'pearl', 'frost', 'blue_split',
  'sage_edge', 'rose_corner', 'peel_white', 'peel_black', 'clear', 'silver',
  'film', 'letter', 'postmark', 'archive', 'tape', 'wave', 'fold',
];
const TICKETS = ['landscape', 'portrait', 'postcard', 'filmstrip', 'couple', 'datestamp', 'boarding', 'route'];
const LOOKS = [
  'instant_clear', 'instant_soft', 'instant_flash', 'ccd_cool', 'ccd_pop',
  'ccd_faded', 'film_day', 'film_warm', 'film_grain', 'bw_soft', 'bw_contrast', 'bw_grain',
];
const MODES = ['walking', 'bicycling', 'driving', 'transit'];

function fail(message, status = 400) {
  const error = new Error(message);
  error.status = status;
  throw error;
}
function text(value, max) { return String(value ?? '').trim().slice(0, max); }
function integer(value, min, max, label) {
  const result = Number(value);
  if (!Number.isInteger(result) || result < min || result > max) fail(label);
  return result;
}
function date(value) {
  if (value == null || value === '') return null;
  const result = String(value).slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(result)) fail('日期格式不正确');
  const parsed = new Date(`${result}T00:00:00Z`);
  if (!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== result) fail('日期不存在');
  return result;
}
function json(value, fallback) {
  if (value == null) return fallback;
  if (typeof value !== 'string') return value;
  try { return JSON.parse(value); } catch (_) { fail('保存的数据格式不正确'); }
}
function strokes(value) {
  if (!Array.isArray(value) || value.length > 800) fail('笔迹过多，请先保存一份');
  let total = 0;
  return value.map(stroke => {
    if (!stroke || !Array.isArray(stroke.points) || !stroke.points.length) fail('笔迹格式不正确');
    total += stroke.points.length;
    if (total > 20000) fail('笔迹过多，请先保存一份');
    const width = Number(stroke.width);
    if (!Number.isFinite(width) || width < 0.0005 || width > 0.1) fail('画笔宽度不正确');
    return {
      width,
      color: integer(stroke.color, 0, 0xffffffff, '画笔颜色不正确'),
      points: stroke.points.map(point => {
        if (!Array.isArray(point) || point.length !== 2 || point.some(v => !Number.isFinite(v) || v < 0 || v > 1)) fail('笔迹坐标不正确');
        return point;
      }),
    };
  });
}
function document(value) {
  const data = json(value, {});
  if (!data || !['polaroid', 'ticket'].includes(data.kind)) fail('作品类型不正确');
  const templates = data.kind === 'ticket' ? TICKETS : PAPERS;
  if (!templates.includes(data.templateId) || !LOOKS.includes(data.lookId)) fail('请选择可用的样式');
  const intensity = Number(data.intensity ?? 1);
  if (!Number.isFinite(intensity) || intensity < 0 || intensity > 1) fail('成像强度不正确');
  if (!Array.isArray(data.transforms) || data.transforms.length < 1 || data.transforms.length > 8) fail('请选择照片');
  if (data.kind === 'polaroid' && data.transforms.length !== 1) fail('拍立得需要一张照片');
  if (data.kind === 'ticket' && ['couple', 'filmstrip'].includes(data.templateId) && data.transforms.length !== 2) fail('这个票根版式需要两张照片');
  const result = {
    schema: 1, kind: data.kind, templateId: data.templateId, lookId: data.lookId,
    intensity, title: text(data.title, 100), note: text(data.note, 2000),
    date: date(data.date),
    accent: integer(data.accent ?? 0xff7d899b, 0, 0xffffffff, '配色不正确'),
    background: integer(data.background ?? 0xffeef0f3, 0, 0xffffffff, '背景色不正确'),
    gradient: data.gradient === true,
    frontInk: strokes(data.frontInk ?? []), backInk: strokes(data.backInk ?? []),
    transforms: data.transforms.map(transform => {
      const scale = Number(transform.scale ?? 1);
      const x = Number(transform.x ?? 0);
      const y = Number(transform.y ?? 0);
      if (![scale, x, y].every(Number.isFinite) || scale < 1 || scale > 5 || Math.abs(x) > 2 || Math.abs(y) > 2) fail('照片裁切参数不正确');
      return { scale, x, y };
    }),
  };
  if (JSON.stringify(result).length > 600000) fail('作品内容过大');
  return result;
}
function itinerary(value) {
  const data = json(value, {});
  const startDate = date(data.startDate);
  const endDate = date(data.endDate);
  const days = integer(data.days ?? 1, 1, 90, '行程天数应为1至90天');
  if ((startDate == null) !== (endDate == null)) fail('请选择完整日期');
  if (startDate && (new Date(endDate) - new Date(startDate)) / 86400000 !== days - 1) fail('行程日期与天数不一致');
  const title = text(data.title, 100);
  if (!title) fail('请输入行程名称');
  if (!Array.isArray(data.stops) || data.stops.length > 500) fail('每份行程最多500个地点');
  const keys = new Set();
  const stops = data.stops.map(stop => {
    const key = text(stop.key, 80);
    if (!/^[a-zA-Z0-9_-]+$/.test(key) || keys.has(key)) fail('行程地点标识不正确');
    keys.add(key);
    if (!MODES.includes(stop.mode ?? 'driving')) fail('交通方式不正确');
    return {
      key, spotId: integer(stop.spotId, 1, 2147483647, '地点不正确'),
      day: stop.day == null ? null : integer(stop.day, 0, days - 1, '地点所属日期不正确'),
      mode: stop.mode ?? 'driving', note: text(stop.note, 1000),
    };
  });
  return { title, city: text(data.city, 50), description: text(data.description, 2000), startDate, endDate, days, stops };
}

module.exports = { PAPERS, TICKETS, LOOKS, MODES, fail, text, integer, date, json, document, itinerary };
