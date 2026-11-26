# 墨匣（InkBox）— 本地书籍与漫画双引擎阅读器（v0.0.1）

墨匣（InkBox）是一款基于 **Flutter + Rust Core（C-ABI FFI）+ 极薄 PlatformBridge** 构建的本地书籍与漫画双引擎阅读器。  
`v0.0.1` 为项目的首个 **Android 端基线版本**，整体架构面向 **Android → iOS → Windows → HarmonyOS NEXT → macOS** 五端平滑演进。

## 设计与架构文档

- **原型与 UI/交互设计规范**：[docs/design/design_spec.md](./docs/design/design_spec.md)
- **可交互原型（HTML）**：[docs/design/prototype.html](./docs/design/prototype.html)
- **高保真 UI 设计图**：[docs/design/mockups/](./docs/design/mockups/)（含 `05_floating_card_handdrawn_icons.jpg` FloatingCard 与手绘单色线性图标规范）
- **技术选型与五端架构**：[docs/architecture/tech_selection.md](./docs/architecture/tech_selection.md)

## v0.0.1 已实现核心能力

| 模块 | 已实现功能 |
| :--- | :--- |
| **视觉体系** | Material Design 3 + **FloatingCard 悬浮卡片风格**（支持与经典贴边布局切换）、**全套手绘单色线性 SVG 图标**（`InkIcons`）、定制输入框/底部选择器/开关组件、暖纸日间 / 暗室漫底 / OLED 纯黑 / Monet 动态取色（入口收敛在「我的」→「主题预设」） |
| **书架 & 漫画架** | 零预置示例数据、**多书架 / 多漫画架管理**（支持新建/重命名/切换与跨书架移入，保留「所有 / 在读 / 已读完」状态分组）、紧凑 3 列网格与列表视图、搜索与多维排序、继续阅读浮卡、长按批量操作、详情页章节浏览与编码/目录规则配置、移出书架（保留导入历史）或彻底删除双策略 |
| **书籍阅读引擎** | **EPUB**（NCX + EPUB3 Nav + 百分号解码目录）、**TXT**（Rust `fancy-regex` 内核、自动编码探测与 CRLF 兼容、内置 14 条默认目录规则、智能多规则打分匹配、正文净化与简繁转换）、**PDF**（Android 原生 `PdfRenderer` 高清缩放 + Rust `lopdf` 文本重排双模）、**MOBI / AZW3 / FB2 / MD**；贝塞尔仿真卷曲 / 覆盖 / 滑动 / 滚动翻页 + 自动滚屏；长按划词多色高亮与波浪线批注、单页书签、目录面板与 Markdown 笔记导出；Android 原生 **TTS 听书**（语速、音调、语种、引擎切换、自动翻页与定时停止） |
| **漫画阅读引擎** | **CBZ / ZIP、CB7 / 7Z、PDF、本地图片文件夹**免解压流式解码与 `ComicInfo.xml` 解析；从右到左 / 从左到右 / 条漫无缝滚动 / 双页拼接；Rust 像素级智能白边裁切与跨页检测；Mihon 风格三标签悬浮设置卡（暖色/灰度滤镜、暗室调光、点击区、音量键翻页、LRU 预加载） |
| **智能本地导入 & 历史** | Android SAF 多文件选择 + 持久化监听目录递归扫描 + 系统 `Open-With` 意图接入 + 书籍/漫画智能分拣；Rust Core 三段 64KB SHA-256 快速指纹去重、扩展名与内容识别、0 字节空文件校验、损坏路径自愈与覆盖重导；导入历史支持一键恢复入架或彻底删除 |
| **我的 & WebDAV 同步** | 底部 4-Tab 导航（「书架 / 漫画 / 导入 / 我的」），集成主题预设、多书架管理、TTS 语音设置、TXT 目录规则管理与 WebDAV 同步；RFC 4918 WebDAV 客户端（坚果云 429 指数退避 + 坚果云/Alist/Nextcloud/群晖预设）；Layer 1（进度/书架结构/书签/笔记 UUID 三向合并/排版配置 + 冲突决策弹窗）；Layer 2（源文件去重流式上传）；全量 `.zip` 备份快照与一键恢复 |

## 技术架构

```text
Flutter UI (Riverpod + GoRouter + FloatingCard / InkIcons)
   ├── C-ABI FFI (RustCoreBridge) ──▶ rust_core (inkbox_core: 书籍/漫画解析、图像裁边、指纹去重、WebDAV 合并与快照)
   ├── PlatformBridge (MethodChannel / EventChannel) ──▶ Android Kotlin MainActivity (SAF、TTS、PdfRenderer、亮度/音量键、Open-With)
   └── Drift SQLite ──▶ 本地书架、阅读进度、划线批注、目录规则与导入历史持久化
```

## 仓库目录结构

```text
InkBox/
├── app/                                      # Flutter 工程（UI、Drift 数据库、FFI 桥接、Android Kotlin PlatformBridge）
│   ├── assets/txt_toc_rules.json             # 内置 14 条默认 TXT 目录识别规则
│   ├── lib/
│   │   ├── core/                             # 主题系统（FloatingCard/经典双模）、手绘 SVG 图标、路由与基础控件
│   │   ├── data/                             # Drift SQLite、Rust C-ABI FFI 桥接、PlatformBridge 与 Riverpod Providers
│   │   └── features/                         # 书架、漫画架、书籍/漫画阅读器、导入中心、目录规则、TTS、WebDAV 同步
│   ├── android/                              # Android 宿主工程（MainActivity.kt 实现原生 PlatformBridge）
│   └── test/                                 # Flutter 单元测试、Widget 测试与 FFI/WebDAV 联调套件
├── rust_core/                                # 跨平台共享 Rust 核心引擎（inkbox_core）
│   ├── src/                                  # book / comic / importer / webdav / ffi C-ABI 导出层
│   └── tests/                                # 格式解析与 WebDAV 快照集成测试
├── scripts/                                  # Windows / Android 多 ABI Rust 动态库构建脚本
└── docs/                                     # 设计规范、交互原型、高保真设计图与架构选型文档
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
flutter analyze
flutter test

# 4. 打包 Android Release APK
cd app
flutter build apk --release
# 或按 ABI 拆分更小安装包：
flutter build apk --release --split-per-abi
```

## 后续演进路线

- **v0.0.1 → V1.0 完善**：Android 真机与模拟器全链路联调、UI 细节与交互打磨、性能与内存持续优化。
- **格式与阅读体验扩展**：补全 `CBR / RAR` 漫画流式解码、多语言与在线 TTS 语音能力、更多阅读个性化选项。
- **五端逐步落地**：以共享 `rust_core` 与极薄 `PlatformBridge` 为基础，按 **Android → iOS → Windows → HarmonyOS NEXT → macOS** 路线补齐各端原生桥接实现。
