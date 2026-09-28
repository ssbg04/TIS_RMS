/**
 * TIS-RMS Interactive Prototype Logic
 * Powers navigation, device switching, mock data filtering, and simulated workflows.
 */

// ── Mock Data ───────────────────────────────────────────────────
const MOCK_STUDENTS = [
  { id: 1, lrn: '109876543210', name: 'DELA CRUZ, Juan Santos', grade: 'Grade 10', section: 'Jacinto', sex: 'Male', status: 'Enrolled', age: 16, contact: '0917-123-4567', docs: 4 },
  { id: 2, lrn: '109876543211', name: 'SANTOS, Maria Clara Perez', grade: 'Grade 9', section: 'Silang', sex: 'Female', status: 'Enrolled', age: 15, contact: '0918-234-5678', docs: 5 },
  { id: 3, lrn: '109876543212', name: 'ALVAREZ, Gabriel Mendoza', grade: 'Grade 7', section: 'Rizal', sex: 'Male', status: 'Enrolled', age: 13, contact: '0919-345-6789', docs: 3 },
  { id: 4, lrn: '109876543213', name: 'BAUTISTA, Chloe Anne Flores', grade: 'Grade 8', section: 'Aguinaldo', sex: 'Female', status: 'Enrolled', age: 14, contact: '0920-456-7890', docs: 4 },
  { id: 5, lrn: '109876543214', name: 'RAMIREZ, Christian Paul Torres', grade: 'Grade 11', section: 'TVL-ICT', sex: 'Male', status: 'Enrolled', age: 17, contact: '0921-567-8901', docs: 5 },
  { id: 6, lrn: '109876543215', name: 'VILLANUEVA, Princess Diane Gomez', grade: 'Grade 12', section: 'STEM A', sex: 'Female', status: 'Enrolled', age: 18, contact: '0922-678-9012', docs: 5 },
  { id: 7, lrn: '109876543216', name: 'CASTILLO, Joshua Mark Reyes', grade: 'Grade 10', section: 'Tandang Sora', sex: 'Male', status: 'Enrolled', age: 16, contact: '0923-789-0123', docs: 4 },
  { id: 8, lrn: '109876543217', name: 'MERCADO, Angel Mae Lim', grade: 'Grade 7', section: 'Bonifacio', sex: 'Female', status: 'Enrolled', age: 13, contact: '0924-890-1234', docs: 3 },
];

const MOCK_DOCS = [
  { name: 'PSA / NSO Birth Certificate', code: 'DOC-PSA', required: true, status: 'Verified', count: 1420 },
  { name: 'SF10 / Form 137 (Permanent Record)', code: 'DOC-SF10', required: true, status: 'Verified', count: 1388 },
  { name: 'SF9 / Form 138 (Report Card)', code: 'DOC-SF9', required: true, status: 'Verified', count: 1405 },
  { name: 'Certificate of Good Moral Character', code: 'DOC-GMC', required: false, status: 'Complete', count: 1290 },
  { name: '2x2 Recent ID Photo', code: 'DOC-PHOTO', required: true, status: 'Verified', count: 1482 },
];

const MOCK_CLASSES = [
  { grade: 'Grade 7', section: 'Rizal', adviser: 'Ms. Carmela Diaz', students: 46, max: 50 },
  { grade: 'Grade 7', section: 'Bonifacio', adviser: 'Mr. Eduardo Ramos', students: 48, max: 50 },
  { grade: 'Grade 8', section: 'Aguinaldo', adviser: 'Mrs. Leah Manalo', students: 45, max: 50 },
  { grade: 'Grade 8', section: 'Luna', adviser: 'Mr. Kenneth Ortiz', students: 47, max: 50 },
  { grade: 'Grade 9', section: 'Silang', adviser: 'Ms. Joanne Beltran', students: 44, max: 50 },
  { grade: 'Grade 10', section: 'Jacinto', adviser: 'Mr. Roderick Tan', students: 49, max: 50 },
  { grade: 'Grade 11', section: 'TVL-ICT', adviser: 'Engr. Mark Soriano', students: 42, max: 45 },
  { grade: 'Grade 12', section: 'STEM A', adviser: 'Dr. Evelyn Cruz', students: 40, max: 45 },
];

// ── Application State ──────────────────────────────────────────
let currentDevice = 'windows';
let currentScreen = 'dashboard';
let currentTheme = 'light';
let studentFilter = 'all';
let searchQuery = '';

// ── Initialization ─────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  setupDeviceSwitcher();
  setupThemeToggle();
  setupNavigation();
  renderStudentsTable();
  renderMobileStudentsList();
  renderDocsList();
  renderClassesList();
  startClock();
});

// ── Device Switcher ────────────────────────────────────────────
function setupDeviceSwitcher() {
  const winBtn = document.getElementById('btn-view-windows');
  const androidBtn = document.getElementById('btn-view-android');
  const winFrame = document.getElementById('desktop-frame');
  const phoneFrame = document.getElementById('phone-frame');

  winBtn.addEventListener('click', () => {
    currentDevice = 'windows';
    winBtn.classList.add('active');
    androidBtn.classList.remove('active');
    winFrame.style.display = 'flex';
    phoneFrame.style.display = 'none';
    syncScreens();
  });

  androidBtn.addEventListener('click', () => {
    currentDevice = 'android';
    androidBtn.classList.add('active');
    winBtn.classList.remove('active');
    winFrame.style.display = 'none';
    phoneFrame.style.display = 'flex';
    syncScreens();
  });
}

// ── Theme Toggle ───────────────────────────────────────────────
function setupThemeToggle() {
  const toggleBtn = document.getElementById('theme-toggle-btn');
  toggleBtn.addEventListener('click', () => {
    currentTheme = currentTheme === 'light' ? 'dark' : 'light';
    document.documentElement.setAttribute('data-theme', currentTheme);
    toggleBtn.innerHTML = currentTheme === 'light' 
      ? `<svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path></svg>`
      : `<svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line></svg>`;
  });
}

// ── Navigation ─────────────────────────────────────────────────
function setupNavigation() {
  // Desktop sidebar clicks
  document.querySelectorAll('.win-nav-item').forEach(item => {
    item.addEventListener('click', () => {
      const target = item.getAttribute('data-screen');
      if (target) navigateTo(target);
    });
  });

  // Mobile bottom nav clicks
  document.querySelectorAll('.bottom-nav-item').forEach(item => {
    item.addEventListener('click', () => {
      const target = item.getAttribute('data-screen');
      if (target) navigateTo(target);
    });
  });
}

function navigateTo(screenId) {
  currentScreen = screenId;
  syncScreens();
}

function syncScreens() {
  // Update desktop sidebar active class
  document.querySelectorAll('.win-nav-item').forEach(el => {
    el.classList.toggle('active', el.getAttribute('data-screen') === currentScreen);
  });

  // Update mobile bottom nav active class
  document.querySelectorAll('.bottom-nav-item').forEach(el => {
    el.classList.toggle('active', el.getAttribute('data-screen') === currentScreen);
  });

  // Update desktop content views
  document.querySelectorAll('.win-screen-view').forEach(view => {
    view.style.display = view.id === `win-${currentScreen}` ? 'block' : 'none';
  });

  // Update mobile content views
  document.querySelectorAll('.phone-screen-view').forEach(view => {
    view.style.display = view.id === `phone-${currentScreen}` ? 'block' : 'none';
  });

  // Update breadcrumb titles
  const titles = {
    dashboard: 'Dashboard Overview',
    students: 'Students Directory',
    documents: 'Document Requirements',
    academic: 'Classes & Academic Structure',
    settings: 'System Settings & About'
  };

  const winTitle = document.getElementById('win-breadcrumb-title');
  if (winTitle) winTitle.textContent = titles[currentScreen] || 'Dashboard';

  const phoneTitle = document.getElementById('phone-header-title');
  if (phoneTitle) phoneTitle.textContent = titles[currentScreen] || 'TIS-RMS';
}

// ── Students Table & Card Rendering ────────────────────────────
function renderStudentsTable() {
  const tbody = document.getElementById('students-table-body');
  if (!tbody) return;

  const filtered = filterStudentData();
  tbody.innerHTML = '';

  if (filtered.length === 0) {
    tbody.innerHTML = `<tr><td colspan="7" style="text-align: center; padding: 32px; color: var(--win-text-muted);">No student records matched your search query.</td></tr>`;
    return;
  }

  filtered.forEach(student => {
    const tr = document.createElement('tr');
    tr.className = 'student-row-click';
    tr.innerHTML = `
      <td style="font-weight: 600;">${student.name}</td>
      <td style="font-family: monospace; color: var(--win-text-muted);">${student.lrn}</td>
      <td>${student.grade}</td>
      <td>${student.section}</td>
      <td>${student.sex}</td>
      <td><span class="status-badge badge-enrolled">${student.status}</span></td>
      <td>
        <button class="btn-secondary" style="height: 28px; padding: 0 10px; font-size: 11px;" onclick="openStudentModal(${student.id})">
          View Details
        </button>
      </td>
    `;
    tr.addEventListener('click', (e) => {
      if (e.target.tagName !== 'BUTTON') openStudentModal(student.id);
    });
    tbody.appendChild(tr);
  });
}

function renderMobileStudentsList() {
  const container = document.getElementById('mobile-students-container');
  if (!container) return;

  const filtered = filterStudentData();
  container.innerHTML = '';

  if (filtered.length === 0) {
    container.innerHTML = `<div style="text-align:center; padding: 30px; color: var(--win-text-muted); font-size: 13px;">No student records found.</div>`;
    return;
  }

  filtered.forEach(student => {
    const card = document.createElement('div');
    card.className = 'mobile-student-card';
    card.innerHTML = `
      <div class="m-student-header">
        <span class="m-student-name">${student.name}</span>
        <span class="status-badge badge-enrolled">${student.status}</span>
      </div>
      <div class="m-student-lrn">LRN: ${student.lrn}</div>
      <div class="m-student-footer">
        <span>${student.grade} - ${student.section}</span>
        <span style="color: var(--primary-green); font-weight: 600;">Details &rsaquo;</span>
      </div>
    `;
    card.addEventListener('click', () => openStudentModal(student.id));
    container.appendChild(card);
  });
}

function filterStudentData() {
  return MOCK_STUDENTS.filter(s => {
    const matchesSearch = s.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                          s.lrn.includes(searchQuery) ||
                          s.section.toLowerCase().includes(searchQuery.toLowerCase());
    
    if (studentFilter === 'all') return matchesSearch;
    if (studentFilter === 'male') return matchesSearch && s.sex === 'Male';
    if (studentFilter === 'female') return matchesSearch && s.sex === 'Female';
    return matchesSearch && s.grade.toLowerCase().includes(studentFilter.toLowerCase());
  });
}

function setStudentFilter(filterVal, element) {
  studentFilter = filterVal;
  document.querySelectorAll('.filter-chips .chip').forEach(c => c.classList.remove('active'));
  if (element) element.classList.add('active');
  renderStudentsTable();
  renderMobileStudentsList();
}

function onSearchInput(query) {
  searchQuery = query;
  renderStudentsTable();
  renderMobileStudentsList();
}

// ── Documents Screen ───────────────────────────────────────────
function renderDocsList() {
  const winContainer = document.getElementById('docs-grid-windows');
  const phoneContainer = document.getElementById('docs-list-phone');

  if (winContainer) {
    winContainer.innerHTML = MOCK_DOCS.map(doc => `
      <div class="content-card" style="display: flex; justify-content: space-between; align-items: center;">
        <div>
          <div style="font-weight: 700; font-size: 14px; margin-bottom: 2px;">${doc.name}</div>
          <div style="font-size: 12px; color: var(--win-text-muted);">${doc.code} &bull; ${doc.count} Verified Records</div>
        </div>
        <div style="display: flex; align-items: center; gap: 12px;">
          <span class="status-badge badge-complete">${doc.status}</span>
          <button class="btn-secondary" style="height: 32px; padding: 0 12px;" onclick="openDocPreviewModal('${doc.name}', '${doc.code}')">Preview Scan</button>
        </div>
      </div>
    `).join('');
  }

  if (phoneContainer) {
    phoneContainer.innerHTML = MOCK_DOCS.map(doc => `
      <div class="mobile-student-card" onclick="openDocPreviewModal('${doc.name}', '${doc.code}')">
        <div class="m-student-header">
          <span class="m-student-name" style="font-size: 13px;">${doc.name}</span>
          <span class="status-badge badge-complete">${doc.status}</span>
        </div>
        <div class="m-student-footer" style="margin-top: 6px;">
          <span>${doc.count} submissions</span>
          <span style="color: var(--primary-green); font-weight: 600;">View &rsaquo;</span>
        </div>
      </div>
    `).join('');
  }
}

// ── Academic Screen ────────────────────────────────────────────
function renderClassesList() {
  const winContainer = document.getElementById('classes-grid-windows');
  const phoneContainer = document.getElementById('classes-list-phone');

  const html = MOCK_CLASSES.map(cls => `
    <div class="content-card">
      <div class="card-header" style="margin-bottom: 8px;">
        <span style="font-size: 12px; font-weight: 700; color: var(--primary-green); text-transform: uppercase;">${cls.grade}</span>
        <span style="font-size: 11px; font-weight: 600; color: var(--win-text-muted);">${cls.students}/${cls.max} Students</span>
      </div>
      <div style="font-size: 16px; font-weight: 700; color: var(--win-text); margin-bottom: 4px;">Section ${cls.section}</div>
      <div style="font-size: 12px; color: var(--win-text-muted); margin-bottom: 12px;">Adviser: ${cls.adviser}</div>
      <div class="bar-track" style="height: 6px;">
        <div class="bar-fill" style="width: ${(cls.students / cls.max) * 100}%;"></div>
      </div>
    </div>
  `).join('');

  if (winContainer) winContainer.innerHTML = html;
  if (phoneContainer) phoneContainer.innerHTML = html;
}

// ── Student Detail Modal ───────────────────────────────────────
function openStudentModal(id) {
  const student = MOCK_STUDENTS.find(s => s.id === id);
  if (!student) return;

  const modal = document.getElementById('student-modal');
  const body = document.getElementById('student-modal-body');

  body.innerHTML = `
    <div style="display: flex; align-items: center; gap: 14px; padding-bottom: 12px; border-bottom: 1px solid var(--win-border);">
      <div style="width: 52px; height: 52px; border-radius: 50%; background: var(--primary-green); color: #fff; display: flex; align-items: center; justify-content: center; font-size: 20px; font-weight: 700;">
        ${student.name.charAt(0)}
      </div>
      <div>
        <h4 style="font-size: 16px; font-weight: 700;">${student.name}</h4>
        <span style="font-size: 12px; color: var(--win-text-muted);">LRN: ${student.lrn} &bull; ${student.grade} - ${student.section}</span>
      </div>
    </div>
    
    <div class="info-row"><span class="info-label">Gender:</span><span class="info-val">${student.sex}</span></div>
    <div class="info-row"><span class="info-label">Age:</span><span class="info-val">${student.age} years old</span></div>
    <div class="info-row"><span class="info-label">Enrollment Status:</span><span class="info-val"><span class="status-badge badge-enrolled">${student.status}</span></span></div>
    <div class="info-row"><span class="info-label">Parent / Guardian Contact:</span><span class="info-val">${student.contact}</span></div>
    <div class="info-row"><span class="info-label">School:</span><span class="info-val">Talipan National High School</span></div>
    
    <div style="margin-top: 10px;">
      <h5 style="font-size: 13px; font-weight: 700; margin-bottom: 8px;">Submitted Document Requirements</h5>
      <div style="display: flex; flex-direction: column; gap: 6px;">
        <div style="display: flex; justify-content: space-between; font-size: 12px; padding: 6px 10px; background: var(--win-surface-subtle); border-radius: 6px;">
          <span>PSA Birth Certificate</span>
          <span style="color: var(--primary-green); font-weight: 600;">✓ Verified</span>
        </div>
        <div style="display: flex; justify-content: space-between; font-size: 12px; padding: 6px 10px; background: var(--win-surface-subtle); border-radius: 6px;">
          <span>Form 137 / SF10</span>
          <span style="color: var(--primary-green); font-weight: 600;">✓ Verified</span>
        </div>
        <div style="display: flex; justify-content: space-between; font-size: 12px; padding: 6px 10px; background: var(--win-surface-subtle); border-radius: 6px;">
          <span>Form 138 / SF9</span>
          <span style="color: var(--primary-green); font-weight: 600;">✓ Verified</span>
        </div>
      </div>
    </div>
  `;

  modal.classList.add('active');
}

function openDocPreviewModal(name, code) {
  const modal = document.getElementById('doc-preview-modal');
  const title = document.getElementById('doc-preview-title');
  const codeEl = document.getElementById('doc-preview-code');

  if (title) title.textContent = name;
  if (codeEl) codeEl.textContent = code;

  modal.classList.add('active');
}

function openAddStudentModal() {
  const modal = document.getElementById('add-student-modal');
  modal.classList.add('active');
}

function closeModal(id) {
  const modal = document.getElementById(id);
  if (modal) modal.classList.remove('active');
}

// ── Settings Collapsible Sections ──────────────────────────────
function toggleSettingsSection(id) {
  const body = document.getElementById(`settings-body-${id}`);
  const arrow = document.getElementById(`settings-arrow-${id}`);
  if (!body) return;

  const isVisible = body.style.display !== 'none';
  body.style.display = isVisible ? 'none' : 'flex';
  if (arrow) {
    arrow.style.transform = isVisible ? 'rotate(0deg)' : 'rotate(180deg)';
  }
}

// ── Check For Updates Simulation ───────────────────────────────
function simulateUpdateCheck() {
  const btn = document.getElementById('btn-check-update');
  const btnText = document.getElementById('btn-check-update-text');
  const statusBanner = document.getElementById('update-status-banner');
  const toast = document.getElementById('browser-download-toast');
  const toastText = document.getElementById('toast-filename');

  if (!btn) return;

  btn.disabled = true;
  btnText.textContent = 'Checking GitHub releases...';
  statusBanner.style.display = 'none';

  setTimeout(() => {
    btn.disabled = false;
    btnText.textContent = 'Check for Updates';

    // Architecture-matched file simulation
    const isWin = currentDevice === 'windows';
    const filename = isWin ? 'TIS_RMS_Setup_v1.0.24.exe' : 'TIS_RMS_64_v1.0.24.apk';
    const archLabel = isWin ? 'x64 (64-bit)' : 'ARM64 (64-bit)';

    statusBanner.style.display = 'block';
    statusBanner.innerHTML = `
      <div style="display: flex; align-items: center; gap: 8px; font-weight: 600; color: var(--primary-green); margin-bottom: 4px;">
        <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
        New Version Detected: v1.0.24 for ${archLabel}
      </div>
      <div style="font-size: 12px; color: var(--win-text);">
        Architecture matched: <strong>${filename}</strong>.<br/>
        Simulating launching download in device's default browser...
      </div>
    `;

    // Show simulated default browser toast
    if (toast && toastText) {
      toastText.textContent = filename;
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
    const el = document.getElementById('phone-time');
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
