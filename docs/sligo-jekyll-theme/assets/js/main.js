/**
 * Sligo Jekyll Theme - Main JavaScript
 */

(function() {
  'use strict';

  // ==========================================================================
  // THEME TOGGLE (Dark/Light Mode)
  // ==========================================================================
  
  const themeToggle = document.getElementById('theme-toggle');
  const html = document.documentElement;
  
  function setTheme(theme) {
    html.setAttribute('data-theme', theme);
    localStorage.setItem('sligo-theme', theme);
  }
  
  function toggleTheme() {
    const currentTheme = html.getAttribute('data-theme');
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    setTheme(newTheme);
  }
  
  if (themeToggle) {
    themeToggle.addEventListener('click', toggleTheme);
  }
  
  // Listen for system preference changes
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
    if (!localStorage.getItem('sligo-theme')) {
      setTheme(e.matches ? 'dark' : 'light');
    }
  });

  // ==========================================================================
  // MOBILE NAVIGATION
  // ==========================================================================
  
  const mobileMenuToggle = document.getElementById('mobile-menu-toggle');
  const sidebar = document.getElementById('sidebar');
  const sidebarOverlay = document.getElementById('sidebar-overlay');
  
  function openMobileNav() {
    sidebar.classList.add('is-open');
    sidebarOverlay.classList.add('is-visible');
    mobileMenuToggle.setAttribute('aria-expanded', 'true');
    document.body.classList.add('nav-open');
  }
  
  function closeMobileNav() {
    sidebar.classList.remove('is-open');
    sidebarOverlay.classList.remove('is-visible');
    mobileMenuToggle.setAttribute('aria-expanded', 'false');
    document.body.classList.remove('nav-open');
  }
  
  function toggleMobileNav() {
    const isOpen = sidebar.classList.contains('is-open');
    if (isOpen) {
      closeMobileNav();
    } else {
      openMobileNav();
    }
  }
  
  if (mobileMenuToggle) {
    mobileMenuToggle.addEventListener('click', toggleMobileNav);
  }
  
  if (sidebarOverlay) {
    sidebarOverlay.addEventListener('click', closeMobileNav);
  }
  
  // Close mobile nav on escape key
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && sidebar.classList.contains('is-open')) {
      closeMobileNav();
    }
  });
  
  // Close mobile nav on window resize to desktop
  window.addEventListener('resize', () => {
    if (window.innerWidth >= 1024 && sidebar.classList.contains('is-open')) {
      closeMobileNav();
    }
  });

  // ==========================================================================
  // VERSION SELECTOR
  // ==========================================================================
  
  const versionToggle = document.getElementById('version-toggle');
  const versionDropdown = document.getElementById('version-dropdown');
  
  function toggleVersionDropdown() {
    const isExpanded = versionToggle.getAttribute('aria-expanded') === 'true';
    versionToggle.setAttribute('aria-expanded', !isExpanded);
    versionDropdown.classList.toggle('is-open');
  }
  
  function closeVersionDropdown() {
    versionToggle.setAttribute('aria-expanded', 'false');
    versionDropdown.classList.remove('is-open');
  }
  
  if (versionToggle && versionDropdown) {
    versionToggle.addEventListener('click', toggleVersionDropdown);
    
    // Close on click outside
    document.addEventListener('click', (e) => {
      if (!versionToggle.contains(e.target) && !versionDropdown.contains(e.target)) {
        closeVersionDropdown();
      }
    });
    
    // Close on escape
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        closeVersionDropdown();
      }
    });
  }

  // ==========================================================================
  // TABLE OF CONTENTS
  // ==========================================================================
  
  function generateTOC() {
    const tocList = document.getElementById('toc-list');
    const tocInlineList = document.getElementById('toc-inline-list');
    const content = document.querySelector('.content');
    
    if (!content) return;
    
    const headings = content.querySelectorAll('h2, h3');
    
    if (headings.length === 0) return;
    
    const tocItems = [];
    
    headings.forEach((heading, index) => {
      // Ensure heading has an ID
      if (!heading.id) {
        heading.id = heading.textContent
          .toLowerCase()
          .replace(/[^\w\s-]/g, '')
          .replace(/\s+/g, '-')
          .replace(/-+/g, '-');
      }
      
      // Add anchor link to heading
      const anchor = document.createElement('a');
      anchor.href = '#' + heading.id;
      anchor.className = 'heading-anchor';
      anchor.textContent = '#';
      anchor.setAttribute('aria-label', 'Link to this section');
      heading.insertBefore(anchor, heading.firstChild);
      
      tocItems.push({
        id: heading.id,
        text: heading.textContent.replace('#', '').trim(),
        level: heading.tagName.toLowerCase()
      });
    });
    
    // Build TOC HTML
    function buildTOCHTML(items) {
      return items.map(item => {
        const isNested = item.level === 'h3';
        return `<li class="toc-item">
          <a href="#${item.id}" class="toc-link ${isNested ? 'toc-link--nested' : ''}">${item.text}</a>
        </li>`;
      }).join('');
    }
    
    const tocHTML = buildTOCHTML(tocItems);
    
    if (tocList) {
      tocList.innerHTML = tocHTML;
    }
    
    if (tocInlineList) {
      tocInlineList.innerHTML = tocHTML;
    }
    
    // Highlight active TOC item on scroll
    if (tocList) {
      const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            const id = entry.target.id;
            document.querySelectorAll('.toc-link').forEach(link => {
              link.classList.remove('is-active');
              if (link.getAttribute('href') === '#' + id) {
                link.classList.add('is-active');
              }
            });
          }
        });
      }, {
        rootMargin: '-80px 0px -80% 0px',
        threshold: 0
      });
      
      headings.forEach(heading => observer.observe(heading));
    }
  }
  
  generateTOC();

  // ==========================================================================
  // CODE COPY BUTTON
  // ==========================================================================
  
  function addCopyButtons() {
    const codeBlocks = document.querySelectorAll('div.highlighter-rouge, div.highlight, pre.highlight');
    
    codeBlocks.forEach(block => {
      // Skip if already has copy button
      if (block.querySelector('.code-copy-btn')) return;
      
      const button = document.createElement('button');
      button.className = 'code-copy-btn';
      button.setAttribute('aria-label', 'Copy code to clipboard');
      button.innerHTML = `
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
          <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
        </svg>
      `;
      
      button.addEventListener('click', async () => {
        const code = block.querySelector('code');
        const text = code ? code.textContent : block.textContent;
        
        try {
          await navigator.clipboard.writeText(text);
          button.classList.add('copied');
          button.innerHTML = `
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="20 6 9 17 4 12"/>
            </svg>
          `;
          
          setTimeout(() => {
            button.classList.remove('copied');
            button.innerHTML = `
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
                <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
              </svg>
            `;
          }, 2000);
        } catch (err) {
          console.error('Failed to copy:', err);
        }
      });
      
      // Position relative for the button
      block.style.position = 'relative';
      block.appendChild(button);
      
      // Add language label if available
      const pre = block.querySelector('pre') || block;
      const language = block.className.match(/language-(\w+)/);
      if (language) {
        block.setAttribute('data-lang', language[1]);
      }
    });
  }
  
  addCopyButtons();

  // ==========================================================================
  // SMOOTH SCROLL FOR ANCHOR LINKS
  // ==========================================================================
  
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function(e) {
      const targetId = this.getAttribute('href');
      if (targetId === '#') return;
      
      const target = document.querySelector(targetId);
      if (target) {
        e.preventDefault();
        target.scrollIntoView({
          behavior: 'smooth',
          block: 'start'
        });
        
        // Update URL without jumping
        history.pushState(null, null, targetId);
      }
    });
  });

  // ==========================================================================
  // COLLAPSIBLE NAVIGATION SECTIONS
  // ==========================================================================
  
  document.querySelectorAll('.nav-collapsible .nav-toggle').forEach(toggle => {
    toggle.addEventListener('click', () => {
      const parent = toggle.closest('.nav-collapsible');
      parent.classList.toggle('is-expanded');
    });
  });

  // ==========================================================================
  // EXTERNAL LINKS - Add target="_blank"
  // ==========================================================================
  
  document.querySelectorAll('.content a[href^="http"]').forEach(link => {
    if (!link.hostname.includes(window.location.hostname)) {
      link.setAttribute('target', '_blank');
      link.setAttribute('rel', 'noopener noreferrer');
    }
  });

  // ==========================================================================
  // WRAP TABLES FOR HORIZONTAL SCROLL
  // ==========================================================================
  
  document.querySelectorAll('.content table').forEach(table => {
    if (!table.parentElement.classList.contains('table-wrapper')) {
      const wrapper = document.createElement('div');
      wrapper.className = 'table-wrapper';
      table.parentNode.insertBefore(wrapper, table);
      wrapper.appendChild(table);
    }
  });

})();
