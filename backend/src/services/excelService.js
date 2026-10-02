'use strict';

const ExcelJS = require('exceljs');

/**
 * Generate Compliance Report Excel (.xlsx) buffer matching TIS RMS design and layout.
 *
 * @param {Object} data
 * @param {Object} data.studentCounts - { active, dropped, transferee, graduated, inactive, fourPs }
 * @param {Array} data.missingDocsBreakdown - [ { name, count } ]
 * @param {Array} data.students - [ { lrn, first_name, last_name, fullName, sex, grade_level, gradeLevel, section_name, sectionName, status, missing_count, missingCount, missing_requirements, missingRequirements } ]
 * @param {string} data.yearLabel - e.g. "2025-2026" or "All Years"
 * @returns {Promise<Buffer>}
 */
async function generateComplianceExcel({ studentCounts = {}, missingDocsBreakdown = [], students = [], yearLabel = 'All Years' }) {
    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'TIS RMS';
    workbook.lastModifiedBy = 'TIS RMS';
    workbook.created = new Date();
    workbook.modified = new Date();

    const borderThin = {
        top: { style: 'thin', color: { argb: 'FFE2E8F0' } },
        left: { style: 'thin', color: { argb: 'FFE2E8F0' } },
        bottom: { style: 'thin', color: { argb: 'FFE2E8F0' } },
        right: { style: 'thin', color: { argb: 'FFE2E8F0' } }
    };

    // ── SHEET 1: Summary ────────────────────────────────────────────────────────
    const summarySheet = workbook.addWorksheet('Summary', {
        views: [{ showGridLines: true }]
    });

    summarySheet.columns = [
        { width: 44 },
        { width: 18 }
    ];

    // Title & Metadata
    const titleRow = summarySheet.addRow(['TALISAY INTEGRATED SCHOOL - TIS RMS']);
    titleRow.font = { name: 'Arial', size: 14, bold: true, color: { argb: 'FF166534' } };

    const subTitleRow = summarySheet.addRow([`Annual Report Summary: ${yearLabel}`]);
    subTitleRow.font = { name: 'Arial', size: 11, bold: true, color: { argb: 'FF334155' } };

    const genDateStr = new Date().toISOString().replace('T', ' ').substring(0, 19);
    const dateRow = summarySheet.addRow([`Generated: ${genDateStr}`]);
    dateRow.font = { name: 'Arial', size: 9, italic: true, color: { argb: 'FF64748B' } };

    summarySheet.addRow([]); // Blank spacer

    // Section 1: Student Statistics
    const sec1Header = summarySheet.addRow(['STUDENT STATISTICS', '']);
    sec1Header.font = { name: 'Arial', size: 11, bold: true, color: { argb: 'FF166534' } };
    sec1Header.getCell(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF0FDF4' } };
    sec1Header.getCell(2).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF0FDF4' } };

    const statHeader = summarySheet.addRow(['Student Status', 'Total Count']);
    statHeader.font = { name: 'Arial', size: 10, bold: true, color: { argb: 'FF1E293B' } };
    statHeader.getCell(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF1F5F9' } };
    statHeader.getCell(2).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF1F5F9' } };
    statHeader.getCell(2).alignment = { horizontal: 'right' };
    statHeader.getCell(1).border = borderThin;
    statHeader.getCell(2).border = borderThin;

    const statsRowsData = [
        ['Active (Enrolled)', Number(studentCounts.active || 0)],
        ['Dropouts (Dropped)', Number(studentCounts.dropped || 0)],
        ['Transferees (Transferred)', Number(studentCounts.transferee || 0)],
        ['Graduated', Number(studentCounts.graduated || 0)],
    ];

    for (const [label, count] of statsRowsData) {
        const r = summarySheet.addRow([label, count]);
        r.font = { name: 'Arial', size: 10, color: { argb: 'FF334155' } };
        r.getCell(1).border = borderThin;
        r.getCell(2).border = borderThin;
        r.getCell(2).alignment = { horizontal: 'right' };
    }

    summarySheet.addRow([]); // Blank spacer

    // Section 2: Missing Documents Per Requirement Type
    const sec2Header = summarySheet.addRow(['MISSING DOCUMENTS PER REQUIREMENT TYPE', '']);
    sec2Header.font = { name: 'Arial', size: 11, bold: true, color: { argb: 'FF166534' } };
    sec2Header.getCell(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF0FDF4' } };
    sec2Header.getCell(2).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF0FDF4' } };

    const docHeader = summarySheet.addRow(['Document Type', 'Missing Count']);
    docHeader.font = { name: 'Arial', size: 10, bold: true, color: { argb: 'FF1E293B' } };
    docHeader.getCell(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF1F5F9' } };
    docHeader.getCell(2).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF1F5F9' } };
    docHeader.getCell(2).alignment = { horizontal: 'right' };
    docHeader.getCell(1).border = borderThin;
    docHeader.getCell(2).border = borderThin;

    if (missingDocsBreakdown.length === 0) {
        const r = summarySheet.addRow(['All student requirements complete', 0]);
        r.font = { name: 'Arial', size: 10, color: { argb: 'FF64748B' } };
        r.getCell(1).border = borderThin;
        r.getCell(2).border = borderThin;
        r.getCell(2).alignment = { horizontal: 'right' };
    } else {
        for (const row of missingDocsBreakdown) {
            const r = summarySheet.addRow([row.name, Number(row.count || 0)]);
            r.font = { name: 'Arial', size: 10, color: { argb: 'FF334155' } };
            r.getCell(1).border = borderThin;
            r.getCell(2).border = borderThin;
            r.getCell(2).alignment = { horizontal: 'right' };
        }
    }

    // ── SHEET 2: Student Compliance List ────────────────────────────────────────
    const listSheet = workbook.addWorksheet('Student Compliance List', {
        views: [{ state: 'frozen', xSplit: 0, ySplit: 1, showGridLines: true }]
    });

    listSheet.columns = [
        { header: '#', key: 'index', width: 6 },
        { header: 'LRN', key: 'lrn', width: 18 },
        { header: 'Student Name', key: 'student_name', width: 28 },
        { header: 'Sex', key: 'sex', width: 10 },
        { header: 'Grade Level', key: 'grade_level', width: 14 },
        { header: 'Section', key: 'section', width: 18 },
        { header: 'Status', key: 'status', width: 14 },
        { header: 'Missing Count', key: 'missing_count', width: 15 },
        { header: 'Missing Documents', key: 'missing_docs', width: 50 },
    ];

    // Style the header row
    const listHeaderRow = listSheet.getRow(1);
    listHeaderRow.height = 26;
    listHeaderRow.font = { name: 'Arial', size: 10, bold: true, color: { argb: 'FFFFFFFF' } };
    listHeaderRow.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FF166534' } // Forest Green
    };
    listHeaderRow.alignment = { vertical: 'middle', horizontal: 'center' };
    listHeaderRow.getCell('student_name').alignment = { vertical: 'middle', horizontal: 'left' };
    listHeaderRow.getCell('missing_docs').alignment = { vertical: 'middle', horizontal: 'left' };

    for (let c = 1; c <= 9; c++) {
        listHeaderRow.getCell(c).border = borderThin;
    }

    // Populate Student Data Rows
    for (let i = 0; i < students.length; i++) {
        const s = students[i];
        const fullName = s.fullName ||
            ([s.last_name, s.first_name].filter(Boolean).join(', ') || 'N/A');

        const gradeVal = s.grade_level != null ? s.grade_level : s.gradeLevel;
        const gradeStr = gradeVal != null ? `Grade ${gradeVal}` : 'N/A';

        const sectionStr = s.section_name || s.sectionName || 'N/A';
        const missingCount = s.missing_count != null ? Number(s.missing_count) : Number(s.missingCount || 0);
        const missingDocsStr = s.missing_requirements || s.missingRequirements ||
            (missingCount === 0 ? 'None (Complete)' : 'N/A');

        const row = listSheet.addRow({
            index: i + 1,
            lrn: s.lrn || '',
            student_name: fullName,
            sex: s.sex || 'N/A',
            grade_level: gradeStr,
            section: sectionStr,
            status: s.status || 'N/A',
            missing_count: missingCount,
            missing_docs: missingDocsStr,
        });

        row.height = 20;
        row.font = { name: 'Arial', size: 9.5, color: { argb: 'FF1F2937' } };

        const isEven = i % 2 === 1;
        const rowBg = isEven ? 'FFF8FAFC' : 'FFFFFFFF';

        for (let colIdx = 1; colIdx <= 9; colIdx++) {
            const cell = row.getCell(colIdx);
            cell.border = borderThin;
            cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: rowBg } };
            cell.alignment = { vertical: 'middle' };
        }

        // Specific cell alignments
        row.getCell('index').alignment = { vertical: 'middle', horizontal: 'center' };
        row.getCell('lrn').alignment = { vertical: 'middle', horizontal: 'center' };
        row.getCell('sex').alignment = { vertical: 'middle', horizontal: 'center' };
        row.getCell('grade_level').alignment = { vertical: 'middle', horizontal: 'center' };
        row.getCell('status').alignment = { vertical: 'middle', horizontal: 'center' };
        row.getCell('missing_count').alignment = { vertical: 'middle', horizontal: 'right' };
        row.getCell('student_name').alignment = { vertical: 'middle', horizontal: 'left' };
        row.getCell('missing_docs').alignment = { vertical: 'middle', horizontal: 'left' };

        // Highlight missing count if > 0
        if (missingCount > 0) {
            row.getCell('missing_count').font = {
                name: 'Arial',
                size: 9.5,
                bold: true,
                color: { argb: 'FFDC2626' }
            };
        } else {
            row.getCell('missing_count').font = {
                name: 'Arial',
                size: 9.5,
                color: { argb: 'FF166534' }
            };
        }
    }

    // Auto-filter on student list
    if (students.length > 0) {
        listSheet.autoFilter = {
            from: { row: 1, column: 1 },
            to: { row: students.length + 1, column: 9 }
        };
    }

    const buffer = await workbook.xlsx.writeBuffer();
    return Buffer.from(buffer);
}

module.exports = {
    generateComplianceExcel,
};
