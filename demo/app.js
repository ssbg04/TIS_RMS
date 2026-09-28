/**
 * TIS-RMS Interactive Prototype Showcase
 * Drives real screen switching between actual screenshots and interactive dialogs.
 */

const SCREENS = [
  { id: 'dashboard', name: 'Dashboard', icon: '📊' },
  { id: 'students',  name: 'Students',  icon: '👥' },
  { id: 'documents', name: 'Documents', icon: '📁' },
  { id: 'archives',  name: 'Archives',  icon: '📦' },
  { id: 'reports',   name: 'Reports',   icon: '📈' },
  { id: 'users',     name: 'Users',     icon: '👤' },
  { id: 'history',   name: 'History',   icon: '🕒' },
  { id: 'settings',  name: 'Settings',  icon: '⚙️' },
];

let currentDevice = 'windows'; // 'windows' | 'android'
let currentScreen = 'dashboard';

document.addEventListener('DOMContentLoaded', () => {
  setupDeviceSwitcher();
  setupScreenPills();
  setupKeyboardNavigation();
  updateView();
});

// ── Device Switcher ───────────────────────────────────────────
function setupDeviceSwitcher() {
  const winBtn = document.getElementById('btn-view-windows');
  const androidBtn = document.getElementById('btn-view-android');

  winBtn.addEventListener('click', () => {
    currentDevice = 'windows';
    winBtn.classList.add('active');
    androidBtn.classList.remove('active');
    document.getElementById('desktop-window').style.display = 'flex';
    document.getElementById('phone-mockup').style.display = 'none';
    updateView();
  });

  androidBtn.addEventListener('click', () => {
    currentDevice = 'android';
    androidBtn.classList.add('active');
    winBtn.classList.remove('active');
    document.getElementById('desktop-window').style.display = 'none';
    document.getElementById('phone-mockup').style.display = 'flex';
    updateView();
  });
}

// ── Screen Selector Pills ─────────────────────────────────────
function setupScreenPills() {
  const bar = document.getElementById('screen-selector-bar');
  if (!bar) return;

  bar.innerHTML = SCREENS.map(s => `
    <button class="screen-pill ${s.id === currentScreen ? 'active' : ''}" data-screen="${s.id}" onclick="setScreen('${s.id}')">
      <span>${s.icon}</span>
      <span>${s.name}</span>
    </button>
  `).join('');
}

function setScreen(screenId) {
  currentScreen = screenId;
  updateView();
}

function updateView() {
  // Update screen pills
  document.querySelectorAll('.screen-pill').forEach(pill => {
    pill.classList.toggle('active', pill.getAttribute('data-screen') === currentScreen);
  });

  // Windows Desktop Image
  const winImg = document.getElementById('win-screen-img');
  if (winImg) {
    winImg.style.opacity = '0';
    setTimeout(() => {
      winImg.src = `screenshots/windows/${currentScreen}.webp`;
      winImg.style.opacity = '1';
    }, 120);
  }

  // Android Mobile Image
  const phoneImg = document.getElementById('phone-screen-img');
  if (phoneImg) {
    phoneImg.style.opacity = '0';
    setTimeout(() => {
      phoneImg.src = `screenshots/android/${currentScreen}.webp`;
      phoneImg.style.opacity = '1';
    }, 120);
  }

  // Update Dynamic Hotspots
  updateHotspots();
}

// ── Dynamic Hotspots ──────────────────────────────────────────
function updateHotspots() {
  const addStudentHotspot = document.getElementById('hotspot-add-student');
  const settingsUpdateHotspot = document.getElementById('hotspot-settings-update');

  if (addStudentHotspot) {
    addStudentHotspot.style.display = currentScreen === 'students' ? 'block' : 'none';
  }

  if (settingsUpdateHotspot) {
    settingsUpdateHotspot.style.display = currentScreen === 'settings' ? 'block' : 'none';
  }
}

// ── Keyboard Shortcuts (1-8 and Left/Right Arrows) ────────────
function setupKeyboardNavigation() {
  document.addEventListener('keydown', (e) => {
    // 1-8 keys
    const num = parseInt(e.key);
    if (!isNaN(num) && num >= 1 && num <= SCREENS.length) {
      setScreen(SCREENS[num - 1].id);
      return;
    }

    // Arrow keys
    const currentIndex = SCREENS.findIndex(s => s.id === currentScreen);
    if (e.key === 'ArrowRight') {
      const nextIndex = (currentIndex + 1) % SCREENS.length;
      setScreen(SCREENS[nextIndex].id);
    } else if (e.key === 'ArrowLeft') {
      const prevIndex = (currentIndex - 1 + SCREENS.length) % SCREENS.length;
      setScreen(SCREENS[prevIndex].id);
    }
  });
}

// ── Interactive Modals ─────────────────────────────────────────
function openAddStudentModal() {
  const modal = document.getElementById('add-student-modal');
  if (modal) modal.classList.add('active');
}

function openUpdateCheckModal() {
  const modal = document.getElementById('update-modal');
  if (modal) {
    modal.classList.add('active');
    simulateUpdateProcess();
  }
}

function closeModal(id) {
  const modal = document.getElementById(id);
  if (modal) modal.classList.remove('active');
}

// ── Simulated Update Check Workflow ────────────────────────────
function simulateUpdateProcess() {
  const statusEl = document.getElementById('update-modal-status');
  const actionBtn = document.getElementById('btn-download-action');
  const toast = document.getElementById('browser-download-toast');
  const toastFile = document.getElementById('toast-filename');

  const isWin = currentDevice === 'windows';
  const arch = isWin ? 'x64 (64-bit)' : 'ARM64 (64-bit)';
  const file = isWin ? 'TIS_RMS_Setup_v1.0.24.exe' : 'TIS_RMS_64_v1.0.24.apk';

  statusEl.innerHTML = `
    <div style="display: flex; align-items: center; gap: 10px; color: var(--accent-emerald);">
      <div style="width: 16px; height: 16px; border: 2px solid var(--accent-emerald); border-top-color: transparent; border-radius: 50%; animation: spin 0.8s linear infinite;"></div>
      <span>Querying GitHub releases for ${arch}...</span>
    </div>
  `;
  actionBtn.style.display = 'none';

  setTimeout(() => {
    statusEl.innerHTML = `
      <div style="background: rgba(25, 135, 84, 0.15); border: 1px solid rgba(25, 135, 84, 0.35); padding: 12px; border-radius: 8px;">
        <div style="font-weight: 700; color: var(--accent-emerald); margin-bottom: 4px;">
          ✓ Update Detected: v1.0.24
        </div>
        <div style="font-size: 12px; color: #cbd5e1; line-height: 1.5;">
          Architecture: <strong>${arch}</strong><br/>
          Matched Asset: <strong>${file}</strong><br/>
          Opening direct link in default device browser...
        </div>
      </div>
    `;

    actionBtn.style.display = 'inline-flex';
    actionBtn.onclick = () => {
      closeModal('update-modal');
      triggerDownloadToast(file);
    };

    triggerDownloadToast(file);
  }, 1400);
}

function triggerDownloadToast(filename) {
  const toast = document.getElementById('browser-download-toast');
  const toastFile = document.getElementById('toast-filename');
  if (toast && toastFile) {
    toastFile.textContent = filename;
    toast.classList.add('active');
    setTimeout(() => {
      toast.classList.remove('active');
    }, 5000);
  }
}
