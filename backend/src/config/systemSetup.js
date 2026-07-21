const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

/**
 * Cross-platform environment setup helper.
 * On Windows: Configures bundled Ghostscript and Tesseract binaries from backend directory.
 * On Linux (Ubuntu): Checks system binaries, attempts auto-setup if missing, and configures system tessdata.
 */
function setupSystemEnvironment() {
    const isWindows = process.platform === 'win32';
    const isLinux = process.platform === 'linux';

    console.log(`[System Setup] Operating System detected: ${process.platform} (${isWindows ? 'Windows' : isLinux ? 'Linux/Ubuntu' : 'Other'})`);

    if (isWindows) {
        // WINDOWS: Use bundled binaries inside backend directory
        const gsPath = path.join(__dirname, '..', '..', 'ghostscript', 'bin');
        const tessPath = path.join(__dirname, '..', '..', 'tesseract');
        
        process.env.PATH = `${gsPath}${path.delimiter}${tessPath}${path.delimiter}${process.env.PATH}`;

        const localTessData = path.join(__dirname, '..', '..', 'tesseract', 'tessdata');
        if (fs.existsSync(localTessData)) {
            process.env.TESSDATA_PREFIX = localTessData;
        }

        console.log('[System Setup] Windows environment configured using bundled Ghostscript & Tesseract binaries.');
    } else if (isLinux) {
        // LINUX / UBUNTU: Check and use system installed packages
        const ubuntuOneLiner = 'sudo apt-get update && sudo apt-get install -y ghostscript tesseract-ocr tesseract-ocr-eng libtesseract-dev';
        
        let hasGs = false;
        let hasTesseract = false;

        try {
            execSync('which gs', { stdio: 'ignore' });
            hasGs = true;
        } catch (_) {}

        try {
            execSync('which tesseract', { stdio: 'ignore' });
            hasTesseract = true;
        } catch (_) {}

        if (!hasGs || !hasTesseract) {
            console.warn('[System Setup] WARNING: Missing OCR dependencies on Linux system!');
            if (!hasGs) console.warn('  - Ghostscript (gs) is NOT installed.');
            if (!hasTesseract) console.warn('  - Tesseract (tesseract) is NOT installed.');
            console.log('[System Setup] Attempting auto-setup for Ubuntu/Debian...');

            try {
                execSync(ubuntuOneLiner, { stdio: 'inherit' });
                console.log('[System Setup] Auto-installation of Ghostscript & Tesseract completed successfully.');
            } catch (_) {
                console.warn('[System Setup] Auto-installation requires root/sudo privileges.');
                console.log(`[System Setup] Run this command on your Ubuntu server:\n\n  ${ubuntuOneLiner}\n`);
            }
        } else {
            console.log('[System Setup] Linux environment verified: Ghostscript and Tesseract are installed.');
        }

        // Set TESSDATA_PREFIX for Linux (prioritize system paths, fallback to local tessdata)
        const possibleTessDataPaths = [
            '/usr/share/tesseract-ocr/4.00/tessdata',
            '/usr/share/tesseract-ocr/5/tessdata',
            '/usr/share/tessdata',
            '/usr/share/tesseract-ocr/tessdata',
            path.join(__dirname, '..', '..', 'tesseract', 'tessdata')
        ];

        for (const tessDir of possibleTessDataPaths) {
            if (fs.existsSync(tessDir)) {
                process.env.TESSDATA_PREFIX = tessDir;
                break;
            }
        }
    }
}

module.exports = { setupSystemEnvironment };
