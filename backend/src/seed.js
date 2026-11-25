const db = require('./config/db');

function seedData() {
    console.log('Seeding random data...');
    db.pragma('foreign_keys = OFF');
    db.transaction(() => {
        // 1. Add Academic Years
        const years = ['2022-2023', '2023-2024', '2024-2025', '2025-2026', '2026-2027'];
        const insertYear = db.prepare('INSERT OR IGNORE INTO academic_years (year_range, status) VALUES (?, ?)');
        const yearIds = [];
        for (let i = 0; i < years.length; i++) {
            const status = years[i] === '2023-2024' ? 'active' : 'inactive'; // one active year
            const res = insertYear.run(years[i], status);
            let id = res.lastInsertRowid;
            if (id === 0) {
                // Was ignored, get ID
                id = db.prepare('SELECT id FROM academic_years WHERE year_range = ?').get(years[i]).id;
            }
            yearIds.push({ id, year_range: years[i] });
        }

        // 2. Add Sections for each Grade (7 to 12) across different academic years
        const sections = ['Aristotle', 'Socrates', 'Plato', 'Archimedes', 'Pythagoras', 'Galileo', 'Newton', 'Einstein'];
        const insertSection = db.prepare('INSERT INTO sections (name, grade_level, academic_year_id) VALUES (?, ?, ?)');
        const sectionIds = []; // store {id, grade_level, academic_year_id}
        
        for (const year of yearIds) {
            for (let grade = 7; grade <= 12; grade++) {
                // 2 random sections per grade per year
                const shuffledSections = [...sections].sort(() => 0.5 - Math.random());
                for (let s = 0; s < 2; s++) {
                    const res = insertSection.run(shuffledSections[s], grade, year.id);
                    sectionIds.push({ id: res.lastInsertRowid, grade_level: grade, academic_year_id: year.id });
                }
            }
        }

        // 3. Add Random Students
        const firstNamesMale = ['James', 'John', 'Robert', 'Michael', 'William', 'David', 'Richard', 'Joseph', 'Thomas', 'Charles', 'Christopher', 'Daniel', 'Matthew', 'Anthony', 'Mark', 'Donald', 'Steven', 'Paul', 'Andrew', 'Joshua'];
        const firstNamesFemale = ['Mary', 'Patricia', 'Jennifer', 'Linda', 'Elizabeth', 'Barbara', 'Susan', 'Jessica', 'Sarah', 'Karen', 'Lisa', 'Nancy', 'Betty', 'Margaret', 'Sandra', 'Ashley', 'Kimberly', 'Emily', 'Donna', 'Michelle'];
        const lastNames = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin', 'Lee', 'Perez', 'Thompson', 'White', 'Harris', 'Sanchez', 'Clark', 'Ramirez', 'Lewis', 'Robinson', 'Walker', 'Young', 'Allen', 'King', 'Wright', 'Scott', 'Torres', 'Nguyen', 'Hill', 'Flores'];
        
        const insertStudent = db.prepare(`
            INSERT INTO students (lrn, first_name, middle_name, last_name, sex, birth_date, status)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        `);

        const insertEnrollment = db.prepare(`
            INSERT INTO enrollments (student_id, academic_year_id, section_id, grade_level, track_strand)
            VALUES (?, ?, ?, ?, ?)
        `);

        // Generate 500 students
        for (let i = 1; i <= 500; i++) {
            const isMale = Math.random() > 0.5;
            const firstName = isMale ? firstNamesMale[Math.floor(Math.random() * firstNamesMale.length)] : firstNamesFemale[Math.floor(Math.random() * firstNamesFemale.length)];
            const lastName = lastNames[Math.floor(Math.random() * lastNames.length)];
            const middleName = lastNames[Math.floor(Math.random() * lastNames.length)];
            const sex = isMale ? 'Male' : 'Female';
            const lrn = '101' + Math.floor(100000000 + Math.random() * 900000000).toString(); // 12 digit LRN
            
            // Random birth date between 12 and 18 years ago
            const age = 12 + Math.floor(Math.random() * 6);
            const birthYear = 2024 - age;
            const birthMonth = Math.floor(Math.random() * 12) + 1;
            const birthDay = Math.floor(Math.random() * 28) + 1;
            const birthDate = `${birthYear}-${birthMonth.toString().padStart(2, '0')}-${birthDay.toString().padStart(2, '0')}`;
            
            // Status distribution: mostly Enrolled, some Graduated, few Transferred/Dropped
            const randStatus = Math.random();
            let status = 'Enrolled';
            if (randStatus > 0.9) status = 'Graduated';
            else if (randStatus > 0.85) status = 'Transferred';
            else if (randStatus > 0.8) status = 'Dropped';

            try {
                const res = insertStudent.run(lrn, firstName, middleName, lastName, sex, birthDate, status);
                const studentId = res.lastInsertRowid;

                // Enroll the student in 1 to 3 random years sequentially
                // Just to give them some history
                const studentStartYearIndex = Math.floor(Math.random() * (yearIds.length - 2));
                let currentGrade = 7 + Math.floor(Math.random() * 4); // Start at grade 7-10

                for (let y = studentStartYearIndex; y < yearIds.length && currentGrade <= 12; y++) {
                    const year = yearIds[y];
                    
                    // Find a section for this year and grade
                    const availableSections = sectionIds.filter(s => s.academic_year_id === year.id && s.grade_level === currentGrade);
                    if (availableSections.length > 0) {
                        const section = availableSections[Math.floor(Math.random() * availableSections.length)];
                        const trackStrand = currentGrade >= 11 ? 'STEM' : null; // simplified track
                        insertEnrollment.run(studentId, year.id, section.id, currentGrade, trackStrand);
                    }
                    
                    currentGrade++;
                }
            } catch (err) {
                // Ignore unique LRN constraint errors
                if (!err.message.includes('UNIQUE constraint failed')) {
                    console.error(err);
                }
            }
        }
    })();
    db.pragma('foreign_keys = ON');
    console.log('Seeding completed successfully!');
}

seedData();
