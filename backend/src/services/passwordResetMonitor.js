'use strict';
const db = require('../config/db');
const notificationController = require('../controllers/notificationController');

let monitorInterval = null;

/**
 * Checks all pending password reset links that have expired,
 * marks them as expired, and dispatches in-app + FCM push notification to the initiating admin.
 */
const checkExpiredResetLinks = () => {
    try {
        const expiredLinks = db.prepare(`
            SELECT prl.id, prl.user_id, prl.admin_id, prl.email, prl.expires_at,
                   u.username, u.first_name, u.last_name
            FROM password_reset_links prl
            JOIN users u ON prl.user_id = u.id
            WHERE prl.status = 'pending'
              AND prl.expires_at < (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
              AND prl.expired_notified = 0
        `).all();

        if (expiredLinks && expiredLinks.length > 0) {
            const markNotifiedStmt = db.prepare(`
                UPDATE password_reset_links
                SET status = 'expired', expired_notified = 1
                WHERE id = ?
            `);

            for (const link of expiredLinks) {
                markNotifiedStmt.run(link.id);
                const fullName = [link.first_name, link.last_name].filter(Boolean).join(' ');
                const title = 'Password Reset Link Expired';
                const message = `The password reset link for @${link.username}${fullName ? ` (${fullName})` : ''} has expired without being used.`;

                // Notify initiating admin or all admins if admin_id is null
                notificationController.createNotification(
                    link.admin_id || null,
                    title,
                    message,
                    'user',
                    'user',
                    link.user_id
                );
                console.log(`[ResetMonitor] Notified admin for expired reset link (User: @${link.username})`);
            }
        }
    } catch (err) {
        console.error('[ResetMonitor] Error checking expired reset links:', err.message);
    }
};

/**
 * Starts the periodic background monitor (runs every 30 seconds).
 */
const startResetLinkMonitor = () => {
    if (monitorInterval) clearInterval(monitorInterval);
    checkExpiredResetLinks();
    monitorInterval = setInterval(checkExpiredResetLinks, 30 * 1000);
    console.log('[ResetMonitor] Password reset link expiration monitor started (30s interval)');
};

module.exports = {
    checkExpiredResetLinks,
    startResetLinkMonitor,
};
