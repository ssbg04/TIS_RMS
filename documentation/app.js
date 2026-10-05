/**
 * TIS-RMS DOCUMENTATION INTERACTIVE CONTROLLER
 * Handles:
 * 1. Eye-Friendly Dark/Light Theme Switching with LocalStorage
 * 2. Dedicated Print Action
 * 3. Windows / Android Platform Filter with Persistent State
 * 4. Multi-Page Live Search with Keyboard Navigation (Arrows + Enter)
 * 5. Mockup Platform Tab Switching
 * 6. Responsive Mobile & Landscape Sidebar Navigation
 * 7. Image Lightbox Zoom Modal
 * 8. FAQ Accordion Interaction
 */

document.addEventListener('DOMContentLoaded', () => {

  // ==========================================
  // 1. THEME TOGGLE (EYE-FRIENDLY SLATE DARK / CLEAN LIGHT)
  // ==========================================
  const themeToggleBtn = document.getElementById('themeToggleBtn');
  const savedTheme = localStorage.getItem('tis_doc_theme') || 
    (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
  
  document.documentElement.setAttribute('data-theme', savedTheme);
  updateThemeButton(savedTheme);

  function updateThemeButton(theme) {
    if (!themeToggleBtn) return;
    const isDark = theme === 'dark';
    themeToggleBtn.setAttribute('title', isDark ? 'Switch to light theme' : 'Switch to eye-friendly dark theme');
    themeToggleBtn.setAttribute('aria-label', isDark ? 'Switch to light theme' : 'Switch to eye-friendly dark theme');
  }

  if (themeToggleBtn) {
    themeToggleBtn.addEventListener('click', () => {
      const currentTheme = document.documentElement.getAttribute('data-theme');
      const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', newTheme);
      localStorage.setItem('tis_doc_theme', newTheme);
      updateThemeButton(newTheme);
    });
  }

  // ==========================================
  // 2. PRINT HANDLER
  // ==========================================
  const printBtn = document.getElementById('printBtn');
  if (printBtn) {
    printBtn.addEventListener('click', (e) => {
      e.preventDefault();
      window.print();
    });
  }

  // ==========================================
  // 3. GLOBAL PLATFORM FILTER (ALL / WINDOWS / ANDROID)
  // ==========================================
  const platformFilterBtns = document.querySelectorAll('.platform-pill-toggle .platform-btn');
  const savedPlatform = localStorage.getItem('tis_doc_platform') || 'all';

  function applyPlatformFilter(filter) {
    // 1. Update button states in header
    platformFilterBtns.forEach(btn => {
      const bFilter = btn.getAttribute('data-platform-filter');
      btn.classList.toggle('active', bFilter === filter);
    });

    // 2. Set root attribute for CSS styling
    document.documentElement.setAttribute('data-doc-platform', filter);

    // 3. Save to localStorage
    localStorage.setItem('tis_doc_platform', filter);

    // 4. Update mockup container tabs on the current page
    document.querySelectorAll('.mockup-container').forEach(container => {
      const winTabBtn = container.querySelector('[data-tab-target^="win-"]');
      const andTabBtn = container.querySelector('[data-tab-target^="and-"]');

      if (filter === 'windows' && winTabBtn) {
        winTabBtn.click();
      } else if (filter === 'android' && andTabBtn) {
        andTabBtn.click();
      } else if (filter === 'all' && winTabBtn) {
        winTabBtn.click();
      }
    });

    // 5. In shortcut tables or platform badges, adjust visual state
    document.querySelectorAll('.shortcut-group-windows, .shortcut-group-android').forEach(el => {
      if (filter === 'all') {
        el.style.opacity = '';
      } else if (filter === 'windows') {
        el.style.opacity = el.classList.contains('shortcut-group-windows') ? '1' : '0.35';
      } else if (filter === 'android') {
        el.style.opacity = el.classList.contains('shortcut-group-android') ? '1' : '0.35';
      }
    });
  }

  // Initialize platform filter from storage
  applyPlatformFilter(savedPlatform);

  // Attach click listener to platform pill buttons
  platformFilterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      const filter = btn.getAttribute('data-platform-filter');
      applyPlatformFilter(filter);
    });
  });

  // ==========================================
  // 4. MOCKUP TAB SWITCHING (IN-PAGE WINDOWS / ANDROID)
  // ==========================================
  document.querySelectorAll('.mockup-container').forEach(container => {
    const tabBtns = container.querySelectorAll('.mockup-tab-btn');
    const panes = container.querySelectorAll('.mockup-pane');

    tabBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        const targetId = btn.getAttribute('data-tab-target');

        tabBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        panes.forEach(pane => {
          if (pane.id === targetId) {
            pane.style.display = 'block';
            pane.classList.add('active');
          } else {
            pane.style.display = 'none';
            pane.classList.remove('active');
          }
        });
      });
    });
  });

  // ==========================================
  // 5. MOBILE NAVIGATION & SEARCH
  // ==========================================
  const mobileMenuBtn = document.getElementById('mobileMenuBtn');
  const docSidebar = document.getElementById('docSidebar');
  const sidebarBackdrop = document.getElementById('sidebarBackdrop');
  const mobileSearchBtn = document.getElementById('mobileSearchBtn');
  const headerSearchBox = document.getElementById('headerSearchBox');
  const docSearchInput = document.getElementById('docSearchInput');

  function openMobileSidebar() {
    if (docSidebar) docSidebar.classList.add('open');
    if (sidebarBackdrop) sidebarBackdrop.classList.add('active');
    if (mobileMenuBtn) {
      const ham = mobileMenuBtn.querySelector('.hamburger-icon');
      const close = mobileMenuBtn.querySelector('.close-icon');
      if (ham) ham.style.display = 'none';
      if (close) close.style.display = 'block';
    }
    document.body.style.overflow = 'hidden';
  }

  function closeMobileSidebar() {
    if (docSidebar) docSidebar.classList.remove('open');
    if (sidebarBackdrop) sidebarBackdrop.classList.remove('active');
    if (mobileMenuBtn) {
      const ham = mobileMenuBtn.querySelector('.hamburger-icon');
      const close = mobileMenuBtn.querySelector('.close-icon');
      if (ham) ham.style.display = 'block';
      if (close) close.style.display = 'none';
    }
    document.body.style.overflow = '';
  }

  if (mobileMenuBtn) {
    mobileMenuBtn.addEventListener('click', () => {
      const isOpen = docSidebar && docSidebar.classList.contains('open');
      if (isOpen) {
        closeMobileSidebar();
      } else {
        openMobileSidebar();
      }
    });
  }

  if (sidebarBackdrop) {
    sidebarBackdrop.addEventListener('click', closeMobileSidebar);
  }

  // Close mobile sidebar when clicking any navigation link
  document.querySelectorAll('.doc-sidebar .nav-link').forEach(link => {
    link.addEventListener('click', () => {
      if (window.innerWidth <= 1024) {
        closeMobileSidebar();
      }
    });
  });

  // Mobile search toggle button in header
  if (mobileSearchBtn && headerSearchBox) {
    mobileSearchBtn.addEventListener('click', () => {
      const isOpen = headerSearchBox.classList.toggle('mobile-open');
      if (isOpen && docSearchInput) {
        docSearchInput.focus();
      }
    });
  }

  // ==========================================
  // 6. FAQ ACCORDION HANDLER
  // ==========================================
  document.querySelectorAll('.faq-item').forEach(item => {
    const questionBtn = item.querySelector('.faq-question');
    if (questionBtn) {
      questionBtn.addEventListener('click', () => {
        const isActive = item.classList.contains('active');
        item.classList.toggle('active', !isActive);
      });
    }
  });

  // ==========================================
  // 7. LIGHTBOX ZOOM MODAL
  // ==========================================
  const lightboxModal = document.getElementById('lightboxModal');
  const lightboxImg = document.getElementById('lightboxImg');
  const lightboxCaption = document.getElementById('lightboxCaption');
  const lightboxCloseBtn = document.getElementById('lightboxCloseBtn');

  function openLightbox(src, caption) {
    if (!lightboxModal || !lightboxImg) return;
    lightboxImg.src = src;
    if (lightboxCaption) {
      lightboxCaption.textContent = caption || '';
    }
    lightboxModal.classList.add('active');
    document.body.style.overflow = 'hidden';
  }

  function closeLightbox() {
    if (!lightboxModal) return;
    lightboxModal.classList.remove('active');
    document.body.style.overflow = '';
  }

  document.querySelectorAll('[data-lightbox]').forEach(el => {
    el.addEventListener('click', () => {
      const src = el.getAttribute('data-lightbox');
      const caption = el.getAttribute('data-caption') || '';
      openLightbox(src, caption);
    });
  });

  if (lightboxCloseBtn) {
    lightboxCloseBtn.addEventListener('click', closeLightbox);
  }

  if (lightboxModal) {
    lightboxModal.addEventListener('click', (e) => {
      if (e.target === lightboxModal) {
        closeLightbox();
      }
    });
  }

  // ==========================================
  // 8. MULTI-PAGE LIVE SEARCH & QUICK NAVIGATION
  // ==========================================
  const searchInput = document.getElementById('docSearchInput');
  const searchableSections = document.querySelectorAll('.doc-section, .hero-banner');

  const DOC_PAGES = [
    { title: 'System Overview', url: 'index.html', desc: 'System overview, school background, key capabilities, and handbook introduction' },
    { title: 'Staff Roles & Access', url: 'roles.html', desc: 'Administrator vs. Teacher permissions, advisory scoping, and registration permissions' },
    { title: 'Sign In & Getting Started', url: 'login.html', desc: 'Login credentials, Android & Windows app access, remote tunnel, and OTP recovery' },
    { title: 'Module 1: Dashboard', url: 'dashboard.html', desc: 'Real-time metrics, role toolbars, visual charts, top students, and attention lists' },
    { title: 'Module 2: Students', url: 'students.html', desc: 'Learner profiles, dynamic filters, SF9/SF10 OCR autofill, bulk CSV import, multi-select' },
    { title: 'Module 3: Documents', url: 'documents.html', desc: 'Virtual student folders, Android camera scanner, collapsible checklist, file previews' },
    { title: 'Module 4: Archives', url: 'archives.html', desc: 'Historical learner archives, file restoration, and automatic inactive archiving' },
    { title: 'Module 5: Batch Print', url: 'batchprint.html', desc: 'Multi-document print queue, Excel-to-PDF conversion, and email pickup notifications' },
    { title: 'Module 6: Reports & Analytics', url: 'reports.html', desc: 'DepEd transparency board, compliance breakdown, storage analytics, Excel export' },
    { title: 'Module 7: User Accounts', url: 'users.html', desc: 'Staff account management, teacher assignments, activation, and password resets' },
    { title: 'Module 8: Activity History', url: 'history.html', desc: 'System activity logs, user lifecycle history, active sessions, and IP address audits' },
    { title: 'Module 9: School Settings', url: 'settings.html', desc: 'Academic setup, dynamic document checklists, automated reminders, and graduation' },
    { title: 'Keyboard Shortcuts', url: 'shortcuts.html', desc: 'Hotkeys and touch gestures for Windows desktop and Android tablets' },
    { title: 'Frequently Asked Questions', url: 'faq.html', desc: 'Common questions regarding offline mode, remote access, OCR, and backups' },
    { title: 'Help & Troubleshooting', url: 'troubleshooting.html', desc: 'Diagnostic steps for LAN connections, scanner troubleshooting, and sync' }
  ];

  let searchDropdown = document.getElementById('searchDropdown');
  if (!searchDropdown && headerSearchBox) {
    searchDropdown = document.createElement('div');
    searchDropdown.id = 'searchDropdown';
    searchDropdown.className = 'search-dropdown';
    headerSearchBox.appendChild(searchDropdown);
  }

  let selectedResultIndex = -1;

  function updateSelectedResult(items) {
    items.forEach((item, index) => {
      item.classList.toggle('selected', index === selectedResultIndex);
      if (index === selectedResultIndex) {
        item.scrollIntoView({ block: 'nearest' });
      }
    });
  }

  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      const query = e.target.value.trim().toLowerCase();
      selectedResultIndex = -1;

      // Current page element filtering
      if (!query) {
        if (searchDropdown) {
          searchDropdown.classList.remove('active');
          searchDropdown.innerHTML = '';
        }
        searchableSections.forEach(sec => {
          sec.style.display = '';
          sec.querySelectorAll('.feature-card, .step-card, tr, .component-screenshot, .mockup-container').forEach(item => {
            item.style.display = '';
          });
        });
        return;
      }

      searchableSections.forEach(sec => {
        const text = sec.textContent.toLowerCase();
        if (text.includes(query)) {
          sec.style.display = '';
          sec.querySelectorAll('.feature-card, .step-card').forEach(card => {
            const cardText = card.textContent.toLowerCase();
            card.style.display = cardText.includes(query) ? '' : 'none';
          });
        }
      });

      // Multi-page suggestion dropdown
      if (searchDropdown) {
        const matches = DOC_PAGES.filter(p =>
          p.title.toLowerCase().includes(query) ||
          p.desc.toLowerCase().includes(query)
        );

        if (matches.length > 0) {
          searchDropdown.innerHTML = matches.map((m, idx) => `
            <a href="${m.url}" class="search-result-item" data-index="${idx}">
              <span class="search-result-title">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline></svg>
                ${m.title}
              </span>
              <span class="search-result-desc">${m.desc}</span>
            </a>
          `).join('');
          searchDropdown.classList.add('active');
        } else {
          searchDropdown.classList.remove('active');
          searchDropdown.innerHTML = '';
        }
      }
    });

    // Keyboard navigation in search input: ArrowDown, ArrowUp, Enter, Escape
    searchInput.addEventListener('keydown', (e) => {
      if (!searchDropdown || !searchDropdown.classList.contains('active')) return;
      const items = searchDropdown.querySelectorAll('.search-result-item');
      if (items.length === 0) return;

      if (e.key === 'ArrowDown') {
        e.preventDefault();
        selectedResultIndex = (selectedResultIndex + 1) % items.length;
        updateSelectedResult(items);
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        selectedResultIndex = (selectedResultIndex - 1 + items.length) % items.length;
        updateSelectedResult(items);
      } else if (e.key === 'Enter') {
        e.preventDefault();
        if (selectedResultIndex >= 0 && selectedResultIndex < items.length) {
          items[selectedResultIndex].click();
        } else if (items.length > 0) {
          items[0].click();
        }
      }
    });

    document.addEventListener('click', (e) => {
      if (searchDropdown && !headerSearchBox.contains(e.target)) {
        searchDropdown.classList.remove('active');
      }
    });

    // Global keyboard shortcut: Ctrl+F, Ctrl+K, or / focuses search
    window.addEventListener('keydown', (e) => {
      if ((e.ctrlKey && (e.key.toLowerCase() === 'f' || e.key.toLowerCase() === 'k')) || (e.key === '/' && document.activeElement !== searchInput)) {
        e.preventDefault();
        searchInput.focus();
        searchInput.select();
      } else if (e.key === 'Escape') {
        if (searchDropdown) searchDropdown.classList.remove('active');
        if (lightboxModal && lightboxModal.classList.contains('active')) {
          closeLightbox();
        } else if (document.activeElement === searchInput) {
          searchInput.blur();
        }
      }
    });
  }

  // ==========================================
  // 9. ACTIVE PAGE SIDEBAR HIGHLIGHTING & LANDSCAPE SCROLL
  // ==========================================
  const navLinks = document.querySelectorAll('.doc-sidebar .nav-link');
  const currentPath = window.location.pathname.split('/').pop() || 'index.html';

  navLinks.forEach(link => {
    const linkHref = link.getAttribute('href');
    if (linkHref === currentPath || (currentPath === '' && linkHref === 'index.html') || (currentPath === 'overview.html' && linkHref === 'index.html')) {
      link.classList.add('active');
      // On landscape or small screens, ensure active link is visible in scrollable sidebar
      link.scrollIntoView({ block: 'nearest' });
    }
  });
});
