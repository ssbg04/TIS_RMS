const db = require('../config/db');
const bcrypt = require('bcrypt');

const initSchema = () => {
    // Enable WAL mode for better performance
    db.pragma('journal_mode = WAL');

    db.transaction(() => {
        // 1. Users Table
        db.prepare(`
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                password TEXT NOT NULL,
                first_name TEXT NOT NULL,
                middle_name TEXT,
                last_name TEXT NOT NULL,
                extension TEXT,
                role TEXT CHECK(role IN ('super_admin', 'admin', 'teacher')) NOT NULL,
                email TEXT,
                phone TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `).run();

        // 2. AcademicYears Table
        db.prepare(`
            CREATE TABLE IF NOT EXISTS academic_years (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                year_range TEXT UNIQUE NOT NULL, -- e.g., "2023-2024"
                status TEXT CHECK(status IN ('active', 'inactive')) DEFAULT 'active'
            )
        `).run();

        // 2b. Sections Table
        db.prepare(`
            CREATE TABLE IF NOT EXISTS sections (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                grade_level INTEGER NOT NULL,
                academic_year_id INTEGER,
                FOREIGN KEY (academic_year_id) REFERENCES academic_years(id) ON DELETE CASCADE
            )
        `).run();

        // 3. Subjects Table
        db.prepare(`
            CREATE TABLE IF NOT EXISTS subjects (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                code TEXT UNIQUE NOT NULL,
                title TEXT NOT NULL,
                category TEXT CHECK(category IN ('JHS', 'SHS_CORE', 'SHS_APPLIED', 'SHS_SPECIALIZED')) NOT NULL
            )
        `).run();

        // 4. Students Table
        db.prepare(`
            CREATE TABLE IF NOT EXISTS students (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                lrn TEXT UNIQUE NOT NULL,
                first_name TEXT NOT NULL,
                middle_name TEXT,
                last_name TEXT NOT NULL,
                extension TEXT,
                sex TEXT CHECK(sex IN ('Male', 'Female')) NOT NULL,
                birth_date DATE NOT NULL,
                status TEXT DEFAULT 'Enrolled', -- Enrolled, Graduated, Transferred Out, Dropped
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `).run();

        // 5. Enrollments Table
        db.prepare(`
            CREATE TABLE IF NOT EXISTS enrollments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                student_id INTEGER NOT NULL,
                academic_year_id INTEGER NOT NULL,
                section_id INTEGER NOT NULL,
                grade_level INTEGER NOT NULL,
                track_strand TEXT, -- For SHS
                FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
                FOREIGN KEY (academic_year_id) REFERENCES academic_years(id),
                FOREIGN KEY (section_id) REFERENCES sections(id)
            )
        `).run();

        // 6. Grades Table
        db.prepare(`
            CREATE TABLE IF NOT EXISTS grades (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                enrollment_id INTEGER NOT NULL,
                subject_id INTEGER NOT NULL,
                q1 REAL, q2 REAL, q3 REAL, q4 REAL, -- JHS
                sem1 REAL, sem2 REAL, -- SHS
                final_grade REAL,
                remarks TEXT,
                FOREIGN KEY (enrollment_id) REFERENCES enrollments(id) ON DELETE CASCADE,
                FOREIGN KEY (subject_id) REFERENCES subjects(id)
            )
        `).run();

        // 8. DocumentRequirements Table (Enhanced)
        db.prepare(`
            CREATE TABLE IF NOT EXISTS document_requirements (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                description TEXT,
                category TEXT CHECK(category IN ('JHS', 'SHS')) NOT NULL,
                is_mandatory INTEGER DEFAULT 1,
                is_enabled INTEGER DEFAULT 1,
                due_date DATE,
                accepted_file_types TEXT DEFAULT 'pdf,jpg,jpeg,png',
                school_levels TEXT DEFAULT 'JHS,SHS',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `).run();

        // 8b. DocumentFolders Table (for manual folder management)
        db.prepare(`
            CREATE TABLE IF NOT EXISTS document_folders (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                parent_id INTEGER,
                student_id INTEGER,
                category TEXT,
                created_by INTEGER,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (parent_id) REFERENCES document_folders(id) ON DELETE CASCADE,
                FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
                FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
            )
        `).run();

        // 7. Documents Table
        db.prepare(`
            CREATE TABLE IF NOT EXISTS documents (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                student_id INTEGER NOT NULL,
                requirement_id INTEGER,
                file_name TEXT NOT NULL,
                file_path TEXT NOT NULL,
                document_type TEXT,
                status TEXT CHECK(status IN ('Pending', 'Verified', 'Draft', 'Archived')) DEFAULT 'Pending',
                retention_date DATE,
                uploaded_by INTEGER,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
                FOREIGN KEY (requirement_id) REFERENCES document_requirements(id),
                FOREIGN KEY (uploaded_by) REFERENCES users(id)
            )
        `).run();

        // 9. PrintQueue & Notifications
        db.prepare(`
            CREATE TABLE IF NOT EXISTS print_queue (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                document_id INTEGER NOT NULL,
                user_id INTEGER NOT NULL,
                added_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        `).run();

        db.prepare(`
            CREATE TABLE IF NOT EXISTS notifications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER, -- NULL means global
                title TEXT NOT NULL,
                message TEXT NOT NULL,
                is_read INTEGER DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        `).run();

        // 10. Password Reset Requests Table
        db.prepare(`
            CREATE TABLE IF NOT EXISTS password_reset_requests (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                new_password_hash TEXT NOT NULL,
                status TEXT CHECK(status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
                requested_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                reviewed_at DATETIME,
                reviewed_by INTEGER,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (reviewed_by) REFERENCES users(id)
            )
        `).run();

        // Seed Super Admin if not exists
        const superAdmin = db.prepare("SELECT * FROM users WHERE username = 'superadmin'").get();
        if (!superAdmin) {
            const hashedPassword = bcrypt.hashSync('admin123', 10);
            db.prepare(`
                INSERT INTO users (username, password, first_name, last_name, role)
                VALUES ('superadmin', ?, 'System', 'Developer', 'super_admin')
            `).run(hashedPassword);
            console.log('Default Super Admin created: superadmin / admin123');
        }

        // Seed default document requirements if none exist
        const existingReqs = db.prepare("SELECT COUNT(*) as count FROM document_requirements").get();
        if (existingReqs.count === 0) {
            const defaultRequirements = [
                { name: 'Form 137', description: 'Official copy of grades from previous school', category: 'JHS', is_mandatory: 1 },
                { name: 'Form 137', description: 'Official copy of grades from previous school', category: 'SHS', is_mandatory: 1 },
                { name: 'PSA Birth Certificate', description: 'Philippine Statistics Authority birth certificate', category: 'JHS', is_mandatory: 1 },
                { name: 'PSA Birth Certificate', description: 'Philippine Statistics Authority birth certificate', category: 'SHS', is_mandatory: 1 },
                { name: 'Good Moral Certificate', description: 'Certificate of good moral character', category: 'JHS', is_mandatory: 1 },
                { name: 'Good Moral Certificate', description: 'Certificate of good moral character', category: 'SHS', is_mandatory: 1 },
                { name: 'Medical Certificate', description: 'Physical and medical examination result', category: 'JHS', is_mandatory: 1 },
                { name: 'Medical Certificate', description: 'Physical and medical examination result', category: 'SHS', is_mandatory: 1 },
                { name: 'Report Card (Form 138)', description: 'Latest report card from previous school', category: 'JHS', is_mandatory: 1 },
                { name: 'Report Card (Form 138)', description: 'Latest report card from previous school', category: 'SHS', is_mandatory: 1 },
                { name: '2x2 Photo', description: 'Two pieces of 2x2 colored ID photos', category: 'JHS', is_mandatory: 1 },
                { name: '2x2 Photo', description: 'Two pieces of 2x2 colored ID photos', category: 'SHS', is_mandatory: 1 },
            ];
            const insertReq = db.prepare(`
                INSERT INTO document_requirements (name, description, category, is_mandatory, is_enabled, accepted_file_types, school_levels)
                VALUES (?, ?, ?, ?, 1, 'pdf,jpg,jpeg,png', 'JHS,SHS')
            `);
            for (const req of defaultRequirements) {
                insertReq.run(req.name, req.description, req.category, req.is_mandatory);
            }
            console.log('Default document requirements seeded');
        }
    })();
};

module.exports = { initSchema };
