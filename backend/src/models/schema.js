const db = require('../config/db');
const bcrypt = require('bcrypt');

const initSchema = () => {
    // ── Migration: Document status rename ──────────────────────────────────
    // Old values: 'Pending', 'Verified', 'Draft', 'Archived'
    // Current values: 'Completed', 'Archived'  (Submitted has been removed)
    // SQLite datetime defaults use (DATETIME('now', 'localtime')) which adheres to process.env.TZ = 'Asia/Manila'
    const docTableInfo = db.prepare("SELECT sql FROM sqlite_master WHERE type='table' AND name='documents'").get();
    if (docTableInfo && docTableInfo.sql.includes("'Pending'")) {
        console.log('Migrating documents table: renaming status values...');
        db.pragma('foreign_keys = OFF');
        db.transaction(() => {
            // Rebuild table with new CHECK constraint by renaming first
            db.prepare("ALTER TABLE documents RENAME TO _documents_old").run();
            db.prepare(`
                CREATE TABLE documents (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    student_id INTEGER NOT NULL,
                    requirement_id INTEGER,
                    file_name TEXT NOT NULL,
                    file_path TEXT NOT NULL,
                    document_type TEXT,
                    status TEXT CHECK(status IN ('Completed','Archived')) DEFAULT 'Completed',
                    retention_date DATE,
                    uploaded_by INTEGER,
                    created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                    FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
                    FOREIGN KEY (requirement_id) REFERENCES document_requirements(id),
                    FOREIGN KEY (uploaded_by) REFERENCES users(id)
                )
            `).run();

            // Copy data and map old status values to new status values during copying
            db.prepare(`
                INSERT INTO documents (id, student_id, requirement_id, file_name, file_path, document_type, status, retention_date, uploaded_by, created_at)
                SELECT id, student_id, requirement_id, file_name, file_path, document_type,
                    CASE 
                        WHEN status IN ('Pending', 'Draft', 'Submitted') THEN 'Completed'
                        WHEN status = 'Verified' THEN 'Completed'
                        ELSE 'Archived'
                    END,
                    retention_date, uploaded_by, created_at
                FROM _documents_old
            `).run();
            db.prepare("DROP TABLE _documents_old").run();
        })();
        db.pragma('foreign_keys = ON');
        console.log('Document status migration completed.');
    }

    // ── Migration: Convert any remaining 'Submitted' rows to 'Completed' ────
    // Handles databases that went through the previous Submitted-era migration
    try {
        db.prepare("UPDATE documents SET status = 'Completed' WHERE status = 'Submitted'").run();
    } catch (_) { /* table may not exist yet on first run */ }

    // ── Migration: Add created_at and updated_at to document_requirements ──
    const reqTableInfo = db.prepare("PRAGMA table_info(document_requirements)").all();
    if (reqTableInfo.length > 0) {
        const hasCreatedAt = reqTableInfo.some(c => c.name === 'created_at');
        const hasUpdatedAt = reqTableInfo.some(c => c.name === 'updated_at');
        
        if (!hasCreatedAt || !hasUpdatedAt) {
            console.log('Migrating document_requirements table: adding created_at/updated_at columns via rebuild...');
            
            db.pragma('foreign_keys = OFF');
            db.transaction(() => {
                // Rename old table
                db.prepare("ALTER TABLE document_requirements RENAME TO _reqs_old").run();

                // Create new table with the correct schema
                db.prepare(`
                    CREATE TABLE document_requirements (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        name TEXT NOT NULL,
                        description TEXT,
                        category TEXT CHECK(category IN ('JHS', 'SHS')) NOT NULL,
                        is_mandatory INTEGER DEFAULT 1,
                        is_enabled INTEGER DEFAULT 1,
                        due_date DATE,
                        accepted_file_types TEXT DEFAULT 'pdf,jpg,jpeg,png',
                        school_levels TEXT DEFAULT 'JHS,SHS',
                        created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                        updated_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
                    )
                `).run();

                // Copy existing data. If the columns don't exist in the old table, the new table's DEFAULT values won't be used by INSERT SELECT if we just list the old columns. 
                // Wait, if we only SELECT the old columns, the new columns will be filled with their DEFAULT values automatically.
                db.prepare(`
                    INSERT INTO document_requirements (id, name, description, category, is_mandatory, is_enabled, due_date, accepted_file_types, school_levels)
                    SELECT id, name, description, category, is_mandatory, is_enabled, due_date, accepted_file_types, school_levels
                    FROM _reqs_old
                `).run();

                // Drop old table
                db.prepare("DROP TABLE _reqs_old").run();
            })();
            db.pragma('foreign_keys = ON');
            console.log('document_requirements migration completed successfully.');
        }
    }

    // Enable WAL mode for better performance
    db.pragma('journal_mode = WAL');

    // Migration: Collapsing user roles from 3 to 2 (admin and teacher only)
    const tableInfo = db.prepare("SELECT sql FROM sqlite_master WHERE type='table' AND name='users'").get();
    if (tableInfo && tableInfo.sql.includes('super_admin')) {
        console.log('Migrating users table: removing super_admin role check constraint...');
        
        // Temporarily disable foreign keys for the migration rebuild
        db.pragma('foreign_keys = OFF');
        
        db.transaction(() => {
            // Update any super_admin users to admin
            db.prepare("UPDATE users SET role = 'admin' WHERE role = 'super_admin'").run();
            
            // Map default username superadmin to admin if admin is not already present
            const existingAdmin = db.prepare("SELECT id FROM users WHERE username = 'admin'").get();
            if (!existingAdmin) {
                db.prepare("UPDATE users SET username = 'admin' WHERE username = 'superadmin'").run();
            }

            // Rename old table
            db.prepare("ALTER TABLE users RENAME TO _users_old").run();

            // Create new table
            db.prepare(`
                CREATE TABLE users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    username TEXT UNIQUE NOT NULL,
                    password TEXT NOT NULL,
                    first_name TEXT NOT NULL,
                    middle_name TEXT,
                    last_name TEXT NOT NULL,
                    extension TEXT,
                    role TEXT CHECK(role IN ('admin', 'teacher')) NOT NULL,
                    email TEXT,
                    phone TEXT,
                    created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                    updated_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
                )
            `).run();

            // Copy data
            db.prepare(`
                INSERT INTO users (id, username, password, first_name, middle_name, last_name, extension, role, email, phone, created_at, updated_at)
                SELECT id, username, password, first_name, middle_name, last_name, extension, role, email, phone, created_at, updated_at
                FROM _users_old
            `).run();

            // Drop old table
            db.prepare("DROP TABLE _users_old").run();
        })();

        // Re-enable foreign keys
        db.pragma('foreign_keys = ON');
        console.log('Database users table role migration completed successfully.');
    }

    // Migration: Fix foreign keys pointing to _users_old or _documents_old in other tables
    const brokenTables = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND (sql LIKE '%_users_old%' OR sql LIKE '%_documents_old%')").all();
    if (brokenTables.length > 0) {
        console.log('Migrating tables: rebuilding tables with broken foreign keys pointing to _users_old or _documents_old...', brokenTables.map(t => t.name));
        
        // Temporarily disable foreign keys for rebuild
        db.pragma('foreign_keys = OFF');
        
        db.transaction(() => {
            for (const table of brokenTables) {
                const tableName = table.name;
                console.log(`Rebuilding table: ${tableName}`);
                
                // 1. Rename to temp
                db.prepare(`ALTER TABLE "${tableName}" RENAME TO "_temp_${tableName}"`).run();
                
                // 2. Create the table with correct definition (referencing users)
                if (tableName === 'documents') {
                    db.prepare(`
                        CREATE TABLE documents (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            student_id INTEGER NOT NULL,
                            requirement_id INTEGER,
                            file_name TEXT NOT NULL,
                            file_path TEXT NOT NULL,
                            document_type TEXT,
                            status TEXT CHECK(status IN ('Pending', 'Verified', 'Draft', 'Archived')) DEFAULT 'Pending',
                            retention_date DATE,
                            uploaded_by INTEGER,
                            created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                            FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
                            FOREIGN KEY (requirement_id) REFERENCES document_requirements(id),
                            FOREIGN KEY (uploaded_by) REFERENCES users(id)
                        )
                    `).run();
                    db.prepare(`
                        INSERT INTO documents (id, student_id, requirement_id, file_name, file_path, document_type, status, retention_date, uploaded_by, created_at)
                        SELECT id, student_id, requirement_id, file_name, file_path, document_type, status, retention_date, uploaded_by, created_at FROM "_temp_${tableName}"
                    `).run();
                } else if (tableName === 'print_queue') {
                    db.prepare(`
                        CREATE TABLE print_queue (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            document_id INTEGER NOT NULL,
                            user_id INTEGER NOT NULL,
                            added_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                            FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
                            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                        )
                    `).run();
                    db.prepare(`
                        INSERT INTO print_queue (id, document_id, user_id, added_at)
                        SELECT id, document_id, user_id, added_at FROM "_temp_${tableName}"
                    `).run();
                } else if (tableName === 'notifications') {
                    db.prepare(`
                        CREATE TABLE notifications (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            user_id INTEGER,
                            title TEXT NOT NULL,
                            message TEXT NOT NULL,
                            is_read INTEGER DEFAULT 0,
                            category TEXT DEFAULT 'system',
                            created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                        )
                    `).run();
                    db.prepare(`
                        INSERT INTO notifications (id, user_id, title, message, is_read, created_at)
                        SELECT id, user_id, title, message, is_read, created_at FROM "_temp_${tableName}"
                    `).run();
                } else if (tableName === 'password_reset_requests') {
                    db.prepare(`
                        CREATE TABLE password_reset_requests (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            user_id INTEGER NOT NULL,
                            new_password_hash TEXT NOT NULL,
                            status TEXT CHECK(status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
                            requested_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                            reviewed_at DATETIME,
                            reviewed_by INTEGER,
                            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                            FOREIGN KEY (reviewed_by) REFERENCES users(id)
                        )
                    `).run();
                    db.prepare(`
                        INSERT INTO password_reset_requests (id, user_id, new_password_hash, status, requested_at, reviewed_at, reviewed_by)
                        SELECT id, user_id, new_password_hash, status, requested_at, reviewed_at, reviewed_by FROM "_temp_${tableName}"
                    `).run();
                } else if (tableName === 'document_folders') {
                    db.prepare(`
                        CREATE TABLE document_folders (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            name TEXT NOT NULL,
                            parent_id INTEGER,
                            student_id INTEGER,
                            category TEXT,
                            created_by INTEGER,
                            created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                            updated_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                            FOREIGN KEY (parent_id) REFERENCES document_folders(id) ON DELETE CASCADE,
                            FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
                            FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
                        )
                    `).run();
                    db.prepare(`
                        INSERT INTO document_folders (id, name, parent_id, student_id, category, created_by, created_at, updated_at)
                        SELECT id, name, parent_id, student_id, category, created_by, created_at, updated_at FROM "_temp_${tableName}"
                    `).run();
                }
                
                // 3. Drop temp table
                db.prepare(`DROP TABLE "_temp_${tableName}"`).run();
            }
        })();
        
        // Re-enable foreign keys
        db.pragma('foreign_keys = ON');
        console.log('Database tables foreign keys migration completed successfully.');
    }

    db.transaction(() => {
        // Drop grades and subjects tables if they exist
        db.prepare('DROP TABLE IF EXISTS grades').run();
        db.prepare('DROP TABLE IF EXISTS subjects').run();

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
                role TEXT CHECK(role IN ('admin', 'teacher')) NOT NULL,
                email TEXT,
                phone TEXT,
                created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                updated_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
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

        // 2c. Grade Levels Table
        db.prepare(`
            CREATE TABLE IF NOT EXISTS grade_levels (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                level INTEGER UNIQUE NOT NULL,
                name TEXT NOT NULL
            )
        `).run();

        // Seed default grade levels 7 to 12 if none exist
        const existingGrades = db.prepare("SELECT COUNT(*) as count FROM grade_levels").get();
        if (existingGrades.count === 0) {
            const insertGrade = db.prepare("INSERT INTO grade_levels (level, name) VALUES (?, ?)");
            for (let g = 7; g <= 12; g++) {
                insertGrade.run(g, `Grade ${g}`);
            }
            console.log('Seeded default grade levels 7 to 12');
        }

        // 2d. Teacher Sections Table
        db.prepare(`
            CREATE TABLE IF NOT EXISTS teacher_sections (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                teacher_id INTEGER NOT NULL,
                section_id INTEGER NOT NULL,
                FOREIGN KEY (teacher_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE,
                UNIQUE(teacher_id, section_id)
            )
        `).run();

        // 3. Students Table
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
                status TEXT DEFAULT 'Enrolled', -- Enrolled, Graduated, Transferred, Dropped
                created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
            )
        `).run();

        // 4. Enrollments Table
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
                created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                updated_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
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
                created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                updated_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
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
                status TEXT CHECK(status IN ('Completed','Archived')) DEFAULT 'Completed',
                retention_date DATE,
                uploaded_by INTEGER,
                created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                deleted_at DATETIME DEFAULT NULL,
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
                added_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        `).run();

        // 9b. PrintedDocumentHistory Table
        db.prepare(`
            CREATE TABLE IF NOT EXISTS printed_document_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                document_id INTEGER,
                student_id INTEGER,
                user_id INTEGER,
                document_name TEXT NOT NULL,
                student_name TEXT NOT NULL,
                printed_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE SET NULL,
                FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE SET NULL,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
            )
        `).run();

        // 9c. RecentDeleted Table
        db.prepare(`
            CREATE TABLE IF NOT EXISTS recent_deleted (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                document_id INTEGER,
                student_id INTEGER,
                file_name TEXT NOT NULL,
                file_path TEXT NOT NULL,
                document_type TEXT,
                deleted_by INTEGER,
                deleted_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE SET NULL,
                FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE SET NULL,
                FOREIGN KEY (deleted_by) REFERENCES users(id) ON DELETE SET NULL
            )
        `).run();

        // Activity Log — records every user CRUD action for recent activities feed
        db.prepare(`
            CREATE TABLE IF NOT EXISTS activity_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                action TEXT NOT NULL,       -- CREATE, UPDATE, DELETE
                entity_type TEXT NOT NULL,  -- document, student, user
                entity_id INTEGER,
                description TEXT NOT NULL,
                created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
            )
        `).run();

        // User History — records user account lifecycle events (admin-only view)
        db.prepare(`
            CREATE TABLE IF NOT EXISTS user_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                performed_by INTEGER,
                target_user_id INTEGER,
                action TEXT NOT NULL,        -- created, updated, deleted
                username TEXT NOT NULL,
                full_name TEXT NOT NULL,
                role TEXT NOT NULL,
                created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                FOREIGN KEY (performed_by) REFERENCES users(id) ON DELETE SET NULL
            )
        `).run();

        db.prepare(`
            CREATE TABLE IF NOT EXISTS deleted_users_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                deleted_user_id INTEGER,           -- Keep ID for reference
                username TEXT NOT NULL,            -- Saved explicitly
                full_name TEXT NOT NULL,           -- Saved explicitly
                role TEXT NOT NULL,                -- Saved explicitly
                reason TEXT NOT NULL,              -- The reason provided
                deleted_by INTEGER,                -- Admin who did it
                deleted_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                FOREIGN KEY (deleted_by) REFERENCES users(id) ON DELETE SET NULL
            )
        `).run();

        db.prepare(`
            CREATE TABLE IF NOT EXISTS notifications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER, -- NULL means global
                title TEXT NOT NULL,
                message TEXT NOT NULL,
                is_read INTEGER DEFAULT 0,
                category TEXT DEFAULT 'system', -- 'student', 'document', 'user', 'system'
                created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        `).run();

        // Migration: add category column to notifications if missing
        const notifCols = db.prepare("PRAGMA table_info(notifications)").all();
        if (!notifCols.some(c => c.name === 'category')) {
            db.prepare("ALTER TABLE notifications ADD COLUMN category TEXT DEFAULT 'system'").run();
        }

        // Migration: add deleted_at column to documents if missing
        const docCols = db.prepare("PRAGMA table_info(documents)").all();
        if (!docCols.some(c => c.name === 'deleted_at')) {
            db.prepare("ALTER TABLE documents ADD COLUMN deleted_at DATETIME DEFAULT NULL").run();
            console.log('Migration: added deleted_at column to documents table');
        }

        // Migration: Backfill any documents that are soft-deleted but missing from recent_deleted
        try {
            const orphanDeleted = db.prepare(`
                SELECT d.id, d.student_id, d.file_name, d.file_path, d.document_type, d.deleted_at
                FROM documents d
                LEFT JOIN recent_deleted rd ON d.id = rd.document_id
                WHERE d.deleted_at IS NOT NULL AND rd.id IS NULL
            `).all();

            if (orphanDeleted.length > 0) {
                console.log(`[Migration] Found \${orphanDeleted.length} orphan soft-deleted documents. Backfilling into recent_deleted...`);
                const backfillStmt = db.prepare(`
                    INSERT INTO recent_deleted (document_id, student_id, file_name, file_path, document_type, deleted_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                `);
                
                db.transaction(() => {
                    for (const doc of orphanDeleted) {
                        backfillStmt.run(doc.id, doc.student_id, doc.file_name, doc.file_path, doc.document_type, doc.deleted_at);
                    }
                })();
                console.log(`[Migration] Successfully backfilled recent_deleted table.`);
            }
        } catch (migrationErr) {
            console.error('[Migration Error] Failed to backfill recent_deleted:', migrationErr.message);
        }

        // 10. Password Reset Requests Table
        db.prepare(`
            CREATE TABLE IF NOT EXISTS password_reset_requests (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                new_password_hash TEXT NOT NULL,
                status TEXT CHECK(status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
                requested_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
                reviewed_at DATETIME,
                reviewed_by INTEGER,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (reviewed_by) REFERENCES users(id)
            )
        `).run();

        // Seed Admin if not exists
        const adminUser = db.prepare("SELECT * FROM users WHERE username = 'admin' OR role = 'admin'").get();
        if (!adminUser) {
            const hashedPassword = bcrypt.hashSync('admin123', 10);
            db.prepare(`
                INSERT INTO users (username, password, first_name, last_name, role)
                VALUES ('admin', ?, 'System', 'Developer', 'admin')
            `).run(hashedPassword);
            console.log('Default Admin created: admin / admin123');
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
