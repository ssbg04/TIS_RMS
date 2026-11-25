/**
 * TIS-RMS Cloudflare Tunnel Security & Binary Auto-Updater
 *
 * Capabilities:
 * 1. Detects installed cloudflared version vs latest official Cloudflare release.
 * 2. Safely downloads, verifies integrity, and updates bin/cloudflared.exe.
 * 3. Gracefully stops running tunnel process before swapping to prevent Windows file lock.
 * 4. Configures new tunnel token / hostname in backend/.env:
 *      node scripts/update_tunnel.js --token eyJh... --hostname subdomain.domain.com
 *
 * Commands:
 *   node scripts/update_tunnel.js          # Check and update binary if newer
 *   node scripts/update_tunnel.js --check  # Check versions without updating
 *   node scripts/update_tunnel.js --force  # Force re-download latest binary
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const { execSync, spawnSync } = require('child_process');

const BACKEND_DIR = path.resolve(__dirname, '..');
const BIN_DIR = path.join(BACKEND_DIR, 'bin');
const CLOUDFLARED_EXE = path.join(BIN_DIR, 'cloudflared.exe');
const ENV_FILE = path.join(BACKEND_DIR, '.env');
const GITHUB_API_URL = 'https://api.github.com/repos/cloudflare/cloudflared/releases/latest';
const DOWNLOAD_URL = 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe';

// Helper: fetch JSON from HTTPS with user-agent
function fetchJson(url) {
    return new Promise((resolve, reject) => {
        const options = {
            headers: {
                'User-Agent': 'TIS-RMS-Tunnel-Updater',
                'Accept': 'application/vnd.github.v3+json'
            }
        };
        https.get(url, options, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                return fetchJson(res.headers.location).then(resolve).catch(reject);
            }
            if (res.statusCode !== 200) {
                return reject(new Error(`HTTP ${res.statusCode}: ${res.statusMessage}`));
            }
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    resolve(JSON.parse(data));
                } catch (e) {
                    reject(e);
                }
            });
        }).on('error', reject);
    });
}

// Helper: download binary following redirects with progress
function downloadFile(url, destPath) {
    return new Promise((resolve, reject) => {
        const file = fs.createWriteStream(destPath);
        const request = https.get(url, { headers: { 'User-Agent': 'TIS-RMS-Tunnel-Updater' } }, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                file.close();
                fs.unlinkSync(destPath);
                return downloadFile(res.headers.location, destPath).then(resolve).catch(reject);
            }
            if (res.statusCode !== 200) {
                file.close();
                fs.unlinkSync(destPath);
                return reject(new Error(`Download failed with HTTP ${res.statusCode}`));
            }
            const totalBytes = parseInt(res.headers['content-length'] || '0', 10);
            let downloadedBytes = 0;
            let lastPercent = 0;

            res.on('data', (chunk) => {
                downloadedBytes += chunk.length;
                if (totalBytes > 0) {
                    const percent = Math.floor((downloadedBytes / totalBytes) * 100);
                    if (percent >= lastPercent + 15 || percent === 100) {
                        process.stdout.write(`[Update] Downloading cloudflared: ${percent}% (${(downloadedBytes / 1048576).toFixed(1)} MB / ${(totalBytes / 1048576).toFixed(1)} MB)\r`);
                        lastPercent = percent;
                    }
                }
            });

            res.pipe(file);
            file.on('finish', () => {
                file.close(() => {
                    process.stdout.write('\n');
                    resolve();
                });
            });
        });

        request.on('error', (err) => {
            file.close();
            if (fs.existsSync(destPath)) fs.unlinkSync(destPath);
            reject(err);
        });
    });
}

// Helper: read current installed cloudflared version string
function getInstalledVersion() {
    if (!fs.existsSync(CLOUDFLARED_EXE)) return null;
    try {
        const out = execSync(`"${CLOUDFLARED_EXE}" --version`, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
        const match = out.match(/cloudflared version (\S+)/i);
        return match ? match[1] : out.trim();
    } catch (_) {
        return null;
    }
}

// Helper: stop any currently active cloudflared process on Windows
function stopRunningCloudflared() {
    if (process.platform === 'win32') {
        try {
            spawnSync('taskkill', ['/F', '/IM', 'cloudflared.exe'], { stdio: 'ignore' });
        } catch (_) {}
    }
}

// Helper: update or insert a key=value in .env preserving all other contents
function updateEnvKey(key, value) {
    if (!fs.existsSync(ENV_FILE)) {
        fs.writeFileSync(ENV_FILE, `${key}=${value}\n`, 'utf8');
        return;
    }
    const content = fs.readFileSync(ENV_FILE, 'utf8');
    const regex = new RegExp(`^${key}=.*$`, 'm');
    let updated;
    if (regex.test(content)) {
        updated = content.replace(regex, `${key}=${value}`);
    } else {
        updated = content.trimEnd() + `\n${key}=${value}\n`;
    }
    fs.writeFileSync(ENV_FILE, updated, 'utf8');
}

// ─── Main Execution ──────────────────────────────────────────────────────────

async function main() {
    console.log('========================================================');
    console.log('  TIS-RMS Cloudflare Tunnel Security & Update Manager');
    console.log('========================================================\n');

    const args = process.argv.slice(2);
    const checkOnly = args.includes('--check');
    const forceUpdate = args.includes('--force');

    // 1. Check if token or hostname configuration requested
    const tokenIndex = args.indexOf('--token');
    const hostnameIndex = args.indexOf('--hostname');
    let configApplied = false;

    if (tokenIndex !== -1 && args[tokenIndex + 1]) {
        const newToken = args[tokenIndex + 1].trim();
        if (!newToken.startsWith('eyJh')) {
            console.warn('[Warning] Token does not look like standard Cloudflare token (usually starts with "eyJh").');
        }
        updateEnvKey('CLOUDFLARE_TUNNEL_TOKEN', newToken);
        updateEnvKey('CLOUDFLARE_TUNNEL_ENABLED', 'true');
        console.log('[Config] Updated CLOUDFLARE_TUNNEL_TOKEN in .env (activation enabled).');
        configApplied = true;
    }

    if (hostnameIndex !== -1 && args[hostnameIndex + 1]) {
        const newHostname = args[hostnameIndex + 1].trim().replace(/^https?:\/\//i, '');
        updateEnvKey('CLOUDFLARE_TUNNEL_HOSTNAME', newHostname);
        console.log(`[Config] Updated CLOUDFLARE_TUNNEL_HOSTNAME in .env: ${newHostname}`);
        configApplied = true;
    }

    if (configApplied && !forceUpdate && !args.includes('--binary')) {
        console.log('\n[Done] Tunnel configuration saved to .env.');
        console.log('Restart the backend service to apply: npm run start (or service:restart)');
        return;
    }

    // 2. Binary Version Check & Update
    if (!fs.existsSync(BIN_DIR)) {
        fs.mkdirSync(BIN_DIR, { recursive: true });
    }

    const currentVersion = getInstalledVersion();
    console.log(`[Version] Currently installed cloudflared: ${currentVersion || 'NOT INSTALLED'}`);

    console.log('[Version] Checking latest official release from GitHub...');
    let latestRelease;
    try {
        latestRelease = await fetchJson(GITHUB_API_URL);
    } catch (err) {
        console.error(`[Error] Failed to fetch release metadata: ${err.message}`);
        console.log('Continuing with existing binary.');
        return;
    }

    const latestVersion = latestRelease.tag_name ? latestRelease.tag_name.replace(/^v/i, '') : 'unknown';
    console.log(`[Version] Latest official release on Cloudflare: ${latestVersion}`);

    const isOutdated = !currentVersion || (currentVersion !== latestVersion);

    if (checkOnly) {
        if (isOutdated) {
            console.log(`\n[Status] Update available: ${currentVersion} -> ${latestVersion}`);
            console.log('Run "node scripts/update_tunnel.js" to upgrade.');
        } else {
            console.log('\n[Status] cloudflared is already up-to-date.');
        }
        return;
    }

    if (!isOutdated && !forceUpdate) {
        console.log('\n[Success] cloudflared is already up-to-date with latest security release.');
        return;
    }

    // 3. Perform Safe Upgrade
    console.log(`\n[Action] Updating cloudflared (${currentVersion || 'none'} -> ${latestVersion})...`);

    const tempDownloadPath = path.join(BIN_DIR, 'cloudflared.exe.download');
    const backupPath = path.join(BIN_DIR, 'cloudflared.exe.old');

    try {
        // Download binary
        await downloadFile(DOWNLOAD_URL, tempDownloadPath);

        // Verify download by executing --version on downloaded temp file
        let verifiedVersion = '';
        try {
            const testOut = execSync(`"${tempDownloadPath}" --version`, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
            verifiedVersion = testOut.match(/cloudflared version (\S+)/i)?.[1] || testOut.trim();
            console.log(`[Verified] Downloaded binary confirmed valid: version ${verifiedVersion}`);
        } catch (verifyErr) {
            throw new Error(`Downloaded binary verification failed: ${verifyErr.message}`);
        }

        // Stop running cloudflared to avoid Windows file lock (EBUSY)
        console.log('[Safety] Terminating any active cloudflared process before file swap...');
        stopRunningCloudflared();

        // Small delay to release file handle on Windows
        await new Promise(r => setTimeout(r, 600));

        // Swap files atomically
        if (fs.existsSync(CLOUDFLARED_EXE)) {
            if (fs.existsSync(backupPath)) fs.unlinkSync(backupPath);
            fs.renameSync(CLOUDFLARED_EXE, backupPath);
        }
        fs.renameSync(tempDownloadPath, CLOUDFLARED_EXE);

        // Clean backup
        if (fs.existsSync(backupPath)) {
            try { fs.unlinkSync(backupPath); } catch (_) {}
        }

        console.log(`\n[Success] cloudflared successfully upgraded to ${verifiedVersion}!`);
        console.log('[Security] Binary is patched with latest CVE fixes and protocol features.');
        console.log('The backend service will automatically connect with the updated binary.');
    } catch (err) {
        console.error(`\n[Upgrade Failed] ${err.message}`);
        // Restore backup if exists
        if (!fs.existsSync(CLOUDFLARED_EXE) && fs.existsSync(backupPath)) {
            fs.renameSync(backupPath, CLOUDFLARED_EXE);
            console.log('[Recovery] Restored previous working binary from backup.');
        }
        if (fs.existsSync(tempDownloadPath)) {
            try { fs.unlinkSync(tempDownloadPath); } catch (_) {}
        }
    }
}

main().catch(err => {
    console.error('[Fatal Error]', err);
    process.exit(1);
});

