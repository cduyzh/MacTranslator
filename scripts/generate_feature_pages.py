#!/usr/bin/env python3
"""
Generate Quiet Native / SF Pro Minimalist SEO Landing Pages for iTrans / MacTranslate AI
Generates 5 pairs (EN + ZH-CN) = 10 HTML static pages + updates sitemap.xml.
"""
import os
import re

BASE_URL = "https://apps.cduyzh.top/iTrans"
OUTPUT_DIR = "/Users/hobby/gitlab-source/cduyzhTranslator/website"

# ── Shared CSS Style ────────────────────────────────────────────────────────
COMMON_CSS = """
:root {
  --bg-canvas: #f6f8fa;
  --bg-surface: #ffffff;
  --bg-subtle: #edf0f3;
  --bg-field: #fafbfc;
  --bg-tag: #e3e8ee;

  --text-primary: #1f2328;
  --text-secondary: #484f58;
  --text-tertiary: #57606a;
  --text-on-accent: #ffffff;

  --border-subtle: 0.8px solid rgba(27, 31, 36, 0.12);
  --border-strong: 0.8px solid rgba(27, 31, 36, 0.22);
  --border-focus: 1.5px solid #0969da;

  --accent: #0969da;
  --accent-hover: #0856b5;
  --accent-subtle: rgba(9, 105, 218, 0.08);

  --signal-success: #1a7f37;
  --signal-success-bg: rgba(26, 127, 55, 0.1);
  --signal-amber: #9a6700;
  --signal-amber-bg: rgba(217, 119, 6, 0.1);

  --radius-sm: 6px;
  --radius-md: 8px;
  --radius-lg: 12px;
  --radius-xl: 16px;

  --shadow-subtle: 0 1px 2px rgba(27, 31, 36, 0.04);
  --shadow-card: 0 4px 12px rgba(27, 31, 36, 0.06), 0 1px 2px rgba(27, 31, 36, 0.04);

  --font-display: "SF Pro Display", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  --font-sans: "SF Pro Text", -apple-system, BlinkMacSystemFont, "Helvetica Neue", "PingFang SC", sans-serif;
  --font-mono: "SF Mono", ui-monospace, Menlo, Monaco, Consolas, monospace;
}

* { box-sizing: border-box; margin: 0; padding: 0; }
html { scroll-behavior: smooth; }
body {
  background: var(--bg-canvas);
  color: var(--text-primary);
  font-family: var(--font-sans);
  font-size: 15px;
  line-height: 1.65;
  -webkit-font-smoothing: antialiased;
  overflow-x: hidden;
}
a { color: inherit; text-decoration: none; }
.mono { font-family: var(--font-mono); font-feature-settings: "tnum"; }

/* Nav */
.site-nav {
  position: sticky;
  top: 0;
  z-index: 100;
  background: rgba(246, 248, 250, 0.94);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border-bottom: var(--border-subtle);
}
.nav-container {
  max-width: 1080px;
  margin: 0 auto;
  padding: 0 24px;
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.brand-group {
  display: flex;
  align-items: center;
  gap: 10px;
}
.brand-icon {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.12);
  display: block;
}
.brand-name {
  font-family: var(--font-display);
  font-weight: 700;
  font-size: 16px;
  letter-spacing: -0.01em;
}
.brand-sub {
  font-size: 13px;
  font-weight: 400;
  color: var(--text-secondary);
  margin-left: 4px;
}
.nav-links {
  display: flex;
  align-items: center;
  gap: 20px;
}
.nav-link {
  font-size: 14px;
  font-weight: 500;
  color: var(--text-secondary);
  transition: color 0.15s ease;
}
.nav-link:hover, .nav-link.active {
  color: var(--accent);
}
.nav-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}
.lang-switch {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 13px;
  font-family: var(--font-mono);
  background: var(--bg-surface);
  border: var(--border-subtle);
  padding: 4px 8px;
  border-radius: var(--radius-sm);
}
.lang-link {
  color: var(--text-tertiary);
  font-weight: 500;
}
.lang-link.active {
  color: var(--accent);
  font-weight: 700;
}
.lang-sep {
  color: var(--text-tertiary);
  opacity: 0.5;
}

/* Buttons */
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  font-size: 13.5px;
  font-weight: 600;
  padding: 7px 14px;
  border-radius: var(--radius-md);
  transition: all 0.15s ease;
  cursor: pointer;
  border: none;
}
.btn-primary {
  background: var(--accent);
  color: var(--text-on-accent);
  box-shadow: 0 1px 2px rgba(9, 105, 218, 0.2);
}
.btn-primary:hover {
  background: var(--accent-hover);
}
.btn-secondary {
  background: var(--bg-surface);
  color: var(--text-primary);
  border: var(--border-subtle);
}
.btn-secondary:hover {
  background: var(--bg-subtle);
}

/* Main Layout */
.page-container {
  max-width: 960px;
  margin: 0 auto;
  padding: 36px 24px 80px;
}
.breadcrumb {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: var(--text-tertiary);
  margin-bottom: 24px;
}
.breadcrumb a:hover {
  color: var(--accent);
}
.breadcrumb-sep {
  opacity: 0.4;
}

/* Hero */
.page-header {
  margin-bottom: 40px;
  border-bottom: var(--border-subtle);
  padding-bottom: 32px;
}
.page-tag {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: var(--accent-subtle);
  color: var(--accent);
  font-size: 12.5px;
  font-weight: 600;
  padding: 3px 10px;
  border-radius: 16px;
  margin-bottom: 14px;
  border: 0.8px solid rgba(9, 105, 218, 0.2);
}
.page-title {
  font-family: var(--font-display);
  font-size: clamp(28px, 3.5vw, 40px);
  font-weight: 800;
  line-height: 1.18;
  letter-spacing: -0.025em;
  color: var(--text-primary);
  margin-bottom: 14px;
}
.page-lead {
  font-size: 16.5px;
  color: var(--text-secondary);
  line-height: 1.6;
  max-width: 760px;
}

/* Content blocks */
.content-section {
  margin-bottom: 48px;
}
.section-heading {
  font-family: var(--font-display);
  font-size: 22px;
  font-weight: 700;
  color: var(--text-primary);
  letter-spacing: -0.015em;
  margin-bottom: 16px;
}
.prose {
  font-size: 15px;
  color: var(--text-secondary);
  line-height: 1.7;
}
.prose p { margin-bottom: 16px; }
.prose strong { color: var(--text-primary); }

/* Plateau Card */
.card {
  background: var(--bg-surface);
  border: var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: 24px;
  box-shadow: var(--shadow-subtle);
  margin-bottom: 24px;
}
.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}
.card-title {
  font-size: 16px;
  font-weight: 700;
  color: var(--text-primary);
}

/* Callouts / Alerts */
.callout {
  padding: 16px 20px;
  border-radius: var(--radius-md);
  margin: 20px 0;
  font-size: 14px;
  line-height: 1.6;
}
.callout-info {
  background: var(--accent-subtle);
  border: 0.8px solid rgba(9, 105, 218, 0.25);
  color: #0856b5;
}
.callout-success {
  background: var(--signal-success-bg);
  border: 0.8px solid rgba(26, 127, 55, 0.25);
  color: var(--signal-success);
}
.callout-warning {
  background: var(--signal-amber-bg);
  border: 0.8px solid rgba(217, 119, 6, 0.25);
  color: var(--signal-amber);
}

/* Steps */
.step-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
  margin: 20px 0;
}
.step-item {
  display: flex;
  gap: 16px;
  background: var(--bg-surface);
  border: var(--border-subtle);
  border-radius: var(--radius-md);
  padding: 18px 20px;
  align-items: flex-start;
}
.step-num {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: var(--accent-subtle);
  color: var(--accent);
  display: grid;
  place-items: center;
  font-weight: 700;
  font-size: 13px;
  flex-shrink: 0;
  font-family: var(--font-mono);
}
.step-content h4 {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: 4px;
}
.step-content p {
  font-size: 14px;
  color: var(--text-secondary);
  line-height: 1.55;
}

/* Table */
.data-table-wrapper {
  overflow-x: auto;
  border: var(--border-subtle);
  border-radius: var(--radius-md);
  background: var(--bg-surface);
  margin: 20px 0;
}
.data-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 14px;
  text-align: left;
}
.data-table th, .data-table td {
  padding: 12px 16px;
  border-bottom: var(--border-subtle);
}
.data-table th {
  background: var(--bg-subtle);
  font-weight: 600;
  color: var(--text-primary);
  font-size: 13px;
}
.data-table tr:last-child td {
  border-bottom: none;
}
.term-pill {
  background: rgba(9, 105, 218, 0.1);
  color: var(--accent);
  padding: 2px 6px;
  border-radius: 4px;
  font-weight: 600;
  font-family: var(--font-mono);
  font-size: 12.5px;
}

/* Code block */
.code-block {
  background: #0d1117;
  color: #e6edf3;
  padding: 16px;
  border-radius: var(--radius-md);
  font-family: var(--font-mono);
  font-size: 13px;
  line-height: 1.6;
  overflow-x: auto;
  margin: 16px 0;
  border: 0.8px solid rgba(255, 255, 255, 0.1);
}

/* Download CTA Box */
.cta-box {
  background: linear-gradient(135deg, rgba(9, 105, 218, 0.05), rgba(9, 105, 218, 0.12));
  border: 0.8px solid rgba(9, 105, 218, 0.25);
  border-radius: var(--radius-xl);
  padding: 36px 32px;
  text-align: center;
  margin-top: 56px;
}
.cta-title {
  font-family: var(--font-display);
  font-size: 24px;
  font-weight: 800;
  color: var(--text-primary);
  margin-bottom: 10px;
}
.cta-desc {
  font-size: 15px;
  color: var(--text-secondary);
  max-width: 520px;
  margin: 0 auto 20px;
}
.cta-buttons {
  display: flex;
  justify-content: center;
  gap: 12px;
  flex-wrap: wrap;
}

/* Footer */
footer {
  border-top: var(--border-subtle);
  background: var(--bg-surface);
  padding: 40px 24px;
  color: var(--text-secondary);
  font-size: 13.5px;
}
.footer-container {
  max-width: 960px;
  margin: 0 auto;
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 16px;
}
.footer-links {
  display: flex;
  gap: 16px;
}
.footer-links a:hover {
  color: var(--accent);
}

@media (max-width: 768px) {
  .nav-links { display: none; }
  .footer-container { flex-direction: column; text-align: center; }
  .page-title { font-size: 26px; }
  .step-item { flex-direction: column; gap: 8px; }
}
"""

def generate_page(
    lang="en",
    slug="features/ai-api-key",
    title="",
    meta_desc="",
    h1="",
    lead="",
    tag="",
    breadcrumb_items=None,
    sections_html="",
    cta_title="",
    cta_desc="",
    schema_type="TechArticle",
    schema_extra=""
):
    is_zh = lang == "zh-CN"
    
    # URL construction
    if is_zh:
        page_url = f"{BASE_URL}/zh/{slug}/"
        counterpart_url = f"{BASE_URL}/{slug}/"
        home_url = f"{BASE_URL}/zh.html"
        docs_url = f"{BASE_URL}/zh/docs/agent-api/"
        download_url = f"{BASE_URL}/zh/download/"
        asset_prefix = "../../../" if slug.count('/') > 0 else "../../"
        brand_sub = "极译 AI"
        nav_features = "核心特性"
        nav_docs = "API 文档"
        nav_download = "下载安装"
        btn_download = "下载 Mac 版"
        en_active = ""
        zh_active = "active"
        og_image = f"{BASE_URL}/assets/og-zh.png"
    else:
        page_url = f"{BASE_URL}/{slug}/"
        counterpart_url = f"{BASE_URL}/zh/{slug}/"
        home_url = f"{BASE_URL}/"
        docs_url = f"{BASE_URL}/docs/agent-api/"
        download_url = f"{BASE_URL}/download/"
        asset_prefix = "../../" if slug.count('/') > 0 else "../"
        brand_sub = "MacTranslate AI"
        nav_features = "Features"
        nav_docs = "Docs"
        nav_download = "Download"
        btn_download = "Download for Mac"
        en_active = "active"
        zh_active = ""
        og_image = f"{BASE_URL}/assets/og-en.png"

    en_url = f"{BASE_URL}/{slug}/"
    zh_url = f"{BASE_URL}/zh/{slug}/"

    docs_active = "active" if "docs" in slug else ""
    download_active = "active" if "download" in slug else ""

    # Breadcrumbs HTML
    bc_html = f'<a href="{home_url}">{"首页" if is_zh else "Home"}</a>'
    bc_schema_items = [
        f'{{"@type": "ListItem", "position": 1, "name": "{"Home" if not is_zh else "首页"}", "item": "{home_url}"}}'
    ]
    if breadcrumb_items:
        for idx, (b_name, b_href) in enumerate(breadcrumb_items, start=2):
            if b_href:
                bc_html += f' <span class="breadcrumb-sep">/</span> <a href="{b_href}">{b_name}</a>'
            else:
                bc_html += f' <span class="breadcrumb-sep">/</span> <span>{b_name}</span>'
            bc_schema_items.append(f'{{"@type": "ListItem", "position": {idx}, "name": "{b_name}", "item": "{page_url}"}}')

    bc_schema_json = ",\n        ".join(bc_schema_items)

    html = f"""<!doctype html>
<html lang="{lang}">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{title}</title>
  <meta name="description" content="{meta_desc}" />
  <link rel="canonical" href="{page_url}" />
  <link rel="alternate" hreflang="en" href="{en_url}" />
  <link rel="alternate" hreflang="zh-CN" href="{zh_url}" />
  <link rel="alternate" hreflang="x-default" href="{en_url}" />
  
  <meta property="og:type" content="article" />
  <meta property="og:site_name" content="iTrans · MacTranslate AI" />
  <meta property="og:title" content="{title}" />
  <meta property="og:description" content="{meta_desc}" />
  <meta property="og:url" content="{page_url}" />
  <meta property="og:image" content="{og_image}" />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="{title}" />
  <meta name="twitter:description" content="{meta_desc}" />
  <meta name="twitter:image" content="{og_image}" />

  <script type="application/ld+json">
  {{
    "@context": "https://schema.org",
    "@graph": [
      {{
        "@type": "BreadcrumbList",
        "itemListElement": [
          {bc_schema_json}
        ]
      }},
      {{
        "@type": "{schema_type}",
        "headline": "{h1}",
        "description": "{meta_desc}",
        "url": "{page_url}",
        "inLanguage": "{lang}",
        "publisher": {{
          "@type": "Person",
          "name": "cduyzh",
          "url": "https://www.cduyzh.top"
        }}
        {schema_extra}
      }}
    ]
  }}
  </script>

  <style>
{COMMON_CSS}
  </style>
</head>
<body>
  <!-- Nav -->
  <header class="site-nav">
    <div class="nav-container">
      <a href="{home_url}" class="brand-group">
        <img class="brand-icon" src="{asset_prefix}assets/app-icon.png" alt="iTrans App Icon" width="32" height="32" />
        <div class="brand-name">iTrans <span class="brand-sub">{brand_sub}</span></div>
      </a>
      <nav class="nav-links">
        <a href="{home_url}#features" class="nav-link">{nav_features}</a>
        <a href="{docs_url}" class="nav-link {docs_active}">{nav_docs}</a>
        <a href="{download_url}" class="nav-link {download_active}">{nav_download}</a>
      </nav>
      <div class="nav-actions">
        <div class="lang-switch">
          <a href="{en_url}" class="lang-link {en_active}">EN</a>
          <span class="lang-sep">/</span>
          <a href="{zh_url}" class="lang-link {zh_active}">中</a>
        </div>
        <a href="https://github.com/cduyzh/iTrans" class="btn btn-secondary mono" target="_blank" rel="noopener">GitHub</a>
        <a href="{download_url}" class="btn btn-primary">{btn_download}</a>
      </div>
    </div>
  </header>

  <!-- Page Body -->
  <main class="page-container">
    <nav aria-label="Breadcrumb" class="breadcrumb">
      {bc_html}
    </nav>

    <header class="page-header">
      <div class="page-tag mono">{tag}</div>
      <h1 class="page-title">{h1}</h1>
      <p class="page-lead">{lead}</p>
    </header>

    {sections_html}

    <!-- CTA -->
    <div class="cta-box">
      <h3 class="cta-title">{cta_title}</h3>
      <p class="cta-desc">{cta_desc}</p>
      <div class="cta-buttons">
        <a href="{download_url}" class="btn btn-primary" style="padding: 10px 22px; font-size: 15px;">
          {btn_download}
        </a>
        <a href="https://github.com/cduyzh/iTrans" class="btn btn-secondary mono" style="padding: 10px 20px; font-size: 15px;" target="_blank" rel="noopener">
          View on GitHub
        </a>
      </div>
    </div>
  </main>

  <!-- Footer -->
  <footer>
    <div class="footer-container">
      <span>© 2026 cduyzh · iTrans · MacTranslate AI · All rights reserved.</span>
      <div class="footer-links">
        <a href="https://www.cduyzh.top" target="_blank" rel="noopener">cduyzh.top</a>
        <a href="https://www.cduyzh.top/goal" target="_blank" rel="noopener">Goal</a>
        <a href="https://github.com/cduyzh/iTrans" target="_blank" rel="noopener">GitHub</a>
        <a href="https://opensource.org/licenses/MIT" target="_blank" rel="noopener">MIT License</a>
      </div>
    </div>
  </footer>
</body>
</html>
"""
    return html

print("Generator script loaded.")