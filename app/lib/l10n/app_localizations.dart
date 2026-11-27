import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'墨匣 InkBox'**
  String get appName;

  /// No description provided for @navBooks.
  ///
  /// In zh, this message translates to:
  /// **'书架'**
  String get navBooks;

  /// No description provided for @navManga.
  ///
  /// In zh, this message translates to:
  /// **'漫画'**
  String get navManga;

  /// No description provided for @navImport.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get navImport;

  /// No description provided for @navMe.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get navMe;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @create.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get create;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @confirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get confirmDelete;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @rename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get rename;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @reset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get reset;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @restore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get restore;

  /// No description provided for @open.
  ///
  /// In zh, this message translates to:
  /// **'打开'**
  String get open;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clear;

  /// No description provided for @details.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get details;

  /// No description provided for @none.
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get none;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// No description provided for @shelfGroupAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get shelfGroupAll;

  /// No description provided for @shelfGroupReading.
  ///
  /// In zh, this message translates to:
  /// **'在读'**
  String get shelfGroupReading;

  /// No description provided for @shelfGroupFinished.
  ///
  /// In zh, this message translates to:
  /// **'已读完'**
  String get shelfGroupFinished;

  /// No description provided for @defaultBookshelf.
  ///
  /// In zh, this message translates to:
  /// **'默认书架'**
  String get defaultBookshelf;

  /// No description provided for @defaultMangaShelf.
  ///
  /// In zh, this message translates to:
  /// **'默认漫画架'**
  String get defaultMangaShelf;

  /// No description provided for @unknownAuthor.
  ///
  /// In zh, this message translates to:
  /// **'未知作者'**
  String get unknownAuthor;

  /// No description provided for @readyToRead.
  ///
  /// In zh, this message translates to:
  /// **'准备阅读'**
  String get readyToRead;

  /// No description provided for @shelvesCountBadge.
  ///
  /// In zh, this message translates to:
  /// **'{count}架'**
  String shelvesCountBadge(int count);

  /// No description provided for @selectedCountBooks.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 本'**
  String selectedCountBooks(int count);

  /// No description provided for @selectedCountManga.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 部'**
  String selectedCountManga(int count);

  /// No description provided for @sortBy.
  ///
  /// In zh, this message translates to:
  /// **'排序方式'**
  String get sortBy;

  /// No description provided for @sortLastRead.
  ///
  /// In zh, this message translates to:
  /// **'按最近阅读'**
  String get sortLastRead;

  /// No description provided for @sortAddedAt.
  ///
  /// In zh, this message translates to:
  /// **'按添加时间'**
  String get sortAddedAt;

  /// No description provided for @sortTitle.
  ///
  /// In zh, this message translates to:
  /// **'按书名'**
  String get sortTitle;

  /// No description provided for @sortProgress.
  ///
  /// In zh, this message translates to:
  /// **'按阅读进度'**
  String get sortProgress;

  /// No description provided for @gridView.
  ///
  /// In zh, this message translates to:
  /// **'网格视图'**
  String get gridView;

  /// No description provided for @listView.
  ///
  /// In zh, this message translates to:
  /// **'列表视图'**
  String get listView;

  /// No description provided for @searchBooks.
  ///
  /// In zh, this message translates to:
  /// **'搜索书籍'**
  String get searchBooks;

  /// No description provided for @searchBooksHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索书名或作者...'**
  String get searchBooksHint;

  /// No description provided for @searchManga.
  ///
  /// In zh, this message translates to:
  /// **'搜索漫画'**
  String get searchManga;

  /// No description provided for @searchMangaHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索漫画名或作者...'**
  String get searchMangaHint;

  /// No description provided for @continueReading.
  ///
  /// In zh, this message translates to:
  /// **'继续阅读'**
  String get continueReading;

  /// No description provided for @emptyLibraryBooks.
  ///
  /// In zh, this message translates to:
  /// **'书架还是空的，导入你的第一本书吧'**
  String get emptyLibraryBooks;

  /// No description provided for @emptyShelfBooks.
  ///
  /// In zh, this message translates to:
  /// **'「{shelfName}」暂无书籍'**
  String emptyShelfBooks(String shelfName);

  /// No description provided for @emptyGroupBooks.
  ///
  /// In zh, this message translates to:
  /// **'当前分组暂无书籍'**
  String get emptyGroupBooks;

  /// No description provided for @importLocalBooks.
  ///
  /// In zh, this message translates to:
  /// **'导入本地书籍'**
  String get importLocalBooks;

  /// No description provided for @switchOtherShelf.
  ///
  /// In zh, this message translates to:
  /// **'切换书架'**
  String get switchOtherShelf;

  /// No description provided for @emptyLibraryManga.
  ///
  /// In zh, this message translates to:
  /// **'漫画架还是空的，前往导入添加吧'**
  String get emptyLibraryManga;

  /// No description provided for @emptyShelfManga.
  ///
  /// In zh, this message translates to:
  /// **'「{shelfName}」暂无漫画'**
  String emptyShelfManga(String shelfName);

  /// No description provided for @emptyGroupManga.
  ///
  /// In zh, this message translates to:
  /// **'当前分组暂无漫画'**
  String get emptyGroupManga;

  /// No description provided for @importLocalManga.
  ///
  /// In zh, this message translates to:
  /// **'导入本地漫画'**
  String get importLocalManga;

  /// No description provided for @bookshelfLoadError.
  ///
  /// In zh, this message translates to:
  /// **'书架加载失败：{error}'**
  String bookshelfLoadError(String error);

  /// No description provided for @mangaShelfLoadError.
  ///
  /// In zh, this message translates to:
  /// **'漫画架加载失败：{error}'**
  String mangaShelfLoadError(String error);

  /// No description provided for @moveShelf.
  ///
  /// In zh, this message translates to:
  /// **'移架'**
  String get moveShelf;

  /// No description provided for @markFinished.
  ///
  /// In zh, this message translates to:
  /// **'标为读完'**
  String get markFinished;

  /// No description provided for @markReading.
  ///
  /// In zh, this message translates to:
  /// **'标为在读'**
  String get markReading;

  /// No description provided for @removeBooks.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get removeBooks;

  /// No description provided for @markAllRead.
  ///
  /// In zh, this message translates to:
  /// **'标为已读'**
  String get markAllRead;

  /// No description provided for @resetUnread.
  ///
  /// In zh, this message translates to:
  /// **'标为未读'**
  String get resetUnread;

  /// No description provided for @removeManga.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get removeManga;

  /// No description provided for @moveBookSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已将 {count} 本书移至「{target}」'**
  String moveBookSuccess(int count, String target);

  /// No description provided for @moveMangaSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已将 {count} 部漫画移至「{target}」'**
  String moveMangaSuccess(int count, String target);

  /// No description provided for @removeBooksTitle.
  ///
  /// In zh, this message translates to:
  /// **'移除选中的 {count} 本书籍'**
  String removeBooksTitle(int count);

  /// No description provided for @removeMangaTitle.
  ///
  /// In zh, this message translates to:
  /// **'移除选中的 {count} 部漫画'**
  String removeMangaTitle(int count);

  /// No description provided for @removeBookTitleSingle.
  ///
  /// In zh, this message translates to:
  /// **'移除《{title}》'**
  String removeBookTitleSingle(String title);

  /// No description provided for @removeArchiveOption.
  ///
  /// In zh, this message translates to:
  /// **'移出书架（保留导入历史）'**
  String get removeArchiveOption;

  /// No description provided for @removeArchiveMangaOption.
  ///
  /// In zh, this message translates to:
  /// **'移出漫画架（保留导入历史）'**
  String get removeArchiveMangaOption;

  /// No description provided for @removePermanentOption.
  ///
  /// In zh, this message translates to:
  /// **'彻底删除'**
  String get removePermanentOption;

  /// No description provided for @archivedBooksToast.
  ///
  /// In zh, this message translates to:
  /// **'已移出 {count} 本书'**
  String archivedBooksToast(int count);

  /// No description provided for @deletedBooksToast.
  ///
  /// In zh, this message translates to:
  /// **'已彻底删除 {count} 本书'**
  String deletedBooksToast(int count);

  /// No description provided for @bookDetailsTitle.
  ///
  /// In zh, this message translates to:
  /// **'书籍详情'**
  String get bookDetailsTitle;

  /// No description provided for @mangaDetailsTitle.
  ///
  /// In zh, this message translates to:
  /// **'漫画详情'**
  String get mangaDetailsTitle;

  /// No description provided for @notFoundBook.
  ///
  /// In zh, this message translates to:
  /// **'未找到该书籍'**
  String get notFoundBook;

  /// No description provided for @notFoundManga.
  ///
  /// In zh, this message translates to:
  /// **'未找到该漫画'**
  String get notFoundManga;

  /// No description provided for @movedShelfSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已修改所属书架'**
  String get movedShelfSuccess;

  /// No description provided for @pinToShelf.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get pinToShelf;

  /// No description provided for @unpinFromShelf.
  ///
  /// In zh, this message translates to:
  /// **'取消置顶'**
  String get unpinFromShelf;

  /// No description provided for @editMetadata.
  ///
  /// In zh, this message translates to:
  /// **'编辑信息'**
  String get editMetadata;

  /// No description provided for @bookTitleLabel.
  ///
  /// In zh, this message translates to:
  /// **'书名'**
  String get bookTitleLabel;

  /// No description provided for @authorLabel.
  ///
  /// In zh, this message translates to:
  /// **'作者'**
  String get authorLabel;

  /// No description provided for @shelfBelongsTo.
  ///
  /// In zh, this message translates to:
  /// **'所属书架'**
  String get shelfBelongsTo;

  /// No description provided for @orCreateShelf.
  ///
  /// In zh, this message translates to:
  /// **'或新建书架'**
  String get orCreateShelf;

  /// No description provided for @readingStatusLabel.
  ///
  /// In zh, this message translates to:
  /// **'阅读状态'**
  String get readingStatusLabel;

  /// No description provided for @readingMinutesShort.
  ///
  /// In zh, this message translates to:
  /// **'{mins} 分钟'**
  String readingMinutesShort(int mins);

  /// No description provided for @readProgressShort.
  ///
  /// In zh, this message translates to:
  /// **'已读 {pct}%'**
  String readProgressShort(String pct);

  /// No description provided for @tocChaptersCount.
  ///
  /// In zh, this message translates to:
  /// **'章节目录 ({count})'**
  String tocChaptersCount(int count);

  /// No description provided for @ascendingOrder.
  ///
  /// In zh, this message translates to:
  /// **'正序'**
  String get ascendingOrder;

  /// No description provided for @descendingOrder.
  ///
  /// In zh, this message translates to:
  /// **'倒序'**
  String get descendingOrder;

  /// No description provided for @fullToc.
  ///
  /// In zh, this message translates to:
  /// **'全部目录'**
  String get fullToc;

  /// No description provided for @expandFullToc.
  ///
  /// In zh, this message translates to:
  /// **'查看全部 {count} 章'**
  String expandFullToc(int count);

  /// No description provided for @noTocFound.
  ///
  /// In zh, this message translates to:
  /// **'未解析到目录章节'**
  String get noTocFound;

  /// No description provided for @currentReadingTag.
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get currentReadingTag;

  /// No description provided for @txtRuleEncodingMeta.
  ///
  /// In zh, this message translates to:
  /// **'规则：{rule} · 编码：{encoding}'**
  String txtRuleEncodingMeta(String rule, String encoding);

  /// No description provided for @smartAutoDetect.
  ///
  /// In zh, this message translates to:
  /// **'自动识别'**
  String get smartAutoDetect;

  /// No description provided for @switchTocRule.
  ///
  /// In zh, this message translates to:
  /// **'目录规则'**
  String get switchTocRule;

  /// No description provided for @switchEncoding.
  ///
  /// In zh, this message translates to:
  /// **'文本编码'**
  String get switchEncoding;

  /// No description provided for @manageRuleLibrary.
  ///
  /// In zh, this message translates to:
  /// **'规则库'**
  String get manageRuleLibrary;

  /// No description provided for @selectTocRuleTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择目录识别规则'**
  String get selectTocRuleTitle;

  /// No description provided for @autoDetectRecommended.
  ///
  /// In zh, this message translates to:
  /// **'智能自动识别'**
  String get autoDetectRecommended;

  /// No description provided for @ruleUnmatchedTag.
  ///
  /// In zh, this message translates to:
  /// **'{name}（未匹配）'**
  String ruleUnmatchedTag(String name);

  /// No description provided for @tocReloadedCount.
  ///
  /// In zh, this message translates to:
  /// **'已更新目录（{count} 章）'**
  String tocReloadedCount(int count);

  /// No description provided for @tocNoMatchFallback.
  ///
  /// In zh, this message translates to:
  /// **'未匹配到章节，已按默认分段（{count} 节）'**
  String tocNoMatchFallback(int count);

  /// No description provided for @selectEncodingTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择文本编码'**
  String get selectEncodingTitle;

  /// No description provided for @encodingAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动检测'**
  String get encodingAuto;

  /// No description provided for @encodingGb18030.
  ///
  /// In zh, this message translates to:
  /// **'GB18030 / GBK'**
  String get encodingGb18030;

  /// No description provided for @encodingBig5.
  ///
  /// In zh, this message translates to:
  /// **'Big5'**
  String get encodingBig5;

  /// No description provided for @encodingSwitched.
  ///
  /// In zh, this message translates to:
  /// **'已切换编码：{encoding}'**
  String encodingSwitched(String encoding);

  /// No description provided for @annotationsTitle.
  ///
  /// In zh, this message translates to:
  /// **'书签与划线'**
  String get annotationsTitle;

  /// No description provided for @noAnnotationsHint.
  ///
  /// In zh, this message translates to:
  /// **'暂无书签或划线笔记'**
  String get noAnnotationsHint;

  /// No description provided for @bookmarkTag.
  ///
  /// In zh, this message translates to:
  /// **'书签'**
  String get bookmarkTag;

  /// No description provided for @highlightNoteTag.
  ///
  /// In zh, this message translates to:
  /// **'想法'**
  String get highlightNoteTag;

  /// No description provided for @highlightTag.
  ///
  /// In zh, this message translates to:
  /// **'划线'**
  String get highlightTag;

  /// No description provided for @chapterLabelShort.
  ///
  /// In zh, this message translates to:
  /// **'第 {index} 章'**
  String chapterLabelShort(int index);

  /// No description provided for @localFileInfo.
  ///
  /// In zh, this message translates to:
  /// **'本地文件'**
  String get localFileInfo;

  /// No description provided for @pathLabel.
  ///
  /// In zh, this message translates to:
  /// **'路径：{path}'**
  String pathLabel(String path);

  /// No description provided for @fingerprintLabel.
  ///
  /// In zh, this message translates to:
  /// **'指纹：{hash}'**
  String fingerprintLabel(String hash);

  /// No description provided for @searchChapterHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索章节...'**
  String get searchChapterHint;

  /// No description provided for @noMatchingChapters.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配章节'**
  String get noMatchingChapters;

  /// No description provided for @mangaDefaultModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'阅读方向'**
  String get mangaDefaultModeLabel;

  /// No description provided for @smartCropLabel.
  ///
  /// In zh, this message translates to:
  /// **'智能白边裁切'**
  String get smartCropLabel;

  /// No description provided for @splitWidePagesLabel.
  ///
  /// In zh, this message translates to:
  /// **'跨页自动切分'**
  String get splitWidePagesLabel;

  /// No description provided for @chaptersVolumeList.
  ///
  /// In zh, this message translates to:
  /// **'章节列表 ({count})'**
  String chaptersVolumeList(int count);

  /// No description provided for @unreadOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅未读'**
  String get unreadOnly;

  /// No description provided for @unreadOnlyActive.
  ///
  /// In zh, this message translates to:
  /// **'仅未读 ✓'**
  String get unreadOnlyActive;

  /// No description provided for @noChaptersMatchHint.
  ///
  /// In zh, this message translates to:
  /// **'当前筛选下无章节'**
  String get noChaptersMatchHint;

  /// No description provided for @startReading.
  ///
  /// In zh, this message translates to:
  /// **'开始阅读'**
  String get startReading;

  /// No description provided for @readLabel.
  ///
  /// In zh, this message translates to:
  /// **'已读'**
  String get readLabel;

  /// No description provided for @pageOfTotalUnknown.
  ///
  /// In zh, this message translates to:
  /// **'第 {current}/{total} 页'**
  String pageOfTotalUnknown(int current, String total);

  /// No description provided for @markAllReadMenu.
  ///
  /// In zh, this message translates to:
  /// **'全部标记已读'**
  String get markAllReadMenu;

  /// No description provided for @resetUnreadMenu.
  ///
  /// In zh, this message translates to:
  /// **'全部重置未读'**
  String get resetUnreadMenu;

  /// No description provided for @moveMangaShelfMenu.
  ///
  /// In zh, this message translates to:
  /// **'修改所属漫画架'**
  String get moveMangaShelfMenu;

  /// No description provided for @shelfNameExists.
  ///
  /// In zh, this message translates to:
  /// **'名称已存在'**
  String get shelfNameExists;

  /// No description provided for @shelfRenameConflict.
  ///
  /// In zh, this message translates to:
  /// **'名称未变更或已存在'**
  String get shelfRenameConflict;

  /// No description provided for @deleteShelfTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除「{name}」'**
  String deleteShelfTitle(String name);

  /// No description provided for @deleteShelfConfirm.
  ///
  /// In zh, this message translates to:
  /// **'作品将移入「{fallback}」，本地文件保留。'**
  String deleteShelfConfirm(String fallback);

  /// No description provided for @createShelfTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建书架'**
  String get createShelfTitle;

  /// No description provided for @createMangaShelfTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建漫画架'**
  String get createMangaShelfTitle;

  /// No description provided for @renameShelfTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名书架'**
  String get renameShelfTitle;

  /// No description provided for @renameMangaShelfTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名漫画架'**
  String get renameMangaShelfTitle;

  /// No description provided for @shelfNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get shelfNameLabel;

  /// No description provided for @newNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'新名称'**
  String get newNameLabel;

  /// No description provided for @switchBookshelfTitle.
  ///
  /// In zh, this message translates to:
  /// **'切换书架'**
  String get switchBookshelfTitle;

  /// No description provided for @switchMangaShelfTitle.
  ///
  /// In zh, this message translates to:
  /// **'切换漫画架'**
  String get switchMangaShelfTitle;

  /// No description provided for @multiShelfManagerTitle.
  ///
  /// In zh, this message translates to:
  /// **'书架与漫画架'**
  String get multiShelfManagerTitle;

  /// No description provided for @bookshelfTab.
  ///
  /// In zh, this message translates to:
  /// **'书架'**
  String get bookshelfTab;

  /// No description provided for @mangaShelfTab.
  ///
  /// In zh, this message translates to:
  /// **'漫画架'**
  String get mangaShelfTab;

  /// No description provided for @defaultShelfBadge.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get defaultShelfBadge;

  /// No description provided for @shelfItemCountBook.
  ///
  /// In zh, this message translates to:
  /// **'{count} 本'**
  String shelfItemCountBook(int count);

  /// No description provided for @shelfItemCountManga.
  ///
  /// In zh, this message translates to:
  /// **'{count} 部'**
  String shelfItemCountManga(int count);

  /// No description provided for @inUseLabel.
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get inUseLabel;

  /// No description provided for @moveToShelfTitleBook.
  ///
  /// In zh, this message translates to:
  /// **'移至书架'**
  String get moveToShelfTitleBook;

  /// No description provided for @moveToShelfTitleManga.
  ///
  /// In zh, this message translates to:
  /// **'移至漫画架'**
  String get moveToShelfTitleManga;

  /// No description provided for @orCreateAndMoveBook.
  ///
  /// In zh, this message translates to:
  /// **'或新建书架并移入'**
  String get orCreateAndMoveBook;

  /// No description provided for @orCreateAndMoveManga.
  ///
  /// In zh, this message translates to:
  /// **'或新建漫画架并移入'**
  String get orCreateAndMoveManga;

  /// No description provided for @shelfExampleBook.
  ///
  /// In zh, this message translates to:
  /// **'例如：历史、随笔'**
  String get shelfExampleBook;

  /// No description provided for @shelfExampleManga.
  ///
  /// In zh, this message translates to:
  /// **'例如：连载、完结'**
  String get shelfExampleManga;

  /// No description provided for @mineTitle.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get mineTitle;

  /// No description provided for @appearanceSettings.
  ///
  /// In zh, this message translates to:
  /// **'外观与主题'**
  String get appearanceSettings;

  /// No description provided for @themePresets.
  ///
  /// In zh, this message translates to:
  /// **'主题预设'**
  String get themePresets;

  /// No description provided for @uiStyleLabel.
  ///
  /// In zh, this message translates to:
  /// **'界面风格'**
  String get uiStyleLabel;

  /// No description provided for @uiStyleFloating.
  ///
  /// In zh, this message translates to:
  /// **'悬浮卡片'**
  String get uiStyleFloating;

  /// No description provided for @uiStyleClassic.
  ///
  /// In zh, this message translates to:
  /// **'经典贴边'**
  String get uiStyleClassic;

  /// No description provided for @colorThemeLabel.
  ///
  /// In zh, this message translates to:
  /// **'色彩模式'**
  String get colorThemeLabel;

  /// No description provided for @themeCrispLight.
  ///
  /// In zh, this message translates to:
  /// **'澄白日间'**
  String get themeCrispLight;

  /// No description provided for @themeDarkTheater.
  ///
  /// In zh, this message translates to:
  /// **'暗夜剧场'**
  String get themeDarkTheater;

  /// No description provided for @themeOledBlack.
  ///
  /// In zh, this message translates to:
  /// **'OLED 纯黑'**
  String get themeOledBlack;

  /// No description provided for @themeFollowSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeFollowSystem;

  /// No description provided for @dynamicColorTitle.
  ///
  /// In zh, this message translates to:
  /// **'Material You 取色'**
  String get dynamicColorTitle;

  /// No description provided for @dynamicColorSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统壁纸强调色'**
  String get dynamicColorSubtitle;

  /// No description provided for @appLanguageTitle.
  ///
  /// In zh, this message translates to:
  /// **'语言 / Language'**
  String get appLanguageTitle;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @languageZh.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageZh;

  /// No description provided for @languageEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @languageJa.
  ///
  /// In zh, this message translates to:
  /// **'日本語'**
  String get languageJa;

  /// No description provided for @statBooks.
  ///
  /// In zh, this message translates to:
  /// **'藏书'**
  String get statBooks;

  /// No description provided for @statReading.
  ///
  /// In zh, this message translates to:
  /// **'在读'**
  String get statReading;

  /// No description provided for @statFinished.
  ///
  /// In zh, this message translates to:
  /// **'读完'**
  String get statFinished;

  /// No description provided for @statMinutes.
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get statMinutes;

  /// No description provided for @sectionAppearanceLanguage.
  ///
  /// In zh, this message translates to:
  /// **'外观与语言'**
  String get sectionAppearanceLanguage;

  /// No description provided for @sectionReadingSync.
  ///
  /// In zh, this message translates to:
  /// **'阅读与同步'**
  String get sectionReadingSync;

  /// No description provided for @multiShelfManagerMenu.
  ///
  /// In zh, this message translates to:
  /// **'多书架管理'**
  String get multiShelfManagerMenu;

  /// No description provided for @multiShelfSummary.
  ///
  /// In zh, this message translates to:
  /// **'书架 {books} · 漫画架 {manga}'**
  String multiShelfSummary(int books, int manga);

  /// No description provided for @ttsMenuTitle.
  ///
  /// In zh, this message translates to:
  /// **'TTS 语音朗读'**
  String get ttsMenuTitle;

  /// No description provided for @ttsMenuSummaryLocal.
  ///
  /// In zh, this message translates to:
  /// **'系统引擎 · {rate}x'**
  String ttsMenuSummaryLocal(String rate);

  /// No description provided for @ttsMenuSummaryOnline.
  ///
  /// In zh, this message translates to:
  /// **'在线语音 · {name} · {rate}x'**
  String ttsMenuSummaryOnline(String name, String rate);

  /// No description provided for @tocRulesMenuTitle.
  ///
  /// In zh, this message translates to:
  /// **'TXT 目录规则'**
  String get tocRulesMenuTitle;

  /// No description provided for @tocRulesMenuSummary.
  ///
  /// In zh, this message translates to:
  /// **'{enabled} / {total} 启用'**
  String tocRulesMenuSummary(int enabled, int total);

  /// No description provided for @webdavMenuTitle.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 同步'**
  String get webdavMenuTitle;

  /// No description provided for @webdavUnconfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get webdavUnconfigured;

  /// No description provided for @importHubTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入中心'**
  String get importHubTitle;

  /// No description provided for @rescanFolders.
  ///
  /// In zh, this message translates to:
  /// **'重新扫描'**
  String get rescanFolders;

  /// No description provided for @supportedFormats.
  ///
  /// In zh, this message translates to:
  /// **'支持格式'**
  String get supportedFormats;

  /// No description provided for @supportedFormatsBooks.
  ///
  /// In zh, this message translates to:
  /// **'书籍：{formats}'**
  String supportedFormatsBooks(String formats);

  /// No description provided for @supportedFormatsManga.
  ///
  /// In zh, this message translates to:
  /// **'漫画：{formats}'**
  String supportedFormatsManga(String formats);

  /// No description provided for @supportedFormatsImageFolder.
  ///
  /// In zh, this message translates to:
  /// **'图片文件夹'**
  String get supportedFormatsImageFolder;

  /// No description provided for @pickLocalFiles.
  ///
  /// In zh, this message translates to:
  /// **'选择本地文件'**
  String get pickLocalFiles;

  /// No description provided for @addAndScanFolder.
  ///
  /// In zh, this message translates to:
  /// **'扫描本地目录'**
  String get addAndScanFolder;

  /// No description provided for @importOptions.
  ///
  /// In zh, this message translates to:
  /// **'导入选项'**
  String get importOptions;

  /// No description provided for @smartAutoClassify.
  ///
  /// In zh, this message translates to:
  /// **'智能分拣书漫'**
  String get smartAutoClassify;

  /// No description provided for @overwriteDuplicates.
  ///
  /// In zh, this message translates to:
  /// **'覆盖已存在文件'**
  String get overwriteDuplicates;

  /// No description provided for @watchedFoldersTitle.
  ///
  /// In zh, this message translates to:
  /// **'监听目录 ({count})'**
  String watchedFoldersTitle(int count);

  /// No description provided for @formatAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get formatAll;

  /// No description provided for @formatComicArchive.
  ///
  /// In zh, this message translates to:
  /// **'漫画'**
  String get formatComicArchive;

  /// No description provided for @importHistoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入历史 ({count})'**
  String importHistoryTitle(int count);

  /// No description provided for @historyAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get historyAll;

  /// No description provided for @historyArchived.
  ///
  /// In zh, this message translates to:
  /// **'已移出'**
  String get historyArchived;

  /// No description provided for @historyOnShelf.
  ///
  /// In zh, this message translates to:
  /// **'在架'**
  String get historyOnShelf;

  /// No description provided for @noImportHistory.
  ///
  /// In zh, this message translates to:
  /// **'暂无导入历史，支持 EPUB / TXT / PDF / MOBI / AZW3 / FB2 / MD / CBZ / CB7'**
  String get noImportHistory;

  /// No description provided for @noMatchingHistory.
  ///
  /// In zh, this message translates to:
  /// **'当前筛选下无记录'**
  String get noMatchingHistory;

  /// No description provided for @fileMissingBadge.
  ///
  /// In zh, this message translates to:
  /// **'缺失'**
  String get fileMissingBadge;

  /// No description provided for @archivedBadge.
  ///
  /// In zh, this message translates to:
  /// **'已移出'**
  String get archivedBadge;

  /// No description provided for @onShelfBadge.
  ///
  /// In zh, this message translates to:
  /// **'在架'**
  String get onShelfBadge;

  /// No description provided for @restoreToShelf.
  ///
  /// In zh, this message translates to:
  /// **'入架'**
  String get restoreToShelf;

  /// No description provided for @readNow.
  ///
  /// In zh, this message translates to:
  /// **'阅读'**
  String get readNow;

  /// No description provided for @permanentDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'彻底删除'**
  String get permanentDeleteTitle;

  /// No description provided for @permanentDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定彻底删除《{title}》？将清除记录与本地缓存，无法恢复。'**
  String permanentDeleteConfirm(String title);

  /// No description provided for @deletedForeverToast.
  ///
  /// In zh, this message translates to:
  /// **'已彻底删除《{title}》'**
  String deletedForeverToast(String title);

  /// No description provided for @fileMissingReimportToast.
  ///
  /// In zh, this message translates to:
  /// **'《{title}》文件不存在，请重新导入'**
  String fileMissingReimportToast(String title);

  /// No description provided for @restoredToShelfToast.
  ///
  /// In zh, this message translates to:
  /// **'已恢复《{title}》到书架'**
  String restoredToShelfToast(String title);

  /// No description provided for @folderScanDoneToast.
  ///
  /// In zh, this message translates to:
  /// **'扫描完成：发现 {count} 个文件'**
  String folderScanDoneToast(int count);

  /// No description provided for @importResultSummary.
  ///
  /// In zh, this message translates to:
  /// **'导入完成：书籍 +{books}，漫画 +{manga}'**
  String importResultSummary(int books, int manga);

  /// No description provided for @importResultSkipped.
  ///
  /// In zh, this message translates to:
  /// **'，重复 {count}'**
  String importResultSkipped(int count);

  /// No description provided for @importResultFailed.
  ///
  /// In zh, this message translates to:
  /// **'，失败 {count}'**
  String importResultFailed(int count);

  /// No description provided for @viewBookshelf.
  ///
  /// In zh, this message translates to:
  /// **'查看书架'**
  String get viewBookshelf;

  /// No description provided for @viewMangaShelf.
  ///
  /// In zh, this message translates to:
  /// **'查看漫画'**
  String get viewMangaShelf;

  /// No description provided for @lastImportResultTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入结果'**
  String get lastImportResultTitle;

  /// No description provided for @collapseLabel.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get collapseLabel;

  /// No description provided for @importedStatus.
  ///
  /// In zh, this message translates to:
  /// **'已入架：《{title}》'**
  String importedStatus(String title);

  /// No description provided for @repairedStatus.
  ///
  /// In zh, this message translates to:
  /// **'已更新：《{title}》'**
  String repairedStatus(String title);

  /// No description provided for @duplicateStatus.
  ///
  /// In zh, this message translates to:
  /// **'已在架：《{title}》'**
  String duplicateStatus(String title);

  /// No description provided for @overwriteReimport.
  ///
  /// In zh, this message translates to:
  /// **'覆盖'**
  String get overwriteReimport;

  /// No description provided for @overwriteSuccessToast.
  ///
  /// In zh, this message translates to:
  /// **'已覆盖更新《{title}》'**
  String overwriteSuccessToast(String title);

  /// No description provided for @overwriteFailedToast.
  ///
  /// In zh, this message translates to:
  /// **'覆盖失败：{error}'**
  String overwriteFailedToast(String error);

  /// No description provided for @selectedCandidatesCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 项'**
  String selectedCandidatesCount(int count);

  /// No description provided for @importToShelfCount.
  ///
  /// In zh, this message translates to:
  /// **'导入 ({count})'**
  String importToShelfCount(int count);

  /// No description provided for @switchToBook.
  ///
  /// In zh, this message translates to:
  /// **'改书'**
  String get switchToBook;

  /// No description provided for @switchToComic.
  ///
  /// In zh, this message translates to:
  /// **'改漫'**
  String get switchToComic;

  /// No description provided for @classifiedAsBook.
  ///
  /// In zh, this message translates to:
  /// **'书籍'**
  String get classifiedAsBook;

  /// No description provided for @classifiedAsComic.
  ///
  /// In zh, this message translates to:
  /// **'漫画'**
  String get classifiedAsComic;

  /// No description provided for @historyBookSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'{author} · {pct}%'**
  String historyBookSubtitle(String author, int pct);

  /// No description provided for @historyMangaSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'{author} · {chapters} 话'**
  String historyMangaSubtitle(String author, int chapters);

  /// No description provided for @emptyChapterPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'（本章节暂无正文内容）'**
  String get emptyChapterPlaceholder;

  /// No description provided for @firstPageToast.
  ///
  /// In zh, this message translates to:
  /// **'已是第一页'**
  String get firstPageToast;

  /// No description provided for @lastPageToast.
  ///
  /// In zh, this message translates to:
  /// **'已是最后一页'**
  String get lastPageToast;

  /// No description provided for @chapterFinishedToast.
  ///
  /// In zh, this message translates to:
  /// **'本话已读完'**
  String get chapterFinishedToast;

  /// No description provided for @bookmarkAddedToast.
  ///
  /// In zh, this message translates to:
  /// **'已添加书签'**
  String get bookmarkAddedToast;

  /// No description provided for @bookmarkRemovedToast.
  ///
  /// In zh, this message translates to:
  /// **'已取消书签'**
  String get bookmarkRemovedToast;

  /// No description provided for @addBookmarkTooltip.
  ///
  /// In zh, this message translates to:
  /// **'添加书签'**
  String get addBookmarkTooltip;

  /// No description provided for @removeBookmarkTooltip.
  ///
  /// In zh, this message translates to:
  /// **'取消书签'**
  String get removeBookmarkTooltip;

  /// No description provided for @highlightNotesTooltip.
  ///
  /// In zh, this message translates to:
  /// **'划线笔记'**
  String get highlightNotesTooltip;

  /// No description provided for @ttsListenTooltip.
  ///
  /// In zh, this message translates to:
  /// **'听书'**
  String get ttsListenTooltip;

  /// No description provided for @originalPdf.
  ///
  /// In zh, this message translates to:
  /// **'原版 PDF'**
  String get originalPdf;

  /// No description provided for @textReflow.
  ///
  /// In zh, this message translates to:
  /// **'文本重排'**
  String get textReflow;

  /// No description provided for @prevChapter.
  ///
  /// In zh, this message translates to:
  /// **'上一章'**
  String get prevChapter;

  /// No description provided for @nextChapter.
  ///
  /// In zh, this message translates to:
  /// **'下一章'**
  String get nextChapter;

  /// No description provided for @readerTabToc.
  ///
  /// In zh, this message translates to:
  /// **'目录'**
  String get readerTabToc;

  /// No description provided for @readerTabDark.
  ///
  /// In zh, this message translates to:
  /// **'夜间'**
  String get readerTabDark;

  /// No description provided for @readerTabLight.
  ///
  /// In zh, this message translates to:
  /// **'日间'**
  String get readerTabLight;

  /// No description provided for @readerTabStyle.
  ///
  /// In zh, this message translates to:
  /// **'排版'**
  String get readerTabStyle;

  /// No description provided for @readerTabTurn.
  ///
  /// In zh, this message translates to:
  /// **'翻页'**
  String get readerTabTurn;

  /// No description provided for @readerTabMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get readerTabMore;

  /// No description provided for @paperWhite.
  ///
  /// In zh, this message translates to:
  /// **'素白'**
  String get paperWhite;

  /// No description provided for @paperIvory.
  ///
  /// In zh, this message translates to:
  /// **'轻象牙'**
  String get paperIvory;

  /// No description provided for @paperSage.
  ///
  /// In zh, this message translates to:
  /// **'青瓷'**
  String get paperSage;

  /// No description provided for @paperDark.
  ///
  /// In zh, this message translates to:
  /// **'墨灰夜'**
  String get paperDark;

  /// No description provided for @paperOled.
  ///
  /// In zh, this message translates to:
  /// **'纯黑夜'**
  String get paperOled;

  /// No description provided for @turnSimulation.
  ///
  /// In zh, this message translates to:
  /// **'仿真'**
  String get turnSimulation;

  /// No description provided for @turnCover.
  ///
  /// In zh, this message translates to:
  /// **'覆盖'**
  String get turnCover;

  /// No description provided for @turnSlide.
  ///
  /// In zh, this message translates to:
  /// **'滑动'**
  String get turnSlide;

  /// No description provided for @turnScroll.
  ///
  /// In zh, this message translates to:
  /// **'滚动'**
  String get turnScroll;

  /// No description provided for @layoutModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'版面'**
  String get layoutModeLabel;

  /// No description provided for @layoutAuto.
  ///
  /// In zh, this message translates to:
  /// **'自适应'**
  String get layoutAuto;

  /// No description provided for @layoutSingle.
  ///
  /// In zh, this message translates to:
  /// **'单页'**
  String get layoutSingle;

  /// No description provided for @layoutDual.
  ///
  /// In zh, this message translates to:
  /// **'双页'**
  String get layoutDual;

  /// No description provided for @fontSizeLabel.
  ///
  /// In zh, this message translates to:
  /// **'字号'**
  String get fontSizeLabel;

  /// No description provided for @lineHeightLabel.
  ///
  /// In zh, this message translates to:
  /// **'行距'**
  String get lineHeightLabel;

  /// No description provided for @paragraphSpacingLabel.
  ///
  /// In zh, this message translates to:
  /// **'段距'**
  String get paragraphSpacingLabel;

  /// No description provided for @firstLineIndentLabel.
  ///
  /// In zh, this message translates to:
  /// **'首行缩进'**
  String get firstLineIndentLabel;

  /// No description provided for @chineseOriginal.
  ///
  /// In zh, this message translates to:
  /// **'原字'**
  String get chineseOriginal;

  /// No description provided for @chineseTrad.
  ///
  /// In zh, this message translates to:
  /// **'繁體'**
  String get chineseTrad;

  /// No description provided for @chineseSimp.
  ///
  /// In zh, this message translates to:
  /// **'简体'**
  String get chineseSimp;

  /// No description provided for @tapZoneLabel.
  ///
  /// In zh, this message translates to:
  /// **'点击区'**
  String get tapZoneLabel;

  /// No description provided for @tapZoneStandard.
  ///
  /// In zh, this message translates to:
  /// **'常规左右'**
  String get tapZoneStandard;

  /// No description provided for @tapZoneLeftHand.
  ///
  /// In zh, this message translates to:
  /// **'左手单手'**
  String get tapZoneLeftHand;

  /// No description provided for @tapZoneRightHand.
  ///
  /// In zh, this message translates to:
  /// **'右手单手'**
  String get tapZoneRightHand;

  /// No description provided for @tapZoneCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get tapZoneCustom;

  /// No description provided for @autoScrollLabel.
  ///
  /// In zh, this message translates to:
  /// **'自动滚屏'**
  String get autoScrollLabel;

  /// No description provided for @startAutoScroll.
  ///
  /// In zh, this message translates to:
  /// **'开启'**
  String get startAutoScroll;

  /// No description provided for @stopAutoScroll.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get stopAutoScroll;

  /// No description provided for @autoScrollReachedEnd.
  ///
  /// In zh, this message translates to:
  /// **'已滚屏至末尾'**
  String get autoScrollReachedEnd;

  /// No description provided for @volumeKeyPaging.
  ///
  /// In zh, this message translates to:
  /// **'音量键翻页'**
  String get volumeKeyPaging;

  /// No description provided for @keepScreenOn.
  ///
  /// In zh, this message translates to:
  /// **'保持常亮'**
  String get keepScreenOn;

  /// No description provided for @edgeBrightnessGesture.
  ///
  /// In zh, this message translates to:
  /// **'边缘滑动调亮度'**
  String get edgeBrightnessGesture;

  /// No description provided for @brightnessIndicator.
  ///
  /// In zh, this message translates to:
  /// **'亮度 {pct}%'**
  String brightnessIndicator(int pct);

  /// No description provided for @ttsSettingsBtn.
  ///
  /// In zh, this message translates to:
  /// **'TTS 设置'**
  String get ttsSettingsBtn;

  /// No description provided for @purificationBtn.
  ///
  /// In zh, this message translates to:
  /// **'正文净化'**
  String get purificationBtn;

  /// No description provided for @exportNotesBtn.
  ///
  /// In zh, this message translates to:
  /// **'导出笔记'**
  String get exportNotesBtn;

  /// No description provided for @exportNotesSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已复制 {count} 条笔记到剪贴板'**
  String exportNotesSuccess(int count);

  /// No description provided for @purificationDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加正文净化规则'**
  String get purificationDialogTitle;

  /// No description provided for @purificationPatternLabel.
  ///
  /// In zh, this message translates to:
  /// **'过滤文本或正则'**
  String get purificationPatternLabel;

  /// No description provided for @purificationPatternHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：请收藏本站.*'**
  String get purificationPatternHint;

  /// No description provided for @purificationReplacementLabel.
  ///
  /// In zh, this message translates to:
  /// **'替换为（留空删除）'**
  String get purificationReplacementLabel;

  /// No description provided for @purificationReplacementHint.
  ///
  /// In zh, this message translates to:
  /// **'留空即删除'**
  String get purificationReplacementHint;

  /// No description provided for @addAndApply.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get addAndApply;

  /// No description provided for @highlightAction.
  ///
  /// In zh, this message translates to:
  /// **'划线'**
  String get highlightAction;

  /// No description provided for @writeNoteAction.
  ///
  /// In zh, this message translates to:
  /// **'写想法'**
  String get writeNoteAction;

  /// No description provided for @editNoteAction.
  ///
  /// In zh, this message translates to:
  /// **'改想法'**
  String get editNoteAction;

  /// No description provided for @deleteHighlightAction.
  ///
  /// In zh, this message translates to:
  /// **'删除划线'**
  String get deleteHighlightAction;

  /// No description provided for @highlightSavedToast.
  ///
  /// In zh, this message translates to:
  /// **'已添加划线'**
  String get highlightSavedToast;

  /// No description provided for @noteSavedToast.
  ///
  /// In zh, this message translates to:
  /// **'已保存想法'**
  String get noteSavedToast;

  /// No description provided for @highlightDeletedToast.
  ///
  /// In zh, this message translates to:
  /// **'已删除划线'**
  String get highlightDeletedToast;

  /// No description provided for @copiedToast.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get copiedToast;

  /// No description provided for @addNoteTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加想法'**
  String get addNoteTitle;

  /// No description provided for @editNoteTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑想法'**
  String get editNoteTitle;

  /// No description provided for @yourNoteLabel.
  ///
  /// In zh, this message translates to:
  /// **'想法内容'**
  String get yourNoteLabel;

  /// No description provided for @yourNoteHint.
  ///
  /// In zh, this message translates to:
  /// **'写下此刻批注...'**
  String get yourNoteHint;

  /// No description provided for @saveHighlightNote.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get saveHighlightNote;

  /// No description provided for @pdfBitmapNoHighlightToast.
  ///
  /// In zh, this message translates to:
  /// **'原版 PDF 暂不支持划线，请先切换文本重排'**
  String get pdfBitmapNoHighlightToast;

  /// No description provided for @noHighlightableTextToast.
  ///
  /// In zh, this message translates to:
  /// **'当前页面无可划线文本'**
  String get noHighlightableTextToast;

  /// No description provided for @pdfUnsupportedPlatform.
  ///
  /// In zh, this message translates to:
  /// **'当前平台不支持 PDF 位图渲染，请切换文本重排'**
  String get pdfUnsupportedPlatform;

  /// No description provided for @scrollModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'第 {cur}/{total} 章 · 滚动'**
  String scrollModeLabel(int cur, int total);

  /// No description provided for @tocTabTitle.
  ///
  /// In zh, this message translates to:
  /// **'目录 ({count})'**
  String tocTabTitle(int count);

  /// No description provided for @annotationsTabTitle.
  ///
  /// In zh, this message translates to:
  /// **'书签/划线 ({count})'**
  String annotationsTabTitle(int count);

  /// No description provided for @noAnnotationsReaderHint.
  ///
  /// In zh, this message translates to:
  /// **'暂无书签与划线'**
  String get noAnnotationsReaderHint;

  /// No description provided for @endOfChapterHint.
  ///
  /// In zh, this message translates to:
  /// **'本章完'**
  String get endOfChapterHint;

  /// No description provided for @nextChapterHint.
  ///
  /// In zh, this message translates to:
  /// **'下一章：{title}'**
  String nextChapterHint(String title);

  /// No description provided for @notePrefix.
  ///
  /// In zh, this message translates to:
  /// **'想法：{note}'**
  String notePrefix(String note);

  /// No description provided for @mangaReadingModeRtl.
  ///
  /// In zh, this message translates to:
  /// **'从右到左'**
  String get mangaReadingModeRtl;

  /// No description provided for @mangaReadingModeLtr.
  ///
  /// In zh, this message translates to:
  /// **'从左到右'**
  String get mangaReadingModeLtr;

  /// No description provided for @mangaReadingModeWebtoon.
  ///
  /// In zh, this message translates to:
  /// **'条漫滚动'**
  String get mangaReadingModeWebtoon;

  /// No description provided for @mangaReadingModeDual.
  ///
  /// In zh, this message translates to:
  /// **'双页拼接'**
  String get mangaReadingModeDual;

  /// No description provided for @mangaScaleFitScreen.
  ///
  /// In zh, this message translates to:
  /// **'适应屏幕'**
  String get mangaScaleFitScreen;

  /// No description provided for @mangaScaleFitWidth.
  ///
  /// In zh, this message translates to:
  /// **'适应宽度'**
  String get mangaScaleFitWidth;

  /// No description provided for @mangaScaleFitHeight.
  ///
  /// In zh, this message translates to:
  /// **'适应高度'**
  String get mangaScaleFitHeight;

  /// No description provided for @mangaScaleOriginal.
  ///
  /// In zh, this message translates to:
  /// **'原始尺寸'**
  String get mangaScaleOriginal;

  /// No description provided for @mangaTapLShaped.
  ///
  /// In zh, this message translates to:
  /// **'L型单手'**
  String get mangaTapLShaped;

  /// No description provided for @mangaTapEdge.
  ///
  /// In zh, this message translates to:
  /// **'左右边缘'**
  String get mangaTapEdge;

  /// No description provided for @mangaTapKindle.
  ///
  /// In zh, this message translates to:
  /// **'Kindle'**
  String get mangaTapKindle;

  /// No description provided for @mangaTapDisabled.
  ///
  /// In zh, this message translates to:
  /// **'仅滑动'**
  String get mangaTapDisabled;

  /// No description provided for @mangaBgBlack.
  ///
  /// In zh, this message translates to:
  /// **'纯黑'**
  String get mangaBgBlack;

  /// No description provided for @mangaBgDarkGrey.
  ///
  /// In zh, this message translates to:
  /// **'深灰'**
  String get mangaBgDarkGrey;

  /// No description provided for @mangaBgCoolGrey.
  ///
  /// In zh, this message translates to:
  /// **'冷灰'**
  String get mangaBgCoolGrey;

  /// No description provided for @mangaBgWhite.
  ///
  /// In zh, this message translates to:
  /// **'纯白'**
  String get mangaBgWhite;

  /// No description provided for @mangaTabMode.
  ///
  /// In zh, this message translates to:
  /// **'阅读模式'**
  String get mangaTabMode;

  /// No description provided for @mangaTabFilter.
  ///
  /// In zh, this message translates to:
  /// **'图像滤镜'**
  String get mangaTabFilter;

  /// No description provided for @mangaTabGeneral.
  ///
  /// In zh, this message translates to:
  /// **'常规'**
  String get mangaTabGeneral;

  /// No description provided for @mangaAutoDualLandscape.
  ///
  /// In zh, this message translates to:
  /// **'横屏自动双页'**
  String get mangaAutoDualLandscape;

  /// No description provided for @mangaCoverAlone.
  ///
  /// In zh, this message translates to:
  /// **'封面首页独立单页'**
  String get mangaCoverAlone;

  /// No description provided for @mangaAutoCrop.
  ///
  /// In zh, this message translates to:
  /// **'智能白边裁切'**
  String get mangaAutoCrop;

  /// No description provided for @mangaWarmFilter.
  ///
  /// In zh, this message translates to:
  /// **'夜间暖色护眼'**
  String get mangaWarmFilter;

  /// No description provided for @mangaGrayscaleFilter.
  ///
  /// In zh, this message translates to:
  /// **'黑白对比增强'**
  String get mangaGrayscaleFilter;

  /// No description provided for @mangaDimmerLabel.
  ///
  /// In zh, this message translates to:
  /// **'暗室调光'**
  String get mangaDimmerLabel;

  /// No description provided for @mangaCanvasBgLabel.
  ///
  /// In zh, this message translates to:
  /// **'画布底色'**
  String get mangaCanvasBgLabel;

  /// No description provided for @mangaTapLayoutLabel.
  ///
  /// In zh, this message translates to:
  /// **'点击翻页布局'**
  String get mangaTapLayoutLabel;

  /// No description provided for @mangaShowPageBadge.
  ///
  /// In zh, this message translates to:
  /// **'显示底角页码'**
  String get mangaShowPageBadge;

  /// No description provided for @mangaNoImagesInChapter.
  ///
  /// In zh, this message translates to:
  /// **'该章节暂无图片'**
  String get mangaNoImagesInChapter;

  /// No description provided for @mangaDecodeFailed.
  ///
  /// In zh, this message translates to:
  /// **'页面解码失败'**
  String get mangaDecodeFailed;

  /// No description provided for @mangaToggleCropTooltip.
  ///
  /// In zh, this message translates to:
  /// **'智能裁边'**
  String get mangaToggleCropTooltip;

  /// No description provided for @mangaToggleSettingsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'阅读设置'**
  String get mangaToggleSettingsTooltip;

  /// No description provided for @ttsSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'TTS 语音设置'**
  String get ttsSettingsTitle;

  /// No description provided for @ttsResetToast.
  ///
  /// In zh, this message translates to:
  /// **'已恢复默认配置'**
  String get ttsResetToast;

  /// No description provided for @ttsModeLocal.
  ///
  /// In zh, this message translates to:
  /// **'系统 TTS'**
  String get ttsModeLocal;

  /// No description provided for @ttsModeOnline.
  ///
  /// In zh, this message translates to:
  /// **'在线 TTS'**
  String get ttsModeOnline;

  /// No description provided for @ttsSpeechRate.
  ///
  /// In zh, this message translates to:
  /// **'语速'**
  String get ttsSpeechRate;

  /// No description provided for @ttsSpeechPitch.
  ///
  /// In zh, this message translates to:
  /// **'音调'**
  String get ttsSpeechPitch;

  /// No description provided for @ttsPitchLow.
  ///
  /// In zh, this message translates to:
  /// **'低沉 0.8'**
  String get ttsPitchLow;

  /// No description provided for @ttsPitchNormal.
  ///
  /// In zh, this message translates to:
  /// **'标准 1.0'**
  String get ttsPitchNormal;

  /// No description provided for @ttsPitchHigh.
  ///
  /// In zh, this message translates to:
  /// **'清亮 1.2'**
  String get ttsPitchHigh;

  /// No description provided for @ttsAutoTurnPage.
  ///
  /// In zh, this message translates to:
  /// **'自动翻页续读'**
  String get ttsAutoTurnPage;

  /// No description provided for @ttsSleepTimer.
  ///
  /// In zh, this message translates to:
  /// **'定时关闭'**
  String get ttsSleepTimer;

  /// No description provided for @ttsTimerOff.
  ///
  /// In zh, this message translates to:
  /// **'不限'**
  String get ttsTimerOff;

  /// No description provided for @ttsTimerMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{mins} 分钟'**
  String ttsTimerMinutes(int mins);

  /// No description provided for @ttsTimerChapterEnd.
  ///
  /// In zh, this message translates to:
  /// **'播完本章'**
  String get ttsTimerChapterEnd;

  /// No description provided for @ttsEngineLabel.
  ///
  /// In zh, this message translates to:
  /// **'系统引擎'**
  String get ttsEngineLabel;

  /// No description provided for @ttsSystemDefaultEngine.
  ///
  /// In zh, this message translates to:
  /// **'系统默认引擎'**
  String get ttsSystemDefaultEngine;

  /// No description provided for @ttsLanguageLabel.
  ///
  /// In zh, this message translates to:
  /// **'朗读语种'**
  String get ttsLanguageLabel;

  /// No description provided for @ttsLangSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get ttsLangSystem;

  /// No description provided for @ttsLangZhCn.
  ///
  /// In zh, this message translates to:
  /// **'中文（普通话）'**
  String get ttsLangZhCn;

  /// No description provided for @ttsLangZhTw.
  ///
  /// In zh, this message translates to:
  /// **'中文（台湾）'**
  String get ttsLangZhTw;

  /// No description provided for @ttsLangZhHk.
  ///
  /// In zh, this message translates to:
  /// **'中文（粤语）'**
  String get ttsLangZhHk;

  /// No description provided for @ttsLangEnUs.
  ///
  /// In zh, this message translates to:
  /// **'English (US)'**
  String get ttsLangEnUs;

  /// No description provided for @ttsLangJaJp.
  ///
  /// In zh, this message translates to:
  /// **'日本語'**
  String get ttsLangJaJp;

  /// No description provided for @ttsVoiceLabel.
  ///
  /// In zh, this message translates to:
  /// **'发音人'**
  String get ttsVoiceLabel;

  /// No description provided for @ttsVoiceDefault.
  ///
  /// In zh, this message translates to:
  /// **'跟随引擎默认'**
  String get ttsVoiceDefault;

  /// No description provided for @ttsVoiceOffline.
  ///
  /// In zh, this message translates to:
  /// **'离线'**
  String get ttsVoiceOffline;

  /// No description provided for @ttsVoiceNetwork.
  ///
  /// In zh, this message translates to:
  /// **'联网'**
  String get ttsVoiceNetwork;

  /// No description provided for @ttsRefreshEngines.
  ///
  /// In zh, this message translates to:
  /// **'刷新引擎列表'**
  String get ttsRefreshEngines;

  /// No description provided for @ttsPreviewBtn.
  ///
  /// In zh, this message translates to:
  /// **'试听效果'**
  String get ttsPreviewBtn;

  /// No description provided for @ttsStopPreviewBtn.
  ///
  /// In zh, this message translates to:
  /// **'停止试听'**
  String get ttsStopPreviewBtn;

  /// No description provided for @ttsOpenSystemSettings.
  ///
  /// In zh, this message translates to:
  /// **'打开系统 TTS 设置'**
  String get ttsOpenSystemSettings;

  /// No description provided for @ttsNewProfile.
  ///
  /// In zh, this message translates to:
  /// **'新建方案'**
  String get ttsNewProfile;

  /// No description provided for @ttsEditProfile.
  ///
  /// In zh, this message translates to:
  /// **'编辑方案'**
  String get ttsEditProfile;

  /// No description provided for @ttsDeleteProfile.
  ///
  /// In zh, this message translates to:
  /// **'删除方案'**
  String get ttsDeleteProfile;

  /// No description provided for @ttsImportLegado.
  ///
  /// In zh, this message translates to:
  /// **'导入 Legado JSON'**
  String get ttsImportLegado;

  /// No description provided for @ttsProviderEdge.
  ///
  /// In zh, this message translates to:
  /// **'Edge TTS'**
  String get ttsProviderEdge;

  /// No description provided for @ttsProviderOpenAi.
  ///
  /// In zh, this message translates to:
  /// **'OpenAI 兼容'**
  String get ttsProviderOpenAi;

  /// No description provided for @ttsProviderCustomHttp.
  ///
  /// In zh, this message translates to:
  /// **'自定义 HTTP'**
  String get ttsProviderCustomHttp;

  /// No description provided for @ttsProfileNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'方案名称'**
  String get ttsProfileNameLabel;

  /// No description provided for @ttsEdgeModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'连接方式'**
  String get ttsEdgeModeLabel;

  /// No description provided for @ttsEdgeDirect.
  ///
  /// In zh, this message translates to:
  /// **'内置直连 (Beta)'**
  String get ttsEdgeDirect;

  /// No description provided for @ttsEdgeGateway.
  ///
  /// In zh, this message translates to:
  /// **'自部署网关'**
  String get ttsEdgeGateway;

  /// No description provided for @ttsEndpointLabel.
  ///
  /// In zh, this message translates to:
  /// **'接口地址 (URL)'**
  String get ttsEndpointLabel;

  /// No description provided for @ttsApiKeyLabel.
  ///
  /// In zh, this message translates to:
  /// **'API 密钥（安全加密存储）'**
  String get ttsApiKeyLabel;

  /// No description provided for @ttsApiKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'选填，部分自建服务无需密钥'**
  String get ttsApiKeyHint;

  /// No description provided for @ttsModelLabel.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get ttsModelLabel;

  /// No description provided for @ttsVoiceIdLabel.
  ///
  /// In zh, this message translates to:
  /// **'音色 / Voice ID'**
  String get ttsVoiceIdLabel;

  /// No description provided for @ttsFormatLabel.
  ///
  /// In zh, this message translates to:
  /// **'音频格式'**
  String get ttsFormatLabel;

  /// No description provided for @ttsHttpMethodLabel.
  ///
  /// In zh, this message translates to:
  /// **'请求方法'**
  String get ttsHttpMethodLabel;

  /// No description provided for @ttsHeadersJsonLabel.
  ///
  /// In zh, this message translates to:
  /// **'Headers (JSON)'**
  String get ttsHeadersJsonLabel;

  /// No description provided for @ttsBodyTemplateLabel.
  ///
  /// In zh, this message translates to:
  /// **'Body 模板'**
  String get ttsBodyTemplateLabel;

  /// No description provided for @ttsTemplateHint.
  ///
  /// In zh, this message translates to:
  /// **'支持变量：\'{{text}}\' \'{{textEncoded}}\' \'{{voice}}\' \'{{rate}}\' \'{{ratePct}}\' \'{{pitch}}\' \'{{speakSpeed}}\''**
  String get ttsTemplateHint;

  /// No description provided for @ttsTestAndPreview.
  ///
  /// In zh, this message translates to:
  /// **'测试连通并试听'**
  String get ttsTestAndPreview;

  /// No description provided for @ttsTestingConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试中...'**
  String get ttsTestingConnection;

  /// No description provided for @ttsTestConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连通 · {ms} ms'**
  String ttsTestConnected(int ms);

  /// No description provided for @ttsTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败：{detail}'**
  String ttsTestFailed(String detail);

  /// No description provided for @ttsFallbackLocalLabel.
  ///
  /// In zh, this message translates to:
  /// **'失败自动回退系统 TTS'**
  String get ttsFallbackLocalLabel;

  /// No description provided for @ttsClearCacheLabel.
  ///
  /// In zh, this message translates to:
  /// **'清理音频缓存 ({size})'**
  String ttsClearCacheLabel(String size);

  /// No description provided for @ttsCacheClearedToast.
  ///
  /// In zh, this message translates to:
  /// **'已清理在线语音缓存'**
  String get ttsCacheClearedToast;

  /// No description provided for @ttsPlayingStatus.
  ///
  /// In zh, this message translates to:
  /// **'{label} · {rate}x'**
  String ttsPlayingStatus(String label, String rate);

  /// No description provided for @ttsOnlineFallbackNotice.
  ///
  /// In zh, this message translates to:
  /// **'在线语音不可用，已切换系统朗读'**
  String get ttsOnlineFallbackNotice;

  /// No description provided for @ttsPrevSentence.
  ///
  /// In zh, this message translates to:
  /// **'上一句'**
  String get ttsPrevSentence;

  /// No description provided for @ttsNextSentence.
  ///
  /// In zh, this message translates to:
  /// **'下一句'**
  String get ttsNextSentence;

  /// No description provided for @ttsPause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get ttsPause;

  /// No description provided for @ttsResume.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get ttsResume;

  /// No description provided for @ttsStop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get ttsStop;

  /// No description provided for @ttsStoppedToast.
  ///
  /// In zh, this message translates to:
  /// **'已停止听书'**
  String get ttsStoppedToast;

  /// No description provided for @ttsStartedToast.
  ///
  /// In zh, this message translates to:
  /// **'开始语音朗读'**
  String get ttsStartedToast;

  /// No description provided for @ttsUnavailableToast.
  ///
  /// In zh, this message translates to:
  /// **'当前无可朗读内容或语音服务不可用'**
  String get ttsUnavailableToast;

  /// No description provided for @ttsTimerExpiredToast.
  ///
  /// In zh, this message translates to:
  /// **'定时关闭已到'**
  String get ttsTimerExpiredToast;

  /// No description provided for @ttsSleepChapterDoneToast.
  ///
  /// In zh, this message translates to:
  /// **'本章朗读完毕，已定时停止'**
  String get ttsSleepChapterDoneToast;

  /// No description provided for @tocRulesTitle.
  ///
  /// In zh, this message translates to:
  /// **'TXT 目录规则'**
  String get tocRulesTitle;

  /// No description provided for @newRuleTooltip.
  ///
  /// In zh, this message translates to:
  /// **'新建规则'**
  String get newRuleTooltip;

  /// No description provided for @moreActionsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get moreActionsTooltip;

  /// No description provided for @importRuleFile.
  ///
  /// In zh, this message translates to:
  /// **'导入文件'**
  String get importRuleFile;

  /// No description provided for @pasteJsonImport.
  ///
  /// In zh, this message translates to:
  /// **'粘贴 JSON'**
  String get pasteJsonImport;

  /// No description provided for @noTocRules.
  ///
  /// In zh, this message translates to:
  /// **'暂无目录规则'**
  String get noTocRules;

  /// No description provided for @restoreDefaultRules.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认规则'**
  String get restoreDefaultRules;

  /// No description provided for @customBadge.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get customBadge;

  /// No description provided for @examplePrefix.
  ///
  /// In zh, this message translates to:
  /// **'示例：{example}'**
  String examplePrefix(String example);

  /// No description provided for @editTestBtn.
  ///
  /// In zh, this message translates to:
  /// **'编辑 / 测试'**
  String get editTestBtn;

  /// No description provided for @ruleNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'规则名称'**
  String get ruleNameLabel;

  /// No description provided for @regexLabel.
  ///
  /// In zh, this message translates to:
  /// **'正则表达式'**
  String get regexLabel;

  /// No description provided for @sampleTextLabel.
  ///
  /// In zh, this message translates to:
  /// **'测试文本'**
  String get sampleTextLabel;

  /// No description provided for @liveTestBtn.
  ///
  /// In zh, this message translates to:
  /// **'测试匹配'**
  String get liveTestBtn;

  /// No description provided for @deleteRuleTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除规则'**
  String get deleteRuleTitle;

  /// No description provided for @deleteRuleConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」吗？'**
  String deleteRuleConfirm(String name);

  /// No description provided for @tocActionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'规则库操作'**
  String get tocActionsTitle;

  /// No description provided for @exportToClipboard.
  ///
  /// In zh, this message translates to:
  /// **'导出规则 JSON'**
  String get exportToClipboard;

  /// No description provided for @restoreBuiltinRules.
  ///
  /// In zh, this message translates to:
  /// **'恢复内置规则'**
  String get restoreBuiltinRules;

  /// No description provided for @pasteImportTitle.
  ///
  /// In zh, this message translates to:
  /// **'粘贴导入规则'**
  String get pasteImportTitle;

  /// No description provided for @ruleJsonOrRegexLabel.
  ///
  /// In zh, this message translates to:
  /// **'Legado JSON 或 名称::正则'**
  String get ruleJsonOrRegexLabel;

  /// No description provided for @pasteFromClipboard.
  ///
  /// In zh, this message translates to:
  /// **'粘贴剪贴板'**
  String get pasteFromClipboard;

  /// No description provided for @importRulesBtn.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importRulesBtn;

  /// No description provided for @newRuleTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建规则'**
  String get newRuleTitle;

  /// No description provided for @editRuleTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑规则'**
  String get editRuleTitle;

  /// No description provided for @webdavTitle.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 同步'**
  String get webdavTitle;

  /// No description provided for @webdavConfigureTooltip.
  ///
  /// In zh, this message translates to:
  /// **'配置服务器'**
  String get webdavConfigureTooltip;

  /// No description provided for @webdavCenterTitle.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 同步中心'**
  String get webdavCenterTitle;

  /// No description provided for @webdavOnline.
  ///
  /// In zh, this message translates to:
  /// **'在线'**
  String get webdavOnline;

  /// No description provided for @webdavOffline.
  ///
  /// In zh, this message translates to:
  /// **'待连接'**
  String get webdavOffline;

  /// No description provided for @webdavSyncNow.
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get webdavSyncNow;

  /// No description provided for @webdavSyncing.
  ///
  /// In zh, this message translates to:
  /// **'同步中...'**
  String get webdavSyncing;

  /// No description provided for @webdavCreateBackup.
  ///
  /// In zh, this message translates to:
  /// **'创建快照'**
  String get webdavCreateBackup;

  /// No description provided for @webdavSyncScope.
  ///
  /// In zh, this message translates to:
  /// **'同步范围'**
  String get webdavSyncScope;

  /// No description provided for @webdavScopeProgress.
  ///
  /// In zh, this message translates to:
  /// **'进度与书签'**
  String get webdavScopeProgress;

  /// No description provided for @webdavScopeProgressDesc.
  ///
  /// In zh, this message translates to:
  /// **'跨端增量合并阅读位置'**
  String get webdavScopeProgressDesc;

  /// No description provided for @webdavScopeMeta.
  ///
  /// In zh, this message translates to:
  /// **'书架与笔记'**
  String get webdavScopeMeta;

  /// No description provided for @webdavScopeMetaDesc.
  ///
  /// In zh, this message translates to:
  /// **'书架分组、划线与批注'**
  String get webdavScopeMetaDesc;

  /// No description provided for @webdavScopePrefs.
  ///
  /// In zh, this message translates to:
  /// **'排版与主题'**
  String get webdavScopePrefs;

  /// No description provided for @webdavScopePrefsDesc.
  ///
  /// In zh, this message translates to:
  /// **'阅读字号、配色与外观'**
  String get webdavScopePrefsDesc;

  /// No description provided for @webdavScopeSourceFiles.
  ///
  /// In zh, this message translates to:
  /// **'书籍与漫画源文件'**
  String get webdavScopeSourceFiles;

  /// No description provided for @webdavScopeSourceFilesDesc.
  ///
  /// In zh, this message translates to:
  /// **'仅上传非敏感本地文件'**
  String get webdavScopeSourceFilesDesc;

  /// No description provided for @webdavPresetsTitle.
  ///
  /// In zh, this message translates to:
  /// **'常用服务器预设'**
  String get webdavPresetsTitle;

  /// No description provided for @webdavBackupsTitle.
  ///
  /// In zh, this message translates to:
  /// **'云端快照'**
  String get webdavBackupsTitle;

  /// No description provided for @webdavNoBackups.
  ///
  /// In zh, this message translates to:
  /// **'暂无云端快照'**
  String get webdavNoBackups;

  /// No description provided for @webdavRestoreBtn.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get webdavRestoreBtn;

  /// No description provided for @webdavConfigTitle.
  ///
  /// In zh, this message translates to:
  /// **'配置 {preset}'**
  String webdavConfigTitle(String preset);

  /// No description provided for @webdavServerUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get webdavServerUrlLabel;

  /// No description provided for @webdavUserLabel.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get webdavUserLabel;

  /// No description provided for @webdavPassLabel.
  ///
  /// In zh, this message translates to:
  /// **'应用密码'**
  String get webdavPassLabel;

  /// No description provided for @webdavRootLabel.
  ///
  /// In zh, this message translates to:
  /// **'同步目录'**
  String get webdavRootLabel;

  /// No description provided for @webdavSaveAndTest.
  ///
  /// In zh, this message translates to:
  /// **'保存并测试'**
  String get webdavSaveAndTest;

  /// No description provided for @webdavConflictTitle.
  ///
  /// In zh, this message translates to:
  /// **'进度冲突'**
  String get webdavConflictTitle;

  /// No description provided for @webdavConflictSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'《{title}》两端均有新进度：'**
  String webdavConflictSubtitle(String title);

  /// No description provided for @webdavRemoteLabel.
  ///
  /// In zh, this message translates to:
  /// **'云端 ({device})'**
  String webdavRemoteLabel(String device);

  /// No description provided for @webdavLocalLabel.
  ///
  /// In zh, this message translates to:
  /// **'本机 ({device})'**
  String webdavLocalLabel(String device);

  /// No description provided for @webdavKeepLocal.
  ///
  /// In zh, this message translates to:
  /// **'保留本机'**
  String get webdavKeepLocal;

  /// No description provided for @webdavAdoptRemote.
  ///
  /// In zh, this message translates to:
  /// **'采用云端'**
  String get webdavAdoptRemote;

  /// No description provided for @webdavSyncDone.
  ///
  /// In zh, this message translates to:
  /// **'同步完成'**
  String get webdavSyncDone;

  /// No description provided for @webdavSnapSummary.
  ///
  /// In zh, this message translates to:
  /// **'{preset} · 连接正常 ({count} 份快照)'**
  String webdavSnapSummary(String preset, int count);

  /// No description provided for @webdavTestPassed.
  ///
  /// In zh, this message translates to:
  /// **'连接成功'**
  String get webdavTestPassed;

  /// No description provided for @webdavTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败：{error}'**
  String webdavTestFailed(String error);

  /// No description provided for @errFileNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到文件'**
  String get errFileNotFound;

  /// No description provided for @errFileEmpty.
  ///
  /// In zh, this message translates to:
  /// **'文件为空 (0 字节)'**
  String get errFileEmpty;

  /// No description provided for @errStreamOpen.
  ///
  /// In zh, this message translates to:
  /// **'无法读取文件流，请检查存储权限'**
  String get errStreamOpen;

  /// No description provided for @errUnsupportedType.
  ///
  /// In zh, this message translates to:
  /// **'不支持的文件格式'**
  String get errUnsupportedType;

  /// No description provided for @errTtsUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'系统 TTS 引擎不可用，请检查语音包'**
  String get errTtsUnavailable;

  /// No description provided for @errTtsTimeout.
  ///
  /// In zh, this message translates to:
  /// **'语音引擎初始化超时'**
  String get errTtsTimeout;

  /// No description provided for @errTtsSpeakFailed.
  ///
  /// In zh, this message translates to:
  /// **'语音合成播放失败'**
  String get errTtsSpeakFailed;

  /// No description provided for @errEdge403.
  ///
  /// In zh, this message translates to:
  /// **'Edge 直连校验已失效 (403)，请切换自部署网关或使用系统 TTS'**
  String get errEdge403;

  /// No description provided for @errNetworkTimeout.
  ///
  /// In zh, this message translates to:
  /// **'网络请求超时'**
  String get errNetworkTimeout;

  /// No description provided for @errHttp401.
  ///
  /// In zh, this message translates to:
  /// **'接口鉴权失败 (401)，请检查 API Key'**
  String get errHttp401;

  /// No description provided for @errHttp403.
  ///
  /// In zh, this message translates to:
  /// **'访问被拒绝 (403)'**
  String get errHttp403;

  /// No description provided for @errHttpStatus.
  ///
  /// In zh, this message translates to:
  /// **'服务端返回错误状态'**
  String get errHttpStatus;

  /// No description provided for @errInvalidAudio.
  ///
  /// In zh, this message translates to:
  /// **'服务返回的不是有效音频'**
  String get errInvalidAudio;

  /// No description provided for @errInvalidJson.
  ///
  /// In zh, this message translates to:
  /// **'JSON 格式无效'**
  String get errInvalidJson;

  /// No description provided for @errUnknown.
  ///
  /// In zh, this message translates to:
  /// **'操作失败'**
  String get errUnknown;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
