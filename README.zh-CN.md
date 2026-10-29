# 极译 AI · MacTranslate AI — Mac 原生 AI 翻译工具

**选中即译，接入自己的 AI API Key。**

极译 AI（MacTranslate AI）是一款适用于 macOS 的原生开源翻译工具，安装后在"应用程序"中显示为 **iTrans**。支持菜单栏翻译、划词快捷键、自定义 DeepSeek API Key 与兼容接口、Google 和 DeepSeek 翻译引擎，以及保存在本机的个人术语记忆。开发者还可以通过本地 CLI 和可选的 Agent Gateway 接入自动化工作流。

**macOS 14.0+** · [立即下载](https://github.com/cduyzh/iTrans/releases) · [English](README.md)

> 项目原名 TransBar。

[![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B-000000?style=flat-square&logo=apple&logoColor=white)](https://github.com/cduyzh/iTrans/releases)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?style=flat-square&logo=swift&logoColor=white)](https://github.com/cduyzh/iTrans)
[![Architecture: Universal 2](https://img.shields.io/badge/架构-Apple%20Silicon%20%7C%20Intel%20Mac-blue?style=flat-square)](https://github.com/cduyzh/iTrans/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)
[![Author](https://img.shields.io/badge/Author-cduyzh-blue?style=flat-square)](https://github.com/cduyzh)

[English](README.md) · **简体中文**

---

## 核心特性

- **极致原生性能**
  - 纯原生 SwiftUI + AppKit 架构，启动时间低于 200ms，常驻内存占用极低。
  - 零第三方第三方闭源依赖，原生适配 macOS 14+ Sonoma、Sequoia 及更新版本。
- **双引擎协同架构**
  - **Google 免费端点**：平均 60~120ms 极低延迟，开箱即用，免配置 API Key。
  - **DeepSeek 思考模型**：深度语义推敲，完整保留 Markdown 代码排版，思维链（Reasoning Content）独立折叠展示。
- **Universal 2 双芯片原生支持（Apple Silicon 与 Intel Mac）**
  - 无论是 Apple Silicon（M1/M2/M3/M4 系列芯片）还是 Intel 芯片 Mac，均享受原生编译加速，无需 Rosetta 2 转译。
- **Quiet Signal 状态控制面板**
  - **左键单击**：极速唤起翻译主面板。
  - **右键单击**：呼出 5 大黄金功能分区毛玻璃控制面板（NSPopover），快捷轮换引擎（`⌥E`）、直达术语记忆库（`⌥M`）、用量统计（`⌥S`）与系统权限巡检。
- **本地自学习记忆库与行业知识库**
  - 重复翻译内容 1ms 毫秒级命中返回，免重复消耗网络与 Token。
  - 内置计算机/AI、医学、法律、网络热梗等垂直术语库，具备智能 Token 预算防护。
- **API 连通性健康巡检（拒绝重复测试）**
  - 提供醒目的 Emerald 微光状态卡片，测试成功后持久展示「测试 API 接口调用成功 · 包含 2 个可用模型 · 延迟 180ms」，切换页面与重启不丢失。
- **本地 Agent 网关（`127.0.0.1:11899`）**
  - 内置轻量级本地 HTTP REST 接口，无缝支持外部 Python 脚本、Claude Desktop、Cursor 等桌面级智能体自动化协同。
- **100% 本地优先与隐私安全**
  - API Key 仅保存在本机私有受限文件（`0600` 权限），位于 `~/Library/Application Support/cduyzhTranslator/`。
  - 严禁调用系统全局钥匙串（避免签名微调时频繁弹出授权密码弹窗）；无埋点、无行为统计、不上传用户个人数据。

---

## 下载与安装

### 方式一：下载官方 DMG 安装包（推荐）

前往 [GitHub Releases](https://github.com/cduyzh/iTrans/releases) 下载最新发行版：

- **Universal 2 通用安装包**：`iTrans-1.0.0-universal.dmg`（同时支持 Apple Silicon 与 Intel Mac）
- **Apple Silicon 专用安装包**：`iTrans-1.0.0-arm64.dmg`（针对 M1/M2/M3/M4 优化）
- **Intel Mac 专用安装包**：`iTrans-1.0.0-x86_64.dmg`（针对 Intel Core 芯片优化）

#### 安装步骤：
1. 双击打开下载好的 `.dmg` 镜像文件。
2. 将 `iTrans.app` 拖入 **Applications**（应用程序）文件夹。
3. 推出磁盘映像，从应用程序中启动 iTrans。

> **关于系统权限说明**：
> 双击 `⌘C` 全局划词秒翻依赖 macOS 辅助功能权限。首次打开时，请前往 **系统设置 → 隐私与安全性 → 辅助功能** 勾选 `iTrans`。若不需要划词功能，可使用 `Option+Z` 或菜单栏手动输入，无需任何额外系统权限。

---

### 方式二：从源码 Clone 本地构建

环境要求：
- macOS 14.0 或更高版本
- Xcode 15+ 或 Xcode 命令行工具（终端执行 `xcode-select --install`）
- Swift 5.9 或更高版本

```bash
# 1. 克隆代码仓库
git clone https://github.com/cduyzh/iTrans.git
cd TransBar

# 2. 运行自动化测试套件验证环境
./scripts/run_tests.sh

# 3. 运行构建脚本打包 App
# 默认构建 Universal 2 通用二进制（同时包含 Apple Silicon 与 Intel 架构）
./build_app.sh

# 也支持指定单一架构构建：
# ./build_app.sh --arm64    # 仅构建 Apple Silicon 架构
# ./build_app.sh --x86_64   # 仅构建 Intel Mac 架构
# ./build_app.sh --native   # 仅构建当前开发机原生架构
```

构建成功后，将在 `.build.noindex/iTrans.app` 生成完整的应用包。双击即可直接运行，或在终端输入：

```bash
open .build.noindex/iTrans.app
```

---

## 快捷键与常用交互

| 功能动作 | 触发方式 / 快捷键 | 详细说明 |
| --- | --- | --- |
| **划词秒翻** | `⌘C ⌘C`（双击 Command+C） | 在任意软件中划选文本，快速连按两次 `⌘C` 极速呼出翻译悬浮窗 |
| **呼出主面板** | `⌥Z` / `⌃Z` | 随时随地呼出或隐藏半透翻译交互窗口 |
| **切换翻译引擎** | `⌥E` | 在 Google 与 DeepSeek 引擎之间切换 |
| **术语记忆库** | `⌥M` | 直达个人翻译记忆与专业术语管理面板 |
| **用量与统计** | `⌥S` | 查看每日调用频次、响应延迟与 Token 消耗账单 |
| **状态栏左键** | 单击图标 | 打开主翻译面板 |
| **状态栏右键** | 单击图标 | 呼出毛玻璃状态控制面板 |

---

## 本地 Agent 网关接口

在设置中启用网关后，TransBar 将在本地回环地址 `http://127.0.0.1:11899` 启动轻量级 HTTP 服务：

| 请求方式 | 端点路径 | 功能描述 |
| --- | --- | --- |
| `POST` | `/v1/translate` | 调用指定引擎执行文本翻译 |
| `GET` | `/v1/memory` | 导出本地个人翻译记忆库为 JSON 格式 |
| `GET` | `/v1/knowledge-base` | 查看已加载的行业专有知识库与分类 |
| `POST` | `/v1/knowledge-base/import`| 批量导入 JSON 或 CSV 行业专业术语库 |
| `GET` | `/v1/stats` | 读取本地翻译调用统计与耗时分析 |
| `GET` | `/v1/version` | 查询当前 TransBar 运行版本与构建号 |
| `GET` | `/v1/changelog` | 读取结构化版本更新历史日志 |

### cURL 示例：

```bash
curl -X POST http://127.0.0.1:11899/v1/translate \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "Evaluating zero-shot transfer capabilities.",
    "source_lang": "en",
    "target_lang": "zh-CN",
    "engine": "deepseek"
  }'
```

---

## 隐私承诺与安全性

- **零云端持久留存**：TransBar 不自建任何中间转发服务器，翻译文本仅直接发往用户明确选定的官方引擎（Google 或 DeepSeek）。
- **密钥本地隔离**：DeepSeek API 密钥仅保存在用户本地磁盘（`0600` 权限），绝不上传、绝不入库，不请求钥匙串访问密码。
- **无数据回传**：无埋点、无用户追踪分析 SDK、无任何隐蔽后台网络外联。

---

## 开源协议

TransBar 遵循 [MIT 许可证](LICENSE) 开源发布。

## 作者

**cduyzh**
- GitHub: [https://github.com/cduyzh](https://github.com/cduyzh)
- 官网主页: [https://www.cduyzh.top](https://www.cduyzh.top)
- 愿景与目标: [https://www.cduyzh.top/goal](https://www.cduyzh.top/goal)
