const fs = require('fs');
const path = require('path');
const ExcelJS = require('exceljs');
const { execFile } = require('child_process');
const util = require('util');
const execFileAsync = util.promisify(execFile);

// ==========================================
// SF9 PARSER (Report Card)
// ==========================================
exports.parseSF9 = (text) => {
    // Pre-process and normalize common OCR LRN misreads (O->0, I/l->1) in candidates near the LRN label
    let processedText = text.replace(
        /(L\s*\.?\s*R\s*\.?\s*[NM]\s*\.?\s*[:\-]?\s*)([0-9OoIl|][\s\-\.]*(?:[0-9OoIl|][\s\-\.]*){11})/gi,
        (match, prefix, lrnStr) => {
            const cleanedLrn = lrnStr
                .replace(/[Oo]/g, '0')
                .replace(/[Il|]/g, '1');
            return prefix + cleanedLrn;
        }
    );

    const normalizedText = processedText
    .replace(/\r/g, '')
    .replace(/[|]/g, 'I')
    .replace(/\s+/g, ' ');

    let extracted = {
        lrn: '', firstName: '', lastName: '', middleName: '', extension: '',
        dob: null, sex: '', gradeLevel: '', section: '', schoolYear: '', trackStrand: ''
    };

    // 1. Extract LRN
    // OCR-tolerant matching any 12 digits separated by spaces, dashes, or periods
    const lrnMatch = normalizedText.match(
        /(?:L\s*\.?\s*R\s*\.?\s*[NM]\s*\.?\s*[:\-]?\s*)?(\d[\s\-\.]*(?:\d[\s\-\.]*){11})/i
    );

    if (lrnMatch) {
        extracted.lrn = lrnMatch[1].replace(/[\s\-\.]/g, '');
    }

    // 2. Extract Name fields
    const nameData = extractStudentName(text);
    extracted.lastName = nameData.lastName;
    extracted.firstName = nameData.firstName;
    extracted.middleName = nameData.middleName;
    extracted.extension = nameData.extension;

    // 4. Extract SF9 Specifics
    extracted.dob = extractDob(text);

    const sexMatch = text.match(/(?:Sex|Gender)[:\s,]*(MALE|FEMALE|M\b|F\b)/i);
    if (sexMatch) extracted.sex = sexMatch[1].toUpperCase().startsWith('M') ? 'Male' : 'Female';

    const gradeMatch = text.match(/(?:Grade|Grade\s*Level)[:\s,]*(\d+)/i);
    if (gradeMatch) extracted.gradeLevel = gradeMatch[1];

    const sectionMatch = text.match(/Section[:\s,]*([^\n,]+)/i);
    if (sectionMatch) extracted.section = sectionMatch[1].trim();

    const syMatch = text.match(/(?:School\s*Year|S\.?Y\.?)[:\s,]*(\d{4}\s*-\s*\d{4})/i);
    if (syMatch) extracted.schoolYear = syMatch[1].replace(/\s/g, '');

    extracted.scholasticRecords = exports.extractAllScholasticRecords(text);
    if (extracted.scholasticRecords.length > 0) {
        const latest = extracted.scholasticRecords[extracted.scholasticRecords.length - 1];
        extracted.gradeLevel = latest.gradeLevel;
        extracted.section = latest.section;
        extracted.schoolYear = latest.schoolYear;
        extracted.adviserName = latest.adviserName || '';
        extracted.semester = latest.semester || '';
    }

    return extracted;
};

// ==========================================
// SF10 PARSER (Permanent Record)
// ==========================================
exports.parseSF10 = (text) => {
    // Pre-process and normalize common OCR LRN misreads (O->0, I/l->1) in candidates near the LRN label
    let processedText = text.replace(
        /(L\s*\.?\s*R\s*\.?\s*[NM]\s*\.?\s*[:\-]?\s*)([0-9OoIl|][\s\-\.]*(?:[0-9OoIl|][\s\-\.]*){11})/gi,
        (match, prefix, lrnStr) => {
            const cleanedLrn = lrnStr
                .replace(/[Oo]/g, '0')
                .replace(/[Il|]/g, '1');
            return prefix + cleanedLrn;
        }
    );

    let extracted = {
        lrn: '', firstName: '', lastName: '', middleName: '', extension: '',
        dob: null, sex: '', gradeLevel: '', section: '', schoolYear: '', trackStrand: ''
    };

    // 1. Extract LRN
    const lrnMatch = processedText.match(
        /(?:L\s*\.?\s*R\s*\.?\s*[NM]\s*\.?\s*[:\-]?\s*)?(\d[\s\-\.]*(?:\d[\s\-\.]*){11})/i
    );
    if (lrnMatch) {
        extracted.lrn = lrnMatch[1].replace(/[\s\-\.]/g, '');
    } else {
        const fallbackLrn = processedText.match(/\b\d{12}\b/);
        if (fallbackLrn) extracted.lrn = fallbackLrn[0];
    }

    // 2. Extract Name fields
    const nameData = extractStudentName(text);
    extracted.lastName = nameData.lastName;
    extracted.firstName = nameData.firstName;
    extracted.middleName = nameData.middleName;
    extracted.extension = nameData.extension;

    // 4. Extract SF10 Specifics
    extracted.dob = extractDob(text);

    const sexMatch = text.match(/(?:Sex|Gender)[:\s,]*(MALE|FEMALE|M\b|F\b)/i);
    if (sexMatch) extracted.sex = sexMatch[1].toUpperCase().startsWith('M') ? 'Male' : 'Female';

    extracted.scholasticRecords = exports.extractAllScholasticRecords(text);
    if (extracted.scholasticRecords.length > 0) {
        const latest = extracted.scholasticRecords[extracted.scholasticRecords.length - 1];
        extracted.gradeLevel = latest.gradeLevel;
        extracted.section = latest.section;
        extracted.schoolYear = latest.schoolYear;
        extracted.adviserName = latest.adviserName || '';
        extracted.semester = latest.semester || '';
    }

    return extracted;
};

// ==========================================
// EXTRACT ALL SCHOLASTIC RECORDS (PDF, Image, Excel)
// ==========================================
exports.extractAllScholasticRecords = (text) => {
    const records = [];
    if (!text || typeof text !== 'string') return records;

    const gradeRegex = /(?:GRADE\s*LEVEL|Classified\s*as\s*Grade|GRADE\s*:)[\s,:]*([7-9]|1[0-2])\b/gi;
    let match;
    while ((match = gradeRegex.exec(text)) !== null) {
        const gradeLevel = match[1];
        const gNum = parseInt(gradeLevel, 10);
        if (isNaN(gNum) || gNum < 7 || gNum > 12) continue;
        const startIndex = match.index;
        const block = text.slice(startIndex, startIndex + 600);

        // 1. Section
        let section = '';
        const secMatch = block.match(/SECTION[\s,:]*([A-Za-z0-9\-\s]+?)(?=\s*(?:FIRST|SECOND|1ST|2ND|SEM|SCHOOL\s*YEAR|S\.?Y\.?|NAME\s*OF|ADVISER|TEACHER|,|\n|$))/i);
        if (secMatch) {
            section = secMatch[1].replace(/[,:]/g, '').trim();
        }

        // 2. School Year
        let schoolYear = '';
        const syMatch = block.match(/(?:SCHOOL\s*YEAR|S\.?Y\.?)[\s,:]*(\d{4}\s*-\s*\d{4})/i);
        if (syMatch) {
            schoolYear = syMatch[1].replace(/\s/g, '');
        }

        // 3. Adviser / Teacher Name
        let adviserName = '';
        const advMatch = block.match(/(?:NAME\s*OF\s*ADVISER\/?TEACHER|ADVISER\/?TEACHER|ADVISER|TEACHER)[\s,:]*([A-Za-z\s\-\.]+?)(?=\s*(?:SIGNATURE|DATE|LEARNING|QUARTERLY|,|\n|$))/i);
        if (advMatch) {
            adviserName = advMatch[1].replace(/[,:]/g, '').trim();
            adviserName = adviserName.replace(/\s*(?:Signature|Date).*$/i, '').trim();
        }

        // 4. Semester
        let semester = '';
        const semMatch = block.match(/(?:SEM(?:ESTER)?|SEM)[\s,:]*(FIRST|SECOND|1ST|2ND|1|2)/i) ||
                         block.match(/\b(FIRST|SECOND|1ST|2ND)\s*SEMESTER\b/i);
        if (semMatch) {
            semester = semMatch[1].toUpperCase();
        }

        if (gradeLevel && section && schoolYear) {
            records.push({
                gradeLevel,
                section,
                schoolYear,
                adviserName,
                semester
            });
        }
    }

    // Deduplicate records: if two semesters or blocks have the same (gradeLevel, schoolYear, section), do not duplicate!
    const seen = new Set();
    const deduplicated = [];
    for (const rec of records) {
        const key = `${rec.gradeLevel}_${rec.schoolYear}_${rec.section}`.toLowerCase();
        if (!seen.has(key)) {
            seen.add(key);
            deduplicated.push(rec);
        } else {
            console.log(`[ocrParser] Deduplicating same semester/grade record -> Grade: ${rec.gradeLevel}, SY: ${rec.schoolYear}, Sec: ${rec.section}`);
        }
    }

    return deduplicated;
};

// ==========================================
// HELPER FUNCTION
// ==========================================
// ==========================================
// HELPER FUNCTIONS FOR NAME CLEANING
// ==========================================
function cleanNameField(str) {
    if (!str || typeof str !== 'string') return '';
    
    // 1. Remove unwanted field headers/labels if accidentally captured in name string
    let cleaned = str.replace(/\b(?:LAST|FIRST|MIDDLE|SURNAME|FAMILY|GIVEN|NAME|EXTENSION|SUFFIX|EXT|LEARNER'?S?|STUDENT|LRN|SEX|GENDER|DOB|BIRTH|DATE|GRADE|SECTION|SCHOOL|S\.?Y\.?)\b/gi, ' ');
    
    // 2. Keep only valid name characters: letters, hyphens, periods, apostrophes, and spaces
    cleaned = cleaned.replace(/[^A-Za-z\-\.\'\s]/g, ' ');

    // 3. Split into trimmed words and strip lone or boundary periods
    let words = cleaned.trim().split(/\s+/).map(w => w.replace(/^\.+|\.+$/g, '')).filter(w => w.length > 0);
    if (words.length === 0) return '';

    // 4. Iteratively deduplicate any repeated adjacent sub-sequences of words (e.g. 1-word, 2-word, 3-word repeats)
    let changed = true;
    while (changed) {
        changed = false;
        const maxChunk = Math.floor(words.length / 2);
        for (let k = maxChunk; k >= 1; k--) {
            for (let i = 0; i <= words.length - 2 * k; i++) {
                const chunk1 = words.slice(i, i + k).map(w => w.toLowerCase()).join(' ');
                const chunk2 = words.slice(i + k, i + 2 * k).map(w => w.toLowerCase()).join(' ');
                if (chunk1.length > 0 && chunk1 === chunk2) {
                    words.splice(i + k, k);
                    changed = true;
                    break;
                }
            }
            if (changed) break;
        }
    }

    return words.join(' ');
}

function escapeRegExp(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function extractStudentName(text) {
    let lastName = '';
    let firstName = '';
    let middleName = '';
    let extension = '';

    // 1. Try explicit separate headers: LAST NAME, FIRST NAME, MIDDLE NAME, EXTENSION
    const lastNameMatch = text.match(/(?:LAST\s*NAME|SURNAME|FAMILY\s*NAME)[:\s,]*([A-Za-z\-\s\.\']+?)(?=\s*(?:FIRST|GIVEN|MIDDLE|M\.?I\.?|EXT|SUFFIX|NAME|LRN|SEX|DOB|DATE|GRADE|SECTION|S\.?Y\.?|,|\n|$))/i);
    const firstNameMatch = text.match(/(?:FIRST\s*NAME|GIVEN\s*NAME)[:\s,]*([A-Za-z\-\s\.\']+?)(?=\s*(?:LAST|SURNAME|MIDDLE|M\.?I\.?|EXT|SUFFIX|NAME|LRN|SEX|DOB|DATE|GRADE|SECTION|S\.?Y\.?|,|\n|$))/i);
    const middleNameMatch = text.match(/(?:MIDDLE\s*NAME|MIDDLE\s*INITIAL|MIDDLE|M\.?I\.?)[:\s,]*([A-Za-z\-\s\.\']+?)(?=\s*(?:LAST|SURNAME|FIRST|GIVEN|EXT|SUFFIX|NAME|LRN|SEX|DOB|DATE|GRADE|SECTION|S\.?Y\.?|,|\n|$))/i);
    const extensionMatch = text.match(/(?:EXTENSION\s*NAME|EXT\.?\s*NAME|NAME\s*EXT\.?|EXTENSION|SUFFIX|EXT)[:\s,]*([A-Za-z0-9\.\-]+?)(?=\s*(?:LAST|FIRST|MIDDLE|M\.?I\.?|NAME|LRN|SEX|DOB|DATE|GRADE|SECTION|S\.?Y\.?|,|\n|$))/i);

    if (lastNameMatch) lastName = lastNameMatch[1].trim();
    if (firstNameMatch) firstName = firstNameMatch[1].trim();
    if (middleNameMatch) middleName = middleNameMatch[1].trim();
    if (extensionMatch) extension = extensionMatch[1].trim();

    // 2. Try combined format if separate headers didn't yield both lastName and firstName
    if (!lastName || !firstName) {
        const combinedMatch = text.match(/(?:Name|Learner'?s?\s*Name|Name\s*of\s*Learner|Name\s*of\s*Student)[:\s,]+([A-Za-z\-\s\.\']+?),\s*([A-Za-z\-\s\.\']+?)(?=\s*(?:LRN|SEX|GENDER|DOB|BIRTH|DATE|GRADE|SECTION|SCHOOL|S\.?Y\.?|TRACK|STRAND|\n|$))/i);
        if (combinedMatch) {
            const candLast = combinedMatch[1].trim();
            let candRest = combinedMatch[2].trim().split(/\s+/);
            if (!lastName) lastName = candLast;
            if (candRest.length > 0) {
                const extCheck = candRest[candRest.length - 1].toUpperCase().replace(/\./g, '');
                if (['JR', 'SR', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'].includes(extCheck)) {
                    if (!extension) extension = candRest.pop();
                }
                if (candRest.length >= 2 && !middleName) {
                    middleName = candRest.pop();
                }
                if (!firstName) firstName = candRest.join(' ');
            }
        }
    }

    // 3. Initial cleaning of fields
    lastName = cleanNameField(lastName);
    firstName = cleanNameField(firstName);
    middleName = cleanNameField(middleName);
    extension = extension.replace(/[\.,]/g, '').trim().toUpperCase();

    // 4. Remove cross-field duplicate values ONLY when target field has extra remaining words
    const cleanLowerLast = lastName.toLowerCase();
    const cleanLowerFirst = firstName.toLowerCase();

    if (lastName && firstName && cleanLowerFirst !== cleanLowerLast) {
        const lastPattern = new RegExp(`\\b${escapeRegExp(lastName)}\\b`, 'gi');
        const candidateFirst = firstName.replace(lastPattern, '').trim();
        if (candidateFirst.length > 0) {
            firstName = candidateFirst;
        }
    }
    if (lastName && middleName && middleName.toLowerCase() !== cleanLowerLast) {
        const lastPattern = new RegExp(`\\b${escapeRegExp(lastName)}\\b`, 'gi');
        const candidateMiddle = middleName.replace(lastPattern, '').trim();
        if (candidateMiddle.length > 0) {
            middleName = candidateMiddle;
        }
    }
    if (firstName && middleName && middleName.toLowerCase() !== cleanLowerFirst) {
        const firstPattern = new RegExp(`\\b${escapeRegExp(firstName)}\\b`, 'gi');
        const candidateMiddle = middleName.replace(firstPattern, '').trim();
        if (candidateMiddle.length > 0) {
            middleName = candidateMiddle;
        }
    }

    // Clean fields again after cross-field deduplication
    lastName = cleanNameField(lastName);
    firstName = cleanNameField(firstName);
    middleName = cleanNameField(middleName);

    // 5. Extract extension name from lastName, firstName, or middleName if not already found
    let res = extractExtension({ lastName, firstName, middleName, extension });
    res.lastName = cleanNameField(res.lastName);
    res.firstName = cleanNameField(res.firstName);
    res.middleName = cleanNameField(res.middleName);

    return res;
}

function extractExtension(extracted) {
    const extRegex = /(?:,\s*|\b)(JR\.?|SR\.?|I{1,3}|IV|V|VI{0,3}|IX|X)\b/i;
    
    if (!extracted.extension) {
        let extMatch = extracted.lastName.match(extRegex);
        if (extMatch) {
            extracted.extension = extMatch[1].replace(/[\.,]/g, '').trim().toUpperCase();
            extracted.lastName = extracted.lastName.replace(extMatch[0], '').replace(/,$/, '').trim();
        }
    }
    
    if (!extracted.extension) {
        let extMatch = extracted.firstName.match(extRegex);
        if (extMatch) {
            extracted.extension = extMatch[1].replace(/[\.,]/g, '').trim().toUpperCase();
            extracted.firstName = extracted.firstName.replace(extMatch[0], '').replace(/,$/, '').trim();
        }
    }

    if (!extracted.extension) {
        let extMatch = extracted.middleName.match(extRegex);
        if (extMatch) {
            extracted.extension = extMatch[1].replace(/[\.,]/g, '').trim().toUpperCase();
            extracted.middleName = extracted.middleName.replace(extMatch[0], '').replace(/,$/, '').trim();
        }
    }

    return extracted;
}

function extractDob(text) {
    const months = {
        jan: '01', january: '01',
        feb: '02', february: '02',
        mar: '03', march: '03',
        apr: '04', april: '04',
        may: '05',
        jun: '06', june: '06',
        jul: '07', july: '07',
        aug: '08', august: '08',
        sep: '09', september: '09',
        oct: '10', october: '10',
        nov: '11', november: '11',
        dec: '12', december: '12'
    };

    // Try finding after explicit DOB keyword first
    const dobKeywordMatch = text.match(/(?:Date\s*of\s*Birth|Birth\s*Date|Birthdate(?:\s*\([^\)]*\))?|DOB|Birth|Born)[:\s,]*([^\n,]{4,35})/i);
    const searchArea = dobKeywordMatch ? dobKeywordMatch[1] : text;

    // 1. Check for Month Name Day, Year (e.g., "May 14, 2007" or "14 May 2007")
    const monthNameMatch = searchArea.match(/\b([A-Za-z]{3,9})\s+(\d{1,2}),?\s+(\d{4})\b/) ||
                           searchArea.match(/\b(\d{1,2})\s+([A-Za-z]{3,9}),?\s+(\d{4})\b/);
    if (monthNameMatch) {
        let mStr = monthNameMatch[1].toLowerCase();
        let dStr = monthNameMatch[2];
        let yStr = monthNameMatch[3];
        if (!months[mStr] && months[dStr.toLowerCase()]) {
            mStr = dStr.toLowerCase();
            dStr = monthNameMatch[1];
        }
        if (months[mStr]) {
            const m = months[mStr];
            const d = dStr.padStart(2, '0');
            return `${yStr}-${m}-${d}`;
        }
    }

    // 2. Check for YYYY-MM-DD or YYYY/MM/DD
    const isoMatch = searchArea.match(/\b(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})\b/);
    if (isoMatch) {
        const y = isoMatch[1];
        const m = isoMatch[2].padStart(2, '0');
        const d = isoMatch[3].padStart(2, '0');
        return `${y}-${m}-${d}`;
    }

    // 3. Check for MM/DD/YYYY, DD/MM/YYYY, MM/DD/YY, or DD/MM/YY (supports 2-digit and 4-digit years)
    const slashMatch = searchArea.match(/\b(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})\b/);
    if (slashMatch) {
        let p1 = parseInt(slashMatch[1], 10);
        let p2 = parseInt(slashMatch[2], 10);
        let y = parseInt(slashMatch[3], 10);
        if (y < 100) {
            y += (y <= 30 ? 2000 : 1900);
        }
        let m = p1;
        let d = p2;
        if (p1 > 12 && p2 <= 12) {
            // Must be DD/MM/YYYY
            d = p1;
            m = p2;
        }
        return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    }

    // 4. Check for Excel serial date numbers (e.g., 38445 -> 2005-04-03)
    const serialMatch = searchArea.match(/\b(1\d{4}|2\d{4}|3\d{4}|4\d{4}|5\d{4}|6\d{4}|7\d{4})\b/);
    if (serialMatch) {
        const serial = parseInt(serialMatch[1], 10);
        if (serial > 10000 && serial < 80000) {
            const date = new Date(Math.round((serial - 25569) * 86400 * 1000));
            return date.toISOString().split('T')[0];
        }
    }

    return null;
}

// ==========================================
// EXTRACT TEXT FROM FILE (Excel, PDF, Image)
// ==========================================
exports.extractTextFromFile = async (filePath, originalName = '', mimeType = '') => {
    let text = '';
    const isExcel = /\.(xlsx|xls|csv)$/i.test(originalName || filePath) ||
                    (mimeType && (mimeType.includes('spreadsheet') || mimeType.includes('excel') || mimeType.includes('csv')));
    const isPdf = (mimeType === 'application/pdf') || /\.(pdf)$/i.test(originalName || filePath);

    if (isExcel) {
        console.log('[ocrParser] Excel/Spreadsheet file detected. Reading tabs via exceljs...');
        const workbook = new ExcelJS.Workbook();
        const ext = path.extname(originalName || filePath).toLowerCase();
        if (ext === '.csv' || (mimeType && mimeType.includes('csv'))) {
            await workbook.csv.readFile(filePath);
        } else {
            await workbook.xlsx.readFile(filePath);
        }

        const tabTexts = [];
        workbook.eachSheet((worksheet) => {
            const tabName = worksheet.name;
            const rowsText = [];
            const csvLines = [];
            worksheet.eachRow({ includeEmpty: false }, (row) => {
                const rowValues = [];
                row.eachCell({ includeEmpty: false }, (cell) => {
                    let val = cell.value;
                    if (val !== null && val !== undefined) {
                        if (typeof val === 'object') {
                            if (val instanceof Date) {
                                val = val.toISOString().split('T')[0];
                            } else if (val.result !== undefined && val.result !== null) {
                                val = val.result;
                            } else if (val.text !== undefined && val.text !== null) {
                                val = val.text;
                            } else if (Array.isArray(val.richText)) {
                                val = val.richText.map(r => r.text).join('');
                            } else {
                                val = JSON.stringify(val);
                            }
                        }
                        const str = String(val).trim();
                        if (str.length > 0) {
                            rowValues.push(str);
                        }
                    }
                });
                if (rowValues.length > 0) {
                    rowsText.push(rowValues.join(' '));
                    csvLines.push(rowValues.map(v => `"${v.replace(/"/g, '""')}"`).join(','));
                }
            });
            const formattedRows = rowsText.join('\n');
            tabTexts.push(`--- TAB: ${tabName} ---\n${formattedRows}`);
        });
        text = tabTexts.join('\n\n');
        return text;
    }

    let imagePathToScan = filePath;
    let tempPngPath = null;

    if (isPdf) {
        console.log('[ocrParser] PDF detected. Spawning Ghostscript to convert page 1 to PNG...');
        const saveDirectory = path.resolve('./uploads/temp_ocr/');
        if (!fs.existsSync(saveDirectory)) {
            fs.mkdirSync(saveDirectory, { recursive: true });
        }
        tempPngPath = path.join(saveDirectory, `temp_ocr_${Date.now()}_${Math.floor(Math.random() * 1000)}.png`);
        const gsArgs = [
            '-dQUIET', '-dPARANOIDSAFER', '-dBATCH', '-dNOPAUSE', '-dNOPROMPT',
            '-sDEVICE=png16m',
            '-dTextAlphaBits=4', '-dGraphicsAlphaBits=4',
            '-r300',
            '-dFirstPage=1', '-dLastPage=1',
            `-sOutputFile=${tempPngPath}`,
            filePath
        ];
        const isWindows = process.platform === 'win32';
        try {
            if (isWindows) {
                try {
                    await execFileAsync('gswin64c', gsArgs);
                } catch (err) {
                    if (err.code === 'ENOENT') {
                        try {
                            await execFileAsync('gs', gsArgs);
                        } catch (fallbackErr) {
                            await execFileAsync('gswin32c', gsArgs);
                        }
                    } else throw err;
                }
            } else {
                await execFileAsync('gs', gsArgs);
            }
            imagePathToScan = tempPngPath;
        } catch (err) {
            console.error('[ocrParser] Ghostscript conversion failed:', err.message);
            throw new Error('Failed to convert PDF to image for OCR: ' + err.message);
        }
    }

    try {
        console.log('[ocrParser] Running Native Tesseract on image:', imagePathToScan);
        const defaultTessData = path.join(__dirname, '..', '..', 'tesseract', 'tessdata');
        const tessEnv = {
            ...process.env,
            TESSDATA_PREFIX: process.env.TESSDATA_PREFIX || defaultTessData
        };
        const result = await execFileAsync('tesseract', [
            imagePathToScan,
            'stdout',
            '-l', 'eng'
        ], { env: tessEnv, maxBuffer: 1024 * 1024 * 10 });
        text = result.stdout || '';
    } catch (err) {
        console.error('[ocrParser] Tesseract execution failed:', err.message);
        throw new Error('Tesseract OCR execution failed: ' + err.message);
    } finally {
        if (tempPngPath && fs.existsSync(tempPngPath)) {
            try { fs.unlinkSync(tempPngPath); } catch (_) {}
        }
    }

    return text;
};