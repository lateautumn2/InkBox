// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'InkBox';

  @override
  String get navBooks => 'Books';

  @override
  String get navManga => 'Manga';

  @override
  String get navImport => 'Import';

  @override
  String get navMe => 'Settings';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get delete => 'Delete';

  @override
  String get confirmDelete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get rename => 'Rename';

  @override
  String get close => 'Close';

  @override
  String get reset => 'Reset';

  @override
  String get search => 'Search';

  @override
  String get refresh => 'Refresh';

  @override
  String get copy => 'Copy';

  @override
  String get restore => 'Restore';

  @override
  String get open => 'Open';

  @override
  String get retry => 'Retry';

  @override
  String get clear => 'Clear';

  @override
  String get details => 'Details';

  @override
  String get none => 'Off';

  @override
  String get loading => 'Loading...';

  @override
  String get shelfGroupAll => 'All';

  @override
  String get shelfGroupReading => 'Reading';

  @override
  String get shelfGroupFinished => 'Finished';

  @override
  String get defaultBookshelf => 'Default Shelf';

  @override
  String get defaultMangaShelf => 'Default Manga';

  @override
  String get unknownAuthor => 'Unknown Author';

  @override
  String get readyToRead => 'Ready to read';

  @override
  String shelvesCountBadge(int count) {
    return '$count';
  }

  @override
  String selectedCountBooks(int count) {
    return '$count selected';
  }

  @override
  String selectedCountManga(int count) {
    return '$count selected';
  }

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortLastRead => 'Last Read';

  @override
  String get sortAddedAt => 'Date Added';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortProgress => 'Progress';

  @override
  String get gridView => 'Grid view';

  @override
  String get listView => 'List view';

  @override
  String get searchBooks => 'Search books';

  @override
  String get searchBooksHint => 'Search title or author...';

  @override
  String get searchManga => 'Search manga';

  @override
  String get searchMangaHint => 'Search title or author...';

  @override
  String get continueReading => 'Continue';

  @override
  String get emptyLibraryBooks =>
      'Your bookshelf is empty. Import your first book.';

  @override
  String emptyShelfBooks(String shelfName) {
    return 'No books in \"$shelfName\"';
  }

  @override
  String get emptyGroupBooks => 'No books in this group';

  @override
  String get importLocalBooks => 'Import Books';

  @override
  String get switchOtherShelf => 'Switch Shelf';

  @override
  String get emptyLibraryManga => 'No manga yet. Go to Import to add some.';

  @override
  String emptyShelfManga(String shelfName) {
    return 'No manga in \"$shelfName\"';
  }

  @override
  String get emptyGroupManga => 'No manga in this group';

  @override
  String get importLocalManga => 'Import Manga';

  @override
  String bookshelfLoadError(String error) {
    return 'Failed to load bookshelf: $error';
  }

  @override
  String mangaShelfLoadError(String error) {
    return 'Failed to load manga shelf: $error';
  }

  @override
  String get moveShelf => 'Move';

  @override
  String get markFinished => 'Mark Finished';

  @override
  String get markReading => 'Mark Reading';

  @override
  String get removeBooks => 'Remove';

  @override
  String get markAllRead => 'Mark Read';

  @override
  String get resetUnread => 'Mark Unread';

  @override
  String get removeManga => 'Remove';

  @override
  String moveBookSuccess(int count, String target) {
    return 'Moved $count books to \"$target\"';
  }

  @override
  String moveMangaSuccess(int count, String target) {
    return 'Moved $count manga to \"$target\"';
  }

  @override
  String removeBooksTitle(int count) {
    return 'Remove $count Books';
  }

  @override
  String removeMangaTitle(int count) {
    return 'Remove $count Manga';
  }

  @override
  String removeBookTitleSingle(String title) {
    return 'Remove \"$title\"';
  }

  @override
  String get removeArchiveOption => 'Remove from shelf (keep history)';

  @override
  String get removeArchiveMangaOption =>
      'Remove from manga shelf (keep history)';

  @override
  String get removePermanentOption => 'Delete permanently';

  @override
  String archivedBooksToast(int count) {
    return 'Removed $count books from shelf';
  }

  @override
  String deletedBooksToast(int count) {
    return 'Deleted $count books permanently';
  }

  @override
  String get bookDetailsTitle => 'Book Details';

  @override
  String get mangaDetailsTitle => 'Manga Details';

  @override
  String get notFoundBook => 'Book not found';

  @override
  String get notFoundManga => 'Manga not found';

  @override
  String get movedShelfSuccess => 'Shelf updated';

  @override
  String get pinToShelf => 'Pin';

  @override
  String get unpinFromShelf => 'Unpin';

  @override
  String get editMetadata => 'Edit Info';

  @override
  String get bookTitleLabel => 'Title';

  @override
  String get authorLabel => 'Author';

  @override
  String get shelfBelongsTo => 'Shelf';

  @override
  String get orCreateShelf => 'Or create new shelf';

  @override
  String get readingStatusLabel => 'Reading Status';

  @override
  String readingMinutesShort(int mins) {
    return '$mins min';
  }

  @override
  String readProgressShort(String pct) {
    return '$pct% read';
  }

  @override
  String tocChaptersCount(int count) {
    return 'Chapters ($count)';
  }

  @override
  String get ascendingOrder => 'Asc';

  @override
  String get descendingOrder => 'Desc';

  @override
  String get fullToc => 'All';

  @override
  String expandFullToc(int count) {
    return 'View all $count chapters';
  }

  @override
  String get noTocFound => 'No chapters detected';

  @override
  String get currentReadingTag => 'Current';

  @override
  String txtRuleEncodingMeta(String rule, String encoding) {
    return 'Rule: $rule · Encoding: $encoding';
  }

  @override
  String get smartAutoDetect => 'Auto';

  @override
  String get switchTocRule => 'TOC Rule';

  @override
  String get switchEncoding => 'Encoding';

  @override
  String get manageRuleLibrary => 'Rule Library';

  @override
  String get selectTocRuleTitle => 'Select TOC Rule';

  @override
  String get autoDetectRecommended => 'Smart Auto-Detect';

  @override
  String ruleUnmatchedTag(String name) {
    return '$name (Unmatched)';
  }

  @override
  String tocReloadedCount(int count) {
    return 'Reloaded $count chapters';
  }

  @override
  String tocNoMatchFallback(int count) {
    return 'No match; split into $count sections';
  }

  @override
  String get selectEncodingTitle => 'Select Text Encoding';

  @override
  String get encodingAuto => 'Auto-Detect';

  @override
  String get encodingGb18030 => 'GB18030 / GBK';

  @override
  String get encodingBig5 => 'Big5';

  @override
  String encodingSwitched(String encoding) {
    return 'Encoding switched: $encoding';
  }

  @override
  String get annotationsTitle => 'Bookmarks & Highlights';

  @override
  String get noAnnotationsHint => 'No bookmarks or highlights yet';

  @override
  String get bookmarkTag => 'Bookmark';

  @override
  String get highlightNoteTag => 'Note';

  @override
  String get highlightTag => 'Highlight';

  @override
  String chapterLabelShort(int index) {
    return 'Ch. $index';
  }

  @override
  String get localFileInfo => 'Local File';

  @override
  String pathLabel(String path) {
    return 'Path: $path';
  }

  @override
  String fingerprintLabel(String hash) {
    return 'Hash: $hash';
  }

  @override
  String get searchChapterHint => 'Search chapters...';

  @override
  String get noMatchingChapters => 'No matching chapters';

  @override
  String get mangaDefaultModeLabel => 'Reading Mode';

  @override
  String get smartCropLabel => 'Smart Margin Crop';

  @override
  String get splitWidePagesLabel => 'Split Wide Spreads';

  @override
  String chaptersVolumeList(int count) {
    return 'Chapters ($count)';
  }

  @override
  String get unreadOnly => 'Unread';

  @override
  String get unreadOnlyActive => 'Unread ✓';

  @override
  String get noChaptersMatchHint => 'No matching chapters';

  @override
  String get startReading => 'Start Reading';

  @override
  String get readLabel => 'Read';

  @override
  String pageOfTotalUnknown(int current, String total) {
    return 'Page $current/$total';
  }

  @override
  String get markAllReadMenu => 'Mark all as read';

  @override
  String get resetUnreadMenu => 'Reset all as unread';

  @override
  String get moveMangaShelfMenu => 'Move to another shelf';

  @override
  String get shelfNameExists => 'Name already exists';

  @override
  String get shelfRenameConflict => 'Unchanged or duplicate name';

  @override
  String deleteShelfTitle(String name) {
    return 'Delete \"$name\"';
  }

  @override
  String deleteShelfConfirm(String fallback) {
    return 'Items will move to \"$fallback\". Local files are preserved.';
  }

  @override
  String get createShelfTitle => 'New Shelf';

  @override
  String get createMangaShelfTitle => 'New Manga Shelf';

  @override
  String get renameShelfTitle => 'Rename Shelf';

  @override
  String get renameMangaShelfTitle => 'Rename Manga Shelf';

  @override
  String get shelfNameLabel => 'Name';

  @override
  String get newNameLabel => 'New name';

  @override
  String get switchBookshelfTitle => 'Switch Shelf';

  @override
  String get switchMangaShelfTitle => 'Switch Manga Shelf';

  @override
  String get multiShelfManagerTitle => 'Shelves';

  @override
  String get bookshelfTab => 'Books';

  @override
  String get mangaShelfTab => 'Manga';

  @override
  String get defaultShelfBadge => 'Default';

  @override
  String shelfItemCountBook(int count) {
    return '$count books';
  }

  @override
  String shelfItemCountManga(int count) {
    return '$count manga';
  }

  @override
  String get inUseLabel => 'Active';

  @override
  String get moveToShelfTitleBook => 'Move to Shelf';

  @override
  String get moveToShelfTitleManga => 'Move to Manga Shelf';

  @override
  String get orCreateAndMoveBook => 'Or create shelf & move';

  @override
  String get orCreateAndMoveManga => 'Or create manga shelf & move';

  @override
  String get shelfExampleBook => 'e.g. Fiction, History';

  @override
  String get shelfExampleManga => 'e.g. Ongoing, Completed';

  @override
  String get mineTitle => 'Settings';

  @override
  String get appearanceSettings => 'Appearance';

  @override
  String get themePresets => 'Theme';

  @override
  String get uiStyleLabel => 'Surface Style';

  @override
  String get uiStyleFloating => 'Floating Card';

  @override
  String get uiStyleClassic => 'Classic MD3';

  @override
  String get colorThemeLabel => 'Color Mode';

  @override
  String get themeCrispLight => 'Crisp Light';

  @override
  String get themeDarkTheater => 'Dark Theater';

  @override
  String get themeOledBlack => 'OLED Black';

  @override
  String get themeFollowSystem => 'System';

  @override
  String get dynamicColorTitle => 'Material You';

  @override
  String get dynamicColorSubtitle => 'Dynamic wallpaper accent';

  @override
  String get appLanguageTitle => 'Language';

  @override
  String get languageSystem => 'Follow System';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageEn => 'English';

  @override
  String get languageJa => '日本語';

  @override
  String get statBooks => 'Books';

  @override
  String get statReading => 'Reading';

  @override
  String get statFinished => 'Done';

  @override
  String get statMinutes => 'Minutes';

  @override
  String get sectionAppearanceLanguage => 'Appearance & Language';

  @override
  String get sectionReadingSync => 'Reading & Sync';

  @override
  String get multiShelfManagerMenu => 'Manage Shelves';

  @override
  String multiShelfSummary(int books, int manga) {
    return '$books book · $manga manga';
  }

  @override
  String get ttsMenuTitle => 'TTS Voice';

  @override
  String ttsMenuSummaryLocal(String rate) {
    return 'System · ${rate}x';
  }

  @override
  String ttsMenuSummaryOnline(String name, String rate) {
    return 'Online · $name · ${rate}x';
  }

  @override
  String get tocRulesMenuTitle => 'TXT TOC Rules';

  @override
  String tocRulesMenuSummary(int enabled, int total) {
    return '$enabled / $total enabled';
  }

  @override
  String get webdavMenuTitle => 'WebDAV Sync';

  @override
  String get webdavUnconfigured => 'Not configured';

  @override
  String get importHubTitle => 'Import';

  @override
  String get rescanFolders => 'Rescan';

  @override
  String get supportedFormats => 'Supported Formats';

  @override
  String supportedFormatsBooks(String formats) {
    return 'Books: $formats';
  }

  @override
  String supportedFormatsManga(String formats) {
    return 'Manga: $formats';
  }

  @override
  String get supportedFormatsImageFolder => 'Image Folder';

  @override
  String get pickLocalFiles => 'Pick Files';

  @override
  String get addAndScanFolder => 'Choose Scan Folder';

  @override
  String get importOptions => 'Options';

  @override
  String get smartAutoClassify => 'Auto-classify books & manga';

  @override
  String get overwriteDuplicates => 'Overwrite existing items';

  @override
  String watchedFoldersTitle(int count) {
    return 'Watched Folders ($count)';
  }

  @override
  String get formatAll => 'All';

  @override
  String get formatComicArchive => 'Manga';

  @override
  String importHistoryTitle(int count) {
    return 'History ($count)';
  }

  @override
  String get historyAll => 'All';

  @override
  String get historyArchived => 'Archived';

  @override
  String get historyOnShelf => 'On Shelf';

  @override
  String get noImportHistory => 'No imports yet';

  @override
  String get noMatchingHistory => 'No matching records';

  @override
  String get fileMissingBadge => 'Missing';

  @override
  String get archivedBadge => 'Archived';

  @override
  String get onShelfBadge => 'On Shelf';

  @override
  String get restoreToShelf => 'Restore';

  @override
  String get readNow => 'Read';

  @override
  String get permanentDeleteTitle => 'Delete Permanently';

  @override
  String permanentDeleteConfirm(String title) {
    return 'Permanently delete \"$title\"? History and local cache will be erased.';
  }

  @override
  String deletedForeverToast(String title) {
    return 'Deleted \"$title\"';
  }

  @override
  String fileMissingReimportToast(String title) {
    return '\"$title\" file is missing. Please re-import.';
  }

  @override
  String restoredToShelfToast(String title) {
    return 'Restored \"$title\" to shelf';
  }

  @override
  String folderScanDoneToast(int count) {
    return 'Scan finished: $count files found';
  }

  @override
  String importResultSummary(int books, int manga) {
    return 'Imported: +$books books, +$manga manga';
  }

  @override
  String importResultSkipped(int count) {
    return ', $count duplicates';
  }

  @override
  String importResultFailed(int count) {
    return ', $count failed';
  }

  @override
  String get viewBookshelf => 'Books';

  @override
  String get viewMangaShelf => 'Manga';

  @override
  String get lastImportResultTitle => 'Import Summary';

  @override
  String get collapseLabel => 'Hide';

  @override
  String importedStatus(String title) {
    return 'Added: $title';
  }

  @override
  String repairedStatus(String title) {
    return 'Updated: $title';
  }

  @override
  String duplicateStatus(String title) {
    return 'Exists: $title';
  }

  @override
  String get overwriteReimport => 'Overwrite';

  @override
  String overwriteSuccessToast(String title) {
    return 'Overwrote \"$title\"';
  }

  @override
  String overwriteFailedToast(String error) {
    return 'Overwrite failed: $error';
  }

  @override
  String selectedCandidatesCount(int count) {
    return '$count selected';
  }

  @override
  String importToShelfCount(int count) {
    return 'Import ($count)';
  }

  @override
  String get switchToBook => 'Book';

  @override
  String get switchToComic => 'Manga';

  @override
  String get classifiedAsBook => 'Bookshelf';

  @override
  String get classifiedAsComic => 'Manga';

  @override
  String historyBookSubtitle(String author, int pct) {
    return '$author · $pct%';
  }

  @override
  String historyMangaSubtitle(String author, int chapters) {
    return '$author · $chapters ch.';
  }

  @override
  String get emptyChapterPlaceholder => '(This chapter has no text content)';

  @override
  String get firstPageToast => 'Already on first page';

  @override
  String get lastPageToast => 'Already on last page';

  @override
  String get chapterFinishedToast => 'Chapter finished';

  @override
  String get bookmarkAddedToast => 'Bookmark added';

  @override
  String get bookmarkRemovedToast => 'Bookmark removed';

  @override
  String get addBookmarkTooltip => 'Add bookmark';

  @override
  String get removeBookmarkTooltip => 'Remove bookmark';

  @override
  String get highlightNotesTooltip => 'Highlight';

  @override
  String get ttsListenTooltip => 'Listen';

  @override
  String get originalPdf => 'PDF View';

  @override
  String get textReflow => 'Reflow';

  @override
  String get prevChapter => 'Prev';

  @override
  String get nextChapter => 'Next';

  @override
  String get readerTabToc => 'Contents';

  @override
  String get readerTabDark => 'Dark';

  @override
  String get readerTabLight => 'Light';

  @override
  String get readerTabStyle => 'Layout';

  @override
  String get readerTabTurn => 'Turn';

  @override
  String get readerTabMore => 'More';

  @override
  String get paperWhite => 'White';

  @override
  String get paperIvory => 'Ivory';

  @override
  String get paperSage => 'Celadon';

  @override
  String get paperDark => 'Slate';

  @override
  String get paperOled => 'OLED';

  @override
  String get turnSimulation => 'Curl';

  @override
  String get turnCover => 'Cover';

  @override
  String get turnSlide => 'Slide';

  @override
  String get turnScroll => 'Scroll';

  @override
  String get layoutModeLabel => 'Spread';

  @override
  String get layoutAuto => 'Auto';

  @override
  String get layoutSingle => 'Single';

  @override
  String get layoutDual => 'Dual';

  @override
  String get fontSizeLabel => 'Size';

  @override
  String get lineHeightLabel => 'Spacing';

  @override
  String get paragraphSpacingLabel => 'Para Gap';

  @override
  String get firstLineIndentLabel => 'First-line Indent';

  @override
  String get chineseOriginal => 'Original';

  @override
  String get chineseTrad => 'Trad.';

  @override
  String get chineseSimp => 'Simp.';

  @override
  String get tapZoneLabel => 'Tap Zones';

  @override
  String get tapZoneStandard => 'Standard';

  @override
  String get tapZoneLeftHand => 'Left Hand';

  @override
  String get tapZoneRightHand => 'Right Hand';

  @override
  String get tapZoneCustom => 'Custom';

  @override
  String get autoScrollLabel => 'Auto-Scroll';

  @override
  String get startAutoScroll => 'Start';

  @override
  String get stopAutoScroll => 'Stop';

  @override
  String get autoScrollReachedEnd => 'Reached end of book';

  @override
  String get volumeKeyPaging => 'Volume Keys Turn Page';

  @override
  String get keepScreenOn => 'Keep Screen On';

  @override
  String get edgeBrightnessGesture => 'Edge Brightness Swipe';

  @override
  String brightnessIndicator(int pct) {
    return 'Brightness $pct%';
  }

  @override
  String get ttsSettingsBtn => 'TTS';

  @override
  String get purificationBtn => 'Clean Rules';

  @override
  String get exportNotesBtn => 'Export Notes';

  @override
  String exportNotesSuccess(int count) {
    return 'Copied $count notes to clipboard';
  }

  @override
  String get purificationDialogTitle => 'Add Text Cleanup Rule';

  @override
  String get purificationPatternLabel => 'Text or Regex';

  @override
  String get purificationPatternHint => 'e.g. Advertisement.*';

  @override
  String get purificationReplacementLabel => 'Replace with (empty deletes)';

  @override
  String get purificationReplacementHint => 'Leave blank to remove';

  @override
  String get addAndApply => 'Apply';

  @override
  String get highlightAction => 'Highlight';

  @override
  String get writeNoteAction => 'Note';

  @override
  String get editNoteAction => 'Edit Note';

  @override
  String get deleteHighlightAction => 'Delete';

  @override
  String get highlightSavedToast => 'Highlight saved';

  @override
  String get noteSavedToast => 'Note saved';

  @override
  String get highlightDeletedToast => 'Highlight deleted';

  @override
  String get copiedToast => 'Copied';

  @override
  String get addNoteTitle => 'Add Note';

  @override
  String get editNoteTitle => 'Edit Note';

  @override
  String get yourNoteLabel => 'Note';

  @override
  String get yourNoteHint => 'Write your thought...';

  @override
  String get saveHighlightNote => 'Save';

  @override
  String get pdfBitmapNoHighlightToast =>
      'Switch to Reflow mode to highlight PDF text';

  @override
  String get noHighlightableTextToast => 'No text available on this page';

  @override
  String get pdfUnsupportedPlatform =>
      'Switch to Reflow mode to read PDF on this platform';

  @override
  String scrollModeLabel(int cur, int total) {
    return 'Ch. $cur/$total · Scroll';
  }

  @override
  String tocTabTitle(int count) {
    return 'Contents ($count)';
  }

  @override
  String annotationsTabTitle(int count) {
    return 'Notes ($count)';
  }

  @override
  String get noAnnotationsReaderHint => 'No bookmarks or highlights';

  @override
  String get endOfChapterHint => 'End of Chapter';

  @override
  String nextChapterHint(String title) {
    return 'Next: $title';
  }

  @override
  String notePrefix(String note) {
    return 'Note: $note';
  }

  @override
  String get mangaReadingModeRtl => 'Right to Left';

  @override
  String get mangaReadingModeLtr => 'Left to Right';

  @override
  String get mangaReadingModeWebtoon => 'Webtoon';

  @override
  String get mangaReadingModeDual => 'Dual Page';

  @override
  String get mangaScaleFitScreen => 'Fit Screen';

  @override
  String get mangaScaleFitWidth => 'Fit Width';

  @override
  String get mangaScaleFitHeight => 'Fit Height';

  @override
  String get mangaScaleOriginal => 'Original';

  @override
  String get mangaTapLShaped => 'L-Shaped';

  @override
  String get mangaTapEdge => 'Edges';

  @override
  String get mangaTapKindle => 'Kindle';

  @override
  String get mangaTapDisabled => 'Swipe Only';

  @override
  String get mangaBgBlack => 'Black';

  @override
  String get mangaBgDarkGrey => 'Charcoal';

  @override
  String get mangaBgCoolGrey => 'Cool Grey';

  @override
  String get mangaBgWhite => 'White';

  @override
  String get mangaTabMode => 'Mode';

  @override
  String get mangaTabFilter => 'Filter';

  @override
  String get mangaTabGeneral => 'General';

  @override
  String get mangaAutoDualLandscape => 'Auto Dual-Page in Landscape';

  @override
  String get mangaCoverAlone => 'Single Cover Page';

  @override
  String get mangaAutoCrop => 'Smart Margin Crop';

  @override
  String get mangaWarmFilter => 'Warm Eye-Care Filter';

  @override
  String get mangaGrayscaleFilter => 'High-Contrast Grayscale';

  @override
  String get mangaDimmerLabel => 'Dimmer';

  @override
  String get mangaCanvasBgLabel => 'Background';

  @override
  String get mangaTapLayoutLabel => 'Tap Layout';

  @override
  String get mangaShowPageBadge => 'Show Page Badge';

  @override
  String get mangaNoImagesInChapter => 'No images in this chapter';

  @override
  String get mangaDecodeFailed => 'Failed to decode page';

  @override
  String get mangaToggleCropTooltip => 'Smart Crop';

  @override
  String get mangaToggleSettingsTooltip => 'Reader Settings';

  @override
  String get ttsSettingsTitle => 'TTS Settings';

  @override
  String get ttsResetToast => 'Reset to default TTS settings';

  @override
  String get ttsModeLocal => 'System TTS';

  @override
  String get ttsModeOnline => 'Online TTS';

  @override
  String get ttsSpeechRate => 'Rate';

  @override
  String get ttsSpeechPitch => 'Pitch';

  @override
  String get ttsPitchLow => 'Low 0.8';

  @override
  String get ttsPitchNormal => 'Normal 1.0';

  @override
  String get ttsPitchHigh => 'Bright 1.2';

  @override
  String get ttsAutoTurnPage => 'Auto-Turn Page';

  @override
  String get ttsSleepTimer => 'Sleep Timer';

  @override
  String get ttsTimerOff => 'Off';

  @override
  String ttsTimerMinutes(int mins) {
    return '${mins}m';
  }

  @override
  String get ttsTimerChapterEnd => 'Chapter End';

  @override
  String get ttsEngineLabel => 'Engine';

  @override
  String get ttsSystemDefaultEngine => 'System Default';

  @override
  String get ttsLanguageLabel => 'Language';

  @override
  String get ttsLangSystem => 'Follow System';

  @override
  String get ttsLangZhCn => 'Chinese (Mandarin)';

  @override
  String get ttsLangZhTw => 'Chinese (Taiwan)';

  @override
  String get ttsLangZhHk => 'Chinese (Cantonese)';

  @override
  String get ttsLangEnUs => 'English (US)';

  @override
  String get ttsLangJaJp => 'Japanese';

  @override
  String get ttsVoiceLabel => 'Voice';

  @override
  String get ttsVoiceDefault => 'Engine Default';

  @override
  String get ttsVoiceOffline => 'Offline';

  @override
  String get ttsVoiceNetwork => 'Network';

  @override
  String get ttsRefreshEngines => 'Refresh Engines';

  @override
  String get ttsPreviewBtn => 'Preview';

  @override
  String get ttsStopPreviewBtn => 'Stop Preview';

  @override
  String get ttsOpenSystemSettings => 'System TTS Settings';

  @override
  String get ttsNewProfile => 'New Profile';

  @override
  String get ttsEditProfile => 'Edit Profile';

  @override
  String get ttsDeleteProfile => 'Delete';

  @override
  String get ttsImportLegado => 'Import Legado JSON';

  @override
  String get ttsProviderEdge => 'Microsoft Read Aloud (Edge)';

  @override
  String get ttsProviderAzure => 'Azure Speech TTS';

  @override
  String get ttsProviderOpenAi => 'OpenAI Compatible';

  @override
  String get ttsProviderCustomHttp => 'Custom HTTP';

  @override
  String get ttsEdgeGatewayProtocolLabel => 'Gateway protocol';

  @override
  String get ttsEdgeGatewayGet => 'GET Query (tts-server)';

  @override
  String get ttsEdgeGatewayRaSsml => 'SSML POST (ms-ra-forwarder)';

  @override
  String get ttsAzureRegionLabel => 'Region (e.g. eastus)';

  @override
  String get ttsCacheSettingsTitle => 'Cache & Prefetch';

  @override
  String get ttsCacheEnableLabel => 'Enable audio cache';

  @override
  String get ttsCacheMaxMbLabel => 'Cache limit';

  @override
  String get ttsPrefetchCountLabel => 'Prefetch sentences';

  @override
  String get ttsPrefetchOff => 'Off';

  @override
  String ttsPrefetchUnit(int count) {
    return '$count';
  }

  @override
  String get readAloudLabel => 'Read aloud';

  @override
  String get webdavDeviceNameLabel => 'Device name';

  @override
  String get readerLocalFileUnavailable => 'Local file is unavailable';

  @override
  String get readerBodyTitle => 'Main text';

  @override
  String get readerPrefaceTitle => 'Preface';

  @override
  String readerLocalFileMissing(String path) {
    return 'The local book file $path could not be found. Import it again.';
  }

  @override
  String readerCoreUnavailable(String format) {
    return 'The local parser is unavailable and cannot read $format files.';
  }

  @override
  String tocRulesImported(int count) {
    return 'Imported $count table of contents rules';
  }

  @override
  String get tocRulesNotFound => 'No table of contents rules to import';

  @override
  String get tocRuleInvalidRegex => 'Invalid regular expression';

  @override
  String get tocRuleEmptyRegex => 'Enter a regular expression';

  @override
  String get tocRuleMissingName => 'Enter a rule name';

  @override
  String get tocRuleExampleLabel => 'Example';

  @override
  String get tocRuleSampleText =>
      'Prologue The Snow\nIt snowed all night.\nChapter 1 Awakening\nA quiet valley.\nChapter 2 The Crossing\nThe trail led west.';

  @override
  String tocRuleTestMatches(int count) {
    return 'Matching chapter titles ($count)';
  }

  @override
  String get tapZoneSectionLabel => 'Tap zones (tap cells to customize)';

  @override
  String get tapActionPrev => 'Prev';

  @override
  String get tapActionNext => 'Next';

  @override
  String get tapActionMenu => 'Menu';

  @override
  String get tapActionBookmark => 'Bookmark';

  @override
  String get tapActionTts => 'Listen';

  @override
  String get autoScrollSpeedLabel => 'Scroll speed';

  @override
  String get ttsProfileNameLabel => 'Profile Name';

  @override
  String get ttsEdgeModeLabel => 'Connection';

  @override
  String get ttsEdgeDirect => 'Direct (Beta)';

  @override
  String get ttsEdgeGateway => 'Custom Gateway';

  @override
  String get ttsEndpointLabel => 'Endpoint URL';

  @override
  String get ttsApiKeyLabel => 'API Key (Encrypted)';

  @override
  String get ttsApiKeyHint => 'Optional for local endpoints';

  @override
  String get ttsModelLabel => 'Model';

  @override
  String get ttsVoiceIdLabel => 'Voice ID';

  @override
  String get ttsFormatLabel => 'Audio Format';

  @override
  String get ttsHttpMethodLabel => 'Method';

  @override
  String get ttsHeadersJsonLabel => 'Headers (JSON)';

  @override
  String get ttsBodyTemplateLabel => 'Body Template';

  @override
  String get ttsTemplateHint =>
      'Tokens: {{text}} {{textEncoded}} {{voice}} {{rate}} {{ratePct}} {{pitch}} {{speakSpeed}}';

  @override
  String get ttsTestAndPreview => 'Test & Preview';

  @override
  String get ttsTestingConnection => 'Testing...';

  @override
  String ttsTestConnected(int ms) {
    return 'Connected · $ms ms';
  }

  @override
  String ttsTestFailed(String detail) {
    return 'Failed: $detail';
  }

  @override
  String get ttsFallbackLocalLabel => 'Fallback to System TTS on failure';

  @override
  String ttsClearCacheLabel(String size) {
    return 'Clear Audio Cache ($size)';
  }

  @override
  String get ttsCacheClearedToast => 'Cleared online TTS cache';

  @override
  String ttsPlayingStatus(String label, String rate) {
    return '$label · ${rate}x';
  }

  @override
  String get ttsOnlineFallbackNotice =>
      'Online TTS unavailable; switched to System TTS';

  @override
  String get ttsPrevSentence => 'Prev';

  @override
  String get ttsNextSentence => 'Next';

  @override
  String get ttsPause => 'Pause';

  @override
  String get ttsResume => 'Resume';

  @override
  String get ttsStop => 'Stop';

  @override
  String get ttsStoppedToast => 'TTS stopped';

  @override
  String get ttsStartedToast => 'TTS started';

  @override
  String get ttsUnavailableToast => 'No readable text or TTS unavailable';

  @override
  String get ttsTimerExpiredToast => 'Sleep timer expired';

  @override
  String get ttsSleepChapterDoneToast => 'Chapter ended; sleep timer stopped';

  @override
  String get tocRulesTitle => 'TXT TOC Rules';

  @override
  String get newRuleTooltip => 'New Rule';

  @override
  String get moreActionsTooltip => 'More';

  @override
  String get importRuleFile => 'Import File';

  @override
  String get pasteJsonImport => 'Paste JSON';

  @override
  String get noTocRules => 'No TOC rules';

  @override
  String get restoreDefaultRules => 'Restore Defaults';

  @override
  String get customBadge => 'Custom';

  @override
  String examplePrefix(String example) {
    return 'Example: $example';
  }

  @override
  String get editTestBtn => 'Edit / Test';

  @override
  String get ruleNameLabel => 'Rule Name';

  @override
  String get regexLabel => 'Regex';

  @override
  String get sampleTextLabel => 'Sample Text';

  @override
  String get liveTestBtn => 'Test Match';

  @override
  String get deleteRuleTitle => 'Delete Rule';

  @override
  String deleteRuleConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get tocActionsTitle => 'Rule Actions';

  @override
  String get exportToClipboard => 'Export JSON';

  @override
  String get restoreBuiltinRules => 'Restore Built-in Rules';

  @override
  String get pasteImportTitle => 'Paste Rules';

  @override
  String get ruleJsonOrRegexLabel => 'Legado JSON or Name::Regex';

  @override
  String get pasteFromClipboard => 'Paste Clipboard';

  @override
  String get importRulesBtn => 'Import';

  @override
  String get newRuleTitle => 'New Rule';

  @override
  String get editRuleTitle => 'Edit Rule';

  @override
  String get webdavTitle => 'WebDAV Sync';

  @override
  String get webdavConfigureTooltip => 'Configure';

  @override
  String get webdavCenterTitle => 'WebDAV Sync';

  @override
  String get webdavOnline => 'Online';

  @override
  String get webdavOffline => 'Offline';

  @override
  String get webdavSyncNow => 'Sync Now';

  @override
  String get webdavSyncing => 'Syncing...';

  @override
  String get webdavCreateBackup => 'Backup';

  @override
  String get webdavSyncScope => 'Sync Scope';

  @override
  String get webdavScopeProgress => 'Progress & Bookmarks';

  @override
  String get webdavScopeProgressDesc => 'Sync reading progress across devices';

  @override
  String get webdavScopeMeta => 'Shelves & Highlights';

  @override
  String get webdavScopeMetaDesc => 'Sync shelf groups and annotations';

  @override
  String get webdavScopePrefs => 'Layout & Theme';

  @override
  String get webdavScopePrefsDesc => 'Reader typography and appearance';

  @override
  String get webdavScopeSourceFiles => 'Source Files';

  @override
  String get webdavScopeSourceFilesDesc => 'Upload book and manga files';

  @override
  String get webdavPresetsTitle => 'Server Presets';

  @override
  String get webdavBackupsTitle => 'Backups';

  @override
  String get webdavNoBackups => 'No backups yet';

  @override
  String get webdavRestoreBtn => 'Restore';

  @override
  String webdavConfigTitle(String preset) {
    return 'Configure $preset';
  }

  @override
  String get webdavServerUrlLabel => 'Server URL';

  @override
  String get webdavUserLabel => 'Username';

  @override
  String get webdavPassLabel => 'App Password';

  @override
  String get webdavRootLabel => 'Remote Folder';

  @override
  String get webdavSaveAndTest => 'Save & Test';

  @override
  String get webdavConflictTitle => 'Sync Conflict';

  @override
  String webdavConflictSubtitle(String title) {
    return 'Choose progress to keep for \"$title\":';
  }

  @override
  String webdavRemoteLabel(String device) {
    return 'Cloud ($device)';
  }

  @override
  String webdavLocalLabel(String device) {
    return 'Local ($device)';
  }

  @override
  String get webdavKeepLocal => 'Keep Local';

  @override
  String get webdavAdoptRemote => 'Use Cloud';

  @override
  String get webdavSyncDone => 'Sync complete';

  @override
  String webdavSnapSummary(String preset, int count) {
    return '$preset · Connected ($count backups)';
  }

  @override
  String get webdavTestPassed => 'Connected';

  @override
  String webdavTestFailed(String error) {
    return 'Connection failed: $error';
  }

  @override
  String get errFileNotFound => 'File not found';

  @override
  String get errFileEmpty => 'File is empty (0 bytes)';

  @override
  String get errStreamOpen =>
      'Unable to read file stream. Check storage permissions.';

  @override
  String get errUnsupportedType => 'Unsupported file type';

  @override
  String get errTtsUnavailable =>
      'System TTS unavailable. Check installed voice packs.';

  @override
  String get errTtsTimeout => 'TTS engine initialization timed out';

  @override
  String get errTtsSpeakFailed => 'TTS speech playback failed';

  @override
  String get errEdge403 =>
      'Edge direct auth rejected (403). Switch to a gateway or System TTS.';

  @override
  String get errNetworkTimeout => 'Network request timed out';

  @override
  String get errHttp401 => 'Unauthorized (401). Check your API key.';

  @override
  String get errHttp403 => 'Access forbidden (403)';

  @override
  String get errHttpStatus => 'Server returned an error status';

  @override
  String get errInvalidAudio => 'Server did not return valid audio';

  @override
  String get errInvalidJson => 'Invalid JSON format';

  @override
  String get errUnknown => 'Operation failed';

  @override
  String get androidImportStorageHint =>
      'Books and comics are copied into the working folder. You can scan any folder you authorize.';

  @override
  String folderScanFailed(String error) {
    return 'Folder scan failed: $error';
  }

  @override
  String get historyBooks => 'Books';

  @override
  String get historyComics => 'Comics';

  @override
  String get themeInkWash => 'Ink Wash';

  @override
  String get localBackupTitle => 'Local Backup';

  @override
  String get localBackupSummary => 'Export or import a library ZIP';

  @override
  String get localBackupDescription =>
      'Backups include available book and comic files, shelves, import history, reading progress, bookmarks, notes, and chapter rules. Import merges libraries and skips books and comics already present.';

  @override
  String get localBackupExport => 'Export Backup';

  @override
  String get localBackupImport => 'Import Backup';

  @override
  String get localBackupExported => 'Local backup exported';

  @override
  String localBackupImported(int books, int comics, int skipped) {
    return 'Restored $books books and $comics comics. Skipped $skipped duplicates.';
  }

  @override
  String localBackupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String get workingDirectoryTitle => 'Working Folder';

  @override
  String get workingDirectoryChoose => 'Choose where to store books and comics';

  @override
  String get errWorkDirectory =>
      'Choose a working folder with read and write access';
}
