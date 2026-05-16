const cron = require('node-cron');
const db = require('../config/db');

// Retention Engine Logic
// Runs every day at midnight
cron.schedule('0 0 * * *', () => {
    console.log('Running Retention Engine...');

    db.transaction(() => {
        const now = new Date();

        // 1. Process Graduated Students (Docs -> Archive 5 years)
        // Set retention_date for documents of graduated students if not set
        db.prepare(`
            UPDATE documents 
            SET retention_date = date(created_at, '+5 years'), status = 'Archived'
            WHERE student_id IN (SELECT id FROM students WHERE status = 'Graduated')
            AND status != 'Archived'
        `).run();

        // 2. Process Transferred Out Students (Docs -> Archive 3 years)
        db.prepare(`
            UPDATE documents 
            SET retention_date = date(created_at, '+3 years'), status = 'Archived'
            WHERE student_id IN (SELECT id FROM students WHERE status = 'Transferred Out')
            AND status != 'Archived'
        `).run();

        // 3. Process Dropped Students (Docs -> Archive 2 years)
        db.prepare(`
            UPDATE documents 
            SET retention_date = date(created_at, '+2 years'), status = 'Archived'
            WHERE student_id IN (SELECT id FROM students WHERE status = 'Dropped')
            AND status != 'Archived'
        `).run();

        console.log('Retention Engine task completed.');
    })();
});

console.log('Retention Engine service initialized.');
