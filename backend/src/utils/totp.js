const crypto = require('crypto');

const BASE32_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const BACKUP_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/**
 * Encodes a Buffer into an unpadded RFC 4648 Base32 string.
 */
function base32Encode(buffer) {
    let bits = 0;
    let value = 0;
    let output = '';
    for (let i = 0; i < buffer.length; i++) {
        value = (value << 8) | buffer[i];
        bits += 8;
        while (bits >= 5) {
            output += BASE32_ALPHABET[(value >>> (bits - 5)) & 31];
            bits -= 5;
        }
    }
    if (bits > 0) {
        output += BASE32_ALPHABET[(value << (5 - bits)) & 31];
    }
    return output;
}

/**
 * Decodes an RFC 4648 Base32 string (ignoring spaces, hyphens, and '=' padding) into a Buffer.
 */
function base32Decode(secret) {
    const cleaned = String(secret || '')
        .toUpperCase()
        .replace(/[\s=-]+/g, '');
    let bits = 0;
    let value = 0;
    const bytes = [];
    for (let i = 0; i < cleaned.length; i++) {
        const idx = BASE32_ALPHABET.indexOf(cleaned[i]);
        if (idx === -1) {
            throw new Error(`Invalid Base32 character: ${cleaned[i]}`);
        }
        value = (value << 5) | idx;
        bits += 5;
        if (bits >= 8) {
            bytes.push((value >>> (bits - 8)) & 0xff);
            bits -= 8;
        }
    }
    return Buffer.from(bytes);
}

/**
 * Generates a cryptographically random Base32 TOTP secret (default 20 bytes -> 32 Base32 chars).
 */
function generateSecret(numBytes = 20) {
    return base32Encode(crypto.randomBytes(numBytes));
}

/**
 * Generates an RFC 6238 TOTP code (HMAC-SHA1, 30s period, 6 digits).
 */
function generateTotp(secret, { step = 30, digits = 6, windowOffset = 0, timestampMs = Date.now() } = {}) {
    const key = base32Decode(secret);
    const counter = Math.floor(timestampMs / 1000 / step) + windowOffset;

    const counterBuf = Buffer.alloc(8);
    // Write 64-bit unsigned integer big-endian
    const high = Math.floor(counter / 0x100000000);
    const low = counter >>> 0;
    counterBuf.writeUInt32BE(high, 0);
    counterBuf.writeUInt32BE(low, 4);

    const hmac = crypto.createHmac('sha1', key).update(counterBuf).digest();
    const offset = hmac[hmac.length - 1] & 0x0f;
    const binary =
        ((hmac[offset] & 0x7f) << 24) |
        ((hmac[offset + 1] & 0xff) << 16) |
        ((hmac[offset + 2] & 0xff) << 8) |
        (hmac[offset + 3] & 0xff);

    const otp = binary % Math.pow(10, digits);
    return String(otp).padStart(digits, '0');
}

/**
 * Verifies a 6-digit TOTP code against [secret] within [-window, +window] time steps
 * using constant-time comparison.
 */
function verifyTotp(secret, code, { window = 1, step = 30, digits = 6, timestampMs = Date.now() } = {}) {
    if (!secret || !code) return false;
    const cleanCode = String(code).replace(/\D/g, '');
    if (cleanCode.length !== digits) return false;

    const candidateBuf = Buffer.from(cleanCode, 'utf8');
    let matched = false;

    for (let offset = -window; offset <= window; offset++) {
        const expected = generateTotp(secret, { step, digits, windowOffset: offset, timestampMs });
        const expectedBuf = Buffer.from(expected, 'utf8');
        if (candidateBuf.length === expectedBuf.length && crypto.timingSafeEqual(candidateBuf, expectedBuf)) {
            matched = true;
        }
    }
    return matched;
}

/**
 * Builds a standard otpauth:// URI scannable by Google / Microsoft Authenticator.
 */
function buildOtpAuthUri({ secret, username, issuer = 'TIS RMS' }) {
    const encIssuer = encodeURIComponent(issuer);
    const encUser = encodeURIComponent(username || 'user');
    return `otpauth://totp/${encIssuer}:${encUser}?secret=${secret}&issuer=${encIssuer}&algorithm=SHA1&digits=6&period=30`;
}

/**
 * Generates [count] backup recovery codes formatted as XXXX-XXXX using unambiguous characters.
 */
function generateBackupCodes(count = 8) {
    const codes = [];
    for (let i = 0; i < count; i++) {
        let raw = '';
        for (let c = 0; c < 8; c++) {
            raw += BACKUP_CODE_ALPHABET[crypto.randomInt(0, BACKUP_CODE_ALPHABET.length)];
        }
        codes.push(`${raw.slice(0, 4)}-${raw.slice(4)}`);
    }
    return codes;
}

module.exports = {
    generateSecret,
    base32Decode,
    generateTotp,
    verifyTotp,
    buildOtpAuthUri,
    generateBackupCodes,
};
