const { parseMedia } = require('../utils/media_access');

const sources = [
  ['photos', 'SELECT user_id, url, thumbnail_url FROM photos'],
  ['avatars', 'SELECT id AS user_id, avatar_url FROM users WHERE avatar_url IS NOT NULL'],
  ['creations', 'SELECT user_id, preview_url, source_urls FROM creative_works'],
  ['travel', 'SELECT user_id, url FROM travel_photos WHERE source_photo_id IS NULL'],
  ['kitchen', 'SELECT user_id, photo_url FROM kitchen_dishes WHERE photo_url IS NOT NULL'],
  ['kitchen', 'SELECT chef_id AS user_id, photo_url FROM cooking_logs WHERE photo_url IS NOT NULL'],
  ['kitchen', 'SELECT cook_id AS user_id, photo_url FROM kitchen_orders WHERE photo_url IS NOT NULL'],
  ['wardrobe', 'SELECT user_id, image_url, thumbnail_url, cutout_url FROM wardrobe_items'],
  ['wardrobe', 'SELECT user_id, image_url, thumbnail_url, cutout_url FROM wardrobe_avatars'],
  ['wardrobe', 'SELECT user_id, photo_url, thumbnail_url FROM wardrobe_outfits'],
];

function paths(row) {
  const { user_id, source_urls, ...fields } = row;
  const values = Object.values(fields);
  if (source_urls != null) {
    const urls = typeof source_urls === 'string' ? JSON.parse(source_urls) : source_urls;
    if (Array.isArray(urls)) values.push(...urls);
  }
  return values.map((value) => {
    if (typeof value !== 'string') return '';
    return value.replace(/^https?:\/\/47\.121\.119\.191:3001(?=\/uploads\/)/, '');
  });
}

async function legacyCandidates(pool) {
  const candidates = new Map();
  for (const [group, sql] of sources) {
    const [rows] = await pool.query(sql);
    for (const row of rows) {
      const owner = Number(row.user_id);
      if (!Number.isSafeInteger(owner) || owner <= 0) continue;
      for (const url of paths(row)) {
        const media = parseMedia(url);
        if (!media || media.ownerId != null || !(media.kind === group || media.kind === group + '/cutout')) continue;
        if (!candidates.has(url)) candidates.set(url, { owners: new Set(), kind: media.kind });
        candidates.get(url).owners.add(owner);
      }
    }
  }
  return candidates;
}

async function migrateMedia(pool) {
  const candidates = await legacyCandidates(pool);
  await pool.query(`CREATE TABLE IF NOT EXISTS legacy_media_owners (
    path VARCHAR(220) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
    user_id INT NOT NULL,
    kind VARCHAR(24) NOT NULL
  ) ENGINE=InnoDB`);
  let ambiguous = 0;
  for (const [url, { owners, kind }] of candidates) {
    if (owners.size !== 1) {
      ambiguous++;
      continue;
    }
    await pool.query('INSERT IGNORE INTO legacy_media_owners (path, user_id, kind) VALUES (?, ?, ?)',
      [url, owners.values().next().value, kind]);
  }
  return { mapped: candidates.size - ambiguous, ambiguous };
}

module.exports = migrateMedia;
module.exports.legacyCandidates = legacyCandidates;

if (require.main === module) {
  const pool = require('../config/database');
  migrateMedia(pool).then((counts) => console.log(counts)).catch((error) => {
    console.error('[Media migration]', error.code || error.name);
    process.exitCode = 1;
  }).finally(() => pool.end());
}
