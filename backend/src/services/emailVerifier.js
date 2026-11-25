'use strict';
require('dotenv').config();

/**
 * Extracts a clean email address from string formats such as:
 * - "user@example.com"
 * - "First Last <user@example.com>"
 */
function extractEmail(to) {
    if (!to || typeof to !== 'string') return null;
    const match = to.match(/<([^>]+)>/);
    if (match) return match[1].trim();
    return to.trim();
}

/**
 * MyEmailVerifier (MEV) Single Email Validator
 * Returns { valid: bool, reason: string, details?: object } — never throws.
 */
const validateEmailMEV = async (email) => {
    if (!email || !email.trim()) {
        return { valid: false, reason: 'Email is empty' };
    }

    const clean = extractEmail(email);
    const apiKey = process.env.MEV_API_KEY;
    if (!apiKey) {
        console.warn('[MEV] MEV_API_KEY not configured in .env – skipping verification');
        return { valid: true, reason: 'MEV key not configured – skipping' };
    }

    try {
        const url = `https://api.myemailverifier.com/api/validate_single.php?apikey=${encodeURIComponent(apiKey)}&email=${encodeURIComponent(clean)}`;
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 10000);

        const response = await fetch(url, { signal: controller.signal });
        clearTimeout(timeoutId);

        if (!response.ok) {
            console.warn(`[MEV] HTTP ${response.status} from MyEmailVerifier`);
            return { valid: true, reason: 'Validation service temporarily unavailable' };
        }

        const data = await response.json();
        const status = (data.Status || '').trim().toLowerCase();
        const diagnosis = data.Diagnosis || '';
        const isDisposable = data.Disposable_Domain === 1 ||
            data.Disposable_Domain === '1' ||
            data.Disposable_Domain === 'true' ||
            data.Disposable_Domain === true;

        if (isDisposable) {
            return { valid: false, reason: 'Disposable email addresses are not allowed', details: data };
        }

        if (status === 'invalid') {
            return { valid: false, reason: diagnosis || 'Email address does not exist or is invalid', details: data };
        }

        const isValid = status === 'valid';
        return {
            valid: isValid,
            reason: isValid ? 'valid' : (diagnosis || 'Email verification failed'),
            details: data,
        };
    } catch (err) {
        console.warn('[MEV] Email validation error (skipping):', err.message);
        return { valid: true, reason: 'MEV unreachable – skipping' };
    }
};

/**
 * Parses and extracts clean email addresses from a string or array of recipients.
 * Handles formats: "user@example.com", "John Doe <user@example.com>", "u1@e.com, u2@e.com", ['u1@e.com', ...]
 */
function parseRecipientEmails(to) {
    if (!to) return [];
    const list = Array.isArray(to) ? to : String(to).split(',');
    return list.map(item => extractEmail(item)).filter(Boolean);
}

module.exports = {
    validateEmailMEV,
    validateEmailQEV: validateEmailMEV, // Backward compatibility
    extractEmail,
    parseRecipientEmails,
};
