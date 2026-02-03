/**
 * Sligo Jekyll Theme - Search Functionality
 * Uses a simple client-side search with a JSON index
 */

(function() {
  'use strict';

  // Elements
  const searchToggle = document.getElementById('search-toggle');
  const searchModal = document.getElementById('search-modal');
  const searchOverlay = document.getElementById('search-overlay');
  const searchInput = document.getElementById('search-input');
  const searchResults = document.getElementById('search-results-list');
  const searchEmpty = document.getElementById('search-empty');
  const searchLoading = document.getElementById('search-loading');
  const searchNoResults = document.getElementById('search-no-results');

  let searchIndex = null;
  let selectedIndex = -1;

  // ==========================================================================
  // MODAL CONTROLS
  // ==========================================================================

  function openSearch() {
    searchModal.classList.add('is-open');
    searchOverlay.classList.add('is-open');
    document.body.style.overflow = 'hidden';
    searchInput.focus();
    
    // Load search index if not already loaded
    if (!searchIndex) {
      loadSearchIndex();
    }
  }

  function closeSearch() {
    searchModal.classList.remove('is-open');
    searchOverlay.classList.remove('is-open');
    document.body.style.overflow = '';
    searchInput.value = '';
    clearResults();
    selectedIndex = -1;
  }

  if (searchToggle) {
    searchToggle.addEventListener('click', openSearch);
  }

  if (searchOverlay) {
    searchOverlay.addEventListener('click', closeSearch);
  }

  // Keyboard shortcuts
  document.addEventListener('keydown', (e) => {
    // Open search with Cmd/Ctrl + K
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
      e.preventDefault();
      if (searchModal.classList.contains('is-open')) {
        closeSearch();
      } else {
        openSearch();
      }
    }
    
    // Close with Escape
    if (e.key === 'Escape' && searchModal.classList.contains('is-open')) {
      closeSearch();
    }
    
    // Navigate results with arrow keys
    if (searchModal.classList.contains('is-open')) {
      const results = searchResults.querySelectorAll('.search-result');
      
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        selectedIndex = Math.min(selectedIndex + 1, results.length - 1);
        updateSelection(results);
      }
      
      if (e.key === 'ArrowUp') {
        e.preventDefault();
        selectedIndex = Math.max(selectedIndex - 1, 0);
        updateSelection(results);
      }
      
      if (e.key === 'Enter' && selectedIndex >= 0 && results[selectedIndex]) {
        e.preventDefault();
        results[selectedIndex].click();
      }
    }
  });

  function updateSelection(results) {
    results.forEach((result, index) => {
      result.classList.toggle('is-selected', index === selectedIndex);
    });
    
    // Scroll selected item into view
    if (results[selectedIndex]) {
      results[selectedIndex].scrollIntoView({
        block: 'nearest',
        behavior: 'smooth'
      });
    }
  }

  // ==========================================================================
  // SEARCH INDEX
  // ==========================================================================

  async function loadSearchIndex() {
    showLoading(true);
    
    try {
      const response = await fetch('/search.json');
      if (response.ok) {
        searchIndex = await response.json();
      } else {
        // Generate index from navigation if search.json doesn't exist
        searchIndex = generateFallbackIndex();
      }
    } catch (error) {
      console.warn('Search index not found, using fallback');
      searchIndex = generateFallbackIndex();
    }
    
    showLoading(false);
    showEmpty(true);
  }

  function generateFallbackIndex() {
    // Fallback: generate index from page content
    const pages = [];
    
    // This is a simple fallback - in production, you'd generate search.json at build time
    document.querySelectorAll('.nav-link').forEach(link => {
      pages.push({
        title: link.textContent.trim(),
        url: link.getAttribute('href'),
        content: ''
      });
    });
    
    return pages;
  }

  // ==========================================================================
  // SEARCH EXECUTION
  // ==========================================================================

  function performSearch(query) {
    if (!query || query.length < 2) {
      clearResults();
      showEmpty(true);
      return;
    }
    
    if (!searchIndex) {
      showLoading(true);
      return;
    }
    
    const normalizedQuery = query.toLowerCase().trim();
    const words = normalizedQuery.split(/\s+/);
    
    const results = searchIndex
      .map(page => {
        let score = 0;
        const titleLower = (page.title || '').toLowerCase();
        const contentLower = (page.content || '').toLowerCase();
        const urlLower = (page.url || '').toLowerCase();
        
        words.forEach(word => {
          // Title matches are weighted higher
          if (titleLower.includes(word)) {
            score += 10;
            if (titleLower.startsWith(word)) {
              score += 5;
            }
          }
          
          // URL matches
          if (urlLower.includes(word)) {
            score += 3;
          }
          
          // Content matches
          if (contentLower.includes(word)) {
            score += 1;
          }
        });
        
        return { ...page, score };
      })
      .filter(page => page.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, 10);
    
    displayResults(results, query);
  }

  // ==========================================================================
  // DISPLAY
  // ==========================================================================

  function displayResults(results, query) {
    showEmpty(false);
    showLoading(false);
    
    if (results.length === 0) {
      showNoResults(true);
      searchResults.innerHTML = '';
      return;
    }
    
    showNoResults(false);
    selectedIndex = -1;
    
    const html = results.map((result, index) => {
      const highlightedTitle = highlightMatches(result.title || 'Untitled', query);
      const excerpt = getExcerpt(result.content || '', query);
      const highlightedExcerpt = highlightMatches(excerpt, query);
      
      return `
        <a href="${result.url}" class="search-result" data-index="${index}">
          <div class="search-result-title">${highlightedTitle}</div>
          <div class="search-result-path">${result.url}</div>
          ${highlightedExcerpt ? `<div class="search-result-excerpt">${highlightedExcerpt}</div>` : ''}
        </a>
      `;
    }).join('');
    
    searchResults.innerHTML = html;
    
    // Add click handlers to close modal
    searchResults.querySelectorAll('.search-result').forEach(result => {
      result.addEventListener('click', () => {
        closeSearch();
      });
    });
  }

  function highlightMatches(text, query) {
    if (!text || !query) return text;
    
    const words = query.toLowerCase().split(/\s+/);
    let result = text;
    
    words.forEach(word => {
      if (word.length >= 2) {
        const regex = new RegExp(`(${escapeRegex(word)})`, 'gi');
        result = result.replace(regex, '<mark>$1</mark>');
      }
    });
    
    return result;
  }

  function getExcerpt(content, query, maxLength = 150) {
    if (!content || !query) return '';
    
    const words = query.toLowerCase().split(/\s+/);
    const contentLower = content.toLowerCase();
    
    // Find the first occurrence of any query word
    let firstIndex = -1;
    for (const word of words) {
      const index = contentLower.indexOf(word);
      if (index !== -1 && (firstIndex === -1 || index < firstIndex)) {
        firstIndex = index;
      }
    }
    
    if (firstIndex === -1) {
      return content.slice(0, maxLength) + (content.length > maxLength ? '...' : '');
    }
    
    // Extract excerpt around the match
    const start = Math.max(0, firstIndex - 40);
    const end = Math.min(content.length, firstIndex + maxLength - 40);
    
    let excerpt = content.slice(start, end);
    
    if (start > 0) excerpt = '...' + excerpt;
    if (end < content.length) excerpt = excerpt + '...';
    
    return excerpt;
  }

  function escapeRegex(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  function clearResults() {
    searchResults.innerHTML = '';
    selectedIndex = -1;
  }

  function showEmpty(show) {
    searchEmpty.classList.toggle('hidden', !show);
  }

  function showLoading(show) {
    searchLoading.classList.toggle('hidden', !show);
  }

  function showNoResults(show) {
    searchNoResults.classList.toggle('hidden', !show);
  }

  // ==========================================================================
  // INPUT HANDLING
  // ==========================================================================

  let debounceTimer;

  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => {
        performSearch(e.target.value);
      }, 200);
    });
  }

})();
