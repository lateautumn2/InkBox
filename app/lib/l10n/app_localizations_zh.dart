// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '墨匣 InkBox';

  @override
  String get navBooks => '书架';

  @override
  String get navManga => '漫画';

  @override
  String get navImport => '导入';

  @override
  String get navMe => '我的';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get save => '保存';

  @override
  String get create => '创建';

  @override
  String get delete => '删除';

  @override
  String get confirmDelete => '确认删除';

  @override
  String get edit => '编辑';

  @override
  String get rename => '重命名';

  @override
  String get close => '关闭';

  @override
  String get reset => '重置';

  @override
  String get search => '搜索';

  @override
  String get refresh => '刷新';

  @override
  String get copy => '复制';

  @override
  String get restore => '恢复';

  @override
  String get open => '打开';

  @override
  String get retry => '重试';

  @override
  String get clear => '清空';

  @override
  String get details => '详情';

  @override
  String get none => '无';

  @override
  String get loading => '加载中...';

  @override
  String get shelfGroupAll => '全部';

  @override
  String get shelfGroupReading => '在读';

  @override
  String get shelfGroupFinished => '已读完';

  @override
  String get defaultBookshelf => '默认书架';

  @override
  String get defaultMangaShelf => '默认漫画架';

  @override
  String get unknownAuthor => '未知作者';

  @override
  String get readyToRead => '准备阅读';

  @override
  String shelvesCountBadge(int count) {
    return '$count架';
  }

  @override
  String selectedCountBooks(int count) {
    return '已选 $count 本';
  }

  @override
  String selectedCountManga(int count) {
    return '已选 $count 部';
  }

  @override
  String get sortBy => '排序方式';

  @override
  String get sortLastRead => '按最近阅读';

  @override
  String get sortAddedAt => '按添加时间';

  @override
  String get sortTitle => '按书名';

  @override
  String get sortProgress => '按阅读进度';

  @override
  String get gridView => '网格视图';

  @override
  String get listView => '列表视图';

  @override
  String get searchBooks => '搜索书籍';

  @override
  String get searchBooksHint => '搜索书名或作者...';

  @override
  String get searchManga => '搜索漫画';

  @override
  String get searchMangaHint => '搜索漫画名或作者...';

  @override
  String get continueReading => '继续阅读';

  @override
  String get emptyLibraryBooks => '书架还是空的，导入你的第一本书吧';

  @override
  String emptyShelfBooks(String shelfName) {
    return '「$shelfName」暂无书籍';
  }

  @override
  String get emptyGroupBooks => '当前分组暂无书籍';

  @override
  String get importLocalBooks => '导入本地书籍';

  @override
  String get switchOtherShelf => '切换书架';

  @override
  String get emptyLibraryManga => '漫画架还是空的，前往导入添加吧';

  @override
  String emptyShelfManga(String shelfName) {
    return '「$shelfName」暂无漫画';
  }

  @override
  String get emptyGroupManga => '当前分组暂无漫画';

  @override
  String get importLocalManga => '导入本地漫画';

  @override
  String bookshelfLoadError(String error) {
    return '书架加载失败：$error';
  }

  @override
  String mangaShelfLoadError(String error) {
    return '漫画架加载失败：$error';
  }

  @override
  String get moveShelf => '移架';

  @override
  String get markFinished => '标为读完';

  @override
  String get markReading => '标为在读';

  @override
  String get removeBooks => '移除';

  @override
  String get markAllRead => '标为已读';

  @override
  String get resetUnread => '标为未读';

  @override
  String get removeManga => '移除';

  @override
  String moveBookSuccess(int count, String target) {
    return '已将 $count 本书移至「$target」';
  }

  @override
  String moveMangaSuccess(int count, String target) {
    return '已将 $count 部漫画移至「$target」';
  }

  @override
  String removeBooksTitle(int count) {
    return '移除选中的 $count 本书籍';
  }

  @override
  String removeMangaTitle(int count) {
    return '移除选中的 $count 部漫画';
  }

  @override
  String removeBookTitleSingle(String title) {
    return '移除《$title》';
  }

  @override
  String get removeArchiveOption => '移出书架（保留导入历史）';

  @override
  String get removeArchiveMangaOption => '移出漫画架（保留导入历史）';

  @override
  String get removePermanentOption => '彻底删除';

  @override
  String archivedBooksToast(int count) {
    return '已移出 $count 本书';
  }

  @override
  String deletedBooksToast(int count) {
    return '已彻底删除 $count 本书';
  }

  @override
  String get bookDetailsTitle => '书籍详情';

  @override
  String get mangaDetailsTitle => '漫画详情';

  @override
  String get notFoundBook => '未找到该书籍';

  @override
  String get notFoundManga => '未找到该漫画';

  @override
  String get movedShelfSuccess => '已修改所属书架';

  @override
  String get pinToShelf => '置顶';

  @override
  String get unpinFromShelf => '取消置顶';

  @override
  String get editMetadata => '编辑信息';

  @override
  String get bookTitleLabel => '书名';

  @override
  String get authorLabel => '作者';

  @override
  String get shelfBelongsTo => '所属书架';

  @override
  String get orCreateShelf => '或新建书架';

  @override
  String get readingStatusLabel => '阅读状态';

  @override
  String readingMinutesShort(int mins) {
    return '$mins 分钟';
  }

  @override
  String readProgressShort(String pct) {
    return '已读 $pct%';
  }

  @override
  String tocChaptersCount(int count) {
    return '章节目录 ($count)';
  }

  @override
  String get ascendingOrder => '正序';

  @override
  String get descendingOrder => '倒序';

  @override
  String get fullToc => '全部目录';

  @override
  String expandFullToc(int count) {
    return '查看全部 $count 章';
  }

  @override
  String get noTocFound => '未解析到目录章节';

  @override
  String get currentReadingTag => '当前';

  @override
  String txtRuleEncodingMeta(String rule, String encoding) {
    return '规则：$rule · 编码：$encoding';
  }

  @override
  String get smartAutoDetect => '自动识别';

  @override
  String get switchTocRule => '目录规则';

  @override
  String get switchEncoding => '文本编码';

  @override
  String get manageRuleLibrary => '规则库';

  @override
  String get selectTocRuleTitle => '选择目录识别规则';

  @override
  String get autoDetectRecommended => '智能自动识别';

  @override
  String ruleUnmatchedTag(String name) {
    return '$name（未匹配）';
  }

  @override
  String tocReloadedCount(int count) {
    return '已更新目录（$count 章）';
  }

  @override
  String tocNoMatchFallback(int count) {
    return '未匹配到章节，已按默认分段（$count 节）';
  }

  @override
  String get selectEncodingTitle => '选择文本编码';

  @override
  String get encodingAuto => '自动检测';

  @override
  String get encodingGb18030 => 'GB18030 / GBK';

  @override
  String get encodingBig5 => 'Big5';

  @override
  String encodingSwitched(String encoding) {
    return '已切换编码：$encoding';
  }

  @override
  String get annotationsTitle => '书签与划线';

  @override
  String get noAnnotationsHint => '暂无书签或划线笔记';

  @override
  String get bookmarkTag => '书签';

  @override
  String get highlightNoteTag => '想法';

  @override
  String get highlightTag => '划线';

  @override
  String chapterLabelShort(int index) {
    return '第 $index 章';
  }

  @override
  String get localFileInfo => '本地文件';

  @override
  String pathLabel(String path) {
    return '路径：$path';
  }

  @override
  String fingerprintLabel(String hash) {
    return '指纹：$hash';
  }

  @override
  String get searchChapterHint => '搜索章节...';

  @override
  String get noMatchingChapters => '未找到匹配章节';

  @override
  String get mangaDefaultModeLabel => '阅读方向';

  @override
  String get smartCropLabel => '智能白边裁切';

  @override
  String get splitWidePagesLabel => '跨页自动切分';

  @override
  String chaptersVolumeList(int count) {
    return '章节列表 ($count)';
  }

  @override
  String get unreadOnly => '仅未读';

  @override
  String get unreadOnlyActive => '仅未读 ✓';

  @override
  String get noChaptersMatchHint => '当前筛选下无章节';

  @override
  String get startReading => '开始阅读';

  @override
  String get readLabel => '已读';

  @override
  String pageOfTotalUnknown(int current, String total) {
    return '第 $current/$total 页';
  }

  @override
  String get markAllReadMenu => '全部标记已读';

  @override
  String get resetUnreadMenu => '全部重置未读';

  @override
  String get moveMangaShelfMenu => '修改所属漫画架';

  @override
  String get shelfNameExists => '名称已存在';

  @override
  String get shelfRenameConflict => '名称未变更或已存在';

  @override
  String deleteShelfTitle(String name) {
    return '删除「$name」';
  }

  @override
  String deleteShelfConfirm(String fallback) {
    return '作品将移入「$fallback」，本地文件保留。';
  }

  @override
  String get createShelfTitle => '新建书架';

  @override
  String get createMangaShelfTitle => '新建漫画架';

  @override
  String get renameShelfTitle => '重命名书架';

  @override
  String get renameMangaShelfTitle => '重命名漫画架';

  @override
  String get shelfNameLabel => '名称';

  @override
  String get newNameLabel => '新名称';

  @override
  String get switchBookshelfTitle => '切换书架';

  @override
  String get switchMangaShelfTitle => '切换漫画架';

  @override
  String get multiShelfManagerTitle => '书架与漫画架';

  @override
  String get bookshelfTab => '书架';

  @override
  String get mangaShelfTab => '漫画架';

  @override
  String get defaultShelfBadge => '默认';

  @override
  String shelfItemCountBook(int count) {
    return '$count 本';
  }

  @override
  String shelfItemCountManga(int count) {
    return '$count 部';
  }

  @override
  String get inUseLabel => '当前';

  @override
  String get moveToShelfTitleBook => '移至书架';

  @override
  String get moveToShelfTitleManga => '移至漫画架';

  @override
  String get orCreateAndMoveBook => '或新建书架并移入';

  @override
  String get orCreateAndMoveManga => '或新建漫画架并移入';

  @override
  String get shelfExampleBook => '例如：历史、随笔';

  @override
  String get shelfExampleManga => '例如：连载、完结';

  @override
  String get mineTitle => '我的';

  @override
  String get appearanceSettings => '外观与主题';

  @override
  String get themePresets => '主题预设';

  @override
  String get uiStyleLabel => '界面风格';

  @override
  String get uiStyleFloating => '悬浮卡片';

  @override
  String get uiStyleClassic => '经典贴边';

  @override
  String get colorThemeLabel => '色彩模式';

  @override
  String get themeCrispLight => '澄白日间';

  @override
  String get themeDarkTheater => '暗夜剧场';

  @override
  String get themeOledBlack => 'OLED 纯黑';

  @override
  String get themeFollowSystem => '跟随系统';

  @override
  String get dynamicColorTitle => 'Material You 取色';

  @override
  String get dynamicColorSubtitle => '跟随系统壁纸强调色';

  @override
  String get appLanguageTitle => '语言 / Language';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageEn => 'English';

  @override
  String get languageJa => '日本語';

  @override
  String get statBooks => '藏书';

  @override
  String get statReading => '在读';

  @override
  String get statFinished => '读完';

  @override
  String get statMinutes => '分钟';

  @override
  String get sectionAppearanceLanguage => '外观与语言';

  @override
  String get sectionReadingSync => '阅读与同步';

  @override
  String get multiShelfManagerMenu => '多书架管理';

  @override
  String multiShelfSummary(int books, int manga) {
    return '书架 $books · 漫画架 $manga';
  }

  @override
  String get ttsMenuTitle => 'TTS 语音朗读';

  @override
  String ttsMenuSummaryLocal(String rate) {
    return '系统引擎 · ${rate}x';
  }

  @override
  String ttsMenuSummaryOnline(String name, String rate) {
    return '在线语音 · $name · ${rate}x';
  }

  @override
  String get tocRulesMenuTitle => 'TXT 目录规则';

  @override
  String tocRulesMenuSummary(int enabled, int total) {
    return '$enabled / $total 启用';
  }

  @override
  String get webdavMenuTitle => 'WebDAV 同步';

  @override
  String get webdavUnconfigured => '未配置';

  @override
  String get importHubTitle => '导入中心';

  @override
  String get rescanFolders => '重新扫描';

  @override
  String get supportedFormats => '支持格式';

  @override
  String supportedFormatsBooks(String formats) {
    return '书籍：$formats';
  }

  @override
  String supportedFormatsManga(String formats) {
    return '漫画：$formats';
  }

  @override
  String get supportedFormatsImageFolder => '图片文件夹';

  @override
  String get pickLocalFiles => '选择本地文件';

  @override
  String get addAndScanFolder => '扫描本地目录';

  @override
  String get importOptions => '导入选项';

  @override
  String get smartAutoClassify => '智能分拣书漫';

  @override
  String get overwriteDuplicates => '覆盖已存在文件';

  @override
  String watchedFoldersTitle(int count) {
    return '监听目录 ($count)';
  }

  @override
  String get formatAll => '全部';

  @override
  String get formatComicArchive => '漫画';

  @override
  String importHistoryTitle(int count) {
    return '导入历史 ($count)';
  }

  @override
  String get historyAll => '全部';

  @override
  String get historyArchived => '已移出';

  @override
  String get historyOnShelf => '在架';

  @override
  String get noImportHistory =>
      '暂无导入历史，支持 EPUB / TXT / PDF / MOBI / AZW3 / FB2 / MD / CBZ / CB7';

  @override
  String get noMatchingHistory => '当前筛选下无记录';

  @override
  String get fileMissingBadge => '缺失';

  @override
  String get archivedBadge => '已移出';

  @override
  String get onShelfBadge => '在架';

  @override
  String get restoreToShelf => '入架';

  @override
  String get readNow => '阅读';

  @override
  String get permanentDeleteTitle => '彻底删除';

  @override
  String permanentDeleteConfirm(String title) {
    return '确定彻底删除《$title》？将清除记录与本地缓存，无法恢复。';
  }

  @override
  String deletedForeverToast(String title) {
    return '已彻底删除《$title》';
  }

  @override
  String fileMissingReimportToast(String title) {
    return '《$title》文件不存在，请重新导入';
  }

  @override
  String restoredToShelfToast(String title) {
    return '已恢复《$title》到书架';
  }

  @override
  String folderScanDoneToast(int count) {
    return '扫描完成：发现 $count 个文件';
  }

  @override
  String importResultSummary(int books, int manga) {
    return '导入完成：书籍 +$books，漫画 +$manga';
  }

  @override
  String importResultSkipped(int count) {
    return '，重复 $count';
  }

  @override
  String importResultFailed(int count) {
    return '，失败 $count';
  }

  @override
  String get viewBookshelf => '查看书架';

  @override
  String get viewMangaShelf => '查看漫画';

  @override
  String get lastImportResultTitle => '导入结果';

  @override
  String get collapseLabel => '收起';

  @override
  String importedStatus(String title) {
    return '已入架：《$title》';
  }

  @override
  String repairedStatus(String title) {
    return '已更新：《$title》';
  }

  @override
  String duplicateStatus(String title) {
    return '已在架：《$title》';
  }

  @override
  String get overwriteReimport => '覆盖';

  @override
  String overwriteSuccessToast(String title) {
    return '已覆盖更新《$title》';
  }

  @override
  String overwriteFailedToast(String error) {
    return '覆盖失败：$error';
  }

  @override
  String selectedCandidatesCount(int count) {
    return '已选 $count 项';
  }

  @override
  String importToShelfCount(int count) {
    return '导入 ($count)';
  }

  @override
  String get switchToBook => '改书';

  @override
  String get switchToComic => '改漫';

  @override
  String get classifiedAsBook => '书籍';

  @override
  String get classifiedAsComic => '漫画';

  @override
  String historyBookSubtitle(String author, int pct) {
    return '$author · $pct%';
  }

  @override
  String historyMangaSubtitle(String author, int chapters) {
    return '$author · $chapters 话';
  }

  @override
  String get emptyChapterPlaceholder => '（本章节暂无正文内容）';

  @override
  String get firstPageToast => '已是第一页';

  @override
  String get lastPageToast => '已是最后一页';

  @override
  String get chapterFinishedToast => '本话已读完';

  @override
  String get bookmarkAddedToast => '已添加书签';

  @override
  String get bookmarkRemovedToast => '已取消书签';

  @override
  String get addBookmarkTooltip => '添加书签';

  @override
  String get removeBookmarkTooltip => '取消书签';

  @override
  String get highlightNotesTooltip => '划线笔记';

  @override
  String get ttsListenTooltip => '听书';

  @override
  String get originalPdf => '原版 PDF';

  @override
  String get textReflow => '文本重排';

  @override
  String get prevChapter => '上一章';

  @override
  String get nextChapter => '下一章';

  @override
  String get readerTabToc => '目录';

  @override
  String get readerTabDark => '夜间';

  @override
  String get readerTabLight => '日间';

  @override
  String get readerTabStyle => '排版';

  @override
  String get readerTabTurn => '翻页';

  @override
  String get readerTabMore => '更多';

  @override
  String get paperWhite => '素白';

  @override
  String get paperIvory => '轻象牙';

  @override
  String get paperSage => '青瓷';

  @override
  String get paperDark => '墨灰夜';

  @override
  String get paperOled => '纯黑夜';

  @override
  String get turnSimulation => '仿真';

  @override
  String get turnCover => '覆盖';

  @override
  String get turnSlide => '滑动';

  @override
  String get turnScroll => '滚动';

  @override
  String get layoutModeLabel => '版面';

  @override
  String get layoutAuto => '自适应';

  @override
  String get layoutSingle => '单页';

  @override
  String get layoutDual => '双页';

  @override
  String get fontSizeLabel => '字号';

  @override
  String get lineHeightLabel => '行距';

  @override
  String get paragraphSpacingLabel => '段距';

  @override
  String get firstLineIndentLabel => '首行缩进';

  @override
  String get chineseOriginal => '原字';

  @override
  String get chineseTrad => '繁體';

  @override
  String get chineseSimp => '简体';

  @override
  String get tapZoneLabel => '点击区';

  @override
  String get tapZoneStandard => '常规左右';

  @override
  String get tapZoneLeftHand => '左手单手';

  @override
  String get tapZoneRightHand => '右手单手';

  @override
  String get tapZoneCustom => '自定义';

  @override
  String get autoScrollLabel => '自动滚屏';

  @override
  String get startAutoScroll => '开启';

  @override
  String get stopAutoScroll => '停止';

  @override
  String get autoScrollReachedEnd => '已滚屏至末尾';

  @override
  String get volumeKeyPaging => '音量键翻页';

  @override
  String get keepScreenOn => '保持常亮';

  @override
  String get edgeBrightnessGesture => '边缘滑动调亮度';

  @override
  String brightnessIndicator(int pct) {
    return '亮度 $pct%';
  }

  @override
  String get ttsSettingsBtn => 'TTS 设置';

  @override
  String get purificationBtn => '正文净化';

  @override
  String get exportNotesBtn => '导出笔记';

  @override
  String exportNotesSuccess(int count) {
    return '已复制 $count 条笔记到剪贴板';
  }

  @override
  String get purificationDialogTitle => '添加正文净化规则';

  @override
  String get purificationPatternLabel => '过滤文本或正则';

  @override
  String get purificationPatternHint => '例如：请收藏本站.*';

  @override
  String get purificationReplacementLabel => '替换为（留空删除）';

  @override
  String get purificationReplacementHint => '留空即删除';

  @override
  String get addAndApply => '添加';

  @override
  String get highlightAction => '划线';

  @override
  String get writeNoteAction => '写想法';

  @override
  String get editNoteAction => '改想法';

  @override
  String get deleteHighlightAction => '删除划线';

  @override
  String get highlightSavedToast => '已添加划线';

  @override
  String get noteSavedToast => '已保存想法';

  @override
  String get highlightDeletedToast => '已删除划线';

  @override
  String get copiedToast => '已复制';

  @override
  String get addNoteTitle => '添加想法';

  @override
  String get editNoteTitle => '编辑想法';

  @override
  String get yourNoteLabel => '想法内容';

  @override
  String get yourNoteHint => '写下此刻批注...';

  @override
  String get saveHighlightNote => '保存';

  @override
  String get pdfBitmapNoHighlightToast => '原版 PDF 暂不支持划线，请先切换文本重排';

  @override
  String get noHighlightableTextToast => '当前页面无可划线文本';

  @override
  String get pdfUnsupportedPlatform => '当前平台不支持 PDF 位图渲染，请切换文本重排';

  @override
  String scrollModeLabel(int cur, int total) {
    return '第 $cur/$total 章 · 滚动';
  }

  @override
  String tocTabTitle(int count) {
    return '目录 ($count)';
  }

  @override
  String annotationsTabTitle(int count) {
    return '书签/划线 ($count)';
  }

  @override
  String get noAnnotationsReaderHint => '暂无书签与划线';

  @override
  String get endOfChapterHint => '本章完';

  @override
  String nextChapterHint(String title) {
    return '下一章：$title';
  }

  @override
  String notePrefix(String note) {
    return '想法：$note';
  }

  @override
  String get mangaReadingModeRtl => '从右到左';

  @override
  String get mangaReadingModeLtr => '从左到右';

  @override
  String get mangaReadingModeWebtoon => '条漫滚动';

  @override
  String get mangaReadingModeDual => '双页拼接';

  @override
  String get mangaScaleFitScreen => '适应屏幕';

  @override
  String get mangaScaleFitWidth => '适应宽度';

  @override
  String get mangaScaleFitHeight => '适应高度';

  @override
  String get mangaScaleOriginal => '原始尺寸';

  @override
  String get mangaTapLShaped => 'L型单手';

  @override
  String get mangaTapEdge => '左右边缘';

  @override
  String get mangaTapKindle => 'Kindle';

  @override
  String get mangaTapDisabled => '仅滑动';

  @override
  String get mangaBgBlack => '纯黑';

  @override
  String get mangaBgDarkGrey => '深灰';

  @override
  String get mangaBgCoolGrey => '冷灰';

  @override
  String get mangaBgWhite => '纯白';

  @override
  String get mangaTabMode => '阅读模式';

  @override
  String get mangaTabFilter => '图像滤镜';

  @override
  String get mangaTabGeneral => '常规';

  @override
  String get mangaAutoDualLandscape => '横屏自动双页';

  @override
  String get mangaCoverAlone => '封面首页独立单页';

  @override
  String get mangaAutoCrop => '智能白边裁切';

  @override
  String get mangaWarmFilter => '夜间暖色护眼';

  @override
  String get mangaGrayscaleFilter => '黑白对比增强';

  @override
  String get mangaDimmerLabel => '暗室调光';

  @override
  String get mangaCanvasBgLabel => '画布底色';

  @override
  String get mangaTapLayoutLabel => '点击翻页布局';

  @override
  String get mangaShowPageBadge => '显示底角页码';

  @override
  String get mangaNoImagesInChapter => '该章节暂无图片';

  @override
  String get mangaDecodeFailed => '页面解码失败';

  @override
  String get mangaToggleCropTooltip => '智能裁边';

  @override
  String get mangaToggleSettingsTooltip => '阅读设置';

  @override
  String get ttsSettingsTitle => 'TTS 语音设置';

  @override
  String get ttsResetToast => '已恢复默认配置';

  @override
  String get ttsModeLocal => '系统 TTS';

  @override
  String get ttsModeOnline => '在线 TTS';

  @override
  String get ttsSpeechRate => '语速';

  @override
  String get ttsSpeechPitch => '音调';

  @override
  String get ttsPitchLow => '低沉 0.8';

  @override
  String get ttsPitchNormal => '标准 1.0';

  @override
  String get ttsPitchHigh => '清亮 1.2';

  @override
  String get ttsAutoTurnPage => '自动翻页续读';

  @override
  String get ttsSleepTimer => '定时关闭';

  @override
  String get ttsTimerOff => '不限';

  @override
  String ttsTimerMinutes(int mins) {
    return '$mins 分钟';
  }

  @override
  String get ttsTimerChapterEnd => '播完本章';

  @override
  String get ttsEngineLabel => '系统引擎';

  @override
  String get ttsSystemDefaultEngine => '系统默认引擎';

  @override
  String get ttsLanguageLabel => '朗读语种';

  @override
  String get ttsLangSystem => '跟随系统';

  @override
  String get ttsLangZhCn => '中文（普通话）';

  @override
  String get ttsLangZhTw => '中文（台湾）';

  @override
  String get ttsLangZhHk => '中文（粤语）';

  @override
  String get ttsLangEnUs => 'English (US)';

  @override
  String get ttsLangJaJp => '日本語';

  @override
  String get ttsVoiceLabel => '发音人';

  @override
  String get ttsVoiceDefault => '跟随引擎默认';

  @override
  String get ttsVoiceOffline => '离线';

  @override
  String get ttsVoiceNetwork => '联网';

  @override
  String get ttsRefreshEngines => '刷新引擎列表';

  @override
  String get ttsPreviewBtn => '试听效果';

  @override
  String get ttsStopPreviewBtn => '停止试听';

  @override
  String get ttsOpenSystemSettings => '打开系统 TTS 设置';

  @override
  String get ttsNewProfile => '新建方案';

  @override
  String get ttsEditProfile => '编辑方案';

  @override
  String get ttsDeleteProfile => '删除方案';

  @override
  String get ttsImportLegado => '导入 Legado JSON';

  @override
  String get ttsProviderEdge => 'Edge TTS';

  @override
  String get ttsProviderOpenAi => 'OpenAI 兼容';

  @override
  String get ttsProviderCustomHttp => '自定义 HTTP';

  @override
  String get ttsProfileNameLabel => '方案名称';

  @override
  String get ttsEdgeModeLabel => '连接方式';

  @override
  String get ttsEdgeDirect => '内置直连 (Beta)';

  @override
  String get ttsEdgeGateway => '自部署网关';

  @override
  String get ttsEndpointLabel => '接口地址 (URL)';

  @override
  String get ttsApiKeyLabel => 'API 密钥（安全加密存储）';

  @override
  String get ttsApiKeyHint => '选填，部分自建服务无需密钥';

  @override
  String get ttsModelLabel => '模型';

  @override
  String get ttsVoiceIdLabel => '音色 / Voice ID';

  @override
  String get ttsFormatLabel => '音频格式';

  @override
  String get ttsHttpMethodLabel => '请求方法';

  @override
  String get ttsHeadersJsonLabel => 'Headers (JSON)';

  @override
  String get ttsBodyTemplateLabel => 'Body 模板';

  @override
  String get ttsTemplateHint =>
      '支持变量：{{text}} {{textEncoded}} {{voice}} {{rate}} {{ratePct}} {{pitch}} {{speakSpeed}}';

  @override
  String get ttsTestAndPreview => '测试连通并试听';

  @override
  String get ttsTestingConnection => '测试中...';

  @override
  String ttsTestConnected(int ms) {
    return '已连通 · $ms ms';
  }

  @override
  String ttsTestFailed(String detail) {
    return '连接失败：$detail';
  }

  @override
  String get ttsFallbackLocalLabel => '失败自动回退系统 TTS';

  @override
  String ttsClearCacheLabel(String size) {
    return '清理音频缓存 ($size)';
  }

  @override
  String get ttsCacheClearedToast => '已清理在线语音缓存';

  @override
  String ttsPlayingStatus(String label, String rate) {
    return '$label · ${rate}x';
  }

  @override
  String get ttsOnlineFallbackNotice => '在线语音不可用，已切换系统朗读';

  @override
  String get ttsPrevSentence => '上一句';

  @override
  String get ttsNextSentence => '下一句';

  @override
  String get ttsPause => '暂停';

  @override
  String get ttsResume => '继续';

  @override
  String get ttsStop => '停止';

  @override
  String get ttsStoppedToast => '已停止听书';

  @override
  String get ttsStartedToast => '开始语音朗读';

  @override
  String get ttsUnavailableToast => '当前无可朗读内容或语音服务不可用';

  @override
  String get ttsTimerExpiredToast => '定时关闭已到';

  @override
  String get ttsSleepChapterDoneToast => '本章朗读完毕，已定时停止';

  @override
  String get tocRulesTitle => 'TXT 目录规则';

  @override
  String get newRuleTooltip => '新建规则';

  @override
  String get moreActionsTooltip => '更多操作';

  @override
  String get importRuleFile => '导入文件';

  @override
  String get pasteJsonImport => '粘贴 JSON';

  @override
  String get noTocRules => '暂无目录规则';

  @override
  String get restoreDefaultRules => '恢复默认规则';

  @override
  String get customBadge => '自定义';

  @override
  String examplePrefix(String example) {
    return '示例：$example';
  }

  @override
  String get editTestBtn => '编辑 / 测试';

  @override
  String get ruleNameLabel => '规则名称';

  @override
  String get regexLabel => '正则表达式';

  @override
  String get sampleTextLabel => '测试文本';

  @override
  String get liveTestBtn => '测试匹配';

  @override
  String get deleteRuleTitle => '删除规则';

  @override
  String deleteRuleConfirm(String name) {
    return '确定删除「$name」吗？';
  }

  @override
  String get tocActionsTitle => '规则库操作';

  @override
  String get exportToClipboard => '导出规则 JSON';

  @override
  String get restoreBuiltinRules => '恢复内置规则';

  @override
  String get pasteImportTitle => '粘贴导入规则';

  @override
  String get ruleJsonOrRegexLabel => 'Legado JSON 或 名称::正则';

  @override
  String get pasteFromClipboard => '粘贴剪贴板';

  @override
  String get importRulesBtn => '导入';

  @override
  String get newRuleTitle => '新建规则';

  @override
  String get editRuleTitle => '编辑规则';

  @override
  String get webdavTitle => 'WebDAV 同步';

  @override
  String get webdavConfigureTooltip => '配置服务器';

  @override
  String get webdavCenterTitle => 'WebDAV 同步中心';

  @override
  String get webdavOnline => '在线';

  @override
  String get webdavOffline => '待连接';

  @override
  String get webdavSyncNow => '立即同步';

  @override
  String get webdavSyncing => '同步中...';

  @override
  String get webdavCreateBackup => '创建快照';

  @override
  String get webdavSyncScope => '同步范围';

  @override
  String get webdavScopeProgress => '进度与书签';

  @override
  String get webdavScopeProgressDesc => '跨端增量合并阅读位置';

  @override
  String get webdavScopeMeta => '书架与笔记';

  @override
  String get webdavScopeMetaDesc => '书架分组、划线与批注';

  @override
  String get webdavScopePrefs => '排版与主题';

  @override
  String get webdavScopePrefsDesc => '阅读字号、配色与外观';

  @override
  String get webdavScopeSourceFiles => '书籍与漫画源文件';

  @override
  String get webdavScopeSourceFilesDesc => '仅上传非敏感本地文件';

  @override
  String get webdavPresetsTitle => '常用服务器预设';

  @override
  String get webdavBackupsTitle => '云端快照';

  @override
  String get webdavNoBackups => '暂无云端快照';

  @override
  String get webdavRestoreBtn => '恢复';

  @override
  String webdavConfigTitle(String preset) {
    return '配置 $preset';
  }

  @override
  String get webdavServerUrlLabel => '服务器地址';

  @override
  String get webdavUserLabel => '账号';

  @override
  String get webdavPassLabel => '应用密码';

  @override
  String get webdavRootLabel => '同步目录';

  @override
  String get webdavSaveAndTest => '保存并测试';

  @override
  String get webdavConflictTitle => '进度冲突';

  @override
  String webdavConflictSubtitle(String title) {
    return '《$title》两端均有新进度：';
  }

  @override
  String webdavRemoteLabel(String device) {
    return '云端 ($device)';
  }

  @override
  String webdavLocalLabel(String device) {
    return '本机 ($device)';
  }

  @override
  String get webdavKeepLocal => '保留本机';

  @override
  String get webdavAdoptRemote => '采用云端';

  @override
  String get webdavSyncDone => '同步完成';

  @override
  String webdavSnapSummary(String preset, int count) {
    return '$preset · 连接正常 ($count 份快照)';
  }

  @override
  String get webdavTestPassed => '连接成功';

  @override
  String webdavTestFailed(String error) {
    return '连接失败：$error';
  }

  @override
  String get errFileNotFound => '未找到文件';

  @override
  String get errFileEmpty => '文件为空 (0 字节)';

  @override
  String get errStreamOpen => '无法读取文件流，请检查存储权限';

  @override
  String get errUnsupportedType => '不支持的文件格式';

  @override
  String get errTtsUnavailable => '系统 TTS 引擎不可用，请检查语音包';

  @override
  String get errTtsTimeout => '语音引擎初始化超时';

  @override
  String get errTtsSpeakFailed => '语音合成播放失败';

  @override
  String get errEdge403 => 'Edge 直连校验已失效 (403)，请切换自部署网关或使用系统 TTS';

  @override
  String get errNetworkTimeout => '网络请求超时';

  @override
  String get errHttp401 => '接口鉴权失败 (401)，请检查 API Key';

  @override
  String get errHttp403 => '访问被拒绝 (403)';

  @override
  String get errHttpStatus => '服务端返回错误状态';

  @override
  String get errInvalidAudio => '服务返回的不是有效音频';

  @override
  String get errInvalidJson => 'JSON 格式无效';

  @override
  String get errUnknown => '操作失败';
}
