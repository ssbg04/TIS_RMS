/**
 * TIS-RMS DOCUMENTATION INTERACTIVE CONTROLLER
 * Handles:
 * 1. Minimalist Dark/Light Theme Switching with Instant Sync & LocalStorage
 * 2. Dedicated Print Action
 * 3. Mockup Platform Tab Switching (Windows / Android)
 * 4. Responsive Mobile & Landscape Sidebar Navigation
 * 5. Lightbox Zoom Modal
 * 6. FAQ Accordion Interaction
 * 7. Multi-Page Live Search with Keyboard Navigation
 * 8. Seamless Zero-Flicker Client-Side Navigation (SPA / Fast Page Swap)
 */

document.addEventListener('DOMContentLoaded', () => {

  // ==========================================
  // 1. THEME CONTROLLER (MINIMALIST LIGHT / DARK)
  // ==========================================
  const themeToggleBtn = document.getElementById('themeToggleBtn');
  const savedTheme = localStorage.getItem('tis_doc_theme');
  const systemPrefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  const currentTheme = document.documentElement.getAttribute('data-theme') || savedTheme || (systemPrefersDark ? 'dark' : 'light');

  function updateThemeButton(theme) {
    if (!themeToggleBtn) return;
    const isDark = theme === 'dark';
    themeToggleBtn.setAttribute('title', isDark ? 'Switch to light theme' : 'Switch to dark theme');
    themeToggleBtn.setAttribute('aria-label', isDark ? 'Switch to light theme' : 'Switch to dark theme');
  }

  function applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    document.documentElement.style.backgroundColor = (theme === 'dark' ? '#09090B' : '#FFFFFF');
    document.documentElement.style.colorScheme = theme;
    localStorage.setItem('tis_doc_theme', theme);
    updateThemeButton(theme);

    const meta = document.getElementById('themeColorMeta') || document.querySelector('meta[name="theme-color"]');
    if (meta) {
      meta.setAttribute('content', theme === 'dark' ? '#09090B' : '#FFFFFF');
    }
  }

  applyTheme(currentTheme);

  if (themeToggleBtn) {
    themeToggleBtn.addEventListener('click', () => {
      const activeTheme = document.documentElement.getAttribute('data-theme') === 'dark' ? 'dark' : 'light';
      const newTheme = activeTheme === 'dark' ? 'light' : 'dark';
      applyTheme(newTheme);
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
  // 3. MOCKUP TAB SWITCHING
  // ==========================================
  function initMockupTabs() {
    document.querySelectorAll('.mockup-container').forEach(container => {
      const tabBtns = container.querySelectorAll('.mockup-tab-btn');
      const panes = container.querySelectorAll('.mockup-pane');

      tabBtns.forEach(btn => {
        btn.onclick = () => {
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
        };
      });
    });
  }

  // ==========================================
  // 4. MOBILE NAVIGATION & SEARCH
  // ==========================================
  const mobileMenuBtn = document.getElementById('mobileMenuBtn');
  const docSidebar = document.getElementById('docSidebar');
  const sidebarBackdrop = document.getElementById('sidebarBackdrop');
  const mobileSearchBtn = document.getElementById('mobileSearchBtn');
  const headerSearchBox = document.getElementById('headerSearchBox');
  const docSearchInput = document.getElementById('docSearchInput');

  function openMobileSidebar() {
    if (docSidebar) {
      docSidebar.classList.add('open');
      const activeLink = docSidebar.querySelector('.nav-link.active');
      if (activeLink) {
        setTimeout(() => {
          activeLink.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        }, 120);
      }
    }
    if (sidebarBackdrop) sidebarBackdrop.classList.add('active');
    if (mobileMenuBtn) {
      mobileMenuBtn.classList.add('active');
      const ham = mobileMenuBtn.querySelector('.hamburger-icon');
      const close = mobileMenuBtn.querySelector('.close-icon');
      if (ham) ham.style.display = 'none';
      if (close) close.style.display = 'block';
      mobileMenuBtn.setAttribute('aria-expanded', 'true');
    }
    document.body.style.overflow = 'hidden';
  }

  function closeMobileSidebar() {
    if (docSidebar) docSidebar.classList.remove('open');
    if (sidebarBackdrop) sidebarBackdrop.classList.remove('active');
    if (mobileMenuBtn) {
      mobileMenuBtn.classList.remove('active');
      const ham = mobileMenuBtn.querySelector('.hamburger-icon');
      const close = mobileMenuBtn.querySelector('.close-icon');
      if (ham) ham.style.display = 'block';
      if (close) close.style.display = 'none';
      mobileMenuBtn.setAttribute('aria-expanded', 'false');
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

  // Touch swipe left to close mobile sidebar
  let touchStartX = 0;
  let touchStartY = 0;
  if (docSidebar) {
    docSidebar.addEventListener('touchstart', (e) => {
      touchStartX = e.changedTouches[0].screenX;
      touchStartY = e.changedTouches[0].screenY;
    }, { passive: true });

    docSidebar.addEventListener('touchend', (e) => {
      const touchEndX = e.changedTouches[0].screenX;
      const touchEndY = e.changedTouches[0].screenY;
      const diffX = touchStartX - touchEndX;
      const diffY = Math.abs(touchStartY - touchEndY);
      if (diffX > 45 && diffY < 100 && docSidebar.classList.contains('open')) {
        closeMobileSidebar();
      }
    }, { passive: true });
  }

  window.addEventListener('resize', () => {
    if (window.innerWidth > 1024 && docSidebar && docSidebar.classList.contains('open')) {
      closeMobileSidebar();
    }
  });

  if (mobileSearchBtn && headerSearchBox) {
    mobileSearchBtn.addEventListener('click', () => {
      const isOpen = headerSearchBox.classList.toggle('mobile-open');
      if (isOpen && docSearchInput) {
        docSearchInput.focus();
      }
    });
  }

  // ==========================================
  // 5. FAQ ACCORDION HANDLER
  // ==========================================
  function initFaqAccordions() {
    document.querySelectorAll('.faq-item').forEach(item => {
      const questionBtn = item.querySelector('.faq-question');
      if (questionBtn) {
        questionBtn.onclick = () => {
          const isActive = item.classList.contains('active');
          item.classList.toggle('active', !isActive);
        };
      }
    });
  }

  // ==========================================
  // 6. LIGHTBOX ZOOM MODAL
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

  function initLightboxTriggers() {
    document.querySelectorAll('[data-lightbox]').forEach(el => {
      el.onclick = () => {
        const src = el.getAttribute('data-lightbox');
        const caption = el.getAttribute('data-caption') || '';
        openLightbox(src, caption);
      };
    });
  }

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
  // 7. MULTI-PAGE LIVE SEARCH & QUICK NAVIGATION
  // ==========================================
  const searchInput = document.getElementById('docSearchInput');
  let searchableSections = document.querySelectorAll('.doc-main .doc-section, .doc-main .hero-banner');

  function updateSearchableSections() {
    searchableSections = document.querySelectorAll('.doc-main .doc-section, .doc-main .hero-banner');
  }

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
  // 8. ACTIVE PAGE SIDEBAR HIGHLIGHTING
  // ==========================================
  function updateActiveSidebarLink(targetHref) {
    const rawPath = targetHref || window.location.pathname;
    let filename = rawPath.split('/').pop().split('?')[0].split('#')[0] || 'index.html';
    if (filename === '' || filename === 'overview.html') filename = 'index.html';

    const navLinks = document.querySelectorAll('.doc-sidebar .nav-link');
    navLinks.forEach(link => {
      const linkHref = link.getAttribute('href');
      if (linkHref === filename) {
        link.classList.add('active');
        link.scrollIntoView({ block: 'nearest' });
      } else {
        link.classList.remove('active');
      }
    });
  }

  // ==========================================
  // 9. COMPONENT RE-INITIALIZER
  // ==========================================
  function initPageFeatures() {
    initMockupTabs();
    initFaqAccordions();
    initLightboxTriggers();
    updateSearchableSections();
    updateActiveSidebarLink();
  }

  // ==========================================
  // 10. SEAMLESS ZERO-FLICKER CLIENT NAVIGATION
  // ==========================================
  async function loadPage(url, pushState = true) {
    try {
      const response = await fetch(url);
      if (!response.ok) throw new Error('HTTP ' + response.status);
      const htmlText = await response.text();
      const parser = new DOMParser();
      const newDoc = parser.parseFromString(htmlText, 'text/html');

      const newMain = newDoc.querySelector('.doc-main');
      const currentMain = document.querySelector('.doc-main');
      if (!newMain || !currentMain) {
        window.location.href = url;
        return;
      }

      // Smoothly replace the main content without destroying the root DOM/canvas
      currentMain.replaceWith(newMain);

      // Update page title
      if (newDoc.title) {
        document.title = newDoc.title;
      }

      // Push history state
      if (pushState) {
        window.history.pushState({ docUrl: url }, '', url);
      }

      // Update active nav-link in sidebar
      updateActiveSidebarLink(url);

      // Close mobile sidebar immediately
      if (window.innerWidth <= 1024) {
        closeMobileSidebar();
      }

      // Close search dropdown and clear inputs
      if (headerSearchBox && headerSearchBox.classList.contains('mobile-open')) {
        headerSearchBox.classList.remove('mobile-open');
      }
      if (searchDropdown) {
        searchDropdown.classList.remove('active');
      }
      if (searchInput) {
        searchInput.value = '';
      }

      // Scroll to anchor or top
      const targetHash = new URL(url, window.location.href).hash;
      if (targetHash) {
        const targetEl = document.querySelector(targetHash);
        if (targetEl) {
          targetEl.scrollIntoView();
        } else {
          window.scrollTo(0, 0);
        }
      } else {
        window.scrollTo(0, 0);
      }

      // Re-init interactive components
      initPageFeatures();
    } catch (_) {
      // Fallback to normal navigation if fetch fails
      window.location.href = url;
    }
  }

  // Global click interceptor for seamless documentation links
  document.addEventListener('click', (e) => {
    const link = e.target.closest('a');
    if (!link) return;

    if (link.target && link.target !== '_self') return;
    if (link.hasAttribute('download')) return;
    if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button !== 0) return;

    const href = link.getAttribute('href');
    if (!href) return;
    if (href.startsWith('javascript:') || href.startsWith('mailto:') || href.startsWith('tel:')) return;

    let targetUrl;
    try {
      targetUrl = new URL(href, window.location.href);
    } catch (_) {
      return;
    }

    if (targetUrl.origin !== window.location.origin) return;

    // Same-page hash navigation
    if (targetUrl.pathname === window.location.pathname) {
      if (targetUrl.hash) {
        if (window.innerWidth <= 1024) {
          closeMobileSidebar();
        }
        return;
      }
    }

    const targetPath = targetUrl.pathname;
    if (targetPath.endsWith('.html') || targetPath.endsWith('/') || targetPath === '') {
      e.preventDefault();
      loadPage(targetUrl.href, true);
    }
  });

  // Browser/WebView Back & Forward history navigation
  window.addEventListener('popstate', () => {
    loadPage(window.location.href, false);
  });

  // Run initial page setup
  initPageFeatures();
});
