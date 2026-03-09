// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $EpisodeProgressTableTable extends EpisodeProgressTable
    with TableInfo<$EpisodeProgressTableTable, EpisodeProgressTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodeProgressTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _anilistIdMeta = const VerificationMeta(
    'anilistId',
  );
  @override
  late final GeneratedColumn<int> anilistId = GeneratedColumn<int>(
    'anilist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeNumberMeta = const VerificationMeta(
    'episodeNumber',
  );
  @override
  late final GeneratedColumn<double> episodeNumber = GeneratedColumn<double>(
    'episode_number',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionSecondsMeta = const VerificationMeta(
    'positionSeconds',
  );
  @override
  late final GeneratedColumn<int> positionSeconds = GeneratedColumn<int>(
    'position_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalDurationSecondsMeta =
      const VerificationMeta('totalDurationSeconds');
  @override
  late final GeneratedColumn<int> totalDurationSeconds = GeneratedColumn<int>(
    'total_duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _watchStateMeta = const VerificationMeta(
    'watchState',
  );
  @override
  late final GeneratedColumn<String> watchState = GeneratedColumn<String>(
    'watch_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unwatched'),
  );
  static const VerificationMeta _lastSourcePluginIdMeta =
      const VerificationMeta('lastSourcePluginId');
  @override
  late final GeneratedColumn<String> lastSourcePluginId =
      GeneratedColumn<String>(
        'last_source_plugin_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastServerNameMeta = const VerificationMeta(
    'lastServerName',
  );
  @override
  late final GeneratedColumn<String> lastServerName = GeneratedColumn<String>(
    'last_server_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastResolverPluginIdMeta =
      const VerificationMeta('lastResolverPluginId');
  @override
  late final GeneratedColumn<String> lastResolverPluginId =
      GeneratedColumn<String>(
        'last_resolver_plugin_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
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
    anilistId,
    episodeNumber,
    positionSeconds,
    totalDurationSeconds,
    watchState,
    lastSourcePluginId,
    lastServerName,
    lastResolverPluginId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episode_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpisodeProgressTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('anilist_id')) {
      context.handle(
        _anilistIdMeta,
        anilistId.isAcceptableOrUnknown(data['anilist_id']!, _anilistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_anilistIdMeta);
    }
    if (data.containsKey('episode_number')) {
      context.handle(
        _episodeNumberMeta,
        episodeNumber.isAcceptableOrUnknown(
          data['episode_number']!,
          _episodeNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_episodeNumberMeta);
    }
    if (data.containsKey('position_seconds')) {
      context.handle(
        _positionSecondsMeta,
        positionSeconds.isAcceptableOrUnknown(
          data['position_seconds']!,
          _positionSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_positionSecondsMeta);
    }
    if (data.containsKey('total_duration_seconds')) {
      context.handle(
        _totalDurationSecondsMeta,
        totalDurationSeconds.isAcceptableOrUnknown(
          data['total_duration_seconds']!,
          _totalDurationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('watch_state')) {
      context.handle(
        _watchStateMeta,
        watchState.isAcceptableOrUnknown(data['watch_state']!, _watchStateMeta),
      );
    }
    if (data.containsKey('last_source_plugin_id')) {
      context.handle(
        _lastSourcePluginIdMeta,
        lastSourcePluginId.isAcceptableOrUnknown(
          data['last_source_plugin_id']!,
          _lastSourcePluginIdMeta,
        ),
      );
    }
    if (data.containsKey('last_server_name')) {
      context.handle(
        _lastServerNameMeta,
        lastServerName.isAcceptableOrUnknown(
          data['last_server_name']!,
          _lastServerNameMeta,
        ),
      );
    }
    if (data.containsKey('last_resolver_plugin_id')) {
      context.handle(
        _lastResolverPluginIdMeta,
        lastResolverPluginId.isAcceptableOrUnknown(
          data['last_resolver_plugin_id']!,
          _lastResolverPluginIdMeta,
        ),
      );
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
  Set<GeneratedColumn> get $primaryKey => {anilistId, episodeNumber};
  @override
  EpisodeProgressTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpisodeProgressTableData(
      anilistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anilist_id'],
      )!,
      episodeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}episode_number'],
      )!,
      positionSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_seconds'],
      )!,
      totalDurationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_duration_seconds'],
      ),
      watchState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}watch_state'],
      )!,
      lastSourcePluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_source_plugin_id'],
      ),
      lastServerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_server_name'],
      ),
      lastResolverPluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_resolver_plugin_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EpisodeProgressTableTable createAlias(String alias) {
    return $EpisodeProgressTableTable(attachedDatabase, alias);
  }
}

class EpisodeProgressTableData extends DataClass
    implements Insertable<EpisodeProgressTableData> {
  final int anilistId;
  final double episodeNumber;
  final int positionSeconds;
  final int? totalDurationSeconds;
  final String watchState;
  final String? lastSourcePluginId;
  final String? lastServerName;
  final String? lastResolverPluginId;
  final int updatedAt;
  const EpisodeProgressTableData({
    required this.anilistId,
    required this.episodeNumber,
    required this.positionSeconds,
    this.totalDurationSeconds,
    required this.watchState,
    this.lastSourcePluginId,
    this.lastServerName,
    this.lastResolverPluginId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anilist_id'] = Variable<int>(anilistId);
    map['episode_number'] = Variable<double>(episodeNumber);
    map['position_seconds'] = Variable<int>(positionSeconds);
    if (!nullToAbsent || totalDurationSeconds != null) {
      map['total_duration_seconds'] = Variable<int>(totalDurationSeconds);
    }
    map['watch_state'] = Variable<String>(watchState);
    if (!nullToAbsent || lastSourcePluginId != null) {
      map['last_source_plugin_id'] = Variable<String>(lastSourcePluginId);
    }
    if (!nullToAbsent || lastServerName != null) {
      map['last_server_name'] = Variable<String>(lastServerName);
    }
    if (!nullToAbsent || lastResolverPluginId != null) {
      map['last_resolver_plugin_id'] = Variable<String>(lastResolverPluginId);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  EpisodeProgressTableCompanion toCompanion(bool nullToAbsent) {
    return EpisodeProgressTableCompanion(
      anilistId: Value(anilistId),
      episodeNumber: Value(episodeNumber),
      positionSeconds: Value(positionSeconds),
      totalDurationSeconds: totalDurationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(totalDurationSeconds),
      watchState: Value(watchState),
      lastSourcePluginId: lastSourcePluginId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSourcePluginId),
      lastServerName: lastServerName == null && nullToAbsent
          ? const Value.absent()
          : Value(lastServerName),
      lastResolverPluginId: lastResolverPluginId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastResolverPluginId),
      updatedAt: Value(updatedAt),
    );
  }

  factory EpisodeProgressTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpisodeProgressTableData(
      anilistId: serializer.fromJson<int>(json['anilistId']),
      episodeNumber: serializer.fromJson<double>(json['episodeNumber']),
      positionSeconds: serializer.fromJson<int>(json['positionSeconds']),
      totalDurationSeconds: serializer.fromJson<int?>(
        json['totalDurationSeconds'],
      ),
      watchState: serializer.fromJson<String>(json['watchState']),
      lastSourcePluginId: serializer.fromJson<String?>(
        json['lastSourcePluginId'],
      ),
      lastServerName: serializer.fromJson<String?>(json['lastServerName']),
      lastResolverPluginId: serializer.fromJson<String?>(
        json['lastResolverPluginId'],
      ),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'anilistId': serializer.toJson<int>(anilistId),
      'episodeNumber': serializer.toJson<double>(episodeNumber),
      'positionSeconds': serializer.toJson<int>(positionSeconds),
      'totalDurationSeconds': serializer.toJson<int?>(totalDurationSeconds),
      'watchState': serializer.toJson<String>(watchState),
      'lastSourcePluginId': serializer.toJson<String?>(lastSourcePluginId),
      'lastServerName': serializer.toJson<String?>(lastServerName),
      'lastResolverPluginId': serializer.toJson<String?>(lastResolverPluginId),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  EpisodeProgressTableData copyWith({
    int? anilistId,
    double? episodeNumber,
    int? positionSeconds,
    Value<int?> totalDurationSeconds = const Value.absent(),
    String? watchState,
    Value<String?> lastSourcePluginId = const Value.absent(),
    Value<String?> lastServerName = const Value.absent(),
    Value<String?> lastResolverPluginId = const Value.absent(),
    int? updatedAt,
  }) => EpisodeProgressTableData(
    anilistId: anilistId ?? this.anilistId,
    episodeNumber: episodeNumber ?? this.episodeNumber,
    positionSeconds: positionSeconds ?? this.positionSeconds,
    totalDurationSeconds: totalDurationSeconds.present
        ? totalDurationSeconds.value
        : this.totalDurationSeconds,
    watchState: watchState ?? this.watchState,
    lastSourcePluginId: lastSourcePluginId.present
        ? lastSourcePluginId.value
        : this.lastSourcePluginId,
    lastServerName: lastServerName.present
        ? lastServerName.value
        : this.lastServerName,
    lastResolverPluginId: lastResolverPluginId.present
        ? lastResolverPluginId.value
        : this.lastResolverPluginId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EpisodeProgressTableData copyWithCompanion(
    EpisodeProgressTableCompanion data,
  ) {
    return EpisodeProgressTableData(
      anilistId: data.anilistId.present ? data.anilistId.value : this.anilistId,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      positionSeconds: data.positionSeconds.present
          ? data.positionSeconds.value
          : this.positionSeconds,
      totalDurationSeconds: data.totalDurationSeconds.present
          ? data.totalDurationSeconds.value
          : this.totalDurationSeconds,
      watchState: data.watchState.present
          ? data.watchState.value
          : this.watchState,
      lastSourcePluginId: data.lastSourcePluginId.present
          ? data.lastSourcePluginId.value
          : this.lastSourcePluginId,
      lastServerName: data.lastServerName.present
          ? data.lastServerName.value
          : this.lastServerName,
      lastResolverPluginId: data.lastResolverPluginId.present
          ? data.lastResolverPluginId.value
          : this.lastResolverPluginId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeProgressTableData(')
          ..write('anilistId: $anilistId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('totalDurationSeconds: $totalDurationSeconds, ')
          ..write('watchState: $watchState, ')
          ..write('lastSourcePluginId: $lastSourcePluginId, ')
          ..write('lastServerName: $lastServerName, ')
          ..write('lastResolverPluginId: $lastResolverPluginId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    anilistId,
    episodeNumber,
    positionSeconds,
    totalDurationSeconds,
    watchState,
    lastSourcePluginId,
    lastServerName,
    lastResolverPluginId,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodeProgressTableData &&
          other.anilistId == this.anilistId &&
          other.episodeNumber == this.episodeNumber &&
          other.positionSeconds == this.positionSeconds &&
          other.totalDurationSeconds == this.totalDurationSeconds &&
          other.watchState == this.watchState &&
          other.lastSourcePluginId == this.lastSourcePluginId &&
          other.lastServerName == this.lastServerName &&
          other.lastResolverPluginId == this.lastResolverPluginId &&
          other.updatedAt == this.updatedAt);
}

class EpisodeProgressTableCompanion
    extends UpdateCompanion<EpisodeProgressTableData> {
  final Value<int> anilistId;
  final Value<double> episodeNumber;
  final Value<int> positionSeconds;
  final Value<int?> totalDurationSeconds;
  final Value<String> watchState;
  final Value<String?> lastSourcePluginId;
  final Value<String?> lastServerName;
  final Value<String?> lastResolverPluginId;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const EpisodeProgressTableCompanion({
    this.anilistId = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.totalDurationSeconds = const Value.absent(),
    this.watchState = const Value.absent(),
    this.lastSourcePluginId = const Value.absent(),
    this.lastServerName = const Value.absent(),
    this.lastResolverPluginId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpisodeProgressTableCompanion.insert({
    required int anilistId,
    required double episodeNumber,
    required int positionSeconds,
    this.totalDurationSeconds = const Value.absent(),
    this.watchState = const Value.absent(),
    this.lastSourcePluginId = const Value.absent(),
    this.lastServerName = const Value.absent(),
    this.lastResolverPluginId = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : anilistId = Value(anilistId),
       episodeNumber = Value(episodeNumber),
       positionSeconds = Value(positionSeconds),
       updatedAt = Value(updatedAt);
  static Insertable<EpisodeProgressTableData> custom({
    Expression<int>? anilistId,
    Expression<double>? episodeNumber,
    Expression<int>? positionSeconds,
    Expression<int>? totalDurationSeconds,
    Expression<String>? watchState,
    Expression<String>? lastSourcePluginId,
    Expression<String>? lastServerName,
    Expression<String>? lastResolverPluginId,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (anilistId != null) 'anilist_id': anilistId,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (positionSeconds != null) 'position_seconds': positionSeconds,
      if (totalDurationSeconds != null)
        'total_duration_seconds': totalDurationSeconds,
      if (watchState != null) 'watch_state': watchState,
      if (lastSourcePluginId != null)
        'last_source_plugin_id': lastSourcePluginId,
      if (lastServerName != null) 'last_server_name': lastServerName,
      if (lastResolverPluginId != null)
        'last_resolver_plugin_id': lastResolverPluginId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpisodeProgressTableCompanion copyWith({
    Value<int>? anilistId,
    Value<double>? episodeNumber,
    Value<int>? positionSeconds,
    Value<int?>? totalDurationSeconds,
    Value<String>? watchState,
    Value<String?>? lastSourcePluginId,
    Value<String?>? lastServerName,
    Value<String?>? lastResolverPluginId,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return EpisodeProgressTableCompanion(
      anilistId: anilistId ?? this.anilistId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      watchState: watchState ?? this.watchState,
      lastSourcePluginId: lastSourcePluginId ?? this.lastSourcePluginId,
      lastServerName: lastServerName ?? this.lastServerName,
      lastResolverPluginId: lastResolverPluginId ?? this.lastResolverPluginId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (anilistId.present) {
      map['anilist_id'] = Variable<int>(anilistId.value);
    }
    if (episodeNumber.present) {
      map['episode_number'] = Variable<double>(episodeNumber.value);
    }
    if (positionSeconds.present) {
      map['position_seconds'] = Variable<int>(positionSeconds.value);
    }
    if (totalDurationSeconds.present) {
      map['total_duration_seconds'] = Variable<int>(totalDurationSeconds.value);
    }
    if (watchState.present) {
      map['watch_state'] = Variable<String>(watchState.value);
    }
    if (lastSourcePluginId.present) {
      map['last_source_plugin_id'] = Variable<String>(lastSourcePluginId.value);
    }
    if (lastServerName.present) {
      map['last_server_name'] = Variable<String>(lastServerName.value);
    }
    if (lastResolverPluginId.present) {
      map['last_resolver_plugin_id'] = Variable<String>(
        lastResolverPluginId.value,
      );
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
    return (StringBuffer('EpisodeProgressTableCompanion(')
          ..write('anilistId: $anilistId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('totalDurationSeconds: $totalDurationSeconds, ')
          ..write('watchState: $watchState, ')
          ..write('lastSourcePluginId: $lastSourcePluginId, ')
          ..write('lastServerName: $lastServerName, ')
          ..write('lastResolverPluginId: $lastResolverPluginId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchHistoryTableTable extends WatchHistoryTable
    with TableInfo<$WatchHistoryTableTable, WatchHistoryTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchHistoryTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _anilistIdMeta = const VerificationMeta(
    'anilistId',
  );
  @override
  late final GeneratedColumn<int> anilistId = GeneratedColumn<int>(
    'anilist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastEpisodeNumberMeta = const VerificationMeta(
    'lastEpisodeNumber',
  );
  @override
  late final GeneratedColumn<double> lastEpisodeNumber =
      GeneratedColumn<double>(
        'last_episode_number',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastSourcePluginIdMeta =
      const VerificationMeta('lastSourcePluginId');
  @override
  late final GeneratedColumn<String> lastSourcePluginId =
      GeneratedColumn<String>(
        'last_source_plugin_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastAccessedAtMeta = const VerificationMeta(
    'lastAccessedAt',
  );
  @override
  late final GeneratedColumn<int> lastAccessedAt = GeneratedColumn<int>(
    'last_accessed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    anilistId,
    lastEpisodeNumber,
    lastSourcePluginId,
    lastAccessedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchHistoryTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('anilist_id')) {
      context.handle(
        _anilistIdMeta,
        anilistId.isAcceptableOrUnknown(data['anilist_id']!, _anilistIdMeta),
      );
    }
    if (data.containsKey('last_episode_number')) {
      context.handle(
        _lastEpisodeNumberMeta,
        lastEpisodeNumber.isAcceptableOrUnknown(
          data['last_episode_number']!,
          _lastEpisodeNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastEpisodeNumberMeta);
    }
    if (data.containsKey('last_source_plugin_id')) {
      context.handle(
        _lastSourcePluginIdMeta,
        lastSourcePluginId.isAcceptableOrUnknown(
          data['last_source_plugin_id']!,
          _lastSourcePluginIdMeta,
        ),
      );
    }
    if (data.containsKey('last_accessed_at')) {
      context.handle(
        _lastAccessedAtMeta,
        lastAccessedAt.isAcceptableOrUnknown(
          data['last_accessed_at']!,
          _lastAccessedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastAccessedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {anilistId};
  @override
  WatchHistoryTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchHistoryTableData(
      anilistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anilist_id'],
      )!,
      lastEpisodeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_episode_number'],
      )!,
      lastSourcePluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_source_plugin_id'],
      ),
      lastAccessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_accessed_at'],
      )!,
    );
  }

  @override
  $WatchHistoryTableTable createAlias(String alias) {
    return $WatchHistoryTableTable(attachedDatabase, alias);
  }
}

class WatchHistoryTableData extends DataClass
    implements Insertable<WatchHistoryTableData> {
  final int anilistId;
  final double lastEpisodeNumber;
  final String? lastSourcePluginId;
  final int lastAccessedAt;
  const WatchHistoryTableData({
    required this.anilistId,
    required this.lastEpisodeNumber,
    this.lastSourcePluginId,
    required this.lastAccessedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anilist_id'] = Variable<int>(anilistId);
    map['last_episode_number'] = Variable<double>(lastEpisodeNumber);
    if (!nullToAbsent || lastSourcePluginId != null) {
      map['last_source_plugin_id'] = Variable<String>(lastSourcePluginId);
    }
    map['last_accessed_at'] = Variable<int>(lastAccessedAt);
    return map;
  }

  WatchHistoryTableCompanion toCompanion(bool nullToAbsent) {
    return WatchHistoryTableCompanion(
      anilistId: Value(anilistId),
      lastEpisodeNumber: Value(lastEpisodeNumber),
      lastSourcePluginId: lastSourcePluginId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSourcePluginId),
      lastAccessedAt: Value(lastAccessedAt),
    );
  }

  factory WatchHistoryTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchHistoryTableData(
      anilistId: serializer.fromJson<int>(json['anilistId']),
      lastEpisodeNumber: serializer.fromJson<double>(json['lastEpisodeNumber']),
      lastSourcePluginId: serializer.fromJson<String?>(
        json['lastSourcePluginId'],
      ),
      lastAccessedAt: serializer.fromJson<int>(json['lastAccessedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'anilistId': serializer.toJson<int>(anilistId),
      'lastEpisodeNumber': serializer.toJson<double>(lastEpisodeNumber),
      'lastSourcePluginId': serializer.toJson<String?>(lastSourcePluginId),
      'lastAccessedAt': serializer.toJson<int>(lastAccessedAt),
    };
  }

  WatchHistoryTableData copyWith({
    int? anilistId,
    double? lastEpisodeNumber,
    Value<String?> lastSourcePluginId = const Value.absent(),
    int? lastAccessedAt,
  }) => WatchHistoryTableData(
    anilistId: anilistId ?? this.anilistId,
    lastEpisodeNumber: lastEpisodeNumber ?? this.lastEpisodeNumber,
    lastSourcePluginId: lastSourcePluginId.present
        ? lastSourcePluginId.value
        : this.lastSourcePluginId,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
  );
  WatchHistoryTableData copyWithCompanion(WatchHistoryTableCompanion data) {
    return WatchHistoryTableData(
      anilistId: data.anilistId.present ? data.anilistId.value : this.anilistId,
      lastEpisodeNumber: data.lastEpisodeNumber.present
          ? data.lastEpisodeNumber.value
          : this.lastEpisodeNumber,
      lastSourcePluginId: data.lastSourcePluginId.present
          ? data.lastSourcePluginId.value
          : this.lastSourcePluginId,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchHistoryTableData(')
          ..write('anilistId: $anilistId, ')
          ..write('lastEpisodeNumber: $lastEpisodeNumber, ')
          ..write('lastSourcePluginId: $lastSourcePluginId, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    anilistId,
    lastEpisodeNumber,
    lastSourcePluginId,
    lastAccessedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchHistoryTableData &&
          other.anilistId == this.anilistId &&
          other.lastEpisodeNumber == this.lastEpisodeNumber &&
          other.lastSourcePluginId == this.lastSourcePluginId &&
          other.lastAccessedAt == this.lastAccessedAt);
}

class WatchHistoryTableCompanion
    extends UpdateCompanion<WatchHistoryTableData> {
  final Value<int> anilistId;
  final Value<double> lastEpisodeNumber;
  final Value<String?> lastSourcePluginId;
  final Value<int> lastAccessedAt;
  const WatchHistoryTableCompanion({
    this.anilistId = const Value.absent(),
    this.lastEpisodeNumber = const Value.absent(),
    this.lastSourcePluginId = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
  });
  WatchHistoryTableCompanion.insert({
    this.anilistId = const Value.absent(),
    required double lastEpisodeNumber,
    this.lastSourcePluginId = const Value.absent(),
    required int lastAccessedAt,
  }) : lastEpisodeNumber = Value(lastEpisodeNumber),
       lastAccessedAt = Value(lastAccessedAt);
  static Insertable<WatchHistoryTableData> custom({
    Expression<int>? anilistId,
    Expression<double>? lastEpisodeNumber,
    Expression<String>? lastSourcePluginId,
    Expression<int>? lastAccessedAt,
  }) {
    return RawValuesInsertable({
      if (anilistId != null) 'anilist_id': anilistId,
      if (lastEpisodeNumber != null) 'last_episode_number': lastEpisodeNumber,
      if (lastSourcePluginId != null)
        'last_source_plugin_id': lastSourcePluginId,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
    });
  }

  WatchHistoryTableCompanion copyWith({
    Value<int>? anilistId,
    Value<double>? lastEpisodeNumber,
    Value<String?>? lastSourcePluginId,
    Value<int>? lastAccessedAt,
  }) {
    return WatchHistoryTableCompanion(
      anilistId: anilistId ?? this.anilistId,
      lastEpisodeNumber: lastEpisodeNumber ?? this.lastEpisodeNumber,
      lastSourcePluginId: lastSourcePluginId ?? this.lastSourcePluginId,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (anilistId.present) {
      map['anilist_id'] = Variable<int>(anilistId.value);
    }
    if (lastEpisodeNumber.present) {
      map['last_episode_number'] = Variable<double>(lastEpisodeNumber.value);
    }
    if (lastSourcePluginId.present) {
      map['last_source_plugin_id'] = Variable<String>(lastSourcePluginId.value);
    }
    if (lastAccessedAt.present) {
      map['last_accessed_at'] = Variable<int>(lastAccessedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchHistoryTableCompanion(')
          ..write('anilistId: $anilistId, ')
          ..write('lastEpisodeNumber: $lastEpisodeNumber, ')
          ..write('lastSourcePluginId: $lastSourcePluginId, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }
}

class $PlaybackPreferenceTableTable extends PlaybackPreferenceTable
    with TableInfo<$PlaybackPreferenceTableTable, PlaybackPreferenceTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackPreferenceTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _anilistIdMeta = const VerificationMeta(
    'anilistId',
  );
  @override
  late final GeneratedColumn<int> anilistId = GeneratedColumn<int>(
    'anilist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preferredSourcePluginIdMeta =
      const VerificationMeta('preferredSourcePluginId');
  @override
  late final GeneratedColumn<String> preferredSourcePluginId =
      GeneratedColumn<String>(
        'preferred_source_plugin_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _preferredServerNameMeta =
      const VerificationMeta('preferredServerName');
  @override
  late final GeneratedColumn<String> preferredServerName =
      GeneratedColumn<String>(
        'preferred_server_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _preferredResolverPluginIdMeta =
      const VerificationMeta('preferredResolverPluginId');
  @override
  late final GeneratedColumn<String> preferredResolverPluginId =
      GeneratedColumn<String>(
        'preferred_resolver_plugin_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _preferredAudioPreferenceMeta =
      const VerificationMeta('preferredAudioPreference');
  @override
  late final GeneratedColumn<String> preferredAudioPreference =
      GeneratedColumn<String>(
        'preferred_audio_preference',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
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
    anilistId,
    preferredSourcePluginId,
    preferredServerName,
    preferredResolverPluginId,
    preferredAudioPreference,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_preference';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackPreferenceTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('anilist_id')) {
      context.handle(
        _anilistIdMeta,
        anilistId.isAcceptableOrUnknown(data['anilist_id']!, _anilistIdMeta),
      );
    }
    if (data.containsKey('preferred_source_plugin_id')) {
      context.handle(
        _preferredSourcePluginIdMeta,
        preferredSourcePluginId.isAcceptableOrUnknown(
          data['preferred_source_plugin_id']!,
          _preferredSourcePluginIdMeta,
        ),
      );
    }
    if (data.containsKey('preferred_server_name')) {
      context.handle(
        _preferredServerNameMeta,
        preferredServerName.isAcceptableOrUnknown(
          data['preferred_server_name']!,
          _preferredServerNameMeta,
        ),
      );
    }
    if (data.containsKey('preferred_resolver_plugin_id')) {
      context.handle(
        _preferredResolverPluginIdMeta,
        preferredResolverPluginId.isAcceptableOrUnknown(
          data['preferred_resolver_plugin_id']!,
          _preferredResolverPluginIdMeta,
        ),
      );
    }
    if (data.containsKey('preferred_audio_preference')) {
      context.handle(
        _preferredAudioPreferenceMeta,
        preferredAudioPreference.isAcceptableOrUnknown(
          data['preferred_audio_preference']!,
          _preferredAudioPreferenceMeta,
        ),
      );
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
  Set<GeneratedColumn> get $primaryKey => {anilistId};
  @override
  PlaybackPreferenceTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackPreferenceTableData(
      anilistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anilist_id'],
      )!,
      preferredSourcePluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_source_plugin_id'],
      ),
      preferredServerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_server_name'],
      ),
      preferredResolverPluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_resolver_plugin_id'],
      ),
      preferredAudioPreference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_audio_preference'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaybackPreferenceTableTable createAlias(String alias) {
    return $PlaybackPreferenceTableTable(attachedDatabase, alias);
  }
}

class PlaybackPreferenceTableData extends DataClass
    implements Insertable<PlaybackPreferenceTableData> {
  final int anilistId;
  final String? preferredSourcePluginId;
  final String? preferredServerName;
  final String? preferredResolverPluginId;
  final String? preferredAudioPreference;
  final int updatedAt;
  const PlaybackPreferenceTableData({
    required this.anilistId,
    this.preferredSourcePluginId,
    this.preferredServerName,
    this.preferredResolverPluginId,
    this.preferredAudioPreference,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anilist_id'] = Variable<int>(anilistId);
    if (!nullToAbsent || preferredSourcePluginId != null) {
      map['preferred_source_plugin_id'] = Variable<String>(
        preferredSourcePluginId,
      );
    }
    if (!nullToAbsent || preferredServerName != null) {
      map['preferred_server_name'] = Variable<String>(preferredServerName);
    }
    if (!nullToAbsent || preferredResolverPluginId != null) {
      map['preferred_resolver_plugin_id'] = Variable<String>(
        preferredResolverPluginId,
      );
    }
    if (!nullToAbsent || preferredAudioPreference != null) {
      map['preferred_audio_preference'] = Variable<String>(
        preferredAudioPreference,
      );
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PlaybackPreferenceTableCompanion toCompanion(bool nullToAbsent) {
    return PlaybackPreferenceTableCompanion(
      anilistId: Value(anilistId),
      preferredSourcePluginId: preferredSourcePluginId == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredSourcePluginId),
      preferredServerName: preferredServerName == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredServerName),
      preferredResolverPluginId:
          preferredResolverPluginId == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredResolverPluginId),
      preferredAudioPreference: preferredAudioPreference == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredAudioPreference),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaybackPreferenceTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackPreferenceTableData(
      anilistId: serializer.fromJson<int>(json['anilistId']),
      preferredSourcePluginId: serializer.fromJson<String?>(
        json['preferredSourcePluginId'],
      ),
      preferredServerName: serializer.fromJson<String?>(
        json['preferredServerName'],
      ),
      preferredResolverPluginId: serializer.fromJson<String?>(
        json['preferredResolverPluginId'],
      ),
      preferredAudioPreference: serializer.fromJson<String?>(
        json['preferredAudioPreference'],
      ),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'anilistId': serializer.toJson<int>(anilistId),
      'preferredSourcePluginId': serializer.toJson<String?>(
        preferredSourcePluginId,
      ),
      'preferredServerName': serializer.toJson<String?>(preferredServerName),
      'preferredResolverPluginId': serializer.toJson<String?>(
        preferredResolverPluginId,
      ),
      'preferredAudioPreference': serializer.toJson<String?>(
        preferredAudioPreference,
      ),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  PlaybackPreferenceTableData copyWith({
    int? anilistId,
    Value<String?> preferredSourcePluginId = const Value.absent(),
    Value<String?> preferredServerName = const Value.absent(),
    Value<String?> preferredResolverPluginId = const Value.absent(),
    Value<String?> preferredAudioPreference = const Value.absent(),
    int? updatedAt,
  }) => PlaybackPreferenceTableData(
    anilistId: anilistId ?? this.anilistId,
    preferredSourcePluginId: preferredSourcePluginId.present
        ? preferredSourcePluginId.value
        : this.preferredSourcePluginId,
    preferredServerName: preferredServerName.present
        ? preferredServerName.value
        : this.preferredServerName,
    preferredResolverPluginId: preferredResolverPluginId.present
        ? preferredResolverPluginId.value
        : this.preferredResolverPluginId,
    preferredAudioPreference: preferredAudioPreference.present
        ? preferredAudioPreference.value
        : this.preferredAudioPreference,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaybackPreferenceTableData copyWithCompanion(
    PlaybackPreferenceTableCompanion data,
  ) {
    return PlaybackPreferenceTableData(
      anilistId: data.anilistId.present ? data.anilistId.value : this.anilistId,
      preferredSourcePluginId: data.preferredSourcePluginId.present
          ? data.preferredSourcePluginId.value
          : this.preferredSourcePluginId,
      preferredServerName: data.preferredServerName.present
          ? data.preferredServerName.value
          : this.preferredServerName,
      preferredResolverPluginId: data.preferredResolverPluginId.present
          ? data.preferredResolverPluginId.value
          : this.preferredResolverPluginId,
      preferredAudioPreference: data.preferredAudioPreference.present
          ? data.preferredAudioPreference.value
          : this.preferredAudioPreference,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackPreferenceTableData(')
          ..write('anilistId: $anilistId, ')
          ..write('preferredSourcePluginId: $preferredSourcePluginId, ')
          ..write('preferredServerName: $preferredServerName, ')
          ..write('preferredResolverPluginId: $preferredResolverPluginId, ')
          ..write('preferredAudioPreference: $preferredAudioPreference, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    anilistId,
    preferredSourcePluginId,
    preferredServerName,
    preferredResolverPluginId,
    preferredAudioPreference,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackPreferenceTableData &&
          other.anilistId == this.anilistId &&
          other.preferredSourcePluginId == this.preferredSourcePluginId &&
          other.preferredServerName == this.preferredServerName &&
          other.preferredResolverPluginId == this.preferredResolverPluginId &&
          other.preferredAudioPreference == this.preferredAudioPreference &&
          other.updatedAt == this.updatedAt);
}

class PlaybackPreferenceTableCompanion
    extends UpdateCompanion<PlaybackPreferenceTableData> {
  final Value<int> anilistId;
  final Value<String?> preferredSourcePluginId;
  final Value<String?> preferredServerName;
  final Value<String?> preferredResolverPluginId;
  final Value<String?> preferredAudioPreference;
  final Value<int> updatedAt;
  const PlaybackPreferenceTableCompanion({
    this.anilistId = const Value.absent(),
    this.preferredSourcePluginId = const Value.absent(),
    this.preferredServerName = const Value.absent(),
    this.preferredResolverPluginId = const Value.absent(),
    this.preferredAudioPreference = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PlaybackPreferenceTableCompanion.insert({
    this.anilistId = const Value.absent(),
    this.preferredSourcePluginId = const Value.absent(),
    this.preferredServerName = const Value.absent(),
    this.preferredResolverPluginId = const Value.absent(),
    this.preferredAudioPreference = const Value.absent(),
    required int updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<PlaybackPreferenceTableData> custom({
    Expression<int>? anilistId,
    Expression<String>? preferredSourcePluginId,
    Expression<String>? preferredServerName,
    Expression<String>? preferredResolverPluginId,
    Expression<String>? preferredAudioPreference,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (anilistId != null) 'anilist_id': anilistId,
      if (preferredSourcePluginId != null)
        'preferred_source_plugin_id': preferredSourcePluginId,
      if (preferredServerName != null)
        'preferred_server_name': preferredServerName,
      if (preferredResolverPluginId != null)
        'preferred_resolver_plugin_id': preferredResolverPluginId,
      if (preferredAudioPreference != null)
        'preferred_audio_preference': preferredAudioPreference,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PlaybackPreferenceTableCompanion copyWith({
    Value<int>? anilistId,
    Value<String?>? preferredSourcePluginId,
    Value<String?>? preferredServerName,
    Value<String?>? preferredResolverPluginId,
    Value<String?>? preferredAudioPreference,
    Value<int>? updatedAt,
  }) {
    return PlaybackPreferenceTableCompanion(
      anilistId: anilistId ?? this.anilistId,
      preferredSourcePluginId:
          preferredSourcePluginId ?? this.preferredSourcePluginId,
      preferredServerName: preferredServerName ?? this.preferredServerName,
      preferredResolverPluginId:
          preferredResolverPluginId ?? this.preferredResolverPluginId,
      preferredAudioPreference:
          preferredAudioPreference ?? this.preferredAudioPreference,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (anilistId.present) {
      map['anilist_id'] = Variable<int>(anilistId.value);
    }
    if (preferredSourcePluginId.present) {
      map['preferred_source_plugin_id'] = Variable<String>(
        preferredSourcePluginId.value,
      );
    }
    if (preferredServerName.present) {
      map['preferred_server_name'] = Variable<String>(
        preferredServerName.value,
      );
    }
    if (preferredResolverPluginId.present) {
      map['preferred_resolver_plugin_id'] = Variable<String>(
        preferredResolverPluginId.value,
      );
    }
    if (preferredAudioPreference.present) {
      map['preferred_audio_preference'] = Variable<String>(
        preferredAudioPreference.value,
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackPreferenceTableCompanion(')
          ..write('anilistId: $anilistId, ')
          ..write('preferredSourcePluginId: $preferredSourcePluginId, ')
          ..write('preferredServerName: $preferredServerName, ')
          ..write('preferredResolverPluginId: $preferredResolverPluginId, ')
          ..write('preferredAudioPreference: $preferredAudioPreference, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SourceAvailabilityCacheTableTable extends SourceAvailabilityCacheTable
    with
        TableInfo<
          $SourceAvailabilityCacheTableTable,
          SourceAvailabilityCacheTableData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourceAvailabilityCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _anilistIdMeta = const VerificationMeta(
    'anilistId',
  );
  @override
  late final GeneratedColumn<int> anilistId = GeneratedColumn<int>(
    'anilist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePluginIdMeta = const VerificationMeta(
    'sourcePluginId',
  );
  @override
  late final GeneratedColumn<String> sourcePluginId = GeneratedColumn<String>(
    'source_plugin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
    anilistId,
    sourcePluginId,
    payloadJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'source_availability_cache_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceAvailabilityCacheTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('anilist_id')) {
      context.handle(
        _anilistIdMeta,
        anilistId.isAcceptableOrUnknown(data['anilist_id']!, _anilistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_anilistIdMeta);
    }
    if (data.containsKey('source_plugin_id')) {
      context.handle(
        _sourcePluginIdMeta,
        sourcePluginId.isAcceptableOrUnknown(
          data['source_plugin_id']!,
          _sourcePluginIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourcePluginIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
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
  Set<GeneratedColumn> get $primaryKey => {anilistId, sourcePluginId};
  @override
  SourceAvailabilityCacheTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceAvailabilityCacheTableData(
      anilistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anilist_id'],
      )!,
      sourcePluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_plugin_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SourceAvailabilityCacheTableTable createAlias(String alias) {
    return $SourceAvailabilityCacheTableTable(attachedDatabase, alias);
  }
}

class SourceAvailabilityCacheTableData extends DataClass
    implements Insertable<SourceAvailabilityCacheTableData> {
  final int anilistId;
  final String sourcePluginId;
  final String payloadJson;
  final int updatedAt;
  const SourceAvailabilityCacheTableData({
    required this.anilistId,
    required this.sourcePluginId,
    required this.payloadJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anilist_id'] = Variable<int>(anilistId);
    map['source_plugin_id'] = Variable<String>(sourcePluginId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SourceAvailabilityCacheTableCompanion toCompanion(bool nullToAbsent) {
    return SourceAvailabilityCacheTableCompanion(
      anilistId: Value(anilistId),
      sourcePluginId: Value(sourcePluginId),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory SourceAvailabilityCacheTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceAvailabilityCacheTableData(
      anilistId: serializer.fromJson<int>(json['anilistId']),
      sourcePluginId: serializer.fromJson<String>(json['sourcePluginId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'anilistId': serializer.toJson<int>(anilistId),
      'sourcePluginId': serializer.toJson<String>(sourcePluginId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SourceAvailabilityCacheTableData copyWith({
    int? anilistId,
    String? sourcePluginId,
    String? payloadJson,
    int? updatedAt,
  }) => SourceAvailabilityCacheTableData(
    anilistId: anilistId ?? this.anilistId,
    sourcePluginId: sourcePluginId ?? this.sourcePluginId,
    payloadJson: payloadJson ?? this.payloadJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SourceAvailabilityCacheTableData copyWithCompanion(
    SourceAvailabilityCacheTableCompanion data,
  ) {
    return SourceAvailabilityCacheTableData(
      anilistId: data.anilistId.present ? data.anilistId.value : this.anilistId,
      sourcePluginId: data.sourcePluginId.present
          ? data.sourcePluginId.value
          : this.sourcePluginId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceAvailabilityCacheTableData(')
          ..write('anilistId: $anilistId, ')
          ..write('sourcePluginId: $sourcePluginId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(anilistId, sourcePluginId, payloadJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceAvailabilityCacheTableData &&
          other.anilistId == this.anilistId &&
          other.sourcePluginId == this.sourcePluginId &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class SourceAvailabilityCacheTableCompanion
    extends UpdateCompanion<SourceAvailabilityCacheTableData> {
  final Value<int> anilistId;
  final Value<String> sourcePluginId;
  final Value<String> payloadJson;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SourceAvailabilityCacheTableCompanion({
    this.anilistId = const Value.absent(),
    this.sourcePluginId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourceAvailabilityCacheTableCompanion.insert({
    required int anilistId,
    required String sourcePluginId,
    required String payloadJson,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : anilistId = Value(anilistId),
       sourcePluginId = Value(sourcePluginId),
       payloadJson = Value(payloadJson),
       updatedAt = Value(updatedAt);
  static Insertable<SourceAvailabilityCacheTableData> custom({
    Expression<int>? anilistId,
    Expression<String>? sourcePluginId,
    Expression<String>? payloadJson,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (anilistId != null) 'anilist_id': anilistId,
      if (sourcePluginId != null) 'source_plugin_id': sourcePluginId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourceAvailabilityCacheTableCompanion copyWith({
    Value<int>? anilistId,
    Value<String>? sourcePluginId,
    Value<String>? payloadJson,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SourceAvailabilityCacheTableCompanion(
      anilistId: anilistId ?? this.anilistId,
      sourcePluginId: sourcePluginId ?? this.sourcePluginId,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (anilistId.present) {
      map['anilist_id'] = Variable<int>(anilistId.value);
    }
    if (sourcePluginId.present) {
      map['source_plugin_id'] = Variable<String>(sourcePluginId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
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
    return (StringBuffer('SourceAvailabilityCacheTableCompanion(')
          ..write('anilistId: $anilistId, ')
          ..write('sourcePluginId: $sourcePluginId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EpisodeProgressTableTable episodeProgressTable =
      $EpisodeProgressTableTable(this);
  late final $WatchHistoryTableTable watchHistoryTable =
      $WatchHistoryTableTable(this);
  late final $PlaybackPreferenceTableTable playbackPreferenceTable =
      $PlaybackPreferenceTableTable(this);
  late final $SourceAvailabilityCacheTableTable sourceAvailabilityCacheTable =
      $SourceAvailabilityCacheTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    episodeProgressTable,
    watchHistoryTable,
    playbackPreferenceTable,
    sourceAvailabilityCacheTable,
  ];
}

typedef $$EpisodeProgressTableTableCreateCompanionBuilder =
    EpisodeProgressTableCompanion Function({
      required int anilistId,
      required double episodeNumber,
      required int positionSeconds,
      Value<int?> totalDurationSeconds,
      Value<String> watchState,
      Value<String?> lastSourcePluginId,
      Value<String?> lastServerName,
      Value<String?> lastResolverPluginId,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$EpisodeProgressTableTableUpdateCompanionBuilder =
    EpisodeProgressTableCompanion Function({
      Value<int> anilistId,
      Value<double> episodeNumber,
      Value<int> positionSeconds,
      Value<int?> totalDurationSeconds,
      Value<String> watchState,
      Value<String?> lastSourcePluginId,
      Value<String?> lastServerName,
      Value<String?> lastResolverPluginId,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$EpisodeProgressTableTableFilterComposer
    extends Composer<_$AppDatabase, $EpisodeProgressTableTable> {
  $$EpisodeProgressTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get anilistId => $composableBuilder(
    column: $table.anilistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalDurationSeconds => $composableBuilder(
    column: $table.totalDurationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get watchState => $composableBuilder(
    column: $table.watchState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSourcePluginId => $composableBuilder(
    column: $table.lastSourcePluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastServerName => $composableBuilder(
    column: $table.lastServerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastResolverPluginId => $composableBuilder(
    column: $table.lastResolverPluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EpisodeProgressTableTableOrderingComposer
    extends Composer<_$AppDatabase, $EpisodeProgressTableTable> {
  $$EpisodeProgressTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get anilistId => $composableBuilder(
    column: $table.anilistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalDurationSeconds => $composableBuilder(
    column: $table.totalDurationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get watchState => $composableBuilder(
    column: $table.watchState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSourcePluginId => $composableBuilder(
    column: $table.lastSourcePluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastServerName => $composableBuilder(
    column: $table.lastServerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastResolverPluginId => $composableBuilder(
    column: $table.lastResolverPluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EpisodeProgressTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpisodeProgressTableTable> {
  $$EpisodeProgressTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get anilistId =>
      $composableBuilder(column: $table.anilistId, builder: (column) => column);

  GeneratedColumn<double> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalDurationSeconds => $composableBuilder(
    column: $table.totalDurationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get watchState => $composableBuilder(
    column: $table.watchState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSourcePluginId => $composableBuilder(
    column: $table.lastSourcePluginId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastServerName => $composableBuilder(
    column: $table.lastServerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastResolverPluginId => $composableBuilder(
    column: $table.lastResolverPluginId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EpisodeProgressTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpisodeProgressTableTable,
          EpisodeProgressTableData,
          $$EpisodeProgressTableTableFilterComposer,
          $$EpisodeProgressTableTableOrderingComposer,
          $$EpisodeProgressTableTableAnnotationComposer,
          $$EpisodeProgressTableTableCreateCompanionBuilder,
          $$EpisodeProgressTableTableUpdateCompanionBuilder,
          (
            EpisodeProgressTableData,
            BaseReferences<
              _$AppDatabase,
              $EpisodeProgressTableTable,
              EpisodeProgressTableData
            >,
          ),
          EpisodeProgressTableData,
          PrefetchHooks Function()
        > {
  $$EpisodeProgressTableTableTableManager(
    _$AppDatabase db,
    $EpisodeProgressTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodeProgressTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodeProgressTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$EpisodeProgressTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                Value<double> episodeNumber = const Value.absent(),
                Value<int> positionSeconds = const Value.absent(),
                Value<int?> totalDurationSeconds = const Value.absent(),
                Value<String> watchState = const Value.absent(),
                Value<String?> lastSourcePluginId = const Value.absent(),
                Value<String?> lastServerName = const Value.absent(),
                Value<String?> lastResolverPluginId = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpisodeProgressTableCompanion(
                anilistId: anilistId,
                episodeNumber: episodeNumber,
                positionSeconds: positionSeconds,
                totalDurationSeconds: totalDurationSeconds,
                watchState: watchState,
                lastSourcePluginId: lastSourcePluginId,
                lastServerName: lastServerName,
                lastResolverPluginId: lastResolverPluginId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int anilistId,
                required double episodeNumber,
                required int positionSeconds,
                Value<int?> totalDurationSeconds = const Value.absent(),
                Value<String> watchState = const Value.absent(),
                Value<String?> lastSourcePluginId = const Value.absent(),
                Value<String?> lastServerName = const Value.absent(),
                Value<String?> lastResolverPluginId = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => EpisodeProgressTableCompanion.insert(
                anilistId: anilistId,
                episodeNumber: episodeNumber,
                positionSeconds: positionSeconds,
                totalDurationSeconds: totalDurationSeconds,
                watchState: watchState,
                lastSourcePluginId: lastSourcePluginId,
                lastServerName: lastServerName,
                lastResolverPluginId: lastResolverPluginId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EpisodeProgressTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpisodeProgressTableTable,
      EpisodeProgressTableData,
      $$EpisodeProgressTableTableFilterComposer,
      $$EpisodeProgressTableTableOrderingComposer,
      $$EpisodeProgressTableTableAnnotationComposer,
      $$EpisodeProgressTableTableCreateCompanionBuilder,
      $$EpisodeProgressTableTableUpdateCompanionBuilder,
      (
        EpisodeProgressTableData,
        BaseReferences<
          _$AppDatabase,
          $EpisodeProgressTableTable,
          EpisodeProgressTableData
        >,
      ),
      EpisodeProgressTableData,
      PrefetchHooks Function()
    >;
typedef $$WatchHistoryTableTableCreateCompanionBuilder =
    WatchHistoryTableCompanion Function({
      Value<int> anilistId,
      required double lastEpisodeNumber,
      Value<String?> lastSourcePluginId,
      required int lastAccessedAt,
    });
typedef $$WatchHistoryTableTableUpdateCompanionBuilder =
    WatchHistoryTableCompanion Function({
      Value<int> anilistId,
      Value<double> lastEpisodeNumber,
      Value<String?> lastSourcePluginId,
      Value<int> lastAccessedAt,
    });

class $$WatchHistoryTableTableFilterComposer
    extends Composer<_$AppDatabase, $WatchHistoryTableTable> {
  $$WatchHistoryTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get anilistId => $composableBuilder(
    column: $table.anilistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lastEpisodeNumber => $composableBuilder(
    column: $table.lastEpisodeNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSourcePluginId => $composableBuilder(
    column: $table.lastSourcePluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WatchHistoryTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchHistoryTableTable> {
  $$WatchHistoryTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get anilistId => $composableBuilder(
    column: $table.anilistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lastEpisodeNumber => $composableBuilder(
    column: $table.lastEpisodeNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSourcePluginId => $composableBuilder(
    column: $table.lastSourcePluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchHistoryTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchHistoryTableTable> {
  $$WatchHistoryTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get anilistId =>
      $composableBuilder(column: $table.anilistId, builder: (column) => column);

  GeneratedColumn<double> get lastEpisodeNumber => $composableBuilder(
    column: $table.lastEpisodeNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSourcePluginId => $composableBuilder(
    column: $table.lastSourcePluginId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => column,
  );
}

class $$WatchHistoryTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchHistoryTableTable,
          WatchHistoryTableData,
          $$WatchHistoryTableTableFilterComposer,
          $$WatchHistoryTableTableOrderingComposer,
          $$WatchHistoryTableTableAnnotationComposer,
          $$WatchHistoryTableTableCreateCompanionBuilder,
          $$WatchHistoryTableTableUpdateCompanionBuilder,
          (
            WatchHistoryTableData,
            BaseReferences<
              _$AppDatabase,
              $WatchHistoryTableTable,
              WatchHistoryTableData
            >,
          ),
          WatchHistoryTableData,
          PrefetchHooks Function()
        > {
  $$WatchHistoryTableTableTableManager(
    _$AppDatabase db,
    $WatchHistoryTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchHistoryTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchHistoryTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchHistoryTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                Value<double> lastEpisodeNumber = const Value.absent(),
                Value<String?> lastSourcePluginId = const Value.absent(),
                Value<int> lastAccessedAt = const Value.absent(),
              }) => WatchHistoryTableCompanion(
                anilistId: anilistId,
                lastEpisodeNumber: lastEpisodeNumber,
                lastSourcePluginId: lastSourcePluginId,
                lastAccessedAt: lastAccessedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                required double lastEpisodeNumber,
                Value<String?> lastSourcePluginId = const Value.absent(),
                required int lastAccessedAt,
              }) => WatchHistoryTableCompanion.insert(
                anilistId: anilistId,
                lastEpisodeNumber: lastEpisodeNumber,
                lastSourcePluginId: lastSourcePluginId,
                lastAccessedAt: lastAccessedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WatchHistoryTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchHistoryTableTable,
      WatchHistoryTableData,
      $$WatchHistoryTableTableFilterComposer,
      $$WatchHistoryTableTableOrderingComposer,
      $$WatchHistoryTableTableAnnotationComposer,
      $$WatchHistoryTableTableCreateCompanionBuilder,
      $$WatchHistoryTableTableUpdateCompanionBuilder,
      (
        WatchHistoryTableData,
        BaseReferences<
          _$AppDatabase,
          $WatchHistoryTableTable,
          WatchHistoryTableData
        >,
      ),
      WatchHistoryTableData,
      PrefetchHooks Function()
    >;
typedef $$PlaybackPreferenceTableTableCreateCompanionBuilder =
    PlaybackPreferenceTableCompanion Function({
      Value<int> anilistId,
      Value<String?> preferredSourcePluginId,
      Value<String?> preferredServerName,
      Value<String?> preferredResolverPluginId,
      Value<String?> preferredAudioPreference,
      required int updatedAt,
    });
typedef $$PlaybackPreferenceTableTableUpdateCompanionBuilder =
    PlaybackPreferenceTableCompanion Function({
      Value<int> anilistId,
      Value<String?> preferredSourcePluginId,
      Value<String?> preferredServerName,
      Value<String?> preferredResolverPluginId,
      Value<String?> preferredAudioPreference,
      Value<int> updatedAt,
    });

class $$PlaybackPreferenceTableTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackPreferenceTableTable> {
  $$PlaybackPreferenceTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get anilistId => $composableBuilder(
    column: $table.anilistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredSourcePluginId => $composableBuilder(
    column: $table.preferredSourcePluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredServerName => $composableBuilder(
    column: $table.preferredServerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredResolverPluginId => $composableBuilder(
    column: $table.preferredResolverPluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredAudioPreference => $composableBuilder(
    column: $table.preferredAudioPreference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaybackPreferenceTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackPreferenceTableTable> {
  $$PlaybackPreferenceTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get anilistId => $composableBuilder(
    column: $table.anilistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredSourcePluginId => $composableBuilder(
    column: $table.preferredSourcePluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredServerName => $composableBuilder(
    column: $table.preferredServerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredResolverPluginId => $composableBuilder(
    column: $table.preferredResolverPluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredAudioPreference => $composableBuilder(
    column: $table.preferredAudioPreference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackPreferenceTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackPreferenceTableTable> {
  $$PlaybackPreferenceTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get anilistId =>
      $composableBuilder(column: $table.anilistId, builder: (column) => column);

  GeneratedColumn<String> get preferredSourcePluginId => $composableBuilder(
    column: $table.preferredSourcePluginId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredServerName => $composableBuilder(
    column: $table.preferredServerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredResolverPluginId => $composableBuilder(
    column: $table.preferredResolverPluginId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredAudioPreference => $composableBuilder(
    column: $table.preferredAudioPreference,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlaybackPreferenceTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackPreferenceTableTable,
          PlaybackPreferenceTableData,
          $$PlaybackPreferenceTableTableFilterComposer,
          $$PlaybackPreferenceTableTableOrderingComposer,
          $$PlaybackPreferenceTableTableAnnotationComposer,
          $$PlaybackPreferenceTableTableCreateCompanionBuilder,
          $$PlaybackPreferenceTableTableUpdateCompanionBuilder,
          (
            PlaybackPreferenceTableData,
            BaseReferences<
              _$AppDatabase,
              $PlaybackPreferenceTableTable,
              PlaybackPreferenceTableData
            >,
          ),
          PlaybackPreferenceTableData,
          PrefetchHooks Function()
        > {
  $$PlaybackPreferenceTableTableTableManager(
    _$AppDatabase db,
    $PlaybackPreferenceTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackPreferenceTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PlaybackPreferenceTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PlaybackPreferenceTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                Value<String?> preferredSourcePluginId = const Value.absent(),
                Value<String?> preferredServerName = const Value.absent(),
                Value<String?> preferredResolverPluginId = const Value.absent(),
                Value<String?> preferredAudioPreference = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => PlaybackPreferenceTableCompanion(
                anilistId: anilistId,
                preferredSourcePluginId: preferredSourcePluginId,
                preferredServerName: preferredServerName,
                preferredResolverPluginId: preferredResolverPluginId,
                preferredAudioPreference: preferredAudioPreference,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                Value<String?> preferredSourcePluginId = const Value.absent(),
                Value<String?> preferredServerName = const Value.absent(),
                Value<String?> preferredResolverPluginId = const Value.absent(),
                Value<String?> preferredAudioPreference = const Value.absent(),
                required int updatedAt,
              }) => PlaybackPreferenceTableCompanion.insert(
                anilistId: anilistId,
                preferredSourcePluginId: preferredSourcePluginId,
                preferredServerName: preferredServerName,
                preferredResolverPluginId: preferredResolverPluginId,
                preferredAudioPreference: preferredAudioPreference,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaybackPreferenceTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackPreferenceTableTable,
      PlaybackPreferenceTableData,
      $$PlaybackPreferenceTableTableFilterComposer,
      $$PlaybackPreferenceTableTableOrderingComposer,
      $$PlaybackPreferenceTableTableAnnotationComposer,
      $$PlaybackPreferenceTableTableCreateCompanionBuilder,
      $$PlaybackPreferenceTableTableUpdateCompanionBuilder,
      (
        PlaybackPreferenceTableData,
        BaseReferences<
          _$AppDatabase,
          $PlaybackPreferenceTableTable,
          PlaybackPreferenceTableData
        >,
      ),
      PlaybackPreferenceTableData,
      PrefetchHooks Function()
    >;
typedef $$SourceAvailabilityCacheTableTableCreateCompanionBuilder =
    SourceAvailabilityCacheTableCompanion Function({
      required int anilistId,
      required String sourcePluginId,
      required String payloadJson,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$SourceAvailabilityCacheTableTableUpdateCompanionBuilder =
    SourceAvailabilityCacheTableCompanion Function({
      Value<int> anilistId,
      Value<String> sourcePluginId,
      Value<String> payloadJson,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$SourceAvailabilityCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $SourceAvailabilityCacheTableTable> {
  $$SourceAvailabilityCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get anilistId => $composableBuilder(
    column: $table.anilistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePluginId => $composableBuilder(
    column: $table.sourcePluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SourceAvailabilityCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SourceAvailabilityCacheTableTable> {
  $$SourceAvailabilityCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get anilistId => $composableBuilder(
    column: $table.anilistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePluginId => $composableBuilder(
    column: $table.sourcePluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SourceAvailabilityCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SourceAvailabilityCacheTableTable> {
  $$SourceAvailabilityCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get anilistId =>
      $composableBuilder(column: $table.anilistId, builder: (column) => column);

  GeneratedColumn<String> get sourcePluginId => $composableBuilder(
    column: $table.sourcePluginId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SourceAvailabilityCacheTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SourceAvailabilityCacheTableTable,
          SourceAvailabilityCacheTableData,
          $$SourceAvailabilityCacheTableTableFilterComposer,
          $$SourceAvailabilityCacheTableTableOrderingComposer,
          $$SourceAvailabilityCacheTableTableAnnotationComposer,
          $$SourceAvailabilityCacheTableTableCreateCompanionBuilder,
          $$SourceAvailabilityCacheTableTableUpdateCompanionBuilder,
          (
            SourceAvailabilityCacheTableData,
            BaseReferences<
              _$AppDatabase,
              $SourceAvailabilityCacheTableTable,
              SourceAvailabilityCacheTableData
            >,
          ),
          SourceAvailabilityCacheTableData,
          PrefetchHooks Function()
        > {
  $$SourceAvailabilityCacheTableTableTableManager(
    _$AppDatabase db,
    $SourceAvailabilityCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourceAvailabilityCacheTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SourceAvailabilityCacheTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SourceAvailabilityCacheTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                Value<String> sourcePluginId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourceAvailabilityCacheTableCompanion(
                anilistId: anilistId,
                sourcePluginId: sourcePluginId,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int anilistId,
                required String sourcePluginId,
                required String payloadJson,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SourceAvailabilityCacheTableCompanion.insert(
                anilistId: anilistId,
                sourcePluginId: sourcePluginId,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SourceAvailabilityCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SourceAvailabilityCacheTableTable,
      SourceAvailabilityCacheTableData,
      $$SourceAvailabilityCacheTableTableFilterComposer,
      $$SourceAvailabilityCacheTableTableOrderingComposer,
      $$SourceAvailabilityCacheTableTableAnnotationComposer,
      $$SourceAvailabilityCacheTableTableCreateCompanionBuilder,
      $$SourceAvailabilityCacheTableTableUpdateCompanionBuilder,
      (
        SourceAvailabilityCacheTableData,
        BaseReferences<
          _$AppDatabase,
          $SourceAvailabilityCacheTableTable,
          SourceAvailabilityCacheTableData
        >,
      ),
      SourceAvailabilityCacheTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EpisodeProgressTableTableTableManager get episodeProgressTable =>
      $$EpisodeProgressTableTableTableManager(_db, _db.episodeProgressTable);
  $$WatchHistoryTableTableTableManager get watchHistoryTable =>
      $$WatchHistoryTableTableTableManager(_db, _db.watchHistoryTable);
  $$PlaybackPreferenceTableTableTableManager get playbackPreferenceTable =>
      $$PlaybackPreferenceTableTableTableManager(
        _db,
        _db.playbackPreferenceTable,
      );
  $$SourceAvailabilityCacheTableTableTableManager
  get sourceAvailabilityCacheTable =>
      $$SourceAvailabilityCacheTableTableTableManager(
        _db,
        _db.sourceAvailabilityCacheTable,
      );
}
