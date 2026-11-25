const fs = require('fs');
const path = require('path');

const GEMINI_API_BASE = 'https://generativelanguage.googleapis.com/v1beta/models';

// Preferred Flash models in order of priority
const CANDIDATE_MODELS = [
    process.env.GEMINI_MODEL,
    'gemini-3.1-flash-lite',
    'gemini-3.5-flash',
    'gemini-flash-latest'
].filter(Boolean);

/**
 * Check whether Gemini Vision OCR is configured and available.
 */
exports.isAvailable = () => {
    const key = process.env.GEMINI_API_KEY;
    return typeof key === 'string' && key.trim().length > 0;
};

/**
 * Resolve MIME type from original name or file extension
 */
function resolveMimeType(filePath, originalName = '', mimeType = '') {
    if (mimeType && mimeType.includes('/')) return mimeType;
    const ext = path.extname(originalName || filePath).toLowerCase();
    switch (ext) {
        case '.pdf': return 'application/pdf';
        case '.png': return 'image/png';
        case '.jpg':
        case '.jpeg': return 'image/jpeg';
        case '.webp': return 'image/webp';
        case '.bmp': return 'image/bmp';
        case '.heic': return 'image/heic';
        default: return 'image/jpeg';
    }
}

/**
 * Normalizes extracted fields to match RMS expectations.
 */
function normalizeExtracted(raw) {
    const data = typeof raw === 'object' && raw !== null ? raw : {};

    // 1. LRN cleanup
    let lrn = String(data.lrn || '').replace(/\D/g, '').trim();
    if (lrn.length > 12) lrn = lrn.slice(0, 12);

    // 2. Names cleanup
    const lastName = String(data.lastName || '').trim();
    const firstName = String(data.firstName || '').trim();
    const middleName = String(data.middleName || '').trim();
    const extension = String(data.extension || '').trim();

    // 3. DOB normalization (YYYY-MM-DD)
    let dob = null;
    if (data.dob) {
        const dStr = String(data.dob).trim();
        const dateMatch = dStr.match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$/);
        if (dateMatch) {
            const y = dateMatch[1];
            const m = dateMatch[2].padStart(2, '0');
            const d = dateMatch[3].padStart(2, '0');
            dob = `${y}-${m}-${d}`;
        } else if (!isNaN(Date.parse(dStr))) {
            const parsed = new Date(dStr);
            if (!isNaN(parsed.getTime())) {
                dob = parsed.toISOString().split('T')[0];
            }
        }
    }

    // 4. Sex normalization
    let sex = '';
    if (data.sex) {
        const s = String(data.sex).trim().toUpperCase();
        if (s.startsWith('M')) sex = 'Male';
        else if (s.startsWith('F')) sex = 'Female';
    }

    // 5. Grade level cleanup (digits only)
    let gradeLevel = '';
    if (data.gradeLevel) {
        const gMatch = String(data.gradeLevel).match(/\d+/);
        if (gMatch) gradeLevel = gMatch[0];
    }

    // 6. Section and School Year
    const section = String(data.section || '').replace(/^[^A-Za-z0-9]+/, '').trim();
    let schoolYear = String(data.schoolYear || '').replace(/\s+/g, '').trim();
    const syMatch = schoolYear.match(/(\d{4})[-/]?(\d{4})/);
    if (syMatch) {
        schoolYear = `${syMatch[1]}-${syMatch[2]}`;
    }

    const trackStrand = String(data.trackStrand || '').trim();
    const adviserName = String(data.adviserName || '').trim();
    const semester = String(data.semester || '').trim().toUpperCase();

    // 7. Scholastic Records
    const scholasticRecords = [];
    if (Array.isArray(data.scholasticRecords)) {
        for (const rec of data.scholasticRecords) {
            if (!rec || typeof rec !== 'object') continue;
            let rGrade = '';
            const rgMatch = String(rec.gradeLevel || '').match(/\d+/);
            if (rgMatch) rGrade = rgMatch[0];

            let rSy = String(rec.schoolYear || '').replace(/\s+/g, '').trim();
            const rSyMatch = rSy.match(/(\d{4})[-/]?(\d{4})/);
            if (rSyMatch) rSy = `${rSyMatch[1]}-${rSyMatch[2]}`;

            const rSec = String(rec.section || '').replace(/^[^A-Za-z0-9]+/, '').trim();
            const rAdv = String(rec.adviserName || '').trim();
            const rSem = String(rec.semester || '').trim().toUpperCase();

            if (rGrade && (rSec || rSy)) {
                scholasticRecords.push({
                    gradeLevel: rGrade,
                    section: rSec,
                    schoolYear: rSy,
                    adviserName: rAdv,
                    semester: rSem
                });
            }
        }
    }

    // If scholasticRecords exists and primary values are missing, inherit latest
    if (scholasticRecords.length > 0) {
        const latest = scholasticRecords[scholasticRecords.length - 1];
        if (!gradeLevel) gradeLevel = latest.gradeLevel;
        if (!section) section = latest.section;
        if (!schoolYear) schoolYear = latest.schoolYear;
        if (!adviserName) adviserName = latest.adviserName;
    }

    return {
        lrn,
        lastName,
        firstName,
        middleName,
        extension,
        dob,
        sex,
        gradeLevel,
        section,
        schoolYear,
        trackStrand,
        adviserName,
        semester,
        scholasticRecords,
        rawText: String(data.rawText || '')
    };
}

/**
 * Extracts student information and form data from an image or PDF using Google Gemini Vision.
 *
 * @param {string} filePath - Absolute or relative path to file on disk.
 * @param {string} originalName - Original uploaded filename.
 * @param {string} mimeType - MIME type of the file.
 * @param {string} docTypeHint - Optional 'SF9' or 'SF10' hint.
 * @returns {Promise<{ ok: boolean, data?: object, rawText?: string, error?: string }>}
 */
exports.extractDocument = async (filePath, originalName = '', mimeType = '', docTypeHint = '') => {
    const key = process.env.GEMINI_API_KEY;
    if (!key || typeof key !== 'string' || !key.trim()) {
        return { ok: false, error: 'GEMINI_API_KEY is not configured.' };
    }

    if (!fs.existsSync(filePath)) {
        return { ok: false, error: `File not found on disk: ${filePath}` };
    }

    const resolvedMime = resolveMimeType(filePath, originalName, mimeType);
    let base64Data;
    try {
        const fileBuffer = fs.readFileSync(filePath);
        base64Data = fileBuffer.toString('base64');
    } catch (readErr) {
        return { ok: false, error: `Failed to read file for Gemini OCR: ${readErr.message}` };
    }

    const prompt = `You are an expert AI document scanner for Philippine Department of Education (DepEd) school records:
- SF9 (Learner's Progress Report Card / Form 138)
- SF10 (Learner's Permanent Academic Record / Form 137 / Form 137-A)
${docTypeHint ? `Hint: The user expects this document to be: ${docTypeHint}` : ''}

Carefully inspect every section, header, table, and student profile in this document.
Extract all details into a clean JSON object adhering to this structure:
{
  "lrn": "12-digit student Learner Reference Number (digits only)",
  "lastName": "Surname / Last Name",
  "firstName": "Given / First Name",
  "middleName": "Middle Name (or empty string if none)",
  "extension": "Name suffix e.g. JR, SR, III (or empty string if none)",
  "dob": "Date of Birth in YYYY-MM-DD format (or null if not found)",
  "sex": "Male or Female",
  "gradeLevel": "Grade level as digits only (e.g. 7, 8, 9, 10, 11, 12)",
  "section": "Section name",
  "schoolYear": "School year in YYYY-YYYY format (e.g. 2023-2024)",
  "trackStrand": "Senior High track/strand if applicable (e.g. STEM, ABM, HUMSS, TVL, or empty string)",
  "adviserName": "Adviser / Teacher full name (or empty string)",
  "semester": "Semester if Senior High (FIRST, SECOND, or empty string)",
  "scholasticRecords": [
    {
      "gradeLevel": "Grade digits only (e.g. 7, 8, 9, 10, 11, 12)",
      "section": "Section name",
      "schoolYear": "YYYY-YYYY",
      "adviserName": "Adviser name",
      "semester": "FIRST, SECOND, or empty string"
    }
  ],
  "rawText": "Full text transcription of all readable content on this document"
}

Key extraction guidelines:
1. LRN is always 12 consecutive digits in DepEd records. Accurately capture each digit.
2. For SF10 (Permanent Record), extract each enrolled grade level and school year found in the scholastic tables into the "scholasticRecords" array.
3. Clean all extraneous prefixes or column headers from names.
4. Output valid JSON only.`;

    let lastError = null;

    // Try candidate models in order (handles quota or temporary model availability spikes)
    for (const model of CANDIDATE_MODELS) {
        try {
            console.log(`[GeminiOCR] Attempting extraction with model: ${model}...`);
            const url = `${GEMINI_API_BASE}/${model}:generateContent?key=${encodeURIComponent(key.trim())}`;

            const response = await fetch(url, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contents: [{
                        parts: [
                            { inline_data: { mime_type: resolvedMime, data: base64Data } },
                            { text: prompt }
                        ]
                    }],
                    generationConfig: {
                        responseMimeType: 'application/json',
                        temperature: 0.1
                    }
                }),
                signal: AbortSignal.timeout(25000)
            });

            const result = await response.json();

            if (!response.ok || result.error) {
                const errDetail = result.error?.message || `HTTP ${response.status}`;
                console.warn(`[GeminiOCR] Model ${model} returned error: ${errDetail}`);
                lastError = errDetail;
                continue;
            }

            const candidate = result.candidates?.[0];
            const textResponse = candidate?.content?.parts?.[0]?.text;
            if (!textResponse) {
                console.warn(`[GeminiOCR] Model ${model} returned empty response.`);
                continue;
            }

            const parsedJson = JSON.parse(textResponse);
            const normalized = normalizeExtracted(parsedJson);

            console.log(`[GeminiOCR] Successfully extracted document data via ${model}. Student: "${normalized.firstName} ${normalized.lastName}" (LRN: ${normalized.lrn || 'N/A'})`);

            return {
                ok: true,
                data: normalized,
                rawText: normalized.rawText,
                model
            };
        } catch (callErr) {
            console.warn(`[GeminiOCR] Attempt with ${model} failed: ${callErr.message}`);
            lastError = callErr.message;
        }
    }

    return {
        ok: false,
        error: lastError || 'All candidate Gemini models failed to process the document.'
    };
};

