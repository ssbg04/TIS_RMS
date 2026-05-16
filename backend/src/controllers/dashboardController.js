const db = require('../config/db');

exports.getStats = (req, res) => {
    try {
        const totalStudents = db.prepare('SELECT COUNT(*) as count FROM students').get().count;
        const printQueueCount = db.prepare('SELECT COUNT(*) as count FROM print_queue').get().count;
        const pendingVerifications = db.prepare("SELECT COUNT(*) as count FROM documents WHERE status = 'Pending'").get().count;
        const activeUsers = db.prepare('SELECT COUNT(*) as count FROM users').get().count;

        res.json({
            totalStudents,
            printQueueCount,
            pendingVerifications,
            activeUsers
        });
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch stats', error: error.message });
    }
};

exports.getPendingTasks = (req, res) => {
    try {
        // Pending tasks are documents that need verification
        const pendingDocs = db.prepare(`
            SELECT d.id, d.file_name, d.created_at, s.first_name, s.last_name 
            FROM documents d
            JOIN students s ON d.student_id = s.id
            WHERE d.status = 'Pending'
            ORDER BY d.created_at DESC
            LIMIT 10
        `).all();

        res.json(pendingDocs);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch pending tasks', error: error.message });
    }
};
