#!/usr/bin/env python3
"""
Generate the 5 pairs (10 pages) of feature and download pages for iTrans / MacTranslate AI.
Also updates website/sitemap.xml.
"""
import os
import sys

# Add script dir to path
sys.path.insert(0, '/Users/hobby/gitlab-source/cduyzhTranslator/scripts')
from generate_feature_pages import generate_page, OUTPUT_DIR, BASE_URL

pages_data = [
    # ── 1. AI API Key (BYOK) ────────────────────────────────────────────────
    {
        "slug": "features/ai-api-key",
        "tag_en": "BYOK ARCHITECTURE",
        "tag_zh": "BYOK 自带密钥架构",
        "title_en": "BYOK AI Translator for Mac – DeepSeek API | MacTranslate AI",
        "title_zh": "Mac 自定义 AI API 翻译 - DeepSeek API Key｜极译 AI",
        "meta_en": "Configure your own DeepSeek API key, compatible endpoint, model, and translation instructions in a native Mac translator. Learn how the BYOK workflow works.",
        "meta_zh": "极译 AI 支持用户配置 DeepSeek API Key、兼容接口、模型与翻译指令。了解 Mac 大模型翻译如何配置，以及第三方 API 的用量与隐私注意事项。",
        "h1_en": "Bring Your Own API Key for AI Translation on Mac",
        "h1_zh": "用自己的 API Key，在 Mac 上进行 AI 翻译",
        "lead_en": "Connect your own DeepSeek API key or OpenAI-compatible endpoint directly to your Mac. Pay official provider rates with zero markup, retain full control over reasoning models, and keep keys locked in private local files.",
        "lead_zh": "直接在 macOS 中接入自己的 DeepSeek API Key 或兼容端点。按官方服务商费率计费无中间商差价，自由掌控大模型思考深度与专属指令，密钥保存在本机 0600 私有文件中。",
        "bc_en": [("Features", f"{BASE_URL}/#features"), ("AI API Key", "")],
        "bc_zh": [("核心特性", f"{BASE_URL}/zh.html#features"), ("自定义 AI API Key", "")],
        "cta_title_en": "Start translating with your own AI key",
        "cta_title_zh": "立即用上专属的 AI 翻译模型",
        "cta_desc_en": "Download iTrans for macOS 14+ and configure your DeepSeek API key in under 60 seconds.",
        "cta_desc_zh": "免费下载适用于 macOS 14+ 的 iTrans，不到一分钟即可完成 DeepSeek 密钥配置。",
        "sections_en": """
    <section class="content-section">
      <h2 class="section-heading">Why Bring Your Own Key (BYOK)?</h2>
      <div class="prose">
        <p>Most commercial translation apps charge recurring $10–$25 monthly subscriptions for fixed translation quotas, routing your text through their proprietary servers. With <strong>iTrans (MacTranslate AI)</strong>, you connect your personal API key directly from providers like DeepSeek.</p>
        <p>You pay pennies directly to the model provider based strictly on actual token consumption, with zero markup, zero subscription lock-in, and zero intermediaries handling your text.</p>
      </div>

      <div class="card">
        <div class="card-header">
          <span class="card-title">Supported Models & Endpoints</span>
          <span class="term-pill mono">DeepSeek + OpenAI Format</span>
        </div>
        <div class="prose">
          <ul style="padding-left: 20px; line-height: 1.8;">
            <li><strong>DeepSeek-V3 (deepseek-chat)</strong>: Ultra-fast general translation with high semantic fluency, ideal for daily reading and document translation.</li>
            <li><strong>DeepSeek-R1 (deepseek-reasoner)</strong>: Deep reasoning model with an independent foldable thought process (Reasoning Content) that dissects nuanced grammar and idioms.</li>
            <li><strong>Custom Base URLs</strong>: Connect any OpenAI-compatible proxy, local Ollama instance, or self-hosted LLM gateway.</li>
          </ul>
        </div>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">How to Configure Your API Key</h2>
      <div class="step-list">
        <div class="step-item">
          <div class="step-num">1</div>
          <div class="step-content">
            <h4>Obtain Your DeepSeek Key</h4>
            <p>Log in to your account at <a href="https://platform.deepseek.com" target="_blank" rel="noopener" style="color: var(--accent); text-decoration: underline;">platform.deepseek.com</a>, navigate to API Keys, and create a new secret key.</p>
          </div>
        </div>
        <div class="step-item">
          <div class="step-num">2</div>
          <div class="step-content">
            <h4>Open iTrans Settings</h4>
            <p>Right-click the iTrans menu bar icon and select <strong>Settings</strong> (or press <code class="mono">⌘,</code> from the main translation HUD). Navigate to the <strong>DeepSeek API</strong> tab.</p>
          </div>
        </div>
        <div class="step-item">
          <div class="step-num">3</div>
          <div class="step-content">
            <h4>Paste & Inspect Connectivity</h4>
            <p>Paste your key and click <strong>Test Connection</strong>. iTrans verifies endpoints in real-time, displays verified model counts and latency metrics, and saves the verified status persistently.</p>
          </div>
        </div>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">Security & Private Local Storage</h2>
      <div class="callout callout-success">
        <strong>100% Local-First Credential Isolation:</strong> Your API Key is saved with restricted owner-only <code class="mono">0600</code> permissions at <code class="mono">~/Library/Application Support/cduyzhTranslator/deepseek-api-key</code>. We deliberately do not use the system Keychain to avoid disruptive authorization password prompts when application binaries update.
      </div>
      <div class="prose">
        <p>Translation requests leave your Mac <strong>only</strong> to the provider endpoint you explicitly configured. There are no tracking SDKs, no behavioral telemetry, and no centralized proxy servers.</p>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">Token Economics & Usage Insights</h2>
      <div class="prose">
        <p>Press <code class="mono">⌥S</code> at any time to open the built-in <strong>Usage Statistics</strong> inspector. iTrans tracks daily translation requests, average round-trip latency, token expenditures, and gives you transparent cost visibility.</p>
      </div>
    </section>
""",
        "sections_zh": """
    <section class="content-section">
      <h2 class="section-heading">为什么选择自带 API 密钥（BYOK）？</h2>
      <div class="prose">
        <p>市面上传统翻译软件往往采用按月 50~150 元的昂贵订阅制，且将你的文本转发至第三方中间服务器。<strong>极译 AI（iTrans）</strong> 采用纯粹的 BYOK（Bring Your Own Key）模式，直接接入你自己的服务商账号。</p>
        <p>你只需向 DeepSeek 官方支付极其微小的 Token 费用（千字仅需几分钱甚至几厘钱），零加价、零中转、绝无强制绑卡按月扣费。</p>
      </div>

      <div class="card">
        <div class="card-header">
          <span class="card-title">深度适配的模型与端点</span>
          <span class="term-pill mono">DeepSeek + OpenAI 兼容</span>
        </div>
        <div class="prose">
          <ul style="padding-left: 20px; line-height: 1.8;">
            <li><strong>DeepSeek-V3 (deepseek-chat)</strong>：极速通识大模型翻译，流畅自然，适合海量网页阅读与日常工作。</li>
            <li><strong>DeepSeek-R1 (deepseek-reasoner)</strong>：推理增强大模型，思维链（Reasoning Content）独立折叠展示，深度推敲长难句、学术论文与专业文献。</li>
            <li><strong>自定义 Base URL 兼容端点</strong>：支持配置任何兼容 OpenAI 规范的本地私有化部署（如 Ollama、vLLM）或第三方 API 镜像端点。</li>
          </ul>
        </div>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">三步快速配置指南</h2>
      <div class="step-list">
        <div class="step-item">
          <div class="step-num">1</div>
          <div class="step-content">
            <h4>获取 DeepSeek API Key</h4>
            <p>登录 DeepSeek 开放平台官网 <a href="https://platform.deepseek.com" target="_blank" rel="noopener" style="color: var(--accent); text-decoration: underline;">platform.deepseek.com</a>，在 API Keys 页面一键创建新的密钥字符串。</p>
          </div>
        </div>
        <div class="step-item">
          <div class="step-num">2</div>
          <div class="step-content">
            <h4>打开 iTrans 设置中心</h4>
            <p>在状态栏右键单击 iTrans 图标呼出控制面板并点击齿轮进入<strong>设置</strong>（或在翻译窗口按快捷键 <code class="mono">⌘,</code>），选择 <strong>DeepSeek API</strong> 配置选项卡。</p>
          </div>
        </div>
        <div class="step-item">
          <div class="step-num">3</div>
          <div class="step-content">
            <h4>粘贴并执行连通性巡检</h4>
            <p>粘贴你的 API Key 并点击<strong>测试连通性</strong>。系统将实时测速、校验可用模型并持久化展示绿色健康徽标，切换页面与重启不丢失。</p>
          </div>
        </div>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">本地安全与 0600 权限隔离</h2>
      <div class="callout callout-success">
        <strong>100% 本地优先原则：</strong> 你的密钥仅以严格的当前用户可读写权限（<code class="mono">0600</code>）保存在本地受限目录：<code class="mono">~/Library/Application Support/cduyzhTranslator/deepseek-api-key</code>。我们严格禁用全局钥匙串以避免每次软件签名或更新时频繁弹出系统密码授权弹窗。
      </div>
      <div class="prose">
        <p>翻译文本仅直接发往用户明确选定的官方引擎，无任何行为埋点、无用户追踪 SDK、无任何隐蔽中间层转发。</p>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">实时用量统计与账单透明</h2>
      <div class="prose">
        <p>随时按下全局快捷键 <code class="mono">⌥S</code> 即可打开<strong>用量与账单统计</strong>面板。iTrans 详细记录每日翻译调用频次、网络平均延迟与消耗的 Token 数量，让你对每一分钱的支出心中有数。</p>
      </div>
    </section>
"""
    },

    # ── 2. Selection Translation (划词翻译) ──────────────────────────────────
    {
        "slug": "features/selection-translation",
        "tag_en": "INSTANT SELECTION",
        "tag_zh": "划词秒翻交互",
        "title_en": "Selected Text Translator for Mac | MacTranslate AI",
        "title_zh": "Mac 划词翻译与快捷键翻译工具｜极译 AI",
        "meta_en": "Translate selected text in supported Mac apps using keyboard shortcuts. Learn about menu bar translation, Accessibility permissions, and copy-to-translate fallback.",
        "meta_zh": "了解极译 AI 如何在 macOS 中实现选中文本翻译、复制后翻译与菜单栏翻译，并查看辅助功能权限和快捷键使用说明。",
        "h1_en": "Translate Selected Text Anywhere You Work on Mac",
        "h1_zh": "在 Mac 上选中文字，快捷翻译",
        "lead_en": "Highlight text in Safari, Chrome, Xcode, or preview documents and double-tap ⌘C. A lightweight floating HUD appears instantly next to your cursor with zero context switching.",
        "lead_zh": "在 Safari、Chrome、Xcode 或任意文档中选中文字，连续快速按下两次 ⌘C。轻量级毛玻璃浮窗瞬间在光标旁展开，无需切屏，阅读流畅连贯。",
        "bc_en": [("Features", f"{BASE_URL}/#features"), ("Selection Translation", "")],
        "bc_zh": [("核心特性", f"{BASE_URL}/zh.html#features"), ("划词翻译与快捷键", "")],
        "cta_title_en": "Experience seamless Mac selection translation",
        "cta_title_zh": "体验流畅无缝的 macOS 划词秒翻",
        "cta_desc_en": "Download iTrans today and enjoy frictionless reading and coding on macOS 14+.",
        "cta_desc_zh": "立即下载 iTrans，在 macOS 14+ 上享受沉浸不打断的划词翻译体验。",
        "sections_en": """
    <section class="content-section">
      <h2 class="section-heading">How ⌘C+C Selection Translation Works</h2>
      <div class="prose">
        <p>Traditional translation tools force you to copy text, switch to another window, paste, wait, and switch back. <strong>iTrans</strong> short-circuits this friction entirely.</p>
        <p>Simply highlight any phrase, paragraph, or code snippet in any supported Mac application, and tap <code class="mono">Command+C</code> twice in quick succession. A floating native HUD immediately displays the translation, allows one-key copy, audio speech synthesis, and engine toggling.</p>
      </div>

      <div class="data-table-wrapper">
        <table class="data-table">
          <thead>
            <tr>
              <th>Action</th>
              <th>Trigger</th>
              <th>Description</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><strong>Instant Selection Translation</strong></td>
              <td><span class="term-pill mono">⌘C ⌘C (Double Tap)</span></td>
              <td>Highlights text and displays the translation floating HUD at cursor position</td>
            </tr>
            <tr>
              <td><strong>Summon / Hide Panel</strong></td>
              <td><span class="term-pill mono">⌥Z or ⌃Z</span></td>
              <td>Toggle the central translation window anywhere on desktop</td>
            </tr>
            <tr>
              <td><strong>Cycle Engines</strong></td>
              <td><span class="term-pill mono">⌥E</span></td>
              <td>Quickly toggle between Google Web RPC and DeepSeek reasoning model</td>
            </tr>
            <tr>
              <td><strong>Personal Memory Hub</strong></td>
              <td><span class="term-pill mono">⌥M</span></td>
              <td>Direct shortcut to personal terminology and approved glossary corrections</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">macOS Accessibility Permission Setup</h2>
      <div class="prose">
        <p>To detect selection across other macOS applications without intrusive background keyloggers, iTrans uses official Apple Accessibility APIs. Setting it up takes just a few clicks:</p>
      </div>

      <div class="step-list">
        <div class="step-item">
          <div class="step-num">1</div>
          <div class="step-content">
            <h4>Open System Settings</h4>
            <p>Go to <strong>Apple Menu () → System Settings → Privacy & Security</strong>, and select <strong>Accessibility</strong>.</p>
          </div>
        </div>
        <div class="step-item">
          <div class="step-num">2</div>
          <div class="step-content">
            <h4>Enable iTrans</h4>
            <p>Locate <strong>iTrans</strong> in the application list and toggle the switch to <strong>ON</strong>. If prompted, enter your Mac administrator password or Touch ID.</p>
          </div>
        </div>
        <div class="step-item">
          <div class="step-num">3</div>
          <div class="step-content">
            <h4>Restart if Replaced</h4>
            <p>If you recently upgraded the app bundle and shortcuts don't fire, remove iTrans from the list using the <code class="mono">-</code> button and re-add it to refresh macOS security entitlements.</p>
          </div>
        </div>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">Fallback for Unsupported Applications</h2>
      <div class="callout callout-info">
        <strong>Compatibility Guarantee:</strong> Some custom Electron apps, games, or remote desktop viewers do not expose their text selection to macOS Accessibility trees. In these rare cases, simply copy the text with normal <code class="mono">⌘C</code>, and press <code class="mono">⌥Z</code> to instantly translate from clipboard with zero friction.
      </div>
    </section>
""",
        "sections_zh": """
    <section class="content-section">
      <h2 class="section-heading">双击 ⌘C 划词秒翻机制</h2>
      <div class="prose">
        <p>很多传统翻译工具需要你频繁复制文字、切换窗口、粘贴、等待结果再切回当前页面。<strong>极译 AI（iTrans）</strong> 将这一繁琐链路彻底压缩为毫秒级直达。</p>
        <p>在任意支持的应用中划选文本，快速连按两次 <code class="mono">⌘C</code>（Command+C），精致的半透悬浮面板便在光标位置瞬时展开，显示完整译文，支持一键复制、发音朗读与模型快速切换。</p>
      </div>

      <div class="data-table-wrapper">
        <table class="data-table">
          <thead>
            <tr>
              <th>功能动作</th>
              <th>快捷键 / 触发方式</th>
              <th>功能说明</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><strong>全局划词秒翻</strong></td>
              <td><span class="term-pill mono">⌘C ⌘C (双击 Command+C)</span></td>
              <td>在光标附近毫秒级唤起轻量翻译悬浮卡片</td>
            </tr>
            <tr>
              <td><strong>呼出 / 隐藏面板</strong></td>
              <td><span class="term-pill mono">⌥Z 或 ⌃Z</span></td>
              <td>随时随地呼出全功能翻译交互主窗口</td>
            </tr>
            <tr>
              <td><strong>轮换翻译引擎</strong></td>
              <td><span class="term-pill mono">⌥E</span></td>
              <td>在 Google 免费极速端点与 DeepSeek 深度思考模型间无缝切换</td>
            </tr>
            <tr>
              <td><strong>术语记忆直达</strong></td>
              <td><span class="term-pill mono">⌥M</span></td>
              <td>一键打开个人专属翻译记忆与行业词库管理面板</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">系统辅助功能权限配置步骤</h2>
      <div class="prose">
        <p>为了能够安全合规地感知其他应用的划词操作，iTrans 依赖 macOS 官方辅助功能 API（Accessibility）。初次启动时仅需简单一步授权：</p>
      </div>

      <div class="step-list">
        <div class="step-item">
          <div class="step-num">1</div>
          <div class="step-content">
            <h4>进入系统设置</h4>
            <p>点击屏幕左上角苹果菜单  → <strong>系统设置</strong> → <strong>隐私与安全性</strong>，在列表中找到 <strong>辅助功能</strong>。</p>
          </div>
        </div>
        <div class="step-item">
          <div class="step-num">2</div>
          <div class="step-content">
            <h4>勾选启用 iTrans</h4>
            <p>在允许列表中找到 <strong>iTrans</strong> 并开启右侧开关。若提示授权验证，使用触控 ID 或输入锁屏密码确认。</p>
          </div>
        </div>
        <div class="step-item">
          <div class="step-num">3</div>
          <div class="step-content">
            <h4>重新授权技巧（如遇更新）</h4>
            <p>若替换或更新安装包后快捷键偶发失效，选中列表中的 iTrans 点击底部的 <code class="mono">-</code> 减号删除，再次拖入最新包即可重新刷新系统信任签名。</p>
          </div>
        </div>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">特殊应用的优雅降级与兜底方案</h2>
      <div class="callout callout-info">
        <strong>兼容性原则：</strong> 极少数第三方非原生应用（如特定 Electron 网页套壳、远程桌面窗口或部分游戏）默认不向 macOS 辅助功能树暴露当前选中文本。遇到此类场景，正常按下一次 <code class="mono">⌘C</code> 复制文本，随即按 <code class="mono">⌥Z</code> 呼出面板即可自动读取剪贴板翻译。
      </div>
    </section>
"""
    },

    # ── 3. Terminology Memory (个人术语记忆) ──────────────────────────────────
    {
        "slug": "features/terminology",
        "tag_en": "LOCAL TERMINOLOGY",
        "tag_zh": "专属术语记忆",
        "title_en": "Personal Translation Memory for Mac | MacTranslate AI",
        "title_zh": "Mac AI 翻译术语记忆与个人词库｜极译 AI",
        "meta_en": "Save preferred terms and confirmed corrections locally, then use them to guide future DeepSeek translations on your Mac.",
        "meta_zh": "极译 AI 支持保存常用术语和已确认的翻译修正，帮助后续 DeepSeek 翻译更贴近个人或专业表达习惯。",
        "h1_en": "Keep Your Terminology Consistent Across Translations",
        "h1_zh": "让 AI 翻译记住你的常用表达",
        "lead_en": "Lock in your preferred domain vocabulary and approved corrections. iTrans injects your personal terminology directly into DeepSeek prompts for consistent, professional voice.",
        "lead_zh": "固定你的专业名词专属译法与人工核准修正。iTrans 自动将你的个人词库注入 DeepSeek 提示词中，告别千人一面、上下文冲突的机械翻译。",
        "bc_en": [("Features", f"{BASE_URL}/#features"), ("Terminology Memory", "")],
        "bc_zh": [("核心特性", f"{BASE_URL}/zh.html#features"), ("术语记忆与个人词库", "")],
        "cta_title_en": "Build your personal translation memory",
        "cta_title_zh": "打造你的私有化翻译术语库",
        "cta_desc_en": "Download iTrans to experience intelligent terminology injection powered by DeepSeek.",
        "cta_desc_zh": "立即下载 iTrans，体验由 DeepSeek 智能驱动的专业术语记忆库。",
        "sections_en": """
    <section class="content-section">
      <h2 class="section-heading">The Problem with Generic AI Translation</h2>
      <div class="prose">
        <p>Standard translation models lack your project context. Today they translate <em>"zero-shot transfer"</em> as 零样本转移, tomorrow as 零次迁移. In engineering, medical, and financial writing, inconsistent terminology erodes clarity and professionalism.</p>
        <p><strong>iTrans Personal Memory</strong> solves this by storing your approved terms locally. Every time you confirm a term or correct a mistake, iTrans remembers it and guides future DeepSeek translations seamlessly.</p>
      </div>

      <div class="data-table-wrapper">
        <table class="data-table">
          <thead>
            <tr>
              <th>Source Term</th>
              <th>Generic Output</th>
              <th>iTrans With Personal Memory</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><span class="mono">zero-shot transfer</span></td>
              <td style="color: var(--text-tertiary);">零样本转移 (Literal)</td>
              <td><strong style="color: var(--accent);">零样本迁移</strong> (Standardized)</td>
            </tr>
            <tr>
              <td><span class="mono">prompt caching</span></td>
              <td style="color: var(--text-tertiary);">提示缓存 (Ambiguous)</td>
              <td><strong style="color: var(--accent);">提示词缓存</strong> (Accurate)</td>
            </tr>
            <tr>
              <td><span class="mono">inference latency</span></td>
              <td style="color: var(--text-tertiary);">推理时延 (Inconsistent)</td>
              <td><strong style="color: var(--accent);">推理延迟</strong> (Project Preferred)</td>
            </tr>
            <tr>
              <td><span class="mono">ground truth</span></td>
              <td style="color: var(--text-tertiary);">地面实况 (Machine noise)</td>
              <td><strong style="color: var(--accent);">真实基准</strong> (Domain verified)</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">How Terminology Injection Works</h2>
      <div class="prose">
        <p>When you trigger a translation with DeepSeek, iTrans performs a 1ms lookup against your local glossary. Matched terms are compiled into a compact, structured system directive injected into the model's instruction payload.</p>
        <p>Built-in <strong>Token Budget Guards</strong> ensure glossaries never blow out token limits or cause unexpected context overflow.</p>
      </div>

      <div class="card">
        <div class="card-header">
          <span class="card-title">Built-in Domain Knowledge Bases</span>
          <span class="term-pill mono">JSON / CSV Import</span>
        </div>
        <div class="prose">
          <p>iTrans ships with optional built-in glossaries across Computer Science & AI, Legal, Finance, Medicine, and Internet Culture. You can also import large organizational term bases via standard JSON or CSV files.</p>
        </div>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">100% Local File Storage</h2>
      <div class="callout callout-success">
        <strong>Zero Cloud Retention:</strong> Your personal vocabulary rules and correction history are saved exclusively on your Mac at:
        <br /><code class="mono" style="font-weight: 600;">~/Library/Application Support/cduyzhTranslator/personal-memory.json</code>.
        <br />You can back up, edit, or migrate your glossary at any time.
      </div>
    </section>
""",
        "sections_zh": """
    <section class="content-section">
      <h2 class="section-heading">通用机器翻译的硬伤</h2>
      <div class="prose">
        <p>通用 AI 模型缺乏具体的业务与行业上下文。今天把 <em>"zero-shot transfer"</em> 直译为“零样本转移”，明天可能变成“零击传输”。在技术研发、法律合规与金融文献中，这种用词漂移极易引发理解偏差。</p>
        <p><strong>iTrans 个人术语记忆库</strong> 彻底解决了这个问题：它在你纠正某次翻译时一键“记住这次修正”，后续使用 DeepSeek 翻译时便会自动沿用你的专属词汇习惯。</p>
      </div>

      <div class="data-table-wrapper">
        <table class="data-table">
          <thead>
            <tr>
              <th>原文专业词汇</th>
              <th>普通机器直译</th>
              <th>iTrans 术语记忆结果</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><span class="mono">zero-shot transfer</span></td>
              <td style="color: var(--text-tertiary);">零样本转移（生硬直译）</td>
              <td><strong style="color: var(--accent);">零样本迁移</strong>（行业标准）</td>
            </tr>
            <tr>
              <td><span class="mono">prompt caching</span></td>
              <td style="color: var(--text-tertiary);">提示缓存（歧义模糊）</td>
              <td><strong style="color: var(--accent);">提示词缓存</strong>（严谨统一）</td>
            </tr>
            <tr>
              <td><span class="mono">inference latency</span></td>
              <td style="color: var(--text-tertiary);">推理时延（忽延忽滞）</td>
              <td><strong style="color: var(--accent);">推理延迟</strong>（个人偏好）</td>
            </tr>
            <tr>
              <td><span class="mono">ground truth</span></td>
              <td style="color: var(--text-tertiary);">地面真值 / 地面实况（机械翻译）</td>
              <td><strong style="color: var(--accent);">真实基准</strong>（专业语境）</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">智能注入与 Token 预算防护</h2>
      <div class="prose">
        <p>每次发起 DeepSeek 翻译请求时，iTrans 在 1ms 内快速检索匹配当前输入文本中的专有名词，并将核准词条精炼为结构化指令注入模型 Prompt 中。</p>
        <p>内置 <strong>Token 预算防溢出守卫</strong>，即使术语库容纳成千上万条记录，也只精准动态切片注入当前相关的词条，绝不浪费宝贵的上下文长度与调用费用。</p>
      </div>

      <div class="card">
        <div class="card-header">
          <span class="card-title">开箱即用的行业专业知识库</span>
          <span class="term-pill mono">支持 JSON / CSV 批量导入</span>
        </div>
        <div class="prose">
          <p>iTrans 原生内置了计算机/AI、医学、法律合规、网络流行梗四大垂直术语库。你更可以通过直观的设置界面，随时一键批量导入团队或开源术语词表。</p>
        </div>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">本地持久化与隐私安全</h2>
      <div class="callout callout-success">
        <strong>绝不上传云端：</strong> 你的个人术语记忆与纠错历史独占保存在你的 Mac 本地磁盘：
        <br /><code class="mono" style="font-weight: 600;">~/Library/Application Support/cduyzhTranslator/personal-memory.json</code>。
        <br />明文 JSON 结构，支持用户自主随时备份、版本控制或跨机同步。
      </div>
    </section>
"""
    },

    # ── 4. Agent API & CLI (本地 API 与 CLI) ──────────────────────────────────
    {
        "slug": "docs/agent-api",
        "tag_en": "LOCAL GATEWAY & CLI",
        "tag_zh": "本地网关与命令行",
        "title_en": "Local Translation API & CLI for macOS | MacTranslate AI",
        "title_zh": "Mac 本地翻译 API 与 CLI 接口文档｜极译 AI",
        "meta_en": "Connect MacTranslate AI to local scripts and desktop agents through the optional loopback HTTP gateway and command-line interface.",
        "meta_zh": "极译 AI 提供可选的本地 Agent Gateway 和命令行接口，适合 Mac 脚本与桌面 Agent 集成。查看接口、示例及安全限制。",
        "h1_en": "Automate Translation with a Local API and CLI",
        "h1_zh": "通过本地 API 和 CLI 自动化翻译工作流",
        "lead_en": "A loopback HTTP daemon at 127.0.0.1:11899 and native terminal CLI that expose your personalized translation engine to Raycast, Alfred, Cursor, and Python scripts.",
        "lead_zh": "仅监听本机 127.0.0.1:11899 的本地 HTTP 回环网关与原生命令行工具，让 Raycast、Alfred、Cursor 与 Python 脚本无缝调用你的个性化记忆翻译引擎。",
        "bc_en": [("Docs", f"{BASE_URL}/docs/agent-api/"), ("Agent API & CLI", "")],
        "bc_zh": [("开发者文档", f"{BASE_URL}/zh/docs/agent-api/"), ("本地 API 与 CLI", "")],
        "cta_title_en": "Integrate iTrans into your automated workflow",
        "cta_title_zh": "将 iTrans 接入你的自动化工作流",
        "cta_desc_en": "Download iTrans to connect your local agents and scripts to high-performance translation.",
        "cta_desc_zh": "立即下载 iTrans，为本地智能体与脚本赋予强大的术语感知翻译能力。",
        "sections_en": """
    <section class="content-section">
      <h2 class="section-heading">Loopback Gateway Architecture</h2>
      <div class="prose">
        <p>When enabled in iTrans Settings, the app hosts an ultra-lightweight HTTP REST server strictly bound to <code class="mono">127.0.0.1:11899</code>. It rejects any external network interface requests, keeping your automation completely local and safe.</p>
      </div>

      <div class="data-table-wrapper">
        <table class="data-table">
          <thead>
            <tr>
              <th>Method</th>
              <th>Endpoint</th>
              <th>Description</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><span class="term-pill mono">POST</span></td>
              <td><code class="mono">/v1/translate</code></td>
              <td>Translate text using selected engine with personal memory injection</td>
            </tr>
            <tr>
              <td><span class="term-pill mono">GET</span></td>
              <td><code class="mono">/v1/memory</code></td>
              <td>Export local personal translation memory rules in JSON</td>
            </tr>
            <tr>
              <td><span class="term-pill mono">GET</span></td>
              <td><code class="mono">/v1/knowledge-base</code></td>
              <td>List active industry knowledge categories and terms</td>
            </tr>
            <tr>
              <td><span class="term-pill mono">POST</span></td>
              <td><code class="mono">/v1/knowledge-base/import</code></td>
              <td>Batch import custom domain glossary entries via JSON/CSV</td>
            </tr>
            <tr>
              <td><span class="term-pill mono">GET</span></td>
              <td><code class="mono">/v1/stats</code></td>
              <td>Retrieve translation latency and token consumption metrics</td>
            </tr>
            <tr>
              <td><span class="term-pill mono">GET</span></td>
              <td><code class="mono">/v1/version</code></td>
              <td>Query app version, build number, and environment status</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">API Example: cURL & Python</h2>
      <div class="prose">
        <p>Triggering a translation via cURL:</p>
      </div>
      <div class="code-block">curl -X POST http://127.0.0.1:11899/v1/translate \\
  -H "Content-Type: application/json" \\
  -d '{
    "text": "Evaluating zero-shot transfer capabilities.",
    "source_lang": "en",
    "target_lang": "zh-CN",
    "engine": "deepseek"
  }'</div>

      <div class="prose">
        <p>Calling from Python with standard libraries:</p>
      </div>
      <div class="code-block">import urllib.request, json

payload = json.dumps({
    "text": "prompt caching reduces inference latency.",
    "source_lang": "en",
    "target_lang": "zh-CN",
    "engine": "deepseek"
}).encode('utf-8')

req = urllib.request.Request(
    "http://127.0.0.1:11899/v1/translate",
    data=payload,
    headers={"Content-Type": "application/json"}
)

with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode())
    print(data.get("translated_text"))</div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">Native CLI Terminal Tool</h2>
      <div class="prose">
        <p>You can also invoke translation directly from your zsh or bash terminal using the bundled command-line executable:</p>
      </div>
      <div class="code-block"># Direct text translation
/Applications/iTrans.app/Contents/MacOS/cduyzhTranslator --translate "Hello world" --engine deepseek

# Inspect local stats and terminology
/Applications/iTrans.app/Contents/MacOS/cduyzhTranslator --stats
/Applications/iTrans.app/Contents/MacOS/cduyzhTranslator --memory</div>
    </section>
""",
        "sections_zh": """
    <section class="content-section">
      <h2 class="section-heading">本地回环网关架构（Loopback Only）</h2>
      <div class="prose">
        <p>在 iTrans 设置中启用本地网关后，系统将在本地回环地址 <code class="mono">127.0.0.1:11899</code> 启动轻量级 HTTP REST 服务。该端口严格限制仅本机访问，绝不对局域网或外部互联网开放，保障绝对的数据安全性。</p>
      </div>

      <div class="data-table-wrapper">
        <table class="data-table">
          <thead>
            <tr>
              <th>请求方式</th>
              <th>端点路径</th>
              <th>功能描述</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><span class="term-pill mono">POST</span></td>
              <td><code class="mono">/v1/translate</code></td>
              <td>调用指定引擎执行文本翻译，自动应用个人术语记忆</td>
            </tr>
            <tr>
              <td><span class="term-pill mono">GET</span></td>
              <td><code class="mono">/v1/memory</code></td>
              <td>以标准 JSON 格式导出本地个人翻译记忆库</td>
            </tr>
            <tr>
              <td><span class="term-pill mono">GET</span></td>
              <td><code class="mono">/v1/knowledge-base</code></td>
              <td>查看当前已加载的行业专有知识库分类与词条</td>
            </tr>
            <tr>
              <td><span class="term-pill mono">POST</span></td>
              <td><code class="mono">/v1/knowledge-base/import</code></td>
              <td>批量导入自定义 JSON 或 CSV 行业专业术语库</td>
            </tr>
            <tr>
              <td><span class="term-pill mono">GET</span></td>
              <td><code class="mono">/v1/stats</code></td>
              <td>读取本地翻译调用频次、耗时与 Token 统计</td>
            </tr>
            <tr>
              <td><span class="term-pill mono">GET</span></td>
              <td><code class="mono">/v1/version</code></td>
              <td>查询当前 iTrans 运行版本与构建编号</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">调用范例：cURL 与 Python 脚本</h2>
      <div class="prose">
        <p>通过命令行 cURL 快速发起翻译：</p>
      </div>
      <div class="code-block">curl -X POST http://127.0.0.1:11899/v1/translate \\
  -H "Content-Type: application/json" \\
  -d '{
    "text": "Evaluating zero-shot transfer capabilities.",
    "source_lang": "en",
    "target_lang": "zh-CN",
    "engine": "deepseek"
  }'</div>

      <div class="prose">
        <p>在 Python 脚本中调用（零外部第三方库依赖）：</p>
      </div>
      <div class="code-block">import urllib.request, json

payload = json.dumps({
    "text": "prompt caching reduces inference latency.",
    "source_lang": "en",
    "target_lang": "zh-CN",
    "engine": "deepseek"
}).encode('utf-8')

req = urllib.request.Request(
    "http://127.0.0.1:11899/v1/translate",
    data=payload,
    headers={"Content-Type": "application/json"}
)

with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode())
    print(data.get("translated_text"))</div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">原生 CLI 终端命令行交互</h2>
      <div class="prose">
        <p>开发者还可在 zsh 或 bash 终端中直接运行二进制文件实现命令行划词与快捷查询：</p>
      </div>
      <div class="code-block"># 执行直接文本翻译
/Applications/iTrans.app/Contents/MacOS/cduyzhTranslator --translate "Hello world" --engine deepseek

# 导出本地用量与术语记忆
/Applications/iTrans.app/Contents/MacOS/cduyzhTranslator --stats
/Applications/iTrans.app/Contents/MacOS/cduyzhTranslator --memory</div>
    </section>
"""
    },

    # ── 5. Download (下载中心) ────────────────────────────────────────────────
    {
        "slug": "download",
        "tag_en": "OFFICIAL RELEASES",
        "tag_zh": "官方版本下载",
        "title_en": "Download MacTranslate AI for Mac – iTrans App",
        "title_zh": "下载极译 AI - macOS 原生 AI 翻译工具",
        "meta_en": "Get the latest macOS installer from official GitHub Releases. Learn how to install iTrans and configure translation on macOS 14.0 or later.",
        "meta_zh": "前往官方 GitHub Releases 下载极译 AI 的 macOS 安装包。支持 macOS 14.0 及以上版本，提供安装和首次启动说明。",
        "h1_en": "Download MacTranslate AI (iTrans)",
        "h1_zh": "下载极译 AI（安装后名称：iTrans）",
        "lead_en": "Free, open-source macOS translator with native Apple Silicon and Intel support. Download pre-built DMG packages directly from official GitHub Releases.",
        "lead_zh": "免费开源的原生 macOS 翻译工具，全面原生支持 Apple Silicon 与 Intel 芯片架构。直接从官方 GitHub Releases 获取经过严格安全校验的 DMG 安装包。",
        "bc_en": [("Download", "")],
        "bc_zh": [("下载安装", "")],
        "cta_title_en": "Looking for the source code?",
        "cta_title_zh": "想查看源码或本地编译构建？",
        "cta_desc_en": "iTrans is completely open source under the MIT License on GitHub.",
        "cta_desc_zh": "iTrans 完全基于宽松的 MIT 许可证在 GitHub 公开所有源代码。",
        "sections_en": """
    <section class="content-section">
      <h2 class="section-heading">Choose Your Build (v1.0.1)</h2>
      <div class="prose">
        <p>Pre-built release packages are hosted securely on GitHub Releases with zero third-party telemetry:</p>
      </div>

      <div class="step-list">
        <div class="step-item" style="border: 1.5px solid var(--accent); background: var(--accent-subtle);">
          <div class="step-num" style="background: var(--accent); color: #fff;">★</div>
          <div class="step-content" style="flex-grow: 1;">
            <div style="display: flex; justify-content: space-between; align-items: baseline; flex-wrap: wrap; gap: 8px;">
              <h4 style="font-size: 17px; color: var(--accent);">Universal 2 Build (Recommended)</h4>
              <span class="mono" style="font-size: 13px; color: var(--text-tertiary);">iTrans-1.0.1-universal.dmg</span>
            </div>
            <p style="margin: 6px 0 12px;">Natively compiled for both Apple Silicon (M1/M2/M3/M4) and Intel x86_64 Macs. Zero Rosetta 2 overhead.</p>
            <a href="https://github.com/cduyzh/iTrans/releases" class="btn btn-primary" target="_blank" rel="noopener">
              Download Universal DMG
            </a>
          </div>
        </div>

        <div class="step-item">
          <div class="step-num"></div>
          <div class="step-content" style="flex-grow: 1;">
            <div style="display: flex; justify-content: space-between; align-items: baseline; flex-wrap: wrap; gap: 8px;">
              <h4>Apple Silicon Build</h4>
              <span class="mono" style="font-size: 13px; color: var(--text-tertiary);">iTrans-1.0.1-arm64.dmg</span>
            </div>
            <p style="margin: 6px 0 12px;">Optimized specifically for Macs with M1, M2, M3, or M4 series chips for minimum download size.</p>
            <a href="https://github.com/cduyzh/iTrans/releases" class="btn btn-secondary" target="_blank" rel="noopener">
              Download arm64 DMG
            </a>
          </div>
        </div>

        <div class="step-item">
          <div class="step-num">⚡︎</div>
          <div class="step-content" style="flex-grow: 1;">
            <div style="display: flex; justify-content: space-between; align-items: baseline; flex-wrap: wrap; gap: 8px;">
              <h4>Intel Mac Build</h4>
              <span class="mono" style="font-size: 13px; color: var(--text-tertiary);">iTrans-1.0.1-x86_64.dmg</span>
            </div>
            <p style="margin: 6px 0 12px;">Native build for traditional Intel Core i5/i7/i9 processors.</p>
            <a href="https://github.com/cduyzh/iTrans/releases" class="btn btn-secondary" target="_blank" rel="noopener">
              Download x86_64 DMG
            </a>
          </div>
        </div>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">Installation & First Launch</h2>
      <div class="step-list">
        <div class="step-item">
          <div class="step-num">1</div>
          <div class="step-content">
            <h4>Mount DMG & Drag to Applications</h4>
            <p>Double-click the downloaded <code class="mono">.dmg</code> file, then drag <code class="mono">iTrans.app</code> into your macOS <strong>Applications</strong> folder.</p>
          </div>
        </div>
        <div class="step-item">
          <div class="step-num">2</div>
          <div class="step-content">
            <h4>Launch & Verify Menu Bar Icon</h4>
            <p>Launch iTrans from Spotlight (<code class="mono">⌘Space</code>) or Applications. A quiet icon appears in your macOS menu bar.</p>
          </div>
        </div>
        <div class="step-item">
          <div class="step-num">3</div>
          <div class="step-content">
            <h4>Grant Accessibility (For Double ⌘C)</h4>
            <p>Open <strong>System Settings → Privacy & Security → Accessibility</strong>, and toggle <strong>iTrans</strong> ON to enable instant text selection translation.</p>
          </div>
        </div>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">Build from Source</h2>
      <div class="prose">
        <p>Requirements: macOS 14.0+, Xcode 15+ (or Command Line Tools), Swift 5.9+.</p>
      </div>
      <div class="code-block">git clone https://github.com/cduyzh/iTrans.git
cd iTrans
./scripts/run_tests.sh
./build_app.sh</div>
    </section>
""",
        "sections_zh": """
    <section class="content-section">
      <h2 class="section-heading">选择适合你 Mac 的安装包（v1.0.1）</h2>
      <div class="prose">
        <p>官方编译安装包托管在 GitHub Releases，经过严格的代码签名与敏感信息扫描，安全透明：</p>
      </div>

      <div class="step-list">
        <div class="step-item" style="border: 1.5px solid var(--accent); background: var(--accent-subtle);">
          <div class="step-num" style="background: var(--accent); color: #fff;">★</div>
          <div class="step-content" style="flex-grow: 1;">
            <div style="display: flex; justify-content: space-between; align-items: baseline; flex-wrap: wrap; gap: 8px;">
              <h4 style="font-size: 17px; color: var(--accent);">Universal 2 通用安装包（推荐）</h4>
              <span class="mono" style="font-size: 13px; color: var(--text-tertiary);">iTrans-1.0.1-universal.dmg</span>
            </div>
            <p style="margin: 6px 0 12px;">同时包含 Apple Silicon 与 Intel 双架构二进制，无论是 M 系列芯片还是 Intel 处理器均享受原生运行，无 Rosetta 2 负担。</p>
            <a href="https://github.com/cduyzh/iTrans/releases" class="btn btn-primary" target="_blank" rel="noopener">
              下载 Universal 通用安装包
            </a>
          </div>
        </div>

        <div class="step-item">
          <div class="step-num"></div>
          <div class="step-content" style="flex-grow: 1;">
            <div style="display: flex; justify-content: space-between; align-items: baseline; flex-wrap: wrap; gap: 8px;">
              <h4>Apple Silicon 专版</h4>
              <span class="mono" style="font-size: 13px; color: var(--text-tertiary);">iTrans-1.0.1-arm64.dmg</span>
            </div>
            <p style="margin: 6px 0 12px;">针对搭载 M1、M2、M3、M4 芯片的 Mac 精简体积，下载安装更小更快。</p>
            <a href="https://github.com/cduyzh/iTrans/releases" class="btn btn-secondary" target="_blank" rel="noopener">
              下载 arm64 独立安装包
            </a>
          </div>
        </div>

        <div class="step-item">
          <div class="step-num">⚡︎</div>
          <div class="step-content" style="flex-grow: 1;">
            <div style="display: flex; justify-content: space-between; align-items: baseline; flex-wrap: wrap; gap: 8px;">
              <h4>Intel Mac 专版</h4>
              <span class="mono" style="font-size: 13px; color: var(--text-tertiary);">iTrans-1.0.1-x86_64.dmg</span>
            </div>
            <p style="margin: 6px 0 12px;">专为 Intel Core 处理器架构的 Mac 电脑优化打包。</p>
            <a href="https://github.com/cduyzh/iTrans/releases" class="btn btn-secondary" target="_blank" rel="noopener">
              下载 x86_64 独立安装包
            </a>
          </div>
        </div>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">极简安装与首次启动说明</h2>
      <div class="step-list">
        <div class="step-item">
          <div class="step-num">1</div>
          <div class="step-content">
            <h4>拖入应用程序</h4>
            <p>双击打开下载的 <code class="mono">.dmg</code> 文件，直接将 <code class="mono">iTrans.app</code> 图标拖动到 <strong>Applications</strong>（应用程序）文件夹。</p>
          </div>
        </div>
        <div class="step-item">
          <div class="step-num">2</div>
          <div class="step-content">
            <h4>启动并确认菜单栏图标</h4>
            <p>按下 <code class="mono">⌘Space</code> 通过聚焦搜索或在启动台中点击 <strong>iTrans</strong>。右上角菜单栏将常驻精致的极简翻译图标。</p>
          </div>
        </div>
        <div class="step-item">
          <div class="step-num">3</div>
          <div class="step-content">
            <h4>授权辅助功能（划词秒翻必备）</h4>
            <p>前往 <strong>系统设置 → 隐私与安全性 → 辅助功能</strong> 开启 <strong>iTrans</strong>，即可畅享全局双击 ⌘C 划词秒翻功能。</p>
          </div>
        </div>
      </div>
    </section>

    <section class="content-section">
      <h2 class="section-heading">从源码本地编译构建</h2>
      <div class="prose">
        <p>开发环境要求：macOS 14.0 或更高版本，Xcode 15+（或命令行工具），Swift 5.9+。</p>
      </div>
      <div class="code-block">git clone https://github.com/cduyzh/iTrans.git
cd iTrans
./scripts/run_tests.sh
./build_app.sh</div>
    </section>
"""
    }
]

# ── Generate all pages ──────────────────────────────────────────────────────
for item in pages_data:
    slug = item["slug"]
    
    # 1. English page
    en_dir = os.path.join(OUTPUT_DIR, slug)
    os.makedirs(en_dir, exist_ok=True)
    en_file = os.path.join(en_dir, "index.html")
    en_html = generate_page(
        lang="en",
        slug=slug,
        title=item["title_en"],
        meta_desc=item["meta_en"],
        h1=item["h1_en"],
        lead=item["lead_en"],
        tag=item["tag_en"],
        breadcrumb_items=item["bc_en"],
        sections_html=item["sections_en"],
        cta_title=item["cta_title_en"],
        cta_desc=item["cta_desc_en"]
    )
    with open(en_file, "w", encoding="utf-8") as f:
        f.write(en_html)
    print(f"Generated: {en_file}")

    # 2. Chinese page
    zh_dir = os.path.join(OUTPUT_DIR, "zh", slug)
    os.makedirs(zh_dir, exist_ok=True)
    zh_file = os.path.join(zh_dir, "index.html")
    zh_html = generate_page(
        lang="zh-CN",
        slug=slug,
        title=item["title_zh"],
        meta_desc=item["meta_zh"],
        h1=item["h1_zh"],
        lead=item["lead_zh"],
        tag=item["tag_zh"],
        breadcrumb_items=item["bc_zh"],
        sections_html=item["sections_zh"],
        cta_title=item["cta_title_zh"],
        cta_desc=item["cta_desc_zh"]
    )
    with open(zh_file, "w", encoding="utf-8") as f:
        f.write(zh_html)
    print(f"Generated: {zh_file}")

print("All 10 pages generated successfully!")

# ── Update sitemap.xml ──────────────────────────────────────────────────────
sitemap_path = os.path.join(OUTPUT_DIR, "sitemap.xml")
with open(sitemap_path, "r", encoding="utf-8") as f:
    sitemap_content = f.read()

# Uncomment all download and feature pages in sitemap.xml
sitemap_content = sitemap_content.replace('<!-- <url>', '<url>')
sitemap_content = sitemap_content.replace('</url> -->', '</url>')

with open(sitemap_path, "w", encoding="utf-8") as f:
    f.write(sitemap_content)
print("Updated sitemap.xml: all pages activated and uncommented.")