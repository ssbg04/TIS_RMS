const fs = require('fs');
const path = require('path');

const ALLOWED_DOCUMENT_EXTENSIONS = new Set([
    '.pdf', '.jpg', '.jpeg', '.png', '.doc', '.docx', '.xls', '.xlsx',
]);

const ALLOWED_DOCUMENT_MIME_TYPES = new Set([
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/jpg',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
]);

const ALLOWED_OCR_EXTENSIONS = new Set([
    '.pdf', '.jpg', '.jpeg', '.png', '.webp', '.bmp', '.xlsx', '.xls',
]);

const ALLOWED_OCR_MIME_TYPES = new Set([
    'application/pdf',
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'image/bmp',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
]);

/**
 * Verifies that a file's leading magic bytes match its declared extension.
 * Prevents MIME-type and filename-extension spoofing (e.g. .exe renamed to .pdf).
 */
function verifyFileMagicBytes(filePath, ext) {
    const cleanExt = (ext || path.extname(filePath)).toLowerCase();
    let fd;
    try {
        fd = fs.openSync(filePath, 'r');
        const buf = Buffer.alloc(12);
        const bytesRead = fs.readSync(fd, buf, 0, 12, 0);
        if (bytesRead < 2) return false;

        switch (cleanExt) {
            case '.pdf':
                return bytesRead >= 5 && buf.subarray(0, 5).toString('ascii') === '%PDF-';
            case '.png':
                return bytesRead >= 8 &&
                    buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4E && buf[3] === 0x47 &&
                    buf[4] === 0x0D && buf[5] === 0x0A && buf[6] === 0x1A && buf[7] === 0x0A;
            case '.jpg':
            case '.jpeg':
                return bytesRead >= 3 && buf[0] === 0xFF && buf[1] === 0xD8 && buf[2] === 0xFF;
            case '.webp':
                return bytesRead >= 12 &&
                    buf.subarray(0, 4).toString('ascii') === 'RIFF' &&
                    buf.subarray(8, 12).toString('ascii') === 'WEBP';
            case '.bmp':
                return buf[0] === 0x42 && buf[1] === 0x4D;
            case '.docx':
            case '.xlsx':
                // OOXML files are ZIP containers (PK\x03\x04, PK\x05\x06, or PK\x07\x08)
                return bytesRead >= 4 &&
                    buf[0] === 0x50 && buf[1] === 0x4B &&
                    (buf[2] === 0x03 || buf[2] === 0x05 || buf[2] === 0x07);
            case '.doc':
            case '.xls':
                // Legacy OLE2 Compound Document Binary Format
                return bytesRead >= 8 &&
                    buf[0] === 0xD0 && buf[1] === 0xCF && buf[2] === 0x11 && buf[3] === 0xE0 &&
                    buf[4] === 0xA1 && buf[5] === 0xB1 && buf[6] === 0x1A && buf[7] === 0xE1;
            default:
                return false;
        }
    } catch (_) {
        return false;
    } finally {
        if (fd !== undefined) {
            try { fs.closeSync(fd); } catch (_) {}
        }
    }
}

module.exports = {
    ALLOWED_DOCUMENT_EXTENSIONS,
    ALLOWED_DOCUMENT_MIME_TYPES,
    ALLOWED_OCR_EXTENSIONS,
    ALLOWED_OCR_MIME_TYPES,
    verifyFileMagicBytes,
};
