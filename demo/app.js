/**
 * TIS-RMS Static Web Application Logic
 * Interactive UI behavior for Windows and Android layouts
 */

let currentDevice = 'windows'; // 'windows' | 'android'
let currentScreen = 'dashboard';

// ── Screen Definitions ─────────────────────────────────────────
const SCREENS = [
  { id: 'dashboard', label: 'Dashboard', icon: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z"/></svg>' },
  { id: 'students',  label: 'Students',  icon: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/></svg>' },
  { id: 'documents', label: 'Documents', icon: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z"/></svg>' },
  { id: 'archives',  label: 'Archives',  icon: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M20.54 5.23l-1.39-1.68C18.88 3.21 18.47 3 18 3H6c-.47 0-.88.21-1.16.55L3.46 5.23C3.17 5.57 3 6.02 3 6.5V19c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V6.5c0-.48-.17-.93-.46-1.27zM12 17.5L6.5 12H10v-2h4v2h3.5L12 17.5zM5.12 5l.81-1h12l.94 1H5.12z"/></svg>' },
  { id: 'reports',   label: 'Reports',   icon: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M5 9.2h3V19H5zM10.6 5h2.8v14h-2.8zm5.6 8H19v6h-2.8z"/><path d="M19 19H5V5h14v14m0-16H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"/></svg>' },
  { id: 'users',     label: 'Users',     icon: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>' },
  { id: 'history',   label: 'History',   icon: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M13 3a9 9 0 0 0-9 9H1l3.89 3.89.07.14L9 12H6c0-3.87 3.13-7 7-7s7 3.13 7 7-3.13 7-7 7c-1.93 0-3.68-.79-4.94-2.06l-1.42 1.42A8.954 8.954 0 0 0 13 21a9 9 0 0 0 0-18zm-1 5v5l4.28 2.54.72-1.21-3.5-2.08V8H12z"/></svg>' },
  { id: 'settings',  label: 'Settings',  icon: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z"/></svg>' },
];

document.addEventListener('DOMContentLoaded', () => {
  setupDeviceSwitcher();
  setupNavigation();
  startClock();
  setScreen('dashboard');
});

// ── Device Switcher ────────────────────────────────────────────
function setupDeviceSwitcher() {
  const winBtn = document.getElementById('btn-view-windows');
  const androidBtn = document.getElementById('btn-view-android');
  const winWindow = document.getElementById('desktop-window');
  const phoneMockup = document.getElementById('phone-frame');

  winBtn.addEventListener('click', () => {
    currentDevice = 'windows';
    winBtn.classList.add('active');
    androidBtn.classList.remove('active');
    winWindow.style.display = 'flex';
    phoneMockup.style.display = 'none';
    syncScreenView();
  });

  androidBtn.addEventListener('click', () => {
    currentDevice = 'android';
    androidBtn.classList.add('active');
    winBtn.classList.remove('active');
    winWindow.style.display = 'none';
    phoneMockup.style.display = 'flex';
    syncScreenView();
  });
}

// ── Navigation ─────────────────────────────────────────────────
function setupNavigation() {
  // Desktop Sidebar
  document.querySelectorAll('.win-nav-item').forEach(item => {
    item.addEventListener('click', () => {
      const scr = item.getAttribute('data-screen');
      if (scr) setScreen(scr);
    });
  });

  // Mobile Bottom Nav
  document.querySelectorAll('.phone-nav-tab').forEach(item => {
    item.addEventListener('click', () => {
      const scr = item.getAttribute('data-screen');
      if (scr) setScreen(scr);
    });
  });
}

function setScreen(screenId) {
  currentScreen = screenId;
  syncScreenView();
}

function syncScreenView() {
  // 1. Update active sidebar item on Windows
  document.querySelectorAll('.win-nav-item').forEach(el => {
    el.classList.toggle('active', el.getAttribute('data-screen') === currentScreen);
  });

  // 2. Update active bottom nav on Android
  document.querySelectorAll('.phone-nav-tab').forEach(el => {
    el.classList.toggle('active', el.getAttribute('data-screen') === currentScreen);
  });

  // 3. Update titles
  const titles = {
    dashboard: 'Dashboard Overview',
    students: 'Students Directory',
    documents: 'Document Folders',
    archives: 'Archived Records',
    reports: 'DepEd Transparency Board',
    users: 'User Management',
    history: 'System Audit Logs',
    settings: 'Account Settings'
  };

  const desktopTitle = document.getElementById('stage-screen-title');
  if (desktopTitle) desktopTitle.textContent = titles[currentScreen] || 'Dashboard Overview';

  const mobileTitle = document.getElementById('phone-screen-title');
  if (mobileTitle) mobileTitle.textContent = titles[currentScreen] || 'TIS RMS';

  // 4. Show/hide desktop screens
  document.querySelectorAll('.desktop-screen-content').forEach(view => {
    view.style.display = view.id === `win-screen-${currentScreen}` ? 'flex' : 'none';
  });

  // 5. Show/hide mobile screens
  document.querySelectorAll('.mobile-screen-content').forEach(view => {
    view.style.display = view.id === `phone-screen-${currentScreen}` ? 'flex' : 'none';
  });

  // 6. Show "+ Add Student" button on Students screen
  const addBtn = document.getElementById('btn-add-student-header');
  if (addBtn) {
    addBtn.style.display = currentScreen === 'students' ? 'flex' : 'none';
  }
}

// ── Collapsible Settings Sections ──────────────────────────────
function toggleSettingsSection(id) {
  const body = document.getElementById(`settings-body-${id}`);
  const chevron = document.getElementById(`settings-chevron-${id}`);
  if (!body) return;

  const isHidden = body.style.display === 'none' || body.style.display === '';
  body.style.display = isHidden ? 'flex' : 'none';
  if (chevron) {
    chevron.style.transform = isHidden ? 'rotate(180deg)' : 'rotate(0deg)';
  }
}

// ── Interactive Modals ─────────────────────────────────────────
function openAddStudentModal() {
  const modal = document.getElementById('add-student-modal');
  if (modal) modal.classList.add('active');
}

function openStudentDetail(name, lrn, grade, status) {
  const modal = document.getElementById('student-detail-modal');
  const title = document.getElementById('detail-student-name');
  const lrnEl = document.getElementById('detail-student-lrn');
  const gradeEl = document.getElementById('detail-student-grade');
  const statusEl = document.getElementById('detail-student-status');

  if (title) title.textContent = name;
  if (lrnEl) lrnEl.textContent = lrn;
  if (gradeEl) gradeEl.textContent = grade;
  if (statusEl) statusEl.textContent = status;

  if (modal) modal.classList.add('active');
}

function closeModal(id) {
  const modal = document.getElementById(id);
  if (modal) modal.classList.remove('active');
}

// ── Check For Updates Simulation (Real feature test) ───────────
function simulateUpdateCheck() {
  const btn = document.getElementById('btn-check-updates');
  const banner = document.getElementById('update-result-banner');
  const toast = document.getElementById('download-toast');
  const toastFile = document.getElementById('toast-filename');

  if (!btn) return;
  btn.disabled = true;
  btn.innerHTML = '<span>Checking for updates...</span>';
  banner.style.display = 'none';

  setTimeout(() => {
    btn.disabled = false;
    btn.innerHTML = '<span>Check for Updates</span>';

    const isWin = currentDevice === 'windows';
    const arch = isWin ? 'x64 (64-bit)' : 'ARM64 (64-bit)';
    const file = isWin ? 'TIS_RMS_Setup_v1.0.24.exe' : 'TIS_RMS_64_v1.0.24.apk';

    banner.style.display = 'block';
    banner.innerHTML = `
      <div style="font-weight: 700; color: var(--accent-emerald); margin-bottom: 4px;">
        ✓ New Update Available: v1.0.24
      </div>
      <div style="font-size: 12px; color: #cbd5e1; line-height: 1.4;">
        Detected architecture: <strong>${arch}</strong><br/>
        Matched package: <strong>${file}</strong><br/>
        Launching download link in default browser...
      </div>
    `;

    if (toast && toastFile) {
      toastFile.textContent = file;
      toast.classList.add('active');
      setTimeout(() => {
        toast.classList.remove('active');
      }, 5000);
    }
  }, 1200);
}

// ── Clock for Android Status Bar ───────────────────────────────
function startClock() {
  function updateTime() {
    const el = document.getElementById('phone-clock');
    if (!el) return;
    const now = new Date();
    let hours = now.getHours();
    let mins = now.getMinutes();
    mins = mins < 10 ? '0' + mins : mins;
    el.textContent = `${hours}:${mins}`;
  }
  updateTime();
  setInterval(updateTime, 30000);
}
