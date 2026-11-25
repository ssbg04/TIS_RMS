const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');
const util = require('util');
const execFileAsync = util.promisify(execFile);
const db = require('../config/db');
const ocrParser = require('./ocrParser');

const CONFIDENCE_HIGH = 90;
const CONFIDENCE_MEDIUM = 65;

const CONTENT_PROFILES = [
    {
        key: 'sf9',
        reqHints: ['sf9', 'sf 9', 'form 138', 'report card', 'school form 9'],
        strongPatterns: [
            /school\s*form\s*9\b/i,
            /\bsf\s*9\b/i,
            /learner'?s\s*progress\s*report\s*card/i,
            /\bform\s*138\b/i,
        ],
        supportPatterns: [
            /report\s*card/i,
            /learning\s*areas/i,
            /quarterly\s*rating/i,
            /observed\s*values/i,
            /attendance\s*record/i,
        ],
    },
    {
        key: 'sf10',
        reqHints: ['sf10', 'sf 10', 'form 137', 'permanent record', 'school form 10'],
        strongPatterns: [
            /school\s*form\s*10\b/i,
            /\bsf\s*10\b/i,
            /learner'?s?\s*permanent\s*(?:academic\s*)?record/i,
            /\bform\s*137\b/i,
        ],
        supportPatterns: [
            /scholastic\s*record/i,
            /certification\s*of\s*transfer/i,
            /elementary\s*school\s*completer/i,
            /junior\s*high\s*school/i,
            /senior\s*high\s*school/i,
        ],
    },
    {
        key: 'psa_birth',
        reqHints: ['psa', 'birth certificate', 'live birth', 'nso'],
        strongPatterns: [
            /philippine\s*statistics\s*authority/i,
            /certificate\s*of\s*live\s*birth/i,
            /office\s*of\s*the\s*civil\s*registrar/i,
        ],
        supportPatterns: [
            /\bpsa\b/i,
            /\bnso\b/i,
            /registry\s*number/i,
            /date\s*of\s*birth/i,
            /place\s*of\s*birth/i,
            /maiden\s*name/i,
        ],
    },
    {
        key: 'good_moral',
        reqHints: ['good moral', 'gmc', 'moral character'],
        strongPatterns: [
            /certificate\s*of\s*good\s*moral\s*character/i,
            /good\s*moral\s*character/i,
        ],
        supportPatterns: [
            /no\s*derogatory\s*record/i,
            /law[- ]abiding/i,
            /guidance\s*(?:counselor|office|coordinator)/i,
            /principal/i,
        ],
    },
    {
        key: 'medical',
        reqHints: ['medical', 'med cert', 'health certificate'],
        strongPatterns: [
            /medical\s*certificate/i,
            /certificate\s*of\s*medical\s*examination/i,
            /physical\s*examination/i,
        ],
        supportPatterns: [
            /physically\s*fit/i,
            /physician/i,
            /license\s*no/i,
            /blood\s*pressure/i,
            /diagnosis/i,
        ],
    },
    {
        key: 'photo_2x2',
        reqHints: ['2x2', 'id photo', 'id picture', 'photo'],
        strongPatterns: [/2\s*x\s*2\s*(?:id\s*)?(?:photo|picture)/i],
        supportPatterns: [],
    },
];

function normalizeText(value) {
    if (!value || typeof value !== 'string') return '';
    return value
        .toLowerCase()
        .replace(/[_.\-/\\]+/g, ' ')
        .replace(/[^a-z0-9\s]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
}

function stripExtension(filename) {
    if (!filename || typeof filename !== 'string') return '';
    const ext = path.extname(filename);
    return ext ? filename.slice(0, -ext.length) : filename;
}

function toConfidenceLevel(score) {
    if (score >= CONFIDENCE_HIGH) return 'high';
    if (score >= CONFIDENCE_MEDIUM) return 'medium';
    return 'low';
}

function getStudentGradeCategories(studentId) {
    if (!studentId) return null;
    try {
        const rows = db.prepare('SELECT DISTINCT grade_level FROM enrollments WHERE student_id = ?').all(studentId);
        if (!rows || rows.length === 0) return null;
        const cats = new Set();
        for (const row of rows) {
            if (row.grade_level <= 10) cats.add('JHS');
            if (row.grade_level >= 11) cats.add('SHS');
        }
        return cats.size > 0 ? cats : null;
    } catch (_) {
        return null;
    }
}

function loadRequirementsAndAliases() {
    const requirements = db.prepare(`
        SELECT id, name, description, category, is_mandatory, is_enabled, max_files
        FROM document_requirements
        WHERE is_enabled = 1
        ORDER BY category ASC, name ASC
    `).all();

    const aliasRows = db.prepare(`
        SELECT id, requirement_id, alias, source, is_approved, usage_count
        FROM document_requirement_aliases
        WHERE is_approved = 1
    `).all();

    const aliasesByReqId = new Map();
    for (const row of aliasRows) {
        if (!aliasesByReqId.has(row.requirement_id)) {
            aliasesByReqId.set(row.requirement_id, []);
        }
        aliasesByReqId.get(row.requirement_id).push(row);
    }

    return { requirements, aliasesByReqId };
}

function scoreRequirementCategoryBonus(req, allowedCategories) {
    if (!allowedCategories) return 0;
    return allowedCategories.has(req.category) ? 2 : -15;
}

function matchByFilename(originalFilename, requirements, aliasesByReqId, allowedCategories) {
    const baseName = stripExtension(originalFilename);
    const normalizedFile = normalizeText(baseName);
    const compactFile = normalizedFile.replace(/\s+/g, '');
    const fileTokens = new Set(normalizedFile.split(' ').filter(t => t.length >= 2));

    if (!normalizedFile) {
        return { requirement: null, confidence: 0, confidenceLevel: 'low', matchedAlias: null };
    }

    let bestReq = null;
    let bestScore = 0;
    let bestAlias = null;

    for (const req of requirements) {
        const normalizedReq = normalizeText(req.name);
        const compactReq = normalizedReq.replace(/\s+/g, '');
        const reqAliases = aliasesByReqId.get(req.id) || [];

        let score = 0;
        let matchedAlias = null;

        // 1. Exact normalized match with requirement name
        if (normalizedReq && (normalizedFile === normalizedReq || compactFile === compactReq)) {
            score = 98;
            matchedAlias = req.name;
        }

        // 2. Check approved aliases (system + admin-learned)
        for (const aliasObj of reqAliases) {
            const normAlias = normalizeText(aliasObj.alias);
            const compactAlias = normAlias.replace(/\s+/g, '');
            if (!normAlias) continue;

            if (normalizedFile === normAlias || compactFile === compactAlias) {
                const s = aliasObj.source === 'admin_learned' ? 95 : 96;
                if (s > score) {
                    score = s;
                    matchedAlias = aliasObj.alias;
                }
            } else if (
                normAlias.length >= 3 &&
                (new RegExp(`\\b${normAlias.replace(/\s+/g, '\\s+')}\\b`, 'i').test(normalizedFile) ||
                 (compactAlias.length >= 3 && compactFile.includes(compactAlias)))
            ) {
                const s = normAlias.includes(' ') ? 93 : 91;
                if (s > score) {
                    score = s;
                    matchedAlias = aliasObj.alias;
                }
            }
        }

        // 3. Partial token overlap fallback
        if (score < 70 && normalizedReq) {
            const reqTokens = normalizedReq.split(' ').filter(t => t.length >= 3);
            if (reqTokens.length > 0) {
                let matchedTokens = 0;
                for (const rt of reqTokens) {
                    if (fileTokens.has(rt) || compactFile.includes(rt)) {
                        matchedTokens++;
                    }
                }
                if (matchedTokens > 0) {
                    const ratio = matchedTokens / reqTokens.length;
                    const partialScore = Math.round(45 + ratio * 40); // 45–85%
                    if (partialScore > score) {
                        score = partialScore;
                        matchedAlias = reqTokens.filter(rt => fileTokens.has(rt) || compactFile.includes(rt)).join(' ');
                    }
                }
            }
        }

        const adjusted = Math.max(0, Math.min(100, score + scoreRequirementCategoryBonus(req, allowedCategories)));
        if (adjusted > bestScore) {
            bestScore = adjusted;
            bestReq = req;
            bestAlias = matchedAlias;
        }
    }

    return {
        requirement: bestScore > 0 ? bestReq : null,
        confidence: bestScore,
        confidenceLevel: toConfidenceLevel(bestScore),
        matchedAlias: bestAlias,
    };
}

async function runGhostscript(gsArgs, timeoutMs = 15000) {
    const isWindows = process.platform === 'win32';
    const opts = { timeout: timeoutMs };
    if (isWindows) {
        try {
            return await execFileAsync('gswin64c', gsArgs, opts);
        } catch (err) {
            if (err.code === 'ENOENT') {
                try {
                    return await execFileAsync('gs', gsArgs, opts);
                } catch (_) {
                    return await execFileAsync('gswin32c', gsArgs, opts);
                }
            }
            throw err;
        }
    }
    return await execFileAsync('gs', gsArgs, opts);
}

async function extractPdfEmbeddedText(filePath) {
    const tempDir = path.resolve('./uploads/temp_ocr/');
    if (!fs.existsSync(tempDir)) {
        fs.mkdirSync(tempDir, { recursive: true });
    }
    const tempTxtPath = path.join(tempDir, `pdf_txt_${Date.now()}_${Math.floor(Math.random() * 10000)}.txt`);
    const gsArgs = [
        '-q', '-dNODISPLAY', '-dSAFER', '-dBATCH', '-dNOPAUSE', '-dNOPROMPT',
        '-dFirstPage=1', '-dLastPage=2',
        '-sDEVICE=txtwrite',
        `-sOutputFile=${tempTxtPath}`,
        filePath,
    ];
    try {
        await runGhostscript(gsArgs, 15000);
        if (fs.existsSync(tempTxtPath)) {
            const raw = fs.readFileSync(tempTxtPath, 'utf8');
            return raw.replace(/\x00/g, '').trim();
        }
        return '';
    } catch (err) {
        console.warn('[DocumentIdentification] PDF txtwrite failed, will fall back to OCR:', err.message);
        return '';
    } finally {
        if (fs.existsSync(tempTxtPath)) {
            try { fs.unlinkSync(tempTxtPath); } catch (_) {}
        }
    }
}

function classifyTextContent(text, requirements, aliasesByReqId, allowedCategories) {
    if (!text || text.trim().length === 0) {
        return { requirement: null, confidence: 0, confidenceLevel: 'low', matchedSignals: [] };
    }

    const normalizedContent = normalizeText(text);
    let bestReq = null;
    let bestScore = 0;
    let bestSignals = [];

    for (const req of requirements) {
        const reqLower = (req.name || '').toLowerCase();
        const normalizedReq = normalizeText(req.name);
        const reqAliases = aliasesByReqId.get(req.id) || [];

        let score = 0;
        const signals = [];

        // 1. Profile regex matching (strong & supporting DepEd document indicators)
        for (const profile of CONTENT_PROFILES) {
            const matchesProfile = profile.reqHints.some(h => reqLower.includes(h) || normalizedReq.includes(h)) ||
                reqAliases.some(a => profile.reqHints.some(h => normalizeText(a.alias).includes(h)));

            if (!matchesProfile) continue;

            let strongHits = 0;
            for (const pat of profile.strongPatterns) {
                if (pat.test(text)) {
                    strongHits++;
                    signals.push(pat.source.replace(/\\s\*/g, ' '));
                }
            }

            let supportHits = 0;
            for (const pat of profile.supportPatterns) {
                if (pat.test(text)) {
                    supportHits++;
                }
            }

            if (strongHits >= 2) {
                score = Math.max(score, 96);
            } else if (strongHits === 1) {
                score = Math.max(score, supportHits >= 1 ? 94 : 84);
            } else if (supportHits >= 2) {
                score = Math.max(score, 76);
            } else if (supportHits === 1) {
                score = Math.max(score, 58);
            }
        }

        // 2. Direct requirement name / alias presence in text
        if (normalizedReq && normalizedReq.length >= 4 && normalizedContent.includes(normalizedReq)) {
            score = Math.max(score, 91);
            signals.push(req.name);
        }

        for (const aliasObj of reqAliases) {
            const normAlias = normalizeText(aliasObj.alias);
            if (normAlias.length >= 4 && normalizedContent.includes(normAlias)) {
                score = Math.max(score, 85);
                signals.push(aliasObj.alias);
            }
        }

        const adjusted = Math.max(0, Math.min(100, score + scoreRequirementCategoryBonus(req, allowedCategories)));
        if (adjusted > bestScore) {
            bestScore = adjusted;
            bestReq = req;
            bestSignals = signals;
        }
    }

    return {
        requirement: bestScore > 0 ? bestReq : null,
        confidence: bestScore,
        confidenceLevel: toConfidenceLevel(bestScore),
        matchedSignals: bestSignals,
    };
}

function verifyStudentIdentity({ text, originalFilename, studentId, lrn }) {
    let detectedLrn = '';
    let detectedName = '';

    if (text && text.trim().length > 0) {
        const parsed = ocrParser.parseSF9(text);
        if (parsed.lrn && /^\d{12}$/.test(parsed.lrn)) {
            detectedLrn = parsed.lrn;
        }
        if (parsed.lastName || parsed.firstName) {
            detectedName = [parsed.firstName, parsed.middleName, parsed.lastName]
                .filter(Boolean)
                .join(' ')
                .trim();
        }
    }

    // Fallback: 12-digit LRN in filename
    if (!detectedLrn && originalFilename) {
        const fileLrnMatch = originalFilename.match(/\b(\d{12})\b/);
        if (fileLrnMatch) {
            detectedLrn = fileLrnMatch[1];
        }
    }

    // Look up student matching detected LRN (if any)
    let studentByDetectedLrn = null;
    if (detectedLrn) {
        studentByDetectedLrn = db.prepare(
            'SELECT id, lrn, first_name, middle_name, last_name FROM students WHERE lrn = ?'
        ).get(detectedLrn) || null;
    }

    // Resolve expected student (if provided)
    let expectedStudent = null;
    if (studentId) {
        expectedStudent = db.prepare(
            'SELECT id, lrn, first_name, middle_name, last_name FROM students WHERE id = ?'
        ).get(studentId) || null;
    } else if (lrn && /^\d{12}$/.test(String(lrn).trim())) {
        expectedStudent = db.prepare(
            'SELECT id, lrn, first_name, middle_name, last_name FROM students WHERE lrn = ?'
        ).get(String(lrn).trim()) || null;
    }

    const formatName = (s) => `${s.first_name} ${s.last_name}`.trim();

    if (!expectedStudent) {
        return {
            status: studentByDetectedLrn ? 'matched_unselected' : 'not_checked',
            detectedLrn: detectedLrn || null,
            detectedStudentName: detectedName || (studentByDetectedLrn ? formatName(studentByDetectedLrn) : null),
            suggestedStudentId: studentByDetectedLrn?.id || null,
            suggestedStudentLrn: studentByDetectedLrn?.lrn || null,
            suggestedStudentName: studentByDetectedLrn ? formatName(studentByDetectedLrn) : null,
            message: studentByDetectedLrn
                ? `Detected LRN ${detectedLrn} (${formatName(studentByDetectedLrn)})`
                : 'No student selected for identity check',
        };
    }

    // Expected student exists — compare LRN first
    if (detectedLrn) {
        if (detectedLrn === expectedStudent.lrn) {
            return {
                status: 'verified',
                detectedLrn,
                detectedStudentName: detectedName || formatName(expectedStudent),
                suggestedStudentId: expectedStudent.id,
                suggestedStudentLrn: expectedStudent.lrn,
                suggestedStudentName: formatName(expectedStudent),
                message: `LRN matched (${detectedLrn})`,
            };
        }

        const otherStudentDesc = studentByDetectedLrn
            ? `belongs to ${formatName(studentByDetectedLrn)} (${studentByDetectedLrn})`
            : `(${detectedLrn}) does not match ${formatName(expectedStudent)} (${expectedStudent.lrn})`;

        return {
            status: 'mismatch',
            detectedLrn,
            detectedStudentName: detectedName || (studentByDetectedLrn ? formatName(studentByDetectedLrn) : null),
            suggestedStudentId: studentByDetectedLrn?.id || null,
            suggestedStudentLrn: studentByDetectedLrn?.lrn || null,
            suggestedStudentName: studentByDetectedLrn ? formatName(studentByDetectedLrn) : null,
            message: `LRN mismatch: document LRN ${otherStudentDesc}`,
        };
    }

    // Fallback: name matching in extracted text
    if (text && text.trim().length > 0) {
        const normText = normalizeText(text);
        const first = normalizeText(expectedStudent.first_name);
        const last = normalizeText(expectedStudent.last_name);
        if (first && last && normText.includes(first) && normText.includes(last)) {
            return {
                status: 'verified',
                detectedLrn: null,
                detectedStudentName: formatName(expectedStudent),
                suggestedStudentId: expectedStudent.id,
                suggestedStudentLrn: expectedStudent.lrn,
                suggestedStudentName: formatName(expectedStudent),
                message: `Student name matched (${formatName(expectedStudent)})`,
            };
        }
    }

    return {
        status: 'unknown',
        detectedLrn: null,
        detectedStudentName: detectedName || null,
        suggestedStudentId: null,
        suggestedStudentLrn: null,
        suggestedStudentName: null,
        message: 'Could not verify student identity from document content',
    };
}

/**
 * Hybrid document identification pipeline:
 * 1. Filename normalization & alias matching
 * 2. PDF embedded-text extraction (or spreadsheet text)
 * 3. Tesseract OCR fallback for scanned PDFs and images
 * 4. Confidence evaluation (high >= 90, medium 65-89, low < 65)
 * 5. Separate student identity verification (LRN & name)
 */
exports.identifyDocument = async ({
    filePath,
    originalFilename,
    mimeType = '',
    fileSize = 0,
    studentId = null,
    lrn = null,
}) => {
    const ext = path.extname(originalFilename || filePath || '').toLowerCase();
    const allowedCategories = getStudentGradeCategories(studentId);
    const { requirements, aliasesByReqId } = loadRequirementsAndAliases();

    // Step 2: Filename matching (Layer 1)
    const filenameResult = matchByFilename(originalFilename, requirements, aliasesByReqId, allowedCategories);

    let extractedText = '';
    let detectionMethod = 'filename';
    let finalClassification = filenameResult;

    const isPdf = ext === '.pdf' || mimeType === 'application/pdf';
    const isImage = ['.jpg', '.jpeg', '.png', '.webp', '.bmp'].includes(ext) || mimeType.startsWith('image/');
    const isSpreadsheet = ['.xlsx', '.xls', '.csv'].includes(ext);

    // For PDFs/spreadsheets, always attempt fast embedded text extraction so we can verify student identity too
    if (isPdf && filePath && fs.existsSync(filePath)) {
        const pdfText = await extractPdfEmbeddedText(filePath);
        if (pdfText.replace(/\s+/g, '').length >= 30) {
            extractedText = pdfText;
        }
    } else if (isSpreadsheet && filePath && fs.existsSync(filePath)) {
        try {
            extractedText = await ocrParser.extractTextFromFile(filePath, originalFilename, mimeType);
        } catch (_) {}
    }

    // If filename match is NOT high confidence, run content classification (PDF text first, then Tesseract OCR)
    if (filenameResult.confidence < CONFIDENCE_HIGH) {
        if (extractedText.length >= 30) {
            const pdfClass = classifyTextContent(extractedText, requirements, aliasesByReqId, allowedCategories);
            if (pdfClass.confidence >= filenameResult.confidence) {
                finalClassification = pdfClass;
                detectionMethod = 'pdf_text';
            }
        } else if ((isPdf || isImage) && filePath && fs.existsSync(filePath)) {
            try {
                const ocrText = await ocrParser.extractTextFromFile(filePath, originalFilename, mimeType);
                extractedText = ocrText || '';
                const ocrClass = classifyTextContent(extractedText, requirements, aliasesByReqId, allowedCategories);
                if (ocrClass.confidence >= filenameResult.confidence) {
                    finalClassification = ocrClass;
                    detectionMethod = 'ocr';
                }
            } catch (ocrErr) {
                console.warn('[DocumentIdentification] OCR fallback failed:', ocrErr.message);
            }
        }
    }

    // Step 5: Student identity verification (independent from classification confidence)
    const identity = verifyStudentIdentity({
        text: extractedText,
        originalFilename,
        studentId,
        lrn,
    });

    const req = finalClassification.requirement;
    const confidence = finalClassification.confidence || 0;
    const confidenceLevel = toConfidenceLevel(confidence);

    return {
        filename: originalFilename,
        extension: ext.replace('.', ''),
        fileSize,
        detectionMethod: req ? detectionMethod : (extractedText ? (isPdf && detectionMethod === 'filename' ? 'pdf_text' : detectionMethod) : 'filename'),
        requirementId: req ? req.id : null,
        requirementName: req ? `${req.category} - ${req.name}` : null,
        requirementRawName: req ? req.name : null,
        requirementCategory: req ? req.category : null,
        confidence,
        confidenceLevel,
        autoSelectRecommended: confidenceLevel === 'high',
        requiresConfirmation: confidenceLevel === 'medium',
        identity,
    };
};

/**
 * Records administrator-confirmed classification and learns non-generic filename aliases.
 */
exports.recordIdentificationFeedback = ({
    originalFilename,
    detectedRequirementId = null,
    confirmedRequirementId,
    detectionMethod = 'manual',
    detectedConfidence = 0,
    studentId = null,
    confirmedBy = null,
}) => {
    if (!originalFilename || !confirmedRequirementId) return null;

    const normalizedFilename = normalizeText(stripExtension(originalFilename));
    if (!normalizedFilename) return null;

    const wasOverridden = detectedRequirementId && Number(detectedRequirementId) !== Number(confirmedRequirementId) ? 1 : 0;

    let learnedAliasId = null;

    // Learn alias when admin manually classifies an undetected file or overrides a wrong suggestion
    // Skip purely numeric camera timestamps like "20261120 123456" unless repeated
    const isNumericOnly = /^[\d\s]+$/.test(normalizedFilename);
    const shouldLearn = (wasOverridden === 1 || !detectedRequirementId) && normalizedFilename.length >= 3 && !isNumericOnly;

    if (shouldLearn) {
        try {
            const existing = db.prepare(`
                SELECT id, usage_count FROM document_requirement_aliases
                WHERE requirement_id = ? AND alias = ?
            `).get(confirmedRequirementId, normalizedFilename);

            if (existing) {
                db.prepare(`
                    UPDATE document_requirement_aliases
                    SET usage_count = usage_count + 1
                    WHERE id = ?
                `).run(existing.id);
                learnedAliasId = existing.id;
            } else {
                const insertRes = db.prepare(`
                    INSERT INTO document_requirement_aliases (requirement_id, alias, source, is_approved, usage_count, created_by)
                    VALUES (?, ?, 'admin_learned', 1, 1, ?)
                `).run(confirmedRequirementId, normalizedFilename, confirmedBy);
                learnedAliasId = insertRes.lastInsertRowid;
            }
        } catch (err) {
            console.warn('[DocumentIdentification] Alias learning error:', err.message);
        }
    }

    try {
        db.prepare(`
            INSERT INTO document_identification_feedback (
                original_filename, normalized_filename, detected_requirement_id,
                confirmed_requirement_id, detection_method, detected_confidence,
                was_overridden, student_id, confirmed_by, learned_alias_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
            originalFilename,
            normalizedFilename,
            detectedRequirementId || null,
            confirmedRequirementId,
            detectionMethod || 'manual',
            Number(detectedConfidence) || 0,
            wasOverridden,
            studentId || null,
            confirmedBy || null,
            learnedAliasId
        );
    } catch (err) {
        console.warn('[DocumentIdentification] Feedback insert error:', err.message);
    }

    return { learnedAliasId, normalizedFilename, wasOverridden: wasOverridden === 1 };
};

exports.listAliases = () => {
    return db.prepare(`
        SELECT a.id, a.requirement_id, r.category || ' - ' || r.name AS requirement_name,
               a.alias, a.source, a.is_approved, a.usage_count, a.created_at
        FROM document_requirement_aliases a
        JOIN document_requirements r ON a.requirement_id = r.id
        ORDER BY CASE WHEN a.source = 'admin_learned' THEN 0 ELSE 1 END, a.usage_count DESC, a.alias ASC
    `).all();
};

exports.updateAliasApproval = (aliasId, isApproved) => {
    const info = db.prepare(`
        UPDATE document_requirement_aliases SET is_approved = ? WHERE id = ?
    `).run(isApproved ? 1 : 0, aliasId);
    return info.changes > 0;
};

exports.deleteAlias = (aliasId) => {
    const info = db.prepare(`
        DELETE FROM document_requirement_aliases WHERE id = ?
    `).run(aliasId);
    return info.changes > 0;
};
