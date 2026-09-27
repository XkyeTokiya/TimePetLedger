// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $GoalsTable extends Goals with TableInfo<$GoalsTable, GoalRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<int> archivedAt = GeneratedColumn<int>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    status,
    createdAt,
    updatedAt,
    archivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
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
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoalRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived_at'],
      ),
    );
  }

  @override
  $GoalsTable createAlias(String alias) {
    return $GoalsTable(attachedDatabase, alias);
  }
}

class GoalRow extends DataClass implements Insertable<GoalRow> {
  final String id;
  final String name;
  final String status;
  final int createdAt;
  final int updatedAt;
  final int? archivedAt;
  const GoalRow({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<int>(archivedAt);
    }
    return map;
  }

  GoalsCompanion toCompanion(bool nullToAbsent) {
    return GoalsCompanion(
      id: Value(id),
      name: Value(name),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
    );
  }

  factory GoalRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      archivedAt: serializer.fromJson<int?>(json['archivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'archivedAt': serializer.toJson<int?>(archivedAt),
    };
  }

  GoalRow copyWith({
    String? id,
    String? name,
    String? status,
    int? createdAt,
    int? updatedAt,
    Value<int?> archivedAt = const Value.absent(),
  }) => GoalRow(
    id: id ?? this.id,
    name: name ?? this.name,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
  );
  GoalRow copyWithCompanion(GoalsCompanion data) {
    return GoalRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, status, createdAt, updatedAt, archivedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.archivedAt == this.archivedAt);
}

class GoalsCompanion extends UpdateCompanion<GoalRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> status;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> archivedAt;
  final Value<int> rowid;
  const GoalsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalsCompanion.insert({
    required String id,
    required String name,
    required String status,
    required int createdAt,
    required int updatedAt,
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<GoalRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? status,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? archivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? status,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? archivedAt,
    Value<int>? rowid,
  }) {
    return GoalsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<int>(archivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TimeBlocksTable extends TimeBlocks
    with TableInfo<$TimeBlocksTable, TimeBlockRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimeBlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<int> endedAt = GeneratedColumn<int>(
    'ended_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startPrecisionMeta = const VerificationMeta(
    'startPrecision',
  );
  @override
  late final GeneratedColumn<String> startPrecision = GeneratedColumn<String>(
    'start_precision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endPrecisionMeta = const VerificationMeta(
    'endPrecision',
  );
  @override
  late final GeneratedColumn<String> endPrecision = GeneratedColumn<String>(
    'end_precision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _knowledgeStateMeta = const VerificationMeta(
    'knowledgeState',
  );
  @override
  late final GeneratedColumn<String> knowledgeState = GeneratedColumn<String>(
    'knowledge_state',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goals (id) ON UPDATE RESTRICT ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    endedAt,
    startPrecision,
    endPrecision,
    knowledgeState,
    title,
    goalId,
    categoryId,
    note,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'time_blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimeBlockRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('start_precision')) {
      context.handle(
        _startPrecisionMeta,
        startPrecision.isAcceptableOrUnknown(
          data['start_precision']!,
          _startPrecisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startPrecisionMeta);
    }
    if (data.containsKey('end_precision')) {
      context.handle(
        _endPrecisionMeta,
        endPrecision.isAcceptableOrUnknown(
          data['end_precision']!,
          _endPrecisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_endPrecisionMeta);
    }
    if (data.containsKey('knowledge_state')) {
      context.handle(
        _knowledgeStateMeta,
        knowledgeState.isAcceptableOrUnknown(
          data['knowledge_state']!,
          _knowledgeStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_knowledgeStateMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
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
  TimeBlockRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimeBlockRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at'],
      )!,
      startPrecision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_precision'],
      )!,
      endPrecision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_precision'],
      )!,
      knowledgeState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}knowledge_state'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TimeBlocksTable createAlias(String alias) {
    return $TimeBlocksTable(attachedDatabase, alias);
  }
}

class TimeBlockRow extends DataClass implements Insertable<TimeBlockRow> {
  final String id;
  final int startedAt;
  final int endedAt;
  final String startPrecision;
  final String endPrecision;
  final String knowledgeState;
  final String? title;
  final String? goalId;
  final String? categoryId;
  final String? note;
  final int createdAt;
  final int updatedAt;
  const TimeBlockRow({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.startPrecision,
    required this.endPrecision,
    required this.knowledgeState,
    this.title,
    this.goalId,
    this.categoryId,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at'] = Variable<int>(startedAt);
    map['ended_at'] = Variable<int>(endedAt);
    map['start_precision'] = Variable<String>(startPrecision);
    map['end_precision'] = Variable<String>(endPrecision);
    map['knowledge_state'] = Variable<String>(knowledgeState);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || goalId != null) {
      map['goal_id'] = Variable<String>(goalId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TimeBlocksCompanion toCompanion(bool nullToAbsent) {
    return TimeBlocksCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      startPrecision: Value(startPrecision),
      endPrecision: Value(endPrecision),
      knowledgeState: Value(knowledgeState),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      goalId: goalId == null && nullToAbsent
          ? const Value.absent()
          : Value(goalId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TimeBlockRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimeBlockRow(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      endedAt: serializer.fromJson<int>(json['endedAt']),
      startPrecision: serializer.fromJson<String>(json['startPrecision']),
      endPrecision: serializer.fromJson<String>(json['endPrecision']),
      knowledgeState: serializer.fromJson<String>(json['knowledgeState']),
      title: serializer.fromJson<String?>(json['title']),
      goalId: serializer.fromJson<String?>(json['goalId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAt': serializer.toJson<int>(startedAt),
      'endedAt': serializer.toJson<int>(endedAt),
      'startPrecision': serializer.toJson<String>(startPrecision),
      'endPrecision': serializer.toJson<String>(endPrecision),
      'knowledgeState': serializer.toJson<String>(knowledgeState),
      'title': serializer.toJson<String?>(title),
      'goalId': serializer.toJson<String?>(goalId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TimeBlockRow copyWith({
    String? id,
    int? startedAt,
    int? endedAt,
    String? startPrecision,
    String? endPrecision,
    String? knowledgeState,
    Value<String?> title = const Value.absent(),
    Value<String?> goalId = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => TimeBlockRow(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    startPrecision: startPrecision ?? this.startPrecision,
    endPrecision: endPrecision ?? this.endPrecision,
    knowledgeState: knowledgeState ?? this.knowledgeState,
    title: title.present ? title.value : this.title,
    goalId: goalId.present ? goalId.value : this.goalId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TimeBlockRow copyWithCompanion(TimeBlocksCompanion data) {
    return TimeBlockRow(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      startPrecision: data.startPrecision.present
          ? data.startPrecision.value
          : this.startPrecision,
      endPrecision: data.endPrecision.present
          ? data.endPrecision.value
          : this.endPrecision,
      knowledgeState: data.knowledgeState.present
          ? data.knowledgeState.value
          : this.knowledgeState,
      title: data.title.present ? data.title.value : this.title,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimeBlockRow(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('startPrecision: $startPrecision, ')
          ..write('endPrecision: $endPrecision, ')
          ..write('knowledgeState: $knowledgeState, ')
          ..write('title: $title, ')
          ..write('goalId: $goalId, ')
          ..write('categoryId: $categoryId, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    endedAt,
    startPrecision,
    endPrecision,
    knowledgeState,
    title,
    goalId,
    categoryId,
    note,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimeBlockRow &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.startPrecision == this.startPrecision &&
          other.endPrecision == this.endPrecision &&
          other.knowledgeState == this.knowledgeState &&
          other.title == this.title &&
          other.goalId == this.goalId &&
          other.categoryId == this.categoryId &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TimeBlocksCompanion extends UpdateCompanion<TimeBlockRow> {
  final Value<String> id;
  final Value<int> startedAt;
  final Value<int> endedAt;
  final Value<String> startPrecision;
  final Value<String> endPrecision;
  final Value<String> knowledgeState;
  final Value<String?> title;
  final Value<String?> goalId;
  final Value<String?> categoryId;
  final Value<String?> note;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TimeBlocksCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.startPrecision = const Value.absent(),
    this.endPrecision = const Value.absent(),
    this.knowledgeState = const Value.absent(),
    this.title = const Value.absent(),
    this.goalId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TimeBlocksCompanion.insert({
    required String id,
    required int startedAt,
    required int endedAt,
    required String startPrecision,
    required String endPrecision,
    required String knowledgeState,
    this.title = const Value.absent(),
    this.goalId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.note = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt),
       endedAt = Value(endedAt),
       startPrecision = Value(startPrecision),
       endPrecision = Value(endPrecision),
       knowledgeState = Value(knowledgeState),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TimeBlockRow> custom({
    Expression<String>? id,
    Expression<int>? startedAt,
    Expression<int>? endedAt,
    Expression<String>? startPrecision,
    Expression<String>? endPrecision,
    Expression<String>? knowledgeState,
    Expression<String>? title,
    Expression<String>? goalId,
    Expression<String>? categoryId,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (startPrecision != null) 'start_precision': startPrecision,
      if (endPrecision != null) 'end_precision': endPrecision,
      if (knowledgeState != null) 'knowledge_state': knowledgeState,
      if (title != null) 'title': title,
      if (goalId != null) 'goal_id': goalId,
      if (categoryId != null) 'category_id': categoryId,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TimeBlocksCompanion copyWith({
    Value<String>? id,
    Value<int>? startedAt,
    Value<int>? endedAt,
    Value<String>? startPrecision,
    Value<String>? endPrecision,
    Value<String>? knowledgeState,
    Value<String?>? title,
    Value<String?>? goalId,
    Value<String?>? categoryId,
    Value<String?>? note,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TimeBlocksCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      startPrecision: startPrecision ?? this.startPrecision,
      endPrecision: endPrecision ?? this.endPrecision,
      knowledgeState: knowledgeState ?? this.knowledgeState,
      title: title ?? this.title,
      goalId: goalId ?? this.goalId,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
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
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<int>(endedAt.value);
    }
    if (startPrecision.present) {
      map['start_precision'] = Variable<String>(startPrecision.value);
    }
    if (endPrecision.present) {
      map['end_precision'] = Variable<String>(endPrecision.value);
    }
    if (knowledgeState.present) {
      map['knowledge_state'] = Variable<String>(knowledgeState.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimeBlocksCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('startPrecision: $startPrecision, ')
          ..write('endPrecision: $endPrecision, ')
          ..write('knowledgeState: $knowledgeState, ')
          ..write('title: $title, ')
          ..write('goalId: $goalId, ')
          ..write('categoryId: $categoryId, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RhythmAnnotationsTable extends RhythmAnnotations
    with TableInfo<$RhythmAnnotationsTable, RhythmAnnotationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RhythmAnnotationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeBlockIdMeta = const VerificationMeta(
    'timeBlockId',
  );
  @override
  late final GeneratedColumn<String> timeBlockId = GeneratedColumn<String>(
    'time_block_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES time_blocks (id) ON UPDATE RESTRICT ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stuckReasonCodeMeta = const VerificationMeta(
    'stuckReasonCode',
  );
  @override
  late final GeneratedColumn<String> stuckReasonCode = GeneratedColumn<String>(
    'stuck_reason_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stuckReasonTextMeta = const VerificationMeta(
    'stuckReasonText',
  );
  @override
  late final GeneratedColumn<String> stuckReasonText = GeneratedColumn<String>(
    'stuck_reason_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recoveryMethodMeta = const VerificationMeta(
    'recoveryMethod',
  );
  @override
  late final GeneratedColumn<String> recoveryMethod = GeneratedColumn<String>(
    'recovery_method',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recoveryQualityMeta = const VerificationMeta(
    'recoveryQuality',
  );
  @override
  late final GeneratedColumn<String> recoveryQuality = GeneratedColumn<String>(
    'recovery_quality',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _continuationHintMeta = const VerificationMeta(
    'continuationHint',
  );
  @override
  late final GeneratedColumn<String> continuationHint = GeneratedColumn<String>(
    'continuation_hint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timeBlockId,
    state,
    stuckReasonCode,
    stuckReasonText,
    recoveryMethod,
    recoveryQuality,
    continuationHint,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rhythm_annotations';
  @override
  VerificationContext validateIntegrity(
    Insertable<RhythmAnnotationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('time_block_id')) {
      context.handle(
        _timeBlockIdMeta,
        timeBlockId.isAcceptableOrUnknown(
          data['time_block_id']!,
          _timeBlockIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timeBlockIdMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('stuck_reason_code')) {
      context.handle(
        _stuckReasonCodeMeta,
        stuckReasonCode.isAcceptableOrUnknown(
          data['stuck_reason_code']!,
          _stuckReasonCodeMeta,
        ),
      );
    }
    if (data.containsKey('stuck_reason_text')) {
      context.handle(
        _stuckReasonTextMeta,
        stuckReasonText.isAcceptableOrUnknown(
          data['stuck_reason_text']!,
          _stuckReasonTextMeta,
        ),
      );
    }
    if (data.containsKey('recovery_method')) {
      context.handle(
        _recoveryMethodMeta,
        recoveryMethod.isAcceptableOrUnknown(
          data['recovery_method']!,
          _recoveryMethodMeta,
        ),
      );
    }
    if (data.containsKey('recovery_quality')) {
      context.handle(
        _recoveryQualityMeta,
        recoveryQuality.isAcceptableOrUnknown(
          data['recovery_quality']!,
          _recoveryQualityMeta,
        ),
      );
    }
    if (data.containsKey('continuation_hint')) {
      context.handle(
        _continuationHintMeta,
        continuationHint.isAcceptableOrUnknown(
          data['continuation_hint']!,
          _continuationHintMeta,
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
  RhythmAnnotationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RhythmAnnotationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      timeBlockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_block_id'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      stuckReasonCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stuck_reason_code'],
      ),
      stuckReasonText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stuck_reason_text'],
      ),
      recoveryMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recovery_method'],
      ),
      recoveryQuality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recovery_quality'],
      ),
      continuationHint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}continuation_hint'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RhythmAnnotationsTable createAlias(String alias) {
    return $RhythmAnnotationsTable(attachedDatabase, alias);
  }
}

class RhythmAnnotationRow extends DataClass
    implements Insertable<RhythmAnnotationRow> {
  final String id;
  final String timeBlockId;
  final String state;
  final String? stuckReasonCode;
  final String? stuckReasonText;
  final String? recoveryMethod;
  final String? recoveryQuality;
  final String? continuationHint;
  final int createdAt;
  final int updatedAt;
  const RhythmAnnotationRow({
    required this.id,
    required this.timeBlockId,
    required this.state,
    this.stuckReasonCode,
    this.stuckReasonText,
    this.recoveryMethod,
    this.recoveryQuality,
    this.continuationHint,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['time_block_id'] = Variable<String>(timeBlockId);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || stuckReasonCode != null) {
      map['stuck_reason_code'] = Variable<String>(stuckReasonCode);
    }
    if (!nullToAbsent || stuckReasonText != null) {
      map['stuck_reason_text'] = Variable<String>(stuckReasonText);
    }
    if (!nullToAbsent || recoveryMethod != null) {
      map['recovery_method'] = Variable<String>(recoveryMethod);
    }
    if (!nullToAbsent || recoveryQuality != null) {
      map['recovery_quality'] = Variable<String>(recoveryQuality);
    }
    if (!nullToAbsent || continuationHint != null) {
      map['continuation_hint'] = Variable<String>(continuationHint);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  RhythmAnnotationsCompanion toCompanion(bool nullToAbsent) {
    return RhythmAnnotationsCompanion(
      id: Value(id),
      timeBlockId: Value(timeBlockId),
      state: Value(state),
      stuckReasonCode: stuckReasonCode == null && nullToAbsent
          ? const Value.absent()
          : Value(stuckReasonCode),
      stuckReasonText: stuckReasonText == null && nullToAbsent
          ? const Value.absent()
          : Value(stuckReasonText),
      recoveryMethod: recoveryMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(recoveryMethod),
      recoveryQuality: recoveryQuality == null && nullToAbsent
          ? const Value.absent()
          : Value(recoveryQuality),
      continuationHint: continuationHint == null && nullToAbsent
          ? const Value.absent()
          : Value(continuationHint),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RhythmAnnotationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RhythmAnnotationRow(
      id: serializer.fromJson<String>(json['id']),
      timeBlockId: serializer.fromJson<String>(json['timeBlockId']),
      state: serializer.fromJson<String>(json['state']),
      stuckReasonCode: serializer.fromJson<String?>(json['stuckReasonCode']),
      stuckReasonText: serializer.fromJson<String?>(json['stuckReasonText']),
      recoveryMethod: serializer.fromJson<String?>(json['recoveryMethod']),
      recoveryQuality: serializer.fromJson<String?>(json['recoveryQuality']),
      continuationHint: serializer.fromJson<String?>(json['continuationHint']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'timeBlockId': serializer.toJson<String>(timeBlockId),
      'state': serializer.toJson<String>(state),
      'stuckReasonCode': serializer.toJson<String?>(stuckReasonCode),
      'stuckReasonText': serializer.toJson<String?>(stuckReasonText),
      'recoveryMethod': serializer.toJson<String?>(recoveryMethod),
      'recoveryQuality': serializer.toJson<String?>(recoveryQuality),
      'continuationHint': serializer.toJson<String?>(continuationHint),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  RhythmAnnotationRow copyWith({
    String? id,
    String? timeBlockId,
    String? state,
    Value<String?> stuckReasonCode = const Value.absent(),
    Value<String?> stuckReasonText = const Value.absent(),
    Value<String?> recoveryMethod = const Value.absent(),
    Value<String?> recoveryQuality = const Value.absent(),
    Value<String?> continuationHint = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => RhythmAnnotationRow(
    id: id ?? this.id,
    timeBlockId: timeBlockId ?? this.timeBlockId,
    state: state ?? this.state,
    stuckReasonCode: stuckReasonCode.present
        ? stuckReasonCode.value
        : this.stuckReasonCode,
    stuckReasonText: stuckReasonText.present
        ? stuckReasonText.value
        : this.stuckReasonText,
    recoveryMethod: recoveryMethod.present
        ? recoveryMethod.value
        : this.recoveryMethod,
    recoveryQuality: recoveryQuality.present
        ? recoveryQuality.value
        : this.recoveryQuality,
    continuationHint: continuationHint.present
        ? continuationHint.value
        : this.continuationHint,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RhythmAnnotationRow copyWithCompanion(RhythmAnnotationsCompanion data) {
    return RhythmAnnotationRow(
      id: data.id.present ? data.id.value : this.id,
      timeBlockId: data.timeBlockId.present
          ? data.timeBlockId.value
          : this.timeBlockId,
      state: data.state.present ? data.state.value : this.state,
      stuckReasonCode: data.stuckReasonCode.present
          ? data.stuckReasonCode.value
          : this.stuckReasonCode,
      stuckReasonText: data.stuckReasonText.present
          ? data.stuckReasonText.value
          : this.stuckReasonText,
      recoveryMethod: data.recoveryMethod.present
          ? data.recoveryMethod.value
          : this.recoveryMethod,
      recoveryQuality: data.recoveryQuality.present
          ? data.recoveryQuality.value
          : this.recoveryQuality,
      continuationHint: data.continuationHint.present
          ? data.continuationHint.value
          : this.continuationHint,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RhythmAnnotationRow(')
          ..write('id: $id, ')
          ..write('timeBlockId: $timeBlockId, ')
          ..write('state: $state, ')
          ..write('stuckReasonCode: $stuckReasonCode, ')
          ..write('stuckReasonText: $stuckReasonText, ')
          ..write('recoveryMethod: $recoveryMethod, ')
          ..write('recoveryQuality: $recoveryQuality, ')
          ..write('continuationHint: $continuationHint, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    timeBlockId,
    state,
    stuckReasonCode,
    stuckReasonText,
    recoveryMethod,
    recoveryQuality,
    continuationHint,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RhythmAnnotationRow &&
          other.id == this.id &&
          other.timeBlockId == this.timeBlockId &&
          other.state == this.state &&
          other.stuckReasonCode == this.stuckReasonCode &&
          other.stuckReasonText == this.stuckReasonText &&
          other.recoveryMethod == this.recoveryMethod &&
          other.recoveryQuality == this.recoveryQuality &&
          other.continuationHint == this.continuationHint &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RhythmAnnotationsCompanion extends UpdateCompanion<RhythmAnnotationRow> {
  final Value<String> id;
  final Value<String> timeBlockId;
  final Value<String> state;
  final Value<String?> stuckReasonCode;
  final Value<String?> stuckReasonText;
  final Value<String?> recoveryMethod;
  final Value<String?> recoveryQuality;
  final Value<String?> continuationHint;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const RhythmAnnotationsCompanion({
    this.id = const Value.absent(),
    this.timeBlockId = const Value.absent(),
    this.state = const Value.absent(),
    this.stuckReasonCode = const Value.absent(),
    this.stuckReasonText = const Value.absent(),
    this.recoveryMethod = const Value.absent(),
    this.recoveryQuality = const Value.absent(),
    this.continuationHint = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RhythmAnnotationsCompanion.insert({
    required String id,
    required String timeBlockId,
    required String state,
    this.stuckReasonCode = const Value.absent(),
    this.stuckReasonText = const Value.absent(),
    this.recoveryMethod = const Value.absent(),
    this.recoveryQuality = const Value.absent(),
    this.continuationHint = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       timeBlockId = Value(timeBlockId),
       state = Value(state),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<RhythmAnnotationRow> custom({
    Expression<String>? id,
    Expression<String>? timeBlockId,
    Expression<String>? state,
    Expression<String>? stuckReasonCode,
    Expression<String>? stuckReasonText,
    Expression<String>? recoveryMethod,
    Expression<String>? recoveryQuality,
    Expression<String>? continuationHint,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timeBlockId != null) 'time_block_id': timeBlockId,
      if (state != null) 'state': state,
      if (stuckReasonCode != null) 'stuck_reason_code': stuckReasonCode,
      if (stuckReasonText != null) 'stuck_reason_text': stuckReasonText,
      if (recoveryMethod != null) 'recovery_method': recoveryMethod,
      if (recoveryQuality != null) 'recovery_quality': recoveryQuality,
      if (continuationHint != null) 'continuation_hint': continuationHint,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RhythmAnnotationsCompanion copyWith({
    Value<String>? id,
    Value<String>? timeBlockId,
    Value<String>? state,
    Value<String?>? stuckReasonCode,
    Value<String?>? stuckReasonText,
    Value<String?>? recoveryMethod,
    Value<String?>? recoveryQuality,
    Value<String?>? continuationHint,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return RhythmAnnotationsCompanion(
      id: id ?? this.id,
      timeBlockId: timeBlockId ?? this.timeBlockId,
      state: state ?? this.state,
      stuckReasonCode: stuckReasonCode ?? this.stuckReasonCode,
      stuckReasonText: stuckReasonText ?? this.stuckReasonText,
      recoveryMethod: recoveryMethod ?? this.recoveryMethod,
      recoveryQuality: recoveryQuality ?? this.recoveryQuality,
      continuationHint: continuationHint ?? this.continuationHint,
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
    if (timeBlockId.present) {
      map['time_block_id'] = Variable<String>(timeBlockId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (stuckReasonCode.present) {
      map['stuck_reason_code'] = Variable<String>(stuckReasonCode.value);
    }
    if (stuckReasonText.present) {
      map['stuck_reason_text'] = Variable<String>(stuckReasonText.value);
    }
    if (recoveryMethod.present) {
      map['recovery_method'] = Variable<String>(recoveryMethod.value);
    }
    if (recoveryQuality.present) {
      map['recovery_quality'] = Variable<String>(recoveryQuality.value);
    }
    if (continuationHint.present) {
      map['continuation_hint'] = Variable<String>(continuationHint.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RhythmAnnotationsCompanion(')
          ..write('id: $id, ')
          ..write('timeBlockId: $timeBlockId, ')
          ..write('state: $state, ')
          ..write('stuckReasonCode: $stuckReasonCode, ')
          ..write('stuckReasonText: $stuckReasonText, ')
          ..write('recoveryMethod: $recoveryMethod, ')
          ..write('recoveryQuality: $recoveryQuality, ')
          ..write('continuationHint: $continuationHint, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SleepSessionsTable extends SleepSessions
    with TableInfo<$SleepSessionsTable, SleepSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SleepSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<int> endedAt = GeneratedColumn<int>(
    'ended_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startPrecisionMeta = const VerificationMeta(
    'startPrecision',
  );
  @override
  late final GeneratedColumn<String> startPrecision = GeneratedColumn<String>(
    'start_precision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endPrecisionMeta = const VerificationMeta(
    'endPrecision',
  );
  @override
  late final GeneratedColumn<String> endPrecision = GeneratedColumn<String>(
    'end_precision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sleepTypeMeta = const VerificationMeta(
    'sleepType',
  );
  @override
  late final GeneratedColumn<String> sleepType = GeneratedColumn<String>(
    'sleep_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    endedAt,
    startPrecision,
    endPrecision,
    sleepType,
    note,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sleep_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SleepSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('start_precision')) {
      context.handle(
        _startPrecisionMeta,
        startPrecision.isAcceptableOrUnknown(
          data['start_precision']!,
          _startPrecisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startPrecisionMeta);
    }
    if (data.containsKey('end_precision')) {
      context.handle(
        _endPrecisionMeta,
        endPrecision.isAcceptableOrUnknown(
          data['end_precision']!,
          _endPrecisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_endPrecisionMeta);
    }
    if (data.containsKey('sleep_type')) {
      context.handle(
        _sleepTypeMeta,
        sleepType.isAcceptableOrUnknown(data['sleep_type']!, _sleepTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sleepTypeMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
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
  SleepSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SleepSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at'],
      )!,
      startPrecision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_precision'],
      )!,
      endPrecision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_precision'],
      )!,
      sleepType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sleep_type'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SleepSessionsTable createAlias(String alias) {
    return $SleepSessionsTable(attachedDatabase, alias);
  }
}

class SleepSessionRow extends DataClass implements Insertable<SleepSessionRow> {
  final String id;
  final int startedAt;
  final int endedAt;
  final String startPrecision;
  final String endPrecision;
  final String sleepType;
  final String? note;
  final int createdAt;
  final int updatedAt;
  const SleepSessionRow({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.startPrecision,
    required this.endPrecision,
    required this.sleepType,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at'] = Variable<int>(startedAt);
    map['ended_at'] = Variable<int>(endedAt);
    map['start_precision'] = Variable<String>(startPrecision);
    map['end_precision'] = Variable<String>(endPrecision);
    map['sleep_type'] = Variable<String>(sleepType);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SleepSessionsCompanion toCompanion(bool nullToAbsent) {
    return SleepSessionsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      startPrecision: Value(startPrecision),
      endPrecision: Value(endPrecision),
      sleepType: Value(sleepType),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SleepSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SleepSessionRow(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      endedAt: serializer.fromJson<int>(json['endedAt']),
      startPrecision: serializer.fromJson<String>(json['startPrecision']),
      endPrecision: serializer.fromJson<String>(json['endPrecision']),
      sleepType: serializer.fromJson<String>(json['sleepType']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAt': serializer.toJson<int>(startedAt),
      'endedAt': serializer.toJson<int>(endedAt),
      'startPrecision': serializer.toJson<String>(startPrecision),
      'endPrecision': serializer.toJson<String>(endPrecision),
      'sleepType': serializer.toJson<String>(sleepType),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SleepSessionRow copyWith({
    String? id,
    int? startedAt,
    int? endedAt,
    String? startPrecision,
    String? endPrecision,
    String? sleepType,
    Value<String?> note = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => SleepSessionRow(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    startPrecision: startPrecision ?? this.startPrecision,
    endPrecision: endPrecision ?? this.endPrecision,
    sleepType: sleepType ?? this.sleepType,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SleepSessionRow copyWithCompanion(SleepSessionsCompanion data) {
    return SleepSessionRow(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      startPrecision: data.startPrecision.present
          ? data.startPrecision.value
          : this.startPrecision,
      endPrecision: data.endPrecision.present
          ? data.endPrecision.value
          : this.endPrecision,
      sleepType: data.sleepType.present ? data.sleepType.value : this.sleepType,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SleepSessionRow(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('startPrecision: $startPrecision, ')
          ..write('endPrecision: $endPrecision, ')
          ..write('sleepType: $sleepType, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    endedAt,
    startPrecision,
    endPrecision,
    sleepType,
    note,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SleepSessionRow &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.startPrecision == this.startPrecision &&
          other.endPrecision == this.endPrecision &&
          other.sleepType == this.sleepType &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SleepSessionsCompanion extends UpdateCompanion<SleepSessionRow> {
  final Value<String> id;
  final Value<int> startedAt;
  final Value<int> endedAt;
  final Value<String> startPrecision;
  final Value<String> endPrecision;
  final Value<String> sleepType;
  final Value<String?> note;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SleepSessionsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.startPrecision = const Value.absent(),
    this.endPrecision = const Value.absent(),
    this.sleepType = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SleepSessionsCompanion.insert({
    required String id,
    required int startedAt,
    required int endedAt,
    required String startPrecision,
    required String endPrecision,
    required String sleepType,
    this.note = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt),
       endedAt = Value(endedAt),
       startPrecision = Value(startPrecision),
       endPrecision = Value(endPrecision),
       sleepType = Value(sleepType),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SleepSessionRow> custom({
    Expression<String>? id,
    Expression<int>? startedAt,
    Expression<int>? endedAt,
    Expression<String>? startPrecision,
    Expression<String>? endPrecision,
    Expression<String>? sleepType,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (startPrecision != null) 'start_precision': startPrecision,
      if (endPrecision != null) 'end_precision': endPrecision,
      if (sleepType != null) 'sleep_type': sleepType,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SleepSessionsCompanion copyWith({
    Value<String>? id,
    Value<int>? startedAt,
    Value<int>? endedAt,
    Value<String>? startPrecision,
    Value<String>? endPrecision,
    Value<String>? sleepType,
    Value<String?>? note,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SleepSessionsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      startPrecision: startPrecision ?? this.startPrecision,
      endPrecision: endPrecision ?? this.endPrecision,
      sleepType: sleepType ?? this.sleepType,
      note: note ?? this.note,
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
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<int>(endedAt.value);
    }
    if (startPrecision.present) {
      map['start_precision'] = Variable<String>(startPrecision.value);
    }
    if (endPrecision.present) {
      map['end_precision'] = Variable<String>(endPrecision.value);
    }
    if (sleepType.present) {
      map['sleep_type'] = Variable<String>(sleepType.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SleepSessionsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('startPrecision: $startPrecision, ')
          ..write('endPrecision: $endPrecision, ')
          ..write('sleepType: $sleepType, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyReviewsTable extends DailyReviews
    with TableInfo<$DailyReviewsTable, DailyReviewRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyReviewsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewDateMeta = const VerificationMeta(
    'reviewDate',
  );
  @override
  late final GeneratedColumn<String> reviewDate = GeneratedColumn<String>(
    'review_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reflectionMeta = const VerificationMeta(
    'reflection',
  );
  @override
  late final GeneratedColumn<String> reflection = GeneratedColumn<String>(
    'reflection',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tomorrowFirstStepTextMeta =
      const VerificationMeta('tomorrowFirstStepText');
  @override
  late final GeneratedColumn<String> tomorrowFirstStepText =
      GeneratedColumn<String>(
        'tomorrow_first_step_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _tomorrowFirstStepGoalIdMeta =
      const VerificationMeta('tomorrowFirstStepGoalId');
  @override
  late final GeneratedColumn<String> tomorrowFirstStepGoalId =
      GeneratedColumn<String>(
        'tomorrow_first_step_goal_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES goals (id) ON UPDATE RESTRICT ON DELETE RESTRICT',
        ),
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    reviewDate,
    summary,
    reflection,
    tomorrowFirstStepText,
    tomorrowFirstStepGoalId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_reviews';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyReviewRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('review_date')) {
      context.handle(
        _reviewDateMeta,
        reviewDate.isAcceptableOrUnknown(data['review_date']!, _reviewDateMeta),
      );
    } else if (isInserting) {
      context.missing(_reviewDateMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('reflection')) {
      context.handle(
        _reflectionMeta,
        reflection.isAcceptableOrUnknown(data['reflection']!, _reflectionMeta),
      );
    }
    if (data.containsKey('tomorrow_first_step_text')) {
      context.handle(
        _tomorrowFirstStepTextMeta,
        tomorrowFirstStepText.isAcceptableOrUnknown(
          data['tomorrow_first_step_text']!,
          _tomorrowFirstStepTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tomorrowFirstStepTextMeta);
    }
    if (data.containsKey('tomorrow_first_step_goal_id')) {
      context.handle(
        _tomorrowFirstStepGoalIdMeta,
        tomorrowFirstStepGoalId.isAcceptableOrUnknown(
          data['tomorrow_first_step_goal_id']!,
          _tomorrowFirstStepGoalIdMeta,
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
  DailyReviewRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyReviewRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      reviewDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}review_date'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      reflection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reflection'],
      ),
      tomorrowFirstStepText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tomorrow_first_step_text'],
      )!,
      tomorrowFirstStepGoalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tomorrow_first_step_goal_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DailyReviewsTable createAlias(String alias) {
    return $DailyReviewsTable(attachedDatabase, alias);
  }
}

class DailyReviewRow extends DataClass implements Insertable<DailyReviewRow> {
  final String id;
  final String reviewDate;
  final String? summary;
  final String? reflection;
  final String tomorrowFirstStepText;
  final String? tomorrowFirstStepGoalId;
  final int createdAt;
  final int updatedAt;
  const DailyReviewRow({
    required this.id,
    required this.reviewDate,
    this.summary,
    this.reflection,
    required this.tomorrowFirstStepText,
    this.tomorrowFirstStepGoalId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['review_date'] = Variable<String>(reviewDate);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || reflection != null) {
      map['reflection'] = Variable<String>(reflection);
    }
    map['tomorrow_first_step_text'] = Variable<String>(tomorrowFirstStepText);
    if (!nullToAbsent || tomorrowFirstStepGoalId != null) {
      map['tomorrow_first_step_goal_id'] = Variable<String>(
        tomorrowFirstStepGoalId,
      );
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  DailyReviewsCompanion toCompanion(bool nullToAbsent) {
    return DailyReviewsCompanion(
      id: Value(id),
      reviewDate: Value(reviewDate),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      reflection: reflection == null && nullToAbsent
          ? const Value.absent()
          : Value(reflection),
      tomorrowFirstStepText: Value(tomorrowFirstStepText),
      tomorrowFirstStepGoalId: tomorrowFirstStepGoalId == null && nullToAbsent
          ? const Value.absent()
          : Value(tomorrowFirstStepGoalId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DailyReviewRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyReviewRow(
      id: serializer.fromJson<String>(json['id']),
      reviewDate: serializer.fromJson<String>(json['reviewDate']),
      summary: serializer.fromJson<String?>(json['summary']),
      reflection: serializer.fromJson<String?>(json['reflection']),
      tomorrowFirstStepText: serializer.fromJson<String>(
        json['tomorrowFirstStepText'],
      ),
      tomorrowFirstStepGoalId: serializer.fromJson<String?>(
        json['tomorrowFirstStepGoalId'],
      ),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'reviewDate': serializer.toJson<String>(reviewDate),
      'summary': serializer.toJson<String?>(summary),
      'reflection': serializer.toJson<String?>(reflection),
      'tomorrowFirstStepText': serializer.toJson<String>(tomorrowFirstStepText),
      'tomorrowFirstStepGoalId': serializer.toJson<String?>(
        tomorrowFirstStepGoalId,
      ),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  DailyReviewRow copyWith({
    String? id,
    String? reviewDate,
    Value<String?> summary = const Value.absent(),
    Value<String?> reflection = const Value.absent(),
    String? tomorrowFirstStepText,
    Value<String?> tomorrowFirstStepGoalId = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => DailyReviewRow(
    id: id ?? this.id,
    reviewDate: reviewDate ?? this.reviewDate,
    summary: summary.present ? summary.value : this.summary,
    reflection: reflection.present ? reflection.value : this.reflection,
    tomorrowFirstStepText: tomorrowFirstStepText ?? this.tomorrowFirstStepText,
    tomorrowFirstStepGoalId: tomorrowFirstStepGoalId.present
        ? tomorrowFirstStepGoalId.value
        : this.tomorrowFirstStepGoalId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DailyReviewRow copyWithCompanion(DailyReviewsCompanion data) {
    return DailyReviewRow(
      id: data.id.present ? data.id.value : this.id,
      reviewDate: data.reviewDate.present
          ? data.reviewDate.value
          : this.reviewDate,
      summary: data.summary.present ? data.summary.value : this.summary,
      reflection: data.reflection.present
          ? data.reflection.value
          : this.reflection,
      tomorrowFirstStepText: data.tomorrowFirstStepText.present
          ? data.tomorrowFirstStepText.value
          : this.tomorrowFirstStepText,
      tomorrowFirstStepGoalId: data.tomorrowFirstStepGoalId.present
          ? data.tomorrowFirstStepGoalId.value
          : this.tomorrowFirstStepGoalId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyReviewRow(')
          ..write('id: $id, ')
          ..write('reviewDate: $reviewDate, ')
          ..write('summary: $summary, ')
          ..write('reflection: $reflection, ')
          ..write('tomorrowFirstStepText: $tomorrowFirstStepText, ')
          ..write('tomorrowFirstStepGoalId: $tomorrowFirstStepGoalId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    reviewDate,
    summary,
    reflection,
    tomorrowFirstStepText,
    tomorrowFirstStepGoalId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyReviewRow &&
          other.id == this.id &&
          other.reviewDate == this.reviewDate &&
          other.summary == this.summary &&
          other.reflection == this.reflection &&
          other.tomorrowFirstStepText == this.tomorrowFirstStepText &&
          other.tomorrowFirstStepGoalId == this.tomorrowFirstStepGoalId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DailyReviewsCompanion extends UpdateCompanion<DailyReviewRow> {
  final Value<String> id;
  final Value<String> reviewDate;
  final Value<String?> summary;
  final Value<String?> reflection;
  final Value<String> tomorrowFirstStepText;
  final Value<String?> tomorrowFirstStepGoalId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const DailyReviewsCompanion({
    this.id = const Value.absent(),
    this.reviewDate = const Value.absent(),
    this.summary = const Value.absent(),
    this.reflection = const Value.absent(),
    this.tomorrowFirstStepText = const Value.absent(),
    this.tomorrowFirstStepGoalId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyReviewsCompanion.insert({
    required String id,
    required String reviewDate,
    this.summary = const Value.absent(),
    this.reflection = const Value.absent(),
    required String tomorrowFirstStepText,
    this.tomorrowFirstStepGoalId = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       reviewDate = Value(reviewDate),
       tomorrowFirstStepText = Value(tomorrowFirstStepText),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DailyReviewRow> custom({
    Expression<String>? id,
    Expression<String>? reviewDate,
    Expression<String>? summary,
    Expression<String>? reflection,
    Expression<String>? tomorrowFirstStepText,
    Expression<String>? tomorrowFirstStepGoalId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (reviewDate != null) 'review_date': reviewDate,
      if (summary != null) 'summary': summary,
      if (reflection != null) 'reflection': reflection,
      if (tomorrowFirstStepText != null)
        'tomorrow_first_step_text': tomorrowFirstStepText,
      if (tomorrowFirstStepGoalId != null)
        'tomorrow_first_step_goal_id': tomorrowFirstStepGoalId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyReviewsCompanion copyWith({
    Value<String>? id,
    Value<String>? reviewDate,
    Value<String?>? summary,
    Value<String?>? reflection,
    Value<String>? tomorrowFirstStepText,
    Value<String?>? tomorrowFirstStepGoalId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return DailyReviewsCompanion(
      id: id ?? this.id,
      reviewDate: reviewDate ?? this.reviewDate,
      summary: summary ?? this.summary,
      reflection: reflection ?? this.reflection,
      tomorrowFirstStepText:
          tomorrowFirstStepText ?? this.tomorrowFirstStepText,
      tomorrowFirstStepGoalId:
          tomorrowFirstStepGoalId ?? this.tomorrowFirstStepGoalId,
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
    if (reviewDate.present) {
      map['review_date'] = Variable<String>(reviewDate.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (reflection.present) {
      map['reflection'] = Variable<String>(reflection.value);
    }
    if (tomorrowFirstStepText.present) {
      map['tomorrow_first_step_text'] = Variable<String>(
        tomorrowFirstStepText.value,
      );
    }
    if (tomorrowFirstStepGoalId.present) {
      map['tomorrow_first_step_goal_id'] = Variable<String>(
        tomorrowFirstStepGoalId.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyReviewsCompanion(')
          ..write('id: $id, ')
          ..write('reviewDate: $reviewDate, ')
          ..write('summary: $summary, ')
          ..write('reflection: $reflection, ')
          ..write('tomorrowFirstStepText: $tomorrowFirstStepText, ')
          ..write('tomorrowFirstStepGoalId: $tomorrowFirstStepGoalId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  late final $GoalsTable goals = $GoalsTable(this);
  late final $TimeBlocksTable timeBlocks = $TimeBlocksTable(this);
  late final $RhythmAnnotationsTable rhythmAnnotations =
      $RhythmAnnotationsTable(this);
  late final $SleepSessionsTable sleepSessions = $SleepSessionsTable(this);
  late final $DailyReviewsTable dailyReviews = $DailyReviewsTable(this);
  late final Index idxTimeBlocksStartedAt = Index(
    'idx_time_blocks_started_at',
    'CREATE INDEX idx_time_blocks_started_at ON time_blocks (started_at)',
  );
  late final Index idxTimeBlocksGoalStartedAt = Index(
    'idx_time_blocks_goal_started_at',
    'CREATE INDEX idx_time_blocks_goal_started_at ON time_blocks (goal_id, started_at)',
  );
  late final Index idxSleepSessionsStartedAt = Index(
    'idx_sleep_sessions_started_at',
    'CREATE INDEX idx_sleep_sessions_started_at ON sleep_sessions (started_at)',
  );
  late final Index idxDailyReviewsFirstStepGoal = Index(
    'idx_daily_reviews_first_step_goal',
    'CREATE INDEX idx_daily_reviews_first_step_goal ON daily_reviews (tomorrow_first_step_goal_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    goals,
    timeBlocks,
    rhythmAnnotations,
    sleepSessions,
    dailyReviews,
    idxTimeBlocksStartedAt,
    idxTimeBlocksGoalStartedAt,
    idxSleepSessionsStartedAt,
    idxDailyReviewsFirstStepGoal,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'time_blocks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('rhythm_annotations', kind: UpdateKind.delete)],
    ),
  ]);
}
