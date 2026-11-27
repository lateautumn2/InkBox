# 墨匣（InkBox）— 本地书籍与漫画双引擎阅读器

墨匣（InkBox）是一款基于 **Flutter + Rust Core（C-ABI FFI）+ 极薄 PlatformBridge** 构建的本地书籍与漫画双引擎阅读器。  
项目以 **Android** 作为首个落地平台，整体架构面向 **Android → iOS → Windows → HarmonyOS NEXT → macOS** 五端演进。

Android 安装包可从 [GitHub Releases](https://github.com/lateautumn2/InkBox/releases/latest) 下载。每次推送 `vMAJOR.MINOR.PATCH` 标签后，GitHub Actions 会生成并上传一个通用 APK。

## 设计与架构文档

- **原型与 UI/交互设计规范（V1.0 初稿）**：[docs/design/design_spec.md](./docs/design/design_spec.md)
- **v0.2 视觉重构、响应式大屏、多语言与在线 TTS 设计规格**：[docs/design/design_spec_v0.2.md](./docs/design/design_spec_v0.2.md)
- **可交互原型（HTML）**：[docs/design/prototype.html](./docs/design/prototype.html)
- **高保真 UI 设计图**：[docs/design/mockups/](./docs/design/mockups/)（含 `05_floating_card_handdrawn_icons.jpg` FloatingCard 与手绘单色线性图标规范）
- **技术选型与五端架构**：[docs/architecture/tech_selection.md](./docs/architecture/tech_selection.md)

## 核心能力总览

| 模块 | 已实现功能 |
| :--- | :--- |
| **视觉体系与多语言** | Material Design 3 + **Crisp Ink & Mineral Paper 素白矿物纸配色**（`crispLight` 素白 / `darkTheater` 深石板暗室 / `oledBlack` 纯黑 OLED，兼容 Monet 动态取色）、**FloatingCard 悬浮卡片与经典贴边双布局**、**手绘单色线性 SVG 图标**（`InkIcons`）；完整 **简体中文 / English / 日本語 / 跟随系统** 实时热切换（Flutter `gen-l10n` + Android 原生多语言资源）；弹窗与页面居中宽度约束（`kMaxModalWidth` / `kMaxContentWidth`） |
| **自适应壳层与书架/漫画架** | 手机竖屏（`< 600dp`）底栏 ↔ 平板/横屏（`≥ 600dp`）左侧 **`NavigationRail`** 自适应切换；自适应多列书架与漫画架网格；零预置示例数据、**多书架 / 多漫画架管理**（新建/重命名/切换与跨架移入，固定「所有 / 在读 / 已读完」状态分组，兼容跨语言默认分组筛选）、搜索与多维排序、继续阅读浮卡、长按批量操作、作品详情页章节浏览与编码/目录规则配置、移出书架（保留导入历史）或彻底删除双策略 |
| **书籍阅读引擎** | **EPUB**（NCX + EPUB3 Nav + 百分号解码目录）、**TXT**（Rust `fancy-regex` 内核、自动编码探测与 CRLF 兼容、内置 14 条默认目录规则、智能多规则打分匹配、正文净化与简繁转换）、**PDF**（Android 原生 `PdfRenderer` 高清缩放 + Rust `lopdf` 文本重排双模）、**MOBI / AZW3 / FB2 / MD**；横屏大屏（`≥ 680dp`）支持 **自动/单页/双栏对页**（居中书脊投影 + 按 2 页步进翻页）、素白/轻象牙/青瓷/墨灰夜/纯黑夜纸张预设、段间距滑块、首行缩进开关、左边缘上下滑动亮度调节；仿真贝塞尔卷曲 / 覆盖 / 滑动 / 滚动翻页 + 自动滚屏；长按划词多色高亮与波浪线批注、单页书签、目录面板与 Markdown 笔记导出 |
| **本地 & 在线 TTS 听书** | **本地系统 TTS**（Android `TextToSpeech` 引擎枚举兜底、按引擎/语种列出可用发音人、语速/音调/定时停止/自动翻页与句级高亮跟随）；**内置在线 TTS 客户端**（支持 **Edge TTS** 直连 WSS 与自部署网关、**OpenAI 兼容 `/v1/audio/speech`**、**Legado 自定义 HTTP 模板**及 JSON 导入），支持 100 MB 磁盘 LRU 音频缓存（含配置指纹隔离）、并发预加载、Android Keystore `AES-GCM` 密钥加密存储（不入明文配置与 WebDAV 快照），以及网络异常自动回退本地 TTS |
| **漫画阅读引擎** | **CBZ / ZIP、CB7 / 7Z、PDF、本地图片文件夹**免解压流式解码与 `ComicInfo.xml` 解析；从右到左 / 从左到右 / 条漫无缝滚动 / 双页拼接；横屏自动双页模式，支持封面单独成页（`dualPageShift`）与跨页宽图防拆分独立占位（`buildMangaSpreadSlots`）；Rust 像素级智能白边裁切与跨页检测；Mihon 风格三标签悬浮设置卡（暖色/灰度滤镜、暗室调光、点击区、音量键翻页、LRU 预加载） |
| **智能本地导入 & 历史** | Android SAF 多文件选择 + 持久化监听目录递归扫描 + 系统 `Open-With` 意图接入 + 书籍/漫画智能分拣；Rust Core 三段 64KB SHA-256 快速指纹去重、扩展名与内容识别、0 字节空文件校验、损坏路径自愈与覆盖重导；导入历史支持一键恢复入架或彻底删除 |
| **我的 & WebDAV 同步** | 集成外观与多语言、多书架管理、TTS 语音设置、TXT 目录规则管理与 WebDAV 同步；RFC 4918 WebDAV 客户端（坚果云 429 指数退避 + 坚果云/Alist/Nextcloud/群晖预设）；Layer 1（进度/书架结构/书签/笔记 UUID 三向合并/排版配置 + 冲突决策弹窗）；Layer 2（源文件去重流式上传）；全量 `.zip` 备份快照与一键恢复 |

## 技术架构

```text
Flutter UI (Riverpod + GoRouter + l10n + ResponsiveLayout + FloatingCard / InkIcons)
   ├── C-ABI FFI (RustCoreBridge) ──▶ rust_core (inkbox_core: 书籍/漫画解析、图像裁边、指纹去重、WebDAV 合并与快照)
   ├── PlatformBridge (MethodChannel / EventChannel) ──▶ Android Kotlin MainActivity (SAF、TTS/MediaPlayer、Keystore AES-GCM、PdfRenderer、亮度/音量键、Open-With)
   ├── Online TTS Pipeline (OnlineTtsClient + TtsAudioCache + TtsPlaybackController) ──▶ Edge WSS/Gateway · OpenAI · Legado HTTP (100 MB LRU + 自动回退本地 TTS)
   └── Drift SQLite ──▶ 本地书架、阅读进度、划线批注、目录规则与导入历史持久化
```

## 仓库目录结构

```text
InkBox/
├── app/                                      # Flutter 工程（UI、l10n、Drift 数据库、FFI 桥接、Android Kotlin PlatformBridge）
│   ├── l10n.yaml                             # Flutter gen-l10n 国际化配置
│   ├── assets/txt_toc_rules.json             # 内置 14 条默认 TXT 目录识别规则
│   ├── lib/
│   │   ├── core/                             # 主题系统（Crisp Ink & FloatingCard/经典双模）、l10n 辅助、响应式布局、手绘 SVG 图标、路由与基础控件
│   │   ├── data/                             # Drift SQLite、Rust C-ABI FFI 桥接、PlatformBridge 与 Riverpod Providers
│   │   ├── features/                         # 书架、漫画架、书籍/漫画阅读器、本地与在线 TTS、导入中心、目录规则、外观设置、WebDAV 同步
│   │   └── l10n/                             # 中/英/日 ARB 词条（app_zh.arb / app_en.arb / app_ja.arb）及生成的本地化类
│   ├── android/                              # Android 宿主工程（MainActivity.kt 与多语言 strings.xml）
│   └── test/                                 # Flutter 单元测试、Widget 测试、i18n/双页/在线 TTS 专项与 FFI/WebDAV 联调套件
├── rust_core/                                # 跨平台共享 Rust 核心引擎（inkbox_core）
│   ├── src/                                  # book / comic / importer / webdav / ffi C-ABI 导出层
│   └── tests/                                # 格式解析与 WebDAV 快照集成测试
├── scripts/                                  # Windows / Android 多 ABI Rust 动态库构建脚本
└── docs/                                     # 设计规范（含 design_spec_v0.2.md）、交互原型、高保真设计图与架构选型文档
```

## 环境要求

- **Flutter / Dart SDK**：兼容 `app/pubspec.yaml`（`sdk: ^3.14.0`）
- **Rust 工具链**：`cargo` / `rustc`，Android 构建需安装目标平台：
  - `aarch64-linux-android`
  - `armv7-linux-androideabi`
  - `x86_64-linux-android`
- **Android 开发环境**：Android SDK、Android NDK（需包含 LLVM toolchain）与 JDK 17

## 构建与测试说明

> **重要提示**：仓库通过 `.gitignore` 排除了编译产物与原生 `.so` 动态库。在执行 Android 调试或 `flutter build apk` 打包前，**请务必先运行 `scripts\build_rust_android.ps1 -Release`**，将 Rust 核心编译并输出到 `app\android\app\src\main\jniLibs\`（覆盖 `arm64-v8a`、`armeabi-v7a`、`x86_64` 三个 ABI）。

```powershell
# 1. 运行 Rust Core 全部单元与集成测试
cd rust_core
cargo test

# 2. 编译 Rust Core 动态库
# 2a. Windows 测试动态库（供本地 flutter test 加载 inkbox_core.dll）
powershell -ExecutionPolicy Bypass -File scripts\build_rust_windows.ps1
# 2b. Android Release 动态库（打包 APK 或模拟器运行前必跑，生成 jniLibs/**/*.so）
powershell -ExecutionPolicy Bypass -File scripts\build_rust_android.ps1 -Release

# 3. 运行 Flutter 静态分析与测试套件
cd app
flutter analyze --no-fatal-infos
flutter test -r expanded

# 4. 打包 Android Release APK
cd app
flutter build apk --release
# 或按 ABI 拆分更小安装包：
flutter build apk --release --split-per-abi
```

## 后续演进路线

- **v0.0.2 → V1.0 完善**：持续打磨阅读细节与性能，补齐书内全文搜索、EPUB 插图与脚注内联气泡、阅读时长统计与更多个性化选项。
- **格式与听书能力扩展**：补全 `CBR / RAR` 漫画流式解码与更多在线语音兼容能力。
- **五端逐步落地**：以共享 `rust_core` 与极薄 `PlatformBridge` 为基础，按 **Android → iOS → Windows → HarmonyOS NEXT → macOS** 路线补齐各端原生桥接实现。
