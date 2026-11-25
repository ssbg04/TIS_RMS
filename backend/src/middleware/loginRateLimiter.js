/**
 * Lightweight in-memory IP rate limiter for login requests.
 * Protects against credential stuffing / username enumeration across accounts.
 */
const WINDOW_MS = 15 * 60 * 1000; // 15 minutes
const MAX_REQUESTS_PER_WINDOW = 15;

const ipAttempts = new Map();

// Periodic cleanup every 15 minutes to prevent unbounded memory growth
setInterval(() => {
    const now = Date.now();
    for (const [ip, entry] of ipAttempts.entries()) {
        if (now > entry.resetAt) {
            ipAttempts.delete(ip);
        }
    }
}, WINDOW_MS).unref();

const getClientIp = (req) => {
    const raw = req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.socket?.remoteAddress || 'unknown';
    const clean = raw.replace(/^::ffff:/, '');
    return clean === '::1' ? '127.0.0.1' : clean;
};

const loginRateLimiter = (req, res, next) => {
    const ip = getClientIp(req);
    const now = Date.now();
    let entry = ipAttempts.get(ip);

    if (!entry || now > entry.resetAt) {
        entry = { count: 1, resetAt: now + WINDOW_MS };
        ipAttempts.set(ip, entry);
        return next();
    }

    entry.count += 1;
    if (entry.count > MAX_REQUESTS_PER_WINDOW) {
        const secsLeft = Math.max(1, Math.ceil((entry.resetAt - now) / 1000));
        const minsLeft = Math.ceil(secsLeft / 60);
        res.set('Retry-After', String(secsLeft));
        return res.status(429).json({
            message: `Too many login attempts from this network. Please try again in ${minsLeft} minute${minsLeft === 1 ? '' : 's'}.`,
        });
    }

    return next();
};

module.exports = { loginRateLimiter, getClientIp };
