// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'InkBox';

  @override
  String get navBooks => '本棚';

  @override
  String get navManga => 'マンガ';

  @override
  String get navImport => '取込';

  @override
  String get navMe => '設定';

  @override
  String get cancel => 'キャンセル';

  @override
  String get confirm => '確定';

  @override
  String get save => '保存';

  @override
  String get create => '作成';

  @override
  String get delete => '削除';

  @override
  String get confirmDelete => '削除する';

  @override
  String get edit => '編集';

  @override
  String get rename => '名前変更';

  @override
  String get close => '閉じる';

  @override
  String get reset => 'リセット';

  @override
  String get search => '検索';

  @override
  String get refresh => '更新';

  @override
  String get copy => 'コピー';

  @override
  String get restore => '復元';

  @override
  String get open => '開く';

  @override
  String get retry => '再試行';

  @override
  String get clear => 'クリア';

  @override
  String get details => '詳細';

  @override
  String get none => 'なし';

  @override
  String get loading => '読み込み中...';

  @override
  String get shelfGroupAll => 'すべて';

  @override
  String get shelfGroupReading => '読書中';

  @override
  String get shelfGroupFinished => '読了';

  @override
  String get defaultBookshelf => '標準本棚';

  @override
  String get defaultMangaShelf => '標準マンガ棚';

  @override
  String get unknownAuthor => '著者不明';

  @override
  String get readyToRead => '読書準備完了';

  @override
  String shelvesCountBadge(int count) {
    return '$count';
  }

  @override
  String selectedCountBooks(int count) {
    return '$count 冊選択中';
  }

  @override
  String selectedCountManga(int count) {
    return '$count 作品選択中';
  }

  @override
  String get sortBy => '並び替え';

  @override
  String get sortLastRead => '最近の読書順';

  @override
  String get sortAddedAt => '追加日時順';

  @override
  String get sortTitle => 'タイトル順';

  @override
  String get sortProgress => '進捗順';

  @override
  String get gridView => 'グリッド表示';

  @override
  String get listView => 'リスト表示';

  @override
  String get searchBooks => '書籍を検索';

  @override
  String get searchBooksHint => 'タイトルまたは著者で検索...';

  @override
  String get searchManga => 'マンガを検索';

  @override
  String get searchMangaHint => 'タイトルまたは著者で検索...';

  @override
  String get continueReading => '続きを読む';

  @override
  String get emptyLibraryBooks => '本棚は空です。最初の本を取り込みましょう';

  @override
  String emptyShelfBooks(String shelfName) {
    return '「$shelfName」に書籍がありません';
  }

  @override
  String get emptyGroupBooks => '該当する書籍がありません';

  @override
  String get importLocalBooks => '書籍を取り込む';

  @override
  String get switchOtherShelf => '本棚を切替';

  @override
  String get emptyLibraryManga => 'マンガ棚は空です。取込から追加してください';

  @override
  String emptyShelfManga(String shelfName) {
    return '「$shelfName」にマンガがありません';
  }

  @override
  String get emptyGroupManga => '該当するマンガがありません';

  @override
  String get importLocalManga => 'マンガを取り込む';

  @override
  String bookshelfLoadError(String error) {
    return '本棚の読み込みに失敗しました: $error';
  }

  @override
  String mangaShelfLoadError(String error) {
    return 'マンガ棚の読み込みに失敗しました: $error';
  }

  @override
  String get moveShelf => '棚移動';

  @override
  String get markFinished => '読了にする';

  @override
  String get markReading => '読書中にする';

  @override
  String get removeBooks => '削除';

  @override
  String get markAllRead => '既読にする';

  @override
  String get resetUnread => '未読に戻す';

  @override
  String get removeManga => '削除';

  @override
  String moveBookSuccess(int count, String target) {
    return '$count 冊を「$target」に移動しました';
  }

  @override
  String moveMangaSuccess(int count, String target) {
    return '$count 作品を「$target」に移動しました';
  }

  @override
  String removeBooksTitle(int count) {
    return '選択した $count 冊を削除';
  }

  @override
  String removeMangaTitle(int count) {
    return '選択した $count 作品を削除';
  }

  @override
  String removeBookTitleSingle(String title) {
    return '『$title』を削除';
  }

  @override
  String get removeArchiveOption => '本棚から外す（履歴を保持）';

  @override
  String get removeArchiveMangaOption => 'マンガ棚から外す（履歴を保持）';

  @override
  String get removePermanentOption => '完全に削除';

  @override
  String archivedBooksToast(int count) {
    return '$count 冊を本棚から外しました';
  }

  @override
  String deletedBooksToast(int count) {
    return '$count 冊を完全に削除しました';
  }

  @override
  String get bookDetailsTitle => '書籍詳細';

  @override
  String get mangaDetailsTitle => 'マンガ詳細';

  @override
  String get notFoundBook => '書籍が見つかりません';

  @override
  String get notFoundManga => 'マンガが見つかりません';

  @override
  String get movedShelfSuccess => '本棚を変更しました';

  @override
  String get pinToShelf => '固定';

  @override
  String get unpinFromShelf => '固定解除';

  @override
  String get editMetadata => '情報編集';

  @override
  String get bookTitleLabel => '書名';

  @override
  String get authorLabel => '著者';

  @override
  String get shelfBelongsTo => '所属本棚';

  @override
  String get orCreateShelf => 'または新しい本棚を作成';

  @override
  String get readingStatusLabel => '読書状態';

  @override
  String readingMinutesShort(int mins) {
    return '$mins 分';
  }

  @override
  String readProgressShort(String pct) {
    return '進捗 $pct%';
  }

  @override
  String tocChaptersCount(int count) {
    return '目次 ($count)';
  }

  @override
  String get ascendingOrder => '昇順';

  @override
  String get descendingOrder => '降順';

  @override
  String get fullToc => '全目次';

  @override
  String expandFullToc(int count) {
    return '全 $count 章を見る';
  }

  @override
  String get noTocFound => '目次が検出されませんでした';

  @override
  String get currentReadingTag => '現在';

  @override
  String txtRuleEncodingMeta(String rule, String encoding) {
    return 'ルール: $rule · 文字コード: $encoding';
  }

  @override
  String get smartAutoDetect => '自動判定';

  @override
  String get switchTocRule => '目次ルール';

  @override
  String get switchEncoding => '文字コード';

  @override
  String get manageRuleLibrary => 'ルール一覧';

  @override
  String get selectTocRuleTitle => '目次ルールを選択';

  @override
  String get autoDetectRecommended => '自動判定（推奨）';

  @override
  String ruleUnmatchedTag(String name) {
    return '$name（未一致）';
  }

  @override
  String tocReloadedCount(int count) {
    return '目次を更新しました（$count 章）';
  }

  @override
  String tocNoMatchFallback(int count) {
    return '一致なし。$count セクションに分割しました';
  }

  @override
  String get selectEncodingTitle => '文字コードを選択';

  @override
  String get encodingAuto => '自動判定';

  @override
  String get encodingGb18030 => 'GB18030 / GBK';

  @override
  String get encodingBig5 => 'Big5';

  @override
  String encodingSwitched(String encoding) {
    return '文字コードを変更しました: $encoding';
  }

  @override
  String get annotationsTitle => 'しおり・ハイライト';

  @override
  String get noAnnotationsHint => 'しおりやメモはまだありません';

  @override
  String get bookmarkTag => 'しおり';

  @override
  String get highlightNoteTag => 'メモ';

  @override
  String get highlightTag => '線引き';

  @override
  String chapterLabelShort(int index) {
    return '第 $index 章';
  }

  @override
  String get localFileInfo => 'ローカルファイル';

  @override
  String pathLabel(String path) {
    return 'パス: $path';
  }

  @override
  String fingerprintLabel(String hash) {
    return 'ハッシュ: $hash';
  }

  @override
  String get searchChapterHint => '章を検索...';

  @override
  String get noMatchingChapters => '一致する章がありません';

  @override
  String get mangaDefaultModeLabel => '読書モード';

  @override
  String get smartCropLabel => '余白自動トリミング';

  @override
  String get splitWidePagesLabel => '見開き自動分割';

  @override
  String chaptersVolumeList(int count) {
    return '話・巻リスト ($count)';
  }

  @override
  String get unreadOnly => '未読のみ';

  @override
  String get unreadOnlyActive => '未読のみ ✓';

  @override
  String get noChaptersMatchHint => '条件に一致する話がありません';

  @override
  String get startReading => '読み始める';

  @override
  String get readLabel => '既読';

  @override
  String pageOfTotalUnknown(int current, String total) {
    return '$current/$total ページ';
  }

  @override
  String get markAllReadMenu => 'すべて既読にする';

  @override
  String get resetUnreadMenu => 'すべて未読に戻す';

  @override
  String get moveMangaShelfMenu => 'マンガ棚を移動';

  @override
  String get shelfNameExists => '同名の棚が既に存在します';

  @override
  String get shelfRenameConflict => '名前が同じか既に使用されています';

  @override
  String deleteShelfTitle(String name) {
    return '「$name」を削除';
  }

  @override
  String deleteShelfConfirm(String fallback) {
    return '作品は「$fallback」へ移動します。ローカルファイルは削除されません。';
  }

  @override
  String get createShelfTitle => '新規本棚';

  @override
  String get createMangaShelfTitle => '新規マンガ棚';

  @override
  String get renameShelfTitle => '本棚名を変更';

  @override
  String get renameMangaShelfTitle => 'マンガ棚名を変更';

  @override
  String get shelfNameLabel => '名前';

  @override
  String get newNameLabel => '新しい名前';

  @override
  String get switchBookshelfTitle => '本棚を切替';

  @override
  String get switchMangaShelfTitle => 'マンガ棚を切替';

  @override
  String get multiShelfManagerTitle => '本棚管理';

  @override
  String get bookshelfTab => '書籍';

  @override
  String get mangaShelfTab => 'マンガ';

  @override
  String get defaultShelfBadge => '標準';

  @override
  String shelfItemCountBook(int count) {
    return '$count 冊';
  }

  @override
  String shelfItemCountManga(int count) {
    return '$count 作品';
  }

  @override
  String get inUseLabel => '使用中';

  @override
  String get moveToShelfTitleBook => '本棚へ移動';

  @override
  String get moveToShelfTitleManga => 'マンガ棚へ移動';

  @override
  String get orCreateAndMoveBook => '新規作成して移動';

  @override
  String get orCreateAndMoveManga => '新規作成して移動';

  @override
  String get shelfExampleBook => '例：歴史、技術書';

  @override
  String get shelfExampleManga => '例：連載中、完結';

  @override
  String get mineTitle => '設定';

  @override
  String get appearanceSettings => '外観とテーマ';

  @override
  String get themePresets => 'テーマ';

  @override
  String get uiStyleLabel => 'レイアウト';

  @override
  String get uiStyleFloating => 'フローティングカード';

  @override
  String get uiStyleClassic => 'クラシック MD3';

  @override
  String get colorThemeLabel => 'カラー';

  @override
  String get themeCrispLight => 'クリアライト';

  @override
  String get themeDarkTheater => 'ダークシアター';

  @override
  String get themeOledBlack => 'OLED ブラック';

  @override
  String get themeFollowSystem => 'システムに従う';

  @override
  String get dynamicColorTitle => 'Material You';

  @override
  String get dynamicColorSubtitle => '壁紙のアクセント色を使用';

  @override
  String get appLanguageTitle => '言語 / Language';

  @override
  String get languageSystem => 'システムに従う';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageEn => 'English';

  @override
  String get languageJa => '日本語';

  @override
  String get statBooks => '蔵書';

  @override
  String get statReading => '読書中';

  @override
  String get statFinished => '読了';

  @override
  String get statMinutes => '分';

  @override
  String get sectionAppearanceLanguage => '外観と言語';

  @override
  String get sectionReadingSync => '読書と同期';

  @override
  String get multiShelfManagerMenu => '複数本棚の管理';

  @override
  String multiShelfSummary(int books, int manga) {
    return '本棚 $books · マンガ $manga';
  }

  @override
  String get ttsMenuTitle => 'TTS 読み上げ';

  @override
  String ttsMenuSummaryLocal(String rate) {
    return 'システム · ${rate}x';
  }

  @override
  String ttsMenuSummaryOnline(String name, String rate) {
    return 'オンライン · $name · ${rate}x';
  }

  @override
  String get tocRulesMenuTitle => 'TXT 目次ルール';

  @override
  String tocRulesMenuSummary(int enabled, int total) {
    return '$enabled / $total 有効';
  }

  @override
  String get webdavMenuTitle => 'WebDAV 同期';

  @override
  String get webdavUnconfigured => '未設定';

  @override
  String get importHubTitle => '取込センター';

  @override
  String get rescanFolders => '再スキャン';

  @override
  String get supportedFormats => '対応形式';

  @override
  String supportedFormatsBooks(String formats) {
    return '書籍：$formats';
  }

  @override
  String supportedFormatsManga(String formats) {
    return 'マンガ：$formats';
  }

  @override
  String get supportedFormatsImageFolder => '画像フォルダ';

  @override
  String get pickLocalFiles => 'ファイルを選択';

  @override
  String get addAndScanFolder => 'フォルダを選んでスキャン';

  @override
  String get importOptions => '取込オプション';

  @override
  String get smartAutoClassify => '書籍・マンガを自動振分け';

  @override
  String get overwriteDuplicates => '重複ファイルを上書き';

  @override
  String watchedFoldersTitle(int count) {
    return '監視フォルダ ($count)';
  }

  @override
  String get formatAll => 'すべて';

  @override
  String get formatComicArchive => 'マンガ';

  @override
  String importHistoryTitle(int count) {
    return '取込履歴 ($count)';
  }

  @override
  String get historyAll => 'すべて';

  @override
  String get historyArchived => 'アーカイブ';

  @override
  String get historyOnShelf => '棚に保存中';

  @override
  String get noImportHistory => '取り込み履歴はありません';

  @override
  String get noMatchingHistory => '該当する履歴がありません';

  @override
  String get fileMissingBadge => '欠落';

  @override
  String get archivedBadge => '外れ';

  @override
  String get onShelfBadge => '登録済';

  @override
  String get restoreToShelf => '戻す';

  @override
  String get readNow => '読む';

  @override
  String get permanentDeleteTitle => '完全削除';

  @override
  String permanentDeleteConfirm(String title) {
    return '『$title』を完全に削除しますか？キャッシュや履歴も消去されます。';
  }

  @override
  String deletedForeverToast(String title) {
    return '『$title』を削除しました';
  }

  @override
  String fileMissingReimportToast(String title) {
    return '『$title』が見つかりません。再取込してください';
  }

  @override
  String restoredToShelfToast(String title) {
    return '『$title』を本棚に戻しました';
  }

  @override
  String folderScanDoneToast(int count) {
    return 'スキャン完了：$count 件検出';
  }

  @override
  String importResultSummary(int books, int manga) {
    return '完了：書籍 +$books、マンガ +$manga';
  }

  @override
  String importResultSkipped(int count) {
    return '、重複 $count';
  }

  @override
  String importResultFailed(int count) {
    return '、失敗 $count';
  }

  @override
  String get viewBookshelf => '本棚へ';

  @override
  String get viewMangaShelf => 'マンガ棚へ';

  @override
  String get lastImportResultTitle => '取込結果';

  @override
  String get collapseLabel => '閉じる';

  @override
  String importedStatus(String title) {
    return '追加：『$title』';
  }

  @override
  String repairedStatus(String title) {
    return '更新：『$title』';
  }

  @override
  String duplicateStatus(String title) {
    return '重複：『$title』';
  }

  @override
  String get overwriteReimport => '上書き';

  @override
  String overwriteSuccessToast(String title) {
    return '『$title』を上書きしました';
  }

  @override
  String overwriteFailedToast(String error) {
    return '上書き失敗: $error';
  }

  @override
  String selectedCandidatesCount(int count) {
    return '$count 件選択';
  }

  @override
  String importToShelfCount(int count) {
    return '取込 ($count)';
  }

  @override
  String get switchToBook => '書籍へ';

  @override
  String get switchToComic => 'マンガへ';

  @override
  String get classifiedAsBook => '本棚';

  @override
  String get classifiedAsComic => 'マンガ棚';

  @override
  String historyBookSubtitle(String author, int pct) {
    return '$author · $pct%';
  }

  @override
  String historyMangaSubtitle(String author, int chapters) {
    return '$author · $chapters 話';
  }

  @override
  String get emptyChapterPlaceholder => '（この章には本文がありません）';

  @override
  String get firstPageToast => '最初のページです';

  @override
  String get lastPageToast => '最後のページです';

  @override
  String get chapterFinishedToast => 'この話を読み終えました';

  @override
  String get bookmarkAddedToast => 'しおりを追加しました';

  @override
  String get bookmarkRemovedToast => 'しおりを解除しました';

  @override
  String get addBookmarkTooltip => 'しおりを追加';

  @override
  String get removeBookmarkTooltip => 'しおりを解除';

  @override
  String get highlightNotesTooltip => 'ハイライト';

  @override
  String get ttsListenTooltip => '音声読み上げ';

  @override
  String get originalPdf => '原本 PDF';

  @override
  String get textReflow => 'リフロー';

  @override
  String get prevChapter => '前の章';

  @override
  String get nextChapter => '次の章';

  @override
  String get readerTabToc => '目次';

  @override
  String get readerTabDark => 'ダーク';

  @override
  String get readerTabLight => 'ライト';

  @override
  String get readerTabStyle => '体裁';

  @override
  String get readerTabTurn => 'めくり';

  @override
  String get readerTabMore => 'その他';

  @override
  String get paperWhite => 'ホワイト';

  @override
  String get paperIvory => 'アイボリー';

  @override
  String get paperSage => '若草';

  @override
  String get paperDark => 'ダーク';

  @override
  String get paperOled => '有機EL黒';

  @override
  String get turnSimulation => 'カール';

  @override
  String get turnCover => 'カバー';

  @override
  String get turnSlide => 'スライド';

  @override
  String get turnScroll => 'スクロール';

  @override
  String get layoutModeLabel => '見開き';

  @override
  String get layoutAuto => '自動';

  @override
  String get layoutSingle => '単ページ';

  @override
  String get layoutDual => '見開き固定';

  @override
  String get fontSizeLabel => '文字サイズ';

  @override
  String get lineHeightLabel => '行間';

  @override
  String get paragraphSpacingLabel => '段落間隔';

  @override
  String get firstLineIndentLabel => '字下げ';

  @override
  String get chineseOriginal => '原文';

  @override
  String get chineseTrad => '繁体字';

  @override
  String get chineseSimp => '簡体字';

  @override
  String get tapZoneLabel => 'タップ領域';

  @override
  String get tapZoneStandard => '標準左右';

  @override
  String get tapZoneLeftHand => '左手用';

  @override
  String get tapZoneRightHand => '右手用';

  @override
  String get tapZoneCustom => 'カスタム';

  @override
  String get autoScrollLabel => '自動スクロール';

  @override
  String get startAutoScroll => '開始';

  @override
  String get stopAutoScroll => '停止';

  @override
  String get autoScrollReachedEnd => '末尾に到達しました';

  @override
  String get volumeKeyPaging => '音量キーでページ送り';

  @override
  String get keepScreenOn => '画面を常時点灯';

  @override
  String get edgeBrightnessGesture => '端スワイプで明るさ調整';

  @override
  String brightnessIndicator(int pct) {
    return '明るさ $pct%';
  }

  @override
  String get ttsSettingsBtn => 'TTS 設定';

  @override
  String get purificationBtn => '本文置換';

  @override
  String get exportNotesBtn => 'ノート書出';

  @override
  String exportNotesSuccess(int count) {
    return '$count 件のノートをコピーしました';
  }

  @override
  String get purificationDialogTitle => '本文置換ルールを追加';

  @override
  String get purificationPatternLabel => '対象テキストまたは正規表現';

  @override
  String get purificationPatternHint => '例：広告テキスト.*';

  @override
  String get purificationReplacementLabel => '置換後（空欄で削除）';

  @override
  String get purificationReplacementHint => '空欄の場合は削除';

  @override
  String get addAndApply => '適用';

  @override
  String get highlightAction => '線引き';

  @override
  String get writeNoteAction => 'メモ';

  @override
  String get editNoteAction => 'メモ編集';

  @override
  String get deleteHighlightAction => '削除';

  @override
  String get highlightSavedToast => 'ハイライトを保存しました';

  @override
  String get noteSavedToast => 'メモを保存しました';

  @override
  String get highlightDeletedToast => 'ハイライトを削除しました';

  @override
  String get copiedToast => 'コピーしました';

  @override
  String get addNoteTitle => 'メモを追加';

  @override
  String get editNoteTitle => 'メモを編集';

  @override
  String get yourNoteLabel => 'メモ内容';

  @override
  String get yourNoteHint => '感想やメモを入力...';

  @override
  String get saveHighlightNote => '保存';

  @override
  String get pdfBitmapNoHighlightToast => 'リフローモードに切り替えるとハイライトできます';

  @override
  String get noHighlightableTextToast => 'ハイライト可能なテキストがありません';

  @override
  String get pdfUnsupportedPlatform => 'リフローモードに切り替えてご覧ください';

  @override
  String scrollModeLabel(int cur, int total) {
    return '第 $cur/$total 章 · スクロール';
  }

  @override
  String tocTabTitle(int count) {
    return '目次 ($count)';
  }

  @override
  String annotationsTabTitle(int count) {
    return 'しおり/メモ ($count)';
  }

  @override
  String get noAnnotationsReaderHint => 'しおりやハイライトはありません';

  @override
  String get endOfChapterHint => '本章終了';

  @override
  String nextChapterHint(String title) {
    return '次の章：$title';
  }

  @override
  String notePrefix(String note) {
    return 'メモ：$note';
  }

  @override
  String get mangaReadingModeRtl => '右から左';

  @override
  String get mangaReadingModeLtr => '左から右';

  @override
  String get mangaReadingModeWebtoon => '縦スクロール';

  @override
  String get mangaReadingModeDual => '見開き表示';

  @override
  String get mangaScaleFitScreen => '画面に合わせる';

  @override
  String get mangaScaleFitWidth => '幅に合わせる';

  @override
  String get mangaScaleFitHeight => '高さに合わせる';

  @override
  String get mangaScaleOriginal => '原寸';

  @override
  String get mangaTapLShaped => 'L字型';

  @override
  String get mangaTapEdge => '左右端';

  @override
  String get mangaTapKindle => 'Kindle風';

  @override
  String get mangaTapDisabled => 'スワイプのみ';

  @override
  String get mangaBgBlack => '黒';

  @override
  String get mangaBgDarkGrey => '濃灰';

  @override
  String get mangaBgCoolGrey => 'クール灰';

  @override
  String get mangaBgWhite => '白';

  @override
  String get mangaTabMode => '表示';

  @override
  String get mangaTabFilter => '画質';

  @override
  String get mangaTabGeneral => '一般';

  @override
  String get mangaAutoDualLandscape => '横向きで自動見開き';

  @override
  String get mangaCoverAlone => '表紙を単独ページに';

  @override
  String get mangaAutoCrop => '余白自動トリミング';

  @override
  String get mangaWarmFilter => '暖色フィルター';

  @override
  String get mangaGrayscaleFilter => 'モノクロ強調';

  @override
  String get mangaDimmerLabel => '輝度ダウン';

  @override
  String get mangaCanvasBgLabel => '背景色';

  @override
  String get mangaTapLayoutLabel => 'タップ領域';

  @override
  String get mangaShowPageBadge => 'ページ番号を表示';

  @override
  String get mangaNoImagesInChapter => '画像が見つかりません';

  @override
  String get mangaDecodeFailed => '画像の読み込みに失敗しました';

  @override
  String get mangaToggleCropTooltip => '余白切取';

  @override
  String get mangaToggleSettingsTooltip => '設定';

  @override
  String get ttsSettingsTitle => 'TTS 読み上げ設定';

  @override
  String get ttsResetToast => 'TTS 設定をリセットしました';

  @override
  String get ttsModeLocal => 'システム TTS';

  @override
  String get ttsModeOnline => 'オンライン TTS';

  @override
  String get ttsSpeechRate => '速度';

  @override
  String get ttsSpeechPitch => '音程';

  @override
  String get ttsPitchLow => '低め 0.8';

  @override
  String get ttsPitchNormal => '標準 1.0';

  @override
  String get ttsPitchHigh => '高め 1.2';

  @override
  String get ttsAutoTurnPage => '自動で次のページへ';

  @override
  String get ttsSleepTimer => 'スリープタイマー';

  @override
  String get ttsTimerOff => 'オフ';

  @override
  String ttsTimerMinutes(int mins) {
    return '$mins分';
  }

  @override
  String get ttsTimerChapterEnd => '章末で停止';

  @override
  String get ttsEngineLabel => 'エンジン';

  @override
  String get ttsSystemDefaultEngine => 'システム標準';

  @override
  String get ttsLanguageLabel => '読み上げ言語';

  @override
  String get ttsLangSystem => 'システムに従う';

  @override
  String get ttsLangZhCn => '中国語（普通話）';

  @override
  String get ttsLangZhTw => '中国語（台湾）';

  @override
  String get ttsLangZhHk => '中国語（広東語）';

  @override
  String get ttsLangEnUs => 'English (US)';

  @override
  String get ttsLangJaJp => '日本語';

  @override
  String get ttsVoiceLabel => '話者';

  @override
  String get ttsVoiceDefault => 'エンジン標準';

  @override
  String get ttsVoiceOffline => 'オフライン';

  @override
  String get ttsVoiceNetwork => 'オンライン';

  @override
  String get ttsRefreshEngines => '一覧を更新';

  @override
  String get ttsPreviewBtn => '試聴する';

  @override
  String get ttsStopPreviewBtn => '試聴を停止';

  @override
  String get ttsOpenSystemSettings => 'システムの TTS 設定を開く';

  @override
  String get ttsNewProfile => '新規追加';

  @override
  String get ttsEditProfile => '編集';

  @override
  String get ttsDeleteProfile => '削除';

  @override
  String get ttsImportLegado => 'Legado JSON 取込';

  @override
  String get ttsProviderEdge => 'Microsoft 音声読み上げ (Edge)';

  @override
  String get ttsProviderAzure => 'Azure 音声サービス';

  @override
  String get ttsProviderOpenAi => 'OpenAI 互換';

  @override
  String get ttsProviderCustomHttp => 'カスタム HTTP';

  @override
  String get ttsEdgeGatewayProtocolLabel => 'ゲートウェイ方式';

  @override
  String get ttsEdgeGatewayGet => 'GET クエリ (tts-server)';

  @override
  String get ttsEdgeGatewayRaSsml => 'SSML POST (ms-ra-forwarder)';

  @override
  String get ttsAzureRegionLabel => 'リージョン (例: japaneast)';

  @override
  String get ttsCacheSettingsTitle => 'キャッシュと先読み';

  @override
  String get ttsCacheEnableLabel => '音声キャッシュを有効化';

  @override
  String get ttsCacheMaxMbLabel => 'キャッシュ上限';

  @override
  String get ttsPrefetchCountLabel => '先読み文数';

  @override
  String get ttsPrefetchOff => 'オフ';

  @override
  String ttsPrefetchUnit(int count) {
    return '$count 文';
  }

  @override
  String get readAloudLabel => '読み上げ';

  @override
  String get webdavDeviceNameLabel => '端末名';

  @override
  String get readerLocalFileUnavailable => 'ローカルファイルを利用できません';

  @override
  String get readerBodyTitle => '本文';

  @override
  String get readerPrefaceTitle => '序文';

  @override
  String readerLocalFileMissing(String path) {
    return '書籍ファイル $path が見つかりません。再インポートしてください。';
  }

  @override
  String readerCoreUnavailable(String format) {
    return '解析エンジンを利用できないため、$format 形式を読み込めません。';
  }

  @override
  String tocRulesImported(int count) {
    return '目次ルールを $count 件インポートしました';
  }

  @override
  String get tocRulesNotFound => 'インポートできる目次ルールがありません';

  @override
  String get tocRuleInvalidRegex => '正規表現が無効です';

  @override
  String get tocRuleEmptyRegex => '正規表現を入力してください';

  @override
  String get tocRuleMissingName => 'ルール名を入力してください';

  @override
  String get tocRuleExampleLabel => '例';

  @override
  String get tocRuleSampleText =>
      '序章 雪の夜\n一晩中、雪が降った。\n第1章 目覚め\n谷は静かだった。\n第2章 渡河\n道は西へと続いていた。';

  @override
  String tocRuleTestMatches(int count) {
    return '一致した章タイトルは $count 件です';
  }

  @override
  String get tapZoneSectionLabel => 'タップ領域（セルをタップして変更）';

  @override
  String get tapActionPrev => '前へ';

  @override
  String get tapActionNext => '次へ';

  @override
  String get tapActionMenu => 'メニュー';

  @override
  String get tapActionBookmark => 'しおり';

  @override
  String get tapActionTts => '朗読';

  @override
  String get autoScrollSpeedLabel => 'スクロール速度';

  @override
  String get ttsProfileNameLabel => 'プロファイル名';

  @override
  String get ttsEdgeModeLabel => '接続方式';

  @override
  String get ttsEdgeDirect => '直接接続 (Beta)';

  @override
  String get ttsEdgeGateway => '独自ゲートウェイ';

  @override
  String get ttsEndpointLabel => 'エンドポイント URL';

  @override
  String get ttsApiKeyLabel => 'API キー（暗号化保存）';

  @override
  String get ttsApiKeyHint => 'ローカルサーバー等では空欄可';

  @override
  String get ttsModelLabel => 'モデル';

  @override
  String get ttsVoiceIdLabel => '音声 ID';

  @override
  String get ttsFormatLabel => '音声形式';

  @override
  String get ttsHttpMethodLabel => 'メソッド';

  @override
  String get ttsHeadersJsonLabel => 'Headers (JSON)';

  @override
  String get ttsBodyTemplateLabel => 'Body テンプレート';

  @override
  String get ttsTemplateHint =>
      '変数：{{text}} {{textEncoded}} {{voice}} {{rate}} {{ratePct}} {{pitch}} {{speakSpeed}}';

  @override
  String get ttsTestAndPreview => '接続テスト＆試聴';

  @override
  String get ttsTestingConnection => 'テスト中...';

  @override
  String ttsTestConnected(int ms) {
    return '接続成功 · $ms ms';
  }

  @override
  String ttsTestFailed(String detail) {
    return '接続失敗: $detail';
  }

  @override
  String get ttsFallbackLocalLabel => '失敗時にシステム TTS へ自動切替';

  @override
  String ttsClearCacheLabel(String size) {
    return '音声キャッシュを削除 ($size)';
  }

  @override
  String get ttsCacheClearedToast => 'キャッシュを削除しました';

  @override
  String ttsPlayingStatus(String label, String rate) {
    return '$label · ${rate}x';
  }

  @override
  String get ttsOnlineFallbackNotice => 'オンライン TTS が利用できないためシステム音声に切り替えました';

  @override
  String get ttsPrevSentence => '前へ';

  @override
  String get ttsNextSentence => '次へ';

  @override
  String get ttsPause => '一時停止';

  @override
  String get ttsResume => '再開';

  @override
  String get ttsStop => '停止';

  @override
  String get ttsStoppedToast => '読み上げを停止しました';

  @override
  String get ttsStartedToast => '読み上げを開始しました';

  @override
  String get ttsUnavailableToast => '読み上げ可能なテキストがありません';

  @override
  String get ttsTimerExpiredToast => 'スリープタイマーが終了しました';

  @override
  String get ttsSleepChapterDoneToast => 'この章の末尾で停止しました';

  @override
  String get tocRulesTitle => 'TXT 目次ルール';

  @override
  String get newRuleTooltip => '新規ルール';

  @override
  String get moreActionsTooltip => '操作';

  @override
  String get importRuleFile => 'ファイル取込';

  @override
  String get pasteJsonImport => 'JSON 貼付';

  @override
  String get noTocRules => 'ルールがありません';

  @override
  String get restoreDefaultRules => '標準ルールを復元';

  @override
  String get customBadge => 'カスタム';

  @override
  String examplePrefix(String example) {
    return '例: $example';
  }

  @override
  String get editTestBtn => '編集 / テスト';

  @override
  String get ruleNameLabel => 'ルール名';

  @override
  String get regexLabel => '正規表現';

  @override
  String get sampleTextLabel => 'テストテキスト';

  @override
  String get liveTestBtn => 'テスト実行';

  @override
  String get deleteRuleTitle => 'ルール削除';

  @override
  String deleteRuleConfirm(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get tocActionsTitle => 'ルール操作';

  @override
  String get exportToClipboard => 'JSON をコピー';

  @override
  String get restoreBuiltinRules => '内蔵ルールを復元';

  @override
  String get pasteImportTitle => 'ルールを貼り付け';

  @override
  String get ruleJsonOrRegexLabel => 'Legado JSON または ルール名::正規表現';

  @override
  String get pasteFromClipboard => '貼り付け';

  @override
  String get importRulesBtn => '取り込む';

  @override
  String get newRuleTitle => '新規ルール';

  @override
  String get editRuleTitle => 'ルール編集';

  @override
  String get webdavTitle => 'WebDAV 同期';

  @override
  String get webdavConfigureTooltip => 'サーバー設定';

  @override
  String get webdavCenterTitle => 'WebDAV 同期';

  @override
  String get webdavOnline => '接続済';

  @override
  String get webdavOffline => '未接続';

  @override
  String get webdavSyncNow => '今すぐ同期';

  @override
  String get webdavSyncing => '同期中...';

  @override
  String get webdavCreateBackup => 'バックアップ';

  @override
  String get webdavSyncScope => '同期対象';

  @override
  String get webdavScopeProgress => '進捗・しおり';

  @override
  String get webdavScopeProgressDesc => '読書位置を端末間で同期';

  @override
  String get webdavScopeMeta => '本棚・ハイライト';

  @override
  String get webdavScopeMetaDesc => '本棚分類とメモを同期';

  @override
  String get webdavScopePrefs => '体裁・テーマ';

  @override
  String get webdavScopePrefsDesc => 'フォントサイズや配色設定';

  @override
  String get webdavScopeSourceFiles => '原本ファイル';

  @override
  String get webdavScopeSourceFilesDesc => '書籍・マンガ本体を同期';

  @override
  String get webdavPresetsTitle => 'プリセット';

  @override
  String get webdavBackupsTitle => 'スナップショット';

  @override
  String get webdavNoBackups => 'バックアップはありません';

  @override
  String get webdavRestoreBtn => '復元';

  @override
  String webdavConfigTitle(String preset) {
    return '$preset 設定';
  }

  @override
  String get webdavServerUrlLabel => 'サーバー URL';

  @override
  String get webdavUserLabel => 'ユーザー名';

  @override
  String get webdavPassLabel => 'アプリパスワード';

  @override
  String get webdavRootLabel => '同期フォルダ';

  @override
  String get webdavSaveAndTest => '保存してテスト';

  @override
  String get webdavConflictTitle => '進捗の競合';

  @override
  String webdavConflictSubtitle(String title) {
    return '『$title』に競合があります：';
  }

  @override
  String webdavRemoteLabel(String device) {
    return 'クラウド ($device)';
  }

  @override
  String webdavLocalLabel(String device) {
    return 'この端末 ($device)';
  }

  @override
  String get webdavKeepLocal => '端末を優先';

  @override
  String get webdavAdoptRemote => 'クラウドを採用';

  @override
  String get webdavSyncDone => '同期が完了しました';

  @override
  String webdavSnapSummary(String preset, int count) {
    return '$preset · 接続正常 ($count 件)';
  }

  @override
  String get webdavTestPassed => '接続テストに成功しました';

  @override
  String webdavTestFailed(String error) {
    return '接続に失敗しました: $error';
  }

  @override
  String get errFileNotFound => 'ファイルが見つかりません';

  @override
  String get errFileEmpty => 'ファイルが空です (0 バイト)';

  @override
  String get errStreamOpen => 'ファイルを読み込めません。権限を確認してください';

  @override
  String get errUnsupportedType => '未対応のファイル形式です';

  @override
  String get errTtsUnavailable => 'システム TTS が利用できません';

  @override
  String get errTtsTimeout => '音声エンジンの初期化がタイムアウトしました';

  @override
  String get errTtsSpeakFailed => '音声の再生に失敗しました';

  @override
  String get errEdge403 => 'Edge 直接認証が拒否されました (403)。ゲートウェイ等をご利用ください';

  @override
  String get errNetworkTimeout => '通信がタイムアウトしました';

  @override
  String get errHttp401 => '認証エラー (401)。API キーを確認してください';

  @override
  String get errHttp403 => 'アクセスが拒否されました (403)';

  @override
  String get errHttpStatus => 'サーバーエラーが返されました';

  @override
  String get errInvalidAudio => '有効な音声データが返されませんでした';

  @override
  String get errInvalidJson => 'JSON 形式が無効です';

  @override
  String get errUnknown => '処理に失敗しました';

  @override
  String get androidImportStorageHint =>
      '書籍と漫画は作業フォルダにコピーされます。アクセスを許可した任意のフォルダをスキャンできます。';

  @override
  String folderScanFailed(String error) {
    return 'フォルダのスキャンに失敗しました：$error';
  }

  @override
  String get historyBooks => '書籍';

  @override
  String get historyComics => '漫画';

  @override
  String get themeInkWash => '水墨';

  @override
  String get localBackupTitle => 'ローカルバックアップ';

  @override
  String get localBackupSummary => 'ライブラリの ZIP を書き出し・取り込み';

  @override
  String get localBackupDescription =>
      '利用可能な書籍・漫画ファイル、本棚、取り込み履歴、読書の進捗、しおり、メモ、目次ルールをバックアップします。取り込み時にライブラリを統合し、登録済みの書籍や漫画はスキップします。';

  @override
  String get localBackupExport => 'バックアップを書き出す';

  @override
  String get localBackupImport => 'バックアップを取り込む';

  @override
  String get localBackupExported => 'バックアップを書き出しました';

  @override
  String localBackupImported(int books, int comics, int skipped) {
    return '書籍 $books 冊と漫画 $comics 作品を復元し、重複 $skipped 件をスキップしました';
  }

  @override
  String localBackupFailed(String error) {
    return 'バックアップ操作に失敗しました：$error';
  }

  @override
  String get workingDirectoryTitle => '作業フォルダ';

  @override
  String get workingDirectoryChoose => '書籍と漫画の保存先を選択';

  @override
  String get errWorkDirectory => '読み書きが可能な作業フォルダを選択してください';
}
