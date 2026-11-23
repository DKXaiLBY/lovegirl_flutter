const { createHash, randomBytes } = require('node:crypto');

const lifetimeSeconds = 86400;

class RegistrationError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function hashCode(code) {
  const normalized = typeof code === 'string'
    ? code.trim().toUpperCase().replace(/[- ]/g, '')
    : '';
  if (!/^[A-F0-9]{24}$/.test(normalized)) {
    throw new RegistrationError(400, '请输入有效的注册邀请码');
  }
  return createHash('sha256').update(normalized).digest('hex');
}

async function inTransaction(pool, run) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const result = await run(conn);
    await conn.commit();
    return result;
  } catch (error) {
    await conn.rollback();
    throw error;
  } finally {
    conn.release();
  }
}

async function issue(pool, issuerId) {
  const code = randomBytes(12).toString('hex').toUpperCase();
  const hash = hashCode(code);
  return inTransaction(pool, async (conn) => {
    const [issuer] = await conn.query(
      'SELECT id FROM users WHERE id = ? AND is_admin = 1 FOR UPDATE', [issuerId]
    );
    if (issuer.length !== 1) throw new RegistrationError(403, '需要管理员生成注册邀请码');
    await conn.query(
      'UPDATE registration_invites SET revoked_at = UTC_TIMESTAMP() WHERE issuer_id = ? AND revoked_at IS NULL AND used_at IS NULL',
      [issuerId]
    );
    await conn.query(
      'INSERT INTO registration_invites (issuer_id, code_hash, expires_at) VALUES (?, ?, TIMESTAMPADD(SECOND, ?, UTC_TIMESTAMP()))',
      [issuerId, hash, lifetimeSeconds]
    );
    return { code, expiresIn: lifetimeSeconds };
  });
}

function readFields(body) {
  const value = body && typeof body === 'object' ? body : {};
  const username = typeof value.username === 'string' ? value.username.trim() : '';
  const nickname = typeof value.nickname === 'string' ? value.nickname.trim() : '';
  const password = typeof value.password === 'string' ? value.password : '';
  if (username.length < 2 || username.length > 50) throw new RegistrationError(400, '用户名需要填写 2 至 50 个字符');
  if (!nickname || nickname.length > 20) throw new RegistrationError(400, '昵称需要填写 1 至 20 个字符');
  if (password.length < 6) throw new RegistrationError(400, '密码至少需要 6 个字符');
  if (Buffer.byteLength(password, 'utf8') > 72) throw new RegistrationError(400, '密码太长，请缩短后再试');
  if (!['male', 'female'].includes(value.gender)) throw new RegistrationError(400, '请选择性别');
  return { username, nickname, password, gender: value.gender, codeHash: hashCode(value.inviteCode) };
}

async function register(pool, bcrypt, body) {
  const fields = readFields(body);
  const { username, nickname, password, gender, codeHash } = fields;
  const invalidInvite = '注册码无效、已过期或已使用，请让对方重新生成';
  const [eligible] = await pool.query(
    'SELECT id FROM registration_invites WHERE code_hash = ? AND used_at IS NULL AND revoked_at IS NULL AND expires_at > UTC_TIMESTAMP()',
    [codeHash]
  );
  if (eligible.length !== 1) throw new RegistrationError(400, invalidInvite);
  const passwordHash = await bcrypt.hash(password, 10);
  return inTransaction(pool, async (conn) => {
    const [invites] = await conn.query(
      'SELECT id FROM registration_invites WHERE code_hash = ? AND used_at IS NULL AND revoked_at IS NULL AND expires_at > UTC_TIMESTAMP() FOR UPDATE',
      [codeHash]
    );
    if (invites.length !== 1) throw new RegistrationError(400, invalidInvite);
    const role = gender === 'male' ? 'boy' : 'girl';
    let result;
    try {
      [result] = await conn.query(
        'INSERT INTO users (username, password_hash, nickname, role, gender, is_admin) VALUES (?, ?, ?, ?, ?, 0)',
        [username, passwordHash, nickname, role, gender]
      );
    } catch (error) {
      if (error.code === 'ER_DUP_ENTRY') throw new RegistrationError(409, '这个用户名已注册，请换一个');
      throw error;
    }
    await conn.query('INSERT INTO themes (user_id) VALUES (?)', [result.insertId]);
    await conn.query(
      'INSERT INTO user_privacy (user_id, photo_visible, mood_visible, travel_visible, chat_visible) VALUES (?, 0, 0, 1, 1)',
      [result.insertId]
    );
    await conn.query(
      'UPDATE registration_invites SET used_at = UTC_TIMESTAMP(), used_by = ? WHERE id = ?',
      [result.insertId, invites[0].id]
    );
    return { id: result.insertId, username, nickname, role, gender, isAdmin: false };
  });
}

module.exports = { issue, register, RegistrationError };
