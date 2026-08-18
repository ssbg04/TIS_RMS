'use strict';
const path = require('path');
const fs = require('fs');
const { initializeApp, getApps, cert } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');

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
        const resolvedPath = path.isAbsolute(serviceAccountPath)
            ? serviceAccountPath
            : path.resolve(process.cwd(), serviceAccountPath);

        if (!fs.existsSync(resolvedPath)) {
            console.error('[FCM] Service account file not found at:', resolvedPath);
            return;
        }

        const serviceAccount = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));

        if (!getApps().length) {
            initializeApp({ credential: cert(serviceAccount) });
        }
        messaging = getMessaging();
        console.log('[FCM] Firebase Admin initialized successfully');
    } catch (err) {
        console.error('[FCM] Init failed:', err.message);
        messaging = null;
    }
};

const _cleanInvalidTokens = (tokens, responses) => {
    if (!tokens || !responses) return;
    const db = require('../config/db');
    const invalidCodes = [
        'messaging/registration-token-not-registered',
        'messaging/invalid-registration-token',
    ];
    const stmt = db.prepare('DELETE FROM fcm_tokens WHERE token = ?');
    responses.forEach((res, i) => {
        if (!res.success && invalidCodes.includes(res.error?.code)) {
            try {
                stmt.run(tokens[i]);
            } catch (_) {}
        }
    });
};

const _sendMulticast = async (tokens, title, body, category = 'system') => {
    if (!messaging || !tokens || tokens.length === 0) return;
    
    // Deduplicate tokens
    const uniqueTokens = Array.from(new Set(tokens.filter(Boolean)));
    if (uniqueTokens.length === 0) return;

    for (let i = 0; i < uniqueTokens.length; i += 500) {
        const chunk = uniqueTokens.slice(i, i + 500);
        try {
            const result = await messaging.sendEachForMulticast({
                tokens: chunk,
                notification: {
                    title: title || 'TIS RMS',
                    body: body || ''
                },
                data: {
                    title: String(title || 'TIS RMS'),
                    body: String(body || ''),
                    category: String(category || 'system'),
                    click_action: 'FLUTTER_NOTIFICATION_CLICK'
                },
                android: {
                    priority: 'high',
                    notification: {
                        channelId: 'tis_rms_activities_channel',
                        sound: 'default',
                        priority: 'high',
                        defaultSound: true,
                        defaultVibrateTimings: true,
                        visibility: 'public'
                    }
                }
            });
            _cleanInvalidTokens(chunk, result.responses);
        } catch (err) {
            console.error('[FCM] Send batch error:', err.message);
        }
    }
};

/**
 * Sends push notification to the appropriate audience in real-time.
 * - Direct: user_id provided
 * - Broadcast / Scoped: all admins + relevant section teachers (for student/document) or all users
 */
const sendNotification = async ({ userId = null, title, body, category = 'system', entityType = null, entityId = null }) => {
    if (!messaging) return;
    const db = require('../config/db');

    try {
        let tokens = [];

        if (userId) {
            // Direct message to a specific user
            tokens = db.prepare('SELECT token FROM fcm_tokens WHERE user_id = ?')
                .all(userId)
                .map(r => r.token);
        } else {
            // 1. All admins always receive system & activity updates
            const adminTokens = db.prepare(`
                SELECT ft.token 
                FROM fcm_tokens ft
                JOIN users u ON ft.user_id = u.id
                WHERE u.role = 'admin' AND u.is_active = 1
            `).all().map(r => r.token);

            tokens.push(...adminTokens);

            // 2. Target assigned teachers if scoped to student or document
            if (entityType === 'student' && entityId) {
                const teacherTokens = db.prepare(`
                    SELECT DISTINCT ft.token
                    FROM fcm_tokens ft
                    JOIN users u ON ft.user_id = u.id
                    JOIN teacher_sections ts ON u.id = ts.teacher_id
                    JOIN enrollments e ON ts.section_id = e.section_id
                    WHERE e.student_id = ? AND u.role = 'teacher' AND u.is_active = 1
                `).all(entityId).map(r => r.token);
                tokens.push(...teacherTokens);
            } else if (entityType === 'document' && entityId) {
                const teacherTokens = db.prepare(`
                    SELECT DISTINCT ft.token
                    FROM fcm_tokens ft
                    JOIN users u ON ft.user_id = u.id
                    JOIN teacher_sections ts ON u.id = ts.teacher_id
                    JOIN enrollments e ON ts.section_id = e.section_id
                    JOIN documents d ON e.student_id = d.student_id
                    WHERE d.id = ? AND u.role = 'teacher' AND u.is_active = 1
                `).all(entityId).map(r => r.token);
                tokens.push(...teacherTokens);
            } else {
                // Generic broadcast to all active users
                const allTokens = db.prepare(`
                    SELECT ft.token
                    FROM fcm_tokens ft
                    JOIN users u ON ft.user_id = u.id
                    WHERE u.is_active = 1
                `).all().map(r => r.token);
                tokens.push(...allTokens);
            }
        }

        await _sendMulticast(tokens, title, body, category);
    } catch (err) {
        console.error('[FCM] sendNotification error:', err.message);
    }
};

const sendToUser = async (userId, title, body) => {
    return sendNotification({ userId, title, body });
};

const sendToAll = async (title, body) => {
    return sendNotification({ title, body });
};

module.exports = { init, sendNotification, sendToUser, sendToAll };

