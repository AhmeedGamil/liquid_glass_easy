// The only JavaScript on the site.
//
// Navigation, layout, the language switcher and every link are HTML and CSS,
// so the pages work with this file blocked and are readable before it runs.
// What is here is the part that genuinely needs a runtime: remembering a
// choice, copying to the clipboard, and searching an index that would be
// wasteful to download on a page nobody searches from.

(function () {
  'use strict';

  var root = document.documentElement;
  var lang = root.getAttribute('lang') || 'en';

  function store(key, value) {
    try { localStorage.setItem(key, value); } catch (e) { /* private mode */ }
  }
  function read(key) {
    try { return localStorage.getItem(key); } catch (e) { return null; }
  }

  // ── theme ───────────────────────────────────────────────────────────
  //
  // The <head> already applied the stored choice before first paint; this only
  // handles changing it. "system" is a real third state, not the absence of a
  // choice: it keeps following the OS after the user has picked it.

  var media = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)');

  function applyTheme(pref) {
    var resolved = pref === 'system'
      ? (media && media.matches ? 'dark' : 'light')
      : pref;
    root.dataset.theme = resolved;
    root.dataset.themePref = pref;
    // The comment widget is a giscus.app document; it cannot see our
    // data-theme, so it is told.
    var gf = document.querySelector('iframe.giscus-frame');
    if (gf && gf.contentWindow) {
      gf.contentWindow.postMessage(
        { giscus: { setConfig: { theme: resolved } } }, 'https://giscus.app');
    }
    document.querySelectorAll('[data-theme-set]').forEach(function (b) {
      if (b.getAttribute('data-theme-set') === pref) {
        b.setAttribute('aria-current', 'true');
      } else {
        b.removeAttribute('aria-current');
      }
    });
  }

  applyTheme(read('lge-theme') || 'system');

  if (media && media.addEventListener) {
    media.addEventListener('change', function () {
      if ((read('lge-theme') || 'system') === 'system') applyTheme('system');
    });
  }

  document.addEventListener('click', function (e) {
    var btn = e.target.closest('[data-theme-set]');
    if (!btn) return;
    var pref = btn.getAttribute('data-theme-set');
    if (pref === 'system') {
      try { localStorage.removeItem('lge-theme'); } catch (err) { /* ignore */ }
    } else {
      store('lge-theme', pref);
    }
    applyTheme(pref);
    closeMenus();
  });

  // ── lite glass ──────────────────────────────────────────────────────
  //
  // One switch for every demo on the site. The demos are same-origin, so
  // they read 'lge-lite' from the same storage on start-up; this only has
  // to store the choice and reload the frames already on the page.

  function applyLite(on) {
    root.dataset.lite = on ? 'on' : 'off';
    document.querySelectorAll('[data-lite-toggle]').forEach(function (b) {
      b.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
  }

  applyLite(read('lge-lite') === '1');

  document.addEventListener('click', function (e) {
    var btn = e.target.closest('[data-lite-toggle]');
    if (!btn) return;
    var on = btn.getAttribute('aria-pressed') !== 'true';
    if (on) {
      store('lge-lite', '1');
    } else {
      try { localStorage.removeItem('lge-lite'); } catch (err) { /* ignore */ }
    }
    applyLite(on);
    document.querySelectorAll('.demo-frame iframe').forEach(function (f) {
      // Same-origin, so the frame can be reloaded in place; assigning src
      // is the fallback for a frame that has not navigated yet.
      try { f.contentWindow.location.reload(); } catch (err) { f.src = f.src; }
    });
  });

  // ── live counters ───────────────────────────────────────────────────
  //
  // The landing page ships the GitHub star and pub.dev like counts as of the
  // build; this replaces them with today's. Both APIs allow any origin. A
  // failed request leaves the built-in number, which is a fine answer.

  function compact(n) {
    if (n < 1000) return String(n);
    var k = n / 1000;
    return (k >= 10 ? Math.round(k) : k.toFixed(1)) + 'k';
  }

  function refreshStat(name, url, field) {
    var el = document.querySelector('[data-stat="' + name + '"]');
    if (!el || !window.fetch) return;
    fetch(url, { headers: { Accept: 'application/json' } })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (j) {
        var n = j && j[field];
        if (typeof n === 'number') el.textContent = compact(n);
      })
      .catch(function () { /* keep the build-time count */ });
  }

  refreshStat('stars',
    'https://api.github.com/repos/AhmeedGamil/liquid_glass_easy',
    'stargazers_count');
  refreshStat('likes',
    'https://pub.dev/api/packages/liquid_glass_easy/score',
    'likeCount');

  // ── language ────────────────────────────────────────────────────────
  //
  // Remembered so the root redirect can send a returning visitor straight to
  // the language they read last, rather than to whatever their browser claims.

  store('lge-lang', lang);
  document.querySelectorAll('.lang-pop a').forEach(function (a) {
    a.addEventListener('click', function () {
      store('lge-lang', a.getAttribute('lang'));
    });
  });

  // ── menus ───────────────────────────────────────────────────────────

  function closeMenus(except) {
    document.querySelectorAll('.menu-wrap.open').forEach(function (w) {
      if (w === except) return;
      w.classList.remove('open');
      var b = w.querySelector('button');
      if (b) b.setAttribute('aria-expanded', 'false');
    });
  }

  document.addEventListener('click', function (e) {
    var btn = e.target.closest('.menu-wrap > button');
    if (!btn) {
      if (!e.target.closest('.pop')) closeMenus();
      return;
    }
    var wrap = btn.parentElement;
    var open = !wrap.classList.contains('open');
    closeMenus(wrap);
    wrap.classList.toggle('open', open);
    btn.setAttribute('aria-expanded', String(open));
  });

  // ── the sidebar drawer ──────────────────────────────────────────────

  var menuBtn = document.querySelector('.menu');
  var scrim = document.querySelector('.scrim');

  function setNav(open) {
    document.body.classList.toggle('nav-open', open);
    if (menuBtn) menuBtn.setAttribute('aria-expanded', String(open));
    if (scrim) scrim.hidden = !open;
  }
  if (menuBtn) {
    menuBtn.addEventListener('click', function () {
      setNav(!document.body.classList.contains('nav-open'));
    });
  }
  if (scrim) scrim.addEventListener('click', function () { setNav(false); });
  // A tap on a link inside the drawer navigates; the drawer should not still
  // be open behind the new page on a browser that restored the scroll.
  document.querySelectorAll('.sidebar a').forEach(function (a) {
    a.addEventListener('click', function () { setNav(false); });
  });

  // ── copy ────────────────────────────────────────────────────────────

  document.addEventListener('click', function (e) {
    var btn = e.target.closest('.copy, .copy-inline');
    if (!btn) return;

    // A block button sits in its block's header bar; an inline one wraps its
    // own code.
    var inline = btn.classList.contains('copy-inline');
    var code = inline
      ? btn.querySelector('code')
      : btn.closest('.code').querySelector('pre code');
    if (!code || !navigator.clipboard) return;

    navigator.clipboard.writeText(code.innerText).then(function () {
      var target = inline ? code : btn;
      var was = target.textContent;
      target.textContent = btn.getAttribute('data-copied') || 'Copied';
      btn.classList.add('done');
      setTimeout(function () {
        target.textContent = inline ? was : (btn.getAttribute('data-copy') || was);
        btn.classList.remove('done');
      }, 1500);
    });
  });

  // ── which heading am I in ───────────────────────────────────────────
  //
  // The sidebar already says which page you are on. This says which part of
  // it, by marking the last heading to have crossed the top of the viewport.

  (function () {
    var links = document.querySelectorAll('.sidebar .toc a');
    if (!links.length || !window.IntersectionObserver) return;

    var byId = {};
    var heads = [];
    links.forEach(function (a) {
      var h = document.getElementById(decodeURIComponent(a.hash.slice(1)));
      if (!h) return;
      byId[h.id] = a;
      heads.push(h);
    });
    if (!heads.length) return;

    var seen = {};

    function mark() {
      // The active heading is the last one at or above the trigger line;
      // before the first, nothing is marked rather than the wrong thing.
      var current = null;
      for (var i = 0; i < heads.length; i++) {
        if (seen[heads[i].id]) current = heads[i];
      }
      links.forEach(function (a) { a.classList.remove('here'); });
      if (current) byId[current.id].classList.add('here');
    }

    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        seen[entry.target.id] = entry.boundingClientRect.top < 0 ||
                                entry.isIntersecting;
      });
      mark();
    }, { rootMargin: '0px 0px -75% 0px', threshold: 0 });

    heads.forEach(function (h) { io.observe(h); });
  })();

  // ── comments ────────────────────────────────────────────────────────
  //
  // The section only carries the settings; the script is injected here so
  // the widget is created already wearing the theme the page resolved to.
  // Loading is giscus's own lazy mode: nothing is fetched until the section
  // is near the viewport, and a page nobody scrolls to the end of costs
  // nothing.

  (function () {
    var host = document.querySelector('.comments[data-giscus]');
    if (!host) return;

    var s = document.createElement('script');
    s.src = 'https://giscus.app/client.js';
    s.async = true;
    s.crossOrigin = 'anonymous';

    s.setAttribute('data-repo', host.getAttribute('data-repo'));
    s.setAttribute('data-repo-id', host.getAttribute('data-repo-id'));
    s.setAttribute('data-category', host.getAttribute('data-category'));
    s.setAttribute('data-category-id', host.getAttribute('data-category-id'));
    s.setAttribute('data-mapping', 'specific');
    s.setAttribute('data-term', host.getAttribute('data-term'));
    s.setAttribute('data-strict', '1');
    s.setAttribute('data-reactions-enabled', '1');
    s.setAttribute('data-emit-metadata', '0');
    s.setAttribute('data-input-position', 'top');
    s.setAttribute('data-theme', root.dataset.theme === 'dark' ? 'dark' : 'light');
    s.setAttribute('data-lang', host.getAttribute('data-lang') || lang);
    s.setAttribute('data-loading', 'lazy');

    host.appendChild(s);
  })();

  // ── search ──────────────────────────────────────────────────────────
  //
  // The index is one JSON file per language, fetched on the first open. A
  // visitor who never searches never downloads it.

  var panel = document.querySelector('.search-panel');
  if (!panel) return;

  var input = panel.querySelector('input');
  var results = panel.querySelector('.search-results');
  var index = null;
  var loading = false;
  var selected = 0;

  function openSearch() {
    panel.hidden = false;
    input.focus();
    input.select();
    load();
    render(input.value);
  }
  function closeSearch() {
    panel.hidden = true;
  }

  function load() {
    if (index || loading) return;
    loading = true;
    fetch('search.json')
      .then(function (r) { return r.json(); })
      .then(function (data) {
        index = data;
        loading = false;
        render(input.value);
      })
      .catch(function () { loading = false; });
  }

  // Ranking, in one line: a title that starts with the query beats a title
  // that merely contains it, which beats a hit in the description. Enough for
  // a few hundred entries, and it needs no library.
  function score(entry, q) {
    var t = entry.t.toLowerCase();
    var d = (entry.d || '').toLowerCase();
    if (t === q) return 0;
    if (t.indexOf(q) === 0) return 1;
    if (t.indexOf(q) !== -1) return 2;
    if (d.indexOf(q) !== -1) return 3;
    return -1;
  }

  function render(query) {
    var q = (query || '').trim().toLowerCase();
    results.innerHTML = '';
    selected = 0;

    if (!q) {
      results.innerHTML = '<div class="empty">' +
        (results.getAttribute('data-hint') || '') + '</div>';
      return;
    }
    if (!index) return;

    var hits = [];
    for (var i = 0; i < index.length; i++) {
      var s = score(index[i], q);
      if (s !== -1) hits.push({ e: index[i], s: s });
    }
    hits.sort(function (a, b) { return a.s - b.s; });
    hits = hits.slice(0, 30);

    if (!hits.length) {
      results.innerHTML = '<div class="empty">' +
        (results.getAttribute('data-empty') || '') + '</div>';
      return;
    }

    hits.forEach(function (hit, i) {
      var a = document.createElement('a');
      a.href = hit.e.u;
      if (i === 0) a.className = 'sel';

      var title = document.createElement('div');
      title.className = 'r-t';
      var name = document.createElement('span');
      name.textContent = hit.e.t;
      var kind = document.createElement('span');
      kind.className = 'r-k';
      kind.textContent = hit.e.k;
      title.appendChild(name);
      title.appendChild(kind);

      var desc = document.createElement('div');
      desc.className = 'r-d';
      desc.textContent = hit.e.d || '';

      a.appendChild(title);
      a.appendChild(desc);
      results.appendChild(a);
    });
  }

  function move(delta) {
    var items = results.querySelectorAll('a');
    if (!items.length) return;
    items[selected].classList.remove('sel');
    selected = (selected + delta + items.length) % items.length;
    items[selected].classList.add('sel');
    items[selected].scrollIntoView({ block: 'nearest' });
  }

  document.querySelectorAll('.search-btn').forEach(function (b) {
    b.addEventListener('click', openSearch);
  });

  panel.addEventListener('click', function (e) {
    if (e.target === panel) closeSearch();
  });

  input.addEventListener('input', function () { render(input.value); });

  input.addEventListener('keydown', function (e) {
    if (e.key === 'ArrowDown') { e.preventDefault(); move(1); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); move(-1); }
    else if (e.key === 'Enter') {
      var sel = results.querySelector('a.sel');
      if (sel) { e.preventDefault(); location.href = sel.href; }
    }
  });

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && !panel.hidden) { closeSearch(); return; }
    // `/` is the search key everywhere else; do not steal it from a field the
    // visitor is actually typing in.
    var tag = (e.target.tagName || '').toLowerCase();
    if (tag === 'input' || tag === 'textarea' || e.target.isContentEditable) return;
    if (e.key === '/' || ((e.metaKey || e.ctrlKey) && e.key === 'k')) {
      e.preventDefault();
      openSearch();
    }
  });
})();
