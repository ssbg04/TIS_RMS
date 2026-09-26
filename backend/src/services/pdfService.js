const fs = require('fs');
const path = require('path');
const { PDFDocument } = require('pdf-lib');
const sharp = require('sharp');
const PDFKit = require('pdfkit');
const db = require('../config/db');

// Short bond paper size in points (8.5 x 11 inches at 72 DPI)
const SHORT_BOND_WIDTH = 612;
const SHORT_BOND_HEIGHT = 792;

/**
 * Merges multiple documents (PDFs and images) into a single PDF.
 * Settings:
 * - 0 padding, 0 margins
 * - Short bond paper size (612 x 792 points)
 */
async function mergeDocumentsToPdf({ documentIds, userId }) {
    let docs = [];

    if (Array.isArray(documentIds) && documentIds.length > 0) {
        const placeholders = documentIds.map(() => '?').join(',');
        docs = db.prepare(`
            SELECT id, file_name, file_path
            FROM documents
            WHERE id IN (${placeholders}) AND deleted_at IS NULL
        `).all(...documentIds);

        // Preserve input order
        const docMap = new Map(docs.map(d => [d.id, d]));
        docs = documentIds.map(id => docMap.get(id)).filter(Boolean);
    } else if (userId) {
        docs = db.prepare(`
            SELECT d.id, d.file_name, d.file_path
            FROM print_queue pq
            JOIN documents d ON pq.document_id = d.id
            WHERE pq.user_id = ? AND d.deleted_at IS NULL
            ORDER BY pq.added_at ASC, pq.id ASC
        `).all(userId);
    }

    if (!docs.length) {
        throw new Error('No valid documents found to merge.');
    }

    const mergedPdf = await PDFDocument.create();

    for (const doc of docs) {
        const fullPath = path.resolve(doc.file_path);
        if (!fs.existsSync(fullPath)) {
            console.warn(`[pdfService.mergeDocumentsToPdf] Missing file on disk: ${fullPath}`);
            continue;
        }

        const fileBytes = await fs.promises.readFile(fullPath);
        const ext = path.extname(doc.file_name || doc.file_path || '').toLowerCase();
        const isPdf = ext === '.pdf';

        if (isPdf) {
            try {
                const srcDoc = await PDFDocument.load(fileBytes);
                const pageCount = srcDoc.getPageCount();

                for (let i = 0; i < pageCount; i++) {
                    const [embeddedPage] = await mergedPdf.embedPdf(srcDoc, [i]);
                    const page = mergedPdf.addPage([SHORT_BOND_WIDTH, SHORT_BOND_HEIGHT]);

                    // Scale to fit Short Bond dimensions preserving aspect ratio with 0 margins / 0 padding
                    const scale = Math.min(
                        SHORT_BOND_WIDTH / embeddedPage.width,
                        SHORT_BOND_HEIGHT / embeddedPage.height
                    );
                    const drawWidth = embeddedPage.width * scale;
                    const drawHeight = embeddedPage.height * scale;
                    const x = (SHORT_BOND_WIDTH - drawWidth) / 2;
                    const y = (SHORT_BOND_HEIGHT - drawHeight) / 2;

                    page.drawPage(embeddedPage, {
                        x,
                        y,
                        width: drawWidth,
                        height: drawHeight,
                    });
                }
            } catch (err) {
                console.error(`[pdfService] Failed to load/embed PDF doc ID ${doc.id}:`, err);
            }
        } else {
            // Assume image (JPG, PNG, WEBP, etc.)
            try {
                // Normalize image to PNG buffer using sharp
                const pngBuffer = await sharp(fileBytes).png().toBuffer();
                const embeddedImage = await mergedPdf.embedPng(pngBuffer);
                const page = mergedPdf.addPage([SHORT_BOND_WIDTH, SHORT_BOND_HEIGHT]);

                // Scale to fit Short Bond dimensions preserving aspect ratio with 0 margins / 0 padding
                const scale = Math.min(
                    SHORT_BOND_WIDTH / embeddedImage.width,
                    SHORT_BOND_HEIGHT / embeddedImage.height
                );
                const drawWidth = embeddedImage.width * scale;
                const drawHeight = embeddedImage.height * scale;
                const x = (SHORT_BOND_WIDTH - drawWidth) / 2;
                const y = (SHORT_BOND_HEIGHT - drawHeight) / 2;

                page.drawImage(embeddedImage, {
                    x,
                    y,
                    width: drawWidth,
                    height: drawHeight,
                });
            } catch (err) {
                console.error(`[pdfService] Failed to process/embed image doc ID ${doc.id}:`, err);
            }
        }
    }

    if (mergedPdf.getPageCount() === 0) {
        throw new Error('No printable pages could be rendered from the documents.');
    }

    const savedBytes = await mergedPdf.save();
    return Buffer.from(savedBytes);
}

// Helper formatting functions
function formatDiff(diff, hasPrev) {
    if (!hasPrev || diff === null || diff === undefined) return '-';
    return diff > 0 ? `+${diff}` : String(diff);
}

function getRemark(diff, hasPrev) {
    if (!hasPrev || diff === null || diff === undefined) return 'Baseline';
    if (diff > 0) return 'Increasing';
    if (diff < 0) return 'Decreasing';
    return 'Maintained';
}

/**
 * Generates Official DepEd Reports in standard A4 Layout.
 * Supports:
 * - 'all': Full DepEd Transparency Board Report (All sections, 2 pages)
 * - 'enrollment': Individual Data on Enrollment Report (1 page)
 * - 'dropouts_transferees': Individual Dropouts & Transferees Report (1 page)
 * - '4ps': Individual 4Ps Beneficiaries Equity Report (1 page)
 */
function generateTransparencyBoardPdf(data, options = {}) {
    return new Promise((resolve, reject) => {
        try {
            const schoolName = options.schoolName || 'TALISAY INTEGRATED SCHOOL';
            const divisionName = options.divisionName || 'Schools Division of Quezon Province';
            const regionName = options.regionName || 'Region IV-A CALABARZON';
            const category = (options.category || 'all').toLowerCase();

            const assetsDir = path.resolve(__dirname, '../../assets');
            const sealPath = path.join(assetsDir, 'Seal_DepEd.png');
            const quezonPath = path.join(assetsDir, 'DepEd_Quezon.png');
            const qaPath = path.join(assetsDir, 'QA.png');

            const years = data.years || [];
            const latestYear = years.length > 0 ? years[years.length - 1] : null;
            const previousYear = years.length > 1 ? years[years.length - 2] : null;
            const hasPrev = !!previousYear;

            const activeSyLabel = latestYear ? `SY ${latestYear.yearRange}` : 'N/A';
            const prevSyLabel = hasPrev ? `SY ${previousYear.yearRange}` : 'Previous SY';
            const referencePeriod = hasPrev ? `${prevSyLabel} vs. ${activeSyLabel}` : `${activeSyLabel} (Baseline)`;
            const generatedDate = new Date().toISOString().replace('T', ' ').substring(0, 19);

            const doc = new PDFKit({
                size: 'A4',
                margins: { top: 18, bottom: 0, left: 28, right: 28 },
                bufferPages: true,
                autoFirstPage: true,
            });

            const buffers = [];
            doc.on('data', b => buffers.push(b));
            doc.on('end', () => resolve(Buffer.concat(buffers)));
            doc.on('error', reject);

            const pageWidth = 595.28;
            const pageHeight = 841.89;
            const leftMargin = 28;
            const rightMargin = 28;
            const contentWidth = pageWidth - leftMargin - rightMargin;

            // ════════════════════════════════════════════════════════════════
            // CATEGORY 1: INDIVIDUAL ENROLLMENT EXPORT (1 Page)
            // ════════════════════════════════════════════════════════════════
            if (category === 'enrollment') {
                drawDepEdHeader(doc, {
                    sealPath, pageWidth, leftMargin, rightMargin, contentWidth,
                    regionName, divisionName, schoolName,
                    title: 'DEPED TRANSPARENCY REPORT - DATA ON ENROLLMENT',
                    referencePeriod, generatedDate
                });

                // Section 1: Data on Enrollment Table (Comparative)
                drawSectionBar(doc, '1. DATA ON ENROLLMENT (KEY STAGE 3 & 4 BREAKDOWN)', leftMargin, contentWidth);
                doc.moveDown(0.3);
                drawEnrollmentTable(doc, leftMargin, contentWidth, latestYear, previousYear, hasPrev, prevSyLabel, activeSyLabel);
                doc.moveDown(0.6);

                // Section 2: Gender Breakdown Table (Male/Female)
                drawSectionBar(doc, `2. ENROLLMENT BY SEX (GENDER BREAKDOWN - ${activeSyLabel})`, leftMargin, contentWidth);
                doc.moveDown(0.3);
                drawEnrollmentBySexTable(doc, leftMargin, contentWidth, latestYear);
                doc.moveDown(0.8);

                // Section 3: Official Signatories
                drawSectionBar(doc, '3. OFFICIAL SIGNATORIES & CERTIFICATION', leftMargin, contentWidth);
                doc.moveDown(0.6);
                drawSignatoryBlock(doc, leftMargin, contentWidth);

            // ════════════════════════════════════════════════════════════════
            // CATEGORY 2: INDIVIDUAL DROPOUTS & TRANSFEREES EXPORT (1 Page)
            // ════════════════════════════════════════════════════════════════
            } else if (category === 'dropouts_transferees' || category === 'dropouts') {
                drawDepEdHeader(doc, {
                    sealPath, pageWidth, leftMargin, rightMargin, contentWidth,
                    regionName, divisionName, schoolName,
                    title: 'DEPED TRANSPARENCY REPORT - DROPOUTS & TRANSFEREES',
                    referencePeriod, generatedDate
                });

                // Section 1: Dropouts Table
                drawSectionBar(doc, '1. DROPOUTS MULTI-YEAR COMPARATIVE BREAKDOWN', leftMargin, contentWidth);
                doc.moveDown(0.3);
                drawMultiYearStatTable(doc, leftMargin, contentWidth, years, 'dropouts', 'droppedCount', 'TOTAL DROPOUTS', '#e2e8f0', '#0f172a');
                doc.moveDown(0.5);

                // Section 2: Transferees Table
                drawSectionBar(doc, '2. TRANSFEREES MULTI-YEAR COMPARATIVE BREAKDOWN', leftMargin, contentWidth);
                doc.moveDown(0.3);
                drawMultiYearStatTable(doc, leftMargin, contentWidth, years, 'transferees', 'transferredCount', 'TOTAL TRANSFEREES', '#e2e8f0', '#0f172a');
                doc.moveDown(0.5);

                // Section 3: Retention & Learner Mobility Summary
                drawSectionBar(doc, '3. RETENTION & LEARNER MOBILITY SUMMARY', leftMargin, contentWidth);
                doc.moveDown(0.3);
                drawRetentionSummaryTable(doc, leftMargin, contentWidth, years);
                doc.moveDown(0.8);

                // Section 4: Official Signatories
                drawSectionBar(doc, '4. OFFICIAL SIGNATORIES & CERTIFICATION', leftMargin, contentWidth);
                doc.moveDown(0.6);
                drawSignatoryBlock(doc, leftMargin, contentWidth);

            // ════════════════════════════════════════════════════════════════
            // CATEGORY 3: INDIVIDUAL 4Ps BENEFICIARIES EXPORT (1 Page)
            // ════════════════════════════════════════════════════════════════
            } else if (category === '4ps' || category === 'four_ps' || category === 'equity4ps') {
                drawDepEdHeader(doc, {
                    sealPath, pageWidth, leftMargin, rightMargin, contentWidth,
                    regionName, divisionName, schoolName,
                    title: 'DEPED TRANSPARENCY REPORT - 4Ps BENEFICIARIES EQUITY ANALYSIS',
                    referencePeriod, generatedDate
                });

                // Section 1: 4Ps Table
                drawSectionBar(doc, '1. 4Ps BENEFICIARIES EQUITY ANALYSIS TABLE', leftMargin, contentWidth);
                doc.moveDown(0.3);
                drawFourPsTable(doc, leftMargin, contentWidth, latestYear, previousYear, hasPrev, prevSyLabel, activeSyLabel);
                doc.moveDown(0.6);

                // Section 2: Indicators Summary
                drawSectionBar(doc, '2. EQUITY & SOCIAL PROTECTION INDICATORS', leftMargin, contentWidth);
                doc.moveDown(0.3);
                drawFourPsSummaryTable(doc, leftMargin, contentWidth, latestYear);
                doc.moveDown(0.8);

                // Section 3: Official Signatories
                drawSectionBar(doc, '3. OFFICIAL SIGNATORIES & CERTIFICATION', leftMargin, contentWidth);
                doc.moveDown(0.6);
                drawSignatoryBlock(doc, leftMargin, contentWidth);

            // ════════════════════════════════════════════════════════════════
            // CATEGORY 4: FULL TRANSPARENCY BOARD REPORT (All Categories, 2 Pages)
            // ════════════════════════════════════════════════════════════════
            } else {
                // PAGE 1: Header + Section 1 (Enrollment) + Section 2 (Dropouts & Transferees)
                drawDepEdHeader(doc, {
                    sealPath, pageWidth, leftMargin, rightMargin, contentWidth,
                    regionName, divisionName, schoolName,
                    title: 'DEPED TRANSPARENCY & SCHOOL PERFORMANCE BOARD REPORT',
                    referencePeriod, generatedDate
                });

                // ── SECTION 1: DATA ON ENROLLMENT ──
                drawSectionBar(doc, '1. DATA ON ENROLLMENT', leftMargin, contentWidth);
                doc.moveDown(0.3);
                drawEnrollmentTable(doc, leftMargin, contentWidth, latestYear, previousYear, hasPrev, prevSyLabel, activeSyLabel);
                doc.moveDown(0.5);

                // ── SECTION 2: DROPOUTS & TRANSFEREES (Side by Side) ──
                drawSectionBar(doc, '2. DROPOUTS & TRANSFEREES (MULTI-YEAR COMPARATIVE)', leftMargin, contentWidth);
                doc.moveDown(0.3);

                const gap = 12;
                const halfTableWidth = (contentWidth - gap) / 2;
                const sec2StartY = doc.y;

                // Left Table: Dropouts Summary
                doc.fontSize(8.5).font('Helvetica-Bold').fillColor('#0f172a').text('A. Dropouts Summary', leftMargin, sec2StartY);
                doc.y = sec2StartY + 12;
                drawCompactStatTable(doc, leftMargin, halfTableWidth, years, 'dropouts', 'droppedCount', 'Total Dropouts', '#e2e8f0', '#0f172a');

                // Right Table: Transferees Summary
                const rightX = leftMargin + halfTableWidth + gap;
                doc.fontSize(8.5).font('Helvetica-Bold').fillColor('#0f172a').text('B. Transferees Summary', rightX, sec2StartY);
                doc.y = sec2StartY + 12;
                drawCompactStatTable(doc, rightX, halfTableWidth, years, 'transferees', 'transferredCount', 'Total Transferees', '#e2e8f0', '#0f172a');

                // PAGE 2: Header Continuation + Section 3 (4Ps) + Signatories
                doc.addPage();

                // Page 2 Header (Continuation Banner)
                if (fs.existsSync(sealPath)) {
                    doc.image(sealPath, leftMargin, 18, { width: 32, height: 32 });
                }

                doc.fontSize(8.5).font('Helvetica-Bold').fillColor('#000000').text(schoolName, leftMargin + 38, 19);
                doc.fontSize(7.5).font('Helvetica').fillColor('#333333').text(`${divisionName} | ${regionName}`, leftMargin + 38, 30);
                doc.fontSize(7).font('Helvetica').fillColor('#666666').text(
                    `Reference: ${referencePeriod} | Date: ${generatedDate}`,
                    leftMargin + 38, 40
                );

                doc.y = 56;
                doc.strokeColor('#000000').lineWidth(1.2).moveTo(leftMargin, doc.y).lineTo(pageWidth - rightMargin, doc.y).stroke();
                doc.strokeColor('#000000').lineWidth(0.4).moveTo(leftMargin, doc.y + 2).lineTo(pageWidth - rightMargin, doc.y + 2).stroke();
                doc.y = doc.y + 7;

                doc.fontSize(9.5).font('Helvetica-Bold').fillColor('#000000').text(
                    'DEPED TRANSPARENCY & SCHOOL PERFORMANCE REPORT (CONTINUATION)',
                    leftMargin, doc.y,
                    { width: contentWidth, align: 'center' }
                );
                doc.moveDown(0.25);
                doc.strokeColor('#cbd5e1').lineWidth(0.5).moveTo(leftMargin, doc.y).lineTo(pageWidth - rightMargin, doc.y).stroke();
                doc.moveDown(0.4);

                // ── SECTION 3: 4Ps BENEFICIARIES ──
                drawSectionBar(doc, '3. 4Ps BENEFICIARIES EQUITY ANALYSIS', leftMargin, contentWidth);
                doc.moveDown(0.4);
                drawFourPsTable(doc, leftMargin, contentWidth, latestYear, previousYear, hasPrev, prevSyLabel, activeSyLabel);
                doc.moveDown(1.5);

                // ── SECTION 4: OFFICIAL SIGNATORIES ──
                drawSectionBar(doc, '4. OFFICIAL SIGNATORIES & CERTIFICATION', leftMargin, contentWidth);
                doc.moveDown(0.8);
                drawSignatoryBlock(doc, leftMargin, contentWidth);
            }

            // ════════════════════════════════════════════════════════════════
            // RUNNING FOOTER ON ALL PAGES (Fixed coordinates, zero margin bleed)
            // ════════════════════════════════════════════════════════════════
            drawRunningFooter(doc, {
                quezonPath, qaPath, schoolName,
                pageWidth, pageHeight, leftMargin, rightMargin, contentWidth
            });

            doc.end();
        } catch (err) {
            reject(err);
        }
    });
}

// ── Top Header Builder ────────────────────────────────────────────────────────
function drawDepEdHeader(doc, {
    sealPath, pageWidth, leftMargin, rightMargin, contentWidth,
    regionName, divisionName, schoolName,
    title,
    referencePeriod, generatedDate
}) {
    if (fs.existsSync(sealPath)) {
        doc.image(sealPath, (pageWidth - 42) / 2, 18, { width: 42, height: 42 });
    }

    doc.y = 63;
    doc.fontSize(8.5).font('Helvetica').fillColor('#000000').text('Republic of the Philippines', { align: 'center' });
    doc.fontSize(12).font('Helvetica-Bold').fillColor('#000000').text('Department of Education', { align: 'center' });
    doc.fontSize(8).font('Helvetica').fillColor('#000000').text(regionName, { align: 'center' });
    doc.fontSize(8).font('Helvetica').fillColor('#000000').text(divisionName, { align: 'center' });
    doc.fontSize(10).font('Helvetica-Bold').fillColor('#000000').text(schoolName, { align: 'center' });
    doc.fontSize(7.5).font('Helvetica').fillColor('#37474f').text('Talisay, Tiaong, Quezon', { align: 'center' });
    doc.moveDown(0.25);

    // Official DepEd Divider Lines (Double rule: thick upper line + thin lower line)
    const lineY = doc.y;
    doc.strokeColor('#000000').lineWidth(1.2).moveTo(leftMargin, lineY).lineTo(pageWidth - rightMargin, lineY).stroke();
    doc.strokeColor('#000000').lineWidth(0.4).moveTo(leftMargin, lineY + 2).lineTo(pageWidth - rightMargin, lineY + 2).stroke();
    doc.y = lineY + 6;

    // Report Title (Official Administrative Header)
    doc.fontSize(10).font('Helvetica-Bold').fillColor('#000000').text(
        title,
        leftMargin, doc.y,
        { width: contentWidth, align: 'center' }
    );
    doc.moveDown(0.2);

    // Subheader: Reference School Year & Date Generated
    doc.fontSize(8).font('Helvetica-Bold').fillColor('#263238').text(
        `School Year: ${referencePeriod}`,
        leftMargin, doc.y, { continued: true }
    );
    doc.fontSize(7.5).font('Helvetica').fillColor('#455a64').text(
        `Date Generated: ${generatedDate}`,
        { align: 'right' }
    );
    doc.moveDown(0.25);

    // Subtle hairline separator below metadata
    doc.strokeColor('#cbd5e1').lineWidth(0.5).moveTo(leftMargin, doc.y).lineTo(pageWidth - rightMargin, doc.y).stroke();
    doc.moveDown(0.4);
}

// ── Running Footer Builder ────────────────────────────────────────────────────
function drawRunningFooter(doc, {
    quezonPath, qaPath, schoolName,
    pageWidth, pageHeight, leftMargin, rightMargin, contentWidth
}) {
    const range = doc.bufferedPageRange();
    const totalPages = range.count;

    for (let i = range.start; i < range.start + totalPages; i++) {
        doc.switchToPage(i);

        const footerTop = pageHeight - 56;

        // Top black line
        doc.strokeColor('#000000').lineWidth(1.2).moveTo(leftMargin, footerTop).lineTo(pageWidth - rightMargin, footerTop).stroke();

        // Left: DepEd Quezon Logo
        if (fs.existsSync(quezonPath)) {
            doc.image(quezonPath, leftMargin, footerTop + 4, { width: 68, height: 32 });
        }

        // Center text
        const centerLeft = leftMargin + 76;
        const centerWidth = contentWidth - 166;

        doc.fontSize(7.5).font('Helvetica-BoldOblique').fillColor('#000000').text(
            '"Creating Possibilities, Inspiring Innovations"',
            centerLeft, footerTop + 3, { width: centerWidth, align: 'center', lineBreak: false }
        );
        doc.fontSize(6.5).font('Helvetica').fillColor('#000000').text(
            'Address: Brgy. Talisay, Tiaong, Quezon | Trunkline: (042) 784-0366, (042) 784-0164',
            centerLeft, footerTop + 13, { width: centerWidth, align: 'center', lineBreak: false }
        );
        doc.fontSize(6.5).font('Helvetica').fillColor('#1565c0').text(
            'Email: quezon@deped.gov.ph / talisayis.tiaong@deped.gov.ph | Web: www.depedquezon.com.ph',
            centerLeft, footerTop + 22, { width: centerWidth, align: 'center', lineBreak: false }
        );

        // Right: QA Badge
        if (fs.existsSync(qaPath)) {
            doc.image(qaPath, pageWidth - rightMargin - 80, footerTop + 4, { width: 78, height: 26 });
            doc.fontSize(5.5).font('Helvetica').fillColor('#000000').text(
                'Registration: QAC/R63/0216',
                pageWidth - rightMargin - 80, footerTop + 31, { width: 78, align: 'center', lineBreak: false }
            );
        }

        // Bottom Running Page Number & Confidentiality line
        doc.fontSize(6).font('Helvetica').fillColor('#757575').text(
            `${schoolName} - DepEd Transparency & Performance Report`,
            leftMargin, footerTop + 42, { lineBreak: false }
        );
        doc.text(
            `Page ${i + 1} of ${totalPages}`,
            pageWidth - rightMargin - 80, footerTop + 42, { width: 80, align: 'right', lineBreak: false }
        );
    }
}

function drawSectionBar(doc, title, x, width) {
    const y = doc.y;
    doc.rect(x, y, width, 17).fill('#f1f5f9');
    doc.rect(x, y, 3.5, 17).fill('#0f172a');
    doc.strokeColor('#cbd5e1').lineWidth(0.6).rect(x, y, width, 17).stroke();
    doc.fontSize(9.2).font('Helvetica-Bold').fillColor('#0f172a').text(title, x + 8, y + 4.2, { lineBreak: false });
    doc.y = y + 20;
}

// ── Comparative Enrollment Table ──────────────────────────────────────────────
function drawEnrollmentTable(doc, x, width, latestYear, previousYear, hasPrev, prevLabel, currLabel) {
    const cols = [
        { width: width * 0.38, align: 'left' },
        { width: width * 0.15, align: 'center' },
        { width: width * 0.15, align: 'center' },
        { width: width * 0.14, align: 'center' },
        { width: width * 0.18, align: 'center' },
    ];

    drawCustomRow(doc, x, cols, [
        'Key Stage / Grade Level', prevLabel, currLabel, 'Difference', 'Remarks'
    ], { isHeader: true, bgColor: '#e2e8f0', textColor: '#0f172a', height: 20.5, fontSize: 9.5 });

    // JHS Section
    drawCustomRow(doc, x, cols, ['KEY STAGE 3 (JUNIOR HIGH SCHOOL)', '', '', '', ''], { isBold: true, bgColor: '#f8fafc', textColor: '#334155', height: 17, fontSize: 9.0 });

    const grades = [7, 8, 9, 10];
    for (const g of grades) {
        const curr = latestYear?.enrollment?.grades?.find(r => r.gradeLevel === g)?.total || 0;
        const prev = previousYear?.enrollment?.grades?.find(r => r.gradeLevel === g)?.total || 0;
        const diff = hasPrev ? curr - prev : null;

        drawCustomRow(doc, x, cols, [
            `  Grade ${g}`,
            hasPrev ? String(prev) : '-',
            String(curr),
            formatDiff(diff, hasPrev),
            getRemark(diff, hasPrev)
        ], { isAlternate: g % 2 === 1, height: 18, fontSize: 9.1, diffValue: diff, hasPrev });
    }

    // JHS Subtotal
    const jhsCurr = latestYear?.enrollment?.jhsTotal?.total || 0;
    const jhsPrev = previousYear?.enrollment?.jhsTotal?.total || 0;
    const jhsDiff = hasPrev ? jhsCurr - jhsPrev : null;
    drawCustomRow(doc, x, cols, [
        'Subtotal (Junior High School)',
        hasPrev ? String(jhsPrev) : '-',
        String(jhsCurr),
        formatDiff(jhsDiff, hasPrev),
        getRemark(jhsDiff, hasPrev)
    ], { isBold: true, bgColor: '#f1f5f9', textColor: '#0f172a', height: 19, fontSize: 9.5, diffValue: jhsDiff, hasPrev });

    // SHS Section
    drawCustomRow(doc, x, cols, ['KEY STAGE 4 (SENIOR HIGH SCHOOL)', '', '', '', ''], { isBold: true, bgColor: '#f8fafc', textColor: '#334155', height: 17, fontSize: 9.0 });

    const shsGrades = [11, 12];
    for (const g of shsGrades) {
        const curr = latestYear?.enrollment?.grades?.find(r => r.gradeLevel === g)?.total || 0;
        const prev = previousYear?.enrollment?.grades?.find(r => r.gradeLevel === g)?.total || 0;
        const diff = hasPrev ? curr - prev : null;

        drawCustomRow(doc, x, cols, [
            `  Grade ${g}`,
            hasPrev ? String(prev) : '-',
            String(curr),
            formatDiff(diff, hasPrev),
            getRemark(diff, hasPrev)
        ], { isAlternate: g % 2 === 1, height: 18, fontSize: 9.1, diffValue: diff, hasPrev });
    }

    // SHS Subtotal
    const shsCurr = latestYear?.enrollment?.shsTotal?.total || 0;
    const shsPrev = previousYear?.enrollment?.shsTotal?.total || 0;
    const shsDiff = hasPrev ? shsCurr - shsPrev : null;
    drawCustomRow(doc, x, cols, [
        'Subtotal (Senior High School)',
        hasPrev ? String(shsPrev) : '-',
        String(shsCurr),
        formatDiff(shsDiff, hasPrev),
        getRemark(shsDiff, hasPrev)
    ], { isBold: true, bgColor: '#f1f5f9', textColor: '#0f172a', height: 19, fontSize: 9.5, diffValue: shsDiff, hasPrev });

    // Overall Total
    const totCurr = latestYear?.enrollment?.overallTotal?.total || 0;
    const totPrev = previousYear?.enrollment?.overallTotal?.total || 0;
    const totDiff = hasPrev ? totCurr - totPrev : null;
    drawCustomRow(doc, x, cols, [
        'OVERALL TOTAL ENROLLMENT',
        hasPrev ? String(totPrev) : '-',
        String(totCurr),
        formatDiff(totDiff, hasPrev),
        getRemark(totDiff, hasPrev)
    ], { isBold: true, bgColor: '#e2e8f0', textColor: '#000000', height: 21, fontSize: 9.8, diffValue: totDiff, hasPrev });
}

// ── Enrollment Breakdown by Sex Table (Gender Analysis) ──────────────────────
function drawEnrollmentBySexTable(doc, x, width, latestYear) {
    const cols = [
        { width: width * 0.40, align: 'left' },
        { width: width * 0.15, align: 'center' },
        { width: width * 0.15, align: 'center' },
        { width: width * 0.15, align: 'center' },
        { width: width * 0.15, align: 'center' },
    ];

    drawCustomRow(doc, x, cols, [
        'Key Stage / Grade Level', 'Male', 'Female', 'Total Enrolled', 'Female Share'
    ], { isHeader: true, bgColor: '#e2e8f0', textColor: '#0f172a', height: 20.5, fontSize: 9.5 });

    // JHS Section
    drawCustomRow(doc, x, cols, ['KEY STAGE 3 (JUNIOR HIGH SCHOOL)', '', '', '', ''], { isBold: true, bgColor: '#f8fafc', textColor: '#334155', height: 17, fontSize: 9.0 });

    const grades = [7, 8, 9, 10];
    for (const g of grades) {
        const item = latestYear?.enrollment?.grades?.find(r => r.gradeLevel === g) || { male: 0, female: 0, total: 0 };
        const total = item.total || (item.male + item.female);
        const femalePct = total > 0 ? ((item.female / total) * 100).toFixed(1) + '%' : '0.0%';

        drawCustomRow(doc, x, cols, [
            `  Grade ${g}`,
            String(item.male || 0),
            String(item.female || 0),
            String(total),
            femalePct
        ], { isAlternate: g % 2 === 1, height: 18, fontSize: 9.1 });
    }

    // JHS Subtotal
    const jhs = latestYear?.enrollment?.jhsTotal || { male: 0, female: 0, total: 0 };
    const jhsTotal = jhs.total || (jhs.male + jhs.female);
    const jhsFemalePct = jhsTotal > 0 ? ((jhs.female / jhsTotal) * 100).toFixed(1) + '%' : '0.0%';
    drawCustomRow(doc, x, cols, [
        'Subtotal (Junior High School)',
        String(jhs.male || 0),
        String(jhs.female || 0),
        String(jhsTotal),
        jhsFemalePct
    ], { isBold: true, bgColor: '#f1f5f9', textColor: '#0f172a', height: 19, fontSize: 9.5 });

    // SHS Section
    drawCustomRow(doc, x, cols, ['KEY STAGE 4 (SENIOR HIGH SCHOOL)', '', '', '', ''], { isBold: true, bgColor: '#f8fafc', textColor: '#334155', height: 17, fontSize: 9.0 });

    const shsGrades = [11, 12];
    for (const g of shsGrades) {
        const item = latestYear?.enrollment?.grades?.find(r => r.gradeLevel === g) || { male: 0, female: 0, total: 0 };
        const total = item.total || (item.male + item.female);
        const femalePct = total > 0 ? ((item.female / total) * 100).toFixed(1) + '%' : '0.0%';

        drawCustomRow(doc, x, cols, [
            `  Grade ${g}`,
            String(item.male || 0),
            String(item.female || 0),
            String(total),
            femalePct
        ], { isAlternate: g % 2 === 1, height: 18, fontSize: 9.1 });
    }

    // SHS Subtotal
    const shs = latestYear?.enrollment?.shsTotal || { male: 0, female: 0, total: 0 };
    const shsTotal = shs.total || (shs.male + shs.female);
    const shsFemalePct = shsTotal > 0 ? ((shs.female / shsTotal) * 100).toFixed(1) + '%' : '0.0%';
    drawCustomRow(doc, x, cols, [
        'Subtotal (Senior High School)',
        String(shs.male || 0),
        String(shs.female || 0),
        String(shsTotal),
        shsFemalePct
    ], { isBold: true, bgColor: '#f1f5f9', textColor: '#0f172a', height: 19, fontSize: 9.5 });

    // Overall Total
    const ov = latestYear?.enrollment?.overallTotal || { male: 0, female: 0, total: 0 };
    const ovTotal = ov.total || (ov.male + ov.female);
    const ovFemalePct = ovTotal > 0 ? ((ov.female / ovTotal) * 100).toFixed(1) + '%' : '0.0%';
    drawCustomRow(doc, x, cols, [
        'OVERALL TOTAL ENROLLMENT BY SEX',
        String(ov.male || 0),
        String(ov.female || 0),
        String(ovTotal),
        ovFemalePct
    ], { isBold: true, bgColor: '#e2e8f0', textColor: '#000000', height: 21, fontSize: 9.8 });
}

// ── Compact Side-by-Side Stat Table ──────────────────────────────────────────
function drawCompactStatTable(doc, x, width, years, statKey, countKey, totalLabel, headerBg, headerText) {
    const grades = [7, 8, 9, 10, 11, 12];
    const yearCols = years.map(() => ({
        width: (width * 0.68) / (years.length || 1),
        align: 'center'
    }));

    const cols = [
        { width: width * 0.32, align: 'left' },
        ...yearCols
    ];

    drawCustomRow(doc, x, cols, ['Grade Level', ...years.map(y => y.yearRange)], {
        isHeader: true, bgColor: headerBg, textColor: headerText, height: 19, padding: 2, fontSize: 8.4
    });

    for (const g of grades) {
        const rowVals = [
            `Grade ${g}`,
            ...years.map(y => {
                const item = y[statKey]?.grades?.find(r => r.gradeLevel === g);
                return String(item ? item[countKey] || 0 : 0);
            })
        ];
        drawCustomRow(doc, x, cols, rowVals, { isAlternate: g % 2 === 1, height: 17, padding: 3, fontSize: 8.6 });
    }

    const totalVals = [
        totalLabel,
        ...years.map(y => {
            const tot = statKey === 'dropouts' ? y.dropouts?.totalDropped : y.transferees?.totalTransferred;
            return String(tot || 0);
        })
    ];
    drawCustomRow(doc, x, cols, totalVals, { isBold: true, bgColor: '#eeeeee', height: 18.5, padding: 3, fontSize: 9.0 });
}

// ── Full-Width Multi-Year Stat Table ──────────────────────────────────────────
function drawMultiYearStatTable(doc, x, width, years, statKey, countKey, totalLabel, headerBg, headerText) {
    const yearCols = years.map(() => ({
        width: (width * 0.68) / (years.length || 1),
        align: 'center'
    }));

    const cols = [
        { width: width * 0.32, align: 'left' },
        ...yearCols
    ];

    drawCustomRow(doc, x, cols, ['Grade Level / Key Stage', ...years.map(y => `SY ${y.yearRange}`)], {
        isHeader: true, bgColor: headerBg, textColor: headerText, height: 18.5, fontSize: 9.5 });

    // JHS Grades
    const jhsGrades = [7, 8, 9, 10];
    for (const g of jhsGrades) {
        const rowVals = [
            `  Grade ${g}`,
            ...years.map(y => {
                const item = y[statKey]?.grades?.find(r => r.gradeLevel === g);
                return String(item ? item[countKey] || 0 : 0);
            })
        ];
        drawCustomRow(doc, x, cols, rowVals, { isAlternate: g % 2 === 1, height: 16.5, fontSize: 9.0 });
    }

    // JHS Subtotal
    const jhsSubVals = [
        'Subtotal (Junior High School)',
        ...years.map(y => {
            const sub = (y[statKey]?.grades || [])
                .filter(r => r.gradeLevel <= 10)
                .reduce((sum, r) => sum + (r[countKey] || 0), 0);
            return String(sub);
        })
    ];
    drawCustomRow(doc, x, cols, jhsSubVals, { isBold: true, bgColor: '#f5f5f5', height: 17.5, fontSize: 9.3 });

    // SHS Grades
    const shsGrades = [11, 12];
    for (const g of shsGrades) {
        const rowVals = [
            `  Grade ${g}`,
            ...years.map(y => {
                const item = y[statKey]?.grades?.find(r => r.gradeLevel === g);
                return String(item ? item[countKey] || 0 : 0);
            })
        ];
        drawCustomRow(doc, x, cols, rowVals, { isAlternate: g % 2 === 1, height: 16.5, fontSize: 9.0 });
    }

    // SHS Subtotal
    const shsSubVals = [
        'Subtotal (Senior High School)',
        ...years.map(y => {
            const sub = (y[statKey]?.grades || [])
                .filter(r => r.gradeLevel > 10)
                .reduce((sum, r) => sum + (r[countKey] || 0), 0);
            return String(sub);
        })
    ];
    drawCustomRow(doc, x, cols, shsSubVals, { isBold: true, bgColor: '#f5f5f5', height: 17.5, fontSize: 9.3 });

    // Overall Total
    const totalVals = [
        totalLabel,
        ...years.map(y => {
            const tot = statKey === 'dropouts' ? y.dropouts?.totalDropped : y.transferees?.totalTransferred;
            return String(tot || 0);
        })
    ];
    drawCustomRow(doc, x, cols, totalVals, { isBold: true, bgColor: headerBg, textColor: headerText, height: 18.5, fontSize: 9.6 });
}

// ── Retention & Mobility Summary Table ────────────────────────────────────────
function drawRetentionSummaryTable(doc, x, width, years) {
    const yearCols = years.map(() => ({
        width: (width * 0.56) / (years.length || 1),
        align: 'center'
    }));

    const cols = [
        { width: width * 0.44, align: 'left' },
        ...yearCols
    ];

    drawCustomRow(doc, x, cols, ['Retention & Mobility Indicator', ...years.map(y => `SY ${y.yearRange}`)], {
        isHeader: true, bgColor: '#e2e8f0', textColor: '#0f172a', height: 18.5, fontSize: 9.5
    });

    // Total Enrolled Learners
    const enrollVals = [
        'Total Enrolled Learners',
        ...years.map(y => String(y.enrollment?.overallTotal?.total || 0))
    ];
    drawCustomRow(doc, x, cols, enrollVals, { height: 16.5, fontSize: 9.0 });

    // Total Dropouts
    const dropVals = [
        'Total Confirmed Dropouts',
        ...years.map(y => String(y.dropouts?.totalDropped || 0))
    ];
    drawCustomRow(doc, x, cols, dropVals, { isAlternate: true, height: 16.5, fontSize: 9.0 });

    // Dropout Rate %
    const dropRateVals = [
        'Estimated Dropout Rate (%)',
        ...years.map(y => {
            const enr = y.enrollment?.overallTotal?.total || 0;
            const drp = y.dropouts?.totalDropped || 0;
            if (enr <= 0) return '0.0%';
            return `${((drp / enr) * 100).toFixed(1)}%`;
        })
    ];
    drawCustomRow(doc, x, cols, dropRateVals, { height: 16.5, fontSize: 9.0 });

    // Total Transferees
    const transVals = [
        'Total Transferees',
        ...years.map(y => String(y.transferees?.totalTransferred || 0))
    ];
    drawCustomRow(doc, x, cols, transVals, { isAlternate: true, height: 16.5, fontSize: 9.0 });

    // Net Learner Balance (Transferees - Dropouts)
    const netVals = [
        'Net Learner Mobility (Transferees - Dropouts)',
        ...years.map(y => {
            const tr = y.transferees?.totalTransferred || 0;
            const dr = y.dropouts?.totalDropped || 0;
            const net = tr - dr;
            return net > 0 ? `+${net}` : String(net);
        })
    ];
    drawCustomRow(doc, x, cols, netVals, { isBold: true, bgColor: '#f1f5f9', textColor: '#0f172a', height: 18.5, fontSize: 9.3 });
}

// ── 4Ps Beneficiaries Table ───────────────────────────────────────────────────
function drawFourPsTable(doc, x, width, latestYear, previousYear, hasPrev, prevLabel, currLabel) {
    const cols = [
        { width: width * 0.36, align: 'left' },
        { width: width * 0.16, align: 'center' },
        { width: width * 0.16, align: 'center' },
        { width: width * 0.13, align: 'center' },
        { width: width * 0.19, align: 'center' },
    ];

    drawCustomRow(doc, x, cols, [
        'Key Stage / Grade Level',
        hasPrev ? prevLabel : 'Total Students',
        hasPrev ? currLabel : '4Ps Enrolled',
        'Difference',
        'Share in Enrollment'
    ], { isHeader: true, bgColor: '#e2e8f0', textColor: '#0f172a', height: 21, fontSize: 9.5 });

    // JHS Section
    drawCustomRow(doc, x, cols, ['KEY STAGE 3 (JUNIOR HIGH SCHOOL)', '', '', '', ''], { isBold: true, bgColor: '#f8fafc', textColor: '#334155', height: 17, fontSize: 9.0 });

    const grades = [7, 8, 9, 10];
    for (const g of grades) {
        const currItem = latestYear?.fourPs?.grades?.find(r => r.gradeLevel === g);
        const prevItem = previousYear?.fourPs?.grades?.find(r => r.gradeLevel === g);

        const currCount = currItem?.fourPsCount || 0;
        const prevCount = prevItem?.fourPsCount || 0;
        const totalEnrolled = currItem?.totalStudents || 0;
        const diff = hasPrev ? currCount - prevCount : null;
        const pct = currItem?.percentage || (totalEnrolled > 0 ? (currCount / totalEnrolled * 100).toFixed(1) : '0.0');

        drawCustomRow(doc, x, cols, [
            `  Grade ${g}`,
            hasPrev ? String(prevCount) : String(totalEnrolled),
            String(currCount),
            formatDiff(diff, hasPrev),
            `${pct}%`
        ], { isAlternate: g % 2 === 1, height: 18, fontSize: 9.1, diffValue: diff, hasPrev });
    }

    // JHS Subtotal
    const jhsCurrCount = latestYear?.fourPs?.jhsTotal?.fourPsCount || 0;
    const jhsPrevCount = previousYear?.fourPs?.jhsTotal?.fourPsCount || 0;
    const jhsStudents = latestYear?.fourPs?.jhsTotal?.totalStudents || 0;
    const jhsDiff = hasPrev ? jhsCurrCount - jhsPrevCount : null;
    const jhsPct = latestYear?.fourPs?.jhsTotal?.percentage || (jhsStudents > 0 ? (jhsCurrCount / jhsStudents * 100).toFixed(1) : '0.0');

    drawCustomRow(doc, x, cols, [
        'Subtotal (Junior High School)',
        hasPrev ? String(jhsPrevCount) : String(jhsStudents),
        String(jhsCurrCount),
        formatDiff(jhsDiff, hasPrev),
        `${jhsPct}%`
    ], { isBold: true, bgColor: '#f1f5f9', textColor: '#0f172a', height: 19, fontSize: 9.5, diffValue: jhsDiff, hasPrev });

    // SHS Section
    drawCustomRow(doc, x, cols, ['KEY STAGE 4 (SENIOR HIGH SCHOOL)', '', '', '', ''], { isBold: true, bgColor: '#f8fafc', textColor: '#334155', height: 17, fontSize: 9.0 });

    const shsGrades = [11, 12];
    for (const g of shsGrades) {
        const currItem = latestYear?.fourPs?.grades?.find(r => r.gradeLevel === g);
        const prevItem = previousYear?.fourPs?.grades?.find(r => r.gradeLevel === g);

        const currCount = currItem?.fourPsCount || 0;
        const prevCount = prevItem?.fourPsCount || 0;
        const totalEnrolled = currItem?.totalStudents || 0;
        const diff = hasPrev ? currCount - prevCount : null;
        const pct = currItem?.percentage || (totalEnrolled > 0 ? (currCount / totalEnrolled * 100).toFixed(1) : '0.0');

        drawCustomRow(doc, x, cols, [
            `  Grade ${g}`,
            hasPrev ? String(prevCount) : String(totalEnrolled),
            String(currCount),
            formatDiff(diff, hasPrev),
            `${pct}%`
        ], { isAlternate: g % 2 === 1, height: 18, fontSize: 9.1, diffValue: diff, hasPrev });
    }

    // SHS Subtotal
    const shsCurrCount = latestYear?.fourPs?.shsTotal?.fourPsCount || 0;
    const shsPrevCount = previousYear?.fourPs?.shsTotal?.fourPsCount || 0;
    const shsStudents = latestYear?.fourPs?.shsTotal?.totalStudents || 0;
    const shsDiff = hasPrev ? shsCurrCount - shsPrevCount : null;
    const shsPct = latestYear?.fourPs?.shsTotal?.percentage || (shsStudents > 0 ? (shsCurrCount / shsStudents * 100).toFixed(1) : '0.0');

    drawCustomRow(doc, x, cols, [
        'Subtotal (Senior High School)',
        hasPrev ? String(shsPrevCount) : String(shsStudents),
        String(shsCurrCount),
        formatDiff(shsDiff, hasPrev),
        `${shsPct}%`
    ], { isBold: true, bgColor: '#f1f5f9', textColor: '#0f172a', height: 19, fontSize: 9.5, diffValue: shsDiff, hasPrev });

    // Overall Total
    const totCurrCount = latestYear?.fourPs?.overallTotal?.fourPsCount || 0;
    const totPrevCount = previousYear?.fourPs?.overallTotal?.fourPsCount || 0;
    const totStudents = latestYear?.fourPs?.overallTotal?.totalStudents || 0;
    const totDiff = hasPrev ? totCurrCount - totPrevCount : null;
    const totPct = latestYear?.fourPs?.overallTotal?.percentage || (totStudents > 0 ? (totCount / totStudents * 100).toFixed(1) : '0.0');

    drawCustomRow(doc, x, cols, [
        'OVERALL TOTAL 4Ps BENEFICIARIES',
        hasPrev ? String(totPrevCount) : String(totStudents),
        String(totCurrCount),
        formatDiff(totDiff, hasPrev),
        `${totPct}%`
    ], { isBold: true, bgColor: '#e2e8f0', textColor: '#000000', height: 21, fontSize: 9.8, diffValue: totDiff, hasPrev });
}

// ── 4Ps Summary Table (Equity Indicators) ─────────────────────────────────────
function drawFourPsSummaryTable(doc, x, width, latestYear) {
    const cols = [
        { width: width * 0.45, align: 'left' },
        { width: width * 0.25, align: 'center' },
        { width: width * 0.30, align: 'center' },
    ];

    drawCustomRow(doc, x, cols, [
        'Social Protection / Equity Indicator', 'Beneficiaries Count', 'Share in Stage (%)'
    ], { isHeader: true, bgColor: '#e2e8f0', textColor: '#0f172a', height: 20, fontSize: 9.5 });

    const jhsCount = latestYear?.fourPs?.jhsTotal?.fourPsCount || 0;
    const jhsStudents = latestYear?.fourPs?.jhsTotal?.totalStudents || 0;
    const jhsPct = latestYear?.fourPs?.jhsTotal?.percentage || (jhsStudents > 0 ? (jhsCount / jhsStudents * 100).toFixed(1) : '0.0');

    drawCustomRow(doc, x, cols, [
        'Key Stage 3 (Junior High School) 4Ps Learners',
        `${jhsCount} / ${jhsStudents}`,
        `${jhsPct}% of JHS Learners`
    ], { height: 18.5, fontSize: 9.1 });

    const shsCount = latestYear?.fourPs?.shsTotal?.fourPsCount || 0;
    const shsStudents = latestYear?.fourPs?.shsTotal?.totalStudents || 0;
    const shsPct = latestYear?.fourPs?.shsTotal?.percentage || (shsStudents > 0 ? (shsCount / shsStudents * 100).toFixed(1) : '0.0');

    drawCustomRow(doc, x, cols, [
        'Key Stage 4 (Senior High School) 4Ps Learners',
        `${shsCount} / ${shsStudents}`,
        `${shsPct}% of SHS Learners`
    ], { isAlternate: true, height: 18.5, fontSize: 9.1 });

    const totCount = latestYear?.fourPs?.overallTotal?.fourPsCount || 0;
    const totStudents = latestYear?.fourPs?.overallTotal?.totalStudents || 0;
    const totPct = latestYear?.fourPs?.overallTotal?.percentage || (totStudents > 0 ? (totCount / totStudents * 100).toFixed(1) : '0.0');

    drawCustomRow(doc, x, cols, [
        'Total Institutional 4Ps Coverage',
        `${totCount} / ${totStudents}`,
        `${totPct}% School-wide Coverage`
    ], { isBold: true, bgColor: '#e2e8f0', textColor: '#000000', height: 20.5, fontSize: 9.6 });
}

// ── Generic Row Renderer ──────────────────────────────────────────────────────
function drawCustomRow(doc, startX, cols, values, options = {}) {
    const rowHeight = options.height || 18;
    const y = doc.y;

    if (options.bgColor) {
        const totalWidth = cols.reduce((sum, c) => sum + c.width, 0);
        doc.rect(startX, y, totalWidth, rowHeight).fill(options.bgColor);
    } else if (options.isAlternate) {
        const totalWidth = cols.reduce((sum, c) => sum + c.width, 0);
        doc.rect(startX, y, totalWidth, rowHeight).fill('#fafafa');
    }

    const padding = options.padding !== undefined ? options.padding : 5;
    const fontSize = options.fontSize || (options.isHeader ? 9.8 : (options.isBold ? 9.5 : 9.1));

    let curX = startX;
    for (let i = 0; i < cols.length; i++) {
        const col = cols[i];
        const val = values[i] !== undefined ? String(values[i]) : '';

        let textColor = options.textColor || '#000000';
        if (i === 3 && options.diffValue !== undefined && options.hasPrev) {
            if (options.diffValue > 0) textColor = '#2e7d32';
            else if (options.diffValue < 0) textColor = '#c62828';
            else textColor = '#757575';
        }

        doc.fontSize(fontSize)
            .font(options.isHeader || options.isBold ? 'Helvetica-Bold' : 'Helvetica')
            .fillColor(textColor);

        const textYOffset = y + (rowHeight - (fontSize + 1.8)) / 2;
        doc.text(val, curX + padding, textYOffset, {
            width: col.width - (padding * 2),
            align: col.align || 'left',
            lineBreak: false
        });

        // Grid border with high-contrast slate-grey
        doc.strokeColor('#b0bec5').lineWidth(0.6).rect(curX, y, col.width, rowHeight).stroke();
        curX += col.width;
    }

    doc.y = y + rowHeight;
}

// ── Signatory Block ───────────────────────────────────────────────────────────
function drawSignatoryBlock(doc, x, width) {
    const y = doc.y;
    const colWidth = width / 3;

    doc.fontSize(8.5).font('Helvetica').fillColor('#424242');
    doc.text('Prepared by:', x, y, { lineBreak: false });
    doc.text('Verified by:', x + colWidth, y, { lineBreak: false });
    doc.text('Approved by:', x + colWidth * 2, y, { lineBreak: false });

    const lineY = y + 28;
    const lineMargin = 14;

    doc.strokeColor('#616161').lineWidth(0.8).moveTo(x, lineY).lineTo(x + colWidth - lineMargin, lineY).stroke();
    doc.strokeColor('#616161').lineWidth(0.8).moveTo(x + colWidth, lineY).lineTo(x + colWidth * 2 - lineMargin, lineY).stroke();
    doc.strokeColor('#616161').lineWidth(0.8).moveTo(x + colWidth * 2, lineY).lineTo(x + width - lineMargin, lineY).stroke();

    doc.fontSize(8.5).font('Helvetica-Bold').fillColor('#000000');
    doc.text('Class Adviser / Guidance Counselor', x, lineY + 3.5, { width: colWidth - lineMargin, lineBreak: false });
    doc.text('Planning Officer / Assistant Principal', x + colWidth, lineY + 3.5, { width: colWidth - lineMargin, lineBreak: false });
    doc.text('School Principal / Head Teacher', x + colWidth * 2, lineY + 3.5, { width: colWidth - lineMargin, lineBreak: false });

    doc.y = lineY + 20;
}

module.exports = {
    mergeDocumentsToPdf,
    generateTransparencyBoardPdf,
};
