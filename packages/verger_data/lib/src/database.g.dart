// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $NodesTable extends Nodes with TableInfo<$NodesTable, NodeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES nodes (id)',
    ),
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
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _curriculumKeyMeta = const VerificationMeta(
    'curriculumKey',
  );
  @override
  late final GeneratedColumn<String> curriculumKey = GeneratedColumn<String>(
    'curriculum_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<NodeOrigin, String> origin =
      GeneratedColumn<String>(
        'origin',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<NodeOrigin>($NodesTable.$converterorigin);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    parentId,
    title,
    sortIndex,
    curriculumKey,
    origin,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'nodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<NodeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_sortIndexMeta);
    }
    if (data.containsKey('curriculum_key')) {
      context.handle(
        _curriculumKeyMeta,
        curriculumKey.isAcceptableOrUnknown(
          data['curriculum_key']!,
          _curriculumKeyMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NodeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NodeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      curriculumKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curriculum_key'],
      ),
      origin: $NodesTable.$converterorigin.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}origin'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $NodesTable createAlias(String alias) {
    return $NodesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<NodeOrigin, String, String> $converterorigin =
      const EnumNameConverter<NodeOrigin>(NodeOrigin.values);
}

class NodeRow extends DataClass implements Insertable<NodeRow> {
  final String id;
  final String? parentId;
  final String title;
  final int sortIndex;
  final String? curriculumKey;
  final NodeOrigin origin;
  final DateTime createdAt;
  const NodeRow({
    required this.id,
    this.parentId,
    required this.title,
    required this.sortIndex,
    this.curriculumKey,
    required this.origin,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['title'] = Variable<String>(title);
    map['sort_index'] = Variable<int>(sortIndex);
    if (!nullToAbsent || curriculumKey != null) {
      map['curriculum_key'] = Variable<String>(curriculumKey);
    }
    {
      map['origin'] = Variable<String>(
        $NodesTable.$converterorigin.toSql(origin),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  NodesCompanion toCompanion(bool nullToAbsent) {
    return NodesCompanion(
      id: Value(id),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      title: Value(title),
      sortIndex: Value(sortIndex),
      curriculumKey: curriculumKey == null && nullToAbsent
          ? const Value.absent()
          : Value(curriculumKey),
      origin: Value(origin),
      createdAt: Value(createdAt),
    );
  }

  factory NodeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NodeRow(
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      title: serializer.fromJson<String>(json['title']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      curriculumKey: serializer.fromJson<String?>(json['curriculumKey']),
      origin: $NodesTable.$converterorigin.fromJson(
        serializer.fromJson<String>(json['origin']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentId': serializer.toJson<String?>(parentId),
      'title': serializer.toJson<String>(title),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'curriculumKey': serializer.toJson<String?>(curriculumKey),
      'origin': serializer.toJson<String>(
        $NodesTable.$converterorigin.toJson(origin),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  NodeRow copyWith({
    String? id,
    Value<String?> parentId = const Value.absent(),
    String? title,
    int? sortIndex,
    Value<String?> curriculumKey = const Value.absent(),
    NodeOrigin? origin,
    DateTime? createdAt,
  }) => NodeRow(
    id: id ?? this.id,
    parentId: parentId.present ? parentId.value : this.parentId,
    title: title ?? this.title,
    sortIndex: sortIndex ?? this.sortIndex,
    curriculumKey: curriculumKey.present
        ? curriculumKey.value
        : this.curriculumKey,
    origin: origin ?? this.origin,
    createdAt: createdAt ?? this.createdAt,
  );
  NodeRow copyWithCompanion(NodesCompanion data) {
    return NodeRow(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      title: data.title.present ? data.title.value : this.title,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      curriculumKey: data.curriculumKey.present
          ? data.curriculumKey.value
          : this.curriculumKey,
      origin: data.origin.present ? data.origin.value : this.origin,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NodeRow(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('title: $title, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('curriculumKey: $curriculumKey, ')
          ..write('origin: $origin, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    parentId,
    title,
    sortIndex,
    curriculumKey,
    origin,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NodeRow &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.title == this.title &&
          other.sortIndex == this.sortIndex &&
          other.curriculumKey == this.curriculumKey &&
          other.origin == this.origin &&
          other.createdAt == this.createdAt);
}

class NodesCompanion extends UpdateCompanion<NodeRow> {
  final Value<String> id;
  final Value<String?> parentId;
  final Value<String> title;
  final Value<int> sortIndex;
  final Value<String?> curriculumKey;
  final Value<NodeOrigin> origin;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const NodesCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.title = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.curriculumKey = const Value.absent(),
    this.origin = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NodesCompanion.insert({
    required String id,
    this.parentId = const Value.absent(),
    required String title,
    required int sortIndex,
    this.curriculumKey = const Value.absent(),
    required NodeOrigin origin,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       sortIndex = Value(sortIndex),
       origin = Value(origin),
       createdAt = Value(createdAt);
  static Insertable<NodeRow> custom({
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? title,
    Expression<int>? sortIndex,
    Expression<String>? curriculumKey,
    Expression<String>? origin,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (title != null) 'title': title,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (curriculumKey != null) 'curriculum_key': curriculumKey,
      if (origin != null) 'origin': origin,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NodesCompanion copyWith({
    Value<String>? id,
    Value<String?>? parentId,
    Value<String>? title,
    Value<int>? sortIndex,
    Value<String?>? curriculumKey,
    Value<NodeOrigin>? origin,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return NodesCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      title: title ?? this.title,
      sortIndex: sortIndex ?? this.sortIndex,
      curriculumKey: curriculumKey ?? this.curriculumKey,
      origin: origin ?? this.origin,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (curriculumKey.present) {
      map['curriculum_key'] = Variable<String>(curriculumKey.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(
        $NodesTable.$converterorigin.toSql(origin.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NodesCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('title: $title, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('curriculumKey: $curriculumKey, ')
          ..write('origin: $origin, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemsTable extends Items with TableInfo<$ItemsTable, ItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
    'node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES nodes (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ItemKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ItemKind>($ItemsTable.$converterkind);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ExerciseLevel?, String> level =
      GeneratedColumn<String>(
        'level',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<ExerciseLevel?>($ItemsTable.$converterleveln);
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _suspendedMeta = const VerificationMeta(
    'suspended',
  );
  @override
  late final GeneratedColumn<bool> suspended = GeneratedColumn<bool>(
    'suspended',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("suspended" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LearningPhase, String> phase =
      GeneratedColumn<String>(
        'phase',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LearningPhase>($ItemsTable.$converterphase);
  static const VerificationMeta _stepMeta = const VerificationMeta('step');
  @override
  late final GeneratedColumn<int> step = GeneratedColumn<int>(
    'step',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stabilityMeta = const VerificationMeta(
    'stability',
  );
  @override
  late final GeneratedColumn<double> stability = GeneratedColumn<double>(
    'stability',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<double> difficulty = GeneratedColumn<double>(
    'difficulty',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueMeta = const VerificationMeta('due');
  @override
  late final GeneratedColumn<DateTime> due = GeneratedColumn<DateTime>(
    'due',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastReviewMeta = const VerificationMeta(
    'lastReview',
  );
  @override
  late final GeneratedColumn<DateTime> lastReview = GeneratedColumn<DateTime>(
    'last_review',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
    'lapses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nodeId,
    kind,
    title,
    body,
    level,
    sortIndex,
    suspended,
    createdAt,
    updatedAt,
    phase,
    step,
    stability,
    difficulty,
    due,
    lastReview,
    reps,
    lapses,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('node_id')) {
      context.handle(
        _nodeIdMeta,
        nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    if (data.containsKey('suspended')) {
      context.handle(
        _suspendedMeta,
        suspended.isAcceptableOrUnknown(data['suspended']!, _suspendedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('step')) {
      context.handle(
        _stepMeta,
        step.isAcceptableOrUnknown(data['step']!, _stepMeta),
      );
    }
    if (data.containsKey('stability')) {
      context.handle(
        _stabilityMeta,
        stability.isAcceptableOrUnknown(data['stability']!, _stabilityMeta),
      );
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    }
    if (data.containsKey('due')) {
      context.handle(
        _dueMeta,
        due.isAcceptableOrUnknown(data['due']!, _dueMeta),
      );
    }
    if (data.containsKey('last_review')) {
      context.handle(
        _lastReviewMeta,
        lastReview.isAcceptableOrUnknown(data['last_review']!, _lastReviewMeta),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('lapses')) {
      context.handle(
        _lapsesMeta,
        lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_id'],
      )!,
      kind: $ItemsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      level: $ItemsTable.$converterleveln.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}level'],
        ),
      ),
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      suspended: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}suspended'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      phase: $ItemsTable.$converterphase.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}phase'],
        )!,
      ),
      step: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}step'],
      ),
      stability: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stability'],
      ),
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}difficulty'],
      ),
      due: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due'],
      ),
      lastReview: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_review'],
      ),
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      lapses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapses'],
      )!,
    );
  }

  @override
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ItemKind, String, String> $converterkind =
      const EnumNameConverter<ItemKind>(ItemKind.values);
  static JsonTypeConverter2<ExerciseLevel, String, String> $converterlevel =
      const EnumNameConverter<ExerciseLevel>(ExerciseLevel.values);
  static JsonTypeConverter2<ExerciseLevel?, String?, String?> $converterleveln =
      JsonTypeConverter2.asNullable($converterlevel);
  static JsonTypeConverter2<LearningPhase, String, String> $converterphase =
      const EnumNameConverter<LearningPhase>(LearningPhase.values);
}

class ItemRow extends DataClass implements Insertable<ItemRow> {
  final String id;
  final String nodeId;
  final ItemKind kind;
  final String title;
  final String? body;
  final ExerciseLevel? level;
  final int sortIndex;
  final bool suspended;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LearningPhase phase;
  final int? step;
  final double? stability;
  final double? difficulty;
  final DateTime? due;
  final DateTime? lastReview;
  final int reps;
  final int lapses;
  const ItemRow({
    required this.id,
    required this.nodeId,
    required this.kind,
    required this.title,
    this.body,
    this.level,
    required this.sortIndex,
    required this.suspended,
    required this.createdAt,
    required this.updatedAt,
    required this.phase,
    this.step,
    this.stability,
    this.difficulty,
    this.due,
    this.lastReview,
    required this.reps,
    required this.lapses,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['node_id'] = Variable<String>(nodeId);
    {
      map['kind'] = Variable<String>($ItemsTable.$converterkind.toSql(kind));
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || level != null) {
      map['level'] = Variable<String>(
        $ItemsTable.$converterleveln.toSql(level),
      );
    }
    map['sort_index'] = Variable<int>(sortIndex);
    map['suspended'] = Variable<bool>(suspended);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    {
      map['phase'] = Variable<String>($ItemsTable.$converterphase.toSql(phase));
    }
    if (!nullToAbsent || step != null) {
      map['step'] = Variable<int>(step);
    }
    if (!nullToAbsent || stability != null) {
      map['stability'] = Variable<double>(stability);
    }
    if (!nullToAbsent || difficulty != null) {
      map['difficulty'] = Variable<double>(difficulty);
    }
    if (!nullToAbsent || due != null) {
      map['due'] = Variable<DateTime>(due);
    }
    if (!nullToAbsent || lastReview != null) {
      map['last_review'] = Variable<DateTime>(lastReview);
    }
    map['reps'] = Variable<int>(reps);
    map['lapses'] = Variable<int>(lapses);
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      id: Value(id),
      nodeId: Value(nodeId),
      kind: Value(kind),
      title: Value(title),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      level: level == null && nullToAbsent
          ? const Value.absent()
          : Value(level),
      sortIndex: Value(sortIndex),
      suspended: Value(suspended),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      phase: Value(phase),
      step: step == null && nullToAbsent ? const Value.absent() : Value(step),
      stability: stability == null && nullToAbsent
          ? const Value.absent()
          : Value(stability),
      difficulty: difficulty == null && nullToAbsent
          ? const Value.absent()
          : Value(difficulty),
      due: due == null && nullToAbsent ? const Value.absent() : Value(due),
      lastReview: lastReview == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReview),
      reps: Value(reps),
      lapses: Value(lapses),
    );
  }

  factory ItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemRow(
      id: serializer.fromJson<String>(json['id']),
      nodeId: serializer.fromJson<String>(json['nodeId']),
      kind: $ItemsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String?>(json['body']),
      level: $ItemsTable.$converterleveln.fromJson(
        serializer.fromJson<String?>(json['level']),
      ),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      suspended: serializer.fromJson<bool>(json['suspended']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      phase: $ItemsTable.$converterphase.fromJson(
        serializer.fromJson<String>(json['phase']),
      ),
      step: serializer.fromJson<int?>(json['step']),
      stability: serializer.fromJson<double?>(json['stability']),
      difficulty: serializer.fromJson<double?>(json['difficulty']),
      due: serializer.fromJson<DateTime?>(json['due']),
      lastReview: serializer.fromJson<DateTime?>(json['lastReview']),
      reps: serializer.fromJson<int>(json['reps']),
      lapses: serializer.fromJson<int>(json['lapses']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nodeId': serializer.toJson<String>(nodeId),
      'kind': serializer.toJson<String>(
        $ItemsTable.$converterkind.toJson(kind),
      ),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String?>(body),
      'level': serializer.toJson<String?>(
        $ItemsTable.$converterleveln.toJson(level),
      ),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'suspended': serializer.toJson<bool>(suspended),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'phase': serializer.toJson<String>(
        $ItemsTable.$converterphase.toJson(phase),
      ),
      'step': serializer.toJson<int?>(step),
      'stability': serializer.toJson<double?>(stability),
      'difficulty': serializer.toJson<double?>(difficulty),
      'due': serializer.toJson<DateTime?>(due),
      'lastReview': serializer.toJson<DateTime?>(lastReview),
      'reps': serializer.toJson<int>(reps),
      'lapses': serializer.toJson<int>(lapses),
    };
  }

  ItemRow copyWith({
    String? id,
    String? nodeId,
    ItemKind? kind,
    String? title,
    Value<String?> body = const Value.absent(),
    Value<ExerciseLevel?> level = const Value.absent(),
    int? sortIndex,
    bool? suspended,
    DateTime? createdAt,
    DateTime? updatedAt,
    LearningPhase? phase,
    Value<int?> step = const Value.absent(),
    Value<double?> stability = const Value.absent(),
    Value<double?> difficulty = const Value.absent(),
    Value<DateTime?> due = const Value.absent(),
    Value<DateTime?> lastReview = const Value.absent(),
    int? reps,
    int? lapses,
  }) => ItemRow(
    id: id ?? this.id,
    nodeId: nodeId ?? this.nodeId,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    body: body.present ? body.value : this.body,
    level: level.present ? level.value : this.level,
    sortIndex: sortIndex ?? this.sortIndex,
    suspended: suspended ?? this.suspended,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    phase: phase ?? this.phase,
    step: step.present ? step.value : this.step,
    stability: stability.present ? stability.value : this.stability,
    difficulty: difficulty.present ? difficulty.value : this.difficulty,
    due: due.present ? due.value : this.due,
    lastReview: lastReview.present ? lastReview.value : this.lastReview,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
  );
  ItemRow copyWithCompanion(ItemsCompanion data) {
    return ItemRow(
      id: data.id.present ? data.id.value : this.id,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      level: data.level.present ? data.level.value : this.level,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      suspended: data.suspended.present ? data.suspended.value : this.suspended,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      phase: data.phase.present ? data.phase.value : this.phase,
      step: data.step.present ? data.step.value : this.step,
      stability: data.stability.present ? data.stability.value : this.stability,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      due: data.due.present ? data.due.value : this.due,
      lastReview: data.lastReview.present
          ? data.lastReview.value
          : this.lastReview,
      reps: data.reps.present ? data.reps.value : this.reps,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemRow(')
          ..write('id: $id, ')
          ..write('nodeId: $nodeId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('level: $level, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('suspended: $suspended, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('phase: $phase, ')
          ..write('step: $step, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('due: $due, ')
          ..write('lastReview: $lastReview, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nodeId,
    kind,
    title,
    body,
    level,
    sortIndex,
    suspended,
    createdAt,
    updatedAt,
    phase,
    step,
    stability,
    difficulty,
    due,
    lastReview,
    reps,
    lapses,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemRow &&
          other.id == this.id &&
          other.nodeId == this.nodeId &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.body == this.body &&
          other.level == this.level &&
          other.sortIndex == this.sortIndex &&
          other.suspended == this.suspended &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.phase == this.phase &&
          other.step == this.step &&
          other.stability == this.stability &&
          other.difficulty == this.difficulty &&
          other.due == this.due &&
          other.lastReview == this.lastReview &&
          other.reps == this.reps &&
          other.lapses == this.lapses);
}

class ItemsCompanion extends UpdateCompanion<ItemRow> {
  final Value<String> id;
  final Value<String> nodeId;
  final Value<ItemKind> kind;
  final Value<String> title;
  final Value<String?> body;
  final Value<ExerciseLevel?> level;
  final Value<int> sortIndex;
  final Value<bool> suspended;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<LearningPhase> phase;
  final Value<int?> step;
  final Value<double?> stability;
  final Value<double?> difficulty;
  final Value<DateTime?> due;
  final Value<DateTime?> lastReview;
  final Value<int> reps;
  final Value<int> lapses;
  final Value<int> rowid;
  const ItemsCompanion({
    this.id = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.level = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.suspended = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.phase = const Value.absent(),
    this.step = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.due = const Value.absent(),
    this.lastReview = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemsCompanion.insert({
    required String id,
    required String nodeId,
    required ItemKind kind,
    required String title,
    this.body = const Value.absent(),
    this.level = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.suspended = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    required LearningPhase phase,
    this.step = const Value.absent(),
    this.stability = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.due = const Value.absent(),
    this.lastReview = const Value.absent(),
    this.reps = const Value.absent(),
    this.lapses = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nodeId = Value(nodeId),
       kind = Value(kind),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       phase = Value(phase);
  static Insertable<ItemRow> custom({
    Expression<String>? id,
    Expression<String>? nodeId,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? level,
    Expression<int>? sortIndex,
    Expression<bool>? suspended,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? phase,
    Expression<int>? step,
    Expression<double>? stability,
    Expression<double>? difficulty,
    Expression<DateTime>? due,
    Expression<DateTime>? lastReview,
    Expression<int>? reps,
    Expression<int>? lapses,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nodeId != null) 'node_id': nodeId,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (level != null) 'level': level,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (suspended != null) 'suspended': suspended,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (phase != null) 'phase': phase,
      if (step != null) 'step': step,
      if (stability != null) 'stability': stability,
      if (difficulty != null) 'difficulty': difficulty,
      if (due != null) 'due': due,
      if (lastReview != null) 'last_review': lastReview,
      if (reps != null) 'reps': reps,
      if (lapses != null) 'lapses': lapses,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? nodeId,
    Value<ItemKind>? kind,
    Value<String>? title,
    Value<String?>? body,
    Value<ExerciseLevel?>? level,
    Value<int>? sortIndex,
    Value<bool>? suspended,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<LearningPhase>? phase,
    Value<int?>? step,
    Value<double?>? stability,
    Value<double?>? difficulty,
    Value<DateTime?>? due,
    Value<DateTime?>? lastReview,
    Value<int>? reps,
    Value<int>? lapses,
    Value<int>? rowid,
  }) {
    return ItemsCompanion(
      id: id ?? this.id,
      nodeId: nodeId ?? this.nodeId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      body: body ?? this.body,
      level: level ?? this.level,
      sortIndex: sortIndex ?? this.sortIndex,
      suspended: suspended ?? this.suspended,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      phase: phase ?? this.phase,
      step: step ?? this.step,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      due: due ?? this.due,
      lastReview: lastReview ?? this.lastReview,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $ItemsTable.$converterkind.toSql(kind.value),
      );
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(
        $ItemsTable.$converterleveln.toSql(level.value),
      );
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (suspended.present) {
      map['suspended'] = Variable<bool>(suspended.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(
        $ItemsTable.$converterphase.toSql(phase.value),
      );
    }
    if (step.present) {
      map['step'] = Variable<int>(step.value);
    }
    if (stability.present) {
      map['stability'] = Variable<double>(stability.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<double>(difficulty.value);
    }
    if (due.present) {
      map['due'] = Variable<DateTime>(due.value);
    }
    if (lastReview.present) {
      map['last_review'] = Variable<DateTime>(lastReview.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsCompanion(')
          ..write('id: $id, ')
          ..write('nodeId: $nodeId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('level: $level, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('suspended: $suspended, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('phase: $phase, ')
          ..write('step: $step, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('due: $due, ')
          ..write('lastReview: $lastReview, ')
          ..write('reps: $reps, ')
          ..write('lapses: $lapses, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewLogsTable extends ReviewLogs
    with TableInfo<$ReviewLogsTable, ReviewLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _reviewedAtMeta = const VerificationMeta(
    'reviewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> reviewedAt = GeneratedColumn<DateTime>(
    'reviewed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Rating, String> rating =
      GeneratedColumn<String>(
        'rating',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Rating>($ReviewLogsTable.$converterrating);
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _schedulerIdMeta = const VerificationMeta(
    'schedulerId',
  );
  @override
  late final GeneratedColumn<String> schedulerId = GeneratedColumn<String>(
    'scheduler_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateBeforeMeta = const VerificationMeta(
    'stateBefore',
  );
  @override
  late final GeneratedColumn<String> stateBefore = GeneratedColumn<String>(
    'state_before',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateAfterMeta = const VerificationMeta(
    'stateAfter',
  );
  @override
  late final GeneratedColumn<String> stateAfter = GeneratedColumn<String>(
    'state_after',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _impliedByMeta = const VerificationMeta(
    'impliedBy',
  );
  @override
  late final GeneratedColumn<String> impliedBy = GeneratedColumn<String>(
    'implied_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    reviewedAt,
    rating,
    durationMs,
    schedulerId,
    stateBefore,
    stateAfter,
    impliedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
        _reviewedAtMeta,
        reviewedAt.isAcceptableOrUnknown(data['reviewed_at']!, _reviewedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_reviewedAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('scheduler_id')) {
      context.handle(
        _schedulerIdMeta,
        schedulerId.isAcceptableOrUnknown(
          data['scheduler_id']!,
          _schedulerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schedulerIdMeta);
    }
    if (data.containsKey('state_before')) {
      context.handle(
        _stateBeforeMeta,
        stateBefore.isAcceptableOrUnknown(
          data['state_before']!,
          _stateBeforeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stateBeforeMeta);
    }
    if (data.containsKey('state_after')) {
      context.handle(
        _stateAfterMeta,
        stateAfter.isAcceptableOrUnknown(data['state_after']!, _stateAfterMeta),
      );
    } else if (isInserting) {
      context.missing(_stateAfterMeta);
    }
    if (data.containsKey('implied_by')) {
      context.handle(
        _impliedByMeta,
        impliedBy.isAcceptableOrUnknown(data['implied_by']!, _impliedByMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      reviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reviewed_at'],
      )!,
      rating: $ReviewLogsTable.$converterrating.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}rating'],
        )!,
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      schedulerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduler_id'],
      )!,
      stateBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_before'],
      )!,
      stateAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_after'],
      )!,
      impliedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}implied_by'],
      ),
    );
  }

  @override
  $ReviewLogsTable createAlias(String alias) {
    return $ReviewLogsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Rating, String, String> $converterrating =
      const EnumNameConverter<Rating>(Rating.values);
}

class ReviewLogRow extends DataClass implements Insertable<ReviewLogRow> {
  final String id;
  final String itemId;
  final DateTime reviewedAt;
  final Rating rating;
  final int? durationMs;
  final String schedulerId;

  /// États avant/après (JSON de `SchedulingState`).
  final String stateBefore;
  final String stateAfter;

  /// Révision implicite : connaissance réussie qui s'appuie sur celle-ci
  /// (v7). Sans clé étrangère : la trace survit à sa suppression.
  final String? impliedBy;
  const ReviewLogRow({
    required this.id,
    required this.itemId,
    required this.reviewedAt,
    required this.rating,
    this.durationMs,
    required this.schedulerId,
    required this.stateBefore,
    required this.stateAfter,
    this.impliedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['reviewed_at'] = Variable<DateTime>(reviewedAt);
    {
      map['rating'] = Variable<String>(
        $ReviewLogsTable.$converterrating.toSql(rating),
      );
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['scheduler_id'] = Variable<String>(schedulerId);
    map['state_before'] = Variable<String>(stateBefore);
    map['state_after'] = Variable<String>(stateAfter);
    if (!nullToAbsent || impliedBy != null) {
      map['implied_by'] = Variable<String>(impliedBy);
    }
    return map;
  }

  ReviewLogsCompanion toCompanion(bool nullToAbsent) {
    return ReviewLogsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      reviewedAt: Value(reviewedAt),
      rating: Value(rating),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      schedulerId: Value(schedulerId),
      stateBefore: Value(stateBefore),
      stateAfter: Value(stateAfter),
      impliedBy: impliedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(impliedBy),
    );
  }

  factory ReviewLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewLogRow(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      reviewedAt: serializer.fromJson<DateTime>(json['reviewedAt']),
      rating: $ReviewLogsTable.$converterrating.fromJson(
        serializer.fromJson<String>(json['rating']),
      ),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      schedulerId: serializer.fromJson<String>(json['schedulerId']),
      stateBefore: serializer.fromJson<String>(json['stateBefore']),
      stateAfter: serializer.fromJson<String>(json['stateAfter']),
      impliedBy: serializer.fromJson<String?>(json['impliedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'reviewedAt': serializer.toJson<DateTime>(reviewedAt),
      'rating': serializer.toJson<String>(
        $ReviewLogsTable.$converterrating.toJson(rating),
      ),
      'durationMs': serializer.toJson<int?>(durationMs),
      'schedulerId': serializer.toJson<String>(schedulerId),
      'stateBefore': serializer.toJson<String>(stateBefore),
      'stateAfter': serializer.toJson<String>(stateAfter),
      'impliedBy': serializer.toJson<String?>(impliedBy),
    };
  }

  ReviewLogRow copyWith({
    String? id,
    String? itemId,
    DateTime? reviewedAt,
    Rating? rating,
    Value<int?> durationMs = const Value.absent(),
    String? schedulerId,
    String? stateBefore,
    String? stateAfter,
    Value<String?> impliedBy = const Value.absent(),
  }) => ReviewLogRow(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    rating: rating ?? this.rating,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    schedulerId: schedulerId ?? this.schedulerId,
    stateBefore: stateBefore ?? this.stateBefore,
    stateAfter: stateAfter ?? this.stateAfter,
    impliedBy: impliedBy.present ? impliedBy.value : this.impliedBy,
  );
  ReviewLogRow copyWithCompanion(ReviewLogsCompanion data) {
    return ReviewLogRow(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      reviewedAt: data.reviewedAt.present
          ? data.reviewedAt.value
          : this.reviewedAt,
      rating: data.rating.present ? data.rating.value : this.rating,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      schedulerId: data.schedulerId.present
          ? data.schedulerId.value
          : this.schedulerId,
      stateBefore: data.stateBefore.present
          ? data.stateBefore.value
          : this.stateBefore,
      stateAfter: data.stateAfter.present
          ? data.stateAfter.value
          : this.stateAfter,
      impliedBy: data.impliedBy.present ? data.impliedBy.value : this.impliedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogRow(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('rating: $rating, ')
          ..write('durationMs: $durationMs, ')
          ..write('schedulerId: $schedulerId, ')
          ..write('stateBefore: $stateBefore, ')
          ..write('stateAfter: $stateAfter, ')
          ..write('impliedBy: $impliedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    reviewedAt,
    rating,
    durationMs,
    schedulerId,
    stateBefore,
    stateAfter,
    impliedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewLogRow &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.reviewedAt == this.reviewedAt &&
          other.rating == this.rating &&
          other.durationMs == this.durationMs &&
          other.schedulerId == this.schedulerId &&
          other.stateBefore == this.stateBefore &&
          other.stateAfter == this.stateAfter &&
          other.impliedBy == this.impliedBy);
}

class ReviewLogsCompanion extends UpdateCompanion<ReviewLogRow> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<DateTime> reviewedAt;
  final Value<Rating> rating;
  final Value<int?> durationMs;
  final Value<String> schedulerId;
  final Value<String> stateBefore;
  final Value<String> stateAfter;
  final Value<String?> impliedBy;
  final Value<int> rowid;
  const ReviewLogsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.reviewedAt = const Value.absent(),
    this.rating = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.schedulerId = const Value.absent(),
    this.stateBefore = const Value.absent(),
    this.stateAfter = const Value.absent(),
    this.impliedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewLogsCompanion.insert({
    required String id,
    required String itemId,
    required DateTime reviewedAt,
    required Rating rating,
    this.durationMs = const Value.absent(),
    required String schedulerId,
    required String stateBefore,
    required String stateAfter,
    this.impliedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       reviewedAt = Value(reviewedAt),
       rating = Value(rating),
       schedulerId = Value(schedulerId),
       stateBefore = Value(stateBefore),
       stateAfter = Value(stateAfter);
  static Insertable<ReviewLogRow> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<DateTime>? reviewedAt,
    Expression<String>? rating,
    Expression<int>? durationMs,
    Expression<String>? schedulerId,
    Expression<String>? stateBefore,
    Expression<String>? stateAfter,
    Expression<String>? impliedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (rating != null) 'rating': rating,
      if (durationMs != null) 'duration_ms': durationMs,
      if (schedulerId != null) 'scheduler_id': schedulerId,
      if (stateBefore != null) 'state_before': stateBefore,
      if (stateAfter != null) 'state_after': stateAfter,
      if (impliedBy != null) 'implied_by': impliedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewLogsCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<DateTime>? reviewedAt,
    Value<Rating>? rating,
    Value<int?>? durationMs,
    Value<String>? schedulerId,
    Value<String>? stateBefore,
    Value<String>? stateAfter,
    Value<String?>? impliedBy,
    Value<int>? rowid,
  }) {
    return ReviewLogsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rating: rating ?? this.rating,
      durationMs: durationMs ?? this.durationMs,
      schedulerId: schedulerId ?? this.schedulerId,
      stateBefore: stateBefore ?? this.stateBefore,
      stateAfter: stateAfter ?? this.stateAfter,
      impliedBy: impliedBy ?? this.impliedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt.value);
    }
    if (rating.present) {
      map['rating'] = Variable<String>(
        $ReviewLogsTable.$converterrating.toSql(rating.value),
      );
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (schedulerId.present) {
      map['scheduler_id'] = Variable<String>(schedulerId.value);
    }
    if (stateBefore.present) {
      map['state_before'] = Variable<String>(stateBefore.value);
    }
    if (stateAfter.present) {
      map['state_after'] = Variable<String>(stateAfter.value);
    }
    if (impliedBy.present) {
      map['implied_by'] = Variable<String>(impliedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('rating: $rating, ')
          ..write('durationMs: $durationMs, ')
          ..write('schedulerId: $schedulerId, ')
          ..write('stateBefore: $stateBefore, ')
          ..write('stateAfter: $stateAfter, ')
          ..write('impliedBy: $impliedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentsTable extends Documents
    with TableInfo<$DocumentsTable, DocumentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  @override
  late final GeneratedColumnWithTypeConverter<ResourceKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('pdf'),
      ).withConverter<ResourceKind>($DocumentsTable.$converterkind);
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: true,
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
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _fingerprintsMeta = const VerificationMeta(
    'fingerprints',
  );
  @override
  late final GeneratedColumn<Uint8List> fingerprints =
      GeneratedColumn<Uint8List>(
        'fingerprints',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _newPagesMeta = const VerificationMeta(
    'newPages',
  );
  @override
  late final GeneratedColumn<String> newPages = GeneratedColumn<String>(
    'new_pages',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _lastPageMeta = const VerificationMeta(
    'lastPage',
  );
  @override
  late final GeneratedColumn<int> lastPage = GeneratedColumn<int>(
    'last_page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    kind,
    url,
    pageCount,
    contentHash,
    importedAt,
    version,
    fingerprints,
    newPages,
    lastPage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    } else if (isInserting) {
      context.missing(_pageCountMeta);
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
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('fingerprints')) {
      context.handle(
        _fingerprintsMeta,
        fingerprints.isAcceptableOrUnknown(
          data['fingerprints']!,
          _fingerprintsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintsMeta);
    }
    if (data.containsKey('new_pages')) {
      context.handle(
        _newPagesMeta,
        newPages.isAcceptableOrUnknown(data['new_pages']!, _newPagesMeta),
      );
    }
    if (data.containsKey('last_page')) {
      context.handle(
        _lastPageMeta,
        lastPage.isAcceptableOrUnknown(data['last_page']!, _lastPageMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      kind: $DocumentsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      fingerprints: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}fingerprints'],
      )!,
      newPages: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}new_pages'],
      )!,
      lastPage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_page'],
      )!,
    );
  }

  @override
  $DocumentsTable createAlias(String alias) {
    return $DocumentsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ResourceKind, String, String> $converterkind =
      const EnumNameConverter<ResourceKind>(ResourceKind.values);
}

class DocumentRow extends DataClass implements Insertable<DocumentRow> {
  final String id;
  final String title;

  /// Nature du contenu (v5, remplace le rôle cours / notes).
  final ResourceKind kind;

  /// Adresse d'origine : vidéo, ou PDF téléchargeable (v5).
  final String? url;
  final int pageCount;
  final String contentHash;
  final DateTime importedAt;
  final int version;

  /// Empreintes des pages, concaténées (pageCount × fingerprintSide²).
  final Uint8List fingerprints;

  /// Pages apparues à la dernière mise à jour (JSON : liste d'entiers).
  final String newPages;

  /// Dernière page consultée (v3).
  final int lastPage;
  const DocumentRow({
    required this.id,
    required this.title,
    required this.kind,
    this.url,
    required this.pageCount,
    required this.contentHash,
    required this.importedAt,
    required this.version,
    required this.fingerprints,
    required this.newPages,
    required this.lastPage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    {
      map['kind'] = Variable<String>(
        $DocumentsTable.$converterkind.toSql(kind),
      );
    }
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    map['page_count'] = Variable<int>(pageCount);
    map['content_hash'] = Variable<String>(contentHash);
    map['imported_at'] = Variable<DateTime>(importedAt);
    map['version'] = Variable<int>(version);
    map['fingerprints'] = Variable<Uint8List>(fingerprints);
    map['new_pages'] = Variable<String>(newPages);
    map['last_page'] = Variable<int>(lastPage);
    return map;
  }

  DocumentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentsCompanion(
      id: Value(id),
      title: Value(title),
      kind: Value(kind),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      pageCount: Value(pageCount),
      contentHash: Value(contentHash),
      importedAt: Value(importedAt),
      version: Value(version),
      fingerprints: Value(fingerprints),
      newPages: Value(newPages),
      lastPage: Value(lastPage),
    );
  }

  factory DocumentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      kind: $DocumentsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      url: serializer.fromJson<String?>(json['url']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
      version: serializer.fromJson<int>(json['version']),
      fingerprints: serializer.fromJson<Uint8List>(json['fingerprints']),
      newPages: serializer.fromJson<String>(json['newPages']),
      lastPage: serializer.fromJson<int>(json['lastPage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'kind': serializer.toJson<String>(
        $DocumentsTable.$converterkind.toJson(kind),
      ),
      'url': serializer.toJson<String?>(url),
      'pageCount': serializer.toJson<int>(pageCount),
      'contentHash': serializer.toJson<String>(contentHash),
      'importedAt': serializer.toJson<DateTime>(importedAt),
      'version': serializer.toJson<int>(version),
      'fingerprints': serializer.toJson<Uint8List>(fingerprints),
      'newPages': serializer.toJson<String>(newPages),
      'lastPage': serializer.toJson<int>(lastPage),
    };
  }

  DocumentRow copyWith({
    String? id,
    String? title,
    ResourceKind? kind,
    Value<String?> url = const Value.absent(),
    int? pageCount,
    String? contentHash,
    DateTime? importedAt,
    int? version,
    Uint8List? fingerprints,
    String? newPages,
    int? lastPage,
  }) => DocumentRow(
    id: id ?? this.id,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    url: url.present ? url.value : this.url,
    pageCount: pageCount ?? this.pageCount,
    contentHash: contentHash ?? this.contentHash,
    importedAt: importedAt ?? this.importedAt,
    version: version ?? this.version,
    fingerprints: fingerprints ?? this.fingerprints,
    newPages: newPages ?? this.newPages,
    lastPage: lastPage ?? this.lastPage,
  );
  DocumentRow copyWithCompanion(DocumentsCompanion data) {
    return DocumentRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      kind: data.kind.present ? data.kind.value : this.kind,
      url: data.url.present ? data.url.value : this.url,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      version: data.version.present ? data.version.value : this.version,
      fingerprints: data.fingerprints.present
          ? data.fingerprints.value
          : this.fingerprints,
      newPages: data.newPages.present ? data.newPages.value : this.newPages,
      lastPage: data.lastPage.present ? data.lastPage.value : this.lastPage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('url: $url, ')
          ..write('pageCount: $pageCount, ')
          ..write('contentHash: $contentHash, ')
          ..write('importedAt: $importedAt, ')
          ..write('version: $version, ')
          ..write('fingerprints: $fingerprints, ')
          ..write('newPages: $newPages, ')
          ..write('lastPage: $lastPage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    kind,
    url,
    pageCount,
    contentHash,
    importedAt,
    version,
    $driftBlobEquality.hash(fingerprints),
    newPages,
    lastPage,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.kind == this.kind &&
          other.url == this.url &&
          other.pageCount == this.pageCount &&
          other.contentHash == this.contentHash &&
          other.importedAt == this.importedAt &&
          other.version == this.version &&
          $driftBlobEquality.equals(other.fingerprints, this.fingerprints) &&
          other.newPages == this.newPages &&
          other.lastPage == this.lastPage);
}

class DocumentsCompanion extends UpdateCompanion<DocumentRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<ResourceKind> kind;
  final Value<String?> url;
  final Value<int> pageCount;
  final Value<String> contentHash;
  final Value<DateTime> importedAt;
  final Value<int> version;
  final Value<Uint8List> fingerprints;
  final Value<String> newPages;
  final Value<int> lastPage;
  final Value<int> rowid;
  const DocumentsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.kind = const Value.absent(),
    this.url = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.fingerprints = const Value.absent(),
    this.newPages = const Value.absent(),
    this.lastPage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentsCompanion.insert({
    required String id,
    required String title,
    this.kind = const Value.absent(),
    this.url = const Value.absent(),
    required int pageCount,
    required String contentHash,
    required DateTime importedAt,
    this.version = const Value.absent(),
    required Uint8List fingerprints,
    this.newPages = const Value.absent(),
    this.lastPage = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       pageCount = Value(pageCount),
       contentHash = Value(contentHash),
       importedAt = Value(importedAt),
       fingerprints = Value(fingerprints);
  static Insertable<DocumentRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? kind,
    Expression<String>? url,
    Expression<int>? pageCount,
    Expression<String>? contentHash,
    Expression<DateTime>? importedAt,
    Expression<int>? version,
    Expression<Uint8List>? fingerprints,
    Expression<String>? newPages,
    Expression<int>? lastPage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (kind != null) 'kind': kind,
      if (url != null) 'url': url,
      if (pageCount != null) 'page_count': pageCount,
      if (contentHash != null) 'content_hash': contentHash,
      if (importedAt != null) 'imported_at': importedAt,
      if (version != null) 'version': version,
      if (fingerprints != null) 'fingerprints': fingerprints,
      if (newPages != null) 'new_pages': newPages,
      if (lastPage != null) 'last_page': lastPage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<ResourceKind>? kind,
    Value<String?>? url,
    Value<int>? pageCount,
    Value<String>? contentHash,
    Value<DateTime>? importedAt,
    Value<int>? version,
    Value<Uint8List>? fingerprints,
    Value<String>? newPages,
    Value<int>? lastPage,
    Value<int>? rowid,
  }) {
    return DocumentsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      url: url ?? this.url,
      pageCount: pageCount ?? this.pageCount,
      contentHash: contentHash ?? this.contentHash,
      importedAt: importedAt ?? this.importedAt,
      version: version ?? this.version,
      fingerprints: fingerprints ?? this.fingerprints,
      newPages: newPages ?? this.newPages,
      lastPage: lastPage ?? this.lastPage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $DocumentsTable.$converterkind.toSql(kind.value),
      );
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (fingerprints.present) {
      map['fingerprints'] = Variable<Uint8List>(fingerprints.value);
    }
    if (newPages.present) {
      map['new_pages'] = Variable<String>(newPages.value);
    }
    if (lastPage.present) {
      map['last_page'] = Variable<int>(lastPage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('url: $url, ')
          ..write('pageCount: $pageCount, ')
          ..write('contentHash: $contentHash, ')
          ..write('importedAt: $importedAt, ')
          ..write('version: $version, ')
          ..write('fingerprints: $fingerprints, ')
          ..write('newPages: $newPages, ')
          ..write('lastPage: $lastPage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentFilesTable extends DocumentFiles
    with TableInfo<$DocumentFilesTable, DocumentFileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [documentId, bytes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentFileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {documentId};
  @override
  DocumentFileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentFileRow(
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
    );
  }

  @override
  $DocumentFilesTable createAlias(String alias) {
    return $DocumentFilesTable(attachedDatabase, alias);
  }
}

class DocumentFileRow extends DataClass implements Insertable<DocumentFileRow> {
  final String documentId;
  final Uint8List bytes;
  const DocumentFileRow({required this.documentId, required this.bytes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['document_id'] = Variable<String>(documentId);
    map['bytes'] = Variable<Uint8List>(bytes);
    return map;
  }

  DocumentFilesCompanion toCompanion(bool nullToAbsent) {
    return DocumentFilesCompanion(
      documentId: Value(documentId),
      bytes: Value(bytes),
    );
  }

  factory DocumentFileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentFileRow(
      documentId: serializer.fromJson<String>(json['documentId']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentId': serializer.toJson<String>(documentId),
      'bytes': serializer.toJson<Uint8List>(bytes),
    };
  }

  DocumentFileRow copyWith({String? documentId, Uint8List? bytes}) =>
      DocumentFileRow(
        documentId: documentId ?? this.documentId,
        bytes: bytes ?? this.bytes,
      );
  DocumentFileRow copyWithCompanion(DocumentFilesCompanion data) {
    return DocumentFileRow(
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentFileRow(')
          ..write('documentId: $documentId, ')
          ..write('bytes: $bytes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(documentId, $driftBlobEquality.hash(bytes));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentFileRow &&
          other.documentId == this.documentId &&
          $driftBlobEquality.equals(other.bytes, this.bytes));
}

class DocumentFilesCompanion extends UpdateCompanion<DocumentFileRow> {
  final Value<String> documentId;
  final Value<Uint8List> bytes;
  final Value<int> rowid;
  const DocumentFilesCompanion({
    this.documentId = const Value.absent(),
    this.bytes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentFilesCompanion.insert({
    required String documentId,
    required Uint8List bytes,
    this.rowid = const Value.absent(),
  }) : documentId = Value(documentId),
       bytes = Value(bytes);
  static Insertable<DocumentFileRow> custom({
    Expression<String>? documentId,
    Expression<Uint8List>? bytes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentId != null) 'document_id': documentId,
      if (bytes != null) 'bytes': bytes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentFilesCompanion copyWith({
    Value<String>? documentId,
    Value<Uint8List>? bytes,
    Value<int>? rowid,
  }) {
    return DocumentFilesCompanion(
      documentId: documentId ?? this.documentId,
      bytes: bytes ?? this.bytes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentFilesCompanion(')
          ..write('documentId: $documentId, ')
          ..write('bytes: $bytes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnchorsTable extends Anchors with TableInfo<$AnchorsTable, AnchorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnchorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<AnchorRole, String> role =
      GeneratedColumn<String>(
        'role',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AnchorRole>($AnchorsTable.$converterrole);
  static const VerificationMeta _pageMeta = const VerificationMeta('page');
  @override
  late final GeneratedColumn<int> page = GeneratedColumn<int>(
    'page',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leftMeta = const VerificationMeta('left');
  @override
  late final GeneratedColumn<double> left = GeneratedColumn<double>(
    'left',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _topMeta = const VerificationMeta('top');
  @override
  late final GeneratedColumn<double> top = GeneratedColumn<double>(
    'top',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rightMeta = const VerificationMeta('right');
  @override
  late final GeneratedColumn<double> right = GeneratedColumn<double>(
    'right',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bottomMeta = const VerificationMeta('bottom');
  @override
  late final GeneratedColumn<double> bottom = GeneratedColumn<double>(
    'bottom',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textSnippetMeta = const VerificationMeta(
    'textSnippet',
  );
  @override
  late final GeneratedColumn<String> textSnippet = GeneratedColumn<String>(
    'text_snippet',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snapshotMeta = const VerificationMeta(
    'snapshot',
  );
  @override
  late final GeneratedColumn<Uint8List> snapshot = GeneratedColumn<Uint8List>(
    'snapshot',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _needsReviewMeta = const VerificationMeta(
    'needsReview',
  );
  @override
  late final GeneratedColumn<bool> needsReview = GeneratedColumn<bool>(
    'needs_review',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_review" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    documentId,
    role,
    page,
    startMs,
    endMs,
    left,
    top,
    right,
    bottom,
    textSnippet,
    snapshot,
    needsReview,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'anchors';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnchorRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('page')) {
      context.handle(
        _pageMeta,
        page.isAcceptableOrUnknown(data['page']!, _pageMeta),
      );
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    }
    if (data.containsKey('end_ms')) {
      context.handle(
        _endMsMeta,
        endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta),
      );
    }
    if (data.containsKey('left')) {
      context.handle(
        _leftMeta,
        left.isAcceptableOrUnknown(data['left']!, _leftMeta),
      );
    }
    if (data.containsKey('top')) {
      context.handle(
        _topMeta,
        top.isAcceptableOrUnknown(data['top']!, _topMeta),
      );
    }
    if (data.containsKey('right')) {
      context.handle(
        _rightMeta,
        right.isAcceptableOrUnknown(data['right']!, _rightMeta),
      );
    }
    if (data.containsKey('bottom')) {
      context.handle(
        _bottomMeta,
        bottom.isAcceptableOrUnknown(data['bottom']!, _bottomMeta),
      );
    }
    if (data.containsKey('text_snippet')) {
      context.handle(
        _textSnippetMeta,
        textSnippet.isAcceptableOrUnknown(
          data['text_snippet']!,
          _textSnippetMeta,
        ),
      );
    }
    if (data.containsKey('snapshot')) {
      context.handle(
        _snapshotMeta,
        snapshot.isAcceptableOrUnknown(data['snapshot']!, _snapshotMeta),
      );
    }
    if (data.containsKey('needs_review')) {
      context.handle(
        _needsReviewMeta,
        needsReview.isAcceptableOrUnknown(
          data['needs_review']!,
          _needsReviewMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnchorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnchorRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      role: $AnchorsTable.$converterrole.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}role'],
        )!,
      ),
      page: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page'],
      ),
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      ),
      endMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ms'],
      ),
      left: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}left'],
      ),
      top: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}top'],
      ),
      right: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}right'],
      ),
      bottom: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bottom'],
      ),
      textSnippet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_snippet'],
      ),
      snapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}snapshot'],
      ),
      needsReview: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_review'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AnchorsTable createAlias(String alias) {
    return $AnchorsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AnchorRole, String, String> $converterrole =
      const EnumNameConverter<AnchorRole>(AnchorRole.values);
}

class AnchorRow extends DataClass implements Insertable<AnchorRow> {
  final String id;
  final String itemId;
  final String documentId;
  final AnchorRole role;

  /// Page d'un PDF (nulle pour une vidéo depuis v5).
  final int? page;

  /// Extrait d'une vidéo, en millisecondes (v5).
  final int? startMs;
  final int? endMs;
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final String? textSnippet;
  final Uint8List? snapshot;
  final bool needsReview;
  final DateTime createdAt;
  const AnchorRow({
    required this.id,
    required this.itemId,
    required this.documentId,
    required this.role,
    this.page,
    this.startMs,
    this.endMs,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.textSnippet,
    this.snapshot,
    required this.needsReview,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['document_id'] = Variable<String>(documentId);
    {
      map['role'] = Variable<String>($AnchorsTable.$converterrole.toSql(role));
    }
    if (!nullToAbsent || page != null) {
      map['page'] = Variable<int>(page);
    }
    if (!nullToAbsent || startMs != null) {
      map['start_ms'] = Variable<int>(startMs);
    }
    if (!nullToAbsent || endMs != null) {
      map['end_ms'] = Variable<int>(endMs);
    }
    if (!nullToAbsent || left != null) {
      map['left'] = Variable<double>(left);
    }
    if (!nullToAbsent || top != null) {
      map['top'] = Variable<double>(top);
    }
    if (!nullToAbsent || right != null) {
      map['right'] = Variable<double>(right);
    }
    if (!nullToAbsent || bottom != null) {
      map['bottom'] = Variable<double>(bottom);
    }
    if (!nullToAbsent || textSnippet != null) {
      map['text_snippet'] = Variable<String>(textSnippet);
    }
    if (!nullToAbsent || snapshot != null) {
      map['snapshot'] = Variable<Uint8List>(snapshot);
    }
    map['needs_review'] = Variable<bool>(needsReview);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AnchorsCompanion toCompanion(bool nullToAbsent) {
    return AnchorsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      documentId: Value(documentId),
      role: Value(role),
      page: page == null && nullToAbsent ? const Value.absent() : Value(page),
      startMs: startMs == null && nullToAbsent
          ? const Value.absent()
          : Value(startMs),
      endMs: endMs == null && nullToAbsent
          ? const Value.absent()
          : Value(endMs),
      left: left == null && nullToAbsent ? const Value.absent() : Value(left),
      top: top == null && nullToAbsent ? const Value.absent() : Value(top),
      right: right == null && nullToAbsent
          ? const Value.absent()
          : Value(right),
      bottom: bottom == null && nullToAbsent
          ? const Value.absent()
          : Value(bottom),
      textSnippet: textSnippet == null && nullToAbsent
          ? const Value.absent()
          : Value(textSnippet),
      snapshot: snapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(snapshot),
      needsReview: Value(needsReview),
      createdAt: Value(createdAt),
    );
  }

  factory AnchorRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnchorRow(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      documentId: serializer.fromJson<String>(json['documentId']),
      role: $AnchorsTable.$converterrole.fromJson(
        serializer.fromJson<String>(json['role']),
      ),
      page: serializer.fromJson<int?>(json['page']),
      startMs: serializer.fromJson<int?>(json['startMs']),
      endMs: serializer.fromJson<int?>(json['endMs']),
      left: serializer.fromJson<double?>(json['left']),
      top: serializer.fromJson<double?>(json['top']),
      right: serializer.fromJson<double?>(json['right']),
      bottom: serializer.fromJson<double?>(json['bottom']),
      textSnippet: serializer.fromJson<String?>(json['textSnippet']),
      snapshot: serializer.fromJson<Uint8List?>(json['snapshot']),
      needsReview: serializer.fromJson<bool>(json['needsReview']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'documentId': serializer.toJson<String>(documentId),
      'role': serializer.toJson<String>(
        $AnchorsTable.$converterrole.toJson(role),
      ),
      'page': serializer.toJson<int?>(page),
      'startMs': serializer.toJson<int?>(startMs),
      'endMs': serializer.toJson<int?>(endMs),
      'left': serializer.toJson<double?>(left),
      'top': serializer.toJson<double?>(top),
      'right': serializer.toJson<double?>(right),
      'bottom': serializer.toJson<double?>(bottom),
      'textSnippet': serializer.toJson<String?>(textSnippet),
      'snapshot': serializer.toJson<Uint8List?>(snapshot),
      'needsReview': serializer.toJson<bool>(needsReview),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AnchorRow copyWith({
    String? id,
    String? itemId,
    String? documentId,
    AnchorRole? role,
    Value<int?> page = const Value.absent(),
    Value<int?> startMs = const Value.absent(),
    Value<int?> endMs = const Value.absent(),
    Value<double?> left = const Value.absent(),
    Value<double?> top = const Value.absent(),
    Value<double?> right = const Value.absent(),
    Value<double?> bottom = const Value.absent(),
    Value<String?> textSnippet = const Value.absent(),
    Value<Uint8List?> snapshot = const Value.absent(),
    bool? needsReview,
    DateTime? createdAt,
  }) => AnchorRow(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    documentId: documentId ?? this.documentId,
    role: role ?? this.role,
    page: page.present ? page.value : this.page,
    startMs: startMs.present ? startMs.value : this.startMs,
    endMs: endMs.present ? endMs.value : this.endMs,
    left: left.present ? left.value : this.left,
    top: top.present ? top.value : this.top,
    right: right.present ? right.value : this.right,
    bottom: bottom.present ? bottom.value : this.bottom,
    textSnippet: textSnippet.present ? textSnippet.value : this.textSnippet,
    snapshot: snapshot.present ? snapshot.value : this.snapshot,
    needsReview: needsReview ?? this.needsReview,
    createdAt: createdAt ?? this.createdAt,
  );
  AnchorRow copyWithCompanion(AnchorsCompanion data) {
    return AnchorRow(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      role: data.role.present ? data.role.value : this.role,
      page: data.page.present ? data.page.value : this.page,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      left: data.left.present ? data.left.value : this.left,
      top: data.top.present ? data.top.value : this.top,
      right: data.right.present ? data.right.value : this.right,
      bottom: data.bottom.present ? data.bottom.value : this.bottom,
      textSnippet: data.textSnippet.present
          ? data.textSnippet.value
          : this.textSnippet,
      snapshot: data.snapshot.present ? data.snapshot.value : this.snapshot,
      needsReview: data.needsReview.present
          ? data.needsReview.value
          : this.needsReview,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnchorRow(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('documentId: $documentId, ')
          ..write('role: $role, ')
          ..write('page: $page, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('left: $left, ')
          ..write('top: $top, ')
          ..write('right: $right, ')
          ..write('bottom: $bottom, ')
          ..write('textSnippet: $textSnippet, ')
          ..write('snapshot: $snapshot, ')
          ..write('needsReview: $needsReview, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    documentId,
    role,
    page,
    startMs,
    endMs,
    left,
    top,
    right,
    bottom,
    textSnippet,
    $driftBlobEquality.hash(snapshot),
    needsReview,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnchorRow &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.documentId == this.documentId &&
          other.role == this.role &&
          other.page == this.page &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.left == this.left &&
          other.top == this.top &&
          other.right == this.right &&
          other.bottom == this.bottom &&
          other.textSnippet == this.textSnippet &&
          $driftBlobEquality.equals(other.snapshot, this.snapshot) &&
          other.needsReview == this.needsReview &&
          other.createdAt == this.createdAt);
}

class AnchorsCompanion extends UpdateCompanion<AnchorRow> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String> documentId;
  final Value<AnchorRole> role;
  final Value<int?> page;
  final Value<int?> startMs;
  final Value<int?> endMs;
  final Value<double?> left;
  final Value<double?> top;
  final Value<double?> right;
  final Value<double?> bottom;
  final Value<String?> textSnippet;
  final Value<Uint8List?> snapshot;
  final Value<bool> needsReview;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AnchorsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.documentId = const Value.absent(),
    this.role = const Value.absent(),
    this.page = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.left = const Value.absent(),
    this.top = const Value.absent(),
    this.right = const Value.absent(),
    this.bottom = const Value.absent(),
    this.textSnippet = const Value.absent(),
    this.snapshot = const Value.absent(),
    this.needsReview = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnchorsCompanion.insert({
    required String id,
    required String itemId,
    required String documentId,
    required AnchorRole role,
    this.page = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.left = const Value.absent(),
    this.top = const Value.absent(),
    this.right = const Value.absent(),
    this.bottom = const Value.absent(),
    this.textSnippet = const Value.absent(),
    this.snapshot = const Value.absent(),
    this.needsReview = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       documentId = Value(documentId),
       role = Value(role),
       createdAt = Value(createdAt);
  static Insertable<AnchorRow> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? documentId,
    Expression<String>? role,
    Expression<int>? page,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<double>? left,
    Expression<double>? top,
    Expression<double>? right,
    Expression<double>? bottom,
    Expression<String>? textSnippet,
    Expression<Uint8List>? snapshot,
    Expression<bool>? needsReview,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (documentId != null) 'document_id': documentId,
      if (role != null) 'role': role,
      if (page != null) 'page': page,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (left != null) 'left': left,
      if (top != null) 'top': top,
      if (right != null) 'right': right,
      if (bottom != null) 'bottom': bottom,
      if (textSnippet != null) 'text_snippet': textSnippet,
      if (snapshot != null) 'snapshot': snapshot,
      if (needsReview != null) 'needs_review': needsReview,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnchorsCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<String>? documentId,
    Value<AnchorRole>? role,
    Value<int?>? page,
    Value<int?>? startMs,
    Value<int?>? endMs,
    Value<double?>? left,
    Value<double?>? top,
    Value<double?>? right,
    Value<double?>? bottom,
    Value<String?>? textSnippet,
    Value<Uint8List?>? snapshot,
    Value<bool>? needsReview,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AnchorsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      documentId: documentId ?? this.documentId,
      role: role ?? this.role,
      page: page ?? this.page,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
      textSnippet: textSnippet ?? this.textSnippet,
      snapshot: snapshot ?? this.snapshot,
      needsReview: needsReview ?? this.needsReview,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(
        $AnchorsTable.$converterrole.toSql(role.value),
      );
    }
    if (page.present) {
      map['page'] = Variable<int>(page.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (left.present) {
      map['left'] = Variable<double>(left.value);
    }
    if (top.present) {
      map['top'] = Variable<double>(top.value);
    }
    if (right.present) {
      map['right'] = Variable<double>(right.value);
    }
    if (bottom.present) {
      map['bottom'] = Variable<double>(bottom.value);
    }
    if (textSnippet.present) {
      map['text_snippet'] = Variable<String>(textSnippet.value);
    }
    if (snapshot.present) {
      map['snapshot'] = Variable<Uint8List>(snapshot.value);
    }
    if (needsReview.present) {
      map['needs_review'] = Variable<bool>(needsReview.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnchorsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('documentId: $documentId, ')
          ..write('role: $role, ')
          ..write('page: $page, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('left: $left, ')
          ..write('top: $top, ')
          ..write('right: $right, ')
          ..write('bottom: $bottom, ')
          ..write('textSnippet: $textSnippet, ')
          ..write('snapshot: $snapshot, ')
          ..write('needsReview: $needsReview, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, NoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _pageMeta = const VerificationMeta('page');
  @override
  late final GeneratedColumn<int> page = GeneratedColumn<int>(
    'page',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leftMeta = const VerificationMeta('left');
  @override
  late final GeneratedColumn<double> left = GeneratedColumn<double>(
    'left',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _topMeta = const VerificationMeta('top');
  @override
  late final GeneratedColumn<double> top = GeneratedColumn<double>(
    'top',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rightMeta = const VerificationMeta('right');
  @override
  late final GeneratedColumn<double> right = GeneratedColumn<double>(
    'right',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bottomMeta = const VerificationMeta('bottom');
  @override
  late final GeneratedColumn<double> bottom = GeneratedColumn<double>(
    'bottom',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snapshotMeta = const VerificationMeta(
    'snapshot',
  );
  @override
  late final GeneratedColumn<Uint8List> snapshot = GeneratedColumn<Uint8List>(
    'snapshot',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _inkMeta = const VerificationMeta('ink');
  @override
  late final GeneratedColumn<String> ink = GeneratedColumn<String>(
    'ink',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    body,
    documentId,
    page,
    startMs,
    endMs,
    left,
    top,
    right,
    bottom,
    snapshot,
    itemId,
    ink,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    }
    if (data.containsKey('page')) {
      context.handle(
        _pageMeta,
        page.isAcceptableOrUnknown(data['page']!, _pageMeta),
      );
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    }
    if (data.containsKey('end_ms')) {
      context.handle(
        _endMsMeta,
        endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta),
      );
    }
    if (data.containsKey('left')) {
      context.handle(
        _leftMeta,
        left.isAcceptableOrUnknown(data['left']!, _leftMeta),
      );
    }
    if (data.containsKey('top')) {
      context.handle(
        _topMeta,
        top.isAcceptableOrUnknown(data['top']!, _topMeta),
      );
    }
    if (data.containsKey('right')) {
      context.handle(
        _rightMeta,
        right.isAcceptableOrUnknown(data['right']!, _rightMeta),
      );
    }
    if (data.containsKey('bottom')) {
      context.handle(
        _bottomMeta,
        bottom.isAcceptableOrUnknown(data['bottom']!, _bottomMeta),
      );
    }
    if (data.containsKey('snapshot')) {
      context.handle(
        _snapshotMeta,
        snapshot.isAcceptableOrUnknown(data['snapshot']!, _snapshotMeta),
      );
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('ink')) {
      context.handle(
        _inkMeta,
        ink.isAcceptableOrUnknown(data['ink']!, _inkMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      ),
      page: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page'],
      ),
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      ),
      endMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ms'],
      ),
      left: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}left'],
      ),
      top: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}top'],
      ),
      right: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}right'],
      ),
      bottom: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bottom'],
      ),
      snapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}snapshot'],
      ),
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      ),
      ink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ink'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class NoteRow extends DataClass implements Insertable<NoteRow> {
  final String id;
  final String body;
  final String? documentId;
  final int? page;

  /// Moment ou extrait d'une vidéo, en millisecondes (v5).
  final int? startMs;
  final int? endMs;
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final Uint8List? snapshot;
  final String? itemId;

  /// Écriture manuscrite, JSON de `Ink` (v8).
  final String? ink;
  final DateTime createdAt;
  final DateTime updatedAt;
  const NoteRow({
    required this.id,
    required this.body,
    this.documentId,
    this.page,
    this.startMs,
    this.endMs,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.snapshot,
    this.itemId,
    this.ink,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || documentId != null) {
      map['document_id'] = Variable<String>(documentId);
    }
    if (!nullToAbsent || page != null) {
      map['page'] = Variable<int>(page);
    }
    if (!nullToAbsent || startMs != null) {
      map['start_ms'] = Variable<int>(startMs);
    }
    if (!nullToAbsent || endMs != null) {
      map['end_ms'] = Variable<int>(endMs);
    }
    if (!nullToAbsent || left != null) {
      map['left'] = Variable<double>(left);
    }
    if (!nullToAbsent || top != null) {
      map['top'] = Variable<double>(top);
    }
    if (!nullToAbsent || right != null) {
      map['right'] = Variable<double>(right);
    }
    if (!nullToAbsent || bottom != null) {
      map['bottom'] = Variable<double>(bottom);
    }
    if (!nullToAbsent || snapshot != null) {
      map['snapshot'] = Variable<Uint8List>(snapshot);
    }
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<String>(itemId);
    }
    if (!nullToAbsent || ink != null) {
      map['ink'] = Variable<String>(ink);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      body: Value(body),
      documentId: documentId == null && nullToAbsent
          ? const Value.absent()
          : Value(documentId),
      page: page == null && nullToAbsent ? const Value.absent() : Value(page),
      startMs: startMs == null && nullToAbsent
          ? const Value.absent()
          : Value(startMs),
      endMs: endMs == null && nullToAbsent
          ? const Value.absent()
          : Value(endMs),
      left: left == null && nullToAbsent ? const Value.absent() : Value(left),
      top: top == null && nullToAbsent ? const Value.absent() : Value(top),
      right: right == null && nullToAbsent
          ? const Value.absent()
          : Value(right),
      bottom: bottom == null && nullToAbsent
          ? const Value.absent()
          : Value(bottom),
      snapshot: snapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(snapshot),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      ink: ink == null && nullToAbsent ? const Value.absent() : Value(ink),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory NoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteRow(
      id: serializer.fromJson<String>(json['id']),
      body: serializer.fromJson<String>(json['body']),
      documentId: serializer.fromJson<String?>(json['documentId']),
      page: serializer.fromJson<int?>(json['page']),
      startMs: serializer.fromJson<int?>(json['startMs']),
      endMs: serializer.fromJson<int?>(json['endMs']),
      left: serializer.fromJson<double?>(json['left']),
      top: serializer.fromJson<double?>(json['top']),
      right: serializer.fromJson<double?>(json['right']),
      bottom: serializer.fromJson<double?>(json['bottom']),
      snapshot: serializer.fromJson<Uint8List?>(json['snapshot']),
      itemId: serializer.fromJson<String?>(json['itemId']),
      ink: serializer.fromJson<String?>(json['ink']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'body': serializer.toJson<String>(body),
      'documentId': serializer.toJson<String?>(documentId),
      'page': serializer.toJson<int?>(page),
      'startMs': serializer.toJson<int?>(startMs),
      'endMs': serializer.toJson<int?>(endMs),
      'left': serializer.toJson<double?>(left),
      'top': serializer.toJson<double?>(top),
      'right': serializer.toJson<double?>(right),
      'bottom': serializer.toJson<double?>(bottom),
      'snapshot': serializer.toJson<Uint8List?>(snapshot),
      'itemId': serializer.toJson<String?>(itemId),
      'ink': serializer.toJson<String?>(ink),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  NoteRow copyWith({
    String? id,
    String? body,
    Value<String?> documentId = const Value.absent(),
    Value<int?> page = const Value.absent(),
    Value<int?> startMs = const Value.absent(),
    Value<int?> endMs = const Value.absent(),
    Value<double?> left = const Value.absent(),
    Value<double?> top = const Value.absent(),
    Value<double?> right = const Value.absent(),
    Value<double?> bottom = const Value.absent(),
    Value<Uint8List?> snapshot = const Value.absent(),
    Value<String?> itemId = const Value.absent(),
    Value<String?> ink = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => NoteRow(
    id: id ?? this.id,
    body: body ?? this.body,
    documentId: documentId.present ? documentId.value : this.documentId,
    page: page.present ? page.value : this.page,
    startMs: startMs.present ? startMs.value : this.startMs,
    endMs: endMs.present ? endMs.value : this.endMs,
    left: left.present ? left.value : this.left,
    top: top.present ? top.value : this.top,
    right: right.present ? right.value : this.right,
    bottom: bottom.present ? bottom.value : this.bottom,
    snapshot: snapshot.present ? snapshot.value : this.snapshot,
    itemId: itemId.present ? itemId.value : this.itemId,
    ink: ink.present ? ink.value : this.ink,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  NoteRow copyWithCompanion(NotesCompanion data) {
    return NoteRow(
      id: data.id.present ? data.id.value : this.id,
      body: data.body.present ? data.body.value : this.body,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      page: data.page.present ? data.page.value : this.page,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      left: data.left.present ? data.left.value : this.left,
      top: data.top.present ? data.top.value : this.top,
      right: data.right.present ? data.right.value : this.right,
      bottom: data.bottom.present ? data.bottom.value : this.bottom,
      snapshot: data.snapshot.present ? data.snapshot.value : this.snapshot,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      ink: data.ink.present ? data.ink.value : this.ink,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteRow(')
          ..write('id: $id, ')
          ..write('body: $body, ')
          ..write('documentId: $documentId, ')
          ..write('page: $page, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('left: $left, ')
          ..write('top: $top, ')
          ..write('right: $right, ')
          ..write('bottom: $bottom, ')
          ..write('snapshot: $snapshot, ')
          ..write('itemId: $itemId, ')
          ..write('ink: $ink, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    body,
    documentId,
    page,
    startMs,
    endMs,
    left,
    top,
    right,
    bottom,
    $driftBlobEquality.hash(snapshot),
    itemId,
    ink,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteRow &&
          other.id == this.id &&
          other.body == this.body &&
          other.documentId == this.documentId &&
          other.page == this.page &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.left == this.left &&
          other.top == this.top &&
          other.right == this.right &&
          other.bottom == this.bottom &&
          $driftBlobEquality.equals(other.snapshot, this.snapshot) &&
          other.itemId == this.itemId &&
          other.ink == this.ink &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class NotesCompanion extends UpdateCompanion<NoteRow> {
  final Value<String> id;
  final Value<String> body;
  final Value<String?> documentId;
  final Value<int?> page;
  final Value<int?> startMs;
  final Value<int?> endMs;
  final Value<double?> left;
  final Value<double?> top;
  final Value<double?> right;
  final Value<double?> bottom;
  final Value<Uint8List?> snapshot;
  final Value<String?> itemId;
  final Value<String?> ink;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.body = const Value.absent(),
    this.documentId = const Value.absent(),
    this.page = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.left = const Value.absent(),
    this.top = const Value.absent(),
    this.right = const Value.absent(),
    this.bottom = const Value.absent(),
    this.snapshot = const Value.absent(),
    this.itemId = const Value.absent(),
    this.ink = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    required String id,
    required String body,
    this.documentId = const Value.absent(),
    this.page = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.left = const Value.absent(),
    this.top = const Value.absent(),
    this.right = const Value.absent(),
    this.bottom = const Value.absent(),
    this.snapshot = const Value.absent(),
    this.itemId = const Value.absent(),
    this.ink = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       body = Value(body),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<NoteRow> custom({
    Expression<String>? id,
    Expression<String>? body,
    Expression<String>? documentId,
    Expression<int>? page,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<double>? left,
    Expression<double>? top,
    Expression<double>? right,
    Expression<double>? bottom,
    Expression<Uint8List>? snapshot,
    Expression<String>? itemId,
    Expression<String>? ink,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (body != null) 'body': body,
      if (documentId != null) 'document_id': documentId,
      if (page != null) 'page': page,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (left != null) 'left': left,
      if (top != null) 'top': top,
      if (right != null) 'right': right,
      if (bottom != null) 'bottom': bottom,
      if (snapshot != null) 'snapshot': snapshot,
      if (itemId != null) 'item_id': itemId,
      if (ink != null) 'ink': ink,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? id,
    Value<String>? body,
    Value<String?>? documentId,
    Value<int?>? page,
    Value<int?>? startMs,
    Value<int?>? endMs,
    Value<double?>? left,
    Value<double?>? top,
    Value<double?>? right,
    Value<double?>? bottom,
    Value<Uint8List?>? snapshot,
    Value<String?>? itemId,
    Value<String?>? ink,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      body: body ?? this.body,
      documentId: documentId ?? this.documentId,
      page: page ?? this.page,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
      snapshot: snapshot ?? this.snapshot,
      itemId: itemId ?? this.itemId,
      ink: ink ?? this.ink,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (page.present) {
      map['page'] = Variable<int>(page.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (left.present) {
      map['left'] = Variable<double>(left.value);
    }
    if (top.present) {
      map['top'] = Variable<double>(top.value);
    }
    if (right.present) {
      map['right'] = Variable<double>(right.value);
    }
    if (bottom.present) {
      map['bottom'] = Variable<double>(bottom.value);
    }
    if (snapshot.present) {
      map['snapshot'] = Variable<Uint8List>(snapshot.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (ink.present) {
      map['ink'] = Variable<String>(ink.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('body: $body, ')
          ..write('documentId: $documentId, ')
          ..write('page: $page, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('left: $left, ')
          ..write('top: $top, ')
          ..write('right: $right, ')
          ..write('bottom: $bottom, ')
          ..write('snapshot: $snapshot, ')
          ..write('itemId: $itemId, ')
          ..write('ink: $ink, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ResourceLinksTable extends ResourceLinks
    with TableInfo<$ResourceLinksTable, ResourceLinkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResourceLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
    'node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES nodes (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [documentId, nodeId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'resource_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResourceLinkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('node_id')) {
      context.handle(
        _nodeIdMeta,
        nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {documentId, nodeId};
  @override
  ResourceLinkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResourceLinkRow(
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      nodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_id'],
      )!,
    );
  }

  @override
  $ResourceLinksTable createAlias(String alias) {
    return $ResourceLinksTable(attachedDatabase, alias);
  }
}

class ResourceLinkRow extends DataClass implements Insertable<ResourceLinkRow> {
  final String documentId;
  final String nodeId;
  const ResourceLinkRow({required this.documentId, required this.nodeId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['document_id'] = Variable<String>(documentId);
    map['node_id'] = Variable<String>(nodeId);
    return map;
  }

  ResourceLinksCompanion toCompanion(bool nullToAbsent) {
    return ResourceLinksCompanion(
      documentId: Value(documentId),
      nodeId: Value(nodeId),
    );
  }

  factory ResourceLinkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResourceLinkRow(
      documentId: serializer.fromJson<String>(json['documentId']),
      nodeId: serializer.fromJson<String>(json['nodeId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentId': serializer.toJson<String>(documentId),
      'nodeId': serializer.toJson<String>(nodeId),
    };
  }

  ResourceLinkRow copyWith({String? documentId, String? nodeId}) =>
      ResourceLinkRow(
        documentId: documentId ?? this.documentId,
        nodeId: nodeId ?? this.nodeId,
      );
  ResourceLinkRow copyWithCompanion(ResourceLinksCompanion data) {
    return ResourceLinkRow(
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResourceLinkRow(')
          ..write('documentId: $documentId, ')
          ..write('nodeId: $nodeId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(documentId, nodeId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResourceLinkRow &&
          other.documentId == this.documentId &&
          other.nodeId == this.nodeId);
}

class ResourceLinksCompanion extends UpdateCompanion<ResourceLinkRow> {
  final Value<String> documentId;
  final Value<String> nodeId;
  final Value<int> rowid;
  const ResourceLinksCompanion({
    this.documentId = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ResourceLinksCompanion.insert({
    required String documentId,
    required String nodeId,
    this.rowid = const Value.absent(),
  }) : documentId = Value(documentId),
       nodeId = Value(nodeId);
  static Insertable<ResourceLinkRow> custom({
    Expression<String>? documentId,
    Expression<String>? nodeId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentId != null) 'document_id': documentId,
      if (nodeId != null) 'node_id': nodeId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ResourceLinksCompanion copyWith({
    Value<String>? documentId,
    Value<String>? nodeId,
    Value<int>? rowid,
  }) {
    return ResourceLinksCompanion(
      documentId: documentId ?? this.documentId,
      nodeId: nodeId ?? this.nodeId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResourceLinksCompanion(')
          ..write('documentId: $documentId, ')
          ..write('nodeId: $nodeId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PrerequisitesTable extends Prerequisites
    with TableInfo<$PrerequisitesTable, PrerequisiteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrerequisitesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _requiresIdMeta = const VerificationMeta(
    'requiresId',
  );
  @override
  late final GeneratedColumn<String> requiresId = GeneratedColumn<String>(
    'requires_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [itemId, requiresId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prerequisites';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrerequisiteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('requires_id')) {
      context.handle(
        _requiresIdMeta,
        requiresId.isAcceptableOrUnknown(data['requires_id']!, _requiresIdMeta),
      );
    } else if (isInserting) {
      context.missing(_requiresIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId, requiresId};
  @override
  PrerequisiteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrerequisiteRow(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      requiresId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}requires_id'],
      )!,
    );
  }

  @override
  $PrerequisitesTable createAlias(String alias) {
    return $PrerequisitesTable(attachedDatabase, alias);
  }
}

class PrerequisiteRow extends DataClass implements Insertable<PrerequisiteRow> {
  final String itemId;
  final String requiresId;
  const PrerequisiteRow({required this.itemId, required this.requiresId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['requires_id'] = Variable<String>(requiresId);
    return map;
  }

  PrerequisitesCompanion toCompanion(bool nullToAbsent) {
    return PrerequisitesCompanion(
      itemId: Value(itemId),
      requiresId: Value(requiresId),
    );
  }

  factory PrerequisiteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrerequisiteRow(
      itemId: serializer.fromJson<String>(json['itemId']),
      requiresId: serializer.fromJson<String>(json['requiresId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'requiresId': serializer.toJson<String>(requiresId),
    };
  }

  PrerequisiteRow copyWith({String? itemId, String? requiresId}) =>
      PrerequisiteRow(
        itemId: itemId ?? this.itemId,
        requiresId: requiresId ?? this.requiresId,
      );
  PrerequisiteRow copyWithCompanion(PrerequisitesCompanion data) {
    return PrerequisiteRow(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      requiresId: data.requiresId.present
          ? data.requiresId.value
          : this.requiresId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrerequisiteRow(')
          ..write('itemId: $itemId, ')
          ..write('requiresId: $requiresId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, requiresId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrerequisiteRow &&
          other.itemId == this.itemId &&
          other.requiresId == this.requiresId);
}

class PrerequisitesCompanion extends UpdateCompanion<PrerequisiteRow> {
  final Value<String> itemId;
  final Value<String> requiresId;
  final Value<int> rowid;
  const PrerequisitesCompanion({
    this.itemId = const Value.absent(),
    this.requiresId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PrerequisitesCompanion.insert({
    required String itemId,
    required String requiresId,
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       requiresId = Value(requiresId);
  static Insertable<PrerequisiteRow> custom({
    Expression<String>? itemId,
    Expression<String>? requiresId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (requiresId != null) 'requires_id': requiresId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PrerequisitesCompanion copyWith({
    Value<String>? itemId,
    Value<String>? requiresId,
    Value<int>? rowid,
  }) {
    return PrerequisitesCompanion(
      itemId: itemId ?? this.itemId,
      requiresId: requiresId ?? this.requiresId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (requiresId.present) {
      map['requires_id'] = Variable<String>(requiresId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrerequisitesCompanion(')
          ..write('itemId: $itemId, ')
          ..write('requiresId: $requiresId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$VergerDatabase extends GeneratedDatabase {
  _$VergerDatabase(QueryExecutor e) : super(e);
  $VergerDatabaseManager get managers => $VergerDatabaseManager(this);
  late final $NodesTable nodes = $NodesTable(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $ReviewLogsTable reviewLogs = $ReviewLogsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $DocumentsTable documents = $DocumentsTable(this);
  late final $DocumentFilesTable documentFiles = $DocumentFilesTable(this);
  late final $AnchorsTable anchors = $AnchorsTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $ResourceLinksTable resourceLinks = $ResourceLinksTable(this);
  late final $PrerequisitesTable prerequisites = $PrerequisitesTable(this);
  late final Index nodesParent = Index(
    'nodes_parent',
    'CREATE INDEX nodes_parent ON nodes (parent_id)',
  );
  late final Index itemsNode = Index(
    'items_node',
    'CREATE INDEX items_node ON items (node_id)',
  );
  late final Index itemsDue = Index(
    'items_due',
    'CREATE INDEX items_due ON items (due)',
  );
  late final Index reviewLogsItem = Index(
    'review_logs_item',
    'CREATE INDEX review_logs_item ON review_logs (item_id)',
  );
  late final Index anchorsItem = Index(
    'anchors_item',
    'CREATE INDEX anchors_item ON anchors (item_id)',
  );
  late final Index anchorsDocument = Index(
    'anchors_document',
    'CREATE INDEX anchors_document ON anchors (document_id)',
  );
  late final Index notesDocument = Index(
    'notes_document',
    'CREATE INDEX notes_document ON notes (document_id)',
  );
  late final Index notesItem = Index(
    'notes_item',
    'CREATE INDEX notes_item ON notes (item_id)',
  );
  late final Index resourceLinksNode = Index(
    'resource_links_node',
    'CREATE INDEX resource_links_node ON resource_links (node_id)',
  );
  late final Index prerequisitesRequires = Index(
    'prerequisites_requires',
    'CREATE INDEX prerequisites_requires ON prerequisites (requires_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    nodes,
    items,
    reviewLogs,
    settings,
    documents,
    documentFiles,
    anchors,
    notes,
    resourceLinks,
    prerequisites,
    nodesParent,
    itemsNode,
    itemsDue,
    reviewLogsItem,
    anchorsItem,
    anchorsDocument,
    notesDocument,
    notesItem,
    resourceLinksNode,
    prerequisitesRequires,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('review_logs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'documents',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('document_files', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('anchors', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'documents',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('anchors', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'documents',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('notes', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('notes', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'documents',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('resource_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'nodes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('resource_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('prerequisites', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('prerequisites', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$NodesTableCreateCompanionBuilder =
    NodesCompanion Function({
      required String id,
      Value<String?> parentId,
      required String title,
      required int sortIndex,
      Value<String?> curriculumKey,
      required NodeOrigin origin,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$NodesTableUpdateCompanionBuilder =
    NodesCompanion Function({
      Value<String> id,
      Value<String?> parentId,
      Value<String> title,
      Value<int> sortIndex,
      Value<String?> curriculumKey,
      Value<NodeOrigin> origin,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$NodesTableReferences
    extends BaseReferences<_$VergerDatabase, $NodesTable, NodeRow> {
  $$NodesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NodesTable _parentIdTable(_$VergerDatabase db) =>
      db.nodes.createAlias('nodes__parent_id__nodes__id');

  $$NodesTableProcessedTableManager? get parentId {
    final $_column = $_itemColumn<String>('parent_id');
    if ($_column == null) return null;
    final manager = $$NodesTableTableManager(
      $_db,
      $_db.nodes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ItemsTable, List<ItemRow>> _itemsRefsTable(
    _$VergerDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.items,
    aliasName: 'nodes__id__items__node_id',
  );

  $$ItemsTableProcessedTableManager get itemsRefs {
    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.nodeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_itemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ResourceLinksTable, List<ResourceLinkRow>>
  _resourceLinksRefsTable(_$VergerDatabase db) => MultiTypedResultKey.fromTable(
    db.resourceLinks,
    aliasName: 'nodes__id__resource_links__node_id',
  );

  $$ResourceLinksTableProcessedTableManager get resourceLinksRefs {
    final manager = $$ResourceLinksTableTableManager(
      $_db,
      $_db.resourceLinks,
    ).filter((f) => f.nodeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_resourceLinksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NodesTableFilterComposer
    extends Composer<_$VergerDatabase, $NodesTable> {
  $$NodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get curriculumKey => $composableBuilder(
    column: $table.curriculumKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<NodeOrigin, NodeOrigin, String> get origin =>
      $composableBuilder(
        column: $table.origin,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$NodesTableFilterComposer get parentId {
    final $$NodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.nodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NodesTableFilterComposer(
            $db: $db,
            $table: $db.nodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> itemsRefs(
    Expression<bool> Function($$ItemsTableFilterComposer f) f,
  ) {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.nodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> resourceLinksRefs(
    Expression<bool> Function($$ResourceLinksTableFilterComposer f) f,
  ) {
    final $$ResourceLinksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.resourceLinks,
      getReferencedColumn: (t) => t.nodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ResourceLinksTableFilterComposer(
            $db: $db,
            $table: $db.resourceLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NodesTableOrderingComposer
    extends Composer<_$VergerDatabase, $NodesTable> {
  $$NodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get curriculumKey => $composableBuilder(
    column: $table.curriculumKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$NodesTableOrderingComposer get parentId {
    final $$NodesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.nodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NodesTableOrderingComposer(
            $db: $db,
            $table: $db.nodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NodesTableAnnotationComposer
    extends Composer<_$VergerDatabase, $NodesTable> {
  $$NodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<String> get curriculumKey => $composableBuilder(
    column: $table.curriculumKey,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<NodeOrigin, String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$NodesTableAnnotationComposer get parentId {
    final $$NodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.nodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NodesTableAnnotationComposer(
            $db: $db,
            $table: $db.nodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> itemsRefs<T extends Object>(
    Expression<T> Function($$ItemsTableAnnotationComposer a) f,
  ) {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.nodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> resourceLinksRefs<T extends Object>(
    Expression<T> Function($$ResourceLinksTableAnnotationComposer a) f,
  ) {
    final $$ResourceLinksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.resourceLinks,
      getReferencedColumn: (t) => t.nodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ResourceLinksTableAnnotationComposer(
            $db: $db,
            $table: $db.resourceLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NodesTableTableManager
    extends
        RootTableManager<
          _$VergerDatabase,
          $NodesTable,
          NodeRow,
          $$NodesTableFilterComposer,
          $$NodesTableOrderingComposer,
          $$NodesTableAnnotationComposer,
          $$NodesTableCreateCompanionBuilder,
          $$NodesTableUpdateCompanionBuilder,
          (NodeRow, $$NodesTableReferences),
          NodeRow,
          PrefetchHooks Function({
            bool parentId,
            bool itemsRefs,
            bool resourceLinksRefs,
          })
        > {
  $$NodesTableTableManager(_$VergerDatabase db, $NodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<String?> curriculumKey = const Value.absent(),
                Value<NodeOrigin> origin = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NodesCompanion(
                id: id,
                parentId: parentId,
                title: title,
                sortIndex: sortIndex,
                curriculumKey: curriculumKey,
                origin: origin,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> parentId = const Value.absent(),
                required String title,
                required int sortIndex,
                Value<String?> curriculumKey = const Value.absent(),
                required NodeOrigin origin,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => NodesCompanion.insert(
                id: id,
                parentId: parentId,
                title: title,
                sortIndex: sortIndex,
                curriculumKey: curriculumKey,
                origin: origin,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NodesTable, NodeRow>(table),
                  $$NodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                parentId = false,
                itemsRefs = false,
                resourceLinksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (itemsRefs) db.items,
                    if (resourceLinksRefs) db.resourceLinks,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (parentId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parentId,
                                    referencedTable: $$NodesTableReferences
                                        ._parentIdTable(db),
                                    referencedColumn: $$NodesTableReferences
                                        ._parentIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (itemsRefs)
                        await $_getPrefetchedData<
                          NodeRow,
                          $NodesTable,
                          ItemRow
                        >(
                          currentTable: table,
                          referencedTable: $$NodesTableReferences
                              ._itemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NodesTableReferences(db, table, p0).itemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.nodeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (resourceLinksRefs)
                        await $_getPrefetchedData<
                          NodeRow,
                          $NodesTable,
                          ResourceLinkRow
                        >(
                          currentTable: table,
                          referencedTable: $$NodesTableReferences
                              ._resourceLinksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NodesTableReferences(
                                db,
                                table,
                                p0,
                              ).resourceLinksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.nodeId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$NodesTableProcessedTableManager =
    ProcessedTableManager<
      _$VergerDatabase,
      $NodesTable,
      NodeRow,
      $$NodesTableFilterComposer,
      $$NodesTableOrderingComposer,
      $$NodesTableAnnotationComposer,
      $$NodesTableCreateCompanionBuilder,
      $$NodesTableUpdateCompanionBuilder,
      (NodeRow, $$NodesTableReferences),
      NodeRow,
      PrefetchHooks Function({
        bool parentId,
        bool itemsRefs,
        bool resourceLinksRefs,
      })
    >;
typedef $$ItemsTableCreateCompanionBuilder =
    ItemsCompanion Function({
      required String id,
      required String nodeId,
      required ItemKind kind,
      required String title,
      Value<String?> body,
      Value<ExerciseLevel?> level,
      Value<int> sortIndex,
      Value<bool> suspended,
      required DateTime createdAt,
      required DateTime updatedAt,
      required LearningPhase phase,
      Value<int?> step,
      Value<double?> stability,
      Value<double?> difficulty,
      Value<DateTime?> due,
      Value<DateTime?> lastReview,
      Value<int> reps,
      Value<int> lapses,
      Value<int> rowid,
    });
typedef $$ItemsTableUpdateCompanionBuilder =
    ItemsCompanion Function({
      Value<String> id,
      Value<String> nodeId,
      Value<ItemKind> kind,
      Value<String> title,
      Value<String?> body,
      Value<ExerciseLevel?> level,
      Value<int> sortIndex,
      Value<bool> suspended,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<LearningPhase> phase,
      Value<int?> step,
      Value<double?> stability,
      Value<double?> difficulty,
      Value<DateTime?> due,
      Value<DateTime?> lastReview,
      Value<int> reps,
      Value<int> lapses,
      Value<int> rowid,
    });

final class $$ItemsTableReferences
    extends BaseReferences<_$VergerDatabase, $ItemsTable, ItemRow> {
  $$ItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NodesTable _nodeIdTable(_$VergerDatabase db) =>
      db.nodes.createAlias('items__node_id__nodes__id');

  $$NodesTableProcessedTableManager get nodeId {
    final $_column = $_itemColumn<String>('node_id')!;

    final manager = $$NodesTableTableManager(
      $_db,
      $_db.nodes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_nodeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ReviewLogsTable, List<ReviewLogRow>>
  _reviewLogsRefsTable(_$VergerDatabase db) => MultiTypedResultKey.fromTable(
    db.reviewLogs,
    aliasName: 'items__id__review_logs__item_id',
  );

  $$ReviewLogsTableProcessedTableManager get reviewLogsRefs {
    final manager = $$ReviewLogsTableTableManager(
      $_db,
      $_db.reviewLogs,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_reviewLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AnchorsTable, List<AnchorRow>> _anchorsRefsTable(
    _$VergerDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.anchors,
    aliasName: 'items__id__anchors__item_id',
  );

  $$AnchorsTableProcessedTableManager get anchorsRefs {
    final manager = $$AnchorsTableTableManager(
      $_db,
      $_db.anchors,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_anchorsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NotesTable, List<NoteRow>> _notesRefsTable(
    _$VergerDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.notes,
    aliasName: 'items__id__notes__item_id',
  );

  $$NotesTableProcessedTableManager get notesRefs {
    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_notesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ItemsTableFilterComposer
    extends Composer<_$VergerDatabase, $ItemsTable> {
  $$ItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ItemKind, ItemKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ExerciseLevel?, ExerciseLevel, String>
  get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get suspended => $composableBuilder(
    column: $table.suspended,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LearningPhase, LearningPhase, String>
  get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get step => $composableBuilder(
    column: $table.step,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnFilters(column),
  );

  $$NodesTableFilterComposer get nodeId {
    final $$NodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.nodeId,
      referencedTable: $db.nodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NodesTableFilterComposer(
            $db: $db,
            $table: $db.nodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> reviewLogsRefs(
    Expression<bool> Function($$ReviewLogsTableFilterComposer f) f,
  ) {
    final $$ReviewLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewLogs,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewLogsTableFilterComposer(
            $db: $db,
            $table: $db.reviewLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> anchorsRefs(
    Expression<bool> Function($$AnchorsTableFilterComposer f) f,
  ) {
    final $$AnchorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.anchors,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnchorsTableFilterComposer(
            $db: $db,
            $table: $db.anchors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> notesRefs(
    Expression<bool> Function($$NotesTableFilterComposer f) f,
  ) {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItemsTableOrderingComposer
    extends Composer<_$VergerDatabase, $ItemsTable> {
  $$ItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get suspended => $composableBuilder(
    column: $table.suspended,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get step => $composableBuilder(
    column: $table.step,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stability => $composableBuilder(
    column: $table.stability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get due => $composableBuilder(
    column: $table.due,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnOrderings(column),
  );

  $$NodesTableOrderingComposer get nodeId {
    final $$NodesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.nodeId,
      referencedTable: $db.nodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NodesTableOrderingComposer(
            $db: $db,
            $table: $db.nodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemsTableAnnotationComposer
    extends Composer<_$VergerDatabase, $ItemsTable> {
  $$ItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ItemKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ExerciseLevel?, String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<bool> get suspended =>
      $composableBuilder(column: $table.suspended, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LearningPhase, String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<int> get step =>
      $composableBuilder(column: $table.step, builder: (column) => column);

  GeneratedColumn<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => column);

  GeneratedColumn<double> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get due =>
      $composableBuilder(column: $table.due, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReview => $composableBuilder(
    column: $table.lastReview,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => column);

  $$NodesTableAnnotationComposer get nodeId {
    final $$NodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.nodeId,
      referencedTable: $db.nodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NodesTableAnnotationComposer(
            $db: $db,
            $table: $db.nodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> reviewLogsRefs<T extends Object>(
    Expression<T> Function($$ReviewLogsTableAnnotationComposer a) f,
  ) {
    final $$ReviewLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewLogs,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.reviewLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> anchorsRefs<T extends Object>(
    Expression<T> Function($$AnchorsTableAnnotationComposer a) f,
  ) {
    final $$AnchorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.anchors,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnchorsTableAnnotationComposer(
            $db: $db,
            $table: $db.anchors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> notesRefs<T extends Object>(
    Expression<T> Function($$NotesTableAnnotationComposer a) f,
  ) {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItemsTableTableManager
    extends
        RootTableManager<
          _$VergerDatabase,
          $ItemsTable,
          ItemRow,
          $$ItemsTableFilterComposer,
          $$ItemsTableOrderingComposer,
          $$ItemsTableAnnotationComposer,
          $$ItemsTableCreateCompanionBuilder,
          $$ItemsTableUpdateCompanionBuilder,
          (ItemRow, $$ItemsTableReferences),
          ItemRow,
          PrefetchHooks Function({
            bool nodeId,
            bool reviewLogsRefs,
            bool anchorsRefs,
            bool notesRefs,
          })
        > {
  $$ItemsTableTableManager(_$VergerDatabase db, $ItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nodeId = const Value.absent(),
                Value<ItemKind> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<ExerciseLevel?> level = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<bool> suspended = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<LearningPhase> phase = const Value.absent(),
                Value<int?> step = const Value.absent(),
                Value<double?> stability = const Value.absent(),
                Value<double?> difficulty = const Value.absent(),
                Value<DateTime?> due = const Value.absent(),
                Value<DateTime?> lastReview = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion(
                id: id,
                nodeId: nodeId,
                kind: kind,
                title: title,
                body: body,
                level: level,
                sortIndex: sortIndex,
                suspended: suspended,
                createdAt: createdAt,
                updatedAt: updatedAt,
                phase: phase,
                step: step,
                stability: stability,
                difficulty: difficulty,
                due: due,
                lastReview: lastReview,
                reps: reps,
                lapses: lapses,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nodeId,
                required ItemKind kind,
                required String title,
                Value<String?> body = const Value.absent(),
                Value<ExerciseLevel?> level = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<bool> suspended = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                required LearningPhase phase,
                Value<int?> step = const Value.absent(),
                Value<double?> stability = const Value.absent(),
                Value<double?> difficulty = const Value.absent(),
                Value<DateTime?> due = const Value.absent(),
                Value<DateTime?> lastReview = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion.insert(
                id: id,
                nodeId: nodeId,
                kind: kind,
                title: title,
                body: body,
                level: level,
                sortIndex: sortIndex,
                suspended: suspended,
                createdAt: createdAt,
                updatedAt: updatedAt,
                phase: phase,
                step: step,
                stability: stability,
                difficulty: difficulty,
                due: due,
                lastReview: lastReview,
                reps: reps,
                lapses: lapses,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ItemsTable, ItemRow>(table),
                  $$ItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                nodeId = false,
                reviewLogsRefs = false,
                anchorsRefs = false,
                notesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (reviewLogsRefs) db.reviewLogs,
                    if (anchorsRefs) db.anchors,
                    if (notesRefs) db.notes,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (nodeId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.nodeId,
                                    referencedTable: $$ItemsTableReferences
                                        ._nodeIdTable(db),
                                    referencedColumn: $$ItemsTableReferences
                                        ._nodeIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (reviewLogsRefs)
                        await $_getPrefetchedData<
                          ItemRow,
                          $ItemsTable,
                          ReviewLogRow
                        >(
                          currentTable: table,
                          referencedTable: $$ItemsTableReferences
                              ._reviewLogsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).reviewLogsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (anchorsRefs)
                        await $_getPrefetchedData<
                          ItemRow,
                          $ItemsTable,
                          AnchorRow
                        >(
                          currentTable: table,
                          referencedTable: $$ItemsTableReferences
                              ._anchorsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemsTableReferences(db, table, p0).anchorsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (notesRefs)
                        await $_getPrefetchedData<
                          ItemRow,
                          $ItemsTable,
                          NoteRow
                        >(
                          currentTable: table,
                          referencedTable: $$ItemsTableReferences
                              ._notesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemsTableReferences(db, table, p0).notesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$VergerDatabase,
      $ItemsTable,
      ItemRow,
      $$ItemsTableFilterComposer,
      $$ItemsTableOrderingComposer,
      $$ItemsTableAnnotationComposer,
      $$ItemsTableCreateCompanionBuilder,
      $$ItemsTableUpdateCompanionBuilder,
      (ItemRow, $$ItemsTableReferences),
      ItemRow,
      PrefetchHooks Function({
        bool nodeId,
        bool reviewLogsRefs,
        bool anchorsRefs,
        bool notesRefs,
      })
    >;
typedef $$ReviewLogsTableCreateCompanionBuilder =
    ReviewLogsCompanion Function({
      required String id,
      required String itemId,
      required DateTime reviewedAt,
      required Rating rating,
      Value<int?> durationMs,
      required String schedulerId,
      required String stateBefore,
      required String stateAfter,
      Value<String?> impliedBy,
      Value<int> rowid,
    });
typedef $$ReviewLogsTableUpdateCompanionBuilder =
    ReviewLogsCompanion Function({
      Value<String> id,
      Value<String> itemId,
      Value<DateTime> reviewedAt,
      Value<Rating> rating,
      Value<int?> durationMs,
      Value<String> schedulerId,
      Value<String> stateBefore,
      Value<String> stateAfter,
      Value<String?> impliedBy,
      Value<int> rowid,
    });

final class $$ReviewLogsTableReferences
    extends BaseReferences<_$VergerDatabase, $ReviewLogsTable, ReviewLogRow> {
  $$ReviewLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ItemsTable _itemIdTable(_$VergerDatabase db) =>
      db.items.createAlias('review_logs__item_id__items__id');

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReviewLogsTableFilterComposer
    extends Composer<_$VergerDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Rating, Rating, String> get rating =>
      $composableBuilder(
        column: $table.rating,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schedulerId => $composableBuilder(
    column: $table.schedulerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stateBefore => $composableBuilder(
    column: $table.stateBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stateAfter => $composableBuilder(
    column: $table.stateAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get impliedBy => $composableBuilder(
    column: $table.impliedBy,
    builder: (column) => ColumnFilters(column),
  );

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewLogsTableOrderingComposer
    extends Composer<_$VergerDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schedulerId => $composableBuilder(
    column: $table.schedulerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stateBefore => $composableBuilder(
    column: $table.stateBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stateAfter => $composableBuilder(
    column: $table.stateAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get impliedBy => $composableBuilder(
    column: $table.impliedBy,
    builder: (column) => ColumnOrderings(column),
  );

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableOrderingComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewLogsTableAnnotationComposer
    extends Composer<_$VergerDatabase, $ReviewLogsTable> {
  $$ReviewLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get reviewedAt => $composableBuilder(
    column: $table.reviewedAt,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Rating, String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get schedulerId => $composableBuilder(
    column: $table.schedulerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stateBefore => $composableBuilder(
    column: $table.stateBefore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stateAfter => $composableBuilder(
    column: $table.stateAfter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get impliedBy =>
      $composableBuilder(column: $table.impliedBy, builder: (column) => column);

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewLogsTableTableManager
    extends
        RootTableManager<
          _$VergerDatabase,
          $ReviewLogsTable,
          ReviewLogRow,
          $$ReviewLogsTableFilterComposer,
          $$ReviewLogsTableOrderingComposer,
          $$ReviewLogsTableAnnotationComposer,
          $$ReviewLogsTableCreateCompanionBuilder,
          $$ReviewLogsTableUpdateCompanionBuilder,
          (ReviewLogRow, $$ReviewLogsTableReferences),
          ReviewLogRow,
          PrefetchHooks Function({bool itemId})
        > {
  $$ReviewLogsTableTableManager(_$VergerDatabase db, $ReviewLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<DateTime> reviewedAt = const Value.absent(),
                Value<Rating> rating = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String> schedulerId = const Value.absent(),
                Value<String> stateBefore = const Value.absent(),
                Value<String> stateAfter = const Value.absent(),
                Value<String?> impliedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewLogsCompanion(
                id: id,
                itemId: itemId,
                reviewedAt: reviewedAt,
                rating: rating,
                durationMs: durationMs,
                schedulerId: schedulerId,
                stateBefore: stateBefore,
                stateAfter: stateAfter,
                impliedBy: impliedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String itemId,
                required DateTime reviewedAt,
                required Rating rating,
                Value<int?> durationMs = const Value.absent(),
                required String schedulerId,
                required String stateBefore,
                required String stateAfter,
                Value<String?> impliedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewLogsCompanion.insert(
                id: id,
                itemId: itemId,
                reviewedAt: reviewedAt,
                rating: rating,
                durationMs: durationMs,
                schedulerId: schedulerId,
                stateBefore: stateBefore,
                stateAfter: stateAfter,
                impliedBy: impliedBy,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReviewLogsTable, ReviewLogRow>(table),
                  $$ReviewLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable: $$ReviewLogsTableReferences
                                    ._itemIdTable(db),
                                referencedColumn: $$ReviewLogsTableReferences
                                    ._itemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReviewLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$VergerDatabase,
      $ReviewLogsTable,
      ReviewLogRow,
      $$ReviewLogsTableFilterComposer,
      $$ReviewLogsTableOrderingComposer,
      $$ReviewLogsTableAnnotationComposer,
      $$ReviewLogsTableCreateCompanionBuilder,
      $$ReviewLogsTableUpdateCompanionBuilder,
      (ReviewLogRow, $$ReviewLogsTableReferences),
      ReviewLogRow,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$VergerDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$VergerDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$VergerDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$VergerDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$VergerDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$VergerDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$VergerDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$VergerDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (
        SettingRow,
        BaseReferences<_$VergerDatabase, $SettingsTable, SettingRow>,
      ),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$DocumentsTableCreateCompanionBuilder =
    DocumentsCompanion Function({
      required String id,
      required String title,
      Value<ResourceKind> kind,
      Value<String?> url,
      required int pageCount,
      required String contentHash,
      required DateTime importedAt,
      Value<int> version,
      required Uint8List fingerprints,
      Value<String> newPages,
      Value<int> lastPage,
      Value<int> rowid,
    });
typedef $$DocumentsTableUpdateCompanionBuilder =
    DocumentsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<ResourceKind> kind,
      Value<String?> url,
      Value<int> pageCount,
      Value<String> contentHash,
      Value<DateTime> importedAt,
      Value<int> version,
      Value<Uint8List> fingerprints,
      Value<String> newPages,
      Value<int> lastPage,
      Value<int> rowid,
    });

final class $$DocumentsTableReferences
    extends BaseReferences<_$VergerDatabase, $DocumentsTable, DocumentRow> {
  $$DocumentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DocumentFilesTable, List<DocumentFileRow>>
  _documentFilesRefsTable(_$VergerDatabase db) => MultiTypedResultKey.fromTable(
    db.documentFiles,
    aliasName: 'documents__id__document_files__document_id',
  );

  $$DocumentFilesTableProcessedTableManager get documentFilesRefs {
    final manager = $$DocumentFilesTableTableManager(
      $_db,
      $_db.documentFiles,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_documentFilesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AnchorsTable, List<AnchorRow>> _anchorsRefsTable(
    _$VergerDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.anchors,
    aliasName: 'documents__id__anchors__document_id',
  );

  $$AnchorsTableProcessedTableManager get anchorsRefs {
    final manager = $$AnchorsTableTableManager(
      $_db,
      $_db.anchors,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_anchorsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NotesTable, List<NoteRow>> _notesRefsTable(
    _$VergerDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.notes,
    aliasName: 'documents__id__notes__document_id',
  );

  $$NotesTableProcessedTableManager get notesRefs {
    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_notesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ResourceLinksTable, List<ResourceLinkRow>>
  _resourceLinksRefsTable(_$VergerDatabase db) => MultiTypedResultKey.fromTable(
    db.resourceLinks,
    aliasName: 'documents__id__resource_links__document_id',
  );

  $$ResourceLinksTableProcessedTableManager get resourceLinksRefs {
    final manager = $$ResourceLinksTableTableManager(
      $_db,
      $_db.resourceLinks,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_resourceLinksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DocumentsTableFilterComposer
    extends Composer<_$VergerDatabase, $DocumentsTable> {
  $$DocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ResourceKind, ResourceKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get fingerprints => $composableBuilder(
    column: $table.fingerprints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get newPages => $composableBuilder(
    column: $table.newPages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPage => $composableBuilder(
    column: $table.lastPage,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> documentFilesRefs(
    Expression<bool> Function($$DocumentFilesTableFilterComposer f) f,
  ) {
    final $$DocumentFilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentFiles,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentFilesTableFilterComposer(
            $db: $db,
            $table: $db.documentFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> anchorsRefs(
    Expression<bool> Function($$AnchorsTableFilterComposer f) f,
  ) {
    final $$AnchorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.anchors,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnchorsTableFilterComposer(
            $db: $db,
            $table: $db.anchors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> notesRefs(
    Expression<bool> Function($$NotesTableFilterComposer f) f,
  ) {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> resourceLinksRefs(
    Expression<bool> Function($$ResourceLinksTableFilterComposer f) f,
  ) {
    final $$ResourceLinksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.resourceLinks,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ResourceLinksTableFilterComposer(
            $db: $db,
            $table: $db.resourceLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DocumentsTableOrderingComposer
    extends Composer<_$VergerDatabase, $DocumentsTable> {
  $$DocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get fingerprints => $composableBuilder(
    column: $table.fingerprints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get newPages => $composableBuilder(
    column: $table.newPages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPage => $composableBuilder(
    column: $table.lastPage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentsTableAnnotationComposer
    extends Composer<_$VergerDatabase, $DocumentsTable> {
  $$DocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ResourceKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<Uint8List> get fingerprints => $composableBuilder(
    column: $table.fingerprints,
    builder: (column) => column,
  );

  GeneratedColumn<String> get newPages =>
      $composableBuilder(column: $table.newPages, builder: (column) => column);

  GeneratedColumn<int> get lastPage =>
      $composableBuilder(column: $table.lastPage, builder: (column) => column);

  Expression<T> documentFilesRefs<T extends Object>(
    Expression<T> Function($$DocumentFilesTableAnnotationComposer a) f,
  ) {
    final $$DocumentFilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentFiles,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentFilesTableAnnotationComposer(
            $db: $db,
            $table: $db.documentFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> anchorsRefs<T extends Object>(
    Expression<T> Function($$AnchorsTableAnnotationComposer a) f,
  ) {
    final $$AnchorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.anchors,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnchorsTableAnnotationComposer(
            $db: $db,
            $table: $db.anchors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> notesRefs<T extends Object>(
    Expression<T> Function($$NotesTableAnnotationComposer a) f,
  ) {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> resourceLinksRefs<T extends Object>(
    Expression<T> Function($$ResourceLinksTableAnnotationComposer a) f,
  ) {
    final $$ResourceLinksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.resourceLinks,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ResourceLinksTableAnnotationComposer(
            $db: $db,
            $table: $db.resourceLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DocumentsTableTableManager
    extends
        RootTableManager<
          _$VergerDatabase,
          $DocumentsTable,
          DocumentRow,
          $$DocumentsTableFilterComposer,
          $$DocumentsTableOrderingComposer,
          $$DocumentsTableAnnotationComposer,
          $$DocumentsTableCreateCompanionBuilder,
          $$DocumentsTableUpdateCompanionBuilder,
          (DocumentRow, $$DocumentsTableReferences),
          DocumentRow,
          PrefetchHooks Function({
            bool documentFilesRefs,
            bool anchorsRefs,
            bool notesRefs,
            bool resourceLinksRefs,
          })
        > {
  $$DocumentsTableTableManager(_$VergerDatabase db, $DocumentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<ResourceKind> kind = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<Uint8List> fingerprints = const Value.absent(),
                Value<String> newPages = const Value.absent(),
                Value<int> lastPage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion(
                id: id,
                title: title,
                kind: kind,
                url: url,
                pageCount: pageCount,
                contentHash: contentHash,
                importedAt: importedAt,
                version: version,
                fingerprints: fingerprints,
                newPages: newPages,
                lastPage: lastPage,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<ResourceKind> kind = const Value.absent(),
                Value<String?> url = const Value.absent(),
                required int pageCount,
                required String contentHash,
                required DateTime importedAt,
                Value<int> version = const Value.absent(),
                required Uint8List fingerprints,
                Value<String> newPages = const Value.absent(),
                Value<int> lastPage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion.insert(
                id: id,
                title: title,
                kind: kind,
                url: url,
                pageCount: pageCount,
                contentHash: contentHash,
                importedAt: importedAt,
                version: version,
                fingerprints: fingerprints,
                newPages: newPages,
                lastPage: lastPage,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DocumentsTable, DocumentRow>(table),
                  $$DocumentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                documentFilesRefs = false,
                anchorsRefs = false,
                notesRefs = false,
                resourceLinksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (documentFilesRefs) db.documentFiles,
                    if (anchorsRefs) db.anchors,
                    if (notesRefs) db.notes,
                    if (resourceLinksRefs) db.resourceLinks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (documentFilesRefs)
                        await $_getPrefetchedData<
                          DocumentRow,
                          $DocumentsTable,
                          DocumentFileRow
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._documentFilesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).documentFilesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (anchorsRefs)
                        await $_getPrefetchedData<
                          DocumentRow,
                          $DocumentsTable,
                          AnchorRow
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._anchorsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).anchorsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (notesRefs)
                        await $_getPrefetchedData<
                          DocumentRow,
                          $DocumentsTable,
                          NoteRow
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._notesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).notesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (resourceLinksRefs)
                        await $_getPrefetchedData<
                          DocumentRow,
                          $DocumentsTable,
                          ResourceLinkRow
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._resourceLinksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).resourceLinksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$VergerDatabase,
      $DocumentsTable,
      DocumentRow,
      $$DocumentsTableFilterComposer,
      $$DocumentsTableOrderingComposer,
      $$DocumentsTableAnnotationComposer,
      $$DocumentsTableCreateCompanionBuilder,
      $$DocumentsTableUpdateCompanionBuilder,
      (DocumentRow, $$DocumentsTableReferences),
      DocumentRow,
      PrefetchHooks Function({
        bool documentFilesRefs,
        bool anchorsRefs,
        bool notesRefs,
        bool resourceLinksRefs,
      })
    >;
typedef $$DocumentFilesTableCreateCompanionBuilder =
    DocumentFilesCompanion Function({
      required String documentId,
      required Uint8List bytes,
      Value<int> rowid,
    });
typedef $$DocumentFilesTableUpdateCompanionBuilder =
    DocumentFilesCompanion Function({
      Value<String> documentId,
      Value<Uint8List> bytes,
      Value<int> rowid,
    });

final class $$DocumentFilesTableReferences
    extends
        BaseReferences<_$VergerDatabase, $DocumentFilesTable, DocumentFileRow> {
  $$DocumentFilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DocumentsTable _documentIdTable(_$VergerDatabase db) =>
      db.documents.createAlias('document_files__document_id__documents__id');

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DocumentFilesTableFilterComposer
    extends Composer<_$VergerDatabase, $DocumentFilesTable> {
  $$DocumentFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentFilesTableOrderingComposer
    extends Composer<_$VergerDatabase, $DocumentFilesTable> {
  $$DocumentFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentFilesTableAnnotationComposer
    extends Composer<_$VergerDatabase, $DocumentFilesTable> {
  $$DocumentFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentFilesTableTableManager
    extends
        RootTableManager<
          _$VergerDatabase,
          $DocumentFilesTable,
          DocumentFileRow,
          $$DocumentFilesTableFilterComposer,
          $$DocumentFilesTableOrderingComposer,
          $$DocumentFilesTableAnnotationComposer,
          $$DocumentFilesTableCreateCompanionBuilder,
          $$DocumentFilesTableUpdateCompanionBuilder,
          (DocumentFileRow, $$DocumentFilesTableReferences),
          DocumentFileRow,
          PrefetchHooks Function({bool documentId})
        > {
  $$DocumentFilesTableTableManager(
    _$VergerDatabase db,
    $DocumentFilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> documentId = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentFilesCompanion(
                documentId: documentId,
                bytes: bytes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String documentId,
                required Uint8List bytes,
                Value<int> rowid = const Value.absent(),
              }) => DocumentFilesCompanion.insert(
                documentId: documentId,
                bytes: bytes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DocumentFilesTable, DocumentFileRow>(table),
                  $$DocumentFilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({documentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (documentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.documentId,
                                referencedTable: $$DocumentFilesTableReferences
                                    ._documentIdTable(db),
                                referencedColumn: $$DocumentFilesTableReferences
                                    ._documentIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DocumentFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$VergerDatabase,
      $DocumentFilesTable,
      DocumentFileRow,
      $$DocumentFilesTableFilterComposer,
      $$DocumentFilesTableOrderingComposer,
      $$DocumentFilesTableAnnotationComposer,
      $$DocumentFilesTableCreateCompanionBuilder,
      $$DocumentFilesTableUpdateCompanionBuilder,
      (DocumentFileRow, $$DocumentFilesTableReferences),
      DocumentFileRow,
      PrefetchHooks Function({bool documentId})
    >;
typedef $$AnchorsTableCreateCompanionBuilder =
    AnchorsCompanion Function({
      required String id,
      required String itemId,
      required String documentId,
      required AnchorRole role,
      Value<int?> page,
      Value<int?> startMs,
      Value<int?> endMs,
      Value<double?> left,
      Value<double?> top,
      Value<double?> right,
      Value<double?> bottom,
      Value<String?> textSnippet,
      Value<Uint8List?> snapshot,
      Value<bool> needsReview,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$AnchorsTableUpdateCompanionBuilder =
    AnchorsCompanion Function({
      Value<String> id,
      Value<String> itemId,
      Value<String> documentId,
      Value<AnchorRole> role,
      Value<int?> page,
      Value<int?> startMs,
      Value<int?> endMs,
      Value<double?> left,
      Value<double?> top,
      Value<double?> right,
      Value<double?> bottom,
      Value<String?> textSnippet,
      Value<Uint8List?> snapshot,
      Value<bool> needsReview,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$AnchorsTableReferences
    extends BaseReferences<_$VergerDatabase, $AnchorsTable, AnchorRow> {
  $$AnchorsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ItemsTable _itemIdTable(_$VergerDatabase db) =>
      db.items.createAlias('anchors__item_id__items__id');

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DocumentsTable _documentIdTable(_$VergerDatabase db) =>
      db.documents.createAlias('anchors__document_id__documents__id');

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AnchorsTableFilterComposer
    extends Composer<_$VergerDatabase, $AnchorsTable> {
  $$AnchorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AnchorRole, AnchorRole, String> get role =>
      $composableBuilder(
        column: $table.role,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get left => $composableBuilder(
    column: $table.left,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get top => $composableBuilder(
    column: $table.top,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get right => $composableBuilder(
    column: $table.right,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bottom => $composableBuilder(
    column: $table.bottom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textSnippet => $composableBuilder(
    column: $table.textSnippet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get snapshot => $composableBuilder(
    column: $table.snapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsReview => $composableBuilder(
    column: $table.needsReview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnchorsTableOrderingComposer
    extends Composer<_$VergerDatabase, $AnchorsTable> {
  $$AnchorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get left => $composableBuilder(
    column: $table.left,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get top => $composableBuilder(
    column: $table.top,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get right => $composableBuilder(
    column: $table.right,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bottom => $composableBuilder(
    column: $table.bottom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textSnippet => $composableBuilder(
    column: $table.textSnippet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get snapshot => $composableBuilder(
    column: $table.snapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsReview => $composableBuilder(
    column: $table.needsReview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableOrderingComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnchorsTableAnnotationComposer
    extends Composer<_$VergerDatabase, $AnchorsTable> {
  $$AnchorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AnchorRole, String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<int> get page =>
      $composableBuilder(column: $table.page, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<double> get left =>
      $composableBuilder(column: $table.left, builder: (column) => column);

  GeneratedColumn<double> get top =>
      $composableBuilder(column: $table.top, builder: (column) => column);

  GeneratedColumn<double> get right =>
      $composableBuilder(column: $table.right, builder: (column) => column);

  GeneratedColumn<double> get bottom =>
      $composableBuilder(column: $table.bottom, builder: (column) => column);

  GeneratedColumn<String> get textSnippet => $composableBuilder(
    column: $table.textSnippet,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get snapshot =>
      $composableBuilder(column: $table.snapshot, builder: (column) => column);

  GeneratedColumn<bool> get needsReview => $composableBuilder(
    column: $table.needsReview,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnchorsTableTableManager
    extends
        RootTableManager<
          _$VergerDatabase,
          $AnchorsTable,
          AnchorRow,
          $$AnchorsTableFilterComposer,
          $$AnchorsTableOrderingComposer,
          $$AnchorsTableAnnotationComposer,
          $$AnchorsTableCreateCompanionBuilder,
          $$AnchorsTableUpdateCompanionBuilder,
          (AnchorRow, $$AnchorsTableReferences),
          AnchorRow,
          PrefetchHooks Function({bool itemId, bool documentId})
        > {
  $$AnchorsTableTableManager(_$VergerDatabase db, $AnchorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnchorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnchorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnchorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<AnchorRole> role = const Value.absent(),
                Value<int?> page = const Value.absent(),
                Value<int?> startMs = const Value.absent(),
                Value<int?> endMs = const Value.absent(),
                Value<double?> left = const Value.absent(),
                Value<double?> top = const Value.absent(),
                Value<double?> right = const Value.absent(),
                Value<double?> bottom = const Value.absent(),
                Value<String?> textSnippet = const Value.absent(),
                Value<Uint8List?> snapshot = const Value.absent(),
                Value<bool> needsReview = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnchorsCompanion(
                id: id,
                itemId: itemId,
                documentId: documentId,
                role: role,
                page: page,
                startMs: startMs,
                endMs: endMs,
                left: left,
                top: top,
                right: right,
                bottom: bottom,
                textSnippet: textSnippet,
                snapshot: snapshot,
                needsReview: needsReview,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String itemId,
                required String documentId,
                required AnchorRole role,
                Value<int?> page = const Value.absent(),
                Value<int?> startMs = const Value.absent(),
                Value<int?> endMs = const Value.absent(),
                Value<double?> left = const Value.absent(),
                Value<double?> top = const Value.absent(),
                Value<double?> right = const Value.absent(),
                Value<double?> bottom = const Value.absent(),
                Value<String?> textSnippet = const Value.absent(),
                Value<Uint8List?> snapshot = const Value.absent(),
                Value<bool> needsReview = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AnchorsCompanion.insert(
                id: id,
                itemId: itemId,
                documentId: documentId,
                role: role,
                page: page,
                startMs: startMs,
                endMs: endMs,
                left: left,
                top: top,
                right: right,
                bottom: bottom,
                textSnippet: textSnippet,
                snapshot: snapshot,
                needsReview: needsReview,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AnchorsTable, AnchorRow>(table),
                  $$AnchorsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false, documentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable: $$AnchorsTableReferences
                                    ._itemIdTable(db),
                                referencedColumn: $$AnchorsTableReferences
                                    ._itemIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (documentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.documentId,
                                referencedTable: $$AnchorsTableReferences
                                    ._documentIdTable(db),
                                referencedColumn: $$AnchorsTableReferences
                                    ._documentIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AnchorsTableProcessedTableManager =
    ProcessedTableManager<
      _$VergerDatabase,
      $AnchorsTable,
      AnchorRow,
      $$AnchorsTableFilterComposer,
      $$AnchorsTableOrderingComposer,
      $$AnchorsTableAnnotationComposer,
      $$AnchorsTableCreateCompanionBuilder,
      $$AnchorsTableUpdateCompanionBuilder,
      (AnchorRow, $$AnchorsTableReferences),
      AnchorRow,
      PrefetchHooks Function({bool itemId, bool documentId})
    >;
typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      required String id,
      required String body,
      Value<String?> documentId,
      Value<int?> page,
      Value<int?> startMs,
      Value<int?> endMs,
      Value<double?> left,
      Value<double?> top,
      Value<double?> right,
      Value<double?> bottom,
      Value<Uint8List?> snapshot,
      Value<String?> itemId,
      Value<String?> ink,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<String> id,
      Value<String> body,
      Value<String?> documentId,
      Value<int?> page,
      Value<int?> startMs,
      Value<int?> endMs,
      Value<double?> left,
      Value<double?> top,
      Value<double?> right,
      Value<double?> bottom,
      Value<Uint8List?> snapshot,
      Value<String?> itemId,
      Value<String?> ink,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$NotesTableReferences
    extends BaseReferences<_$VergerDatabase, $NotesTable, NoteRow> {
  $$NotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DocumentsTable _documentIdTable(_$VergerDatabase db) =>
      db.documents.createAlias('notes__document_id__documents__id');

  $$DocumentsTableProcessedTableManager? get documentId {
    final $_column = $_itemColumn<String>('document_id');
    if ($_column == null) return null;
    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ItemsTable _itemIdTable(_$VergerDatabase db) =>
      db.items.createAlias('notes__item_id__items__id');

  $$ItemsTableProcessedTableManager? get itemId {
    final $_column = $_itemColumn<String>('item_id');
    if ($_column == null) return null;
    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NotesTableFilterComposer
    extends Composer<_$VergerDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get left => $composableBuilder(
    column: $table.left,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get top => $composableBuilder(
    column: $table.top,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get right => $composableBuilder(
    column: $table.right,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bottom => $composableBuilder(
    column: $table.bottom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get snapshot => $composableBuilder(
    column: $table.snapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ink => $composableBuilder(
    column: $table.ink,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotesTableOrderingComposer
    extends Composer<_$VergerDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get left => $composableBuilder(
    column: $table.left,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get top => $composableBuilder(
    column: $table.top,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get right => $composableBuilder(
    column: $table.right,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bottom => $composableBuilder(
    column: $table.bottom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get snapshot => $composableBuilder(
    column: $table.snapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ink => $composableBuilder(
    column: $table.ink,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableOrderingComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotesTableAnnotationComposer
    extends Composer<_$VergerDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get page =>
      $composableBuilder(column: $table.page, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<double> get left =>
      $composableBuilder(column: $table.left, builder: (column) => column);

  GeneratedColumn<double> get top =>
      $composableBuilder(column: $table.top, builder: (column) => column);

  GeneratedColumn<double> get right =>
      $composableBuilder(column: $table.right, builder: (column) => column);

  GeneratedColumn<double> get bottom =>
      $composableBuilder(column: $table.bottom, builder: (column) => column);

  GeneratedColumn<Uint8List> get snapshot =>
      $composableBuilder(column: $table.snapshot, builder: (column) => column);

  GeneratedColumn<String> get ink =>
      $composableBuilder(column: $table.ink, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$VergerDatabase,
          $NotesTable,
          NoteRow,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (NoteRow, $$NotesTableReferences),
          NoteRow,
          PrefetchHooks Function({bool documentId, bool itemId})
        > {
  $$NotesTableTableManager(_$VergerDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> documentId = const Value.absent(),
                Value<int?> page = const Value.absent(),
                Value<int?> startMs = const Value.absent(),
                Value<int?> endMs = const Value.absent(),
                Value<double?> left = const Value.absent(),
                Value<double?> top = const Value.absent(),
                Value<double?> right = const Value.absent(),
                Value<double?> bottom = const Value.absent(),
                Value<Uint8List?> snapshot = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String?> ink = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                body: body,
                documentId: documentId,
                page: page,
                startMs: startMs,
                endMs: endMs,
                left: left,
                top: top,
                right: right,
                bottom: bottom,
                snapshot: snapshot,
                itemId: itemId,
                ink: ink,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String body,
                Value<String?> documentId = const Value.absent(),
                Value<int?> page = const Value.absent(),
                Value<int?> startMs = const Value.absent(),
                Value<int?> endMs = const Value.absent(),
                Value<double?> left = const Value.absent(),
                Value<double?> top = const Value.absent(),
                Value<double?> right = const Value.absent(),
                Value<double?> bottom = const Value.absent(),
                Value<Uint8List?> snapshot = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String?> ink = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                body: body,
                documentId: documentId,
                page: page,
                startMs: startMs,
                endMs: endMs,
                left: left,
                top: top,
                right: right,
                bottom: bottom,
                snapshot: snapshot,
                itemId: itemId,
                ink: ink,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotesTable, NoteRow>(table),
                  $$NotesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({documentId = false, itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (documentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.documentId,
                                referencedTable: $$NotesTableReferences
                                    ._documentIdTable(db),
                                referencedColumn: $$NotesTableReferences
                                    ._documentIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable: $$NotesTableReferences
                                    ._itemIdTable(db),
                                referencedColumn: $$NotesTableReferences
                                    ._itemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$VergerDatabase,
      $NotesTable,
      NoteRow,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (NoteRow, $$NotesTableReferences),
      NoteRow,
      PrefetchHooks Function({bool documentId, bool itemId})
    >;
typedef $$ResourceLinksTableCreateCompanionBuilder =
    ResourceLinksCompanion Function({
      required String documentId,
      required String nodeId,
      Value<int> rowid,
    });
typedef $$ResourceLinksTableUpdateCompanionBuilder =
    ResourceLinksCompanion Function({
      Value<String> documentId,
      Value<String> nodeId,
      Value<int> rowid,
    });

final class $$ResourceLinksTableReferences
    extends
        BaseReferences<_$VergerDatabase, $ResourceLinksTable, ResourceLinkRow> {
  $$ResourceLinksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DocumentsTable _documentIdTable(_$VergerDatabase db) =>
      db.documents.createAlias('resource_links__document_id__documents__id');

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $NodesTable _nodeIdTable(_$VergerDatabase db) =>
      db.nodes.createAlias('resource_links__node_id__nodes__id');

  $$NodesTableProcessedTableManager get nodeId {
    final $_column = $_itemColumn<String>('node_id')!;

    final manager = $$NodesTableTableManager(
      $_db,
      $_db.nodes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_nodeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ResourceLinksTableFilterComposer
    extends Composer<_$VergerDatabase, $ResourceLinksTable> {
  $$ResourceLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NodesTableFilterComposer get nodeId {
    final $$NodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.nodeId,
      referencedTable: $db.nodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NodesTableFilterComposer(
            $db: $db,
            $table: $db.nodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ResourceLinksTableOrderingComposer
    extends Composer<_$VergerDatabase, $ResourceLinksTable> {
  $$ResourceLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NodesTableOrderingComposer get nodeId {
    final $$NodesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.nodeId,
      referencedTable: $db.nodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NodesTableOrderingComposer(
            $db: $db,
            $table: $db.nodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ResourceLinksTableAnnotationComposer
    extends Composer<_$VergerDatabase, $ResourceLinksTable> {
  $$ResourceLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$NodesTableAnnotationComposer get nodeId {
    final $$NodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.nodeId,
      referencedTable: $db.nodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NodesTableAnnotationComposer(
            $db: $db,
            $table: $db.nodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ResourceLinksTableTableManager
    extends
        RootTableManager<
          _$VergerDatabase,
          $ResourceLinksTable,
          ResourceLinkRow,
          $$ResourceLinksTableFilterComposer,
          $$ResourceLinksTableOrderingComposer,
          $$ResourceLinksTableAnnotationComposer,
          $$ResourceLinksTableCreateCompanionBuilder,
          $$ResourceLinksTableUpdateCompanionBuilder,
          (ResourceLinkRow, $$ResourceLinksTableReferences),
          ResourceLinkRow,
          PrefetchHooks Function({bool documentId, bool nodeId})
        > {
  $$ResourceLinksTableTableManager(
    _$VergerDatabase db,
    $ResourceLinksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResourceLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResourceLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResourceLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> documentId = const Value.absent(),
                Value<String> nodeId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ResourceLinksCompanion(
                documentId: documentId,
                nodeId: nodeId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String documentId,
                required String nodeId,
                Value<int> rowid = const Value.absent(),
              }) => ResourceLinksCompanion.insert(
                documentId: documentId,
                nodeId: nodeId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ResourceLinksTable, ResourceLinkRow>(table),
                  $$ResourceLinksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({documentId = false, nodeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (documentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.documentId,
                                referencedTable: $$ResourceLinksTableReferences
                                    ._documentIdTable(db),
                                referencedColumn: $$ResourceLinksTableReferences
                                    ._documentIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (nodeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.nodeId,
                                referencedTable: $$ResourceLinksTableReferences
                                    ._nodeIdTable(db),
                                referencedColumn: $$ResourceLinksTableReferences
                                    ._nodeIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ResourceLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$VergerDatabase,
      $ResourceLinksTable,
      ResourceLinkRow,
      $$ResourceLinksTableFilterComposer,
      $$ResourceLinksTableOrderingComposer,
      $$ResourceLinksTableAnnotationComposer,
      $$ResourceLinksTableCreateCompanionBuilder,
      $$ResourceLinksTableUpdateCompanionBuilder,
      (ResourceLinkRow, $$ResourceLinksTableReferences),
      ResourceLinkRow,
      PrefetchHooks Function({bool documentId, bool nodeId})
    >;
typedef $$PrerequisitesTableCreateCompanionBuilder =
    PrerequisitesCompanion Function({
      required String itemId,
      required String requiresId,
      Value<int> rowid,
    });
typedef $$PrerequisitesTableUpdateCompanionBuilder =
    PrerequisitesCompanion Function({
      Value<String> itemId,
      Value<String> requiresId,
      Value<int> rowid,
    });

final class $$PrerequisitesTableReferences
    extends
        BaseReferences<_$VergerDatabase, $PrerequisitesTable, PrerequisiteRow> {
  $$PrerequisitesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ItemsTable _itemIdTable(_$VergerDatabase db) =>
      db.items.createAlias('prerequisites__item_id__items__id');

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ItemsTable _requiresIdTable(_$VergerDatabase db) =>
      db.items.createAlias('prerequisites__requires_id__items__id');

  $$ItemsTableProcessedTableManager get requiresId {
    final $_column = $_itemColumn<String>('requires_id')!;

    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_requiresIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PrerequisitesTableFilterComposer
    extends Composer<_$VergerDatabase, $PrerequisitesTable> {
  $$PrerequisitesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ItemsTableFilterComposer get requiresId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.requiresId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrerequisitesTableOrderingComposer
    extends Composer<_$VergerDatabase, $PrerequisitesTable> {
  $$PrerequisitesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableOrderingComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ItemsTableOrderingComposer get requiresId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.requiresId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableOrderingComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrerequisitesTableAnnotationComposer
    extends Composer<_$VergerDatabase, $PrerequisitesTable> {
  $$PrerequisitesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ItemsTableAnnotationComposer get requiresId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.requiresId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrerequisitesTableTableManager
    extends
        RootTableManager<
          _$VergerDatabase,
          $PrerequisitesTable,
          PrerequisiteRow,
          $$PrerequisitesTableFilterComposer,
          $$PrerequisitesTableOrderingComposer,
          $$PrerequisitesTableAnnotationComposer,
          $$PrerequisitesTableCreateCompanionBuilder,
          $$PrerequisitesTableUpdateCompanionBuilder,
          (PrerequisiteRow, $$PrerequisitesTableReferences),
          PrerequisiteRow,
          PrefetchHooks Function({bool itemId, bool requiresId})
        > {
  $$PrerequisitesTableTableManager(
    _$VergerDatabase db,
    $PrerequisitesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrerequisitesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrerequisitesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrerequisitesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<String> requiresId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrerequisitesCompanion(
                itemId: itemId,
                requiresId: requiresId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                required String requiresId,
                Value<int> rowid = const Value.absent(),
              }) => PrerequisitesCompanion.insert(
                itemId: itemId,
                requiresId: requiresId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PrerequisitesTable, PrerequisiteRow>(table),
                  $$PrerequisitesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false, requiresId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable: $$PrerequisitesTableReferences
                                    ._itemIdTable(db),
                                referencedColumn: $$PrerequisitesTableReferences
                                    ._itemIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (requiresId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.requiresId,
                                referencedTable: $$PrerequisitesTableReferences
                                    ._requiresIdTable(db),
                                referencedColumn: $$PrerequisitesTableReferences
                                    ._requiresIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PrerequisitesTableProcessedTableManager =
    ProcessedTableManager<
      _$VergerDatabase,
      $PrerequisitesTable,
      PrerequisiteRow,
      $$PrerequisitesTableFilterComposer,
      $$PrerequisitesTableOrderingComposer,
      $$PrerequisitesTableAnnotationComposer,
      $$PrerequisitesTableCreateCompanionBuilder,
      $$PrerequisitesTableUpdateCompanionBuilder,
      (PrerequisiteRow, $$PrerequisitesTableReferences),
      PrerequisiteRow,
      PrefetchHooks Function({bool itemId, bool requiresId})
    >;

class $VergerDatabaseManager {
  final _$VergerDatabase _db;
  $VergerDatabaseManager(this._db);
  $$NodesTableTableManager get nodes =>
      $$NodesTableTableManager(_db, _db.nodes);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db, _db.items);
  $$ReviewLogsTableTableManager get reviewLogs =>
      $$ReviewLogsTableTableManager(_db, _db.reviewLogs);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$DocumentsTableTableManager get documents =>
      $$DocumentsTableTableManager(_db, _db.documents);
  $$DocumentFilesTableTableManager get documentFiles =>
      $$DocumentFilesTableTableManager(_db, _db.documentFiles);
  $$AnchorsTableTableManager get anchors =>
      $$AnchorsTableTableManager(_db, _db.anchors);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$ResourceLinksTableTableManager get resourceLinks =>
      $$ResourceLinksTableTableManager(_db, _db.resourceLinks);
  $$PrerequisitesTableTableManager get prerequisites =>
      $$PrerequisitesTableTableManager(_db, _db.prerequisites);
}
