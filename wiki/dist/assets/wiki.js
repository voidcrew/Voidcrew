/* Voidcrew wiki: client-side search + mobile nav. No dependencies. */
(function () {
  "use strict";

  var toggle = document.getElementById("nav-toggle");
  var sidebar = document.getElementById("sidebar");
  if (toggle && sidebar) {
    toggle.addEventListener("click", function () {
      sidebar.classList.toggle("open");
    });
  }

  var input = document.getElementById("search");
  var resultsBox = document.getElementById("search-results");
  if (!input || !resultsBox) return;

  var index = null;

  function loadIndex(cb) {
    if (index) return cb();
    fetch("search-index.json")
      .then(function (r) { return r.json(); })
      .then(function (data) { index = data; cb(); })
      .catch(function () { index = []; cb(); });
  }

  function snippet(text, q) {
    var i = text.toLowerCase().indexOf(q);
    if (i < 0) return text.slice(0, 110);
    var start = Math.max(0, i - 40);
    return (start > 0 ? "…" : "") + text.slice(start, i + q.length + 70) + "…";
  }

  function search(q) {
    q = q.trim().toLowerCase();
    if (q.length < 2) { resultsBox.hidden = true; resultsBox.innerHTML = ""; return; }
    loadIndex(function () {
      var hits = [];
      for (var i = 0; i < index.length; i++) {
        var p = index[i];
        var inTitle = p.title.toLowerCase().indexOf(q) >= 0;
        var inText = p.text.toLowerCase().indexOf(q) >= 0;
        if (inTitle || inText) hits.push({ p: p, score: inTitle ? 0 : 1 });
      }
      hits.sort(function (a, b) { return a.score - b.score; });
      hits = hits.slice(0, 10);
      if (!hits.length) {
        resultsBox.innerHTML = '<div class="empty">No results.</div>';
      } else {
        resultsBox.innerHTML = hits.map(function (h) {
          return '<a href="' + h.p.url + '"><span class="r-title">' + h.p.title +
            '</span><span class="r-cat">' + h.p.category + '</span>' +
            '<span class="r-snip">' + escapeHtml(snippet(h.p.text, q)) + "</span></a>";
        }).join("");
      }
      resultsBox.hidden = false;
    });
  }

  function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  var timer = null;
  input.addEventListener("input", function () {
    clearTimeout(timer);
    timer = setTimeout(function () { search(input.value); }, 120);
  });
  input.addEventListener("focus", function () { if (input.value) search(input.value); });
  document.addEventListener("click", function (e) {
    if (!resultsBox.contains(e.target) && e.target !== input) resultsBox.hidden = true;
  });
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape") { resultsBox.hidden = true; input.blur(); }
    if (e.key === "/" && document.activeElement !== input) { e.preventDefault(); input.focus(); }
  });
})();
