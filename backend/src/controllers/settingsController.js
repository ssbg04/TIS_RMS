const db = require('../config/db');
const autoArchiveService = require('../services/autoArchiveService');
const { checkAndRunTeacherDueDateReminders } = require('../services/teacherReminderService');
const emailService = require('../services/emailService');
const tunnelService = require('../services/tunnelService');

exports.getSettings = (req, res) => {
    try {
        const rows = db.prepare('SELECT key, value FROM system_settings').all();
        const settings = {
            auto_update_enrollment_from_sf: 'false',
            enrollment_grace_period_days: '30',
            remind_teachers_due_date_enabled: 'false',
            remind_teachers_due_date_days: '3',
            cloudflare_tunnel_enabled: process.env.CLOUDFLARE_TUNNEL_ENABLED !== 'false' ? 'true' : 'false'
        };
        for (const row of rows) {
            settings[row.key] = row.value;
        }
        settings.cloudflare_tunnel_enabled = process.env.CLOUDFLARE_TUNNEL_ENABLED !== 'false' ? 'true' : 'false';
        res.json({
            success: true,
            data: settings
        });
    } catch (error) {
        console.error('getSettings error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to retrieve system settings',
            error: error.message
        });
    }
};

exports.updateSettings = async (req, res) => {
    try {
        const updates = req.body.settings || req.body;
        if (!updates || typeof updates !== 'object') {
            return res.status(400).json({
                success: false,
                message: 'Invalid settings payload'
            });
        }

        const stmt = db.prepare(`
            INSERT INTO system_settings (key, value, updated_at)
            VALUES (?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(key) DO UPDATE SET
                value = excluded.value,
                updated_at = CURRENT_TIMESTAMP
        `);

        const insertOrUpdate = db.transaction((settingsObj) => {
            for (const [key, value] of Object.entries(settingsObj)) {
                stmt.run(key, String(value));
            }
        });

        insertOrUpdate(updates);

        if (updates.cloudflare_tunnel_enabled !== undefined) {
            const enabled = updates.cloudflare_tunnel_enabled === true || updates.cloudflare_tunnel_enabled === 'true';
            await tunnelService.setTunnelEnabled(enabled);
        }

        if (updates.enrollment_grace_period_days !== undefined || updates.auto_archive_datetime !== undefined || updates.auto_archive_enabled !== undefined) {
            autoArchiveService.checkAndRunAutoArchive(req.user?.id);
            autoArchiveService.scheduleAutoArchiveTimer();
        }

        if (updates.remind_teachers_due_date_enabled !== undefined || updates.remind_teachers_due_date_days !== undefined) {
            checkAndRunTeacherDueDateReminders();
        }

        const rows = db.prepare('SELECT key, value FROM system_settings').all();
        const updatedSettings = {};
        for (const row of rows) {
            updatedSettings[row.key] = row.value;
        }
        updatedSettings.cloudflare_tunnel_enabled = process.env.CLOUDFLARE_TUNNEL_ENABLED !== 'false' ? 'true' : 'false';

        res.json({
            success: true,
            message: 'System settings updated successfully',
            data: updatedSettings
        });
    } catch (error) {
        console.error('updateSettings error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update system settings',
            error: error.message
        });
    }
};

exports.reportIssue = async (req, res) => {
    try {
        const category = (req.body.category || 'bug').toString().trim();
        const urgency = (req.body.urgency || 'medium').toString().trim();
        const title = (req.body.title || '').toString().trim();
        const description = (req.body.description || '').toString().trim();
        const platform = (req.body.platform || 'Unknown').toString().trim();
        const deviceName = (req.body.deviceName || 'Unknown').toString().trim();
        const appVersion = (req.body.appVersion || 'Unknown').toString().trim();

        if (!title || !description) {
            return res.status(400).json({
                success: false,
                message: 'Subject/title and description are required.'
            });
        }

        let reporter = {
            name: 'Unknown User',
            email: 'N/A',
            role: req.user?.role || 'N/A',
        };
        if (req.user?.id) {
            const userRow = db
                .prepare('SELECT first_name, last_name, email, role FROM users WHERE id = ?')
                .get(req.user.id);
            if (userRow) {
                reporter = {
                    name: `${userRow.first_name || ''} ${userRow.last_name || ''}`.trim() || 'User',
                    email: userRow.email || 'N/A',
                    role: userRow.role || req.user.role || 'N/A',
                };
            }
        }

        const attachments = Array.isArray(req.files) ? req.files : [];

        await emailService.sendIssueReportEmail({
            category,
            urgency,
            title,
            description,
            reporter,
            systemInfo: {
                platform,
                deviceName,
                appVersion,
                reportedAt: new Date().toLocaleString('en-PH', { timeZone: 'Asia/Manila' }),
            },
            attachments,
        });

        res.json({
            success: true,
            message: 'Issue report sent to developer successfully.'
        });
    } catch (error) {
        console.error('reportIssue error:', error);
        res.status(500).json({
            success: false,
            message: error.message || 'Failed to send issue report.'
        });
    }
};
