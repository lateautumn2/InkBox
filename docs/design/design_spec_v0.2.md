# 墨匣（InkBox）下一阶段视觉、UI、阅读体验、多语言与在线 TTS 功能设计规格文档

- **目标项目**：墨匣 InkBox（`E:\code\read`，Flutter + Rust Core + Android Kotlin）
- **基线范围**：基于 `v0.0.1` 代码库真实模块结构设计，所有改造可直接映射到 `app/lib/`、`app/android/`、`app/pubspec.yaml`。

---

## 1. 市面及 GitHub 开源阅读器深度对比与选型建议

### 1.1 竞品与开源标杆对比矩阵

| 产品 / 项目 | 核心技术栈 | 配色与视觉审美 | UI 结构与大屏适配 | 阅读体验核心亮点 | 多语言与 TTS 能力 | 对 InkBox 的可借鉴点 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Readest** (`readest/readest`) | Tauri + Next.js | 极简冷灰/中性纸白、低饱和出版风 | 宽屏悬浮侧边栏、双栏并排（Parallel Read）、零冗余图标 | 仿真/平铺翻页、精准页边距与列宽、句级 TTS 高亮跟随、智能图片反色 | 原生多语言；内置 Edge TTS + 系统语音，底部迷你播放器 + AB 复读 | **去牛皮纸化现代纸张配色**、大屏双页居中书脊比例、TTS 句级高亮跟随 |
| **Anx Reader** (`Anxcye/anx-reader`) | Flutter（同栈） | 浅灰/素白/深灰高质感 Material 3 | 干净网格书架、单行状态标签、紧凑弹出层 | 多色划线与笔记导出、阅读时长热力图、自定义字体/字重/段距 | 完整 i18n；支持系统/多音色 TTS、倍速、定时关闭 | **Flutter 同栈极简面板密度**、阅读统计热力图、TTS 定时/语速胶囊交互 |
| **KOReader** (`koreader/koreader`) | Lua + C/C++ | 墨水屏高对比纯黑白灰 | 紧凑单行状态栏、极致手势网格 | 毫米级版心/段距/行距微调、字典查词、高精度裁边与 PDF 重排 | 极多语种；插件支持 Piper/eSpeak/系统 TTS 并可字词同步高亮 | **状态信息单行极简化**、精细排版控制边界 |
| **Legado (阅读)** (`gedoor/legado`) | Android Kotlin | 工具导向高密度、可高度自定义皮肤 | 列表/网格书架、底部 4~5 键清晰阅读菜单 | 正文净化替换、TXT 智能分章规则、自定义翻页/滚屏 | 简体中文为主；**HTTP TTS 标杆**：URL/Method/Headers/Body 模板 + `{{speakSpeed}}` 占位符 | **HTTP TTS 模板体系**、Edge TTS 网关/自定义 HTTP TTS 配置表单、断点续听 |
| **Mihon** (`mihonapp/mihon`) | Android Kotlin | MD3 + 暗室高对比 | **手机 BottomNav ↔ 平板 `NavigationRail` 自适应**、动态网格列数 | 漫画双页布局（自动/单页/双页）、封面首页偏移、日漫/美漫阅读方向与边缘热区 | 多语言完整；无文本 TTS | **平板横屏 `NavigationRail` 切换**、漫画横屏自动双页与跨页宽图防挤压 |
| **Foliate** (`johnfactotum/foliate`) | GTK4 / Libadwaita | 现代桌面留白、柔和纸感 + 微妙书脊投影 | 悬浮弹出气泡（Popover）、不遮挡视口阅读菜单 | 双栏对页布局、书中缝柔光阴影、脚注内联气泡、选中文本即时高亮菜单 | 多语种；系统 Speech-Dispatcher | **双页中缝视觉质感**、大屏居中悬浮设置卡 |
| **Apple Books / Kindle** | 原生 iOS/Android | 素白/浅象牙/石板灰/纯黑（全面淘汰深黄牛皮纸） | 手机底栏、iPad 侧边栏 + 居中最大行宽约束 | 横屏双栏真书体验、丝滑仿真卷页、简洁「Aa」排版入口 | 全球多语种；Apple 神经语音自然度高 | **全局语义配色审美**、大屏单栏最大行宽约束、高频入口收敛至 4~5 个 |
| **ReadEra / Moon+ Reader** | Android 原生 | ReadEra 极简白灰；Moon+ 高可配 | 平板自动切换双页与缩略预览条 | 边缘上下滑动调亮度（Moon+）、无缝横屏双页（ReadEra/Moon+） | 多语言完整；Moon+ 支持系统语音与定时/耳机线控 | **左右边缘手势调亮度**、横屏自动触发双页阅读 |

### 1.2 选型落地路线拆分

#### A. 本期优先落地（P0 / P1）
1. **全局去牛皮纸重构（P0）**：用「澄雾冷灰白 + 砚墨青蓝 + 轻象牙/素白纸张」替换当前 `warmPaperLight` 与默认 `parchment`。
2. **UI 减法与响应式重构（P0）**：删除重复「切换书架/漫画架」胶囊按钮、网格卡片冗余图标及长篇副标题；手机竖屏底部导航，平板/横屏切换左侧 `NavigationRail` + 自适应列数网格 + 浮层最大宽度约束。
3. **平板横屏双屏阅读与手感升级（P0）**：自适应/单页/双页排版模式、大屏单栏居中最大行宽（`640dp`）、左边缘上下滑动调亮度、漫画横屏自动双页与跨页宽图独占整屏。
4. **多语言 i18n 架构（P0）**：`flutter_localizations` + `intl` + ARB（`zh`、`en`、`ja` 及跟随系统），全量 UI 与错误码本地化映射。
5. **TTS 系统重构与在线 TTS（P0）**：修复 `MainActivity.kt` 初始化硬编码与竞态问题，新增本地发音人选择；内置在线 TTS（Edge TTS 直连/网关、OpenAI 兼容、自定义 HTTP 模板），支持安全密钥存储、预加载缓存、句级高亮与断网自动回退本地 TTS。

#### B. 后续演进路线图（P2+）
1. 书内全文搜索与跳转历史栈。
2. EPUB 富文本/插图/脚注气泡弹窗。
3. 阅读统计热力图与每日目标。
4. 划线工具栏 AI 解读 / 词典 / 翻译扩展。
5. OPDS / Calibre 书库与桌面端键鼠快捷键。

---

## 2. 全新配色与视觉设计规范（Crisp Ink & Mineral Paper）

- **日间澄白 `crispLight`**：`canvasBg: #F4F5F7 / #FAFAFB`、`cardSurface: #FFFFFF`、`surfaceVariant: #E9ECF1`、`subtleBorder: #14161A22`、`inkPrimary: #15171C`、`inkMuted: #636A76`、`accentPrimary: #2F5C8F`、`accentSoft: #E3ECF6`、`accentWarm: #CF4B40`、`statusOk: #248A62`。
- **暗夜剧场 `darkTheater`**：`canvasBg: #101216`、`cardSurface: #181B21`、`surfaceVariant: #222630`、`subtleBorder: #17FFFFFF`、`inkPrimary: #ECEDF0`、`inkMuted: #9198A6`、`accentPrimary: #6FA4E0`、`accentSoft: #1F2F43`、`accentWarm: #E86A60`、`statusOk: #4DC191`。
- **OLED 极夜 `oledBlack`**：`canvasBg: #000000`、`cardSurface: #0D0F13`、`surfaceVariant: #171A21`、`subtleBorder: #1CFFFFFF`、`inkPrimary: #E4E6EB`、`inkMuted: #838A98`、`accentSoft: #1A283A`。
- **书籍阅读器纸张预设**：默认 `white`（`#FFFFFF`），原 `parchment` 重构为轻象牙 `#F7F6F2`，`sage` `#EAF2EC`，`dark` `#1A1D22`，`oled` `#000000`。

---

## 3. UI 精简与结构形态重构

- `width < 600dp` 手机竖屏保留紧凑底栏；`width >= 600dp` 平板/横屏切换左侧 `NavigationRail`。
- 书架/漫画架网格改用 `SliverGridDelegateWithMaxCrossAxisExtent` 自适应 3~7 列。
- 删除重复「切换书架/切换漫画架」胶囊、书架网格卡片 `…` 杂乱按钮、漫画封面 `CBZ` 格式角标及卡片底部冗余模式文字、导入页独立「支持类型」大卡、以及全局长篇说明书式副标题。

---

## 4. 平板横屏双屏阅读与体验升级

- 书籍阅读器支持 `Auto / Single / Spread` 布局模式；横屏宽屏（`width >= 680dp`）自动双栏对页排版与 2 页步进翻页，居中 `44dp` 书脊阴影，左/右双 `ReaderHighlightCanvas` 独立交互，并支持左边缘滑动调亮度、段落间距与首行缩进开关、TTS 句级高亮跟随。
- 漫画阅读器支持横屏自动双页及 `isWideSpread` 跨页宽图独占整屏防挤压。

---

## 5. 多语言国际化（i18n）

- 支持简体中文（`zh`）、English（`en`）、日本語（`ja`）与跟随系统，支持应用内热切换；数据库默认分组与默认书架名展示解耦，跨语言筛选兼容。

---

## 6. TTS 系统重构与在线 TTS

- 修复 Android 本地 TTS 初始化硬编码、引擎列表竞态、5s 超时保护与发音人选择。
- 新增内置在线 TTS（Edge TTS 直连与网关 / OpenAI `/v1/audio/speech` / Legado 兼容自定义 HTTP 模板），密钥经 Android Keystore AES-GCM 加密存储（绝不写入 WebDAV 明文配置），支持 100MB LRU 音频缓存、预加载流水线与失败自动无缝回退本地 TTS。
