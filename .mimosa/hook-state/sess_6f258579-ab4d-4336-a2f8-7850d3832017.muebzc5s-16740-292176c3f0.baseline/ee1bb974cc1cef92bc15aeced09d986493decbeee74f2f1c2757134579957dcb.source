const crypto = require('crypto');

const SECRET =
  process.env.DATA_ENCRYPTION_KEY ||
  process.env.ENCRYPTION_KEY ||
  process.env.APP_SECRET ||
  'lovegirl-dev-encryption-key';

const KEY = crypto.createHash('sha256').update(String(SECRET)).digest();
const IV_LENGTH = 12;

function encrypt(value) {
  const plainText = value == null ? '' : String(value);
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv('aes-256-gcm', KEY, iv);
  const encrypted = Buffer.concat([
    cipher.update(plainText, 'utf8'),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  return `${iv.toString('hex')}:${tag.toString('hex')}:${encrypted.toString('hex')}`;
}

function decrypt(payload) {
  if (payload == null || payload === '') return '';
  if (typeof payload !== 'string' || !payload.includes(':')) {
    return String(payload);
  }

  const [ivHex, tagHex, encryptedHex] = payload.split(':');
  if (!ivHex || !tagHex || !encryptedHex) {
    throw new Error('invalid encrypted payload');
  }

  const decipher = crypto.createDecipheriv(
    'aes-256-gcm',
    KEY,
    Buffer.from(ivHex, 'hex')
  );
  decipher.setAuthTag(Buffer.from(tagHex, 'hex'));

  const decrypted = Buffer.concat([
    decipher.update(Buffer.from(encryptedHex, 'hex')),
    decipher.final(),
  ]);

  return decrypted.toString('utf8');
}

module.exports = {
  encrypt,
  decrypt,
};
