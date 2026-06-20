const db = require('./config/db');

function seedDocuments() {
    console.log('Seeding random documents for students...');
    db.pragma('foreign_keys = OFF');
    db.transaction(() => {
        // Get all students
        const students = db.prepare('SELECT id FROM students').all();
        if (students.length === 0) {
            console.log('No students found! Run seed.js first.');
            return;
        }

        // Get admin user to assign as uploaded_by
        const adminUser = db.prepare("SELECT id FROM users WHERE role = 'admin' LIMIT 1").get();
        const uploadedBy = adminUser ? adminUser.id : null;

        // Get document requirements
        const reqs = db.prepare('SELECT id, name FROM document_requirements').all();
        if (reqs.length === 0) {
            console.log('No document requirements found!');
            return;
        }

        const insertDoc = db.prepare(`
            INSERT INTO documents (student_id, requirement_id, file_name, file_path, document_type, status, uploaded_by, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `);

        const startTimestamp = Date.now() - (365 * 24 * 60 * 60 * 1000); // Up to 1 year ago

        let docCount = 0;
        for (const student of students) {
            // Give each student 2 to 6 random documents
            const numDocs = 2 + Math.floor(Math.random() * 5);
            
            // Pick random unique requirements for this student
            const studentReqs = [...reqs].sort(() => 0.5 - Math.random()).slice(0, numDocs);

            for (const req of studentReqs) {
                // Generate a dummy file name
                const randomId = Math.floor(1000 + Math.random() * 9000);
                const isPdf = Math.random() > 0.3;
                const ext = isPdf ? '.pdf' : '.jpg';
                const fileName = `${req.name.replace(/\s+/g, '_')}_${randomId}${ext}`;
                const filePath = `/uploads/dummy/${fileName}`; // Just a dummy path
                const mimeType = isPdf ? 'application/pdf' : 'image/jpeg';
                
                // Random past date for created_at
                const randomTime = startTimestamp + Math.random() * (Date.now() - startTimestamp);
                const createdAt = new Date(randomTime).toISOString().replace(/\.\d{3}Z$/, 'Z');
                
                // Status mostly Completed, sometimes Archived
                const status = Math.random() > 0.9 ? 'Archived' : 'Completed';

                insertDoc.run(
                    student.id,
                    req.id,
                    fileName,
                    filePath,
                    mimeType,
                    status,
                    uploadedBy,
                    createdAt
                );
                docCount++;
            }
        }
        
        console.log(`Successfully seeded ${docCount} documents across ${students.length} students!`);
    })();
    db.pragma('foreign_keys = ON');
}

seedDocuments();
