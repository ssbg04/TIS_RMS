/**
 * TIS-RMS DOCUMENTATION INTERACTIVE CONTROLLER
 * Handles:
 * 1. Interactive Walkthrough Reel / Video Player
 * 2. Mockup Platform Tab Switching & Header Platform Filtering
 * 3. Live Client-Side Search with Highlighting
 * 4. Image Lightbox Zoom Modal
 * 5. Theme Toggle (Dark/Light) with LocalStorage
 * 6. Sidebar Scrollspy Navigation
 * 7. Print Handler & Global Keyboard Shortcuts
 */

document.addEventListener('DOMContentLoaded', () => {

  // ==========================================
  // 1. THEME TOGGLE
  // ==========================================
  const themeToggleBtn = document.getElementById('themeToggleBtn');
  const savedTheme = localStorage.getItem('tis_doc_theme') || 'light';
  document.documentElement.setAttribute('data-theme', savedTheme);

  themeToggleBtn.addEventListener('click', () => {
    const currentTheme = document.documentElement.getAttribute('data-theme');
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', newTheme);
    localStorage.setItem('tis_doc_theme', newTheme);
  });

  // ==========================================
  // 2. PRINT HANDLER
  // ==========================================
  const printBtn = document.getElementById('printBtn');
  if (printBtn) {
    printBtn.addEventListener('click', () => {
      window.print();
    });
  }

  // ==========================================
  // 2B. MOBILE NAVIGATION & SEARCH
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

  // Mobile search toggle
  if (mobileSearchBtn && headerSearchBox) {
    mobileSearchBtn.addEventListener('click', () => {
      const isOpen = headerSearchBox.classList.toggle('mobile-open');
      if (isOpen && docSearchInput) {
        docSearchInput.focus();
      }
    });
  }

  // ==========================================
  // 3. FAQ ACCORDION HANDLER
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
  // 4. MOCKUP TAB SWITCHING (WINDOWS / ANDROID)
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
  // 5. GLOBAL PLATFORM FILTER IN HEADER
  // ==========================================
  const platformFilterBtns = document.querySelectorAll('.platform-pill-toggle .platform-btn');
  platformFilterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      platformFilterBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');

      const filter = btn.getAttribute('data-platform-filter');

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
    });
  });

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
  // 7. LIVE SEARCH WITH HIGHLIGHTING & SHORTCUT
  // ==========================================
  const searchInput = document.getElementById('docSearchInput');
  const searchableSections = document.querySelectorAll('.doc-section, .hero-banner');

  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      const query = e.target.value.trim().toLowerCase();

      if (!query) {
        searchableSections.forEach(sec => {
          sec.style.display = '';
          sec.querySelectorAll('.feature-card, .step-card, tr').forEach(item => {
            item.style.display = '';
          });
        });
        return;
      }

      searchableSections.forEach(sec => {
        const text = sec.textContent.toLowerCase();
        if (text.includes(query)) {
          sec.style.display = '';

          // Filter internal child cards
          sec.querySelectorAll('.feature-card, .step-card').forEach(card => {
            const cardText = card.textContent.toLowerCase();
            card.style.display = cardText.includes(query) ? '' : 'none';
          });
        } else {
          sec.style.display = 'none';
        }
      });
    });

    // Global keyboard shortcut: Ctrl+K or / focuses search
    window.addEventListener('keydown', (e) => {
      if ((e.ctrlKey && e.key === 'k') || (e.key === '/' && document.activeElement !== searchInput)) {
        e.preventDefault();
        searchInput.focus();
        searchInput.select();
      } else if (e.key === 'Escape') {
        if (lightboxModal && lightboxModal.classList.contains('active')) {
          closeLightbox();
        } else if (document.activeElement === searchInput) {
          searchInput.blur();
        }
      }
    });
  }

  // ==========================================
  // 8. SCROLLSPY NAVIGATION
  // ==========================================
  const navLinks = document.querySelectorAll('.doc-sidebar .nav-link');
  const sections = document.querySelectorAll('.hero-banner, .doc-section');

  function updateActiveNavLink() {
    const scrollY = window.pageYOffset || document.documentElement.scrollTop;

    sections.forEach(section => {
      const sectionTop = section.offsetTop - 120;
      const sectionHeight = section.offsetHeight;
      const sectionId = section.getAttribute('id');

      if (scrollY >= sectionTop && scrollY < sectionTop + sectionHeight) {
        navLinks.forEach(link => {
          link.classList.remove('active');
          if (link.getAttribute('href') === `#${sectionId}`) {
            link.classList.add('active');
          }
        });
      }
    });
  }

  window.addEventListener('scroll', updateActiveNavLink, { passive: true });
});
