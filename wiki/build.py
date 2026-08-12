#!/usr/bin/env python3
"""Build the Voidcrew wiki.

Converts wiki/content/*.md into a static HTML site in wiki/dist/, ready to
upload to S3 (or any static file host):

    python wiki/build.py
    aws s3 sync wiki/dist s3://<your-bucket> --delete

Every page carries simple frontmatter:

    ---
    title: Piloting Your Ship
    category: Your Ship
    order: 1
    blurb: One line shown on the front page and in search results.
    ---

Files whose names start with an underscore are skipped (templates, notes).
The markdown converter is vendored in wiki/tools/vendor, no pip install
needed to run this.
"""
from __future__ import annotations

import html
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools" / "vendor"))

import markdown  # vendored

CONTENT = ROOT / "content"
ASSETS = ROOT / "assets"
DIST = ROOT / "dist"

SITE_NAME = "Voidcrew Wiki"
TAGLINE = "A crew, a ship, and the void."
CATEGORY_ORDER = [
    "Getting Started",
    "Your Ship",
    "The Fleet",
    "Exploration",
    "Economy",
    "Danger",
]

MD_EXTENSIONS = ["extra", "toc", "sane_lists", "admonition"]


def parse_frontmatter(text: str) -> tuple[dict, str]:
    meta: dict[str, str] = {}
    if text.startswith("---"):
        parts = text.split("---", 2)
        if len(parts) >= 3:
            for line in parts[1].splitlines():
                if ":" in line:
                    key, _, value = line.partition(":")
                    meta[key.strip().lower()] = value.strip()
            return meta, parts[2]
    return meta, text


class Page:
    def __init__(self, path: Path):
        raw = path.read_text(encoding="utf-8")
        meta, body = parse_frontmatter(raw)
        self.name = path.stem
        self.title = meta.get("title", self.name.replace("-", " ").title())
        self.category = meta.get("category", "Misc")
        self.order = float(meta.get("order", 99))
        self.blurb = meta.get("blurb", "")
        md = markdown.Markdown(extensions=MD_EXTENSIONS)
        self.body_html = md.convert(body)
        # Rewrite in-wiki links: foo.md -> foo.html
        self.body_html = re.sub(
            r'href="([A-Za-z0-9_-]+)\.md(#[^"]*)?"',
            r'href="\1.html\2"',
            self.body_html,
        )
        self.toc_html = md.toc if getattr(md, "toc_tokens", None) and len(md.toc_tokens) > 1 else ""
        # Tags first, then entities. search_text is plain text: the client
        # escapes it again before putting a snippet on the page, so an "&amp;"
        # left in here reaches the reader as a literal "&amp;".
        stripped = re.sub(r"<[^>]+>", " ", self.body_html)
        self.search_text = re.sub(r"\s+", " ", html.unescape(stripped)).strip()

    @property
    def url(self) -> str:
        return f"{self.name}.html"


def sidebar_html(pages: list[Page], current: Page | None) -> str:
    by_cat: dict[str, list[Page]] = {}
    for p in pages:
        by_cat.setdefault(p.category, []).append(p)
    cats = [c for c in CATEGORY_ORDER if c in by_cat]
    cats += sorted(c for c in by_cat if c not in CATEGORY_ORDER)
    out = ['<nav class="sidebar" id="sidebar">']
    out.append(f'<a class="home-link" href="index.html">&#x2726; {SITE_NAME}</a>')
    for cat in cats:
        out.append(f"<h3>{html.escape(cat)}</h3><ul>")
        for p in sorted(by_cat[cat], key=lambda p: (p.order, p.title)):
            cls = ' class="active"' if current and p.name == current.name else ""
            out.append(f'<li{cls}><a href="{p.url}">{html.escape(p.title)}</a></li>')
        out.append("</ul>")
    out.append("</nav>")
    return "\n".join(out)


def shell(title: str, sidebar: str, main: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)} | {SITE_NAME}</title>
<link rel="stylesheet" href="assets/style.css">
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='80' font-size='80'>&#128760;</text></svg>">
</head>
<body>
<header class="topbar">
<button class="nav-toggle" id="nav-toggle" aria-label="Menu">&#9776;</button>
<a class="site-name" href="index.html">{SITE_NAME}</a>
<div class="search-wrap">
<input type="search" id="search" placeholder="Search the wiki&hellip;" autocomplete="off">
<div id="search-results" hidden></div>
</div>
</header>
<div class="layout">
{sidebar}
<main class="content">
{main}
<footer>Voidcrew is a /tg/station fork. This wiki covers Voidcrew-specific systems; for base-game mechanics (chemistry, surgery, engineering&hellip;) see the <a href="https://wiki.tgstation13.org/">/tg/station wiki</a>.</footer>
</main>
</div>
<script src="assets/wiki.js"></script>
</body>
</html>
"""


def render_page(page: Page, pages: list[Page]) -> str:
    toc = f'<aside class="toc"><div class="toc-title">On this page</div>{page.toc_html}</aside>' if page.toc_html else ""
    main = f"<article>{toc}<h1>{html.escape(page.title)}</h1>\n{page.body_html}</article>"
    return shell(page.title, sidebar_html(pages, page), main)


def render_index(index_page: Page | None, pages: list[Page]) -> str:
    by_cat: dict[str, list[Page]] = {}
    for p in pages:
        by_cat.setdefault(p.category, []).append(p)
    cats = [c for c in CATEGORY_ORDER if c in by_cat]
    cats += sorted(c for c in by_cat if c not in CATEGORY_ORDER)
    parts = []
    parts.append(f'<div class="hero"><h1>{SITE_NAME}</h1><p class="tagline">{TAGLINE}</p></div>')
    if index_page:
        parts.append(index_page.body_html)
    parts.append('<div class="card-grid">')
    for cat in cats:
        parts.append(f'<section class="card"><h2>{html.escape(cat)}</h2><ul>')
        for p in sorted(by_cat[cat], key=lambda p: (p.order, p.title)):
            blurb = f' <span class="blurb">&mdash; {html.escape(p.blurb)}</span>' if p.blurb else ""
            parts.append(f'<li><a href="{p.url}">{html.escape(p.title)}</a>{blurb}</li>')
        parts.append("</ul></section>")
    parts.append("</div>")
    return shell("Home", sidebar_html(pages, None), "\n".join(parts))


def main() -> None:
    # Clear contents rather than deleting dist/ itself: Windows locks the
    # directory while Explorer or a terminal is sitting in it.
    DIST.mkdir(parents=True, exist_ok=True)
    for entry in DIST.iterdir():
        if entry.is_dir():
            shutil.rmtree(entry)
        else:
            entry.unlink()
    shutil.copytree(ASSETS, DIST / "assets", dirs_exist_ok=True)

    index_page: Page | None = None
    pages: list[Page] = []
    for path in sorted(CONTENT.glob("*.md")):
        if path.stem.startswith("_"):
            continue
        page = Page(path)
        if page.name == "index":
            index_page = page
        else:
            pages.append(page)

    for page in pages:
        (DIST / page.url).write_text(render_page(page, pages), encoding="utf-8")

    (DIST / "index.html").write_text(render_index(index_page, pages), encoding="utf-8")

    not_found = '<article><h1>Page not found</h1><p>That page has drifted off into the void. <a href="index.html">Return to the wiki home</a>.</p></article>'
    (DIST / "404.html").write_text(shell("Not found", sidebar_html(pages, None), not_found), encoding="utf-8")

    search_index = [
        {"title": p.title, "url": p.url, "category": p.category, "blurb": p.blurb, "text": p.search_text[:6000]}
        for p in pages
    ]
    (DIST / "search-index.json").write_text(json.dumps(search_index), encoding="utf-8")

    print(f"Built {len(pages) + 1} pages -> {DIST}")


if __name__ == "__main__":
    main()
