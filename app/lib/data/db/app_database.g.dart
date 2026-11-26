// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, Book> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('未知作者'),
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shelfIdMeta = const VerificationMeta(
    'shelfId',
  );
  @override
  late final GeneratedColumn<int> shelfId = GeneratedColumn<int>(
    'shelf_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shelfGroupMeta = const VerificationMeta(
    'shelfGroup',
  );
  @override
  late final GeneratedColumn<String> shelfGroup = GeneratedColumn<String>(
    'shelf_group',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('在读'),
  );
  static const VerificationMeta _progressRatioMeta = const VerificationMeta(
    'progressRatio',
  );
  @override
  late final GeneratedColumn<double> progressRatio = GeneratedColumn<double>(
    'progress_ratio',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _currentChapterIndexMeta =
      const VerificationMeta('currentChapterIndex');
  @override
  late final GeneratedColumn<int> currentChapterIndex = GeneratedColumn<int>(
    'current_chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentCharOffsetMeta = const VerificationMeta(
    'currentCharOffset',
  );
  @override
  late final GeneratedColumn<int> currentCharOffset = GeneratedColumn<int>(
    'current_char_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentChapterTitleMeta =
      const VerificationMeta('currentChapterTitle');
  @override
  late final GeneratedColumn<String> currentChapterTitle =
      GeneratedColumn<String>(
        'current_chapter_title',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('准备阅读'),
      );
  static const VerificationMeta _readingTimeSecMeta = const VerificationMeta(
    'readingTimeSec',
  );
  @override
  late final GeneratedColumn<int> readingTimeSec = GeneratedColumn<int>(
    'reading_time_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _cloudFileSyncedMeta = const VerificationMeta(
    'cloudFileSynced',
  );
  @override
  late final GeneratedColumn<bool> cloudFileSynced = GeneratedColumn<bool>(
    'cloud_file_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("cloud_file_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _tocRuleIdMeta = const VerificationMeta(
    'tocRuleId',
  );
  @override
  late final GeneratedColumn<int> tocRuleId = GeneratedColumn<int>(
    'toc_rule_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _forcedEncodingMeta = const VerificationMeta(
    'forcedEncoding',
  );
  @override
  late final GeneratedColumn<String> forcedEncoding = GeneratedColumn<String>(
    'forced_encoding',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMsMeta = const VerificationMeta(
    'addedAtMs',
  );
  @override
  late final GeneratedColumn<int> addedAtMs = GeneratedColumn<int>(
    'added_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastReadAtMsMeta = const VerificationMeta(
    'lastReadAtMs',
  );
  @override
  late final GeneratedColumn<int> lastReadAtMs = GeneratedColumn<int>(
    'last_read_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    contentHash,
    title,
    author,
    format,
    filePath,
    coverPath,
    shelfId,
    shelfGroup,
    progressRatio,
    currentChapterIndex,
    currentCharOffset,
    currentChapterTitle,
    readingTimeSec,
    isPinned,
    cloudFileSynced,
    isArchived,
    tocRuleId,
    forcedEncoding,
    addedAtMs,
    lastReadAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<Book> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('shelf_id')) {
      context.handle(
        _shelfIdMeta,
        shelfId.isAcceptableOrUnknown(data['shelf_id']!, _shelfIdMeta),
      );
    }
    if (data.containsKey('shelf_group')) {
      context.handle(
        _shelfGroupMeta,
        shelfGroup.isAcceptableOrUnknown(data['shelf_group']!, _shelfGroupMeta),
      );
    }
    if (data.containsKey('progress_ratio')) {
      context.handle(
        _progressRatioMeta,
        progressRatio.isAcceptableOrUnknown(
          data['progress_ratio']!,
          _progressRatioMeta,
        ),
      );
    }
    if (data.containsKey('current_chapter_index')) {
      context.handle(
        _currentChapterIndexMeta,
        currentChapterIndex.isAcceptableOrUnknown(
          data['current_chapter_index']!,
          _currentChapterIndexMeta,
        ),
      );
    }
    if (data.containsKey('current_char_offset')) {
      context.handle(
        _currentCharOffsetMeta,
        currentCharOffset.isAcceptableOrUnknown(
          data['current_char_offset']!,
          _currentCharOffsetMeta,
        ),
      );
    }
    if (data.containsKey('current_chapter_title')) {
      context.handle(
        _currentChapterTitleMeta,
        currentChapterTitle.isAcceptableOrUnknown(
          data['current_chapter_title']!,
          _currentChapterTitleMeta,
        ),
      );
    }
    if (data.containsKey('reading_time_sec')) {
      context.handle(
        _readingTimeSecMeta,
        readingTimeSec.isAcceptableOrUnknown(
          data['reading_time_sec']!,
          _readingTimeSecMeta,
        ),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('cloud_file_synced')) {
      context.handle(
        _cloudFileSyncedMeta,
        cloudFileSynced.isAcceptableOrUnknown(
          data['cloud_file_synced']!,
          _cloudFileSyncedMeta,
        ),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('toc_rule_id')) {
      context.handle(
        _tocRuleIdMeta,
        tocRuleId.isAcceptableOrUnknown(data['toc_rule_id']!, _tocRuleIdMeta),
      );
    }
    if (data.containsKey('forced_encoding')) {
      context.handle(
        _forcedEncodingMeta,
        forcedEncoding.isAcceptableOrUnknown(
          data['forced_encoding']!,
          _forcedEncodingMeta,
        ),
      );
    }
    if (data.containsKey('added_at_ms')) {
      context.handle(
        _addedAtMsMeta,
        addedAtMs.isAcceptableOrUnknown(data['added_at_ms']!, _addedAtMsMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMsMeta);
    }
    if (data.containsKey('last_read_at_ms')) {
      context.handle(
        _lastReadAtMsMeta,
        lastReadAtMs.isAcceptableOrUnknown(
          data['last_read_at_ms']!,
          _lastReadAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastReadAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Book map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Book(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      shelfId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shelf_id'],
      ),
      shelfGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shelf_group'],
      )!,
      progressRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress_ratio'],
      )!,
      currentChapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_chapter_index'],
      )!,
      currentCharOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_char_offset'],
      )!,
      currentChapterTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_chapter_title'],
      )!,
      readingTimeSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reading_time_sec'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      cloudFileSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}cloud_file_synced'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      tocRuleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}toc_rule_id'],
      ),
      forcedEncoding: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}forced_encoding'],
      ),
      addedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at_ms'],
      )!,
      lastReadAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_read_at_ms'],
      )!,
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class Book extends DataClass implements Insertable<Book> {
  final int id;
  final String contentHash;
  final String title;
  final String author;
  final String format;
  final String filePath;
  final String? coverPath;
  final int? shelfId;
  final String shelfGroup;
  final double progressRatio;
  final int currentChapterIndex;
  final int currentCharOffset;
  final String currentChapterTitle;
  final int readingTimeSec;
  final bool isPinned;
  final bool cloudFileSynced;
  final bool isArchived;
  final int? tocRuleId;
  final String? forcedEncoding;
  final int addedAtMs;
  final int lastReadAtMs;
  const Book({
    required this.id,
    required this.contentHash,
    required this.title,
    required this.author,
    required this.format,
    required this.filePath,
    this.coverPath,
    this.shelfId,
    required this.shelfGroup,
    required this.progressRatio,
    required this.currentChapterIndex,
    required this.currentCharOffset,
    required this.currentChapterTitle,
    required this.readingTimeSec,
    required this.isPinned,
    required this.cloudFileSynced,
    required this.isArchived,
    this.tocRuleId,
    this.forcedEncoding,
    required this.addedAtMs,
    required this.lastReadAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['content_hash'] = Variable<String>(contentHash);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    map['format'] = Variable<String>(format);
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    if (!nullToAbsent || shelfId != null) {
      map['shelf_id'] = Variable<int>(shelfId);
    }
    map['shelf_group'] = Variable<String>(shelfGroup);
    map['progress_ratio'] = Variable<double>(progressRatio);
    map['current_chapter_index'] = Variable<int>(currentChapterIndex);
    map['current_char_offset'] = Variable<int>(currentCharOffset);
    map['current_chapter_title'] = Variable<String>(currentChapterTitle);
    map['reading_time_sec'] = Variable<int>(readingTimeSec);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['cloud_file_synced'] = Variable<bool>(cloudFileSynced);
    map['is_archived'] = Variable<bool>(isArchived);
    if (!nullToAbsent || tocRuleId != null) {
      map['toc_rule_id'] = Variable<int>(tocRuleId);
    }
    if (!nullToAbsent || forcedEncoding != null) {
      map['forced_encoding'] = Variable<String>(forcedEncoding);
    }
    map['added_at_ms'] = Variable<int>(addedAtMs);
    map['last_read_at_ms'] = Variable<int>(lastReadAtMs);
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      contentHash: Value(contentHash),
      title: Value(title),
      author: Value(author),
      format: Value(format),
      filePath: Value(filePath),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      shelfId: shelfId == null && nullToAbsent
          ? const Value.absent()
          : Value(shelfId),
      shelfGroup: Value(shelfGroup),
      progressRatio: Value(progressRatio),
      currentChapterIndex: Value(currentChapterIndex),
      currentCharOffset: Value(currentCharOffset),
      currentChapterTitle: Value(currentChapterTitle),
      readingTimeSec: Value(readingTimeSec),
      isPinned: Value(isPinned),
      cloudFileSynced: Value(cloudFileSynced),
      isArchived: Value(isArchived),
      tocRuleId: tocRuleId == null && nullToAbsent
          ? const Value.absent()
          : Value(tocRuleId),
      forcedEncoding: forcedEncoding == null && nullToAbsent
          ? const Value.absent()
          : Value(forcedEncoding),
      addedAtMs: Value(addedAtMs),
      lastReadAtMs: Value(lastReadAtMs),
    );
  }

  factory Book.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Book(
      id: serializer.fromJson<int>(json['id']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      format: serializer.fromJson<String>(json['format']),
      filePath: serializer.fromJson<String>(json['filePath']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      shelfId: serializer.fromJson<int?>(json['shelfId']),
      shelfGroup: serializer.fromJson<String>(json['shelfGroup']),
      progressRatio: serializer.fromJson<double>(json['progressRatio']),
      currentChapterIndex: serializer.fromJson<int>(
        json['currentChapterIndex'],
      ),
      currentCharOffset: serializer.fromJson<int>(json['currentCharOffset']),
      currentChapterTitle: serializer.fromJson<String>(
        json['currentChapterTitle'],
      ),
      readingTimeSec: serializer.fromJson<int>(json['readingTimeSec']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      cloudFileSynced: serializer.fromJson<bool>(json['cloudFileSynced']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      tocRuleId: serializer.fromJson<int?>(json['tocRuleId']),
      forcedEncoding: serializer.fromJson<String?>(json['forcedEncoding']),
      addedAtMs: serializer.fromJson<int>(json['addedAtMs']),
      lastReadAtMs: serializer.fromJson<int>(json['lastReadAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'contentHash': serializer.toJson<String>(contentHash),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'format': serializer.toJson<String>(format),
      'filePath': serializer.toJson<String>(filePath),
      'coverPath': serializer.toJson<String?>(coverPath),
      'shelfId': serializer.toJson<int?>(shelfId),
      'shelfGroup': serializer.toJson<String>(shelfGroup),
      'progressRatio': serializer.toJson<double>(progressRatio),
      'currentChapterIndex': serializer.toJson<int>(currentChapterIndex),
      'currentCharOffset': serializer.toJson<int>(currentCharOffset),
      'currentChapterTitle': serializer.toJson<String>(currentChapterTitle),
      'readingTimeSec': serializer.toJson<int>(readingTimeSec),
      'isPinned': serializer.toJson<bool>(isPinned),
      'cloudFileSynced': serializer.toJson<bool>(cloudFileSynced),
      'isArchived': serializer.toJson<bool>(isArchived),
      'tocRuleId': serializer.toJson<int?>(tocRuleId),
      'forcedEncoding': serializer.toJson<String?>(forcedEncoding),
      'addedAtMs': serializer.toJson<int>(addedAtMs),
      'lastReadAtMs': serializer.toJson<int>(lastReadAtMs),
    };
  }

  Book copyWith({
    int? id,
    String? contentHash,
    String? title,
    String? author,
    String? format,
    String? filePath,
    Value<String?> coverPath = const Value.absent(),
    Value<int?> shelfId = const Value.absent(),
    String? shelfGroup,
    double? progressRatio,
    int? currentChapterIndex,
    int? currentCharOffset,
    String? currentChapterTitle,
    int? readingTimeSec,
    bool? isPinned,
    bool? cloudFileSynced,
    bool? isArchived,
    Value<int?> tocRuleId = const Value.absent(),
    Value<String?> forcedEncoding = const Value.absent(),
    int? addedAtMs,
    int? lastReadAtMs,
  }) => Book(
    id: id ?? this.id,
    contentHash: contentHash ?? this.contentHash,
    title: title ?? this.title,
    author: author ?? this.author,
    format: format ?? this.format,
    filePath: filePath ?? this.filePath,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    shelfId: shelfId.present ? shelfId.value : this.shelfId,
    shelfGroup: shelfGroup ?? this.shelfGroup,
    progressRatio: progressRatio ?? this.progressRatio,
    currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
    currentCharOffset: currentCharOffset ?? this.currentCharOffset,
    currentChapterTitle: currentChapterTitle ?? this.currentChapterTitle,
    readingTimeSec: readingTimeSec ?? this.readingTimeSec,
    isPinned: isPinned ?? this.isPinned,
    cloudFileSynced: cloudFileSynced ?? this.cloudFileSynced,
    isArchived: isArchived ?? this.isArchived,
    tocRuleId: tocRuleId.present ? tocRuleId.value : this.tocRuleId,
    forcedEncoding: forcedEncoding.present
        ? forcedEncoding.value
        : this.forcedEncoding,
    addedAtMs: addedAtMs ?? this.addedAtMs,
    lastReadAtMs: lastReadAtMs ?? this.lastReadAtMs,
  );
  Book copyWithCompanion(BooksCompanion data) {
    return Book(
      id: data.id.present ? data.id.value : this.id,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      format: data.format.present ? data.format.value : this.format,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      shelfId: data.shelfId.present ? data.shelfId.value : this.shelfId,
      shelfGroup: data.shelfGroup.present
          ? data.shelfGroup.value
          : this.shelfGroup,
      progressRatio: data.progressRatio.present
          ? data.progressRatio.value
          : this.progressRatio,
      currentChapterIndex: data.currentChapterIndex.present
          ? data.currentChapterIndex.value
          : this.currentChapterIndex,
      currentCharOffset: data.currentCharOffset.present
          ? data.currentCharOffset.value
          : this.currentCharOffset,
      currentChapterTitle: data.currentChapterTitle.present
          ? data.currentChapterTitle.value
          : this.currentChapterTitle,
      readingTimeSec: data.readingTimeSec.present
          ? data.readingTimeSec.value
          : this.readingTimeSec,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      cloudFileSynced: data.cloudFileSynced.present
          ? data.cloudFileSynced.value
          : this.cloudFileSynced,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      tocRuleId: data.tocRuleId.present ? data.tocRuleId.value : this.tocRuleId,
      forcedEncoding: data.forcedEncoding.present
          ? data.forcedEncoding.value
          : this.forcedEncoding,
      addedAtMs: data.addedAtMs.present ? data.addedAtMs.value : this.addedAtMs,
      lastReadAtMs: data.lastReadAtMs.present
          ? data.lastReadAtMs.value
          : this.lastReadAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('id: $id, ')
          ..write('contentHash: $contentHash, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('format: $format, ')
          ..write('filePath: $filePath, ')
          ..write('coverPath: $coverPath, ')
          ..write('shelfId: $shelfId, ')
          ..write('shelfGroup: $shelfGroup, ')
          ..write('progressRatio: $progressRatio, ')
          ..write('currentChapterIndex: $currentChapterIndex, ')
          ..write('currentCharOffset: $currentCharOffset, ')
          ..write('currentChapterTitle: $currentChapterTitle, ')
          ..write('readingTimeSec: $readingTimeSec, ')
          ..write('isPinned: $isPinned, ')
          ..write('cloudFileSynced: $cloudFileSynced, ')
          ..write('isArchived: $isArchived, ')
          ..write('tocRuleId: $tocRuleId, ')
          ..write('forcedEncoding: $forcedEncoding, ')
          ..write('addedAtMs: $addedAtMs, ')
          ..write('lastReadAtMs: $lastReadAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    contentHash,
    title,
    author,
    format,
    filePath,
    coverPath,
    shelfId,
    shelfGroup,
    progressRatio,
    currentChapterIndex,
    currentCharOffset,
    currentChapterTitle,
    readingTimeSec,
    isPinned,
    cloudFileSynced,
    isArchived,
    tocRuleId,
    forcedEncoding,
    addedAtMs,
    lastReadAtMs,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.id == this.id &&
          other.contentHash == this.contentHash &&
          other.title == this.title &&
          other.author == this.author &&
          other.format == this.format &&
          other.filePath == this.filePath &&
          other.coverPath == this.coverPath &&
          other.shelfId == this.shelfId &&
          other.shelfGroup == this.shelfGroup &&
          other.progressRatio == this.progressRatio &&
          other.currentChapterIndex == this.currentChapterIndex &&
          other.currentCharOffset == this.currentCharOffset &&
          other.currentChapterTitle == this.currentChapterTitle &&
          other.readingTimeSec == this.readingTimeSec &&
          other.isPinned == this.isPinned &&
          other.cloudFileSynced == this.cloudFileSynced &&
          other.isArchived == this.isArchived &&
          other.tocRuleId == this.tocRuleId &&
          other.forcedEncoding == this.forcedEncoding &&
          other.addedAtMs == this.addedAtMs &&
          other.lastReadAtMs == this.lastReadAtMs);
}

class BooksCompanion extends UpdateCompanion<Book> {
  final Value<int> id;
  final Value<String> contentHash;
  final Value<String> title;
  final Value<String> author;
  final Value<String> format;
  final Value<String> filePath;
  final Value<String?> coverPath;
  final Value<int?> shelfId;
  final Value<String> shelfGroup;
  final Value<double> progressRatio;
  final Value<int> currentChapterIndex;
  final Value<int> currentCharOffset;
  final Value<String> currentChapterTitle;
  final Value<int> readingTimeSec;
  final Value<bool> isPinned;
  final Value<bool> cloudFileSynced;
  final Value<bool> isArchived;
  final Value<int?> tocRuleId;
  final Value<String?> forcedEncoding;
  final Value<int> addedAtMs;
  final Value<int> lastReadAtMs;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.format = const Value.absent(),
    this.filePath = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.shelfId = const Value.absent(),
    this.shelfGroup = const Value.absent(),
    this.progressRatio = const Value.absent(),
    this.currentChapterIndex = const Value.absent(),
    this.currentCharOffset = const Value.absent(),
    this.currentChapterTitle = const Value.absent(),
    this.readingTimeSec = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.cloudFileSynced = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.tocRuleId = const Value.absent(),
    this.forcedEncoding = const Value.absent(),
    this.addedAtMs = const Value.absent(),
    this.lastReadAtMs = const Value.absent(),
  });
  BooksCompanion.insert({
    this.id = const Value.absent(),
    required String contentHash,
    required String title,
    this.author = const Value.absent(),
    required String format,
    required String filePath,
    this.coverPath = const Value.absent(),
    this.shelfId = const Value.absent(),
    this.shelfGroup = const Value.absent(),
    this.progressRatio = const Value.absent(),
    this.currentChapterIndex = const Value.absent(),
    this.currentCharOffset = const Value.absent(),
    this.currentChapterTitle = const Value.absent(),
    this.readingTimeSec = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.cloudFileSynced = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.tocRuleId = const Value.absent(),
    this.forcedEncoding = const Value.absent(),
    required int addedAtMs,
    required int lastReadAtMs,
  }) : contentHash = Value(contentHash),
       title = Value(title),
       format = Value(format),
       filePath = Value(filePath),
       addedAtMs = Value(addedAtMs),
       lastReadAtMs = Value(lastReadAtMs);
  static Insertable<Book> custom({
    Expression<int>? id,
    Expression<String>? contentHash,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? format,
    Expression<String>? filePath,
    Expression<String>? coverPath,
    Expression<int>? shelfId,
    Expression<String>? shelfGroup,
    Expression<double>? progressRatio,
    Expression<int>? currentChapterIndex,
    Expression<int>? currentCharOffset,
    Expression<String>? currentChapterTitle,
    Expression<int>? readingTimeSec,
    Expression<bool>? isPinned,
    Expression<bool>? cloudFileSynced,
    Expression<bool>? isArchived,
    Expression<int>? tocRuleId,
    Expression<String>? forcedEncoding,
    Expression<int>? addedAtMs,
    Expression<int>? lastReadAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (contentHash != null) 'content_hash': contentHash,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (format != null) 'format': format,
      if (filePath != null) 'file_path': filePath,
      if (coverPath != null) 'cover_path': coverPath,
      if (shelfId != null) 'shelf_id': shelfId,
      if (shelfGroup != null) 'shelf_group': shelfGroup,
      if (progressRatio != null) 'progress_ratio': progressRatio,
      if (currentChapterIndex != null)
        'current_chapter_index': currentChapterIndex,
      if (currentCharOffset != null) 'current_char_offset': currentCharOffset,
      if (currentChapterTitle != null)
        'current_chapter_title': currentChapterTitle,
      if (readingTimeSec != null) 'reading_time_sec': readingTimeSec,
      if (isPinned != null) 'is_pinned': isPinned,
      if (cloudFileSynced != null) 'cloud_file_synced': cloudFileSynced,
      if (isArchived != null) 'is_archived': isArchived,
      if (tocRuleId != null) 'toc_rule_id': tocRuleId,
      if (forcedEncoding != null) 'forced_encoding': forcedEncoding,
      if (addedAtMs != null) 'added_at_ms': addedAtMs,
      if (lastReadAtMs != null) 'last_read_at_ms': lastReadAtMs,
    });
  }

  BooksCompanion copyWith({
    Value<int>? id,
    Value<String>? contentHash,
    Value<String>? title,
    Value<String>? author,
    Value<String>? format,
    Value<String>? filePath,
    Value<String?>? coverPath,
    Value<int?>? shelfId,
    Value<String>? shelfGroup,
    Value<double>? progressRatio,
    Value<int>? currentChapterIndex,
    Value<int>? currentCharOffset,
    Value<String>? currentChapterTitle,
    Value<int>? readingTimeSec,
    Value<bool>? isPinned,
    Value<bool>? cloudFileSynced,
    Value<bool>? isArchived,
    Value<int?>? tocRuleId,
    Value<String?>? forcedEncoding,
    Value<int>? addedAtMs,
    Value<int>? lastReadAtMs,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      contentHash: contentHash ?? this.contentHash,
      title: title ?? this.title,
      author: author ?? this.author,
      format: format ?? this.format,
      filePath: filePath ?? this.filePath,
      coverPath: coverPath ?? this.coverPath,
      shelfId: shelfId ?? this.shelfId,
      shelfGroup: shelfGroup ?? this.shelfGroup,
      progressRatio: progressRatio ?? this.progressRatio,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      currentCharOffset: currentCharOffset ?? this.currentCharOffset,
      currentChapterTitle: currentChapterTitle ?? this.currentChapterTitle,
      readingTimeSec: readingTimeSec ?? this.readingTimeSec,
      isPinned: isPinned ?? this.isPinned,
      cloudFileSynced: cloudFileSynced ?? this.cloudFileSynced,
      isArchived: isArchived ?? this.isArchived,
      tocRuleId: tocRuleId ?? this.tocRuleId,
      forcedEncoding: forcedEncoding ?? this.forcedEncoding,
      addedAtMs: addedAtMs ?? this.addedAtMs,
      lastReadAtMs: lastReadAtMs ?? this.lastReadAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (shelfId.present) {
      map['shelf_id'] = Variable<int>(shelfId.value);
    }
    if (shelfGroup.present) {
      map['shelf_group'] = Variable<String>(shelfGroup.value);
    }
    if (progressRatio.present) {
      map['progress_ratio'] = Variable<double>(progressRatio.value);
    }
    if (currentChapterIndex.present) {
      map['current_chapter_index'] = Variable<int>(currentChapterIndex.value);
    }
    if (currentCharOffset.present) {
      map['current_char_offset'] = Variable<int>(currentCharOffset.value);
    }
    if (currentChapterTitle.present) {
      map['current_chapter_title'] = Variable<String>(
        currentChapterTitle.value,
      );
    }
    if (readingTimeSec.present) {
      map['reading_time_sec'] = Variable<int>(readingTimeSec.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (cloudFileSynced.present) {
      map['cloud_file_synced'] = Variable<bool>(cloudFileSynced.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (tocRuleId.present) {
      map['toc_rule_id'] = Variable<int>(tocRuleId.value);
    }
    if (forcedEncoding.present) {
      map['forced_encoding'] = Variable<String>(forcedEncoding.value);
    }
    if (addedAtMs.present) {
      map['added_at_ms'] = Variable<int>(addedAtMs.value);
    }
    if (lastReadAtMs.present) {
      map['last_read_at_ms'] = Variable<int>(lastReadAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('contentHash: $contentHash, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('format: $format, ')
          ..write('filePath: $filePath, ')
          ..write('coverPath: $coverPath, ')
          ..write('shelfId: $shelfId, ')
          ..write('shelfGroup: $shelfGroup, ')
          ..write('progressRatio: $progressRatio, ')
          ..write('currentChapterIndex: $currentChapterIndex, ')
          ..write('currentCharOffset: $currentCharOffset, ')
          ..write('currentChapterTitle: $currentChapterTitle, ')
          ..write('readingTimeSec: $readingTimeSec, ')
          ..write('isPinned: $isPinned, ')
          ..write('cloudFileSynced: $cloudFileSynced, ')
          ..write('isArchived: $isArchived, ')
          ..write('tocRuleId: $tocRuleId, ')
          ..write('forcedEncoding: $forcedEncoding, ')
          ..write('addedAtMs: $addedAtMs, ')
          ..write('lastReadAtMs: $lastReadAtMs')
          ..write(')'))
        .toString();
  }
}

class $MangasTable extends Mangas with TableInfo<$MangasTable, Manga> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MangasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('未知作者'),
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootPathMeta = const VerificationMeta(
    'rootPath',
  );
  @override
  late final GeneratedColumn<String> rootPath = GeneratedColumn<String>(
    'root_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shelfIdMeta = const VerificationMeta(
    'shelfId',
  );
  @override
  late final GeneratedColumn<int> shelfId = GeneratedColumn<int>(
    'shelf_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shelfGroupMeta = const VerificationMeta(
    'shelfGroup',
  );
  @override
  late final GeneratedColumn<String> shelfGroup = GeneratedColumn<String>(
    'shelf_group',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('在读'),
  );
  static const VerificationMeta _unreadCountMeta = const VerificationMeta(
    'unreadCount',
  );
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
    'unread_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalChaptersMeta = const VerificationMeta(
    'totalChapters',
  );
  @override
  late final GeneratedColumn<int> totalChapters = GeneratedColumn<int>(
    'total_chapters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _preferredReadingModeMeta =
      const VerificationMeta('preferredReadingMode');
  @override
  late final GeneratedColumn<String> preferredReadingMode =
      GeneratedColumn<String>(
        'preferred_reading_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('rtl'),
      );
  static const VerificationMeta _autoCropMeta = const VerificationMeta(
    'autoCrop',
  );
  @override
  late final GeneratedColumn<bool> autoCrop = GeneratedColumn<bool>(
    'auto_crop',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_crop" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _splitWidePagesMeta = const VerificationMeta(
    'splitWidePages',
  );
  @override
  late final GeneratedColumn<bool> splitWidePages = GeneratedColumn<bool>(
    'split_wide_pages',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("split_wide_pages" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _cloudFileSyncedMeta = const VerificationMeta(
    'cloudFileSynced',
  );
  @override
  late final GeneratedColumn<bool> cloudFileSynced = GeneratedColumn<bool>(
    'cloud_file_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("cloud_file_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _addedAtMsMeta = const VerificationMeta(
    'addedAtMs',
  );
  @override
  late final GeneratedColumn<int> addedAtMs = GeneratedColumn<int>(
    'added_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastReadAtMsMeta = const VerificationMeta(
    'lastReadAtMs',
  );
  @override
  late final GeneratedColumn<int> lastReadAtMs = GeneratedColumn<int>(
    'last_read_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    contentHash,
    title,
    author,
    format,
    rootPath,
    coverPath,
    shelfId,
    shelfGroup,
    unreadCount,
    totalChapters,
    preferredReadingMode,
    autoCrop,
    splitWidePages,
    isPinned,
    cloudFileSynced,
    isArchived,
    addedAtMs,
    lastReadAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mangas';
  @override
  VerificationContext validateIntegrity(
    Insertable<Manga> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('root_path')) {
      context.handle(
        _rootPathMeta,
        rootPath.isAcceptableOrUnknown(data['root_path']!, _rootPathMeta),
      );
    } else if (isInserting) {
      context.missing(_rootPathMeta);
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('shelf_id')) {
      context.handle(
        _shelfIdMeta,
        shelfId.isAcceptableOrUnknown(data['shelf_id']!, _shelfIdMeta),
      );
    }
    if (data.containsKey('shelf_group')) {
      context.handle(
        _shelfGroupMeta,
        shelfGroup.isAcceptableOrUnknown(data['shelf_group']!, _shelfGroupMeta),
      );
    }
    if (data.containsKey('unread_count')) {
      context.handle(
        _unreadCountMeta,
        unreadCount.isAcceptableOrUnknown(
          data['unread_count']!,
          _unreadCountMeta,
        ),
      );
    }
    if (data.containsKey('total_chapters')) {
      context.handle(
        _totalChaptersMeta,
        totalChapters.isAcceptableOrUnknown(
          data['total_chapters']!,
          _totalChaptersMeta,
        ),
      );
    }
    if (data.containsKey('preferred_reading_mode')) {
      context.handle(
        _preferredReadingModeMeta,
        preferredReadingMode.isAcceptableOrUnknown(
          data['preferred_reading_mode']!,
          _preferredReadingModeMeta,
        ),
      );
    }
    if (data.containsKey('auto_crop')) {
      context.handle(
        _autoCropMeta,
        autoCrop.isAcceptableOrUnknown(data['auto_crop']!, _autoCropMeta),
      );
    }
    if (data.containsKey('split_wide_pages')) {
      context.handle(
        _splitWidePagesMeta,
        splitWidePages.isAcceptableOrUnknown(
          data['split_wide_pages']!,
          _splitWidePagesMeta,
        ),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('cloud_file_synced')) {
      context.handle(
        _cloudFileSyncedMeta,
        cloudFileSynced.isAcceptableOrUnknown(
          data['cloud_file_synced']!,
          _cloudFileSyncedMeta,
        ),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('added_at_ms')) {
      context.handle(
        _addedAtMsMeta,
        addedAtMs.isAcceptableOrUnknown(data['added_at_ms']!, _addedAtMsMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMsMeta);
    }
    if (data.containsKey('last_read_at_ms')) {
      context.handle(
        _lastReadAtMsMeta,
        lastReadAtMs.isAcceptableOrUnknown(
          data['last_read_at_ms']!,
          _lastReadAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastReadAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Manga map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Manga(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      rootPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_path'],
      )!,
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      shelfId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shelf_id'],
      ),
      shelfGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shelf_group'],
      )!,
      unreadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_count'],
      )!,
      totalChapters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_chapters'],
      )!,
      preferredReadingMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_reading_mode'],
      )!,
      autoCrop: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_crop'],
      )!,
      splitWidePages: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}split_wide_pages'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      cloudFileSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}cloud_file_synced'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      addedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at_ms'],
      )!,
      lastReadAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_read_at_ms'],
      )!,
    );
  }

  @override
  $MangasTable createAlias(String alias) {
    return $MangasTable(attachedDatabase, alias);
  }
}

class Manga extends DataClass implements Insertable<Manga> {
  final int id;
  final String contentHash;
  final String title;
  final String author;
  final String format;
  final String rootPath;
  final String? coverPath;
  final int? shelfId;
  final String shelfGroup;
  final int unreadCount;
  final int totalChapters;
  final String preferredReadingMode;
  final bool autoCrop;
  final bool splitWidePages;
  final bool isPinned;
  final bool cloudFileSynced;
  final bool isArchived;
  final int addedAtMs;
  final int lastReadAtMs;
  const Manga({
    required this.id,
    required this.contentHash,
    required this.title,
    required this.author,
    required this.format,
    required this.rootPath,
    this.coverPath,
    this.shelfId,
    required this.shelfGroup,
    required this.unreadCount,
    required this.totalChapters,
    required this.preferredReadingMode,
    required this.autoCrop,
    required this.splitWidePages,
    required this.isPinned,
    required this.cloudFileSynced,
    required this.isArchived,
    required this.addedAtMs,
    required this.lastReadAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['content_hash'] = Variable<String>(contentHash);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    map['format'] = Variable<String>(format);
    map['root_path'] = Variable<String>(rootPath);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    if (!nullToAbsent || shelfId != null) {
      map['shelf_id'] = Variable<int>(shelfId);
    }
    map['shelf_group'] = Variable<String>(shelfGroup);
    map['unread_count'] = Variable<int>(unreadCount);
    map['total_chapters'] = Variable<int>(totalChapters);
    map['preferred_reading_mode'] = Variable<String>(preferredReadingMode);
    map['auto_crop'] = Variable<bool>(autoCrop);
    map['split_wide_pages'] = Variable<bool>(splitWidePages);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['cloud_file_synced'] = Variable<bool>(cloudFileSynced);
    map['is_archived'] = Variable<bool>(isArchived);
    map['added_at_ms'] = Variable<int>(addedAtMs);
    map['last_read_at_ms'] = Variable<int>(lastReadAtMs);
    return map;
  }

  MangasCompanion toCompanion(bool nullToAbsent) {
    return MangasCompanion(
      id: Value(id),
      contentHash: Value(contentHash),
      title: Value(title),
      author: Value(author),
      format: Value(format),
      rootPath: Value(rootPath),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      shelfId: shelfId == null && nullToAbsent
          ? const Value.absent()
          : Value(shelfId),
      shelfGroup: Value(shelfGroup),
      unreadCount: Value(unreadCount),
      totalChapters: Value(totalChapters),
      preferredReadingMode: Value(preferredReadingMode),
      autoCrop: Value(autoCrop),
      splitWidePages: Value(splitWidePages),
      isPinned: Value(isPinned),
      cloudFileSynced: Value(cloudFileSynced),
      isArchived: Value(isArchived),
      addedAtMs: Value(addedAtMs),
      lastReadAtMs: Value(lastReadAtMs),
    );
  }

  factory Manga.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Manga(
      id: serializer.fromJson<int>(json['id']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      format: serializer.fromJson<String>(json['format']),
      rootPath: serializer.fromJson<String>(json['rootPath']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      shelfId: serializer.fromJson<int?>(json['shelfId']),
      shelfGroup: serializer.fromJson<String>(json['shelfGroup']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      totalChapters: serializer.fromJson<int>(json['totalChapters']),
      preferredReadingMode: serializer.fromJson<String>(
        json['preferredReadingMode'],
      ),
      autoCrop: serializer.fromJson<bool>(json['autoCrop']),
      splitWidePages: serializer.fromJson<bool>(json['splitWidePages']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      cloudFileSynced: serializer.fromJson<bool>(json['cloudFileSynced']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      addedAtMs: serializer.fromJson<int>(json['addedAtMs']),
      lastReadAtMs: serializer.fromJson<int>(json['lastReadAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'contentHash': serializer.toJson<String>(contentHash),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'format': serializer.toJson<String>(format),
      'rootPath': serializer.toJson<String>(rootPath),
      'coverPath': serializer.toJson<String?>(coverPath),
      'shelfId': serializer.toJson<int?>(shelfId),
      'shelfGroup': serializer.toJson<String>(shelfGroup),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'totalChapters': serializer.toJson<int>(totalChapters),
      'preferredReadingMode': serializer.toJson<String>(preferredReadingMode),
      'autoCrop': serializer.toJson<bool>(autoCrop),
      'splitWidePages': serializer.toJson<bool>(splitWidePages),
      'isPinned': serializer.toJson<bool>(isPinned),
      'cloudFileSynced': serializer.toJson<bool>(cloudFileSynced),
      'isArchived': serializer.toJson<bool>(isArchived),
      'addedAtMs': serializer.toJson<int>(addedAtMs),
      'lastReadAtMs': serializer.toJson<int>(lastReadAtMs),
    };
  }

  Manga copyWith({
    int? id,
    String? contentHash,
    String? title,
    String? author,
    String? format,
    String? rootPath,
    Value<String?> coverPath = const Value.absent(),
    Value<int?> shelfId = const Value.absent(),
    String? shelfGroup,
    int? unreadCount,
    int? totalChapters,
    String? preferredReadingMode,
    bool? autoCrop,
    bool? splitWidePages,
    bool? isPinned,
    bool? cloudFileSynced,
    bool? isArchived,
    int? addedAtMs,
    int? lastReadAtMs,
  }) => Manga(
    id: id ?? this.id,
    contentHash: contentHash ?? this.contentHash,
    title: title ?? this.title,
    author: author ?? this.author,
    format: format ?? this.format,
    rootPath: rootPath ?? this.rootPath,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    shelfId: shelfId.present ? shelfId.value : this.shelfId,
    shelfGroup: shelfGroup ?? this.shelfGroup,
    unreadCount: unreadCount ?? this.unreadCount,
    totalChapters: totalChapters ?? this.totalChapters,
    preferredReadingMode: preferredReadingMode ?? this.preferredReadingMode,
    autoCrop: autoCrop ?? this.autoCrop,
    splitWidePages: splitWidePages ?? this.splitWidePages,
    isPinned: isPinned ?? this.isPinned,
    cloudFileSynced: cloudFileSynced ?? this.cloudFileSynced,
    isArchived: isArchived ?? this.isArchived,
    addedAtMs: addedAtMs ?? this.addedAtMs,
    lastReadAtMs: lastReadAtMs ?? this.lastReadAtMs,
  );
  Manga copyWithCompanion(MangasCompanion data) {
    return Manga(
      id: data.id.present ? data.id.value : this.id,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      format: data.format.present ? data.format.value : this.format,
      rootPath: data.rootPath.present ? data.rootPath.value : this.rootPath,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      shelfId: data.shelfId.present ? data.shelfId.value : this.shelfId,
      shelfGroup: data.shelfGroup.present
          ? data.shelfGroup.value
          : this.shelfGroup,
      unreadCount: data.unreadCount.present
          ? data.unreadCount.value
          : this.unreadCount,
      totalChapters: data.totalChapters.present
          ? data.totalChapters.value
          : this.totalChapters,
      preferredReadingMode: data.preferredReadingMode.present
          ? data.preferredReadingMode.value
          : this.preferredReadingMode,
      autoCrop: data.autoCrop.present ? data.autoCrop.value : this.autoCrop,
      splitWidePages: data.splitWidePages.present
          ? data.splitWidePages.value
          : this.splitWidePages,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      cloudFileSynced: data.cloudFileSynced.present
          ? data.cloudFileSynced.value
          : this.cloudFileSynced,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      addedAtMs: data.addedAtMs.present ? data.addedAtMs.value : this.addedAtMs,
      lastReadAtMs: data.lastReadAtMs.present
          ? data.lastReadAtMs.value
          : this.lastReadAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Manga(')
          ..write('id: $id, ')
          ..write('contentHash: $contentHash, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('format: $format, ')
          ..write('rootPath: $rootPath, ')
          ..write('coverPath: $coverPath, ')
          ..write('shelfId: $shelfId, ')
          ..write('shelfGroup: $shelfGroup, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('preferredReadingMode: $preferredReadingMode, ')
          ..write('autoCrop: $autoCrop, ')
          ..write('splitWidePages: $splitWidePages, ')
          ..write('isPinned: $isPinned, ')
          ..write('cloudFileSynced: $cloudFileSynced, ')
          ..write('isArchived: $isArchived, ')
          ..write('addedAtMs: $addedAtMs, ')
          ..write('lastReadAtMs: $lastReadAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    contentHash,
    title,
    author,
    format,
    rootPath,
    coverPath,
    shelfId,
    shelfGroup,
    unreadCount,
    totalChapters,
    preferredReadingMode,
    autoCrop,
    splitWidePages,
    isPinned,
    cloudFileSynced,
    isArchived,
    addedAtMs,
    lastReadAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Manga &&
          other.id == this.id &&
          other.contentHash == this.contentHash &&
          other.title == this.title &&
          other.author == this.author &&
          other.format == this.format &&
          other.rootPath == this.rootPath &&
          other.coverPath == this.coverPath &&
          other.shelfId == this.shelfId &&
          other.shelfGroup == this.shelfGroup &&
          other.unreadCount == this.unreadCount &&
          other.totalChapters == this.totalChapters &&
          other.preferredReadingMode == this.preferredReadingMode &&
          other.autoCrop == this.autoCrop &&
          other.splitWidePages == this.splitWidePages &&
          other.isPinned == this.isPinned &&
          other.cloudFileSynced == this.cloudFileSynced &&
          other.isArchived == this.isArchived &&
          other.addedAtMs == this.addedAtMs &&
          other.lastReadAtMs == this.lastReadAtMs);
}

class MangasCompanion extends UpdateCompanion<Manga> {
  final Value<int> id;
  final Value<String> contentHash;
  final Value<String> title;
  final Value<String> author;
  final Value<String> format;
  final Value<String> rootPath;
  final Value<String?> coverPath;
  final Value<int?> shelfId;
  final Value<String> shelfGroup;
  final Value<int> unreadCount;
  final Value<int> totalChapters;
  final Value<String> preferredReadingMode;
  final Value<bool> autoCrop;
  final Value<bool> splitWidePages;
  final Value<bool> isPinned;
  final Value<bool> cloudFileSynced;
  final Value<bool> isArchived;
  final Value<int> addedAtMs;
  final Value<int> lastReadAtMs;
  const MangasCompanion({
    this.id = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.format = const Value.absent(),
    this.rootPath = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.shelfId = const Value.absent(),
    this.shelfGroup = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.preferredReadingMode = const Value.absent(),
    this.autoCrop = const Value.absent(),
    this.splitWidePages = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.cloudFileSynced = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.addedAtMs = const Value.absent(),
    this.lastReadAtMs = const Value.absent(),
  });
  MangasCompanion.insert({
    this.id = const Value.absent(),
    required String contentHash,
    required String title,
    this.author = const Value.absent(),
    required String format,
    required String rootPath,
    this.coverPath = const Value.absent(),
    this.shelfId = const Value.absent(),
    this.shelfGroup = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.preferredReadingMode = const Value.absent(),
    this.autoCrop = const Value.absent(),
    this.splitWidePages = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.cloudFileSynced = const Value.absent(),
    this.isArchived = const Value.absent(),
    required int addedAtMs,
    required int lastReadAtMs,
  }) : contentHash = Value(contentHash),
       title = Value(title),
       format = Value(format),
       rootPath = Value(rootPath),
       addedAtMs = Value(addedAtMs),
       lastReadAtMs = Value(lastReadAtMs);
  static Insertable<Manga> custom({
    Expression<int>? id,
    Expression<String>? contentHash,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? format,
    Expression<String>? rootPath,
    Expression<String>? coverPath,
    Expression<int>? shelfId,
    Expression<String>? shelfGroup,
    Expression<int>? unreadCount,
    Expression<int>? totalChapters,
    Expression<String>? preferredReadingMode,
    Expression<bool>? autoCrop,
    Expression<bool>? splitWidePages,
    Expression<bool>? isPinned,
    Expression<bool>? cloudFileSynced,
    Expression<bool>? isArchived,
    Expression<int>? addedAtMs,
    Expression<int>? lastReadAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (contentHash != null) 'content_hash': contentHash,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (format != null) 'format': format,
      if (rootPath != null) 'root_path': rootPath,
      if (coverPath != null) 'cover_path': coverPath,
      if (shelfId != null) 'shelf_id': shelfId,
      if (shelfGroup != null) 'shelf_group': shelfGroup,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (totalChapters != null) 'total_chapters': totalChapters,
      if (preferredReadingMode != null)
        'preferred_reading_mode': preferredReadingMode,
      if (autoCrop != null) 'auto_crop': autoCrop,
      if (splitWidePages != null) 'split_wide_pages': splitWidePages,
      if (isPinned != null) 'is_pinned': isPinned,
      if (cloudFileSynced != null) 'cloud_file_synced': cloudFileSynced,
      if (isArchived != null) 'is_archived': isArchived,
      if (addedAtMs != null) 'added_at_ms': addedAtMs,
      if (lastReadAtMs != null) 'last_read_at_ms': lastReadAtMs,
    });
  }

  MangasCompanion copyWith({
    Value<int>? id,
    Value<String>? contentHash,
    Value<String>? title,
    Value<String>? author,
    Value<String>? format,
    Value<String>? rootPath,
    Value<String?>? coverPath,
    Value<int?>? shelfId,
    Value<String>? shelfGroup,
    Value<int>? unreadCount,
    Value<int>? totalChapters,
    Value<String>? preferredReadingMode,
    Value<bool>? autoCrop,
    Value<bool>? splitWidePages,
    Value<bool>? isPinned,
    Value<bool>? cloudFileSynced,
    Value<bool>? isArchived,
    Value<int>? addedAtMs,
    Value<int>? lastReadAtMs,
  }) {
    return MangasCompanion(
      id: id ?? this.id,
      contentHash: contentHash ?? this.contentHash,
      title: title ?? this.title,
      author: author ?? this.author,
      format: format ?? this.format,
      rootPath: rootPath ?? this.rootPath,
      coverPath: coverPath ?? this.coverPath,
      shelfId: shelfId ?? this.shelfId,
      shelfGroup: shelfGroup ?? this.shelfGroup,
      unreadCount: unreadCount ?? this.unreadCount,
      totalChapters: totalChapters ?? this.totalChapters,
      preferredReadingMode: preferredReadingMode ?? this.preferredReadingMode,
      autoCrop: autoCrop ?? this.autoCrop,
      splitWidePages: splitWidePages ?? this.splitWidePages,
      isPinned: isPinned ?? this.isPinned,
      cloudFileSynced: cloudFileSynced ?? this.cloudFileSynced,
      isArchived: isArchived ?? this.isArchived,
      addedAtMs: addedAtMs ?? this.addedAtMs,
      lastReadAtMs: lastReadAtMs ?? this.lastReadAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (rootPath.present) {
      map['root_path'] = Variable<String>(rootPath.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (shelfId.present) {
      map['shelf_id'] = Variable<int>(shelfId.value);
    }
    if (shelfGroup.present) {
      map['shelf_group'] = Variable<String>(shelfGroup.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (totalChapters.present) {
      map['total_chapters'] = Variable<int>(totalChapters.value);
    }
    if (preferredReadingMode.present) {
      map['preferred_reading_mode'] = Variable<String>(
        preferredReadingMode.value,
      );
    }
    if (autoCrop.present) {
      map['auto_crop'] = Variable<bool>(autoCrop.value);
    }
    if (splitWidePages.present) {
      map['split_wide_pages'] = Variable<bool>(splitWidePages.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (cloudFileSynced.present) {
      map['cloud_file_synced'] = Variable<bool>(cloudFileSynced.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (addedAtMs.present) {
      map['added_at_ms'] = Variable<int>(addedAtMs.value);
    }
    if (lastReadAtMs.present) {
      map['last_read_at_ms'] = Variable<int>(lastReadAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MangasCompanion(')
          ..write('id: $id, ')
          ..write('contentHash: $contentHash, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('format: $format, ')
          ..write('rootPath: $rootPath, ')
          ..write('coverPath: $coverPath, ')
          ..write('shelfId: $shelfId, ')
          ..write('shelfGroup: $shelfGroup, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('preferredReadingMode: $preferredReadingMode, ')
          ..write('autoCrop: $autoCrop, ')
          ..write('splitWidePages: $splitWidePages, ')
          ..write('isPinned: $isPinned, ')
          ..write('cloudFileSynced: $cloudFileSynced, ')
          ..write('isArchived: $isArchived, ')
          ..write('addedAtMs: $addedAtMs, ')
          ..write('lastReadAtMs: $lastReadAtMs')
          ..write(')'))
        .toString();
  }
}

class $MangaChaptersTable extends MangaChapters
    with TableInfo<$MangaChaptersTable, MangaChapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MangaChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _mangaIdMeta = const VerificationMeta(
    'mangaId',
  );
  @override
  late final GeneratedColumn<int> mangaId = GeneratedColumn<int>(
    'manga_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePathMeta = const VerificationMeta(
    'sourcePath',
  );
  @override
  late final GeneratedColumn<String> sourcePath = GeneratedColumn<String>(
    'source_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReadPageMeta = const VerificationMeta(
    'lastReadPage',
  );
  @override
  late final GeneratedColumn<int> lastReadPage = GeneratedColumn<int>(
    'last_read_page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
    'is_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mangaId,
    title,
    chapterIndex,
    sourcePath,
    pageCount,
    lastReadPage,
    isRead,
    updatedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'manga_chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<MangaChapter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('manga_id')) {
      context.handle(
        _mangaIdMeta,
        mangaId.isAcceptableOrUnknown(data['manga_id']!, _mangaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mangaIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('source_path')) {
      context.handle(
        _sourcePathMeta,
        sourcePath.isAcceptableOrUnknown(data['source_path']!, _sourcePathMeta),
      );
    } else if (isInserting) {
      context.missing(_sourcePathMeta);
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    }
    if (data.containsKey('last_read_page')) {
      context.handle(
        _lastReadPageMeta,
        lastReadPage.isAcceptableOrUnknown(
          data['last_read_page']!,
          _lastReadPageMeta,
        ),
      );
    }
    if (data.containsKey('is_read')) {
      context.handle(
        _isReadMeta,
        isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta),
      );
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MangaChapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MangaChapter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mangaId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manga_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      sourcePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_path'],
      )!,
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      lastReadPage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_read_page'],
      )!,
      isRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_read'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $MangaChaptersTable createAlias(String alias) {
    return $MangaChaptersTable(attachedDatabase, alias);
  }
}

class MangaChapter extends DataClass implements Insertable<MangaChapter> {
  final int id;
  final int mangaId;
  final String title;
  final int chapterIndex;
  final String sourcePath;
  final int pageCount;
  final int lastReadPage;
  final bool isRead;
  final int updatedAtMs;
  const MangaChapter({
    required this.id,
    required this.mangaId,
    required this.title,
    required this.chapterIndex,
    required this.sourcePath,
    required this.pageCount,
    required this.lastReadPage,
    required this.isRead,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['manga_id'] = Variable<int>(mangaId);
    map['title'] = Variable<String>(title);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['source_path'] = Variable<String>(sourcePath);
    map['page_count'] = Variable<int>(pageCount);
    map['last_read_page'] = Variable<int>(lastReadPage);
    map['is_read'] = Variable<bool>(isRead);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  MangaChaptersCompanion toCompanion(bool nullToAbsent) {
    return MangaChaptersCompanion(
      id: Value(id),
      mangaId: Value(mangaId),
      title: Value(title),
      chapterIndex: Value(chapterIndex),
      sourcePath: Value(sourcePath),
      pageCount: Value(pageCount),
      lastReadPage: Value(lastReadPage),
      isRead: Value(isRead),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory MangaChapter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MangaChapter(
      id: serializer.fromJson<int>(json['id']),
      mangaId: serializer.fromJson<int>(json['mangaId']),
      title: serializer.fromJson<String>(json['title']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      sourcePath: serializer.fromJson<String>(json['sourcePath']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      lastReadPage: serializer.fromJson<int>(json['lastReadPage']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mangaId': serializer.toJson<int>(mangaId),
      'title': serializer.toJson<String>(title),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'sourcePath': serializer.toJson<String>(sourcePath),
      'pageCount': serializer.toJson<int>(pageCount),
      'lastReadPage': serializer.toJson<int>(lastReadPage),
      'isRead': serializer.toJson<bool>(isRead),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  MangaChapter copyWith({
    int? id,
    int? mangaId,
    String? title,
    int? chapterIndex,
    String? sourcePath,
    int? pageCount,
    int? lastReadPage,
    bool? isRead,
    int? updatedAtMs,
  }) => MangaChapter(
    id: id ?? this.id,
    mangaId: mangaId ?? this.mangaId,
    title: title ?? this.title,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    sourcePath: sourcePath ?? this.sourcePath,
    pageCount: pageCount ?? this.pageCount,
    lastReadPage: lastReadPage ?? this.lastReadPage,
    isRead: isRead ?? this.isRead,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  MangaChapter copyWithCompanion(MangaChaptersCompanion data) {
    return MangaChapter(
      id: data.id.present ? data.id.value : this.id,
      mangaId: data.mangaId.present ? data.mangaId.value : this.mangaId,
      title: data.title.present ? data.title.value : this.title,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      sourcePath: data.sourcePath.present
          ? data.sourcePath.value
          : this.sourcePath,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      lastReadPage: data.lastReadPage.present
          ? data.lastReadPage.value
          : this.lastReadPage,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MangaChapter(')
          ..write('id: $id, ')
          ..write('mangaId: $mangaId, ')
          ..write('title: $title, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('pageCount: $pageCount, ')
          ..write('lastReadPage: $lastReadPage, ')
          ..write('isRead: $isRead, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mangaId,
    title,
    chapterIndex,
    sourcePath,
    pageCount,
    lastReadPage,
    isRead,
    updatedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MangaChapter &&
          other.id == this.id &&
          other.mangaId == this.mangaId &&
          other.title == this.title &&
          other.chapterIndex == this.chapterIndex &&
          other.sourcePath == this.sourcePath &&
          other.pageCount == this.pageCount &&
          other.lastReadPage == this.lastReadPage &&
          other.isRead == this.isRead &&
          other.updatedAtMs == this.updatedAtMs);
}

class MangaChaptersCompanion extends UpdateCompanion<MangaChapter> {
  final Value<int> id;
  final Value<int> mangaId;
  final Value<String> title;
  final Value<int> chapterIndex;
  final Value<String> sourcePath;
  final Value<int> pageCount;
  final Value<int> lastReadPage;
  final Value<bool> isRead;
  final Value<int> updatedAtMs;
  const MangaChaptersCompanion({
    this.id = const Value.absent(),
    this.mangaId = const Value.absent(),
    this.title = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.lastReadPage = const Value.absent(),
    this.isRead = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
  });
  MangaChaptersCompanion.insert({
    this.id = const Value.absent(),
    required int mangaId,
    required String title,
    required int chapterIndex,
    required String sourcePath,
    this.pageCount = const Value.absent(),
    this.lastReadPage = const Value.absent(),
    this.isRead = const Value.absent(),
    required int updatedAtMs,
  }) : mangaId = Value(mangaId),
       title = Value(title),
       chapterIndex = Value(chapterIndex),
       sourcePath = Value(sourcePath),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<MangaChapter> custom({
    Expression<int>? id,
    Expression<int>? mangaId,
    Expression<String>? title,
    Expression<int>? chapterIndex,
    Expression<String>? sourcePath,
    Expression<int>? pageCount,
    Expression<int>? lastReadPage,
    Expression<bool>? isRead,
    Expression<int>? updatedAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mangaId != null) 'manga_id': mangaId,
      if (title != null) 'title': title,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (sourcePath != null) 'source_path': sourcePath,
      if (pageCount != null) 'page_count': pageCount,
      if (lastReadPage != null) 'last_read_page': lastReadPage,
      if (isRead != null) 'is_read': isRead,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
    });
  }

  MangaChaptersCompanion copyWith({
    Value<int>? id,
    Value<int>? mangaId,
    Value<String>? title,
    Value<int>? chapterIndex,
    Value<String>? sourcePath,
    Value<int>? pageCount,
    Value<int>? lastReadPage,
    Value<bool>? isRead,
    Value<int>? updatedAtMs,
  }) {
    return MangaChaptersCompanion(
      id: id ?? this.id,
      mangaId: mangaId ?? this.mangaId,
      title: title ?? this.title,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      sourcePath: sourcePath ?? this.sourcePath,
      pageCount: pageCount ?? this.pageCount,
      lastReadPage: lastReadPage ?? this.lastReadPage,
      isRead: isRead ?? this.isRead,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mangaId.present) {
      map['manga_id'] = Variable<int>(mangaId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (lastReadPage.present) {
      map['last_read_page'] = Variable<int>(lastReadPage.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MangaChaptersCompanion(')
          ..write('id: $id, ')
          ..write('mangaId: $mangaId, ')
          ..write('title: $title, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('pageCount: $pageCount, ')
          ..write('lastReadPage: $lastReadPage, ')
          ..write('isRead: $isRead, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }
}

class $AnnotationsTable extends Annotations
    with TableInfo<$AnnotationsTable, Annotation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnnotationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaKindMeta = const VerificationMeta(
    'mediaKind',
  );
  @override
  late final GeneratedColumn<String> mediaKind = GeneratedColumn<String>(
    'media_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _locatorMeta = const VerificationMeta(
    'locator',
  );
  @override
  late final GeneratedColumn<String> locator = GeneratedColumn<String>(
    'locator',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _excerptMeta = const VerificationMeta(
    'excerpt',
  );
  @override
  late final GeneratedColumn<String> excerpt = GeneratedColumn<String>(
    'excerpt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _noteTextMeta = const VerificationMeta(
    'noteText',
  );
  @override
  late final GeneratedColumn<String> noteText = GeneratedColumn<String>(
    'note_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#EED29A'),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    contentHash,
    mediaKind,
    kind,
    chapterIndex,
    locator,
    excerpt,
    noteText,
    colorHex,
    isDeleted,
    updatedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'annotations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Annotation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('media_kind')) {
      context.handle(
        _mediaKindMeta,
        mediaKind.isAcceptableOrUnknown(data['media_kind']!, _mediaKindMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaKindMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    }
    if (data.containsKey('locator')) {
      context.handle(
        _locatorMeta,
        locator.isAcceptableOrUnknown(data['locator']!, _locatorMeta),
      );
    } else if (isInserting) {
      context.missing(_locatorMeta);
    }
    if (data.containsKey('excerpt')) {
      context.handle(
        _excerptMeta,
        excerpt.isAcceptableOrUnknown(data['excerpt']!, _excerptMeta),
      );
    }
    if (data.containsKey('note_text')) {
      context.handle(
        _noteTextMeta,
        noteText.isAcceptableOrUnknown(data['note_text']!, _noteTextMeta),
      );
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Annotation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Annotation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      mediaKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_kind'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      locator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator'],
      )!,
      excerpt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}excerpt'],
      )!,
      noteText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_text'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $AnnotationsTable createAlias(String alias) {
    return $AnnotationsTable(attachedDatabase, alias);
  }
}

class Annotation extends DataClass implements Insertable<Annotation> {
  final int id;
  final String uuid;
  final String contentHash;
  final String mediaKind;
  final String kind;
  final int chapterIndex;
  final String locator;
  final String excerpt;
  final String noteText;
  final String colorHex;
  final bool isDeleted;
  final int updatedAtMs;
  const Annotation({
    required this.id,
    required this.uuid,
    required this.contentHash,
    required this.mediaKind,
    required this.kind,
    required this.chapterIndex,
    required this.locator,
    required this.excerpt,
    required this.noteText,
    required this.colorHex,
    required this.isDeleted,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['content_hash'] = Variable<String>(contentHash);
    map['media_kind'] = Variable<String>(mediaKind);
    map['kind'] = Variable<String>(kind);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['locator'] = Variable<String>(locator);
    map['excerpt'] = Variable<String>(excerpt);
    map['note_text'] = Variable<String>(noteText);
    map['color_hex'] = Variable<String>(colorHex);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  AnnotationsCompanion toCompanion(bool nullToAbsent) {
    return AnnotationsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      contentHash: Value(contentHash),
      mediaKind: Value(mediaKind),
      kind: Value(kind),
      chapterIndex: Value(chapterIndex),
      locator: Value(locator),
      excerpt: Value(excerpt),
      noteText: Value(noteText),
      colorHex: Value(colorHex),
      isDeleted: Value(isDeleted),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory Annotation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Annotation(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      mediaKind: serializer.fromJson<String>(json['mediaKind']),
      kind: serializer.fromJson<String>(json['kind']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      locator: serializer.fromJson<String>(json['locator']),
      excerpt: serializer.fromJson<String>(json['excerpt']),
      noteText: serializer.fromJson<String>(json['noteText']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'contentHash': serializer.toJson<String>(contentHash),
      'mediaKind': serializer.toJson<String>(mediaKind),
      'kind': serializer.toJson<String>(kind),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'locator': serializer.toJson<String>(locator),
      'excerpt': serializer.toJson<String>(excerpt),
      'noteText': serializer.toJson<String>(noteText),
      'colorHex': serializer.toJson<String>(colorHex),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  Annotation copyWith({
    int? id,
    String? uuid,
    String? contentHash,
    String? mediaKind,
    String? kind,
    int? chapterIndex,
    String? locator,
    String? excerpt,
    String? noteText,
    String? colorHex,
    bool? isDeleted,
    int? updatedAtMs,
  }) => Annotation(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    contentHash: contentHash ?? this.contentHash,
    mediaKind: mediaKind ?? this.mediaKind,
    kind: kind ?? this.kind,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    locator: locator ?? this.locator,
    excerpt: excerpt ?? this.excerpt,
    noteText: noteText ?? this.noteText,
    colorHex: colorHex ?? this.colorHex,
    isDeleted: isDeleted ?? this.isDeleted,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  Annotation copyWithCompanion(AnnotationsCompanion data) {
    return Annotation(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      mediaKind: data.mediaKind.present ? data.mediaKind.value : this.mediaKind,
      kind: data.kind.present ? data.kind.value : this.kind,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      locator: data.locator.present ? data.locator.value : this.locator,
      excerpt: data.excerpt.present ? data.excerpt.value : this.excerpt,
      noteText: data.noteText.present ? data.noteText.value : this.noteText,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Annotation(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('contentHash: $contentHash, ')
          ..write('mediaKind: $mediaKind, ')
          ..write('kind: $kind, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('locator: $locator, ')
          ..write('excerpt: $excerpt, ')
          ..write('noteText: $noteText, ')
          ..write('colorHex: $colorHex, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    contentHash,
    mediaKind,
    kind,
    chapterIndex,
    locator,
    excerpt,
    noteText,
    colorHex,
    isDeleted,
    updatedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Annotation &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.contentHash == this.contentHash &&
          other.mediaKind == this.mediaKind &&
          other.kind == this.kind &&
          other.chapterIndex == this.chapterIndex &&
          other.locator == this.locator &&
          other.excerpt == this.excerpt &&
          other.noteText == this.noteText &&
          other.colorHex == this.colorHex &&
          other.isDeleted == this.isDeleted &&
          other.updatedAtMs == this.updatedAtMs);
}

class AnnotationsCompanion extends UpdateCompanion<Annotation> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> contentHash;
  final Value<String> mediaKind;
  final Value<String> kind;
  final Value<int> chapterIndex;
  final Value<String> locator;
  final Value<String> excerpt;
  final Value<String> noteText;
  final Value<String> colorHex;
  final Value<bool> isDeleted;
  final Value<int> updatedAtMs;
  const AnnotationsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.mediaKind = const Value.absent(),
    this.kind = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.locator = const Value.absent(),
    this.excerpt = const Value.absent(),
    this.noteText = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
  });
  AnnotationsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String contentHash,
    required String mediaKind,
    required String kind,
    this.chapterIndex = const Value.absent(),
    required String locator,
    this.excerpt = const Value.absent(),
    this.noteText = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.isDeleted = const Value.absent(),
    required int updatedAtMs,
  }) : uuid = Value(uuid),
       contentHash = Value(contentHash),
       mediaKind = Value(mediaKind),
       kind = Value(kind),
       locator = Value(locator),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<Annotation> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? contentHash,
    Expression<String>? mediaKind,
    Expression<String>? kind,
    Expression<int>? chapterIndex,
    Expression<String>? locator,
    Expression<String>? excerpt,
    Expression<String>? noteText,
    Expression<String>? colorHex,
    Expression<bool>? isDeleted,
    Expression<int>? updatedAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (contentHash != null) 'content_hash': contentHash,
      if (mediaKind != null) 'media_kind': mediaKind,
      if (kind != null) 'kind': kind,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (locator != null) 'locator': locator,
      if (excerpt != null) 'excerpt': excerpt,
      if (noteText != null) 'note_text': noteText,
      if (colorHex != null) 'color_hex': colorHex,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
    });
  }

  AnnotationsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? contentHash,
    Value<String>? mediaKind,
    Value<String>? kind,
    Value<int>? chapterIndex,
    Value<String>? locator,
    Value<String>? excerpt,
    Value<String>? noteText,
    Value<String>? colorHex,
    Value<bool>? isDeleted,
    Value<int>? updatedAtMs,
  }) {
    return AnnotationsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      contentHash: contentHash ?? this.contentHash,
      mediaKind: mediaKind ?? this.mediaKind,
      kind: kind ?? this.kind,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      locator: locator ?? this.locator,
      excerpt: excerpt ?? this.excerpt,
      noteText: noteText ?? this.noteText,
      colorHex: colorHex ?? this.colorHex,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (mediaKind.present) {
      map['media_kind'] = Variable<String>(mediaKind.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (locator.present) {
      map['locator'] = Variable<String>(locator.value);
    }
    if (excerpt.present) {
      map['excerpt'] = Variable<String>(excerpt.value);
    }
    if (noteText.present) {
      map['note_text'] = Variable<String>(noteText.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('contentHash: $contentHash, ')
          ..write('mediaKind: $mediaKind, ')
          ..write('kind: $kind, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('locator: $locator, ')
          ..write('excerpt: $excerpt, ')
          ..write('noteText: $noteText, ')
          ..write('colorHex: $colorHex, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }
}

class $WatchedFoldersTable extends WatchedFolders
    with TableInfo<$WatchedFoldersTable, WatchedFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchedFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uriOrPathMeta = const VerificationMeta(
    'uriOrPath',
  );
  @override
  late final GeneratedColumn<String> uriOrPath = GeneratedColumn<String>(
    'uri_or_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _defaultKindMeta = const VerificationMeta(
    'defaultKind',
  );
  @override
  late final GeneratedColumn<String> defaultKind = GeneratedColumn<String>(
    'default_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('auto'),
  );
  static const VerificationMeta _lastScannedAtMsMeta = const VerificationMeta(
    'lastScannedAtMs',
  );
  @override
  late final GeneratedColumn<int> lastScannedAtMs = GeneratedColumn<int>(
    'last_scanned_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uriOrPath,
    displayName,
    defaultKind,
    lastScannedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watched_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchedFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uri_or_path')) {
      context.handle(
        _uriOrPathMeta,
        uriOrPath.isAcceptableOrUnknown(data['uri_or_path']!, _uriOrPathMeta),
      );
    } else if (isInserting) {
      context.missing(_uriOrPathMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('default_kind')) {
      context.handle(
        _defaultKindMeta,
        defaultKind.isAcceptableOrUnknown(
          data['default_kind']!,
          _defaultKindMeta,
        ),
      );
    }
    if (data.containsKey('last_scanned_at_ms')) {
      context.handle(
        _lastScannedAtMsMeta,
        lastScannedAtMs.isAcceptableOrUnknown(
          data['last_scanned_at_ms']!,
          _lastScannedAtMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WatchedFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchedFolder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uriOrPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uri_or_path'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      defaultKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_kind'],
      )!,
      lastScannedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_scanned_at_ms'],
      )!,
    );
  }

  @override
  $WatchedFoldersTable createAlias(String alias) {
    return $WatchedFoldersTable(attachedDatabase, alias);
  }
}

class WatchedFolder extends DataClass implements Insertable<WatchedFolder> {
  final int id;
  final String uriOrPath;
  final String displayName;
  final String defaultKind;
  final int lastScannedAtMs;
  const WatchedFolder({
    required this.id,
    required this.uriOrPath,
    required this.displayName,
    required this.defaultKind,
    required this.lastScannedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uri_or_path'] = Variable<String>(uriOrPath);
    map['display_name'] = Variable<String>(displayName);
    map['default_kind'] = Variable<String>(defaultKind);
    map['last_scanned_at_ms'] = Variable<int>(lastScannedAtMs);
    return map;
  }

  WatchedFoldersCompanion toCompanion(bool nullToAbsent) {
    return WatchedFoldersCompanion(
      id: Value(id),
      uriOrPath: Value(uriOrPath),
      displayName: Value(displayName),
      defaultKind: Value(defaultKind),
      lastScannedAtMs: Value(lastScannedAtMs),
    );
  }

  factory WatchedFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchedFolder(
      id: serializer.fromJson<int>(json['id']),
      uriOrPath: serializer.fromJson<String>(json['uriOrPath']),
      displayName: serializer.fromJson<String>(json['displayName']),
      defaultKind: serializer.fromJson<String>(json['defaultKind']),
      lastScannedAtMs: serializer.fromJson<int>(json['lastScannedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uriOrPath': serializer.toJson<String>(uriOrPath),
      'displayName': serializer.toJson<String>(displayName),
      'defaultKind': serializer.toJson<String>(defaultKind),
      'lastScannedAtMs': serializer.toJson<int>(lastScannedAtMs),
    };
  }

  WatchedFolder copyWith({
    int? id,
    String? uriOrPath,
    String? displayName,
    String? defaultKind,
    int? lastScannedAtMs,
  }) => WatchedFolder(
    id: id ?? this.id,
    uriOrPath: uriOrPath ?? this.uriOrPath,
    displayName: displayName ?? this.displayName,
    defaultKind: defaultKind ?? this.defaultKind,
    lastScannedAtMs: lastScannedAtMs ?? this.lastScannedAtMs,
  );
  WatchedFolder copyWithCompanion(WatchedFoldersCompanion data) {
    return WatchedFolder(
      id: data.id.present ? data.id.value : this.id,
      uriOrPath: data.uriOrPath.present ? data.uriOrPath.value : this.uriOrPath,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      defaultKind: data.defaultKind.present
          ? data.defaultKind.value
          : this.defaultKind,
      lastScannedAtMs: data.lastScannedAtMs.present
          ? data.lastScannedAtMs.value
          : this.lastScannedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchedFolder(')
          ..write('id: $id, ')
          ..write('uriOrPath: $uriOrPath, ')
          ..write('displayName: $displayName, ')
          ..write('defaultKind: $defaultKind, ')
          ..write('lastScannedAtMs: $lastScannedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, uriOrPath, displayName, defaultKind, lastScannedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchedFolder &&
          other.id == this.id &&
          other.uriOrPath == this.uriOrPath &&
          other.displayName == this.displayName &&
          other.defaultKind == this.defaultKind &&
          other.lastScannedAtMs == this.lastScannedAtMs);
}

class WatchedFoldersCompanion extends UpdateCompanion<WatchedFolder> {
  final Value<int> id;
  final Value<String> uriOrPath;
  final Value<String> displayName;
  final Value<String> defaultKind;
  final Value<int> lastScannedAtMs;
  const WatchedFoldersCompanion({
    this.id = const Value.absent(),
    this.uriOrPath = const Value.absent(),
    this.displayName = const Value.absent(),
    this.defaultKind = const Value.absent(),
    this.lastScannedAtMs = const Value.absent(),
  });
  WatchedFoldersCompanion.insert({
    this.id = const Value.absent(),
    required String uriOrPath,
    required String displayName,
    this.defaultKind = const Value.absent(),
    this.lastScannedAtMs = const Value.absent(),
  }) : uriOrPath = Value(uriOrPath),
       displayName = Value(displayName);
  static Insertable<WatchedFolder> custom({
    Expression<int>? id,
    Expression<String>? uriOrPath,
    Expression<String>? displayName,
    Expression<String>? defaultKind,
    Expression<int>? lastScannedAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uriOrPath != null) 'uri_or_path': uriOrPath,
      if (displayName != null) 'display_name': displayName,
      if (defaultKind != null) 'default_kind': defaultKind,
      if (lastScannedAtMs != null) 'last_scanned_at_ms': lastScannedAtMs,
    });
  }

  WatchedFoldersCompanion copyWith({
    Value<int>? id,
    Value<String>? uriOrPath,
    Value<String>? displayName,
    Value<String>? defaultKind,
    Value<int>? lastScannedAtMs,
  }) {
    return WatchedFoldersCompanion(
      id: id ?? this.id,
      uriOrPath: uriOrPath ?? this.uriOrPath,
      displayName: displayName ?? this.displayName,
      defaultKind: defaultKind ?? this.defaultKind,
      lastScannedAtMs: lastScannedAtMs ?? this.lastScannedAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uriOrPath.present) {
      map['uri_or_path'] = Variable<String>(uriOrPath.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (defaultKind.present) {
      map['default_kind'] = Variable<String>(defaultKind.value);
    }
    if (lastScannedAtMs.present) {
      map['last_scanned_at_ms'] = Variable<int>(lastScannedAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchedFoldersCompanion(')
          ..write('id: $id, ')
          ..write('uriOrPath: $uriOrPath, ')
          ..write('displayName: $displayName, ')
          ..write('defaultKind: $defaultKind, ')
          ..write('lastScannedAtMs: $lastScannedAtMs')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaKindMeta = const VerificationMeta(
    'mediaKind',
  );
  @override
  late final GeneratedColumn<String> mediaKind = GeneratedColumn<String>(
    'media_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locatorMeta = const VerificationMeta(
    'locator',
  );
  @override
  late final GeneratedColumn<String> locator = GeneratedColumn<String>(
    'locator',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressRatioMeta = const VerificationMeta(
    'progressRatio',
  );
  @override
  late final GeneratedColumn<double> progressRatio = GeneratedColumn<double>(
    'progress_ratio',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncedAtMsMeta = const VerificationMeta(
    'lastSyncedAtMs',
  );
  @override
  late final GeneratedColumn<int> lastSyncedAtMs = GeneratedColumn<int>(
    'last_synced_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceNameMeta = const VerificationMeta(
    'deviceName',
  );
  @override
  late final GeneratedColumn<String> deviceName = GeneratedColumn<String>(
    'device_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    contentHash,
    mediaKind,
    locator,
    progressRatio,
    updatedAtMs,
    lastSyncedAtMs,
    deviceId,
    deviceName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('media_kind')) {
      context.handle(
        _mediaKindMeta,
        mediaKind.isAcceptableOrUnknown(data['media_kind']!, _mediaKindMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaKindMeta);
    }
    if (data.containsKey('locator')) {
      context.handle(
        _locatorMeta,
        locator.isAcceptableOrUnknown(data['locator']!, _locatorMeta),
      );
    } else if (isInserting) {
      context.missing(_locatorMeta);
    }
    if (data.containsKey('progress_ratio')) {
      context.handle(
        _progressRatioMeta,
        progressRatio.isAcceptableOrUnknown(
          data['progress_ratio']!,
          _progressRatioMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    if (data.containsKey('last_synced_at_ms')) {
      context.handle(
        _lastSyncedAtMsMeta,
        lastSyncedAtMs.isAcceptableOrUnknown(
          data['last_synced_at_ms']!,
          _lastSyncedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('device_name')) {
      context.handle(
        _deviceNameMeta,
        deviceName.isAcceptableOrUnknown(data['device_name']!, _deviceNameMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentHash};
  @override
  SyncState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncState(
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      mediaKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_kind'],
      )!,
      locator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator'],
      )!,
      progressRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress_ratio'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
      lastSyncedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_at_ms'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deviceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_name'],
      )!,
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncState extends DataClass implements Insertable<SyncState> {
  final String contentHash;
  final String mediaKind;
  final String locator;
  final double progressRatio;
  final int updatedAtMs;
  final int lastSyncedAtMs;
  final String deviceId;
  final String deviceName;
  const SyncState({
    required this.contentHash,
    required this.mediaKind,
    required this.locator,
    required this.progressRatio,
    required this.updatedAtMs,
    required this.lastSyncedAtMs,
    required this.deviceId,
    required this.deviceName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_hash'] = Variable<String>(contentHash);
    map['media_kind'] = Variable<String>(mediaKind);
    map['locator'] = Variable<String>(locator);
    map['progress_ratio'] = Variable<double>(progressRatio);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    map['last_synced_at_ms'] = Variable<int>(lastSyncedAtMs);
    map['device_id'] = Variable<String>(deviceId);
    map['device_name'] = Variable<String>(deviceName);
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(
      contentHash: Value(contentHash),
      mediaKind: Value(mediaKind),
      locator: Value(locator),
      progressRatio: Value(progressRatio),
      updatedAtMs: Value(updatedAtMs),
      lastSyncedAtMs: Value(lastSyncedAtMs),
      deviceId: Value(deviceId),
      deviceName: Value(deviceName),
    );
  }

  factory SyncState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncState(
      contentHash: serializer.fromJson<String>(json['contentHash']),
      mediaKind: serializer.fromJson<String>(json['mediaKind']),
      locator: serializer.fromJson<String>(json['locator']),
      progressRatio: serializer.fromJson<double>(json['progressRatio']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
      lastSyncedAtMs: serializer.fromJson<int>(json['lastSyncedAtMs']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      deviceName: serializer.fromJson<String>(json['deviceName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'contentHash': serializer.toJson<String>(contentHash),
      'mediaKind': serializer.toJson<String>(mediaKind),
      'locator': serializer.toJson<String>(locator),
      'progressRatio': serializer.toJson<double>(progressRatio),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
      'lastSyncedAtMs': serializer.toJson<int>(lastSyncedAtMs),
      'deviceId': serializer.toJson<String>(deviceId),
      'deviceName': serializer.toJson<String>(deviceName),
    };
  }

  SyncState copyWith({
    String? contentHash,
    String? mediaKind,
    String? locator,
    double? progressRatio,
    int? updatedAtMs,
    int? lastSyncedAtMs,
    String? deviceId,
    String? deviceName,
  }) => SyncState(
    contentHash: contentHash ?? this.contentHash,
    mediaKind: mediaKind ?? this.mediaKind,
    locator: locator ?? this.locator,
    progressRatio: progressRatio ?? this.progressRatio,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    lastSyncedAtMs: lastSyncedAtMs ?? this.lastSyncedAtMs,
    deviceId: deviceId ?? this.deviceId,
    deviceName: deviceName ?? this.deviceName,
  );
  SyncState copyWithCompanion(SyncStatesCompanion data) {
    return SyncState(
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      mediaKind: data.mediaKind.present ? data.mediaKind.value : this.mediaKind,
      locator: data.locator.present ? data.locator.value : this.locator,
      progressRatio: data.progressRatio.present
          ? data.progressRatio.value
          : this.progressRatio,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
      lastSyncedAtMs: data.lastSyncedAtMs.present
          ? data.lastSyncedAtMs.value
          : this.lastSyncedAtMs,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deviceName: data.deviceName.present
          ? data.deviceName.value
          : this.deviceName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncState(')
          ..write('contentHash: $contentHash, ')
          ..write('mediaKind: $mediaKind, ')
          ..write('locator: $locator, ')
          ..write('progressRatio: $progressRatio, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('lastSyncedAtMs: $lastSyncedAtMs, ')
          ..write('deviceId: $deviceId, ')
          ..write('deviceName: $deviceName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    contentHash,
    mediaKind,
    locator,
    progressRatio,
    updatedAtMs,
    lastSyncedAtMs,
    deviceId,
    deviceName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncState &&
          other.contentHash == this.contentHash &&
          other.mediaKind == this.mediaKind &&
          other.locator == this.locator &&
          other.progressRatio == this.progressRatio &&
          other.updatedAtMs == this.updatedAtMs &&
          other.lastSyncedAtMs == this.lastSyncedAtMs &&
          other.deviceId == this.deviceId &&
          other.deviceName == this.deviceName);
}

class SyncStatesCompanion extends UpdateCompanion<SyncState> {
  final Value<String> contentHash;
  final Value<String> mediaKind;
  final Value<String> locator;
  final Value<double> progressRatio;
  final Value<int> updatedAtMs;
  final Value<int> lastSyncedAtMs;
  final Value<String> deviceId;
  final Value<String> deviceName;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.contentHash = const Value.absent(),
    this.mediaKind = const Value.absent(),
    this.locator = const Value.absent(),
    this.progressRatio = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.lastSyncedAtMs = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deviceName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String contentHash,
    required String mediaKind,
    required String locator,
    this.progressRatio = const Value.absent(),
    required int updatedAtMs,
    this.lastSyncedAtMs = const Value.absent(),
    required String deviceId,
    required String deviceName,
    this.rowid = const Value.absent(),
  }) : contentHash = Value(contentHash),
       mediaKind = Value(mediaKind),
       locator = Value(locator),
       updatedAtMs = Value(updatedAtMs),
       deviceId = Value(deviceId),
       deviceName = Value(deviceName);
  static Insertable<SyncState> custom({
    Expression<String>? contentHash,
    Expression<String>? mediaKind,
    Expression<String>? locator,
    Expression<double>? progressRatio,
    Expression<int>? updatedAtMs,
    Expression<int>? lastSyncedAtMs,
    Expression<String>? deviceId,
    Expression<String>? deviceName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (contentHash != null) 'content_hash': contentHash,
      if (mediaKind != null) 'media_kind': mediaKind,
      if (locator != null) 'locator': locator,
      if (progressRatio != null) 'progress_ratio': progressRatio,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (lastSyncedAtMs != null) 'last_synced_at_ms': lastSyncedAtMs,
      if (deviceId != null) 'device_id': deviceId,
      if (deviceName != null) 'device_name': deviceName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith({
    Value<String>? contentHash,
    Value<String>? mediaKind,
    Value<String>? locator,
    Value<double>? progressRatio,
    Value<int>? updatedAtMs,
    Value<int>? lastSyncedAtMs,
    Value<String>? deviceId,
    Value<String>? deviceName,
    Value<int>? rowid,
  }) {
    return SyncStatesCompanion(
      contentHash: contentHash ?? this.contentHash,
      mediaKind: mediaKind ?? this.mediaKind,
      locator: locator ?? this.locator,
      progressRatio: progressRatio ?? this.progressRatio,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      lastSyncedAtMs: lastSyncedAtMs ?? this.lastSyncedAtMs,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (mediaKind.present) {
      map['media_kind'] = Variable<String>(mediaKind.value);
    }
    if (locator.present) {
      map['locator'] = Variable<String>(locator.value);
    }
    if (progressRatio.present) {
      map['progress_ratio'] = Variable<double>(progressRatio.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (lastSyncedAtMs.present) {
      map['last_synced_at_ms'] = Variable<int>(lastSyncedAtMs.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deviceName.present) {
      map['device_name'] = Variable<String>(deviceName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('contentHash: $contentHash, ')
          ..write('mediaKind: $mediaKind, ')
          ..write('locator: $locator, ')
          ..write('progressRatio: $progressRatio, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('lastSyncedAtMs: $lastSyncedAtMs, ')
          ..write('deviceId: $deviceId, ')
          ..write('deviceName: $deviceName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShelvesTable extends Shelves with TableInfo<$ShelvesTable, Shelf> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShelvesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaKindMeta = const VerificationMeta(
    'mediaKind',
  );
  @override
  late final GeneratedColumn<String> mediaKind = GeneratedColumn<String>(
    'media_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    mediaKind,
    isDefault,
    sortOrder,
    createdAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shelves';
  @override
  VerificationContext validateIntegrity(
    Insertable<Shelf> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('media_kind')) {
      context.handle(
        _mediaKindMeta,
        mediaKind.isAcceptableOrUnknown(data['media_kind']!, _mediaKindMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaKindMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name, mediaKind},
  ];
  @override
  Shelf map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Shelf(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      mediaKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_kind'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $ShelvesTable createAlias(String alias) {
    return $ShelvesTable(attachedDatabase, alias);
  }
}

class Shelf extends DataClass implements Insertable<Shelf> {
  final int id;
  final String name;
  final String mediaKind;
  final bool isDefault;
  final int sortOrder;
  final int createdAtMs;
  const Shelf({
    required this.id,
    required this.name,
    required this.mediaKind,
    required this.isDefault,
    required this.sortOrder,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['media_kind'] = Variable<String>(mediaKind);
    map['is_default'] = Variable<bool>(isDefault);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  ShelvesCompanion toCompanion(bool nullToAbsent) {
    return ShelvesCompanion(
      id: Value(id),
      name: Value(name),
      mediaKind: Value(mediaKind),
      isDefault: Value(isDefault),
      sortOrder: Value(sortOrder),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory Shelf.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Shelf(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      mediaKind: serializer.fromJson<String>(json['mediaKind']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'mediaKind': serializer.toJson<String>(mediaKind),
      'isDefault': serializer.toJson<bool>(isDefault),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  Shelf copyWith({
    int? id,
    String? name,
    String? mediaKind,
    bool? isDefault,
    int? sortOrder,
    int? createdAtMs,
  }) => Shelf(
    id: id ?? this.id,
    name: name ?? this.name,
    mediaKind: mediaKind ?? this.mediaKind,
    isDefault: isDefault ?? this.isDefault,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  Shelf copyWithCompanion(ShelvesCompanion data) {
    return Shelf(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      mediaKind: data.mediaKind.present ? data.mediaKind.value : this.mediaKind,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Shelf(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('mediaKind: $mediaKind, ')
          ..write('isDefault: $isDefault, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, mediaKind, isDefault, sortOrder, createdAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Shelf &&
          other.id == this.id &&
          other.name == this.name &&
          other.mediaKind == this.mediaKind &&
          other.isDefault == this.isDefault &&
          other.sortOrder == this.sortOrder &&
          other.createdAtMs == this.createdAtMs);
}

class ShelvesCompanion extends UpdateCompanion<Shelf> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> mediaKind;
  final Value<bool> isDefault;
  final Value<int> sortOrder;
  final Value<int> createdAtMs;
  const ShelvesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.mediaKind = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAtMs = const Value.absent(),
  });
  ShelvesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String mediaKind,
    this.isDefault = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int createdAtMs,
  }) : name = Value(name),
       mediaKind = Value(mediaKind),
       createdAtMs = Value(createdAtMs);
  static Insertable<Shelf> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? mediaKind,
    Expression<bool>? isDefault,
    Expression<int>? sortOrder,
    Expression<int>? createdAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (mediaKind != null) 'media_kind': mediaKind,
      if (isDefault != null) 'is_default': isDefault,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
    });
  }

  ShelvesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? mediaKind,
    Value<bool>? isDefault,
    Value<int>? sortOrder,
    Value<int>? createdAtMs,
  }) {
    return ShelvesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      mediaKind: mediaKind ?? this.mediaKind,
      isDefault: isDefault ?? this.isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (mediaKind.present) {
      map['media_kind'] = Variable<String>(mediaKind.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShelvesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('mediaKind: $mediaKind, ')
          ..write('isDefault: $isDefault, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }
}

class $TocRulesTable extends TocRules with TableInfo<$TocRulesTable, TocRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TocRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ruleMeta = const VerificationMeta('rule');
  @override
  late final GeneratedColumn<String> rule = GeneratedColumn<String>(
    'rule',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exampleMeta = const VerificationMeta(
    'example',
  );
  @override
  late final GeneratedColumn<String> example = GeneratedColumn<String>(
    'example',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _serialNumberMeta = const VerificationMeta(
    'serialNumber',
  );
  @override
  late final GeneratedColumn<int> serialNumber = GeneratedColumn<int>(
    'serial_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isBuiltinMeta = const VerificationMeta(
    'isBuiltin',
  );
  @override
  late final GeneratedColumn<bool> isBuiltin = GeneratedColumn<bool>(
    'is_builtin',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_builtin" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    rule,
    example,
    enabled,
    serialNumber,
    isBuiltin,
    createdAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'toc_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<TocRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('rule')) {
      context.handle(
        _ruleMeta,
        rule.isAcceptableOrUnknown(data['rule']!, _ruleMeta),
      );
    } else if (isInserting) {
      context.missing(_ruleMeta);
    }
    if (data.containsKey('example')) {
      context.handle(
        _exampleMeta,
        example.isAcceptableOrUnknown(data['example']!, _exampleMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('serial_number')) {
      context.handle(
        _serialNumberMeta,
        serialNumber.isAcceptableOrUnknown(
          data['serial_number']!,
          _serialNumberMeta,
        ),
      );
    }
    if (data.containsKey('is_builtin')) {
      context.handle(
        _isBuiltinMeta,
        isBuiltin.isAcceptableOrUnknown(data['is_builtin']!, _isBuiltinMeta),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TocRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TocRule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      rule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule'],
      )!,
      example: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}example'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      serialNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}serial_number'],
      )!,
      isBuiltin: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_builtin'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $TocRulesTable createAlias(String alias) {
    return $TocRulesTable(attachedDatabase, alias);
  }
}

class TocRule extends DataClass implements Insertable<TocRule> {
  final int id;
  final String name;
  final String rule;
  final String example;
  final bool enabled;
  final int serialNumber;
  final bool isBuiltin;
  final int createdAtMs;
  const TocRule({
    required this.id,
    required this.name,
    required this.rule,
    required this.example,
    required this.enabled,
    required this.serialNumber,
    required this.isBuiltin,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['rule'] = Variable<String>(rule);
    map['example'] = Variable<String>(example);
    map['enabled'] = Variable<bool>(enabled);
    map['serial_number'] = Variable<int>(serialNumber);
    map['is_builtin'] = Variable<bool>(isBuiltin);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  TocRulesCompanion toCompanion(bool nullToAbsent) {
    return TocRulesCompanion(
      id: Value(id),
      name: Value(name),
      rule: Value(rule),
      example: Value(example),
      enabled: Value(enabled),
      serialNumber: Value(serialNumber),
      isBuiltin: Value(isBuiltin),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory TocRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TocRule(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      rule: serializer.fromJson<String>(json['rule']),
      example: serializer.fromJson<String>(json['example']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      serialNumber: serializer.fromJson<int>(json['serialNumber']),
      isBuiltin: serializer.fromJson<bool>(json['isBuiltin']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'rule': serializer.toJson<String>(rule),
      'example': serializer.toJson<String>(example),
      'enabled': serializer.toJson<bool>(enabled),
      'serialNumber': serializer.toJson<int>(serialNumber),
      'isBuiltin': serializer.toJson<bool>(isBuiltin),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  TocRule copyWith({
    int? id,
    String? name,
    String? rule,
    String? example,
    bool? enabled,
    int? serialNumber,
    bool? isBuiltin,
    int? createdAtMs,
  }) => TocRule(
    id: id ?? this.id,
    name: name ?? this.name,
    rule: rule ?? this.rule,
    example: example ?? this.example,
    enabled: enabled ?? this.enabled,
    serialNumber: serialNumber ?? this.serialNumber,
    isBuiltin: isBuiltin ?? this.isBuiltin,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  TocRule copyWithCompanion(TocRulesCompanion data) {
    return TocRule(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      rule: data.rule.present ? data.rule.value : this.rule,
      example: data.example.present ? data.example.value : this.example,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      serialNumber: data.serialNumber.present
          ? data.serialNumber.value
          : this.serialNumber,
      isBuiltin: data.isBuiltin.present ? data.isBuiltin.value : this.isBuiltin,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TocRule(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rule: $rule, ')
          ..write('example: $example, ')
          ..write('enabled: $enabled, ')
          ..write('serialNumber: $serialNumber, ')
          ..write('isBuiltin: $isBuiltin, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    rule,
    example,
    enabled,
    serialNumber,
    isBuiltin,
    createdAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TocRule &&
          other.id == this.id &&
          other.name == this.name &&
          other.rule == this.rule &&
          other.example == this.example &&
          other.enabled == this.enabled &&
          other.serialNumber == this.serialNumber &&
          other.isBuiltin == this.isBuiltin &&
          other.createdAtMs == this.createdAtMs);
}

class TocRulesCompanion extends UpdateCompanion<TocRule> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> rule;
  final Value<String> example;
  final Value<bool> enabled;
  final Value<int> serialNumber;
  final Value<bool> isBuiltin;
  final Value<int> createdAtMs;
  const TocRulesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.rule = const Value.absent(),
    this.example = const Value.absent(),
    this.enabled = const Value.absent(),
    this.serialNumber = const Value.absent(),
    this.isBuiltin = const Value.absent(),
    this.createdAtMs = const Value.absent(),
  });
  TocRulesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String rule,
    this.example = const Value.absent(),
    this.enabled = const Value.absent(),
    this.serialNumber = const Value.absent(),
    this.isBuiltin = const Value.absent(),
    required int createdAtMs,
  }) : name = Value(name),
       rule = Value(rule),
       createdAtMs = Value(createdAtMs);
  static Insertable<TocRule> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? rule,
    Expression<String>? example,
    Expression<bool>? enabled,
    Expression<int>? serialNumber,
    Expression<bool>? isBuiltin,
    Expression<int>? createdAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (rule != null) 'rule': rule,
      if (example != null) 'example': example,
      if (enabled != null) 'enabled': enabled,
      if (serialNumber != null) 'serial_number': serialNumber,
      if (isBuiltin != null) 'is_builtin': isBuiltin,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
    });
  }

  TocRulesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? rule,
    Value<String>? example,
    Value<bool>? enabled,
    Value<int>? serialNumber,
    Value<bool>? isBuiltin,
    Value<int>? createdAtMs,
  }) {
    return TocRulesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      rule: rule ?? this.rule,
      example: example ?? this.example,
      enabled: enabled ?? this.enabled,
      serialNumber: serialNumber ?? this.serialNumber,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rule.present) {
      map['rule'] = Variable<String>(rule.value);
    }
    if (example.present) {
      map['example'] = Variable<String>(example.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (serialNumber.present) {
      map['serial_number'] = Variable<int>(serialNumber.value);
    }
    if (isBuiltin.present) {
      map['is_builtin'] = Variable<bool>(isBuiltin.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TocRulesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rule: $rule, ')
          ..write('example: $example, ')
          ..write('enabled: $enabled, ')
          ..write('serialNumber: $serialNumber, ')
          ..write('isBuiltin: $isBuiltin, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $MangasTable mangas = $MangasTable(this);
  late final $MangaChaptersTable mangaChapters = $MangaChaptersTable(this);
  late final $AnnotationsTable annotations = $AnnotationsTable(this);
  late final $WatchedFoldersTable watchedFolders = $WatchedFoldersTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final $ShelvesTable shelves = $ShelvesTable(this);
  late final $TocRulesTable tocRules = $TocRulesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    mangas,
    mangaChapters,
    annotations,
    watchedFolders,
    syncStates,
    shelves,
    tocRules,
  ];
}

typedef $$BooksTableCreateCompanionBuilder =
    BooksCompanion Function({
      Value<int> id,
      required String contentHash,
      required String title,
      Value<String> author,
      required String format,
      required String filePath,
      Value<String?> coverPath,
      Value<int?> shelfId,
      Value<String> shelfGroup,
      Value<double> progressRatio,
      Value<int> currentChapterIndex,
      Value<int> currentCharOffset,
      Value<String> currentChapterTitle,
      Value<int> readingTimeSec,
      Value<bool> isPinned,
      Value<bool> cloudFileSynced,
      Value<bool> isArchived,
      Value<int?> tocRuleId,
      Value<String?> forcedEncoding,
      required int addedAtMs,
      required int lastReadAtMs,
    });
typedef $$BooksTableUpdateCompanionBuilder =
    BooksCompanion Function({
      Value<int> id,
      Value<String> contentHash,
      Value<String> title,
      Value<String> author,
      Value<String> format,
      Value<String> filePath,
      Value<String?> coverPath,
      Value<int?> shelfId,
      Value<String> shelfGroup,
      Value<double> progressRatio,
      Value<int> currentChapterIndex,
      Value<int> currentCharOffset,
      Value<String> currentChapterTitle,
      Value<int> readingTimeSec,
      Value<bool> isPinned,
      Value<bool> cloudFileSynced,
      Value<bool> isArchived,
      Value<int?> tocRuleId,
      Value<String?> forcedEncoding,
      Value<int> addedAtMs,
      Value<int> lastReadAtMs,
    });

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shelfId => $composableBuilder(
    column: $table.shelfId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shelfGroup => $composableBuilder(
    column: $table.shelfGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progressRatio => $composableBuilder(
    column: $table.progressRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentChapterIndex => $composableBuilder(
    column: $table.currentChapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentCharOffset => $composableBuilder(
    column: $table.currentCharOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentChapterTitle => $composableBuilder(
    column: $table.currentChapterTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readingTimeSec => $composableBuilder(
    column: $table.readingTimeSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get cloudFileSynced => $composableBuilder(
    column: $table.cloudFileSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tocRuleId => $composableBuilder(
    column: $table.tocRuleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get forcedEncoding => $composableBuilder(
    column: $table.forcedEncoding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAtMs => $composableBuilder(
    column: $table.addedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReadAtMs => $composableBuilder(
    column: $table.lastReadAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shelfId => $composableBuilder(
    column: $table.shelfId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shelfGroup => $composableBuilder(
    column: $table.shelfGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progressRatio => $composableBuilder(
    column: $table.progressRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentChapterIndex => $composableBuilder(
    column: $table.currentChapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentCharOffset => $composableBuilder(
    column: $table.currentCharOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentChapterTitle => $composableBuilder(
    column: $table.currentChapterTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readingTimeSec => $composableBuilder(
    column: $table.readingTimeSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get cloudFileSynced => $composableBuilder(
    column: $table.cloudFileSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tocRuleId => $composableBuilder(
    column: $table.tocRuleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get forcedEncoding => $composableBuilder(
    column: $table.forcedEncoding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAtMs => $composableBuilder(
    column: $table.addedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReadAtMs => $composableBuilder(
    column: $table.lastReadAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<int> get shelfId =>
      $composableBuilder(column: $table.shelfId, builder: (column) => column);

  GeneratedColumn<String> get shelfGroup => $composableBuilder(
    column: $table.shelfGroup,
    builder: (column) => column,
  );

  GeneratedColumn<double> get progressRatio => $composableBuilder(
    column: $table.progressRatio,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentChapterIndex => $composableBuilder(
    column: $table.currentChapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentCharOffset => $composableBuilder(
    column: $table.currentCharOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currentChapterTitle => $composableBuilder(
    column: $table.currentChapterTitle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get readingTimeSec => $composableBuilder(
    column: $table.readingTimeSec,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get cloudFileSynced => $composableBuilder(
    column: $table.cloudFileSynced,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tocRuleId =>
      $composableBuilder(column: $table.tocRuleId, builder: (column) => column);

  GeneratedColumn<String> get forcedEncoding => $composableBuilder(
    column: $table.forcedEncoding,
    builder: (column) => column,
  );

  GeneratedColumn<int> get addedAtMs =>
      $composableBuilder(column: $table.addedAtMs, builder: (column) => column);

  GeneratedColumn<int> get lastReadAtMs => $composableBuilder(
    column: $table.lastReadAtMs,
    builder: (column) => column,
  );
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTable,
          Book,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (Book, BaseReferences<_$AppDatabase, $BooksTable, Book>),
          Book,
          PrefetchHooks Function()
        > {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<int?> shelfId = const Value.absent(),
                Value<String> shelfGroup = const Value.absent(),
                Value<double> progressRatio = const Value.absent(),
                Value<int> currentChapterIndex = const Value.absent(),
                Value<int> currentCharOffset = const Value.absent(),
                Value<String> currentChapterTitle = const Value.absent(),
                Value<int> readingTimeSec = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> cloudFileSynced = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int?> tocRuleId = const Value.absent(),
                Value<String?> forcedEncoding = const Value.absent(),
                Value<int> addedAtMs = const Value.absent(),
                Value<int> lastReadAtMs = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                contentHash: contentHash,
                title: title,
                author: author,
                format: format,
                filePath: filePath,
                coverPath: coverPath,
                shelfId: shelfId,
                shelfGroup: shelfGroup,
                progressRatio: progressRatio,
                currentChapterIndex: currentChapterIndex,
                currentCharOffset: currentCharOffset,
                currentChapterTitle: currentChapterTitle,
                readingTimeSec: readingTimeSec,
                isPinned: isPinned,
                cloudFileSynced: cloudFileSynced,
                isArchived: isArchived,
                tocRuleId: tocRuleId,
                forcedEncoding: forcedEncoding,
                addedAtMs: addedAtMs,
                lastReadAtMs: lastReadAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String contentHash,
                required String title,
                Value<String> author = const Value.absent(),
                required String format,
                required String filePath,
                Value<String?> coverPath = const Value.absent(),
                Value<int?> shelfId = const Value.absent(),
                Value<String> shelfGroup = const Value.absent(),
                Value<double> progressRatio = const Value.absent(),
                Value<int> currentChapterIndex = const Value.absent(),
                Value<int> currentCharOffset = const Value.absent(),
                Value<String> currentChapterTitle = const Value.absent(),
                Value<int> readingTimeSec = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> cloudFileSynced = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int?> tocRuleId = const Value.absent(),
                Value<String?> forcedEncoding = const Value.absent(),
                required int addedAtMs,
                required int lastReadAtMs,
              }) => BooksCompanion.insert(
                id: id,
                contentHash: contentHash,
                title: title,
                author: author,
                format: format,
                filePath: filePath,
                coverPath: coverPath,
                shelfId: shelfId,
                shelfGroup: shelfGroup,
                progressRatio: progressRatio,
                currentChapterIndex: currentChapterIndex,
                currentCharOffset: currentCharOffset,
                currentChapterTitle: currentChapterTitle,
                readingTimeSec: readingTimeSec,
                isPinned: isPinned,
                cloudFileSynced: cloudFileSynced,
                isArchived: isArchived,
                tocRuleId: tocRuleId,
                forcedEncoding: forcedEncoding,
                addedAtMs: addedAtMs,
                lastReadAtMs: lastReadAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTable,
      Book,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (Book, BaseReferences<_$AppDatabase, $BooksTable, Book>),
      Book,
      PrefetchHooks Function()
    >;
typedef $$MangasTableCreateCompanionBuilder =
    MangasCompanion Function({
      Value<int> id,
      required String contentHash,
      required String title,
      Value<String> author,
      required String format,
      required String rootPath,
      Value<String?> coverPath,
      Value<int?> shelfId,
      Value<String> shelfGroup,
      Value<int> unreadCount,
      Value<int> totalChapters,
      Value<String> preferredReadingMode,
      Value<bool> autoCrop,
      Value<bool> splitWidePages,
      Value<bool> isPinned,
      Value<bool> cloudFileSynced,
      Value<bool> isArchived,
      required int addedAtMs,
      required int lastReadAtMs,
    });
typedef $$MangasTableUpdateCompanionBuilder =
    MangasCompanion Function({
      Value<int> id,
      Value<String> contentHash,
      Value<String> title,
      Value<String> author,
      Value<String> format,
      Value<String> rootPath,
      Value<String?> coverPath,
      Value<int?> shelfId,
      Value<String> shelfGroup,
      Value<int> unreadCount,
      Value<int> totalChapters,
      Value<String> preferredReadingMode,
      Value<bool> autoCrop,
      Value<bool> splitWidePages,
      Value<bool> isPinned,
      Value<bool> cloudFileSynced,
      Value<bool> isArchived,
      Value<int> addedAtMs,
      Value<int> lastReadAtMs,
    });

class $$MangasTableFilterComposer
    extends Composer<_$AppDatabase, $MangasTable> {
  $$MangasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootPath => $composableBuilder(
    column: $table.rootPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shelfId => $composableBuilder(
    column: $table.shelfId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shelfGroup => $composableBuilder(
    column: $table.shelfGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredReadingMode => $composableBuilder(
    column: $table.preferredReadingMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoCrop => $composableBuilder(
    column: $table.autoCrop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get splitWidePages => $composableBuilder(
    column: $table.splitWidePages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get cloudFileSynced => $composableBuilder(
    column: $table.cloudFileSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAtMs => $composableBuilder(
    column: $table.addedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReadAtMs => $composableBuilder(
    column: $table.lastReadAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MangasTableOrderingComposer
    extends Composer<_$AppDatabase, $MangasTable> {
  $$MangasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootPath => $composableBuilder(
    column: $table.rootPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shelfId => $composableBuilder(
    column: $table.shelfId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shelfGroup => $composableBuilder(
    column: $table.shelfGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredReadingMode => $composableBuilder(
    column: $table.preferredReadingMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoCrop => $composableBuilder(
    column: $table.autoCrop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get splitWidePages => $composableBuilder(
    column: $table.splitWidePages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get cloudFileSynced => $composableBuilder(
    column: $table.cloudFileSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAtMs => $composableBuilder(
    column: $table.addedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReadAtMs => $composableBuilder(
    column: $table.lastReadAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MangasTableAnnotationComposer
    extends Composer<_$AppDatabase, $MangasTable> {
  $$MangasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get rootPath =>
      $composableBuilder(column: $table.rootPath, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<int> get shelfId =>
      $composableBuilder(column: $table.shelfId, builder: (column) => column);

  GeneratedColumn<String> get shelfGroup => $composableBuilder(
    column: $table.shelfGroup,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredReadingMode => $composableBuilder(
    column: $table.preferredReadingMode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoCrop =>
      $composableBuilder(column: $table.autoCrop, builder: (column) => column);

  GeneratedColumn<bool> get splitWidePages => $composableBuilder(
    column: $table.splitWidePages,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get cloudFileSynced => $composableBuilder(
    column: $table.cloudFileSynced,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<int> get addedAtMs =>
      $composableBuilder(column: $table.addedAtMs, builder: (column) => column);

  GeneratedColumn<int> get lastReadAtMs => $composableBuilder(
    column: $table.lastReadAtMs,
    builder: (column) => column,
  );
}

class $$MangasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MangasTable,
          Manga,
          $$MangasTableFilterComposer,
          $$MangasTableOrderingComposer,
          $$MangasTableAnnotationComposer,
          $$MangasTableCreateCompanionBuilder,
          $$MangasTableUpdateCompanionBuilder,
          (Manga, BaseReferences<_$AppDatabase, $MangasTable, Manga>),
          Manga,
          PrefetchHooks Function()
        > {
  $$MangasTableTableManager(_$AppDatabase db, $MangasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MangasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MangasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MangasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> rootPath = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<int?> shelfId = const Value.absent(),
                Value<String> shelfGroup = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<int> totalChapters = const Value.absent(),
                Value<String> preferredReadingMode = const Value.absent(),
                Value<bool> autoCrop = const Value.absent(),
                Value<bool> splitWidePages = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> cloudFileSynced = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> addedAtMs = const Value.absent(),
                Value<int> lastReadAtMs = const Value.absent(),
              }) => MangasCompanion(
                id: id,
                contentHash: contentHash,
                title: title,
                author: author,
                format: format,
                rootPath: rootPath,
                coverPath: coverPath,
                shelfId: shelfId,
                shelfGroup: shelfGroup,
                unreadCount: unreadCount,
                totalChapters: totalChapters,
                preferredReadingMode: preferredReadingMode,
                autoCrop: autoCrop,
                splitWidePages: splitWidePages,
                isPinned: isPinned,
                cloudFileSynced: cloudFileSynced,
                isArchived: isArchived,
                addedAtMs: addedAtMs,
                lastReadAtMs: lastReadAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String contentHash,
                required String title,
                Value<String> author = const Value.absent(),
                required String format,
                required String rootPath,
                Value<String?> coverPath = const Value.absent(),
                Value<int?> shelfId = const Value.absent(),
                Value<String> shelfGroup = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<int> totalChapters = const Value.absent(),
                Value<String> preferredReadingMode = const Value.absent(),
                Value<bool> autoCrop = const Value.absent(),
                Value<bool> splitWidePages = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> cloudFileSynced = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                required int addedAtMs,
                required int lastReadAtMs,
              }) => MangasCompanion.insert(
                id: id,
                contentHash: contentHash,
                title: title,
                author: author,
                format: format,
                rootPath: rootPath,
                coverPath: coverPath,
                shelfId: shelfId,
                shelfGroup: shelfGroup,
                unreadCount: unreadCount,
                totalChapters: totalChapters,
                preferredReadingMode: preferredReadingMode,
                autoCrop: autoCrop,
                splitWidePages: splitWidePages,
                isPinned: isPinned,
                cloudFileSynced: cloudFileSynced,
                isArchived: isArchived,
                addedAtMs: addedAtMs,
                lastReadAtMs: lastReadAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MangasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MangasTable,
      Manga,
      $$MangasTableFilterComposer,
      $$MangasTableOrderingComposer,
      $$MangasTableAnnotationComposer,
      $$MangasTableCreateCompanionBuilder,
      $$MangasTableUpdateCompanionBuilder,
      (Manga, BaseReferences<_$AppDatabase, $MangasTable, Manga>),
      Manga,
      PrefetchHooks Function()
    >;
typedef $$MangaChaptersTableCreateCompanionBuilder =
    MangaChaptersCompanion Function({
      Value<int> id,
      required int mangaId,
      required String title,
      required int chapterIndex,
      required String sourcePath,
      Value<int> pageCount,
      Value<int> lastReadPage,
      Value<bool> isRead,
      required int updatedAtMs,
    });
typedef $$MangaChaptersTableUpdateCompanionBuilder =
    MangaChaptersCompanion Function({
      Value<int> id,
      Value<int> mangaId,
      Value<String> title,
      Value<int> chapterIndex,
      Value<String> sourcePath,
      Value<int> pageCount,
      Value<int> lastReadPage,
      Value<bool> isRead,
      Value<int> updatedAtMs,
    });

class $$MangaChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $MangaChaptersTable> {
  $$MangaChaptersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mangaId => $composableBuilder(
    column: $table.mangaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReadPage => $composableBuilder(
    column: $table.lastReadPage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MangaChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $MangaChaptersTable> {
  $$MangaChaptersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mangaId => $composableBuilder(
    column: $table.mangaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReadPage => $composableBuilder(
    column: $table.lastReadPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MangaChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $MangaChaptersTable> {
  $$MangaChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get mangaId =>
      $composableBuilder(column: $table.mangaId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<int> get lastReadPage => $composableBuilder(
    column: $table.lastReadPage,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );
}

class $$MangaChaptersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MangaChaptersTable,
          MangaChapter,
          $$MangaChaptersTableFilterComposer,
          $$MangaChaptersTableOrderingComposer,
          $$MangaChaptersTableAnnotationComposer,
          $$MangaChaptersTableCreateCompanionBuilder,
          $$MangaChaptersTableUpdateCompanionBuilder,
          (
            MangaChapter,
            BaseReferences<_$AppDatabase, $MangaChaptersTable, MangaChapter>,
          ),
          MangaChapter,
          PrefetchHooks Function()
        > {
  $$MangaChaptersTableTableManager(_$AppDatabase db, $MangaChaptersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MangaChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MangaChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MangaChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> mangaId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<String> sourcePath = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<int> lastReadPage = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
              }) => MangaChaptersCompanion(
                id: id,
                mangaId: mangaId,
                title: title,
                chapterIndex: chapterIndex,
                sourcePath: sourcePath,
                pageCount: pageCount,
                lastReadPage: lastReadPage,
                isRead: isRead,
                updatedAtMs: updatedAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int mangaId,
                required String title,
                required int chapterIndex,
                required String sourcePath,
                Value<int> pageCount = const Value.absent(),
                Value<int> lastReadPage = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                required int updatedAtMs,
              }) => MangaChaptersCompanion.insert(
                id: id,
                mangaId: mangaId,
                title: title,
                chapterIndex: chapterIndex,
                sourcePath: sourcePath,
                pageCount: pageCount,
                lastReadPage: lastReadPage,
                isRead: isRead,
                updatedAtMs: updatedAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MangaChaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MangaChaptersTable,
      MangaChapter,
      $$MangaChaptersTableFilterComposer,
      $$MangaChaptersTableOrderingComposer,
      $$MangaChaptersTableAnnotationComposer,
      $$MangaChaptersTableCreateCompanionBuilder,
      $$MangaChaptersTableUpdateCompanionBuilder,
      (
        MangaChapter,
        BaseReferences<_$AppDatabase, $MangaChaptersTable, MangaChapter>,
      ),
      MangaChapter,
      PrefetchHooks Function()
    >;
typedef $$AnnotationsTableCreateCompanionBuilder =
    AnnotationsCompanion Function({
      Value<int> id,
      required String uuid,
      required String contentHash,
      required String mediaKind,
      required String kind,
      Value<int> chapterIndex,
      required String locator,
      Value<String> excerpt,
      Value<String> noteText,
      Value<String> colorHex,
      Value<bool> isDeleted,
      required int updatedAtMs,
    });
typedef $$AnnotationsTableUpdateCompanionBuilder =
    AnnotationsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> contentHash,
      Value<String> mediaKind,
      Value<String> kind,
      Value<int> chapterIndex,
      Value<String> locator,
      Value<String> excerpt,
      Value<String> noteText,
      Value<String> colorHex,
      Value<bool> isDeleted,
      Value<int> updatedAtMs,
    });

class $$AnnotationsTableFilterComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get excerpt => $composableBuilder(
    column: $table.excerpt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteText => $composableBuilder(
    column: $table.noteText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AnnotationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get excerpt => $composableBuilder(
    column: $table.excerpt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteText => $composableBuilder(
    column: $table.noteText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnnotationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaKind =>
      $composableBuilder(column: $table.mediaKind, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locator =>
      $composableBuilder(column: $table.locator, builder: (column) => column);

  GeneratedColumn<String> get excerpt =>
      $composableBuilder(column: $table.excerpt, builder: (column) => column);

  GeneratedColumn<String> get noteText =>
      $composableBuilder(column: $table.noteText, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );
}

class $$AnnotationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnnotationsTable,
          Annotation,
          $$AnnotationsTableFilterComposer,
          $$AnnotationsTableOrderingComposer,
          $$AnnotationsTableAnnotationComposer,
          $$AnnotationsTableCreateCompanionBuilder,
          $$AnnotationsTableUpdateCompanionBuilder,
          (
            Annotation,
            BaseReferences<_$AppDatabase, $AnnotationsTable, Annotation>,
          ),
          Annotation,
          PrefetchHooks Function()
        > {
  $$AnnotationsTableTableManager(_$AppDatabase db, $AnnotationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnnotationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnnotationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnnotationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<String> mediaKind = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<String> locator = const Value.absent(),
                Value<String> excerpt = const Value.absent(),
                Value<String> noteText = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
              }) => AnnotationsCompanion(
                id: id,
                uuid: uuid,
                contentHash: contentHash,
                mediaKind: mediaKind,
                kind: kind,
                chapterIndex: chapterIndex,
                locator: locator,
                excerpt: excerpt,
                noteText: noteText,
                colorHex: colorHex,
                isDeleted: isDeleted,
                updatedAtMs: updatedAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String contentHash,
                required String mediaKind,
                required String kind,
                Value<int> chapterIndex = const Value.absent(),
                required String locator,
                Value<String> excerpt = const Value.absent(),
                Value<String> noteText = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                required int updatedAtMs,
              }) => AnnotationsCompanion.insert(
                id: id,
                uuid: uuid,
                contentHash: contentHash,
                mediaKind: mediaKind,
                kind: kind,
                chapterIndex: chapterIndex,
                locator: locator,
                excerpt: excerpt,
                noteText: noteText,
                colorHex: colorHex,
                isDeleted: isDeleted,
                updatedAtMs: updatedAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnnotationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnnotationsTable,
      Annotation,
      $$AnnotationsTableFilterComposer,
      $$AnnotationsTableOrderingComposer,
      $$AnnotationsTableAnnotationComposer,
      $$AnnotationsTableCreateCompanionBuilder,
      $$AnnotationsTableUpdateCompanionBuilder,
      (
        Annotation,
        BaseReferences<_$AppDatabase, $AnnotationsTable, Annotation>,
      ),
      Annotation,
      PrefetchHooks Function()
    >;
typedef $$WatchedFoldersTableCreateCompanionBuilder =
    WatchedFoldersCompanion Function({
      Value<int> id,
      required String uriOrPath,
      required String displayName,
      Value<String> defaultKind,
      Value<int> lastScannedAtMs,
    });
typedef $$WatchedFoldersTableUpdateCompanionBuilder =
    WatchedFoldersCompanion Function({
      Value<int> id,
      Value<String> uriOrPath,
      Value<String> displayName,
      Value<String> defaultKind,
      Value<int> lastScannedAtMs,
    });

class $$WatchedFoldersTableFilterComposer
    extends Composer<_$AppDatabase, $WatchedFoldersTable> {
  $$WatchedFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uriOrPath => $composableBuilder(
    column: $table.uriOrPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultKind => $composableBuilder(
    column: $table.defaultKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastScannedAtMs => $composableBuilder(
    column: $table.lastScannedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WatchedFoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchedFoldersTable> {
  $$WatchedFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uriOrPath => $composableBuilder(
    column: $table.uriOrPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultKind => $composableBuilder(
    column: $table.defaultKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastScannedAtMs => $composableBuilder(
    column: $table.lastScannedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchedFoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchedFoldersTable> {
  $$WatchedFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uriOrPath =>
      $composableBuilder(column: $table.uriOrPath, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultKind => $composableBuilder(
    column: $table.defaultKind,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastScannedAtMs => $composableBuilder(
    column: $table.lastScannedAtMs,
    builder: (column) => column,
  );
}

class $$WatchedFoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchedFoldersTable,
          WatchedFolder,
          $$WatchedFoldersTableFilterComposer,
          $$WatchedFoldersTableOrderingComposer,
          $$WatchedFoldersTableAnnotationComposer,
          $$WatchedFoldersTableCreateCompanionBuilder,
          $$WatchedFoldersTableUpdateCompanionBuilder,
          (
            WatchedFolder,
            BaseReferences<_$AppDatabase, $WatchedFoldersTable, WatchedFolder>,
          ),
          WatchedFolder,
          PrefetchHooks Function()
        > {
  $$WatchedFoldersTableTableManager(
    _$AppDatabase db,
    $WatchedFoldersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchedFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchedFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchedFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uriOrPath = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> defaultKind = const Value.absent(),
                Value<int> lastScannedAtMs = const Value.absent(),
              }) => WatchedFoldersCompanion(
                id: id,
                uriOrPath: uriOrPath,
                displayName: displayName,
                defaultKind: defaultKind,
                lastScannedAtMs: lastScannedAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uriOrPath,
                required String displayName,
                Value<String> defaultKind = const Value.absent(),
                Value<int> lastScannedAtMs = const Value.absent(),
              }) => WatchedFoldersCompanion.insert(
                id: id,
                uriOrPath: uriOrPath,
                displayName: displayName,
                defaultKind: defaultKind,
                lastScannedAtMs: lastScannedAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WatchedFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchedFoldersTable,
      WatchedFolder,
      $$WatchedFoldersTableFilterComposer,
      $$WatchedFoldersTableOrderingComposer,
      $$WatchedFoldersTableAnnotationComposer,
      $$WatchedFoldersTableCreateCompanionBuilder,
      $$WatchedFoldersTableUpdateCompanionBuilder,
      (
        WatchedFolder,
        BaseReferences<_$AppDatabase, $WatchedFoldersTable, WatchedFolder>,
      ),
      WatchedFolder,
      PrefetchHooks Function()
    >;
typedef $$SyncStatesTableCreateCompanionBuilder =
    SyncStatesCompanion Function({
      required String contentHash,
      required String mediaKind,
      required String locator,
      Value<double> progressRatio,
      required int updatedAtMs,
      Value<int> lastSyncedAtMs,
      required String deviceId,
      required String deviceName,
      Value<int> rowid,
    });
typedef $$SyncStatesTableUpdateCompanionBuilder =
    SyncStatesCompanion Function({
      Value<String> contentHash,
      Value<String> mediaKind,
      Value<String> locator,
      Value<double> progressRatio,
      Value<int> updatedAtMs,
      Value<int> lastSyncedAtMs,
      Value<String> deviceId,
      Value<String> deviceName,
      Value<int> rowid,
    });

class $$SyncStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progressRatio => $composableBuilder(
    column: $table.progressRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedAtMs => $composableBuilder(
    column: $table.lastSyncedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locator => $composableBuilder(
    column: $table.locator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progressRatio => $composableBuilder(
    column: $table.progressRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedAtMs => $composableBuilder(
    column: $table.lastSyncedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaKind =>
      $composableBuilder(column: $table.mediaKind, builder: (column) => column);

  GeneratedColumn<String> get locator =>
      $composableBuilder(column: $table.locator, builder: (column) => column);

  GeneratedColumn<double> get progressRatio => $composableBuilder(
    column: $table.progressRatio,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncedAtMs => $composableBuilder(
    column: $table.lastSyncedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => column,
  );
}

class $$SyncStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStatesTable,
          SyncState,
          $$SyncStatesTableFilterComposer,
          $$SyncStatesTableOrderingComposer,
          $$SyncStatesTableAnnotationComposer,
          $$SyncStatesTableCreateCompanionBuilder,
          $$SyncStatesTableUpdateCompanionBuilder,
          (
            SyncState,
            BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>,
          ),
          SyncState,
          PrefetchHooks Function()
        > {
  $$SyncStatesTableTableManager(_$AppDatabase db, $SyncStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> contentHash = const Value.absent(),
                Value<String> mediaKind = const Value.absent(),
                Value<String> locator = const Value.absent(),
                Value<double> progressRatio = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int> lastSyncedAtMs = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> deviceName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion(
                contentHash: contentHash,
                mediaKind: mediaKind,
                locator: locator,
                progressRatio: progressRatio,
                updatedAtMs: updatedAtMs,
                lastSyncedAtMs: lastSyncedAtMs,
                deviceId: deviceId,
                deviceName: deviceName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String contentHash,
                required String mediaKind,
                required String locator,
                Value<double> progressRatio = const Value.absent(),
                required int updatedAtMs,
                Value<int> lastSyncedAtMs = const Value.absent(),
                required String deviceId,
                required String deviceName,
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion.insert(
                contentHash: contentHash,
                mediaKind: mediaKind,
                locator: locator,
                progressRatio: progressRatio,
                updatedAtMs: updatedAtMs,
                lastSyncedAtMs: lastSyncedAtMs,
                deviceId: deviceId,
                deviceName: deviceName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStatesTable,
      SyncState,
      $$SyncStatesTableFilterComposer,
      $$SyncStatesTableOrderingComposer,
      $$SyncStatesTableAnnotationComposer,
      $$SyncStatesTableCreateCompanionBuilder,
      $$SyncStatesTableUpdateCompanionBuilder,
      (SyncState, BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>),
      SyncState,
      PrefetchHooks Function()
    >;
typedef $$ShelvesTableCreateCompanionBuilder =
    ShelvesCompanion Function({
      Value<int> id,
      required String name,
      required String mediaKind,
      Value<bool> isDefault,
      Value<int> sortOrder,
      required int createdAtMs,
    });
typedef $$ShelvesTableUpdateCompanionBuilder =
    ShelvesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> mediaKind,
      Value<bool> isDefault,
      Value<int> sortOrder,
      Value<int> createdAtMs,
    });

class $$ShelvesTableFilterComposer
    extends Composer<_$AppDatabase, $ShelvesTable> {
  $$ShelvesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ShelvesTableOrderingComposer
    extends Composer<_$AppDatabase, $ShelvesTable> {
  $$ShelvesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShelvesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShelvesTable> {
  $$ShelvesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get mediaKind =>
      $composableBuilder(column: $table.mediaKind, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );
}

class $$ShelvesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShelvesTable,
          Shelf,
          $$ShelvesTableFilterComposer,
          $$ShelvesTableOrderingComposer,
          $$ShelvesTableAnnotationComposer,
          $$ShelvesTableCreateCompanionBuilder,
          $$ShelvesTableUpdateCompanionBuilder,
          (Shelf, BaseReferences<_$AppDatabase, $ShelvesTable, Shelf>),
          Shelf,
          PrefetchHooks Function()
        > {
  $$ShelvesTableTableManager(_$AppDatabase db, $ShelvesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShelvesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShelvesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShelvesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> mediaKind = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
              }) => ShelvesCompanion(
                id: id,
                name: name,
                mediaKind: mediaKind,
                isDefault: isDefault,
                sortOrder: sortOrder,
                createdAtMs: createdAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String mediaKind,
                Value<bool> isDefault = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required int createdAtMs,
              }) => ShelvesCompanion.insert(
                id: id,
                name: name,
                mediaKind: mediaKind,
                isDefault: isDefault,
                sortOrder: sortOrder,
                createdAtMs: createdAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ShelvesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShelvesTable,
      Shelf,
      $$ShelvesTableFilterComposer,
      $$ShelvesTableOrderingComposer,
      $$ShelvesTableAnnotationComposer,
      $$ShelvesTableCreateCompanionBuilder,
      $$ShelvesTableUpdateCompanionBuilder,
      (Shelf, BaseReferences<_$AppDatabase, $ShelvesTable, Shelf>),
      Shelf,
      PrefetchHooks Function()
    >;
typedef $$TocRulesTableCreateCompanionBuilder =
    TocRulesCompanion Function({
      Value<int> id,
      required String name,
      required String rule,
      Value<String> example,
      Value<bool> enabled,
      Value<int> serialNumber,
      Value<bool> isBuiltin,
      required int createdAtMs,
    });
typedef $$TocRulesTableUpdateCompanionBuilder =
    TocRulesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> rule,
      Value<String> example,
      Value<bool> enabled,
      Value<int> serialNumber,
      Value<bool> isBuiltin,
      Value<int> createdAtMs,
    });

class $$TocRulesTableFilterComposer
    extends Composer<_$AppDatabase, $TocRulesTable> {
  $$TocRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rule => $composableBuilder(
    column: $table.rule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get example => $composableBuilder(
    column: $table.example,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serialNumber => $composableBuilder(
    column: $table.serialNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBuiltin => $composableBuilder(
    column: $table.isBuiltin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TocRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $TocRulesTable> {
  $$TocRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rule => $composableBuilder(
    column: $table.rule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get example => $composableBuilder(
    column: $table.example,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serialNumber => $composableBuilder(
    column: $table.serialNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBuiltin => $composableBuilder(
    column: $table.isBuiltin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TocRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TocRulesTable> {
  $$TocRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get rule =>
      $composableBuilder(column: $table.rule, builder: (column) => column);

  GeneratedColumn<String> get example =>
      $composableBuilder(column: $table.example, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get serialNumber => $composableBuilder(
    column: $table.serialNumber,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isBuiltin =>
      $composableBuilder(column: $table.isBuiltin, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );
}

class $$TocRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TocRulesTable,
          TocRule,
          $$TocRulesTableFilterComposer,
          $$TocRulesTableOrderingComposer,
          $$TocRulesTableAnnotationComposer,
          $$TocRulesTableCreateCompanionBuilder,
          $$TocRulesTableUpdateCompanionBuilder,
          (TocRule, BaseReferences<_$AppDatabase, $TocRulesTable, TocRule>),
          TocRule,
          PrefetchHooks Function()
        > {
  $$TocRulesTableTableManager(_$AppDatabase db, $TocRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TocRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TocRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TocRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> rule = const Value.absent(),
                Value<String> example = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> serialNumber = const Value.absent(),
                Value<bool> isBuiltin = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
              }) => TocRulesCompanion(
                id: id,
                name: name,
                rule: rule,
                example: example,
                enabled: enabled,
                serialNumber: serialNumber,
                isBuiltin: isBuiltin,
                createdAtMs: createdAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String rule,
                Value<String> example = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> serialNumber = const Value.absent(),
                Value<bool> isBuiltin = const Value.absent(),
                required int createdAtMs,
              }) => TocRulesCompanion.insert(
                id: id,
                name: name,
                rule: rule,
                example: example,
                enabled: enabled,
                serialNumber: serialNumber,
                isBuiltin: isBuiltin,
                createdAtMs: createdAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TocRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TocRulesTable,
      TocRule,
      $$TocRulesTableFilterComposer,
      $$TocRulesTableOrderingComposer,
      $$TocRulesTableAnnotationComposer,
      $$TocRulesTableCreateCompanionBuilder,
      $$TocRulesTableUpdateCompanionBuilder,
      (TocRule, BaseReferences<_$AppDatabase, $TocRulesTable, TocRule>),
      TocRule,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$MangasTableTableManager get mangas =>
      $$MangasTableTableManager(_db, _db.mangas);
  $$MangaChaptersTableTableManager get mangaChapters =>
      $$MangaChaptersTableTableManager(_db, _db.mangaChapters);
  $$AnnotationsTableTableManager get annotations =>
      $$AnnotationsTableTableManager(_db, _db.annotations);
  $$WatchedFoldersTableTableManager get watchedFolders =>
      $$WatchedFoldersTableTableManager(_db, _db.watchedFolders);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
  $$ShelvesTableTableManager get shelves =>
      $$ShelvesTableTableManager(_db, _db.shelves);
  $$TocRulesTableTableManager get tocRules =>
      $$TocRulesTableTableManager(_db, _db.tocRules);
}
