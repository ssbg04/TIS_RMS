'use strict';
const path = require('path');

let messaging = null;
let initialized = false;

const init = () => {
    if (initialized) return;
    initialized = true;

    const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT;
    if (!serviceAccountPath) {
        console.log('[FCM] FIREBASE_SERVICE_ACCOUNT not set — push notifications disabled');
        return;
    }

    try {
        const admin = require('firebase-admin');
        if (!admin.apps.length) {
            const serviceAccount = require(path.resolve(serviceAccountPath));
            admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
        }
        messaging = admin.messaging();
        console.log('[FCM] Firebase Admin initialized');
    } catch (err) {
        console.error('[FCM] Init failed:', err.message);
        messaging = null;
    }
};

const _cleanInvalidTokens = (tokens, responses) => {
    const db = require('../config/db');
    const invalidCodes = [
        'messaging/registration-token-not-registered',
        'messaging/invalid-registration-token',
    ];
    const stmt = db.prepare('DELETE FROM fcm_tokens WHERE token = ?');
    responses.forEach((res, i) => {
        if (!res.success && invalidCodes.includes(res.error?.code)) {
            stmt.run(tokens[i]);
        }
    });
};

const sendToUser = async (userId, title, body) => {
    if (!messaging) return;
    const db = require('../config/db');
    const tokens = db.prepare('SELECT token FROM fcm_tokens WHERE user_id = ?')
        .all(userId)
        .map(r => r.token);
    if (tokens.length === 0) return;
    try {
        const result = await messaging.sendEachForMulticast({
            tokens,
            notification: { title, body },
            android: { priority: 'high' },
        });
        _cleanInvalidTokens(tokens, result.responses);
    } catch (err) {
        console.error('[FCM] sendToUser error:', err.message);
    }
};

const sendToAll = async (title, body) => {
    if (!messaging) return;
    const db = require('../config/db');
    const tokens = db.prepare('SELECT token FROM fcm_tokens').all().map(r => r.token);
    if (tokens.length === 0) return;
    try {
        for (let i = 0; i < tokens.length; i += 500) {
            const chunk = tokens.slice(i, i + 500);
            const result = await messaging.sendEachForMulticast({
                tokens: chunk,
                notification: { title, body },
                android: { priority: 'high' },
            });
            _cleanInvalidTokens(chunk, result.responses);
        }
    } catch (err) {
        console.error('[FCM] sendToAll error:', err.message);
    }
};

module.exports = { init, sendToUser, sendToAll };
