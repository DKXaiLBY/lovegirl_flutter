const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const code = fs.readFileSync(path.join(__dirname, '../travel.js'), 'utf8');
const begin = code.indexOf('function parseAmapPath(');
const end = code.indexOf("router.get('/amap/poi'", begin);
const context = {};
vm.runInNewContext(`${code.slice(begin, end)}; this.normalize = normalizeDirection;`, context);
const normalize = context.normalize;
const step = { distance: '300', duration: '120', polyline: '121.490000,31.220000;121.491000,31.221000' };

test('v4 bicycling payload retains cycling identity and actual path', () => {
  const result = normalize('bicycling', { errcode: 0, data: { paths: [{ distance: 300, duration: 120, steps: [step] }] } });
  assert.equal(result.mode, 'bicycling');
  assert.equal(result.distance, 300);
  assert.equal(result.path[0].lat, 31.22);
  assert.equal(result.path[1].lng, 121.491);
});
test('v3 walking and driving parse their own returned distance and time', () => {
  for (const mode of ['walking', 'driving']) {
    const result = normalize(mode, { route: { paths: [{ distance: '300', duration: '120', steps: [step] }] } });
    assert.equal(result.mode, mode);
    assert.equal(result.duration, 120);
  }
});
test('transit includes walking connectors and bus geometry', () => {
  const result = normalize('transit', { route: { transits: [{ distance: '600', duration: '360', segments: [{ walking: { steps: [step] }, bus: { buslines: [{ name: '公交1路', polyline: step.polyline }] } }] }] } });
  assert.equal(result.mode, 'transit');
  assert.equal(result.path.length, 4);
  assert.equal(result.steps[0].instruction, '公交1路');
});
test('missing routes produce a visible failure instead of a fake zero-distance route', () => {
  for (const mode of ['walking', 'bicycling', 'driving', 'transit']) {
    assert.throws(() => normalize(mode, {}), error => error.status === 422);
  }
});
