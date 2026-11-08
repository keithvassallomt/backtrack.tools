/* backtrack.tools: the theme switch, the copy buttons, and the home page's
   working Rewind, stories, day on a laptop and cards. All of it is added to
   pages that read in full without it. */
(function () {
  'use strict';

  var root = document.documentElement;
  var phone = window.matchMedia('(max-width: 860px)');
  var reduced = window.matchMedia('(prefers-reduced-motion: reduce)');
  var each = function (list, fn) { Array.prototype.forEach.call(list, fn); };

  // A click from the keyboard has no pointer; a mouse click is told apart
  // from a tap by the pointer that started it.
  var lastPointer = null;
  document.addEventListener('pointerdown', function (e) { lastPointer = e.pointerType; }, true);
  function clickKind(e) {
    if (e.detail === 0) return 'keyboard';
    var kind = e.pointerType || lastPointer || 'mouse';
    return kind === 'mouse' ? 'mouse' : 'touch';
  }

  /* ---- Theme: the system's, unless the visitor chose the other one ---- */

  var systemLight = window.matchMedia('(prefers-color-scheme: light)');
  var choice = null;
  try { choice = window.localStorage.getItem('bt-theme'); } catch (e) { choice = null; }
  if (choice !== 'light' && choice !== 'dark') choice = null;
  var themeButton = document.querySelector('.b-theme');

  function applyTheme() {
    var light = choice ? choice === 'light' : systemLight.matches;
    root.classList.toggle('light', light);
    root.classList.toggle('dark', !light);
    if (themeButton) themeButton.setAttribute('aria-label', light ? 'Switch to the dark theme' : 'Switch to the light theme');
  }
  if (themeButton) {
    themeButton.hidden = false;
    themeButton.addEventListener('click', function () {
      var next = root.classList.contains('light') ? 'dark' : 'light';
      var system = systemLight.matches ? 'light' : 'dark';
      // A choice that matches the system is forgotten, so the page follows
      // the system again from then on.
      choice = next === system ? null : next;
      try {
        if (choice) window.localStorage.setItem('bt-theme', choice);
        else window.localStorage.removeItem('bt-theme');
      } catch (e) { /* the choice lasts this visit only */ }
      applyTheme();
    });
  }
  systemLight.addEventListener('change', applyTheme);
  applyTheme();

  /* ---- Copy buttons: the home page's commands, and those in the guides ---- */

  var COPY_ICONS = '<svg class="idle" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V6a2 2 0 0 1 2-2h9"/></svg><svg class="ok" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg><span class="lbl" aria-hidden="true">Copied</span>';
  var copiedSay = document.querySelector('.b-copied');

  function announceCopied(text) {
    if (!copiedSay) {
      copiedSay = document.createElement('span');
      copiedSay.className = 'sr';
      copiedSay.setAttribute('aria-live', 'polite');
      document.body.appendChild(copiedSay);
    }
    copiedSay.textContent = text;
  }

  function copy(code, button) {
    var done = function () {
      button.classList.add('done');
      announceCopied('Copied');
      clearTimeout(button.copyTimer);
      button.copyTimer = setTimeout(function () { button.classList.remove('done'); announceCopied(''); }, 1800);
    };
    // Where the clipboard API is refused, copy through a selection instead.
    var fallback = function () {
      try {
        var selection = window.getSelection();
        var range = document.createRange();
        range.selectNodeContents(code);
        selection.removeAllRanges();
        selection.addRange(range);
        var worked = document.execCommand('copy');
        selection.removeAllRanges();
        if (worked) done();
      } catch (e) { /* nothing copied, so nothing to say */ }
    };
    var text = code.textContent.replace(/\n+$/, '');
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(done, fallback);
      else fallback();
    } catch (e) { fallback(); }
  }

  each(document.querySelectorAll('.b-cmd'), function (row) {
    var button = row.querySelector('.b-copy');
    button.hidden = false;
    button.addEventListener('click', function () { copy(row.querySelector('code'), button); });
  });
  each(document.querySelectorAll('.prose pre > code.language-sh, .prose pre > code.language-bash, .prose pre > code.language-shell'), function (code) {
    var pre = code.parentNode;
    var button = document.createElement('button');
    button.type = 'button';
    button.className = 'b-copy';
    button.setAttribute('aria-label', /\n./.test(code.textContent.trim()) ? 'Copy the commands' : 'Copy the command');
    button.innerHTML = COPY_ICONS;
    button.addEventListener('click', function () { copy(code, button); });
    pre.classList.add('has-copy');
    pre.appendChild(button);
  });

  /* ---- A guide's contents: the section being read is marked ---- */

  var tocLinks = document.querySelectorAll('.b-toc a[href^="#"]');
  if (tocLinks.length && 'IntersectionObserver' in window) {
    var byId = {};
    each(tocLinks, function (a) { byId[decodeURIComponent(a.getAttribute('href').slice(1))] = a; });
    var headings = Array.prototype.filter.call(document.querySelectorAll('.prose h2[id], .prose h3[id]'), function (h) { return byId[h.id]; });
    var mark = function () {
      var current = null;
      each(headings, function (h) { if (h.getBoundingClientRect().top < window.innerHeight * 0.3) current = h; });
      each(tocLinks, function (a) { a.classList.toggle('here', !!current && a === byId[current.id]); });
    };
    var observer = new IntersectionObserver(mark, { rootMargin: '0px 0px -70% 0px' });
    each(headings, function (h) { observer.observe(h); });
    mark();
  }

  /* ---- The home page ---- */

  var closers = [];
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') closers.forEach(function (close) { close(true); });
  });

  rewind(document.querySelector('.b-hero-grid'));
  stories(document.querySelector('.b-railwrap'));
  day(document.querySelector('.b-day'));
  homes(document.querySelectorAll('.b-home'));

  // The opening: a Documents folder, rewound a backup at a time.
  function rewind(grid) {
    if (!grid) return;
    var data = JSON.parse(document.getElementById('rewind-data').textContent);
    var backups = data.backups;
    var files = data.files;
    var n = backups.length;
    var backs = grid.querySelectorAll('.b-back');
    var folder = grid.querySelector('.b-files');
    var whens = [grid.querySelector('.b-bar .when'), grid.querySelector('.b-cap b')];
    var count = grid.querySelector('.b-cap span');
    var list = grid.querySelector('.b-tl-list');
    var ticks = list.querySelectorAll('.b-tick');
    var older = grid.querySelector('.b-tl-arrow.older');
    var newer = grid.querySelector('.b-tl-arrow.newer');
    var say = grid.querySelector('.b-under .sr');
    var deck = grid.querySelector('.b-deck');
    var i = 0;
    var steps = 0;
    var sayTimer = null;

    var caption = function (k) {
      return k === 0 ? 'The folder as it is now' : 'Backup ' + k + ' of ' + (n - 1) + ' with changes to this folder';
    };
    var escape = function (s) {
      return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; });
    };
    var FOLDER = '<svg viewBox="0 0 48 40" aria-hidden="true"><path class="fold" d="M2 6a4 4 0 0 1 4-4h12l5 5h19a4 4 0 0 1 4 4v23a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4z"/><path class="fold2" d="M2 13h44" stroke-width="2"/></svg>';
    var DOC = '<svg viewBox="0 0 40 48" aria-hidden="true"><path class="page" d="M5 1h20l12 12v30a4 4 0 0 1-4 4H5a4 4 0 0 1-4-4V5a4 4 0 0 1 4-4z"/><path class="page2" d="M25 1v9a3 3 0 0 0 3 3h9z"/></svg>';

    // One missing from the newest backup is deleted; one whose copy differs
    // from the newest backup's is changed.
    var fileHtml = function (f) {
      var badge = '';
      if (i >= 1) {
        if (f.to > 1) badge = 'deleted';
        else if (f.changedFrom && i >= f.changedFrom) badge = 'changed';
      }
      return '<div class="b-f" role="listitem"><span class="ic">' +
        (f.folder ? FOLDER : DOC + '<span class="ext">' + escape(f.ext) + '</span>') +
        '</span><span class="nm">' + escape(f.name) + '</span>' +
        (badge ? '<i class="b-badge ' + badge + '">' + badge + '</i>' : '') + '</div>';
    };

    var orient = function () {
      list.setAttribute('aria-orientation', phone.matches ? 'horizontal' : 'vertical');
      // Down the side, up is older; along the bottom on a phone, left is.
      list.setAttribute('aria-valuenow', String(phone.matches ? n - 1 - i : i));
    };

    var render = function () {
      each(backs, function (el, k) {
        var d = k - i;
        el.className = 'b-back ' + (d < 0 ? 'past' : d === 0 ? 'd0' : d <= 5 ? 'd' + d : 'far');
      });
      folder.innerHTML = files.filter(function (f) { return f.to <= i && i <= f.from; }).map(fileHtml).join('');
      folder.className = 'b-files ' + (steps % 2 ? 'swapA' : 'swapB');
      whens.forEach(function (el) { el.textContent = backups[i].when; });
      count.textContent = caption(i);
      each(ticks, function (t) { t.classList.toggle('cur', Number(t.getAttribute('data-k')) === i); });
      older.setAttribute('aria-disabled', String(i === n - 1));
      newer.setAttribute('aria-disabled', String(i === 0));
      list.setAttribute('aria-valuetext', backups[i].when);
      orient();
    };

    // Moves the stack; true when it moved. The announcement waits until the
    // stack has rested, so a held key is not read out backup by backup.
    var go = function (j) {
      var k = Math.max(0, Math.min(n - 1, j));
      if (k === i) return false;
      i = k;
      steps += 1;
      render();
      clearTimeout(sayTimer);
      sayTimer = setTimeout(function () { say.textContent = backups[i].when + '. ' + caption(i); }, 700);
      return true;
    };

    phone.addEventListener('change', orient);
    orient();

    older.addEventListener('click', function () { go(i + 1); });
    newer.addEventListener('click', function () { go(i - 1); });

    // Rewind's own keys. Where the stack cannot move, the key keeps its
    // usual job, so the page still scrolls.
    var keyTarget = function (key) {
      if (key === 'ArrowUp' || key === 'PageUp') return i + 1;
      if (key === 'ArrowDown' || key === 'PageDown') return i - 1;
      if (key === 'Home') return 0;
      if (key === 'End') return n - 1;
      return null;
    };
    grid.addEventListener('keydown', function (e) {
      var j = keyTarget(e.key);
      if (j !== null && go(j)) e.preventDefault();
    });
    // With nothing focused, ↑ and ↓ work the stack while the opening is on
    // screen.
    document.addEventListener('keydown', function (e) {
      if (e.defaultPrevented || e.altKey || e.ctrlKey || e.metaKey || e.shiftKey) return;
      if (e.key !== 'ArrowUp' && e.key !== 'ArrowDown') return;
      var active = document.activeElement;
      if (active && active !== document.body && active !== root) return;
      var r = grid.getBoundingClientRect();
      var middle = window.innerHeight / 2;
      if (r.top > middle || r.bottom < middle) return;
      if (go(keyTarget(e.key))) e.preventDefault();
    });

    // The timeline is one slider: its arrow keys follow its orientation, and
    // a press or a drag picks the nearest backup.
    list.addEventListener('keydown', function (e) {
      var key = e.key;
      var isOlder = phone.matches ? (key === 'ArrowLeft' || key === 'ArrowDown') : (key === 'ArrowUp' || key === 'ArrowRight');
      var isNewer = phone.matches ? (key === 'ArrowRight' || key === 'ArrowUp') : (key === 'ArrowDown' || key === 'ArrowLeft');
      if (!isOlder && !isNewer) return;
      e.stopPropagation();
      if (go(i + (isOlder ? 1 : -1))) e.preventDefault();
    });
    var dragging = false;
    var pickAt = function (e) {
      var horizontal = phone.matches;
      var at = horizontal ? e.clientX : e.clientY;
      var best = null;
      var bestDistance = Infinity;
      each(ticks, function (t) {
        var r = t.getBoundingClientRect();
        var centre = horizontal ? r.left + r.width / 2 : r.top + r.height / 2;
        var d = Math.abs(at - centre);
        if (d < bestDistance) { bestDistance = d; best = t; }
      });
      if (best) go(Number(best.getAttribute('data-k')));
    };
    list.addEventListener('pointerdown', function (e) {
      dragging = true;
      try { list.setPointerCapture(e.pointerId); } catch (x) { /* a drag still works without capture */ }
      pickAt(e);
    });
    list.addEventListener('pointermove', function (e) { if (dragging) pickAt(e); });
    list.addEventListener('pointerup', function () { dragging = false; });
    list.addEventListener('pointercancel', function () { dragging = false; });

    // A sideways swipe on the card: to the left is back in time.
    var start = null;
    deck.addEventListener('pointerdown', function (e) { start = { x: e.clientX, y: e.clientY, type: e.pointerType }; });
    deck.addEventListener('pointerup', function (e) {
      if (!start) return;
      var dx = e.clientX - start.x;
      var dy = e.clientY - start.y;
      var touch = start.type === 'touch' || start.type === 'pen';
      start = null;
      if ((touch || phone.matches) && Math.abs(dx) > 40 && Math.abs(dx) > Math.abs(dy) * 1.2) go(i + (dx < 0 ? 1 : -1));
    });
    deck.addEventListener('pointercancel', function () { start = null; });
  }

  // Five stories in a sideways rail; each opens up on hover or a tap.
  function stories(wrap) {
    if (!wrap) return;
    var rail = wrap.querySelector('.b-rail');
    var cards = rail.querySelectorAll('.b-story');
    var zoom = wrap.querySelector('.b-szoom');
    var closeButton = zoom.querySelector('.b-close');
    var dots = document.querySelectorAll('.b-dots i');
    var prev = document.querySelector('.b-step.prev');
    var next = document.querySelector('.b-step.next');
    var openCard = null;
    var hoverTimer = null;
    var atStart = true;
    var atEnd = false;

    var gap = function () { return parseFloat(window.getComputedStyle(rail).columnGap) || 20; };
    var stride = function () { return cards[0].offsetWidth + gap(); };
    var read = function () {
      var max = rail.scrollWidth - rail.clientWidth;
      atStart = rail.scrollLeft < 8;
      atEnd = rail.scrollLeft >= max - 8;
      var first = Math.round(rail.scrollLeft / stride());
      var shown = Math.max(1, Math.floor((rail.clientWidth + gap()) / stride()));
      wrap.classList.toggle('fl', !atStart);
      wrap.classList.toggle('fr', !atEnd);
      prev.setAttribute('aria-disabled', String(atStart));
      next.setAttribute('aria-disabled', String(atEnd));
      each(dots, function (dot, k) { dot.classList.toggle('on', k >= first && k < first + shown); });
    };
    var scroll = function (dir) { rail.scrollBy({ left: dir * stride(), behavior: reduced.matches ? 'auto' : 'smooth' }); };

    var open = function (card, focusClose) {
      zoom.querySelector('.n').textContent = card.querySelector('.n').textContent;
      zoom.querySelector('h3').textContent = card.querySelector('.t').textContent;
      zoom.querySelector('.text').textContent = card.getAttribute('data-text');
      var guide = zoom.querySelector('.b-guide a');
      guide.href = card.getAttribute('data-href');
      guide.textContent = card.getAttribute('data-guide') + ' →';
      var from = card.querySelector('img');
      var img = zoom.querySelector('img');
      img.src = from.currentSrc || from.src;
      img.width = from.width;
      img.height = from.height;
      img.alt = card.getAttribute('data-alt');
      // Over the card on a wide screen, kept inside the page.
      var left = 0;
      if (!phone.matches) {
        var wr = wrap.getBoundingClientRect();
        var cr = card.getBoundingClientRect();
        var gut = parseFloat(window.getComputedStyle(root).getPropertyValue('--gut')) || 48;
        var w = zoom.offsetWidth;
        left = Math.max(0, Math.min(cr.left - wr.left + cr.width / 2 - w / 2, wr.width - w - gut));
      }
      zoom.style.left = Math.round(left) + 'px';
      openCard = card;
      zoom.classList.add('open');
      zoom.setAttribute('aria-hidden', 'false');
      each(cards, function (c) { c.setAttribute('aria-expanded', String(c === card)); });
      if (focusClose) setTimeout(function () { closeButton.focus({ preventScroll: true }); }, 60);
    };
    var close = function (returnFocus) {
      if (!openCard) return;
      var card = openCard;
      openCard = null;
      zoom.classList.remove('open');
      zoom.setAttribute('aria-hidden', 'true');
      card.setAttribute('aria-expanded', 'false');
      if (returnFocus === true) card.focus({ preventScroll: true });
    };
    closers.push(function (returnFocus) { if (openCard) close(returnFocus); });

    each(cards, function (card) {
      card.addEventListener('pointerenter', function (e) {
        if (e.pointerType !== 'mouse') return;
        clearTimeout(hoverTimer);
        hoverTimer = setTimeout(function () { open(card, false); }, 260);
      });
      card.addEventListener('pointerleave', function (e) { if (e.pointerType === 'mouse') clearTimeout(hoverTimer); });
      card.addEventListener('click', function (e) {
        clearTimeout(hoverTimer);
        open(card, clickKind(e) !== 'mouse');
      });
    });
    zoom.addEventListener('pointerleave', function (e) { if (e.pointerType === 'mouse') close(false); });
    zoom.addEventListener('focusout', function (e) { if (!zoom.contains(e.relatedTarget)) close(false); });
    closeButton.addEventListener('click', function () { close(true); });
    document.addEventListener('pointerdown', function (e) {
      if (openCard && !e.target.closest('.b-szoom') && !e.target.closest('.b-story')) close(false);
    });

    rail.addEventListener('scroll', function () { if (!phone.matches) close(false); read(); }, { passive: true });
    prev.addEventListener('click', function () { if (!atStart) scroll(-1); });
    next.addEventListener('click', function () { if (!atEnd) scroll(1); });
    if ('ResizeObserver' in window) new ResizeObserver(read).observe(rail);
    read();
  }

  // One day on a laptop: pick a moment, and the panel says what happened.
  function day(box) {
    if (!box) return;
    var chips = box.querySelectorAll('.b-chip');
    var when = box.querySelector('.b-day-say .when');
    var text = box.querySelector('.b-day-say p');
    var pick = function (key) {
      box.className = 'b-day sel-' + key;
      each(chips, function (chip) {
        var on = chip.getAttribute('data-day') === key;
        chip.classList.toggle('on', on);
        chip.setAttribute('aria-pressed', String(on));
        if (on) {
          when.textContent = chip.getAttribute('data-when');
          text.textContent = chip.getAttribute('data-text');
        }
      });
    };
    each(chips, function (chip) {
      chip.addEventListener('click', function () { pick(chip.getAttribute('data-day')); });
    });
    each(box.querySelectorAll('.b-day-track [data-day]'), function (el) {
      el.addEventListener('pointerenter', function (e) { if (e.pointerType === 'mouse') pick(el.getAttribute('data-day')); });
      el.addEventListener('click', function () { pick(el.getAttribute('data-day')); });
    });
  }

  // At home: each card opens up on hover or a tap, with more and a picture.
  function homes(cards) {
    if (!cards.length) return;
    var openCard = null;
    var hoverTimer = null;
    var set = function (card) {
      openCard = card;
      each(cards, function (c) {
        var on = c === card;
        c.classList.toggle('open', on);
        c.querySelector('.b-home-btn').setAttribute('aria-expanded', String(on));
        c.querySelector('.b-zoom').setAttribute('aria-hidden', String(!on));
      });
    };
    closers.push(function (returnFocus) {
      if (!openCard) return;
      var card = openCard;
      set(null);
      if (returnFocus === true) card.querySelector('.b-home-btn').focus({ preventScroll: true });
    });
    each(cards, function (card) {
      var button = card.querySelector('.b-home-btn');
      card.addEventListener('pointerenter', function (e) {
        if (e.pointerType !== 'mouse') return;
        clearTimeout(hoverTimer);
        hoverTimer = setTimeout(function () { set(card); }, 220);
      });
      card.addEventListener('pointerleave', function (e) {
        if (e.pointerType !== 'mouse') return;
        clearTimeout(hoverTimer);
        if (openCard === card) set(null);
      });
      button.addEventListener('click', function (e) {
        clearTimeout(hoverTimer);
        if (clickKind(e) === 'mouse') set(card);
        else set(openCard === card ? null : card);
      });
      card.addEventListener('focusout', function (e) {
        if (openCard === card && !card.contains(e.relatedTarget)) set(null);
      });
      card.querySelector('.b-close').addEventListener('click', function () {
        set(null);
        button.focus({ preventScroll: true });
      });
    });
    document.addEventListener('pointerdown', function (e) {
      if (openCard && !e.target.closest('.b-home.open')) set(null);
    });
  }
})();
