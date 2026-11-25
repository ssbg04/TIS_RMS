const { execSync } = require('child_process');
const fs = require('fs');

const candidates = [
    'C:\\Program Files\\Microsoft Office\\Office16\\OSPP.VBS',
    'C:\\Program Files (x86)\\Microsoft Office\\Office16\\OSPP.VBS'
];

for (const c of candidates) {
    if (fs.existsSync(c)) {
        console.log('Found OSPP.VBS at:', c);
        try {
            const out = execSync(`cscript //Nologo "${c}" /dstatus`, { encoding: 'utf8' });
            console.log(out);
        } catch (e) {
            console.log(e.stdout || e.message);
        }
        break;
    }
}
