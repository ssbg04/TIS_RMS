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

    // 2. Extract Name (Format: "Name: LASTNAME, FIRSTNAME MIDDLENAME")
    const sf9NameMatch = text.match(/Name[:\s]+([^,\n]+),\s*([^\n]+)/i);
    if (sf9NameMatch) {
        extracted.lastName = sf9NameMatch[1].trim(); 
        const firstMiddle = sf9NameMatch[2].trim().split(/\s+/);
        if (firstMiddle.length > 1) {
            extracted.middleName = firstMiddle.pop(); 
            extracted.firstName = firstMiddle.join(' '); 
        } else {
            extracted.firstName = firstMiddle[0];
        }
    }

    // 3. Extract Extension Name from First Name or Last Name
    extracted = extractExtension(extracted);

    // 4. Extract SF9 Specifics
    const sexMatch = text.match(/(?:Sex|Gender)[:\s]*(MALE|FEMALE|M\b|F\b)/i);
    if (sexMatch) extracted.sex = sexMatch[1].toUpperCase().startsWith('M') ? 'Male' : 'Female';

    const gradeMatch = text.match(/Grade[:\s]*(\d+)/i);
    if (gradeMatch) extracted.gradeLevel = gradeMatch[1];

    const sectionMatch = text.match(/Section[:\s]*([^\n]+)/i);
    if (sectionMatch) extracted.section = sectionMatch[1].trim();

    const syMatch = text.match(/School Year[:\s]*(\d{4}\s*-\s*\d{4})/i);
    if (syMatch) extracted.schoolYear = syMatch[1].replace(/\s/g, '');

    const trackMatch = text.match(/TRACK\/STRAND[:\s]*([^\n]+)/i);
    if (trackMatch) extracted.trackStrand = trackMatch[1].trim();

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

    // 2. Extract Name (Format: "LAST NAME: ... FIRST NAME: ...")
    const lastNameMatch = text.match(/LAST\s*NAME[:\s]*([A-Za-z\-\s,\.]+?)(?=\s*(FIRST|MIDDLE|\n|$))/i);
    if (lastNameMatch) extracted.lastName = lastNameMatch[1].trim();

    const firstNameMatch = text.match(/FIRST\s*NAME[:\s]*([A-Za-z\-\s,\.]+?)(?=\s*(LAST|MIDDLE|\n|$))/i);
    if (firstNameMatch) extracted.firstName = firstNameMatch[1].trim();

    const middleNameMatch = text.match(/MIDDLE\s*NAME[:\s]*([A-Za-z\-\s,\.]+?)(?=\s*(LRN|SEX|DOB|DATE|\n|$))/i);
    if (middleNameMatch) extracted.middleName = middleNameMatch[1].trim();

    // Fallback if specific labels fail
    if (!extracted.lastName && !extracted.firstName) {
        const fallbackNameMatch = text.match(/Name[:\s]+([A-Za-z]+),\s+([A-Za-z]+)\s*([A-Za-z]+)?/i);
        if (fallbackNameMatch) {
            extracted.lastName = fallbackNameMatch[1] || '';
            extracted.firstName = fallbackNameMatch[2] || '';
            extracted.middleName = fallbackNameMatch[3] || '';
        }
    }

    // 3. Extract Extension Name
    extracted = extractExtension(extracted);

    // 4. Extract SF10 Specifics
    const dobMatch = text.match(/\b(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})\b/);
    if (dobMatch) {
        const month = dobMatch[1].padStart(2, '0');
        const day = dobMatch[2].padStart(2, '0');
        const year = dobMatch[3];
        extracted.dob = `${year}-${month}-${day}`; 
    }

    const sexMatch = text.match(/(?:Sex|Gender)[:\s]*(MALE|FEMALE|M\b|F\b)/i);
    if (sexMatch) extracted.sex = sexMatch[1].toUpperCase().startsWith('M') ? 'Male' : 'Female';

    const gradeMatch = text.match(/GRADE LEVEL[:\s]*(\d+)/i);
    if (gradeMatch) extracted.gradeLevel = gradeMatch[1];

    const sectionMatch = text.match(/SECTION[:\s]*([^\n]+)/i);
    if (sectionMatch) extracted.section = sectionMatch[1].trim();

    const syMatch = text.match(/S\.?Y\.?[:\s]*(\d{4}\s*-\s*\d{4})/i);
    if (syMatch) extracted.schoolYear = syMatch[1].replace(/\s/g, '');

    return extracted;
};

// ==========================================
// HELPER FUNCTION
// ==========================================
function extractExtension(extracted) {
    const extRegex = /(?:,\s*|\b)(JR\.?|SR\.?|II|III|IV|V|VI)\b/i;
    
    let extMatch = extracted.lastName.match(extRegex);
    if (extMatch) {
        extracted.extension = extMatch[1].replace(/[\.,]/g, '').trim().toUpperCase();
        extracted.lastName = extracted.lastName.replace(extMatch[0], '').replace(/,$/, '').trim();
    }
    
    if (!extracted.extension) {
        extMatch = extracted.firstName.match(extRegex);
        if (extMatch) {
            extracted.extension = extMatch[1].replace(/[\.,]/g, '').trim().toUpperCase();
            extracted.firstName = extracted.firstName.replace(extMatch[0], '').replace(/,$/, '').trim();
        }
    }
    return extracted;
}