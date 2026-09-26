const db = require('../config/db');
const autoArchiveService = require('../services/autoArchiveService');

exports.getSettings = (req, res) => {
    try {
        const rows = db.prepare('SELECT key, value FROM system_settings').all();
        const settings = {
            auto_update_enrollment_from_sf: 'false',
            enrollment_grace_period_days: '30'
        };
        for (const row of rows) {
            settings[row.key] = row.value;
        }
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

exports.updateSettings = (req, res) => {
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

        if (updates.enrollment_grace_period_days !== undefined || updates.auto_archive_datetime !== undefined || updates.auto_archive_enabled !== undefined) {
            autoArchiveService.checkAndRunAutoArchive(req.user?.id);
            autoArchiveService.scheduleAutoArchiveTimer();
        }

        const rows = db.prepare('SELECT key, value FROM system_settings').all();
        const updatedSettings = {};
        for (const row of rows) {
            updatedSettings[row.key] = row.value;
        }

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
