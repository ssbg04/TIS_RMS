const db = require('../config/db');

// GET /api/reports/academic-years
exports.getAcademicYears = (req, res) => {
    try {
        const years = db.prepare('SELECT * FROM academic_years ORDER BY year_range ASC, id ASC').all();
        res.json(years);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch academic years', error: error.message });
    }
};

// GET /api/reports/stats?academicYearId=1&gradeLevel=7&sectionId=2&status=Enrolled
exports.getStats = (req, res) => {
    const { academicYearId, gradeLevel, sectionId, status } = req.query;
    try {
        let params = [];
        let enrollParams = [];
        let whereClauses = [];
        let enrollWhereClauses = [];

        if (req.user?.role === 'teacher') {
            whereClauses.push('e.section_id IN (SELECT section_id FROM teacher_sections WHERE teacher_id = ?)');
            enrollWhereClauses.push('e.section_id IN (SELECT section_id FROM teacher_sections WHERE teacher_id = ?)');
            params.push(req.user.id);
            enrollParams.push(req.user.id);
        }

        if (academicYearId) {
            whereClauses.push('e.academic_year_id = ?');
            enrollWhereClauses.push('e.academic_year_id = ?');
            params.push(academicYearId);
            enrollParams.push(academicYearId);
        }
        if (gradeLevel) {
            whereClauses.push('e.grade_level = ?');
            enrollWhereClauses.push('e.grade_level = ?');
            params.push(gradeLevel);
            enrollParams.push(gradeLevel);
        }
        if (sectionId) {
            whereClauses.push('e.section_id = ?');
            enrollWhereClauses.push('e.section_id = ?');
            params.push(sectionId);
            enrollParams.push(sectionId);
        }

        const whereSql = whereClauses.length > 0 ? 'AND ' + whereClauses.join(' AND ') : '';
        const enrollWhereSql = enrollWhereClauses.length > 0 ? 'AND ' + enrollWhereClauses.join(' AND ') : '';

        // 1. Fetch counts of active, inactive, dropped, transferee, graduated, and 4Ps beneficiaries
        const countsQuery = `
            SELECT 
                COUNT(DISTINCT CASE WHEN s.status = 'Enrolled' THEN s.id END) as active,
                COUNT(DISTINCT CASE WHEN s.status = 'Inactive' THEN s.id END) as inactive,
                COUNT(DISTINCT CASE WHEN s.status = 'Dropped' THEN s.id END) as dropped,
                COUNT(DISTINCT CASE WHEN s.status = 'Transferred' THEN s.id END) as transferee,
                COUNT(DISTINCT CASE WHEN s.status = 'Graduated' THEN s.id END) as graduated,
                COUNT(DISTINCT CASE WHEN s.is_4ps = 1 THEN s.id END) as fourPs
            FROM students s
            JOIN enrollments e ON s.id = e.student_id
                AND e.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay ON e2.academic_year_id = ay.id
                    WHERE e2.student_id = s.id
                      ${academicYearId ? 'AND e2.academic_year_id = ' + Number(academicYearId) : ''}
                    ORDER BY e2.grade_level DESC, ay.year_range DESC, e2.id DESC LIMIT 1
                )
            WHERE 1=1 ${enrollWhereSql}
        `;
        const studentCounts = db.prepare(countsQuery).get(enrollParams);

        // 2. Fetch missing documents count per requirement type
        const missingQuery = `
            SELECT r.id as requirementId, r.category || ' - ' || r.name as name, COUNT(DISTINCT s.id) as count
            FROM document_requirements r
            CROSS JOIN students s
            JOIN enrollments e ON s.id = e.student_id
                AND e.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay ON e2.academic_year_id = ay.id
                    WHERE e2.student_id = s.id
                      ${academicYearId ? 'AND e2.academic_year_id = ' + Number(academicYearId) : ''}
                    ORDER BY e2.grade_level DESC, ay.year_range DESC, e2.id DESC LIMIT 1
                )
            WHERE r.is_enabled = 1
              AND r.is_mandatory = 1
              AND r.category IN (
                  SELECT DISTINCT CASE WHEN grade_level <= 10 THEN 'JHS' ELSE 'SHS' END
                  FROM enrollments WHERE student_id = s.id
              )
              ${whereSql}
              AND NOT EXISTS (
                  SELECT 1 FROM documents d 
                  WHERE d.student_id = s.id 
                    AND d.requirement_id = r.id 
                    AND d.status = 'Completed'
                    AND d.deleted_at IS NULL
              )
            GROUP BY r.id, r.category, r.name
            ORDER BY count DESC
        `;
        const missingDocsBreakdown = db.prepare(missingQuery).all(params);

        // 3. Fetch students details list (filtered)
        let studentFilterSql = whereSql;
        let studentParams = [...params];
        if (status) {
            studentFilterSql += " AND s.status = ?";
            studentParams.push(status);
        }

        const studentsQuery = `
            SELECT s.id, s.lrn, s.first_name, s.last_name, s.sex, s.status,
                   e_latest.grade_level, sec.name as section_name,
                   (
                       SELECT COUNT(*) 
                       FROM document_requirements r
                       WHERE r.is_enabled = 1
                         AND r.is_mandatory = 1
                         AND r.category IN (
                             SELECT DISTINCT CASE WHEN grade_level <= 10 THEN 'JHS' ELSE 'SHS' END
                             FROM enrollments WHERE student_id = s.id
                         )
                         AND NOT EXISTS (
                             SELECT 1 FROM documents d 
                             WHERE d.student_id = s.id 
                               AND d.requirement_id = r.id 
                               AND d.status = 'Completed'
                               AND d.deleted_at IS NULL
                         )
                   ) as missing_count,
                   (
                       SELECT group_concat('[' || r.category || '] ' || r.name, ', ')
                       FROM document_requirements r
                       WHERE r.is_enabled = 1
                         AND r.is_mandatory = 1
                         AND r.category IN (
                             SELECT DISTINCT CASE WHEN grade_level <= 10 THEN 'JHS' ELSE 'SHS' END
                             FROM enrollments WHERE student_id = s.id
                         )
                         AND NOT EXISTS (
                             SELECT 1 FROM documents d 
                             WHERE d.student_id = s.id 
                               AND d.requirement_id = r.id 
                               AND d.status = 'Completed'
                               AND d.deleted_at IS NULL
                         )
                   ) as missing_requirements
            FROM students s
            JOIN enrollments e_latest ON s.id = e_latest.student_id
                AND e_latest.id = (
                    SELECT e2.id FROM enrollments e2
                    JOIN academic_years ay ON e2.academic_year_id = ay.id
                    WHERE e2.student_id = s.id
                      ${academicYearId ? 'AND e2.academic_year_id = ' + Number(academicYearId) : ''}
                    ORDER BY e2.grade_level DESC, ay.year_range DESC, e2.id DESC LIMIT 1
                )
            LEFT JOIN sections sec ON e_latest.section_id = sec.id
            WHERE 1=1 ${studentFilterSql.replace(/\be\./g, 'e_latest.')}
            ORDER BY s.last_name ASC, s.first_name ASC
            LIMIT 1000
        `;
        const studentsList = db.prepare(studentsQuery).all(studentParams);

        res.json({
            studentCounts,
            missingDocsBreakdown,
            students: studentsList
        });
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch report stats', error: error.message });
    }
};

// GET /api/reports/enrollment-by-grade?academicYearId=1
exports.getEnrollmentByGrade = (req, res) => {
    const { academicYearId } = req.query;
    try {
        let rows;
        if (academicYearId) {
            rows = db.prepare(`
                SELECT grade_level, COUNT(*) as count
                FROM enrollments
                WHERE academic_year_id = ?
                GROUP BY grade_level
                ORDER BY grade_level ASC
            `).all(academicYearId);
        } else {
            rows = db.prepare(`
                SELECT grade_level, COUNT(*) as count
                FROM enrollments
                GROUP BY grade_level
                ORDER BY grade_level ASC
            `).all();
        }
        res.json(rows);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch enrollment data', error: error.message });
    }
};

// GET /api/reports/document-status
exports.getDocumentStatus = (req, res) => {
    try {
        const rows = db.prepare(`
            SELECT status, COUNT(*) as count FROM documents WHERE deleted_at IS NULL GROUP BY status
        `).all();
        const result = { Completed: 0, Archived: 0 };
        rows.forEach(r => { if (r.status in result) result[r.status] = r.count; });
        res.json(result);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch document status', error: error.message });
    }
};

// GET /api/reports/export-data?academicYearId=1  — Full data payload for Excel export
exports.getExportData = (req, res) => {
    const { academicYearId } = req.query;
    try {
        // Enrollment summary per grade level
        let enrollmentByGrade;
        if (academicYearId) {
            enrollmentByGrade = db.prepare(`
                SELECT e.grade_level, COUNT(DISTINCT e.student_id) as total_students,
                       ay.year_range
                FROM enrollments e
                JOIN academic_years ay ON e.academic_year_id = ay.id
                WHERE e.academic_year_id = ?
                GROUP BY e.grade_level
                ORDER BY e.grade_level ASC
            `).all(academicYearId);
        } else {
            enrollmentByGrade = db.prepare(`
                SELECT e.grade_level, COUNT(DISTINCT e.student_id) as total_students,
                       'All Years' as year_range
                FROM enrollments e
                GROUP BY e.grade_level
                ORDER BY e.grade_level ASC
            `).all();
        }

        // Document status breakdown
        const docStatusRows = db.prepare(`
            SELECT status, COUNT(*) as count FROM documents WHERE deleted_at IS NULL GROUP BY status
        `).all();
        const documentStatus = { Completed: 0, Archived: 0 };
        docStatusRows.forEach(r => { if (r.status in documentStatus) documentStatus[r.status] = r.count; });

        // Student detail list with document compliance
        let students;
        if (academicYearId) {
            students = db.prepare(`
                SELECT s.lrn, s.first_name, s.last_name, s.sex, e.grade_level,
                       COUNT(CASE WHEN d.status = 'Completed' THEN 1 END) as verified_docs,
                       COUNT(CASE WHEN d.status = 'Archived' THEN 1 END) as archived_docs
                FROM students s
                JOIN enrollments e ON s.id = e.student_id AND e.academic_year_id = ?
                LEFT JOIN documents d ON s.id = d.student_id AND d.deleted_at IS NULL
                GROUP BY s.id
                ORDER BY s.last_name ASC
                LIMIT 500
            `).all(academicYearId);
        } else {
            students = db.prepare(`
                SELECT s.lrn, s.first_name, s.last_name, s.sex,
                       e_latest.grade_level,
                       COUNT(CASE WHEN d.status = 'Completed' THEN 1 END) as verified_docs,
                       COUNT(CASE WHEN d.status = 'Archived' THEN 1 END) as archived_docs
                FROM students s
                LEFT JOIN enrollments e_latest ON s.id = e_latest.student_id
                    AND e_latest.id = (
                        SELECT e2.id FROM enrollments e2
                        JOIN academic_years ay ON e2.academic_year_id = ay.id
                        WHERE e2.student_id = s.id
                        ORDER BY e2.grade_level DESC, ay.year_range DESC, e2.id DESC LIMIT 1
                    )
                LEFT JOIN documents d ON s.id = d.student_id AND d.deleted_at IS NULL
                GROUP BY s.id
                ORDER BY s.last_name ASC
                LIMIT 500
            `).all();
        }

        res.json({ enrollmentByGrade, documentStatus, students });
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch export data', error: error.message });
    }
};

// GET /api/reports/yearly-comparison
exports.getYearlyComparison = (req, res) => {
    try {
        const query = `
            SELECT 
                ay.year_range as year,
                COUNT(DISTINCT CASE WHEN (CASE WHEN e.academic_year_id = sly.max_ay_id THEN s.status ELSE 'Enrolled' END) = 'Enrolled' THEN s.id END) as enrolled,
                COUNT(DISTINCT CASE WHEN (CASE WHEN e.academic_year_id = sly.max_ay_id THEN s.status ELSE 'Enrolled' END) = 'Inactive' THEN s.id END) as inactive,
                COUNT(DISTINCT CASE WHEN (CASE WHEN e.academic_year_id = sly.max_ay_id THEN s.status ELSE 'Enrolled' END) = 'Dropped' THEN s.id END) as dropped,
                COUNT(DISTINCT CASE WHEN (CASE WHEN e.academic_year_id = sly.max_ay_id THEN s.status ELSE 'Enrolled' END) = 'Graduated' THEN s.id END) as graduated,
                COUNT(DISTINCT CASE WHEN (CASE WHEN e.academic_year_id = sly.max_ay_id THEN s.status ELSE 'Enrolled' END) = 'Transferred' THEN s.id END) as transferred
            FROM academic_years ay
            LEFT JOIN enrollments e ON ay.id = e.academic_year_id
            LEFT JOIN students s ON e.student_id = s.id
            LEFT JOIN (
                SELECT e1.student_id, e1.academic_year_id as max_ay_id
                FROM enrollments e1
                JOIN academic_years ay1 ON e1.academic_year_id = ay1.id
                WHERE NOT EXISTS (
                    SELECT 1
                    FROM enrollments e2
                    JOIN academic_years ay2 ON e2.academic_year_id = ay2.id
                    WHERE e2.student_id = e1.student_id
                      AND ay2.year_range > ay1.year_range
                )
            ) sly ON s.id = sly.student_id
            GROUP BY ay.id, ay.year_range
            ORDER BY ay.year_range ASC
        `;
        const data = db.prepare(query).all();
        res.json(data);
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch yearly comparison', error: error.message });
    }
};

// GET /api/reports/storage
exports.getStorageUsed = async (req, res) => {
    const fs = require('fs');
    const path = require('path');
    const { promisify } = require('util');
    const stat = promisify(fs.stat);

    try {
        const rootDir = path.join(__dirname, '../../');
        const dbPath = process.env.DB_PATH
            ? path.resolve(process.env.DB_PATH)
            : path.join(rootDir, 'data', 'tis_rms.db');

        const dbWalPath = `${dbPath}-wal`;
        const dbShmPath = `${dbPath}-shm`;
        const legacyDbPath = path.join(rootDir, 'tis_rms.db');

        let totalSize = 0;

        const addFileSize = async (filePath) => {
            try {
                const fileStat = await stat(filePath);
                if (fileStat.isFile()) {
                    totalSize += fileStat.size;
                }
            } catch (e) {
                // Ignore missing file
            }
        };

        await addFileSize(dbPath);
        await addFileSize(dbWalPath);
        await addFileSize(dbShmPath);
        if (legacyDbPath !== dbPath) {
            await addFileSize(legacyDbPath);
        }

        res.json({ bytes: totalSize });
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch storage usage', error: error.message });
    }
};

// GET /api/reports/transparency-board
exports.getTransparencyBoardData = (req, res) => {
    try {
        const { academicYearId, yearIds } = req.query;
        let academicYears = [];

        if (yearIds) {
            const ids = yearIds.toString().split(',').map(id => Number(id.trim())).filter(id => !isNaN(id));
            if (ids.length > 0) {
                const placeholders = ids.map(() => '?').join(',');
                academicYears = db.prepare(`
                    SELECT id, year_range 
                    FROM academic_years 
                    WHERE id IN (${placeholders})
                    ORDER BY year_range ASC
                `).all(...ids);
            }
        } else if (academicYearId) {
            const targetYear = db.prepare('SELECT id, year_range FROM academic_years WHERE id = ?').get(academicYearId);
            if (targetYear) {
                academicYears = db.prepare(`
                    SELECT id, year_range 
                    FROM academic_years 
                    WHERE year_range <= ?
                    ORDER BY year_range DESC 
                    LIMIT 3
                `).all(targetYear.year_range).reverse();
            }
        }

        if (academicYears.length === 0) {
            const activeAy = db.prepare("SELECT id, year_range FROM academic_years WHERE status = 'active' LIMIT 1").get()
                || db.prepare("SELECT id, year_range FROM academic_years ORDER BY year_range DESC LIMIT 1").get();

            if (activeAy) {
                academicYears = db.prepare(`
                    SELECT id, year_range 
                    FROM academic_years 
                    WHERE year_range <= ?
                    ORDER BY year_range DESC 
                    LIMIT 3
                `).all(activeAy.year_range).reverse();
            } else {
                academicYears = db.prepare(`
                    SELECT id, year_range 
                    FROM academic_years 
                    ORDER BY year_range DESC 
                    LIMIT 3
                `).all().reverse();
            }
        }

        const yearsData = academicYears.map(ay => {
            // Enrollment breakdown by sex & grade — COUNT DISTINCT students
            // to avoid double-counting students with multiple enrollment rows.
            const enrollRows = db.prepare(`
                SELECT 
                    e.grade_level,
                    COUNT(DISTINCT CASE WHEN s.sex = 'Male' THEN s.id END) as male,
                    COUNT(DISTINCT CASE WHEN s.sex = 'Female' THEN s.id END) as female,
                    COUNT(DISTINCT s.id) as total
                FROM enrollments e
                JOIN students s ON e.student_id = s.id
                WHERE e.academic_year_id = ?
                GROUP BY e.grade_level
            `).all(ay.id);

            const gradesEnrollment = [7, 8, 9, 10, 11, 12].map(g => {
                const row = enrollRows.find(r => Number(r.grade_level) === g) || { male: 0, female: 0, total: 0 };
                return {
                    gradeLevel: g,
                    male: Number(row.male) || 0,
                    female: Number(row.female) || 0,
                    total: Number(row.total) || 0
                };
            });

            const jhsTotal = gradesEnrollment.filter(g => g.gradeLevel <= 10).reduce((acc, curr) => ({
                male: acc.male + curr.male,
                female: acc.female + curr.female,
                total: acc.total + curr.total
            }), { male: 0, female: 0, total: 0 });

            const shsTotal = gradesEnrollment.filter(g => g.gradeLevel > 10).reduce((acc, curr) => ({
                male: acc.male + curr.male,
                female: acc.female + curr.female,
                total: acc.total + curr.total
            }), { male: 0, female: 0, total: 0 });

            const overallTotal = {
                male: jhsTotal.male + shsTotal.male,
                female: jhsTotal.female + shsTotal.female,
                total: jhsTotal.total + shsTotal.total
            };

            // Dropout breakdown by grade
            const dropoutRows = db.prepare(`
                SELECT 
                    e.grade_level,
                    COUNT(DISTINCT s.id) as droppedCount
                FROM enrollments e
                JOIN students s ON e.student_id = s.id
                WHERE e.academic_year_id = ?
                  AND s.status = 'Dropped'
                  AND e.academic_year_id = (SELECT MAX(e2.academic_year_id) FROM enrollments e2 WHERE e2.student_id = s.id)
                GROUP BY e.grade_level
            `).all(ay.id);

            const gradesDropout = [7, 8, 9, 10, 11, 12].map(g => {
                const row = dropoutRows.find(r => Number(r.grade_level) === g) || { droppedCount: 0 };
                return {
                    gradeLevel: g,
                    droppedCount: Number(row.droppedCount) || 0
                };
            });

            const totalDropped = gradesDropout.reduce((sum, g) => sum + g.droppedCount, 0);

            // Transferee breakdown by grade
            const transfereeRows = db.prepare(`
                SELECT 
                    e.grade_level,
                    COUNT(DISTINCT s.id) as transferredCount
                FROM enrollments e
                JOIN students s ON e.student_id = s.id
                WHERE e.academic_year_id = ?
                  AND s.status = 'Transferred'
                  AND e.academic_year_id = (SELECT MAX(e2.academic_year_id) FROM enrollments e2 WHERE e2.student_id = s.id)
                GROUP BY e.grade_level
            `).all(ay.id);

            const gradesTransferee = [7, 8, 9, 10, 11, 12].map(g => {
                const row = transfereeRows.find(r => Number(r.grade_level) === g) || { transferredCount: 0 };
                return {
                    gradeLevel: g,
                    transferredCount: Number(row.transferredCount) || 0
                };
            });

            const totalTransferred = gradesTransferee.reduce((sum, g) => sum + g.transferredCount, 0);

            // 4Ps breakdown by grade for this specific academic year
            const fourPsRows = db.prepare(`
                SELECT 
                    e.grade_level,
                    COUNT(DISTINCT CASE WHEN s.is_4ps = 1 THEN s.id END) as fourPsCount,
                    COUNT(DISTINCT s.id) as totalStudents
                FROM enrollments e
                JOIN students s ON e.student_id = s.id
                WHERE e.academic_year_id = ?
                GROUP BY e.grade_level
            `).all(ay.id);

            const grades4Ps = [7, 8, 9, 10, 11, 12].map(g => {
                const row = fourPsRows.find(r => Number(r.grade_level) === g) || { fourPsCount: 0, totalStudents: 0 };
                const count = Number(row.fourPsCount) || 0;
                const total = Number(row.totalStudents) || 0;
                const percentage = total > 0 ? Number((count / total * 100).toFixed(1)) : 0;
                return {
                    gradeLevel: g,
                    fourPsCount: count,
                    totalStudents: total,
                    percentage
                };
            });

            const jhs4PsCount = grades4Ps.filter(g => g.gradeLevel <= 10).reduce((sum, g) => sum + g.fourPsCount, 0);
            const jhs4PsTotalStudents = grades4Ps.filter(g => g.gradeLevel <= 10).reduce((sum, g) => sum + g.totalStudents, 0);
            const jhs4PsPercentage = jhs4PsTotalStudents > 0 ? Number((jhs4PsCount / jhs4PsTotalStudents * 100).toFixed(1)) : 0;

            const shs4PsCount = grades4Ps.filter(g => g.gradeLevel > 10).reduce((sum, g) => sum + g.fourPsCount, 0);
            const shs4PsTotalStudents = grades4Ps.filter(g => g.gradeLevel > 10).reduce((sum, g) => sum + g.totalStudents, 0);
            const shs4PsPercentage = shs4PsTotalStudents > 0 ? Number((shs4PsCount / shs4PsTotalStudents * 100).toFixed(1)) : 0;

            const total4Ps = grades4Ps.reduce((sum, g) => sum + g.fourPsCount, 0);
            const totalStudents4Ps = grades4Ps.reduce((sum, g) => sum + g.totalStudents, 0);
            const overallPercentage = totalStudents4Ps > 0 ? Number((total4Ps / totalStudents4Ps * 100).toFixed(1)) : 0;

            const fourPs = {
                grades: grades4Ps,
                jhsTotal: {
                    fourPsCount: jhs4PsCount,
                    totalStudents: jhs4PsTotalStudents,
                    percentage: jhs4PsPercentage
                },
                shsTotal: {
                    fourPsCount: shs4PsCount,
                    totalStudents: shs4PsTotalStudents,
                    percentage: shs4PsPercentage
                },
                overallTotal: {
                    fourPsCount: total4Ps,
                    totalStudents: totalStudents4Ps,
                    percentage: overallPercentage
                }
            };

            return {
                yearRange: ay.year_range,
                enrollment: {
                    grades: gradesEnrollment,
                    jhsTotal,
                    shsTotal,
                    overallTotal
                },
                dropouts: {
                    grades: gradesDropout,
                    totalDropped
                },
                transferees: {
                    grades: gradesTransferee,
                    totalTransferred
                },
                fourPs
            };
        });

        // Top level equity4Ps uses the active / selected year's 4Ps data
        const latestYearData = yearsData.length > 0 ? yearsData[yearsData.length - 1] : null;
        const equity4Ps = latestYearData?.fourPs
            ? {
                grades: latestYearData.fourPs.grades,
                total4Ps: latestYearData.fourPs.overallTotal.fourPsCount,
                totalStudents: latestYearData.fourPs.overallTotal.totalStudents,
                overallPercentage: latestYearData.fourPs.overallTotal.percentage
            }
            : {
                grades: [7, 8, 9, 10, 11, 12].map(g => ({ gradeLevel: g, fourPsCount: 0, totalStudents: 0, percentage: 0 })),
                total4Ps: 0,
                totalStudents: 0,
                overallPercentage: 0
            };

        res.json({
            years: yearsData,
            equity4Ps
        });
    } catch (error) {
        res.status(500).json({ message: 'Failed to fetch transparency board data', error: error.message });
    }
};

