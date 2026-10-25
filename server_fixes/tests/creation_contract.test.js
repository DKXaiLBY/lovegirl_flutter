const test = require('node:test');
const assert = require('node:assert/strict');
const contract = require('../utils/creation_contract');
const { visibleIds, slots } = require('../utils/creation_access');

const work = () => ({
  kind: 'polaroid', templateId: 'classic', lookId: 'instant_clear',
  title: '海边，和你', date: '2026-10-24', transforms: [{ scale: 1, x: 0, y: 0 }],
  frontInk: [{ width: 0.006, color: 0xff111111, points: [[0.1, 0.85], [0.8, 0.9]] }],
});
const plan = () => ({
  title: '上海两日', days: 2, startDate: '2026-10-24', endDate: '2026-10-25',
  stops: [
    { key: 'one', spotId: 37, day: 0, mode: 'walking', note: '傍晚去' },
    { key: 'two', spotId: 38, day: null, mode: 'transit' },
  ],
});
const invalid = fn => assert.throws(fn, error => error.status === 400);

test('catalog counts refer to independent paper, look and ticket identifiers', () => {
  assert.equal(new Set(contract.PAPERS).size, 20);
  assert.equal(new Set(contract.LOOKS).size, 12);
  assert.equal(new Set(contract.TICKETS).size, 8);
});
test('paper-margin handwriting and crop survive canonical JSON round trip', () => {
  const original = work();
  original.transforms[0] = { scale: 1.8, x: -0.3, y: 0.2 };
  const saved = contract.document(JSON.stringify(original));
  assert.deepEqual(saved.frontInk, original.frontInk);
  assert.deepEqual(contract.document(JSON.stringify(saved)), saved);
  assert.equal(saved.title, original.title);
});
test('templates cannot be confused with image processing looks', () => {
  invalid(() => contract.document({ ...work(), lookId: 'classic' }));
  invalid(() => contract.document({ ...work(), kind: 'ticket', templateId: 'classic' }));
  assert.equal(contract.document({ ...work(), kind: 'ticket', templateId: 'couple', transforms: [{}, {}] }).kind, 'ticket');
});
test('two-photo tickets reject missing sources and polaroids stay single-shot', () => {
  invalid(() => contract.document({ ...work(), kind: 'ticket', templateId: 'couple' }));
  invalid(() => contract.document({ ...work(), transforms: [{}, {}] }));
});

test('invalid dates, crop limits and nonfinite inputs are rejected', () => {
  invalid(() => contract.document({ ...work(), date: '2026-02-30' }));
  invalid(() => contract.document({ ...work(), intensity: NaN }));
  invalid(() => contract.document({ ...work(), transforms: [{ scale: 6 }] }));
  invalid(() => contract.document({ ...work(), transforms: [{ x: Infinity }] }));
});
test('invalid ink cannot escape the canvas or exceed bounded work size', () => {
  invalid(() => contract.document({ ...work(), frontInk: [{ width: 0.006, color: 0, points: [[1.2, 0.4]] }] }));
  invalid(() => contract.document({ ...work(), frontInk: [{ width: 0, color: 0, points: [[0.1, 0.4]] }] }));
  invalid(() => contract.document({ ...work(), frontInk: [{ width: 0.006, color: 0, points: Array(20001).fill([0.1, 0.4]) }] }));
});
test('an empty new journey is valid and unplanned stops stay unplanned', () => {
  assert.equal(contract.itinerary({ ...plan(), stops: [] }).stops.length, 0);
  assert.equal(contract.itinerary(plan()).stops[1].day, null);
});
test('reordering preserves stop identity, explicit mode and notes', () => {
  const data = plan();
  data.stops.reverse();
  const saved = contract.itinerary(data);
  assert.equal(saved.stops[0].key, 'two');
  assert.equal(saved.stops[0].mode, 'transit');
  assert.equal(saved.stops[1].note, '傍晚去');
});
test('date length, invalid day, duplicate stop keys and modes are validated', () => {
  invalid(() => contract.itinerary({ ...plan(), days: 3 }));
  invalid(() => contract.itinerary({ ...plan(), endDate: null }));
  invalid(() => contract.itinerary({ ...plan(), stops: [{ key: 'one', spotId: 37, day: 2 }] }));
  invalid(() => contract.itinerary({ ...plan(), stops: [plan().stops[0], plan().stops[0]] }));
  invalid(() => contract.itinerary({ ...plan(), stops: [{ key: 'one', spotId: 37, mode: 'teleport' }] }));
});
test('the same place can appear on separate days with independent stop keys', () => {
  const data = plan();
  data.stops[1] = { key: 'return', spotId: 37, day: 1, mode: 'driving' };
  assert.equal(contract.itinerary(data).stops.length, 2);
});
test('sharing uses current active partner and never widens on database failure', async () => {
  assert.deepEqual(await visibleIds({ query: async () => [[{ partner_id: 32 }]] }, 33), [33, 32]);
  assert.deepEqual(await visibleIds({ query: async () => [[]] }, 33), [33]);
  await assert.rejects(visibleIds({ query: async () => { throw new Error('offline'); } }, 33));
  assert.deepEqual(slots([33, 32]), [33, 32, null, null, null, null, null, null]);
});
