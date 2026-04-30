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
  static const VerificationMeta _lastPositionSecondsMeta =
      const VerificationMeta('lastPositionSeconds');
  @override
  late final GeneratedColumn<int> lastPositionSeconds = GeneratedColumn<int>(
    'last_position_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastTotalDurationSecondsMeta =
      const VerificationMeta('lastTotalDurationSeconds');
  @override
  late final GeneratedColumn<int> lastTotalDurationSeconds =
      GeneratedColumn<int>(
        'last_total_duration_seconds',
        aliasedName,
        true,
        type: DriftSqlType.int,
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
    lastPositionSeconds,
    lastTotalDurationSeconds,
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
    if (data.containsKey('last_position_seconds')) {
      context.handle(
        _lastPositionSecondsMeta,
        lastPositionSeconds.isAcceptableOrUnknown(
          data['last_position_seconds']!,
          _lastPositionSecondsMeta,
        ),
      );
    }
    if (data.containsKey('last_total_duration_seconds')) {
      context.handle(
        _lastTotalDurationSecondsMeta,
        lastTotalDurationSeconds.isAcceptableOrUnknown(
          data['last_total_duration_seconds']!,
          _lastTotalDurationSecondsMeta,
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
      lastPositionSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_position_seconds'],
      )!,
      lastTotalDurationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_total_duration_seconds'],
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
  final int lastPositionSeconds;
  final int? lastTotalDurationSeconds;
  final int lastAccessedAt;
  const WatchHistoryTableData({
    required this.anilistId,
    required this.lastEpisodeNumber,
    this.lastSourcePluginId,
    required this.lastPositionSeconds,
    this.lastTotalDurationSeconds,
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
    map['last_position_seconds'] = Variable<int>(lastPositionSeconds);
    if (!nullToAbsent || lastTotalDurationSeconds != null) {
      map['last_total_duration_seconds'] = Variable<int>(
        lastTotalDurationSeconds,
      );
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
      lastPositionSeconds: Value(lastPositionSeconds),
      lastTotalDurationSeconds: lastTotalDurationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(lastTotalDurationSeconds),
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
      lastPositionSeconds: serializer.fromJson<int>(
        json['lastPositionSeconds'],
      ),
      lastTotalDurationSeconds: serializer.fromJson<int?>(
        json['lastTotalDurationSeconds'],
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
      'lastPositionSeconds': serializer.toJson<int>(lastPositionSeconds),
      'lastTotalDurationSeconds': serializer.toJson<int?>(
        lastTotalDurationSeconds,
      ),
      'lastAccessedAt': serializer.toJson<int>(lastAccessedAt),
    };
  }

  WatchHistoryTableData copyWith({
    int? anilistId,
    double? lastEpisodeNumber,
    Value<String?> lastSourcePluginId = const Value.absent(),
    int? lastPositionSeconds,
    Value<int?> lastTotalDurationSeconds = const Value.absent(),
    int? lastAccessedAt,
  }) => WatchHistoryTableData(
    anilistId: anilistId ?? this.anilistId,
    lastEpisodeNumber: lastEpisodeNumber ?? this.lastEpisodeNumber,
    lastSourcePluginId: lastSourcePluginId.present
        ? lastSourcePluginId.value
        : this.lastSourcePluginId,
    lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
    lastTotalDurationSeconds: lastTotalDurationSeconds.present
        ? lastTotalDurationSeconds.value
        : this.lastTotalDurationSeconds,
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
      lastPositionSeconds: data.lastPositionSeconds.present
          ? data.lastPositionSeconds.value
          : this.lastPositionSeconds,
      lastTotalDurationSeconds: data.lastTotalDurationSeconds.present
          ? data.lastTotalDurationSeconds.value
          : this.lastTotalDurationSeconds,
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
          ..write('lastPositionSeconds: $lastPositionSeconds, ')
          ..write('lastTotalDurationSeconds: $lastTotalDurationSeconds, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    anilistId,
    lastEpisodeNumber,
    lastSourcePluginId,
    lastPositionSeconds,
    lastTotalDurationSeconds,
    lastAccessedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchHistoryTableData &&
          other.anilistId == this.anilistId &&
          other.lastEpisodeNumber == this.lastEpisodeNumber &&
          other.lastSourcePluginId == this.lastSourcePluginId &&
          other.lastPositionSeconds == this.lastPositionSeconds &&
          other.lastTotalDurationSeconds == this.lastTotalDurationSeconds &&
          other.lastAccessedAt == this.lastAccessedAt);
}

class WatchHistoryTableCompanion
    extends UpdateCompanion<WatchHistoryTableData> {
  final Value<int> anilistId;
  final Value<double> lastEpisodeNumber;
  final Value<String?> lastSourcePluginId;
  final Value<int> lastPositionSeconds;
  final Value<int?> lastTotalDurationSeconds;
  final Value<int> lastAccessedAt;
  const WatchHistoryTableCompanion({
    this.anilistId = const Value.absent(),
    this.lastEpisodeNumber = const Value.absent(),
    this.lastSourcePluginId = const Value.absent(),
    this.lastPositionSeconds = const Value.absent(),
    this.lastTotalDurationSeconds = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
  });
  WatchHistoryTableCompanion.insert({
    this.anilistId = const Value.absent(),
    required double lastEpisodeNumber,
    this.lastSourcePluginId = const Value.absent(),
    this.lastPositionSeconds = const Value.absent(),
    this.lastTotalDurationSeconds = const Value.absent(),
    required int lastAccessedAt,
  }) : lastEpisodeNumber = Value(lastEpisodeNumber),
       lastAccessedAt = Value(lastAccessedAt);
  static Insertable<WatchHistoryTableData> custom({
    Expression<int>? anilistId,
    Expression<double>? lastEpisodeNumber,
    Expression<String>? lastSourcePluginId,
    Expression<int>? lastPositionSeconds,
    Expression<int>? lastTotalDurationSeconds,
    Expression<int>? lastAccessedAt,
  }) {
    return RawValuesInsertable({
      if (anilistId != null) 'anilist_id': anilistId,
      if (lastEpisodeNumber != null) 'last_episode_number': lastEpisodeNumber,
      if (lastSourcePluginId != null)
        'last_source_plugin_id': lastSourcePluginId,
      if (lastPositionSeconds != null)
        'last_position_seconds': lastPositionSeconds,
      if (lastTotalDurationSeconds != null)
        'last_total_duration_seconds': lastTotalDurationSeconds,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
    });
  }

  WatchHistoryTableCompanion copyWith({
    Value<int>? anilistId,
    Value<double>? lastEpisodeNumber,
    Value<String?>? lastSourcePluginId,
    Value<int>? lastPositionSeconds,
    Value<int?>? lastTotalDurationSeconds,
    Value<int>? lastAccessedAt,
  }) {
    return WatchHistoryTableCompanion(
      anilistId: anilistId ?? this.anilistId,
      lastEpisodeNumber: lastEpisodeNumber ?? this.lastEpisodeNumber,
      lastSourcePluginId: lastSourcePluginId ?? this.lastSourcePluginId,
      lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
      lastTotalDurationSeconds:
          lastTotalDurationSeconds ?? this.lastTotalDurationSeconds,
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
    if (lastPositionSeconds.present) {
      map['last_position_seconds'] = Variable<int>(lastPositionSeconds.value);
    }
    if (lastTotalDurationSeconds.present) {
      map['last_total_duration_seconds'] = Variable<int>(
        lastTotalDurationSeconds.value,
      );
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
          ..write('lastPositionSeconds: $lastPositionSeconds, ')
          ..write('lastTotalDurationSeconds: $lastTotalDurationSeconds, ')
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

class $AniSkipCacheTableTable extends AniSkipCacheTable
    with TableInfo<$AniSkipCacheTableTable, AniSkipCacheTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AniSkipCacheTableTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumn<int> episodeNumber = GeneratedColumn<int>(
    'episode_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _requestedEpisodeLengthSecondsMeta =
      const VerificationMeta('requestedEpisodeLengthSeconds');
  @override
  late final GeneratedColumn<int> requestedEpisodeLengthSeconds =
      GeneratedColumn<int>(
        'requested_episode_length_seconds',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    anilistId,
    episodeNumber,
    payloadJson,
    updatedAt,
    requestedEpisodeLengthSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'aniskip_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<AniSkipCacheTableData> instance, {
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
    if (data.containsKey('requested_episode_length_seconds')) {
      context.handle(
        _requestedEpisodeLengthSecondsMeta,
        requestedEpisodeLengthSeconds.isAcceptableOrUnknown(
          data['requested_episode_length_seconds']!,
          _requestedEpisodeLengthSecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {anilistId, episodeNumber};
  @override
  AniSkipCacheTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AniSkipCacheTableData(
      anilistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anilist_id'],
      )!,
      episodeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_number'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      requestedEpisodeLengthSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}requested_episode_length_seconds'],
      ),
    );
  }

  @override
  $AniSkipCacheTableTable createAlias(String alias) {
    return $AniSkipCacheTableTable(attachedDatabase, alias);
  }
}

class AniSkipCacheTableData extends DataClass
    implements Insertable<AniSkipCacheTableData> {
  final int anilistId;
  final int episodeNumber;
  final String payloadJson;
  final int updatedAt;
  final int? requestedEpisodeLengthSeconds;
  const AniSkipCacheTableData({
    required this.anilistId,
    required this.episodeNumber,
    required this.payloadJson,
    required this.updatedAt,
    this.requestedEpisodeLengthSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anilist_id'] = Variable<int>(anilistId);
    map['episode_number'] = Variable<int>(episodeNumber);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || requestedEpisodeLengthSeconds != null) {
      map['requested_episode_length_seconds'] = Variable<int>(
        requestedEpisodeLengthSeconds,
      );
    }
    return map;
  }

  AniSkipCacheTableCompanion toCompanion(bool nullToAbsent) {
    return AniSkipCacheTableCompanion(
      anilistId: Value(anilistId),
      episodeNumber: Value(episodeNumber),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
      requestedEpisodeLengthSeconds:
          requestedEpisodeLengthSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(requestedEpisodeLengthSeconds),
    );
  }

  factory AniSkipCacheTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AniSkipCacheTableData(
      anilistId: serializer.fromJson<int>(json['anilistId']),
      episodeNumber: serializer.fromJson<int>(json['episodeNumber']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      requestedEpisodeLengthSeconds: serializer.fromJson<int?>(
        json['requestedEpisodeLengthSeconds'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'anilistId': serializer.toJson<int>(anilistId),
      'episodeNumber': serializer.toJson<int>(episodeNumber),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'requestedEpisodeLengthSeconds': serializer.toJson<int?>(
        requestedEpisodeLengthSeconds,
      ),
    };
  }

  AniSkipCacheTableData copyWith({
    int? anilistId,
    int? episodeNumber,
    String? payloadJson,
    int? updatedAt,
    Value<int?> requestedEpisodeLengthSeconds = const Value.absent(),
  }) => AniSkipCacheTableData(
    anilistId: anilistId ?? this.anilistId,
    episodeNumber: episodeNumber ?? this.episodeNumber,
    payloadJson: payloadJson ?? this.payloadJson,
    updatedAt: updatedAt ?? this.updatedAt,
    requestedEpisodeLengthSeconds: requestedEpisodeLengthSeconds.present
        ? requestedEpisodeLengthSeconds.value
        : this.requestedEpisodeLengthSeconds,
  );
  AniSkipCacheTableData copyWithCompanion(AniSkipCacheTableCompanion data) {
    return AniSkipCacheTableData(
      anilistId: data.anilistId.present ? data.anilistId.value : this.anilistId,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      requestedEpisodeLengthSeconds: data.requestedEpisodeLengthSeconds.present
          ? data.requestedEpisodeLengthSeconds.value
          : this.requestedEpisodeLengthSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AniSkipCacheTableData(')
          ..write('anilistId: $anilistId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write(
            'requestedEpisodeLengthSeconds: $requestedEpisodeLengthSeconds',
          )
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    anilistId,
    episodeNumber,
    payloadJson,
    updatedAt,
    requestedEpisodeLengthSeconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AniSkipCacheTableData &&
          other.anilistId == this.anilistId &&
          other.episodeNumber == this.episodeNumber &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt &&
          other.requestedEpisodeLengthSeconds ==
              this.requestedEpisodeLengthSeconds);
}

class AniSkipCacheTableCompanion
    extends UpdateCompanion<AniSkipCacheTableData> {
  final Value<int> anilistId;
  final Value<int> episodeNumber;
  final Value<String> payloadJson;
  final Value<int> updatedAt;
  final Value<int?> requestedEpisodeLengthSeconds;
  final Value<int> rowid;
  const AniSkipCacheTableCompanion({
    this.anilistId = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.requestedEpisodeLengthSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AniSkipCacheTableCompanion.insert({
    required int anilistId,
    required int episodeNumber,
    required String payloadJson,
    required int updatedAt,
    this.requestedEpisodeLengthSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : anilistId = Value(anilistId),
       episodeNumber = Value(episodeNumber),
       payloadJson = Value(payloadJson),
       updatedAt = Value(updatedAt);
  static Insertable<AniSkipCacheTableData> custom({
    Expression<int>? anilistId,
    Expression<int>? episodeNumber,
    Expression<String>? payloadJson,
    Expression<int>? updatedAt,
    Expression<int>? requestedEpisodeLengthSeconds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (anilistId != null) 'anilist_id': anilistId,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (requestedEpisodeLengthSeconds != null)
        'requested_episode_length_seconds': requestedEpisodeLengthSeconds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AniSkipCacheTableCompanion copyWith({
    Value<int>? anilistId,
    Value<int>? episodeNumber,
    Value<String>? payloadJson,
    Value<int>? updatedAt,
    Value<int?>? requestedEpisodeLengthSeconds,
    Value<int>? rowid,
  }) {
    return AniSkipCacheTableCompanion(
      anilistId: anilistId ?? this.anilistId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      requestedEpisodeLengthSeconds:
          requestedEpisodeLengthSeconds ?? this.requestedEpisodeLengthSeconds,
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
      map['episode_number'] = Variable<int>(episodeNumber.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (requestedEpisodeLengthSeconds.present) {
      map['requested_episode_length_seconds'] = Variable<int>(
        requestedEpisodeLengthSeconds.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AniSkipCacheTableCompanion(')
          ..write('anilistId: $anilistId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write(
            'requestedEpisodeLengthSeconds: $requestedEpisodeLengthSeconds, ',
          )
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadTaskTableTable extends DownloadTaskTable
    with TableInfo<$DownloadTaskTableTable, DownloadTaskTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadTaskTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
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
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
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
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedBytesMeta = const VerificationMeta(
    'downloadedBytes',
  );
  @override
  late final GeneratedColumn<int> downloadedBytes = GeneratedColumn<int>(
    'downloaded_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourcePluginIdMeta = const VerificationMeta(
    'sourcePluginId',
  );
  @override
  late final GeneratedColumn<String> sourcePluginId = GeneratedColumn<String>(
    'source_plugin_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverNameMeta = const VerificationMeta(
    'serverName',
  );
  @override
  late final GeneratedColumn<String> serverName = GeneratedColumn<String>(
    'server_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detectedHostMeta = const VerificationMeta(
    'detectedHost',
  );
  @override
  late final GeneratedColumn<String> detectedHost = GeneratedColumn<String>(
    'detected_host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
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
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _headersMeta = const VerificationMeta(
    'headers',
  );
  @override
  late final GeneratedColumn<String> headers = GeneratedColumn<String>(
    'headers',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isHlsMeta = const VerificationMeta('isHls');
  @override
  late final GeneratedColumn<bool> isHls = GeneratedColumn<bool>(
    'is_hls',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_hls" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _animeTitleMeta = const VerificationMeta(
    'animeTitle',
  );
  @override
  late final GeneratedColumn<String> animeTitle = GeneratedColumn<String>(
    'anime_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _qualityLabelMeta = const VerificationMeta(
    'qualityLabel',
  );
  @override
  late final GeneratedColumn<String> qualityLabel = GeneratedColumn<String>(
    'quality_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeTitleMeta = const VerificationMeta(
    'episodeTitle',
  );
  @override
  late final GeneratedColumn<String> episodeTitle = GeneratedColumn<String>(
    'episode_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    anilistId,
    episodeNumber,
    sourceUrl,
    status,
    fileName,
    filePath,
    totalBytes,
    downloadedBytes,
    sourcePluginId,
    serverName,
    detectedHost,
    errorMessage,
    createdAt,
    updatedAt,
    headers,
    isHls,
    animeTitle,
    qualityLabel,
    episodeTitle,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_task';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadTaskTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
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
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('downloaded_bytes')) {
      context.handle(
        _downloadedBytesMeta,
        downloadedBytes.isAcceptableOrUnknown(
          data['downloaded_bytes']!,
          _downloadedBytesMeta,
        ),
      );
    }
    if (data.containsKey('source_plugin_id')) {
      context.handle(
        _sourcePluginIdMeta,
        sourcePluginId.isAcceptableOrUnknown(
          data['source_plugin_id']!,
          _sourcePluginIdMeta,
        ),
      );
    }
    if (data.containsKey('server_name')) {
      context.handle(
        _serverNameMeta,
        serverName.isAcceptableOrUnknown(data['server_name']!, _serverNameMeta),
      );
    }
    if (data.containsKey('detected_host')) {
      context.handle(
        _detectedHostMeta,
        detectedHost.isAcceptableOrUnknown(
          data['detected_host']!,
          _detectedHostMeta,
        ),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
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
    }
    if (data.containsKey('headers')) {
      context.handle(
        _headersMeta,
        headers.isAcceptableOrUnknown(data['headers']!, _headersMeta),
      );
    }
    if (data.containsKey('is_hls')) {
      context.handle(
        _isHlsMeta,
        isHls.isAcceptableOrUnknown(data['is_hls']!, _isHlsMeta),
      );
    }
    if (data.containsKey('anime_title')) {
      context.handle(
        _animeTitleMeta,
        animeTitle.isAcceptableOrUnknown(data['anime_title']!, _animeTitleMeta),
      );
    }
    if (data.containsKey('quality_label')) {
      context.handle(
        _qualityLabelMeta,
        qualityLabel.isAcceptableOrUnknown(
          data['quality_label']!,
          _qualityLabelMeta,
        ),
      );
    }
    if (data.containsKey('episode_title')) {
      context.handle(
        _episodeTitleMeta,
        episodeTitle.isAcceptableOrUnknown(
          data['episode_title']!,
          _episodeTitleMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadTaskTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadTaskTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      anilistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anilist_id'],
      )!,
      episodeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}episode_number'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      ),
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      ),
      downloadedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_bytes'],
      ),
      sourcePluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_plugin_id'],
      ),
      serverName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_name'],
      ),
      detectedHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detected_host'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      ),
      headers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headers'],
      ),
      isHls: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_hls'],
      ),
      animeTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}anime_title'],
      ),
      qualityLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quality_label'],
      ),
      episodeTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_title'],
      ),
    );
  }

  @override
  $DownloadTaskTableTable createAlias(String alias) {
    return $DownloadTaskTableTable(attachedDatabase, alias);
  }
}

class DownloadTaskTableData extends DataClass
    implements Insertable<DownloadTaskTableData> {
  final String id;
  final int anilistId;
  final double episodeNumber;
  final String sourceUrl;
  final String status;
  final String? fileName;
  final String? filePath;
  final int? totalBytes;
  final int? downloadedBytes;
  final String? sourcePluginId;
  final String? serverName;
  final String? detectedHost;
  final String? errorMessage;
  final int createdAt;
  final int? updatedAt;

  /// JSON-encoded `Map<String, String>` of HTTP headers (referer, origin, etc.)
  final String? headers;

  /// Whether this download is an HLS stream requiring segment download.
  final bool? isHls;

  /// Human-readable anime title (used for folder name and UI).
  final String? animeTitle;

  /// Stream quality label (e.g. "1080p", "720p").
  final String? qualityLabel;

  /// Human-readable episode title from the source.
  final String? episodeTitle;
  const DownloadTaskTableData({
    required this.id,
    required this.anilistId,
    required this.episodeNumber,
    required this.sourceUrl,
    required this.status,
    this.fileName,
    this.filePath,
    this.totalBytes,
    this.downloadedBytes,
    this.sourcePluginId,
    this.serverName,
    this.detectedHost,
    this.errorMessage,
    required this.createdAt,
    this.updatedAt,
    this.headers,
    this.isHls,
    this.animeTitle,
    this.qualityLabel,
    this.episodeTitle,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['anilist_id'] = Variable<int>(anilistId);
    map['episode_number'] = Variable<double>(episodeNumber);
    map['source_url'] = Variable<String>(sourceUrl);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || fileName != null) {
      map['file_name'] = Variable<String>(fileName);
    }
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || totalBytes != null) {
      map['total_bytes'] = Variable<int>(totalBytes);
    }
    if (!nullToAbsent || downloadedBytes != null) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes);
    }
    if (!nullToAbsent || sourcePluginId != null) {
      map['source_plugin_id'] = Variable<String>(sourcePluginId);
    }
    if (!nullToAbsent || serverName != null) {
      map['server_name'] = Variable<String>(serverName);
    }
    if (!nullToAbsent || detectedHost != null) {
      map['detected_host'] = Variable<String>(detectedHost);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    if (!nullToAbsent || headers != null) {
      map['headers'] = Variable<String>(headers);
    }
    if (!nullToAbsent || isHls != null) {
      map['is_hls'] = Variable<bool>(isHls);
    }
    if (!nullToAbsent || animeTitle != null) {
      map['anime_title'] = Variable<String>(animeTitle);
    }
    if (!nullToAbsent || qualityLabel != null) {
      map['quality_label'] = Variable<String>(qualityLabel);
    }
    if (!nullToAbsent || episodeTitle != null) {
      map['episode_title'] = Variable<String>(episodeTitle);
    }
    return map;
  }

  DownloadTaskTableCompanion toCompanion(bool nullToAbsent) {
    return DownloadTaskTableCompanion(
      id: Value(id),
      anilistId: Value(anilistId),
      episodeNumber: Value(episodeNumber),
      sourceUrl: Value(sourceUrl),
      status: Value(status),
      fileName: fileName == null && nullToAbsent
          ? const Value.absent()
          : Value(fileName),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      totalBytes: totalBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalBytes),
      downloadedBytes: downloadedBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedBytes),
      sourcePluginId: sourcePluginId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourcePluginId),
      serverName: serverName == null && nullToAbsent
          ? const Value.absent()
          : Value(serverName),
      detectedHost: detectedHost == null && nullToAbsent
          ? const Value.absent()
          : Value(detectedHost),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      headers: headers == null && nullToAbsent
          ? const Value.absent()
          : Value(headers),
      isHls: isHls == null && nullToAbsent
          ? const Value.absent()
          : Value(isHls),
      animeTitle: animeTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(animeTitle),
      qualityLabel: qualityLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(qualityLabel),
      episodeTitle: episodeTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeTitle),
    );
  }

  factory DownloadTaskTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadTaskTableData(
      id: serializer.fromJson<String>(json['id']),
      anilistId: serializer.fromJson<int>(json['anilistId']),
      episodeNumber: serializer.fromJson<double>(json['episodeNumber']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      status: serializer.fromJson<String>(json['status']),
      fileName: serializer.fromJson<String?>(json['fileName']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      totalBytes: serializer.fromJson<int?>(json['totalBytes']),
      downloadedBytes: serializer.fromJson<int?>(json['downloadedBytes']),
      sourcePluginId: serializer.fromJson<String?>(json['sourcePluginId']),
      serverName: serializer.fromJson<String?>(json['serverName']),
      detectedHost: serializer.fromJson<String?>(json['detectedHost']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
      headers: serializer.fromJson<String?>(json['headers']),
      isHls: serializer.fromJson<bool?>(json['isHls']),
      animeTitle: serializer.fromJson<String?>(json['animeTitle']),
      qualityLabel: serializer.fromJson<String?>(json['qualityLabel']),
      episodeTitle: serializer.fromJson<String?>(json['episodeTitle']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'anilistId': serializer.toJson<int>(anilistId),
      'episodeNumber': serializer.toJson<double>(episodeNumber),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'status': serializer.toJson<String>(status),
      'fileName': serializer.toJson<String?>(fileName),
      'filePath': serializer.toJson<String?>(filePath),
      'totalBytes': serializer.toJson<int?>(totalBytes),
      'downloadedBytes': serializer.toJson<int?>(downloadedBytes),
      'sourcePluginId': serializer.toJson<String?>(sourcePluginId),
      'serverName': serializer.toJson<String?>(serverName),
      'detectedHost': serializer.toJson<String?>(detectedHost),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int?>(updatedAt),
      'headers': serializer.toJson<String?>(headers),
      'isHls': serializer.toJson<bool?>(isHls),
      'animeTitle': serializer.toJson<String?>(animeTitle),
      'qualityLabel': serializer.toJson<String?>(qualityLabel),
      'episodeTitle': serializer.toJson<String?>(episodeTitle),
    };
  }

  DownloadTaskTableData copyWith({
    String? id,
    int? anilistId,
    double? episodeNumber,
    String? sourceUrl,
    String? status,
    Value<String?> fileName = const Value.absent(),
    Value<String?> filePath = const Value.absent(),
    Value<int?> totalBytes = const Value.absent(),
    Value<int?> downloadedBytes = const Value.absent(),
    Value<String?> sourcePluginId = const Value.absent(),
    Value<String?> serverName = const Value.absent(),
    Value<String?> detectedHost = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    int? createdAt,
    Value<int?> updatedAt = const Value.absent(),
    Value<String?> headers = const Value.absent(),
    Value<bool?> isHls = const Value.absent(),
    Value<String?> animeTitle = const Value.absent(),
    Value<String?> qualityLabel = const Value.absent(),
    Value<String?> episodeTitle = const Value.absent(),
  }) => DownloadTaskTableData(
    id: id ?? this.id,
    anilistId: anilistId ?? this.anilistId,
    episodeNumber: episodeNumber ?? this.episodeNumber,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    status: status ?? this.status,
    fileName: fileName.present ? fileName.value : this.fileName,
    filePath: filePath.present ? filePath.value : this.filePath,
    totalBytes: totalBytes.present ? totalBytes.value : this.totalBytes,
    downloadedBytes: downloadedBytes.present
        ? downloadedBytes.value
        : this.downloadedBytes,
    sourcePluginId: sourcePluginId.present
        ? sourcePluginId.value
        : this.sourcePluginId,
    serverName: serverName.present ? serverName.value : this.serverName,
    detectedHost: detectedHost.present ? detectedHost.value : this.detectedHost,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    headers: headers.present ? headers.value : this.headers,
    isHls: isHls.present ? isHls.value : this.isHls,
    animeTitle: animeTitle.present ? animeTitle.value : this.animeTitle,
    qualityLabel: qualityLabel.present ? qualityLabel.value : this.qualityLabel,
    episodeTitle: episodeTitle.present ? episodeTitle.value : this.episodeTitle,
  );
  DownloadTaskTableData copyWithCompanion(DownloadTaskTableCompanion data) {
    return DownloadTaskTableData(
      id: data.id.present ? data.id.value : this.id,
      anilistId: data.anilistId.present ? data.anilistId.value : this.anilistId,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      status: data.status.present ? data.status.value : this.status,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      downloadedBytes: data.downloadedBytes.present
          ? data.downloadedBytes.value
          : this.downloadedBytes,
      sourcePluginId: data.sourcePluginId.present
          ? data.sourcePluginId.value
          : this.sourcePluginId,
      serverName: data.serverName.present
          ? data.serverName.value
          : this.serverName,
      detectedHost: data.detectedHost.present
          ? data.detectedHost.value
          : this.detectedHost,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      headers: data.headers.present ? data.headers.value : this.headers,
      isHls: data.isHls.present ? data.isHls.value : this.isHls,
      animeTitle: data.animeTitle.present
          ? data.animeTitle.value
          : this.animeTitle,
      qualityLabel: data.qualityLabel.present
          ? data.qualityLabel.value
          : this.qualityLabel,
      episodeTitle: data.episodeTitle.present
          ? data.episodeTitle.value
          : this.episodeTitle,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTaskTableData(')
          ..write('id: $id, ')
          ..write('anilistId: $anilistId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('status: $status, ')
          ..write('fileName: $fileName, ')
          ..write('filePath: $filePath, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('sourcePluginId: $sourcePluginId, ')
          ..write('serverName: $serverName, ')
          ..write('detectedHost: $detectedHost, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('headers: $headers, ')
          ..write('isHls: $isHls, ')
          ..write('animeTitle: $animeTitle, ')
          ..write('qualityLabel: $qualityLabel, ')
          ..write('episodeTitle: $episodeTitle')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    anilistId,
    episodeNumber,
    sourceUrl,
    status,
    fileName,
    filePath,
    totalBytes,
    downloadedBytes,
    sourcePluginId,
    serverName,
    detectedHost,
    errorMessage,
    createdAt,
    updatedAt,
    headers,
    isHls,
    animeTitle,
    qualityLabel,
    episodeTitle,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadTaskTableData &&
          other.id == this.id &&
          other.anilistId == this.anilistId &&
          other.episodeNumber == this.episodeNumber &&
          other.sourceUrl == this.sourceUrl &&
          other.status == this.status &&
          other.fileName == this.fileName &&
          other.filePath == this.filePath &&
          other.totalBytes == this.totalBytes &&
          other.downloadedBytes == this.downloadedBytes &&
          other.sourcePluginId == this.sourcePluginId &&
          other.serverName == this.serverName &&
          other.detectedHost == this.detectedHost &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.headers == this.headers &&
          other.isHls == this.isHls &&
          other.animeTitle == this.animeTitle &&
          other.qualityLabel == this.qualityLabel &&
          other.episodeTitle == this.episodeTitle);
}

class DownloadTaskTableCompanion
    extends UpdateCompanion<DownloadTaskTableData> {
  final Value<String> id;
  final Value<int> anilistId;
  final Value<double> episodeNumber;
  final Value<String> sourceUrl;
  final Value<String> status;
  final Value<String?> fileName;
  final Value<String?> filePath;
  final Value<int?> totalBytes;
  final Value<int?> downloadedBytes;
  final Value<String?> sourcePluginId;
  final Value<String?> serverName;
  final Value<String?> detectedHost;
  final Value<String?> errorMessage;
  final Value<int> createdAt;
  final Value<int?> updatedAt;
  final Value<String?> headers;
  final Value<bool?> isHls;
  final Value<String?> animeTitle;
  final Value<String?> qualityLabel;
  final Value<String?> episodeTitle;
  final Value<int> rowid;
  const DownloadTaskTableCompanion({
    this.id = const Value.absent(),
    this.anilistId = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.status = const Value.absent(),
    this.fileName = const Value.absent(),
    this.filePath = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.sourcePluginId = const Value.absent(),
    this.serverName = const Value.absent(),
    this.detectedHost = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.headers = const Value.absent(),
    this.isHls = const Value.absent(),
    this.animeTitle = const Value.absent(),
    this.qualityLabel = const Value.absent(),
    this.episodeTitle = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadTaskTableCompanion.insert({
    required String id,
    required int anilistId,
    required double episodeNumber,
    required String sourceUrl,
    this.status = const Value.absent(),
    this.fileName = const Value.absent(),
    this.filePath = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.sourcePluginId = const Value.absent(),
    this.serverName = const Value.absent(),
    this.detectedHost = const Value.absent(),
    this.errorMessage = const Value.absent(),
    required int createdAt,
    this.updatedAt = const Value.absent(),
    this.headers = const Value.absent(),
    this.isHls = const Value.absent(),
    this.animeTitle = const Value.absent(),
    this.qualityLabel = const Value.absent(),
    this.episodeTitle = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       anilistId = Value(anilistId),
       episodeNumber = Value(episodeNumber),
       sourceUrl = Value(sourceUrl),
       createdAt = Value(createdAt);
  static Insertable<DownloadTaskTableData> custom({
    Expression<String>? id,
    Expression<int>? anilistId,
    Expression<double>? episodeNumber,
    Expression<String>? sourceUrl,
    Expression<String>? status,
    Expression<String>? fileName,
    Expression<String>? filePath,
    Expression<int>? totalBytes,
    Expression<int>? downloadedBytes,
    Expression<String>? sourcePluginId,
    Expression<String>? serverName,
    Expression<String>? detectedHost,
    Expression<String>? errorMessage,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? headers,
    Expression<bool>? isHls,
    Expression<String>? animeTitle,
    Expression<String>? qualityLabel,
    Expression<String>? episodeTitle,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (anilistId != null) 'anilist_id': anilistId,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (status != null) 'status': status,
      if (fileName != null) 'file_name': fileName,
      if (filePath != null) 'file_path': filePath,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (downloadedBytes != null) 'downloaded_bytes': downloadedBytes,
      if (sourcePluginId != null) 'source_plugin_id': sourcePluginId,
      if (serverName != null) 'server_name': serverName,
      if (detectedHost != null) 'detected_host': detectedHost,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (headers != null) 'headers': headers,
      if (isHls != null) 'is_hls': isHls,
      if (animeTitle != null) 'anime_title': animeTitle,
      if (qualityLabel != null) 'quality_label': qualityLabel,
      if (episodeTitle != null) 'episode_title': episodeTitle,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadTaskTableCompanion copyWith({
    Value<String>? id,
    Value<int>? anilistId,
    Value<double>? episodeNumber,
    Value<String>? sourceUrl,
    Value<String>? status,
    Value<String?>? fileName,
    Value<String?>? filePath,
    Value<int?>? totalBytes,
    Value<int?>? downloadedBytes,
    Value<String?>? sourcePluginId,
    Value<String?>? serverName,
    Value<String?>? detectedHost,
    Value<String?>? errorMessage,
    Value<int>? createdAt,
    Value<int?>? updatedAt,
    Value<String?>? headers,
    Value<bool?>? isHls,
    Value<String?>? animeTitle,
    Value<String?>? qualityLabel,
    Value<String?>? episodeTitle,
    Value<int>? rowid,
  }) {
    return DownloadTaskTableCompanion(
      id: id ?? this.id,
      anilistId: anilistId ?? this.anilistId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      status: status ?? this.status,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      sourcePluginId: sourcePluginId ?? this.sourcePluginId,
      serverName: serverName ?? this.serverName,
      detectedHost: detectedHost ?? this.detectedHost,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      headers: headers ?? this.headers,
      isHls: isHls ?? this.isHls,
      animeTitle: animeTitle ?? this.animeTitle,
      qualityLabel: qualityLabel ?? this.qualityLabel,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (anilistId.present) {
      map['anilist_id'] = Variable<int>(anilistId.value);
    }
    if (episodeNumber.present) {
      map['episode_number'] = Variable<double>(episodeNumber.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (downloadedBytes.present) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes.value);
    }
    if (sourcePluginId.present) {
      map['source_plugin_id'] = Variable<String>(sourcePluginId.value);
    }
    if (serverName.present) {
      map['server_name'] = Variable<String>(serverName.value);
    }
    if (detectedHost.present) {
      map['detected_host'] = Variable<String>(detectedHost.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (headers.present) {
      map['headers'] = Variable<String>(headers.value);
    }
    if (isHls.present) {
      map['is_hls'] = Variable<bool>(isHls.value);
    }
    if (animeTitle.present) {
      map['anime_title'] = Variable<String>(animeTitle.value);
    }
    if (qualityLabel.present) {
      map['quality_label'] = Variable<String>(qualityLabel.value);
    }
    if (episodeTitle.present) {
      map['episode_title'] = Variable<String>(episodeTitle.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTaskTableCompanion(')
          ..write('id: $id, ')
          ..write('anilistId: $anilistId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('status: $status, ')
          ..write('fileName: $fileName, ')
          ..write('filePath: $filePath, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('sourcePluginId: $sourcePluginId, ')
          ..write('serverName: $serverName, ')
          ..write('detectedHost: $detectedHost, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('headers: $headers, ')
          ..write('isHls: $isHls, ')
          ..write('animeTitle: $animeTitle, ')
          ..write('qualityLabel: $qualityLabel, ')
          ..write('episodeTitle: $episodeTitle, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HlsSegmentTableTable extends HlsSegmentTable
    with TableInfo<$HlsSegmentTableTable, HlsSegmentTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HlsSegmentTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _downloadTaskIdMeta = const VerificationMeta(
    'downloadTaskId',
  );
  @override
  late final GeneratedColumn<String> downloadTaskId = GeneratedColumn<String>(
    'download_task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _segmentIndexMeta = const VerificationMeta(
    'segmentIndex',
  );
  @override
  late final GeneratedColumn<int> segmentIndex = GeneratedColumn<int>(
    'segment_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
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
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    downloadTaskId,
    segmentIndex,
    url,
    status,
    localPath,
    byteSize,
    retryCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hls_segment';
  @override
  VerificationContext validateIntegrity(
    Insertable<HlsSegmentTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('download_task_id')) {
      context.handle(
        _downloadTaskIdMeta,
        downloadTaskId.isAcceptableOrUnknown(
          data['download_task_id']!,
          _downloadTaskIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_downloadTaskIdMeta);
    }
    if (data.containsKey('segment_index')) {
      context.handle(
        _segmentIndexMeta,
        segmentIndex.isAcceptableOrUnknown(
          data['segment_index']!,
          _segmentIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_segmentIndexMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HlsSegmentTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HlsSegmentTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      downloadTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_task_id'],
      )!,
      segmentIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment_index'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      ),
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
    );
  }

  @override
  $HlsSegmentTableTable createAlias(String alias) {
    return $HlsSegmentTableTable(attachedDatabase, alias);
  }
}

class HlsSegmentTableData extends DataClass
    implements Insertable<HlsSegmentTableData> {
  /// Deterministic ID: `{downloadTaskId}:seg:{segmentIndex}`.
  final String id;

  /// FK reference to the parent download_task.id.
  final String downloadTaskId;

  /// Zero-based position in the playlist — determines concatenation order.
  final int segmentIndex;

  /// Absolute URL of the .ts segment.
  final String url;

  /// Current status: pending | downloading | completed | failed.
  final String status;

  /// Local file path where the segment is stored.
  final String? localPath;

  /// Byte count of the downloaded segment.
  final int? byteSize;

  /// Number of failed retry attempts.
  final int retryCount;
  const HlsSegmentTableData({
    required this.id,
    required this.downloadTaskId,
    required this.segmentIndex,
    required this.url,
    required this.status,
    this.localPath,
    this.byteSize,
    required this.retryCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['download_task_id'] = Variable<String>(downloadTaskId);
    map['segment_index'] = Variable<int>(segmentIndex);
    map['url'] = Variable<String>(url);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || byteSize != null) {
      map['byte_size'] = Variable<int>(byteSize);
    }
    map['retry_count'] = Variable<int>(retryCount);
    return map;
  }

  HlsSegmentTableCompanion toCompanion(bool nullToAbsent) {
    return HlsSegmentTableCompanion(
      id: Value(id),
      downloadTaskId: Value(downloadTaskId),
      segmentIndex: Value(segmentIndex),
      url: Value(url),
      status: Value(status),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      byteSize: byteSize == null && nullToAbsent
          ? const Value.absent()
          : Value(byteSize),
      retryCount: Value(retryCount),
    );
  }

  factory HlsSegmentTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HlsSegmentTableData(
      id: serializer.fromJson<String>(json['id']),
      downloadTaskId: serializer.fromJson<String>(json['downloadTaskId']),
      segmentIndex: serializer.fromJson<int>(json['segmentIndex']),
      url: serializer.fromJson<String>(json['url']),
      status: serializer.fromJson<String>(json['status']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      byteSize: serializer.fromJson<int?>(json['byteSize']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'downloadTaskId': serializer.toJson<String>(downloadTaskId),
      'segmentIndex': serializer.toJson<int>(segmentIndex),
      'url': serializer.toJson<String>(url),
      'status': serializer.toJson<String>(status),
      'localPath': serializer.toJson<String?>(localPath),
      'byteSize': serializer.toJson<int?>(byteSize),
      'retryCount': serializer.toJson<int>(retryCount),
    };
  }

  HlsSegmentTableData copyWith({
    String? id,
    String? downloadTaskId,
    int? segmentIndex,
    String? url,
    String? status,
    Value<String?> localPath = const Value.absent(),
    Value<int?> byteSize = const Value.absent(),
    int? retryCount,
  }) => HlsSegmentTableData(
    id: id ?? this.id,
    downloadTaskId: downloadTaskId ?? this.downloadTaskId,
    segmentIndex: segmentIndex ?? this.segmentIndex,
    url: url ?? this.url,
    status: status ?? this.status,
    localPath: localPath.present ? localPath.value : this.localPath,
    byteSize: byteSize.present ? byteSize.value : this.byteSize,
    retryCount: retryCount ?? this.retryCount,
  );
  HlsSegmentTableData copyWithCompanion(HlsSegmentTableCompanion data) {
    return HlsSegmentTableData(
      id: data.id.present ? data.id.value : this.id,
      downloadTaskId: data.downloadTaskId.present
          ? data.downloadTaskId.value
          : this.downloadTaskId,
      segmentIndex: data.segmentIndex.present
          ? data.segmentIndex.value
          : this.segmentIndex,
      url: data.url.present ? data.url.value : this.url,
      status: data.status.present ? data.status.value : this.status,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HlsSegmentTableData(')
          ..write('id: $id, ')
          ..write('downloadTaskId: $downloadTaskId, ')
          ..write('segmentIndex: $segmentIndex, ')
          ..write('url: $url, ')
          ..write('status: $status, ')
          ..write('localPath: $localPath, ')
          ..write('byteSize: $byteSize, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    downloadTaskId,
    segmentIndex,
    url,
    status,
    localPath,
    byteSize,
    retryCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HlsSegmentTableData &&
          other.id == this.id &&
          other.downloadTaskId == this.downloadTaskId &&
          other.segmentIndex == this.segmentIndex &&
          other.url == this.url &&
          other.status == this.status &&
          other.localPath == this.localPath &&
          other.byteSize == this.byteSize &&
          other.retryCount == this.retryCount);
}

class HlsSegmentTableCompanion extends UpdateCompanion<HlsSegmentTableData> {
  final Value<String> id;
  final Value<String> downloadTaskId;
  final Value<int> segmentIndex;
  final Value<String> url;
  final Value<String> status;
  final Value<String?> localPath;
  final Value<int?> byteSize;
  final Value<int> retryCount;
  final Value<int> rowid;
  const HlsSegmentTableCompanion({
    this.id = const Value.absent(),
    this.downloadTaskId = const Value.absent(),
    this.segmentIndex = const Value.absent(),
    this.url = const Value.absent(),
    this.status = const Value.absent(),
    this.localPath = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HlsSegmentTableCompanion.insert({
    required String id,
    required String downloadTaskId,
    required int segmentIndex,
    required String url,
    this.status = const Value.absent(),
    this.localPath = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       downloadTaskId = Value(downloadTaskId),
       segmentIndex = Value(segmentIndex),
       url = Value(url);
  static Insertable<HlsSegmentTableData> custom({
    Expression<String>? id,
    Expression<String>? downloadTaskId,
    Expression<int>? segmentIndex,
    Expression<String>? url,
    Expression<String>? status,
    Expression<String>? localPath,
    Expression<int>? byteSize,
    Expression<int>? retryCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (downloadTaskId != null) 'download_task_id': downloadTaskId,
      if (segmentIndex != null) 'segment_index': segmentIndex,
      if (url != null) 'url': url,
      if (status != null) 'status': status,
      if (localPath != null) 'local_path': localPath,
      if (byteSize != null) 'byte_size': byteSize,
      if (retryCount != null) 'retry_count': retryCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HlsSegmentTableCompanion copyWith({
    Value<String>? id,
    Value<String>? downloadTaskId,
    Value<int>? segmentIndex,
    Value<String>? url,
    Value<String>? status,
    Value<String?>? localPath,
    Value<int?>? byteSize,
    Value<int>? retryCount,
    Value<int>? rowid,
  }) {
    return HlsSegmentTableCompanion(
      id: id ?? this.id,
      downloadTaskId: downloadTaskId ?? this.downloadTaskId,
      segmentIndex: segmentIndex ?? this.segmentIndex,
      url: url ?? this.url,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      byteSize: byteSize ?? this.byteSize,
      retryCount: retryCount ?? this.retryCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (downloadTaskId.present) {
      map['download_task_id'] = Variable<String>(downloadTaskId.value);
    }
    if (segmentIndex.present) {
      map['segment_index'] = Variable<int>(segmentIndex.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HlsSegmentTableCompanion(')
          ..write('id: $id, ')
          ..write('downloadTaskId: $downloadTaskId, ')
          ..write('segmentIndex: $segmentIndex, ')
          ..write('url: $url, ')
          ..write('status: $status, ')
          ..write('localPath: $localPath, ')
          ..write('byteSize: $byteSize, ')
          ..write('retryCount: $retryCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryEntryTableTable extends LibraryEntryTable
    with TableInfo<$LibraryEntryTableTable, LibraryEntryTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryEntryTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notifyNewEpisodesMeta = const VerificationMeta(
    'notifyNewEpisodes',
  );
  @override
  late final GeneratedColumn<bool> notifyNewEpisodes = GeneratedColumn<bool>(
    'notify_new_episodes',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notify_new_episodes" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastNotifiedEpisodeMeta =
      const VerificationMeta('lastNotifiedEpisode');
  @override
  late final GeneratedColumn<int> lastNotifiedEpisode = GeneratedColumn<int>(
    'last_notified_episode',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _autoDownloadNewEpisodesMeta =
      const VerificationMeta('autoDownloadNewEpisodes');
  @override
  late final GeneratedColumn<bool> autoDownloadNewEpisodes =
      GeneratedColumn<bool>(
        'auto_download_new_episodes',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("auto_download_new_episodes" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _autoDownloadAudioPreferenceMeta =
      const VerificationMeta('autoDownloadAudioPreference');
  @override
  late final GeneratedColumn<String> autoDownloadAudioPreference =
      GeneratedColumn<String>(
        'auto_download_audio_preference',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('none'),
      );
  @override
  List<GeneratedColumn> get $columns => [
    anilistId,
    addedAt,
    notifyNewEpisodes,
    lastNotifiedEpisode,
    autoDownloadNewEpisodes,
    autoDownloadAudioPreference,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_entry';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryEntryTableData> instance, {
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
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('notify_new_episodes')) {
      context.handle(
        _notifyNewEpisodesMeta,
        notifyNewEpisodes.isAcceptableOrUnknown(
          data['notify_new_episodes']!,
          _notifyNewEpisodesMeta,
        ),
      );
    }
    if (data.containsKey('last_notified_episode')) {
      context.handle(
        _lastNotifiedEpisodeMeta,
        lastNotifiedEpisode.isAcceptableOrUnknown(
          data['last_notified_episode']!,
          _lastNotifiedEpisodeMeta,
        ),
      );
    }
    if (data.containsKey('auto_download_new_episodes')) {
      context.handle(
        _autoDownloadNewEpisodesMeta,
        autoDownloadNewEpisodes.isAcceptableOrUnknown(
          data['auto_download_new_episodes']!,
          _autoDownloadNewEpisodesMeta,
        ),
      );
    }
    if (data.containsKey('auto_download_audio_preference')) {
      context.handle(
        _autoDownloadAudioPreferenceMeta,
        autoDownloadAudioPreference.isAcceptableOrUnknown(
          data['auto_download_audio_preference']!,
          _autoDownloadAudioPreferenceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {anilistId};
  @override
  LibraryEntryTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryEntryTableData(
      anilistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anilist_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
      notifyNewEpisodes: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notify_new_episodes'],
      )!,
      lastNotifiedEpisode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_notified_episode'],
      ),
      autoDownloadNewEpisodes: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_download_new_episodes'],
      )!,
      autoDownloadAudioPreference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auto_download_audio_preference'],
      ),
    );
  }

  @override
  $LibraryEntryTableTable createAlias(String alias) {
    return $LibraryEntryTableTable(attachedDatabase, alias);
  }
}

class LibraryEntryTableData extends DataClass
    implements Insertable<LibraryEntryTableData> {
  final int anilistId;
  final int addedAt;
  final bool notifyNewEpisodes;
  final int? lastNotifiedEpisode;
  final bool autoDownloadNewEpisodes;

  /// Auto-download audio variant preference: 'none', 'sub', 'dub'
  final String? autoDownloadAudioPreference;
  const LibraryEntryTableData({
    required this.anilistId,
    required this.addedAt,
    required this.notifyNewEpisodes,
    this.lastNotifiedEpisode,
    required this.autoDownloadNewEpisodes,
    this.autoDownloadAudioPreference,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anilist_id'] = Variable<int>(anilistId);
    map['added_at'] = Variable<int>(addedAt);
    map['notify_new_episodes'] = Variable<bool>(notifyNewEpisodes);
    if (!nullToAbsent || lastNotifiedEpisode != null) {
      map['last_notified_episode'] = Variable<int>(lastNotifiedEpisode);
    }
    map['auto_download_new_episodes'] = Variable<bool>(autoDownloadNewEpisodes);
    if (!nullToAbsent || autoDownloadAudioPreference != null) {
      map['auto_download_audio_preference'] = Variable<String>(
        autoDownloadAudioPreference,
      );
    }
    return map;
  }

  LibraryEntryTableCompanion toCompanion(bool nullToAbsent) {
    return LibraryEntryTableCompanion(
      anilistId: Value(anilistId),
      addedAt: Value(addedAt),
      notifyNewEpisodes: Value(notifyNewEpisodes),
      lastNotifiedEpisode: lastNotifiedEpisode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastNotifiedEpisode),
      autoDownloadNewEpisodes: Value(autoDownloadNewEpisodes),
      autoDownloadAudioPreference:
          autoDownloadAudioPreference == null && nullToAbsent
          ? const Value.absent()
          : Value(autoDownloadAudioPreference),
    );
  }

  factory LibraryEntryTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryEntryTableData(
      anilistId: serializer.fromJson<int>(json['anilistId']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      notifyNewEpisodes: serializer.fromJson<bool>(json['notifyNewEpisodes']),
      lastNotifiedEpisode: serializer.fromJson<int?>(
        json['lastNotifiedEpisode'],
      ),
      autoDownloadNewEpisodes: serializer.fromJson<bool>(
        json['autoDownloadNewEpisodes'],
      ),
      autoDownloadAudioPreference: serializer.fromJson<String?>(
        json['autoDownloadAudioPreference'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'anilistId': serializer.toJson<int>(anilistId),
      'addedAt': serializer.toJson<int>(addedAt),
      'notifyNewEpisodes': serializer.toJson<bool>(notifyNewEpisodes),
      'lastNotifiedEpisode': serializer.toJson<int?>(lastNotifiedEpisode),
      'autoDownloadNewEpisodes': serializer.toJson<bool>(
        autoDownloadNewEpisodes,
      ),
      'autoDownloadAudioPreference': serializer.toJson<String?>(
        autoDownloadAudioPreference,
      ),
    };
  }

  LibraryEntryTableData copyWith({
    int? anilistId,
    int? addedAt,
    bool? notifyNewEpisodes,
    Value<int?> lastNotifiedEpisode = const Value.absent(),
    bool? autoDownloadNewEpisodes,
    Value<String?> autoDownloadAudioPreference = const Value.absent(),
  }) => LibraryEntryTableData(
    anilistId: anilistId ?? this.anilistId,
    addedAt: addedAt ?? this.addedAt,
    notifyNewEpisodes: notifyNewEpisodes ?? this.notifyNewEpisodes,
    lastNotifiedEpisode: lastNotifiedEpisode.present
        ? lastNotifiedEpisode.value
        : this.lastNotifiedEpisode,
    autoDownloadNewEpisodes:
        autoDownloadNewEpisodes ?? this.autoDownloadNewEpisodes,
    autoDownloadAudioPreference: autoDownloadAudioPreference.present
        ? autoDownloadAudioPreference.value
        : this.autoDownloadAudioPreference,
  );
  LibraryEntryTableData copyWithCompanion(LibraryEntryTableCompanion data) {
    return LibraryEntryTableData(
      anilistId: data.anilistId.present ? data.anilistId.value : this.anilistId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      notifyNewEpisodes: data.notifyNewEpisodes.present
          ? data.notifyNewEpisodes.value
          : this.notifyNewEpisodes,
      lastNotifiedEpisode: data.lastNotifiedEpisode.present
          ? data.lastNotifiedEpisode.value
          : this.lastNotifiedEpisode,
      autoDownloadNewEpisodes: data.autoDownloadNewEpisodes.present
          ? data.autoDownloadNewEpisodes.value
          : this.autoDownloadNewEpisodes,
      autoDownloadAudioPreference: data.autoDownloadAudioPreference.present
          ? data.autoDownloadAudioPreference.value
          : this.autoDownloadAudioPreference,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryEntryTableData(')
          ..write('anilistId: $anilistId, ')
          ..write('addedAt: $addedAt, ')
          ..write('notifyNewEpisodes: $notifyNewEpisodes, ')
          ..write('lastNotifiedEpisode: $lastNotifiedEpisode, ')
          ..write('autoDownloadNewEpisodes: $autoDownloadNewEpisodes, ')
          ..write('autoDownloadAudioPreference: $autoDownloadAudioPreference')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    anilistId,
    addedAt,
    notifyNewEpisodes,
    lastNotifiedEpisode,
    autoDownloadNewEpisodes,
    autoDownloadAudioPreference,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryEntryTableData &&
          other.anilistId == this.anilistId &&
          other.addedAt == this.addedAt &&
          other.notifyNewEpisodes == this.notifyNewEpisodes &&
          other.lastNotifiedEpisode == this.lastNotifiedEpisode &&
          other.autoDownloadNewEpisodes == this.autoDownloadNewEpisodes &&
          other.autoDownloadAudioPreference ==
              this.autoDownloadAudioPreference);
}

class LibraryEntryTableCompanion
    extends UpdateCompanion<LibraryEntryTableData> {
  final Value<int> anilistId;
  final Value<int> addedAt;
  final Value<bool> notifyNewEpisodes;
  final Value<int?> lastNotifiedEpisode;
  final Value<bool> autoDownloadNewEpisodes;
  final Value<String?> autoDownloadAudioPreference;
  const LibraryEntryTableCompanion({
    this.anilistId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.notifyNewEpisodes = const Value.absent(),
    this.lastNotifiedEpisode = const Value.absent(),
    this.autoDownloadNewEpisodes = const Value.absent(),
    this.autoDownloadAudioPreference = const Value.absent(),
  });
  LibraryEntryTableCompanion.insert({
    this.anilistId = const Value.absent(),
    required int addedAt,
    this.notifyNewEpisodes = const Value.absent(),
    this.lastNotifiedEpisode = const Value.absent(),
    this.autoDownloadNewEpisodes = const Value.absent(),
    this.autoDownloadAudioPreference = const Value.absent(),
  }) : addedAt = Value(addedAt);
  static Insertable<LibraryEntryTableData> custom({
    Expression<int>? anilistId,
    Expression<int>? addedAt,
    Expression<bool>? notifyNewEpisodes,
    Expression<int>? lastNotifiedEpisode,
    Expression<bool>? autoDownloadNewEpisodes,
    Expression<String>? autoDownloadAudioPreference,
  }) {
    return RawValuesInsertable({
      if (anilistId != null) 'anilist_id': anilistId,
      if (addedAt != null) 'added_at': addedAt,
      if (notifyNewEpisodes != null) 'notify_new_episodes': notifyNewEpisodes,
      if (lastNotifiedEpisode != null)
        'last_notified_episode': lastNotifiedEpisode,
      if (autoDownloadNewEpisodes != null)
        'auto_download_new_episodes': autoDownloadNewEpisodes,
      if (autoDownloadAudioPreference != null)
        'auto_download_audio_preference': autoDownloadAudioPreference,
    });
  }

  LibraryEntryTableCompanion copyWith({
    Value<int>? anilistId,
    Value<int>? addedAt,
    Value<bool>? notifyNewEpisodes,
    Value<int?>? lastNotifiedEpisode,
    Value<bool>? autoDownloadNewEpisodes,
    Value<String?>? autoDownloadAudioPreference,
  }) {
    return LibraryEntryTableCompanion(
      anilistId: anilistId ?? this.anilistId,
      addedAt: addedAt ?? this.addedAt,
      notifyNewEpisodes: notifyNewEpisodes ?? this.notifyNewEpisodes,
      lastNotifiedEpisode: lastNotifiedEpisode ?? this.lastNotifiedEpisode,
      autoDownloadNewEpisodes:
          autoDownloadNewEpisodes ?? this.autoDownloadNewEpisodes,
      autoDownloadAudioPreference:
          autoDownloadAudioPreference ?? this.autoDownloadAudioPreference,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (anilistId.present) {
      map['anilist_id'] = Variable<int>(anilistId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (notifyNewEpisodes.present) {
      map['notify_new_episodes'] = Variable<bool>(notifyNewEpisodes.value);
    }
    if (lastNotifiedEpisode.present) {
      map['last_notified_episode'] = Variable<int>(lastNotifiedEpisode.value);
    }
    if (autoDownloadNewEpisodes.present) {
      map['auto_download_new_episodes'] = Variable<bool>(
        autoDownloadNewEpisodes.value,
      );
    }
    if (autoDownloadAudioPreference.present) {
      map['auto_download_audio_preference'] = Variable<String>(
        autoDownloadAudioPreference.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryEntryTableCompanion(')
          ..write('anilistId: $anilistId, ')
          ..write('addedAt: $addedAt, ')
          ..write('notifyNewEpisodes: $notifyNewEpisodes, ')
          ..write('lastNotifiedEpisode: $lastNotifiedEpisode, ')
          ..write('autoDownloadNewEpisodes: $autoDownloadNewEpisodes, ')
          ..write('autoDownloadAudioPreference: $autoDownloadAudioPreference')
          ..write(')'))
        .toString();
  }
}

class $AnilistCacheTableTable extends AnilistCacheTable
    with TableInfo<$AnilistCacheTableTable, AnilistCacheTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnilistCacheTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleRomajiMeta = const VerificationMeta(
    'titleRomaji',
  );
  @override
  late final GeneratedColumn<String> titleRomaji = GeneratedColumn<String>(
    'title_romaji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleEnglishMeta = const VerificationMeta(
    'titleEnglish',
  );
  @override
  late final GeneratedColumn<String> titleEnglish = GeneratedColumn<String>(
    'title_english',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleNativeMeta = const VerificationMeta(
    'titleNative',
  );
  @override
  late final GeneratedColumn<String> titleNative = GeneratedColumn<String>(
    'title_native',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _synonymsMeta = const VerificationMeta(
    'synonyms',
  );
  @override
  late final GeneratedColumn<String> synonyms = GeneratedColumn<String>(
    'synonyms',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverImageUrlMeta = const VerificationMeta(
    'coverImageUrl',
  );
  @override
  late final GeneratedColumn<String> coverImageUrl = GeneratedColumn<String>(
    'cover_image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bannerImageUrlMeta = const VerificationMeta(
    'bannerImageUrl',
  );
  @override
  late final GeneratedColumn<String> bannerImageUrl = GeneratedColumn<String>(
    'banner_image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<String> season = GeneratedColumn<String>(
    'season',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _averageScoreMeta = const VerificationMeta(
    'averageScore',
  );
  @override
  late final GeneratedColumn<int> averageScore = GeneratedColumn<int>(
    'average_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _popularityMeta = const VerificationMeta(
    'popularity',
  );
  @override
  late final GeneratedColumn<int> popularity = GeneratedColumn<int>(
    'popularity',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genresMeta = const VerificationMeta('genres');
  @override
  late final GeneratedColumn<String> genres = GeneratedColumn<String>(
    'genres',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _synopsisMeta = const VerificationMeta(
    'synopsis',
  );
  @override
  late final GeneratedColumn<String> synopsis = GeneratedColumn<String>(
    'synopsis',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _releaseYearMeta = const VerificationMeta(
    'releaseYear',
  );
  @override
  late final GeneratedColumn<int> releaseYear = GeneratedColumn<int>(
    'release_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalEpisodesMeta = const VerificationMeta(
    'totalEpisodes',
  );
  @override
  late final GeneratedColumn<int> totalEpisodes = GeneratedColumn<int>(
    'total_episodes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextAiringEpisodeMeta = const VerificationMeta(
    'nextAiringEpisode',
  );
  @override
  late final GeneratedColumn<int> nextAiringEpisode = GeneratedColumn<int>(
    'next_airing_episode',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextAiringAtMeta = const VerificationMeta(
    'nextAiringAt',
  );
  @override
  late final GeneratedColumn<int> nextAiringAt = GeneratedColumn<int>(
    'next_airing_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _relationsMeta = const VerificationMeta(
    'relations',
  );
  @override
  late final GeneratedColumn<String> relations = GeneratedColumn<String>(
    'relations',
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
    titleRomaji,
    titleEnglish,
    titleNative,
    synonyms,
    coverImageUrl,
    bannerImageUrl,
    status,
    season,
    averageScore,
    popularity,
    genres,
    synopsis,
    format,
    releaseYear,
    totalEpisodes,
    nextAiringEpisode,
    nextAiringAt,
    relations,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'anilist_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnilistCacheTableData> instance, {
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
    if (data.containsKey('title_romaji')) {
      context.handle(
        _titleRomajiMeta,
        titleRomaji.isAcceptableOrUnknown(
          data['title_romaji']!,
          _titleRomajiMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_titleRomajiMeta);
    }
    if (data.containsKey('title_english')) {
      context.handle(
        _titleEnglishMeta,
        titleEnglish.isAcceptableOrUnknown(
          data['title_english']!,
          _titleEnglishMeta,
        ),
      );
    }
    if (data.containsKey('title_native')) {
      context.handle(
        _titleNativeMeta,
        titleNative.isAcceptableOrUnknown(
          data['title_native']!,
          _titleNativeMeta,
        ),
      );
    }
    if (data.containsKey('synonyms')) {
      context.handle(
        _synonymsMeta,
        synonyms.isAcceptableOrUnknown(data['synonyms']!, _synonymsMeta),
      );
    }
    if (data.containsKey('cover_image_url')) {
      context.handle(
        _coverImageUrlMeta,
        coverImageUrl.isAcceptableOrUnknown(
          data['cover_image_url']!,
          _coverImageUrlMeta,
        ),
      );
    }
    if (data.containsKey('banner_image_url')) {
      context.handle(
        _bannerImageUrlMeta,
        bannerImageUrl.isAcceptableOrUnknown(
          data['banner_image_url']!,
          _bannerImageUrlMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('season')) {
      context.handle(
        _seasonMeta,
        season.isAcceptableOrUnknown(data['season']!, _seasonMeta),
      );
    }
    if (data.containsKey('average_score')) {
      context.handle(
        _averageScoreMeta,
        averageScore.isAcceptableOrUnknown(
          data['average_score']!,
          _averageScoreMeta,
        ),
      );
    }
    if (data.containsKey('popularity')) {
      context.handle(
        _popularityMeta,
        popularity.isAcceptableOrUnknown(data['popularity']!, _popularityMeta),
      );
    }
    if (data.containsKey('genres')) {
      context.handle(
        _genresMeta,
        genres.isAcceptableOrUnknown(data['genres']!, _genresMeta),
      );
    }
    if (data.containsKey('synopsis')) {
      context.handle(
        _synopsisMeta,
        synopsis.isAcceptableOrUnknown(data['synopsis']!, _synopsisMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('release_year')) {
      context.handle(
        _releaseYearMeta,
        releaseYear.isAcceptableOrUnknown(
          data['release_year']!,
          _releaseYearMeta,
        ),
      );
    }
    if (data.containsKey('total_episodes')) {
      context.handle(
        _totalEpisodesMeta,
        totalEpisodes.isAcceptableOrUnknown(
          data['total_episodes']!,
          _totalEpisodesMeta,
        ),
      );
    }
    if (data.containsKey('next_airing_episode')) {
      context.handle(
        _nextAiringEpisodeMeta,
        nextAiringEpisode.isAcceptableOrUnknown(
          data['next_airing_episode']!,
          _nextAiringEpisodeMeta,
        ),
      );
    }
    if (data.containsKey('next_airing_at')) {
      context.handle(
        _nextAiringAtMeta,
        nextAiringAt.isAcceptableOrUnknown(
          data['next_airing_at']!,
          _nextAiringAtMeta,
        ),
      );
    }
    if (data.containsKey('relations')) {
      context.handle(
        _relationsMeta,
        relations.isAcceptableOrUnknown(data['relations']!, _relationsMeta),
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
  AnilistCacheTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnilistCacheTableData(
      anilistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anilist_id'],
      )!,
      titleRomaji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_romaji'],
      )!,
      titleEnglish: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_english'],
      ),
      titleNative: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_native'],
      ),
      synonyms: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synonyms'],
      ),
      coverImageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_image_url'],
      ),
      bannerImageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}banner_image_url'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      season: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}season'],
      ),
      averageScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}average_score'],
      ),
      popularity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}popularity'],
      ),
      genres: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genres'],
      ),
      synopsis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synopsis'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      ),
      releaseYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}release_year'],
      ),
      totalEpisodes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_episodes'],
      ),
      nextAiringEpisode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_airing_episode'],
      ),
      nextAiringAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_airing_at'],
      ),
      relations: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relations'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AnilistCacheTableTable createAlias(String alias) {
    return $AnilistCacheTableTable(attachedDatabase, alias);
  }
}

class AnilistCacheTableData extends DataClass
    implements Insertable<AnilistCacheTableData> {
  final int anilistId;
  final String titleRomaji;
  final String? titleEnglish;
  final String? titleNative;
  final String? synonyms;
  final String? coverImageUrl;
  final String? bannerImageUrl;
  final String? status;
  final String? season;
  final int? averageScore;
  final int? popularity;
  final String? genres;
  final String? synopsis;
  final String? format;
  final int? releaseYear;
  final int? totalEpisodes;
  final int? nextAiringEpisode;
  final int? nextAiringAt;
  final String? relations;
  final int updatedAt;
  const AnilistCacheTableData({
    required this.anilistId,
    required this.titleRomaji,
    this.titleEnglish,
    this.titleNative,
    this.synonyms,
    this.coverImageUrl,
    this.bannerImageUrl,
    this.status,
    this.season,
    this.averageScore,
    this.popularity,
    this.genres,
    this.synopsis,
    this.format,
    this.releaseYear,
    this.totalEpisodes,
    this.nextAiringEpisode,
    this.nextAiringAt,
    this.relations,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anilist_id'] = Variable<int>(anilistId);
    map['title_romaji'] = Variable<String>(titleRomaji);
    if (!nullToAbsent || titleEnglish != null) {
      map['title_english'] = Variable<String>(titleEnglish);
    }
    if (!nullToAbsent || titleNative != null) {
      map['title_native'] = Variable<String>(titleNative);
    }
    if (!nullToAbsent || synonyms != null) {
      map['synonyms'] = Variable<String>(synonyms);
    }
    if (!nullToAbsent || coverImageUrl != null) {
      map['cover_image_url'] = Variable<String>(coverImageUrl);
    }
    if (!nullToAbsent || bannerImageUrl != null) {
      map['banner_image_url'] = Variable<String>(bannerImageUrl);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || season != null) {
      map['season'] = Variable<String>(season);
    }
    if (!nullToAbsent || averageScore != null) {
      map['average_score'] = Variable<int>(averageScore);
    }
    if (!nullToAbsent || popularity != null) {
      map['popularity'] = Variable<int>(popularity);
    }
    if (!nullToAbsent || genres != null) {
      map['genres'] = Variable<String>(genres);
    }
    if (!nullToAbsent || synopsis != null) {
      map['synopsis'] = Variable<String>(synopsis);
    }
    if (!nullToAbsent || format != null) {
      map['format'] = Variable<String>(format);
    }
    if (!nullToAbsent || releaseYear != null) {
      map['release_year'] = Variable<int>(releaseYear);
    }
    if (!nullToAbsent || totalEpisodes != null) {
      map['total_episodes'] = Variable<int>(totalEpisodes);
    }
    if (!nullToAbsent || nextAiringEpisode != null) {
      map['next_airing_episode'] = Variable<int>(nextAiringEpisode);
    }
    if (!nullToAbsent || nextAiringAt != null) {
      map['next_airing_at'] = Variable<int>(nextAiringAt);
    }
    if (!nullToAbsent || relations != null) {
      map['relations'] = Variable<String>(relations);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AnilistCacheTableCompanion toCompanion(bool nullToAbsent) {
    return AnilistCacheTableCompanion(
      anilistId: Value(anilistId),
      titleRomaji: Value(titleRomaji),
      titleEnglish: titleEnglish == null && nullToAbsent
          ? const Value.absent()
          : Value(titleEnglish),
      titleNative: titleNative == null && nullToAbsent
          ? const Value.absent()
          : Value(titleNative),
      synonyms: synonyms == null && nullToAbsent
          ? const Value.absent()
          : Value(synonyms),
      coverImageUrl: coverImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverImageUrl),
      bannerImageUrl: bannerImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(bannerImageUrl),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      season: season == null && nullToAbsent
          ? const Value.absent()
          : Value(season),
      averageScore: averageScore == null && nullToAbsent
          ? const Value.absent()
          : Value(averageScore),
      popularity: popularity == null && nullToAbsent
          ? const Value.absent()
          : Value(popularity),
      genres: genres == null && nullToAbsent
          ? const Value.absent()
          : Value(genres),
      synopsis: synopsis == null && nullToAbsent
          ? const Value.absent()
          : Value(synopsis),
      format: format == null && nullToAbsent
          ? const Value.absent()
          : Value(format),
      releaseYear: releaseYear == null && nullToAbsent
          ? const Value.absent()
          : Value(releaseYear),
      totalEpisodes: totalEpisodes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalEpisodes),
      nextAiringEpisode: nextAiringEpisode == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAiringEpisode),
      nextAiringAt: nextAiringAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAiringAt),
      relations: relations == null && nullToAbsent
          ? const Value.absent()
          : Value(relations),
      updatedAt: Value(updatedAt),
    );
  }

  factory AnilistCacheTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnilistCacheTableData(
      anilistId: serializer.fromJson<int>(json['anilistId']),
      titleRomaji: serializer.fromJson<String>(json['titleRomaji']),
      titleEnglish: serializer.fromJson<String?>(json['titleEnglish']),
      titleNative: serializer.fromJson<String?>(json['titleNative']),
      synonyms: serializer.fromJson<String?>(json['synonyms']),
      coverImageUrl: serializer.fromJson<String?>(json['coverImageUrl']),
      bannerImageUrl: serializer.fromJson<String?>(json['bannerImageUrl']),
      status: serializer.fromJson<String?>(json['status']),
      season: serializer.fromJson<String?>(json['season']),
      averageScore: serializer.fromJson<int?>(json['averageScore']),
      popularity: serializer.fromJson<int?>(json['popularity']),
      genres: serializer.fromJson<String?>(json['genres']),
      synopsis: serializer.fromJson<String?>(json['synopsis']),
      format: serializer.fromJson<String?>(json['format']),
      releaseYear: serializer.fromJson<int?>(json['releaseYear']),
      totalEpisodes: serializer.fromJson<int?>(json['totalEpisodes']),
      nextAiringEpisode: serializer.fromJson<int?>(json['nextAiringEpisode']),
      nextAiringAt: serializer.fromJson<int?>(json['nextAiringAt']),
      relations: serializer.fromJson<String?>(json['relations']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'anilistId': serializer.toJson<int>(anilistId),
      'titleRomaji': serializer.toJson<String>(titleRomaji),
      'titleEnglish': serializer.toJson<String?>(titleEnglish),
      'titleNative': serializer.toJson<String?>(titleNative),
      'synonyms': serializer.toJson<String?>(synonyms),
      'coverImageUrl': serializer.toJson<String?>(coverImageUrl),
      'bannerImageUrl': serializer.toJson<String?>(bannerImageUrl),
      'status': serializer.toJson<String?>(status),
      'season': serializer.toJson<String?>(season),
      'averageScore': serializer.toJson<int?>(averageScore),
      'popularity': serializer.toJson<int?>(popularity),
      'genres': serializer.toJson<String?>(genres),
      'synopsis': serializer.toJson<String?>(synopsis),
      'format': serializer.toJson<String?>(format),
      'releaseYear': serializer.toJson<int?>(releaseYear),
      'totalEpisodes': serializer.toJson<int?>(totalEpisodes),
      'nextAiringEpisode': serializer.toJson<int?>(nextAiringEpisode),
      'nextAiringAt': serializer.toJson<int?>(nextAiringAt),
      'relations': serializer.toJson<String?>(relations),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  AnilistCacheTableData copyWith({
    int? anilistId,
    String? titleRomaji,
    Value<String?> titleEnglish = const Value.absent(),
    Value<String?> titleNative = const Value.absent(),
    Value<String?> synonyms = const Value.absent(),
    Value<String?> coverImageUrl = const Value.absent(),
    Value<String?> bannerImageUrl = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<String?> season = const Value.absent(),
    Value<int?> averageScore = const Value.absent(),
    Value<int?> popularity = const Value.absent(),
    Value<String?> genres = const Value.absent(),
    Value<String?> synopsis = const Value.absent(),
    Value<String?> format = const Value.absent(),
    Value<int?> releaseYear = const Value.absent(),
    Value<int?> totalEpisodes = const Value.absent(),
    Value<int?> nextAiringEpisode = const Value.absent(),
    Value<int?> nextAiringAt = const Value.absent(),
    Value<String?> relations = const Value.absent(),
    int? updatedAt,
  }) => AnilistCacheTableData(
    anilistId: anilistId ?? this.anilistId,
    titleRomaji: titleRomaji ?? this.titleRomaji,
    titleEnglish: titleEnglish.present ? titleEnglish.value : this.titleEnglish,
    titleNative: titleNative.present ? titleNative.value : this.titleNative,
    synonyms: synonyms.present ? synonyms.value : this.synonyms,
    coverImageUrl: coverImageUrl.present
        ? coverImageUrl.value
        : this.coverImageUrl,
    bannerImageUrl: bannerImageUrl.present
        ? bannerImageUrl.value
        : this.bannerImageUrl,
    status: status.present ? status.value : this.status,
    season: season.present ? season.value : this.season,
    averageScore: averageScore.present ? averageScore.value : this.averageScore,
    popularity: popularity.present ? popularity.value : this.popularity,
    genres: genres.present ? genres.value : this.genres,
    synopsis: synopsis.present ? synopsis.value : this.synopsis,
    format: format.present ? format.value : this.format,
    releaseYear: releaseYear.present ? releaseYear.value : this.releaseYear,
    totalEpisodes: totalEpisodes.present
        ? totalEpisodes.value
        : this.totalEpisodes,
    nextAiringEpisode: nextAiringEpisode.present
        ? nextAiringEpisode.value
        : this.nextAiringEpisode,
    nextAiringAt: nextAiringAt.present ? nextAiringAt.value : this.nextAiringAt,
    relations: relations.present ? relations.value : this.relations,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AnilistCacheTableData copyWithCompanion(AnilistCacheTableCompanion data) {
    return AnilistCacheTableData(
      anilistId: data.anilistId.present ? data.anilistId.value : this.anilistId,
      titleRomaji: data.titleRomaji.present
          ? data.titleRomaji.value
          : this.titleRomaji,
      titleEnglish: data.titleEnglish.present
          ? data.titleEnglish.value
          : this.titleEnglish,
      titleNative: data.titleNative.present
          ? data.titleNative.value
          : this.titleNative,
      synonyms: data.synonyms.present ? data.synonyms.value : this.synonyms,
      coverImageUrl: data.coverImageUrl.present
          ? data.coverImageUrl.value
          : this.coverImageUrl,
      bannerImageUrl: data.bannerImageUrl.present
          ? data.bannerImageUrl.value
          : this.bannerImageUrl,
      status: data.status.present ? data.status.value : this.status,
      season: data.season.present ? data.season.value : this.season,
      averageScore: data.averageScore.present
          ? data.averageScore.value
          : this.averageScore,
      popularity: data.popularity.present
          ? data.popularity.value
          : this.popularity,
      genres: data.genres.present ? data.genres.value : this.genres,
      synopsis: data.synopsis.present ? data.synopsis.value : this.synopsis,
      format: data.format.present ? data.format.value : this.format,
      releaseYear: data.releaseYear.present
          ? data.releaseYear.value
          : this.releaseYear,
      totalEpisodes: data.totalEpisodes.present
          ? data.totalEpisodes.value
          : this.totalEpisodes,
      nextAiringEpisode: data.nextAiringEpisode.present
          ? data.nextAiringEpisode.value
          : this.nextAiringEpisode,
      nextAiringAt: data.nextAiringAt.present
          ? data.nextAiringAt.value
          : this.nextAiringAt,
      relations: data.relations.present ? data.relations.value : this.relations,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnilistCacheTableData(')
          ..write('anilistId: $anilistId, ')
          ..write('titleRomaji: $titleRomaji, ')
          ..write('titleEnglish: $titleEnglish, ')
          ..write('titleNative: $titleNative, ')
          ..write('synonyms: $synonyms, ')
          ..write('coverImageUrl: $coverImageUrl, ')
          ..write('bannerImageUrl: $bannerImageUrl, ')
          ..write('status: $status, ')
          ..write('season: $season, ')
          ..write('averageScore: $averageScore, ')
          ..write('popularity: $popularity, ')
          ..write('genres: $genres, ')
          ..write('synopsis: $synopsis, ')
          ..write('format: $format, ')
          ..write('releaseYear: $releaseYear, ')
          ..write('totalEpisodes: $totalEpisodes, ')
          ..write('nextAiringEpisode: $nextAiringEpisode, ')
          ..write('nextAiringAt: $nextAiringAt, ')
          ..write('relations: $relations, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    anilistId,
    titleRomaji,
    titleEnglish,
    titleNative,
    synonyms,
    coverImageUrl,
    bannerImageUrl,
    status,
    season,
    averageScore,
    popularity,
    genres,
    synopsis,
    format,
    releaseYear,
    totalEpisodes,
    nextAiringEpisode,
    nextAiringAt,
    relations,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnilistCacheTableData &&
          other.anilistId == this.anilistId &&
          other.titleRomaji == this.titleRomaji &&
          other.titleEnglish == this.titleEnglish &&
          other.titleNative == this.titleNative &&
          other.synonyms == this.synonyms &&
          other.coverImageUrl == this.coverImageUrl &&
          other.bannerImageUrl == this.bannerImageUrl &&
          other.status == this.status &&
          other.season == this.season &&
          other.averageScore == this.averageScore &&
          other.popularity == this.popularity &&
          other.genres == this.genres &&
          other.synopsis == this.synopsis &&
          other.format == this.format &&
          other.releaseYear == this.releaseYear &&
          other.totalEpisodes == this.totalEpisodes &&
          other.nextAiringEpisode == this.nextAiringEpisode &&
          other.nextAiringAt == this.nextAiringAt &&
          other.relations == this.relations &&
          other.updatedAt == this.updatedAt);
}

class AnilistCacheTableCompanion
    extends UpdateCompanion<AnilistCacheTableData> {
  final Value<int> anilistId;
  final Value<String> titleRomaji;
  final Value<String?> titleEnglish;
  final Value<String?> titleNative;
  final Value<String?> synonyms;
  final Value<String?> coverImageUrl;
  final Value<String?> bannerImageUrl;
  final Value<String?> status;
  final Value<String?> season;
  final Value<int?> averageScore;
  final Value<int?> popularity;
  final Value<String?> genres;
  final Value<String?> synopsis;
  final Value<String?> format;
  final Value<int?> releaseYear;
  final Value<int?> totalEpisodes;
  final Value<int?> nextAiringEpisode;
  final Value<int?> nextAiringAt;
  final Value<String?> relations;
  final Value<int> updatedAt;
  const AnilistCacheTableCompanion({
    this.anilistId = const Value.absent(),
    this.titleRomaji = const Value.absent(),
    this.titleEnglish = const Value.absent(),
    this.titleNative = const Value.absent(),
    this.synonyms = const Value.absent(),
    this.coverImageUrl = const Value.absent(),
    this.bannerImageUrl = const Value.absent(),
    this.status = const Value.absent(),
    this.season = const Value.absent(),
    this.averageScore = const Value.absent(),
    this.popularity = const Value.absent(),
    this.genres = const Value.absent(),
    this.synopsis = const Value.absent(),
    this.format = const Value.absent(),
    this.releaseYear = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    this.nextAiringEpisode = const Value.absent(),
    this.nextAiringAt = const Value.absent(),
    this.relations = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AnilistCacheTableCompanion.insert({
    this.anilistId = const Value.absent(),
    required String titleRomaji,
    this.titleEnglish = const Value.absent(),
    this.titleNative = const Value.absent(),
    this.synonyms = const Value.absent(),
    this.coverImageUrl = const Value.absent(),
    this.bannerImageUrl = const Value.absent(),
    this.status = const Value.absent(),
    this.season = const Value.absent(),
    this.averageScore = const Value.absent(),
    this.popularity = const Value.absent(),
    this.genres = const Value.absent(),
    this.synopsis = const Value.absent(),
    this.format = const Value.absent(),
    this.releaseYear = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    this.nextAiringEpisode = const Value.absent(),
    this.nextAiringAt = const Value.absent(),
    this.relations = const Value.absent(),
    required int updatedAt,
  }) : titleRomaji = Value(titleRomaji),
       updatedAt = Value(updatedAt);
  static Insertable<AnilistCacheTableData> custom({
    Expression<int>? anilistId,
    Expression<String>? titleRomaji,
    Expression<String>? titleEnglish,
    Expression<String>? titleNative,
    Expression<String>? synonyms,
    Expression<String>? coverImageUrl,
    Expression<String>? bannerImageUrl,
    Expression<String>? status,
    Expression<String>? season,
    Expression<int>? averageScore,
    Expression<int>? popularity,
    Expression<String>? genres,
    Expression<String>? synopsis,
    Expression<String>? format,
    Expression<int>? releaseYear,
    Expression<int>? totalEpisodes,
    Expression<int>? nextAiringEpisode,
    Expression<int>? nextAiringAt,
    Expression<String>? relations,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (anilistId != null) 'anilist_id': anilistId,
      if (titleRomaji != null) 'title_romaji': titleRomaji,
      if (titleEnglish != null) 'title_english': titleEnglish,
      if (titleNative != null) 'title_native': titleNative,
      if (synonyms != null) 'synonyms': synonyms,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      if (bannerImageUrl != null) 'banner_image_url': bannerImageUrl,
      if (status != null) 'status': status,
      if (season != null) 'season': season,
      if (averageScore != null) 'average_score': averageScore,
      if (popularity != null) 'popularity': popularity,
      if (genres != null) 'genres': genres,
      if (synopsis != null) 'synopsis': synopsis,
      if (format != null) 'format': format,
      if (releaseYear != null) 'release_year': releaseYear,
      if (totalEpisodes != null) 'total_episodes': totalEpisodes,
      if (nextAiringEpisode != null) 'next_airing_episode': nextAiringEpisode,
      if (nextAiringAt != null) 'next_airing_at': nextAiringAt,
      if (relations != null) 'relations': relations,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AnilistCacheTableCompanion copyWith({
    Value<int>? anilistId,
    Value<String>? titleRomaji,
    Value<String?>? titleEnglish,
    Value<String?>? titleNative,
    Value<String?>? synonyms,
    Value<String?>? coverImageUrl,
    Value<String?>? bannerImageUrl,
    Value<String?>? status,
    Value<String?>? season,
    Value<int?>? averageScore,
    Value<int?>? popularity,
    Value<String?>? genres,
    Value<String?>? synopsis,
    Value<String?>? format,
    Value<int?>? releaseYear,
    Value<int?>? totalEpisodes,
    Value<int?>? nextAiringEpisode,
    Value<int?>? nextAiringAt,
    Value<String?>? relations,
    Value<int>? updatedAt,
  }) {
    return AnilistCacheTableCompanion(
      anilistId: anilistId ?? this.anilistId,
      titleRomaji: titleRomaji ?? this.titleRomaji,
      titleEnglish: titleEnglish ?? this.titleEnglish,
      titleNative: titleNative ?? this.titleNative,
      synonyms: synonyms ?? this.synonyms,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      status: status ?? this.status,
      season: season ?? this.season,
      averageScore: averageScore ?? this.averageScore,
      popularity: popularity ?? this.popularity,
      genres: genres ?? this.genres,
      synopsis: synopsis ?? this.synopsis,
      format: format ?? this.format,
      releaseYear: releaseYear ?? this.releaseYear,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      nextAiringEpisode: nextAiringEpisode ?? this.nextAiringEpisode,
      nextAiringAt: nextAiringAt ?? this.nextAiringAt,
      relations: relations ?? this.relations,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (anilistId.present) {
      map['anilist_id'] = Variable<int>(anilistId.value);
    }
    if (titleRomaji.present) {
      map['title_romaji'] = Variable<String>(titleRomaji.value);
    }
    if (titleEnglish.present) {
      map['title_english'] = Variable<String>(titleEnglish.value);
    }
    if (titleNative.present) {
      map['title_native'] = Variable<String>(titleNative.value);
    }
    if (synonyms.present) {
      map['synonyms'] = Variable<String>(synonyms.value);
    }
    if (coverImageUrl.present) {
      map['cover_image_url'] = Variable<String>(coverImageUrl.value);
    }
    if (bannerImageUrl.present) {
      map['banner_image_url'] = Variable<String>(bannerImageUrl.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (season.present) {
      map['season'] = Variable<String>(season.value);
    }
    if (averageScore.present) {
      map['average_score'] = Variable<int>(averageScore.value);
    }
    if (popularity.present) {
      map['popularity'] = Variable<int>(popularity.value);
    }
    if (genres.present) {
      map['genres'] = Variable<String>(genres.value);
    }
    if (synopsis.present) {
      map['synopsis'] = Variable<String>(synopsis.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (releaseYear.present) {
      map['release_year'] = Variable<int>(releaseYear.value);
    }
    if (totalEpisodes.present) {
      map['total_episodes'] = Variable<int>(totalEpisodes.value);
    }
    if (nextAiringEpisode.present) {
      map['next_airing_episode'] = Variable<int>(nextAiringEpisode.value);
    }
    if (nextAiringAt.present) {
      map['next_airing_at'] = Variable<int>(nextAiringAt.value);
    }
    if (relations.present) {
      map['relations'] = Variable<String>(relations.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnilistCacheTableCompanion(')
          ..write('anilistId: $anilistId, ')
          ..write('titleRomaji: $titleRomaji, ')
          ..write('titleEnglish: $titleEnglish, ')
          ..write('titleNative: $titleNative, ')
          ..write('synonyms: $synonyms, ')
          ..write('coverImageUrl: $coverImageUrl, ')
          ..write('bannerImageUrl: $bannerImageUrl, ')
          ..write('status: $status, ')
          ..write('season: $season, ')
          ..write('averageScore: $averageScore, ')
          ..write('popularity: $popularity, ')
          ..write('genres: $genres, ')
          ..write('synopsis: $synopsis, ')
          ..write('format: $format, ')
          ..write('releaseYear: $releaseYear, ')
          ..write('totalEpisodes: $totalEpisodes, ')
          ..write('nextAiringEpisode: $nextAiringEpisode, ')
          ..write('nextAiringAt: $nextAiringAt, ')
          ..write('relations: $relations, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TranslationCacheTableTable extends TranslationCacheTable
    with TableInfo<$TranslationCacheTableTable, TranslationCacheTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranslationCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceTextMeta = const VerificationMeta(
    'sourceText',
  );
  @override
  late final GeneratedColumn<String> sourceText = GeneratedColumn<String>(
    'source_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetLanguageMeta = const VerificationMeta(
    'targetLanguage',
  );
  @override
  late final GeneratedColumn<String> targetLanguage = GeneratedColumn<String>(
    'target_language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _translatedTextMeta = const VerificationMeta(
    'translatedText',
  );
  @override
  late final GeneratedColumn<String> translatedText = GeneratedColumn<String>(
    'translated_text',
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
    sourceText,
    targetLanguage,
    translatedText,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'translation_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<TranslationCacheTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_text')) {
      context.handle(
        _sourceTextMeta,
        sourceText.isAcceptableOrUnknown(data['source_text']!, _sourceTextMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTextMeta);
    }
    if (data.containsKey('target_language')) {
      context.handle(
        _targetLanguageMeta,
        targetLanguage.isAcceptableOrUnknown(
          data['target_language']!,
          _targetLanguageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetLanguageMeta);
    }
    if (data.containsKey('translated_text')) {
      context.handle(
        _translatedTextMeta,
        translatedText.isAcceptableOrUnknown(
          data['translated_text']!,
          _translatedTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_translatedTextMeta);
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
  Set<GeneratedColumn> get $primaryKey => {sourceText, targetLanguage};
  @override
  TranslationCacheTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranslationCacheTableData(
      sourceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_text'],
      )!,
      targetLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_language'],
      )!,
      translatedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translated_text'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TranslationCacheTableTable createAlias(String alias) {
    return $TranslationCacheTableTable(attachedDatabase, alias);
  }
}

class TranslationCacheTableData extends DataClass
    implements Insertable<TranslationCacheTableData> {
  final String sourceText;
  final String targetLanguage;
  final String translatedText;
  final int updatedAt;
  const TranslationCacheTableData({
    required this.sourceText,
    required this.targetLanguage,
    required this.translatedText,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_text'] = Variable<String>(sourceText);
    map['target_language'] = Variable<String>(targetLanguage);
    map['translated_text'] = Variable<String>(translatedText);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TranslationCacheTableCompanion toCompanion(bool nullToAbsent) {
    return TranslationCacheTableCompanion(
      sourceText: Value(sourceText),
      targetLanguage: Value(targetLanguage),
      translatedText: Value(translatedText),
      updatedAt: Value(updatedAt),
    );
  }

  factory TranslationCacheTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranslationCacheTableData(
      sourceText: serializer.fromJson<String>(json['sourceText']),
      targetLanguage: serializer.fromJson<String>(json['targetLanguage']),
      translatedText: serializer.fromJson<String>(json['translatedText']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceText': serializer.toJson<String>(sourceText),
      'targetLanguage': serializer.toJson<String>(targetLanguage),
      'translatedText': serializer.toJson<String>(translatedText),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TranslationCacheTableData copyWith({
    String? sourceText,
    String? targetLanguage,
    String? translatedText,
    int? updatedAt,
  }) => TranslationCacheTableData(
    sourceText: sourceText ?? this.sourceText,
    targetLanguage: targetLanguage ?? this.targetLanguage,
    translatedText: translatedText ?? this.translatedText,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TranslationCacheTableData copyWithCompanion(
    TranslationCacheTableCompanion data,
  ) {
    return TranslationCacheTableData(
      sourceText: data.sourceText.present
          ? data.sourceText.value
          : this.sourceText,
      targetLanguage: data.targetLanguage.present
          ? data.targetLanguage.value
          : this.targetLanguage,
      translatedText: data.translatedText.present
          ? data.translatedText.value
          : this.translatedText,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranslationCacheTableData(')
          ..write('sourceText: $sourceText, ')
          ..write('targetLanguage: $targetLanguage, ')
          ..write('translatedText: $translatedText, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sourceText, targetLanguage, translatedText, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranslationCacheTableData &&
          other.sourceText == this.sourceText &&
          other.targetLanguage == this.targetLanguage &&
          other.translatedText == this.translatedText &&
          other.updatedAt == this.updatedAt);
}

class TranslationCacheTableCompanion
    extends UpdateCompanion<TranslationCacheTableData> {
  final Value<String> sourceText;
  final Value<String> targetLanguage;
  final Value<String> translatedText;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TranslationCacheTableCompanion({
    this.sourceText = const Value.absent(),
    this.targetLanguage = const Value.absent(),
    this.translatedText = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranslationCacheTableCompanion.insert({
    required String sourceText,
    required String targetLanguage,
    required String translatedText,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : sourceText = Value(sourceText),
       targetLanguage = Value(targetLanguage),
       translatedText = Value(translatedText),
       updatedAt = Value(updatedAt);
  static Insertable<TranslationCacheTableData> custom({
    Expression<String>? sourceText,
    Expression<String>? targetLanguage,
    Expression<String>? translatedText,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceText != null) 'source_text': sourceText,
      if (targetLanguage != null) 'target_language': targetLanguage,
      if (translatedText != null) 'translated_text': translatedText,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranslationCacheTableCompanion copyWith({
    Value<String>? sourceText,
    Value<String>? targetLanguage,
    Value<String>? translatedText,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TranslationCacheTableCompanion(
      sourceText: sourceText ?? this.sourceText,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      translatedText: translatedText ?? this.translatedText,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceText.present) {
      map['source_text'] = Variable<String>(sourceText.value);
    }
    if (targetLanguage.present) {
      map['target_language'] = Variable<String>(targetLanguage.value);
    }
    if (translatedText.present) {
      map['translated_text'] = Variable<String>(translatedText.value);
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
    return (StringBuffer('TranslationCacheTableCompanion(')
          ..write('sourceText: $sourceText, ')
          ..write('targetLanguage: $targetLanguage, ')
          ..write('translatedText: $translatedText, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpisodeCatalogCacheTableTable extends EpisodeCatalogCacheTable
    with
        TableInfo<
          $EpisodeCatalogCacheTableTable,
          EpisodeCatalogCacheTableData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodeCatalogCacheTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _airDateMeta = const VerificationMeta(
    'airDate',
  );
  @override
  late final GeneratedColumn<int> airDate = GeneratedColumn<int>(
    'air_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isAiredMeta = const VerificationMeta(
    'isAired',
  );
  @override
  late final GeneratedColumn<bool> isAired = GeneratedColumn<bool>(
    'is_aired',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_aired" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isFillerMeta = const VerificationMeta(
    'isFiller',
  );
  @override
  late final GeneratedColumn<bool> isFiller = GeneratedColumn<bool>(
    'is_filler',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_filler" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    title,
    airDate,
    isAired,
    isFiller,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episode_catalog_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpisodeCatalogCacheTableData> instance, {
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
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('air_date')) {
      context.handle(
        _airDateMeta,
        airDate.isAcceptableOrUnknown(data['air_date']!, _airDateMeta),
      );
    }
    if (data.containsKey('is_aired')) {
      context.handle(
        _isAiredMeta,
        isAired.isAcceptableOrUnknown(data['is_aired']!, _isAiredMeta),
      );
    }
    if (data.containsKey('is_filler')) {
      context.handle(
        _isFillerMeta,
        isFiller.isAcceptableOrUnknown(data['is_filler']!, _isFillerMeta),
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
  EpisodeCatalogCacheTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpisodeCatalogCacheTableData(
      anilistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anilist_id'],
      )!,
      episodeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}episode_number'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      airDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}air_date'],
      ),
      isAired: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_aired'],
      )!,
      isFiller: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_filler'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EpisodeCatalogCacheTableTable createAlias(String alias) {
    return $EpisodeCatalogCacheTableTable(attachedDatabase, alias);
  }
}

class EpisodeCatalogCacheTableData extends DataClass
    implements Insertable<EpisodeCatalogCacheTableData> {
  final int anilistId;
  final double episodeNumber;
  final String title;
  final int? airDate;
  final bool isAired;
  final bool isFiller;
  final int updatedAt;
  const EpisodeCatalogCacheTableData({
    required this.anilistId,
    required this.episodeNumber,
    required this.title,
    this.airDate,
    required this.isAired,
    required this.isFiller,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anilist_id'] = Variable<int>(anilistId);
    map['episode_number'] = Variable<double>(episodeNumber);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || airDate != null) {
      map['air_date'] = Variable<int>(airDate);
    }
    map['is_aired'] = Variable<bool>(isAired);
    map['is_filler'] = Variable<bool>(isFiller);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  EpisodeCatalogCacheTableCompanion toCompanion(bool nullToAbsent) {
    return EpisodeCatalogCacheTableCompanion(
      anilistId: Value(anilistId),
      episodeNumber: Value(episodeNumber),
      title: Value(title),
      airDate: airDate == null && nullToAbsent
          ? const Value.absent()
          : Value(airDate),
      isAired: Value(isAired),
      isFiller: Value(isFiller),
      updatedAt: Value(updatedAt),
    );
  }

  factory EpisodeCatalogCacheTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpisodeCatalogCacheTableData(
      anilistId: serializer.fromJson<int>(json['anilistId']),
      episodeNumber: serializer.fromJson<double>(json['episodeNumber']),
      title: serializer.fromJson<String>(json['title']),
      airDate: serializer.fromJson<int?>(json['airDate']),
      isAired: serializer.fromJson<bool>(json['isAired']),
      isFiller: serializer.fromJson<bool>(json['isFiller']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'anilistId': serializer.toJson<int>(anilistId),
      'episodeNumber': serializer.toJson<double>(episodeNumber),
      'title': serializer.toJson<String>(title),
      'airDate': serializer.toJson<int?>(airDate),
      'isAired': serializer.toJson<bool>(isAired),
      'isFiller': serializer.toJson<bool>(isFiller),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  EpisodeCatalogCacheTableData copyWith({
    int? anilistId,
    double? episodeNumber,
    String? title,
    Value<int?> airDate = const Value.absent(),
    bool? isAired,
    bool? isFiller,
    int? updatedAt,
  }) => EpisodeCatalogCacheTableData(
    anilistId: anilistId ?? this.anilistId,
    episodeNumber: episodeNumber ?? this.episodeNumber,
    title: title ?? this.title,
    airDate: airDate.present ? airDate.value : this.airDate,
    isAired: isAired ?? this.isAired,
    isFiller: isFiller ?? this.isFiller,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EpisodeCatalogCacheTableData copyWithCompanion(
    EpisodeCatalogCacheTableCompanion data,
  ) {
    return EpisodeCatalogCacheTableData(
      anilistId: data.anilistId.present ? data.anilistId.value : this.anilistId,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      title: data.title.present ? data.title.value : this.title,
      airDate: data.airDate.present ? data.airDate.value : this.airDate,
      isAired: data.isAired.present ? data.isAired.value : this.isAired,
      isFiller: data.isFiller.present ? data.isFiller.value : this.isFiller,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeCatalogCacheTableData(')
          ..write('anilistId: $anilistId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('title: $title, ')
          ..write('airDate: $airDate, ')
          ..write('isAired: $isAired, ')
          ..write('isFiller: $isFiller, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    anilistId,
    episodeNumber,
    title,
    airDate,
    isAired,
    isFiller,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodeCatalogCacheTableData &&
          other.anilistId == this.anilistId &&
          other.episodeNumber == this.episodeNumber &&
          other.title == this.title &&
          other.airDate == this.airDate &&
          other.isAired == this.isAired &&
          other.isFiller == this.isFiller &&
          other.updatedAt == this.updatedAt);
}

class EpisodeCatalogCacheTableCompanion
    extends UpdateCompanion<EpisodeCatalogCacheTableData> {
  final Value<int> anilistId;
  final Value<double> episodeNumber;
  final Value<String> title;
  final Value<int?> airDate;
  final Value<bool> isAired;
  final Value<bool> isFiller;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const EpisodeCatalogCacheTableCompanion({
    this.anilistId = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.title = const Value.absent(),
    this.airDate = const Value.absent(),
    this.isAired = const Value.absent(),
    this.isFiller = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpisodeCatalogCacheTableCompanion.insert({
    required int anilistId,
    required double episodeNumber,
    required String title,
    this.airDate = const Value.absent(),
    this.isAired = const Value.absent(),
    this.isFiller = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : anilistId = Value(anilistId),
       episodeNumber = Value(episodeNumber),
       title = Value(title),
       updatedAt = Value(updatedAt);
  static Insertable<EpisodeCatalogCacheTableData> custom({
    Expression<int>? anilistId,
    Expression<double>? episodeNumber,
    Expression<String>? title,
    Expression<int>? airDate,
    Expression<bool>? isAired,
    Expression<bool>? isFiller,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (anilistId != null) 'anilist_id': anilistId,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (title != null) 'title': title,
      if (airDate != null) 'air_date': airDate,
      if (isAired != null) 'is_aired': isAired,
      if (isFiller != null) 'is_filler': isFiller,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpisodeCatalogCacheTableCompanion copyWith({
    Value<int>? anilistId,
    Value<double>? episodeNumber,
    Value<String>? title,
    Value<int?>? airDate,
    Value<bool>? isAired,
    Value<bool>? isFiller,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return EpisodeCatalogCacheTableCompanion(
      anilistId: anilistId ?? this.anilistId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      airDate: airDate ?? this.airDate,
      isAired: isAired ?? this.isAired,
      isFiller: isFiller ?? this.isFiller,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (airDate.present) {
      map['air_date'] = Variable<int>(airDate.value);
    }
    if (isAired.present) {
      map['is_aired'] = Variable<bool>(isAired.value);
    }
    if (isFiller.present) {
      map['is_filler'] = Variable<bool>(isFiller.value);
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
    return (StringBuffer('EpisodeCatalogCacheTableCompanion(')
          ..write('anilistId: $anilistId, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('title: $title, ')
          ..write('airDate: $airDate, ')
          ..write('isAired: $isAired, ')
          ..write('isFiller: $isFiller, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MangaCacheTableTable extends MangaCacheTable
    with TableInfo<$MangaCacheTableTable, MangaCacheTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MangaCacheTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleRomajiMeta = const VerificationMeta(
    'titleRomaji',
  );
  @override
  late final GeneratedColumn<String> titleRomaji = GeneratedColumn<String>(
    'title_romaji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleEnglishMeta = const VerificationMeta(
    'titleEnglish',
  );
  @override
  late final GeneratedColumn<String> titleEnglish = GeneratedColumn<String>(
    'title_english',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleNativeMeta = const VerificationMeta(
    'titleNative',
  );
  @override
  late final GeneratedColumn<String> titleNative = GeneratedColumn<String>(
    'title_native',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _synonymsMeta = const VerificationMeta(
    'synonyms',
  );
  @override
  late final GeneratedColumn<String> synonyms = GeneratedColumn<String>(
    'synonyms',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverImageUrlMeta = const VerificationMeta(
    'coverImageUrl',
  );
  @override
  late final GeneratedColumn<String> coverImageUrl = GeneratedColumn<String>(
    'cover_image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bannerImageUrlMeta = const VerificationMeta(
    'bannerImageUrl',
  );
  @override
  late final GeneratedColumn<String> bannerImageUrl = GeneratedColumn<String>(
    'banner_image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countryOfOriginMeta = const VerificationMeta(
    'countryOfOrigin',
  );
  @override
  late final GeneratedColumn<String> countryOfOrigin = GeneratedColumn<String>(
    'country_of_origin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalLanguageMeta = const VerificationMeta(
    'originalLanguage',
  );
  @override
  late final GeneratedColumn<String> originalLanguage = GeneratedColumn<String>(
    'original_language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _releaseYearMeta = const VerificationMeta(
    'releaseYear',
  );
  @override
  late final GeneratedColumn<int> releaseYear = GeneratedColumn<int>(
    'release_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalChaptersMeta = const VerificationMeta(
    'totalChapters',
  );
  @override
  late final GeneratedColumn<int> totalChapters = GeneratedColumn<int>(
    'total_chapters',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalVolumesMeta = const VerificationMeta(
    'totalVolumes',
  );
  @override
  late final GeneratedColumn<int> totalVolumes = GeneratedColumn<int>(
    'total_volumes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _averageScoreMeta = const VerificationMeta(
    'averageScore',
  );
  @override
  late final GeneratedColumn<int> averageScore = GeneratedColumn<int>(
    'average_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _popularityMeta = const VerificationMeta(
    'popularity',
  );
  @override
  late final GeneratedColumn<int> popularity = GeneratedColumn<int>(
    'popularity',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genresMeta = const VerificationMeta('genres');
  @override
  late final GeneratedColumn<String> genres = GeneratedColumn<String>(
    'genres',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _synopsisMeta = const VerificationMeta(
    'synopsis',
  );
  @override
  late final GeneratedColumn<String> synopsis = GeneratedColumn<String>(
    'synopsis',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _relationsMeta = const VerificationMeta(
    'relations',
  );
  @override
  late final GeneratedColumn<String> relations = GeneratedColumn<String>(
    'relations',
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
    titleRomaji,
    titleEnglish,
    titleNative,
    synonyms,
    coverImageUrl,
    bannerImageUrl,
    status,
    format,
    countryOfOrigin,
    originalLanguage,
    releaseYear,
    totalChapters,
    totalVolumes,
    averageScore,
    popularity,
    genres,
    tags,
    synopsis,
    relations,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'manga_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<MangaCacheTableData> instance, {
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
    if (data.containsKey('title_romaji')) {
      context.handle(
        _titleRomajiMeta,
        titleRomaji.isAcceptableOrUnknown(
          data['title_romaji']!,
          _titleRomajiMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_titleRomajiMeta);
    }
    if (data.containsKey('title_english')) {
      context.handle(
        _titleEnglishMeta,
        titleEnglish.isAcceptableOrUnknown(
          data['title_english']!,
          _titleEnglishMeta,
        ),
      );
    }
    if (data.containsKey('title_native')) {
      context.handle(
        _titleNativeMeta,
        titleNative.isAcceptableOrUnknown(
          data['title_native']!,
          _titleNativeMeta,
        ),
      );
    }
    if (data.containsKey('synonyms')) {
      context.handle(
        _synonymsMeta,
        synonyms.isAcceptableOrUnknown(data['synonyms']!, _synonymsMeta),
      );
    }
    if (data.containsKey('cover_image_url')) {
      context.handle(
        _coverImageUrlMeta,
        coverImageUrl.isAcceptableOrUnknown(
          data['cover_image_url']!,
          _coverImageUrlMeta,
        ),
      );
    }
    if (data.containsKey('banner_image_url')) {
      context.handle(
        _bannerImageUrlMeta,
        bannerImageUrl.isAcceptableOrUnknown(
          data['banner_image_url']!,
          _bannerImageUrlMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('country_of_origin')) {
      context.handle(
        _countryOfOriginMeta,
        countryOfOrigin.isAcceptableOrUnknown(
          data['country_of_origin']!,
          _countryOfOriginMeta,
        ),
      );
    }
    if (data.containsKey('original_language')) {
      context.handle(
        _originalLanguageMeta,
        originalLanguage.isAcceptableOrUnknown(
          data['original_language']!,
          _originalLanguageMeta,
        ),
      );
    }
    if (data.containsKey('release_year')) {
      context.handle(
        _releaseYearMeta,
        releaseYear.isAcceptableOrUnknown(
          data['release_year']!,
          _releaseYearMeta,
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
    if (data.containsKey('total_volumes')) {
      context.handle(
        _totalVolumesMeta,
        totalVolumes.isAcceptableOrUnknown(
          data['total_volumes']!,
          _totalVolumesMeta,
        ),
      );
    }
    if (data.containsKey('average_score')) {
      context.handle(
        _averageScoreMeta,
        averageScore.isAcceptableOrUnknown(
          data['average_score']!,
          _averageScoreMeta,
        ),
      );
    }
    if (data.containsKey('popularity')) {
      context.handle(
        _popularityMeta,
        popularity.isAcceptableOrUnknown(data['popularity']!, _popularityMeta),
      );
    }
    if (data.containsKey('genres')) {
      context.handle(
        _genresMeta,
        genres.isAcceptableOrUnknown(data['genres']!, _genresMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('synopsis')) {
      context.handle(
        _synopsisMeta,
        synopsis.isAcceptableOrUnknown(data['synopsis']!, _synopsisMeta),
      );
    }
    if (data.containsKey('relations')) {
      context.handle(
        _relationsMeta,
        relations.isAcceptableOrUnknown(data['relations']!, _relationsMeta),
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
  MangaCacheTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MangaCacheTableData(
      anilistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anilist_id'],
      )!,
      titleRomaji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_romaji'],
      )!,
      titleEnglish: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_english'],
      ),
      titleNative: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_native'],
      ),
      synonyms: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synonyms'],
      ),
      coverImageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_image_url'],
      ),
      bannerImageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}banner_image_url'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      ),
      countryOfOrigin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country_of_origin'],
      ),
      originalLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_language'],
      ),
      releaseYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}release_year'],
      ),
      totalChapters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_chapters'],
      ),
      totalVolumes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_volumes'],
      ),
      averageScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}average_score'],
      ),
      popularity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}popularity'],
      ),
      genres: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genres'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      synopsis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synopsis'],
      ),
      relations: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relations'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MangaCacheTableTable createAlias(String alias) {
    return $MangaCacheTableTable(attachedDatabase, alias);
  }
}

class MangaCacheTableData extends DataClass
    implements Insertable<MangaCacheTableData> {
  final int anilistId;
  final String titleRomaji;
  final String? titleEnglish;
  final String? titleNative;

  /// JSON-encoded `List<String>`.
  final String? synonyms;
  final String? coverImageUrl;
  final String? bannerImageUrl;

  /// AniList release status string (`RELEASING`, `FINISHED`, `HIATUS`,
  /// `CANCELLED`, `NOT_YET_RELEASED`).
  final String? status;

  /// AniList format string (`MANGA`, `MANHWA`, `MANHUA`, `ONE_SHOT`,
  /// `DOUJINSHI`, `NOVEL`).
  final String? format;

  /// ISO 3166 country code: `JP`, `KR`, `CN`, `TW`.
  final String? countryOfOrigin;

  /// BCP-47 language tag of the original publication when known
  /// (`ja`, `ko`, `zh`).
  final String? originalLanguage;
  final int? releaseYear;
  final int? totalChapters;
  final int? totalVolumes;
  final int? averageScore;
  final int? popularity;

  /// JSON-encoded `List<String>`.
  final String? genres;

  /// JSON-encoded `List<{name, rank?, isAdult?}>`.
  final String? tags;
  final String? synopsis;

  /// JSON-encoded `List<{id, type, mediaKind}>` of relations.
  final String? relations;
  final int updatedAt;
  const MangaCacheTableData({
    required this.anilistId,
    required this.titleRomaji,
    this.titleEnglish,
    this.titleNative,
    this.synonyms,
    this.coverImageUrl,
    this.bannerImageUrl,
    this.status,
    this.format,
    this.countryOfOrigin,
    this.originalLanguage,
    this.releaseYear,
    this.totalChapters,
    this.totalVolumes,
    this.averageScore,
    this.popularity,
    this.genres,
    this.tags,
    this.synopsis,
    this.relations,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anilist_id'] = Variable<int>(anilistId);
    map['title_romaji'] = Variable<String>(titleRomaji);
    if (!nullToAbsent || titleEnglish != null) {
      map['title_english'] = Variable<String>(titleEnglish);
    }
    if (!nullToAbsent || titleNative != null) {
      map['title_native'] = Variable<String>(titleNative);
    }
    if (!nullToAbsent || synonyms != null) {
      map['synonyms'] = Variable<String>(synonyms);
    }
    if (!nullToAbsent || coverImageUrl != null) {
      map['cover_image_url'] = Variable<String>(coverImageUrl);
    }
    if (!nullToAbsent || bannerImageUrl != null) {
      map['banner_image_url'] = Variable<String>(bannerImageUrl);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || format != null) {
      map['format'] = Variable<String>(format);
    }
    if (!nullToAbsent || countryOfOrigin != null) {
      map['country_of_origin'] = Variable<String>(countryOfOrigin);
    }
    if (!nullToAbsent || originalLanguage != null) {
      map['original_language'] = Variable<String>(originalLanguage);
    }
    if (!nullToAbsent || releaseYear != null) {
      map['release_year'] = Variable<int>(releaseYear);
    }
    if (!nullToAbsent || totalChapters != null) {
      map['total_chapters'] = Variable<int>(totalChapters);
    }
    if (!nullToAbsent || totalVolumes != null) {
      map['total_volumes'] = Variable<int>(totalVolumes);
    }
    if (!nullToAbsent || averageScore != null) {
      map['average_score'] = Variable<int>(averageScore);
    }
    if (!nullToAbsent || popularity != null) {
      map['popularity'] = Variable<int>(popularity);
    }
    if (!nullToAbsent || genres != null) {
      map['genres'] = Variable<String>(genres);
    }
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    if (!nullToAbsent || synopsis != null) {
      map['synopsis'] = Variable<String>(synopsis);
    }
    if (!nullToAbsent || relations != null) {
      map['relations'] = Variable<String>(relations);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  MangaCacheTableCompanion toCompanion(bool nullToAbsent) {
    return MangaCacheTableCompanion(
      anilistId: Value(anilistId),
      titleRomaji: Value(titleRomaji),
      titleEnglish: titleEnglish == null && nullToAbsent
          ? const Value.absent()
          : Value(titleEnglish),
      titleNative: titleNative == null && nullToAbsent
          ? const Value.absent()
          : Value(titleNative),
      synonyms: synonyms == null && nullToAbsent
          ? const Value.absent()
          : Value(synonyms),
      coverImageUrl: coverImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverImageUrl),
      bannerImageUrl: bannerImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(bannerImageUrl),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      format: format == null && nullToAbsent
          ? const Value.absent()
          : Value(format),
      countryOfOrigin: countryOfOrigin == null && nullToAbsent
          ? const Value.absent()
          : Value(countryOfOrigin),
      originalLanguage: originalLanguage == null && nullToAbsent
          ? const Value.absent()
          : Value(originalLanguage),
      releaseYear: releaseYear == null && nullToAbsent
          ? const Value.absent()
          : Value(releaseYear),
      totalChapters: totalChapters == null && nullToAbsent
          ? const Value.absent()
          : Value(totalChapters),
      totalVolumes: totalVolumes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalVolumes),
      averageScore: averageScore == null && nullToAbsent
          ? const Value.absent()
          : Value(averageScore),
      popularity: popularity == null && nullToAbsent
          ? const Value.absent()
          : Value(popularity),
      genres: genres == null && nullToAbsent
          ? const Value.absent()
          : Value(genres),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      synopsis: synopsis == null && nullToAbsent
          ? const Value.absent()
          : Value(synopsis),
      relations: relations == null && nullToAbsent
          ? const Value.absent()
          : Value(relations),
      updatedAt: Value(updatedAt),
    );
  }

  factory MangaCacheTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MangaCacheTableData(
      anilistId: serializer.fromJson<int>(json['anilistId']),
      titleRomaji: serializer.fromJson<String>(json['titleRomaji']),
      titleEnglish: serializer.fromJson<String?>(json['titleEnglish']),
      titleNative: serializer.fromJson<String?>(json['titleNative']),
      synonyms: serializer.fromJson<String?>(json['synonyms']),
      coverImageUrl: serializer.fromJson<String?>(json['coverImageUrl']),
      bannerImageUrl: serializer.fromJson<String?>(json['bannerImageUrl']),
      status: serializer.fromJson<String?>(json['status']),
      format: serializer.fromJson<String?>(json['format']),
      countryOfOrigin: serializer.fromJson<String?>(json['countryOfOrigin']),
      originalLanguage: serializer.fromJson<String?>(json['originalLanguage']),
      releaseYear: serializer.fromJson<int?>(json['releaseYear']),
      totalChapters: serializer.fromJson<int?>(json['totalChapters']),
      totalVolumes: serializer.fromJson<int?>(json['totalVolumes']),
      averageScore: serializer.fromJson<int?>(json['averageScore']),
      popularity: serializer.fromJson<int?>(json['popularity']),
      genres: serializer.fromJson<String?>(json['genres']),
      tags: serializer.fromJson<String?>(json['tags']),
      synopsis: serializer.fromJson<String?>(json['synopsis']),
      relations: serializer.fromJson<String?>(json['relations']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'anilistId': serializer.toJson<int>(anilistId),
      'titleRomaji': serializer.toJson<String>(titleRomaji),
      'titleEnglish': serializer.toJson<String?>(titleEnglish),
      'titleNative': serializer.toJson<String?>(titleNative),
      'synonyms': serializer.toJson<String?>(synonyms),
      'coverImageUrl': serializer.toJson<String?>(coverImageUrl),
      'bannerImageUrl': serializer.toJson<String?>(bannerImageUrl),
      'status': serializer.toJson<String?>(status),
      'format': serializer.toJson<String?>(format),
      'countryOfOrigin': serializer.toJson<String?>(countryOfOrigin),
      'originalLanguage': serializer.toJson<String?>(originalLanguage),
      'releaseYear': serializer.toJson<int?>(releaseYear),
      'totalChapters': serializer.toJson<int?>(totalChapters),
      'totalVolumes': serializer.toJson<int?>(totalVolumes),
      'averageScore': serializer.toJson<int?>(averageScore),
      'popularity': serializer.toJson<int?>(popularity),
      'genres': serializer.toJson<String?>(genres),
      'tags': serializer.toJson<String?>(tags),
      'synopsis': serializer.toJson<String?>(synopsis),
      'relations': serializer.toJson<String?>(relations),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  MangaCacheTableData copyWith({
    int? anilistId,
    String? titleRomaji,
    Value<String?> titleEnglish = const Value.absent(),
    Value<String?> titleNative = const Value.absent(),
    Value<String?> synonyms = const Value.absent(),
    Value<String?> coverImageUrl = const Value.absent(),
    Value<String?> bannerImageUrl = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<String?> format = const Value.absent(),
    Value<String?> countryOfOrigin = const Value.absent(),
    Value<String?> originalLanguage = const Value.absent(),
    Value<int?> releaseYear = const Value.absent(),
    Value<int?> totalChapters = const Value.absent(),
    Value<int?> totalVolumes = const Value.absent(),
    Value<int?> averageScore = const Value.absent(),
    Value<int?> popularity = const Value.absent(),
    Value<String?> genres = const Value.absent(),
    Value<String?> tags = const Value.absent(),
    Value<String?> synopsis = const Value.absent(),
    Value<String?> relations = const Value.absent(),
    int? updatedAt,
  }) => MangaCacheTableData(
    anilistId: anilistId ?? this.anilistId,
    titleRomaji: titleRomaji ?? this.titleRomaji,
    titleEnglish: titleEnglish.present ? titleEnglish.value : this.titleEnglish,
    titleNative: titleNative.present ? titleNative.value : this.titleNative,
    synonyms: synonyms.present ? synonyms.value : this.synonyms,
    coverImageUrl: coverImageUrl.present
        ? coverImageUrl.value
        : this.coverImageUrl,
    bannerImageUrl: bannerImageUrl.present
        ? bannerImageUrl.value
        : this.bannerImageUrl,
    status: status.present ? status.value : this.status,
    format: format.present ? format.value : this.format,
    countryOfOrigin: countryOfOrigin.present
        ? countryOfOrigin.value
        : this.countryOfOrigin,
    originalLanguage: originalLanguage.present
        ? originalLanguage.value
        : this.originalLanguage,
    releaseYear: releaseYear.present ? releaseYear.value : this.releaseYear,
    totalChapters: totalChapters.present
        ? totalChapters.value
        : this.totalChapters,
    totalVolumes: totalVolumes.present ? totalVolumes.value : this.totalVolumes,
    averageScore: averageScore.present ? averageScore.value : this.averageScore,
    popularity: popularity.present ? popularity.value : this.popularity,
    genres: genres.present ? genres.value : this.genres,
    tags: tags.present ? tags.value : this.tags,
    synopsis: synopsis.present ? synopsis.value : this.synopsis,
    relations: relations.present ? relations.value : this.relations,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MangaCacheTableData copyWithCompanion(MangaCacheTableCompanion data) {
    return MangaCacheTableData(
      anilistId: data.anilistId.present ? data.anilistId.value : this.anilistId,
      titleRomaji: data.titleRomaji.present
          ? data.titleRomaji.value
          : this.titleRomaji,
      titleEnglish: data.titleEnglish.present
          ? data.titleEnglish.value
          : this.titleEnglish,
      titleNative: data.titleNative.present
          ? data.titleNative.value
          : this.titleNative,
      synonyms: data.synonyms.present ? data.synonyms.value : this.synonyms,
      coverImageUrl: data.coverImageUrl.present
          ? data.coverImageUrl.value
          : this.coverImageUrl,
      bannerImageUrl: data.bannerImageUrl.present
          ? data.bannerImageUrl.value
          : this.bannerImageUrl,
      status: data.status.present ? data.status.value : this.status,
      format: data.format.present ? data.format.value : this.format,
      countryOfOrigin: data.countryOfOrigin.present
          ? data.countryOfOrigin.value
          : this.countryOfOrigin,
      originalLanguage: data.originalLanguage.present
          ? data.originalLanguage.value
          : this.originalLanguage,
      releaseYear: data.releaseYear.present
          ? data.releaseYear.value
          : this.releaseYear,
      totalChapters: data.totalChapters.present
          ? data.totalChapters.value
          : this.totalChapters,
      totalVolumes: data.totalVolumes.present
          ? data.totalVolumes.value
          : this.totalVolumes,
      averageScore: data.averageScore.present
          ? data.averageScore.value
          : this.averageScore,
      popularity: data.popularity.present
          ? data.popularity.value
          : this.popularity,
      genres: data.genres.present ? data.genres.value : this.genres,
      tags: data.tags.present ? data.tags.value : this.tags,
      synopsis: data.synopsis.present ? data.synopsis.value : this.synopsis,
      relations: data.relations.present ? data.relations.value : this.relations,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MangaCacheTableData(')
          ..write('anilistId: $anilistId, ')
          ..write('titleRomaji: $titleRomaji, ')
          ..write('titleEnglish: $titleEnglish, ')
          ..write('titleNative: $titleNative, ')
          ..write('synonyms: $synonyms, ')
          ..write('coverImageUrl: $coverImageUrl, ')
          ..write('bannerImageUrl: $bannerImageUrl, ')
          ..write('status: $status, ')
          ..write('format: $format, ')
          ..write('countryOfOrigin: $countryOfOrigin, ')
          ..write('originalLanguage: $originalLanguage, ')
          ..write('releaseYear: $releaseYear, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('totalVolumes: $totalVolumes, ')
          ..write('averageScore: $averageScore, ')
          ..write('popularity: $popularity, ')
          ..write('genres: $genres, ')
          ..write('tags: $tags, ')
          ..write('synopsis: $synopsis, ')
          ..write('relations: $relations, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    anilistId,
    titleRomaji,
    titleEnglish,
    titleNative,
    synonyms,
    coverImageUrl,
    bannerImageUrl,
    status,
    format,
    countryOfOrigin,
    originalLanguage,
    releaseYear,
    totalChapters,
    totalVolumes,
    averageScore,
    popularity,
    genres,
    tags,
    synopsis,
    relations,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MangaCacheTableData &&
          other.anilistId == this.anilistId &&
          other.titleRomaji == this.titleRomaji &&
          other.titleEnglish == this.titleEnglish &&
          other.titleNative == this.titleNative &&
          other.synonyms == this.synonyms &&
          other.coverImageUrl == this.coverImageUrl &&
          other.bannerImageUrl == this.bannerImageUrl &&
          other.status == this.status &&
          other.format == this.format &&
          other.countryOfOrigin == this.countryOfOrigin &&
          other.originalLanguage == this.originalLanguage &&
          other.releaseYear == this.releaseYear &&
          other.totalChapters == this.totalChapters &&
          other.totalVolumes == this.totalVolumes &&
          other.averageScore == this.averageScore &&
          other.popularity == this.popularity &&
          other.genres == this.genres &&
          other.tags == this.tags &&
          other.synopsis == this.synopsis &&
          other.relations == this.relations &&
          other.updatedAt == this.updatedAt);
}

class MangaCacheTableCompanion extends UpdateCompanion<MangaCacheTableData> {
  final Value<int> anilistId;
  final Value<String> titleRomaji;
  final Value<String?> titleEnglish;
  final Value<String?> titleNative;
  final Value<String?> synonyms;
  final Value<String?> coverImageUrl;
  final Value<String?> bannerImageUrl;
  final Value<String?> status;
  final Value<String?> format;
  final Value<String?> countryOfOrigin;
  final Value<String?> originalLanguage;
  final Value<int?> releaseYear;
  final Value<int?> totalChapters;
  final Value<int?> totalVolumes;
  final Value<int?> averageScore;
  final Value<int?> popularity;
  final Value<String?> genres;
  final Value<String?> tags;
  final Value<String?> synopsis;
  final Value<String?> relations;
  final Value<int> updatedAt;
  const MangaCacheTableCompanion({
    this.anilistId = const Value.absent(),
    this.titleRomaji = const Value.absent(),
    this.titleEnglish = const Value.absent(),
    this.titleNative = const Value.absent(),
    this.synonyms = const Value.absent(),
    this.coverImageUrl = const Value.absent(),
    this.bannerImageUrl = const Value.absent(),
    this.status = const Value.absent(),
    this.format = const Value.absent(),
    this.countryOfOrigin = const Value.absent(),
    this.originalLanguage = const Value.absent(),
    this.releaseYear = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.totalVolumes = const Value.absent(),
    this.averageScore = const Value.absent(),
    this.popularity = const Value.absent(),
    this.genres = const Value.absent(),
    this.tags = const Value.absent(),
    this.synopsis = const Value.absent(),
    this.relations = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  MangaCacheTableCompanion.insert({
    this.anilistId = const Value.absent(),
    required String titleRomaji,
    this.titleEnglish = const Value.absent(),
    this.titleNative = const Value.absent(),
    this.synonyms = const Value.absent(),
    this.coverImageUrl = const Value.absent(),
    this.bannerImageUrl = const Value.absent(),
    this.status = const Value.absent(),
    this.format = const Value.absent(),
    this.countryOfOrigin = const Value.absent(),
    this.originalLanguage = const Value.absent(),
    this.releaseYear = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.totalVolumes = const Value.absent(),
    this.averageScore = const Value.absent(),
    this.popularity = const Value.absent(),
    this.genres = const Value.absent(),
    this.tags = const Value.absent(),
    this.synopsis = const Value.absent(),
    this.relations = const Value.absent(),
    required int updatedAt,
  }) : titleRomaji = Value(titleRomaji),
       updatedAt = Value(updatedAt);
  static Insertable<MangaCacheTableData> custom({
    Expression<int>? anilistId,
    Expression<String>? titleRomaji,
    Expression<String>? titleEnglish,
    Expression<String>? titleNative,
    Expression<String>? synonyms,
    Expression<String>? coverImageUrl,
    Expression<String>? bannerImageUrl,
    Expression<String>? status,
    Expression<String>? format,
    Expression<String>? countryOfOrigin,
    Expression<String>? originalLanguage,
    Expression<int>? releaseYear,
    Expression<int>? totalChapters,
    Expression<int>? totalVolumes,
    Expression<int>? averageScore,
    Expression<int>? popularity,
    Expression<String>? genres,
    Expression<String>? tags,
    Expression<String>? synopsis,
    Expression<String>? relations,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (anilistId != null) 'anilist_id': anilistId,
      if (titleRomaji != null) 'title_romaji': titleRomaji,
      if (titleEnglish != null) 'title_english': titleEnglish,
      if (titleNative != null) 'title_native': titleNative,
      if (synonyms != null) 'synonyms': synonyms,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      if (bannerImageUrl != null) 'banner_image_url': bannerImageUrl,
      if (status != null) 'status': status,
      if (format != null) 'format': format,
      if (countryOfOrigin != null) 'country_of_origin': countryOfOrigin,
      if (originalLanguage != null) 'original_language': originalLanguage,
      if (releaseYear != null) 'release_year': releaseYear,
      if (totalChapters != null) 'total_chapters': totalChapters,
      if (totalVolumes != null) 'total_volumes': totalVolumes,
      if (averageScore != null) 'average_score': averageScore,
      if (popularity != null) 'popularity': popularity,
      if (genres != null) 'genres': genres,
      if (tags != null) 'tags': tags,
      if (synopsis != null) 'synopsis': synopsis,
      if (relations != null) 'relations': relations,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  MangaCacheTableCompanion copyWith({
    Value<int>? anilistId,
    Value<String>? titleRomaji,
    Value<String?>? titleEnglish,
    Value<String?>? titleNative,
    Value<String?>? synonyms,
    Value<String?>? coverImageUrl,
    Value<String?>? bannerImageUrl,
    Value<String?>? status,
    Value<String?>? format,
    Value<String?>? countryOfOrigin,
    Value<String?>? originalLanguage,
    Value<int?>? releaseYear,
    Value<int?>? totalChapters,
    Value<int?>? totalVolumes,
    Value<int?>? averageScore,
    Value<int?>? popularity,
    Value<String?>? genres,
    Value<String?>? tags,
    Value<String?>? synopsis,
    Value<String?>? relations,
    Value<int>? updatedAt,
  }) {
    return MangaCacheTableCompanion(
      anilistId: anilistId ?? this.anilistId,
      titleRomaji: titleRomaji ?? this.titleRomaji,
      titleEnglish: titleEnglish ?? this.titleEnglish,
      titleNative: titleNative ?? this.titleNative,
      synonyms: synonyms ?? this.synonyms,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      status: status ?? this.status,
      format: format ?? this.format,
      countryOfOrigin: countryOfOrigin ?? this.countryOfOrigin,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      releaseYear: releaseYear ?? this.releaseYear,
      totalChapters: totalChapters ?? this.totalChapters,
      totalVolumes: totalVolumes ?? this.totalVolumes,
      averageScore: averageScore ?? this.averageScore,
      popularity: popularity ?? this.popularity,
      genres: genres ?? this.genres,
      tags: tags ?? this.tags,
      synopsis: synopsis ?? this.synopsis,
      relations: relations ?? this.relations,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (anilistId.present) {
      map['anilist_id'] = Variable<int>(anilistId.value);
    }
    if (titleRomaji.present) {
      map['title_romaji'] = Variable<String>(titleRomaji.value);
    }
    if (titleEnglish.present) {
      map['title_english'] = Variable<String>(titleEnglish.value);
    }
    if (titleNative.present) {
      map['title_native'] = Variable<String>(titleNative.value);
    }
    if (synonyms.present) {
      map['synonyms'] = Variable<String>(synonyms.value);
    }
    if (coverImageUrl.present) {
      map['cover_image_url'] = Variable<String>(coverImageUrl.value);
    }
    if (bannerImageUrl.present) {
      map['banner_image_url'] = Variable<String>(bannerImageUrl.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (countryOfOrigin.present) {
      map['country_of_origin'] = Variable<String>(countryOfOrigin.value);
    }
    if (originalLanguage.present) {
      map['original_language'] = Variable<String>(originalLanguage.value);
    }
    if (releaseYear.present) {
      map['release_year'] = Variable<int>(releaseYear.value);
    }
    if (totalChapters.present) {
      map['total_chapters'] = Variable<int>(totalChapters.value);
    }
    if (totalVolumes.present) {
      map['total_volumes'] = Variable<int>(totalVolumes.value);
    }
    if (averageScore.present) {
      map['average_score'] = Variable<int>(averageScore.value);
    }
    if (popularity.present) {
      map['popularity'] = Variable<int>(popularity.value);
    }
    if (genres.present) {
      map['genres'] = Variable<String>(genres.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (synopsis.present) {
      map['synopsis'] = Variable<String>(synopsis.value);
    }
    if (relations.present) {
      map['relations'] = Variable<String>(relations.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MangaCacheTableCompanion(')
          ..write('anilistId: $anilistId, ')
          ..write('titleRomaji: $titleRomaji, ')
          ..write('titleEnglish: $titleEnglish, ')
          ..write('titleNative: $titleNative, ')
          ..write('synonyms: $synonyms, ')
          ..write('coverImageUrl: $coverImageUrl, ')
          ..write('bannerImageUrl: $bannerImageUrl, ')
          ..write('status: $status, ')
          ..write('format: $format, ')
          ..write('countryOfOrigin: $countryOfOrigin, ')
          ..write('originalLanguage: $originalLanguage, ')
          ..write('releaseYear: $releaseYear, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('totalVolumes: $totalVolumes, ')
          ..write('averageScore: $averageScore, ')
          ..write('popularity: $popularity, ')
          ..write('genres: $genres, ')
          ..write('tags: $tags, ')
          ..write('synopsis: $synopsis, ')
          ..write('relations: $relations, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $MangaChapterTableTable extends MangaChapterTable
    with TableInfo<$MangaChapterTableTable, MangaChapterTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MangaChapterTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceChapterIdMeta = const VerificationMeta(
    'sourceChapterId',
  );
  @override
  late final GeneratedColumn<String> sourceChapterId = GeneratedColumn<String>(
    'source_chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mangaAnilistIdMeta = const VerificationMeta(
    'mangaAnilistId',
  );
  @override
  late final GeneratedColumn<int> mangaAnilistId = GeneratedColumn<int>(
    'manga_anilist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMangaIdMeta = const VerificationMeta(
    'sourceMangaId',
  );
  @override
  late final GeneratedColumn<String> sourceMangaId = GeneratedColumn<String>(
    'source_manga_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<double> number = GeneratedColumn<double>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.double,
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
  static const VerificationMeta _volumeMeta = const VerificationMeta('volume');
  @override
  late final GeneratedColumn<int> volume = GeneratedColumn<int>(
    'volume',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('en'),
  );
  static const VerificationMeta _scanlatorMeta = const VerificationMeta(
    'scanlator',
  );
  @override
  late final GeneratedColumn<String> scanlator = GeneratedColumn<String>(
    'scanlator',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<int> publishedAt = GeneratedColumn<int>(
    'published_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    sourceId,
    sourceChapterId,
    mangaAnilistId,
    sourceMangaId,
    number,
    title,
    volume,
    language,
    scanlator,
    publishedAt,
    pageCount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'manga_chapter';
  @override
  VerificationContext validateIntegrity(
    Insertable<MangaChapterTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('source_chapter_id')) {
      context.handle(
        _sourceChapterIdMeta,
        sourceChapterId.isAcceptableOrUnknown(
          data['source_chapter_id']!,
          _sourceChapterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceChapterIdMeta);
    }
    if (data.containsKey('manga_anilist_id')) {
      context.handle(
        _mangaAnilistIdMeta,
        mangaAnilistId.isAcceptableOrUnknown(
          data['manga_anilist_id']!,
          _mangaAnilistIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mangaAnilistIdMeta);
    }
    if (data.containsKey('source_manga_id')) {
      context.handle(
        _sourceMangaIdMeta,
        sourceMangaId.isAcceptableOrUnknown(
          data['source_manga_id']!,
          _sourceMangaIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceMangaIdMeta);
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('volume')) {
      context.handle(
        _volumeMeta,
        volume.isAcceptableOrUnknown(data['volume']!, _volumeMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('scanlator')) {
      context.handle(
        _scanlatorMeta,
        scanlator.isAcceptableOrUnknown(data['scanlator']!, _scanlatorMeta),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
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
  Set<GeneratedColumn> get $primaryKey => {sourceId, sourceChapterId};
  @override
  MangaChapterTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MangaChapterTableData(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      sourceChapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_chapter_id'],
      )!,
      mangaAnilistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manga_anilist_id'],
      )!,
      sourceMangaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_manga_id'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}number'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      volume: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}volume'],
      ),
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      scanlator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scanlator'],
      ),
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}published_at'],
      ),
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MangaChapterTableTable createAlias(String alias) {
    return $MangaChapterTableTable(attachedDatabase, alias);
  }
}

class MangaChapterTableData extends DataClass
    implements Insertable<MangaChapterTableData> {
  final String sourceId;
  final String sourceChapterId;
  final int mangaAnilistId;

  /// Source-side opaque manga id (matches the value used by the source
  /// plugin's `getMangaDetail`/`getChapters`). Stored separately from
  /// `mangaAnilistId` so chapter rows survive matching corrections.
  final String sourceMangaId;
  final double number;
  final String? title;
  final int? volume;
  final String language;
  final String? scanlator;
  final int? publishedAt;
  final int? pageCount;
  final int updatedAt;
  const MangaChapterTableData({
    required this.sourceId,
    required this.sourceChapterId,
    required this.mangaAnilistId,
    required this.sourceMangaId,
    required this.number,
    this.title,
    this.volume,
    required this.language,
    this.scanlator,
    this.publishedAt,
    this.pageCount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['source_chapter_id'] = Variable<String>(sourceChapterId);
    map['manga_anilist_id'] = Variable<int>(mangaAnilistId);
    map['source_manga_id'] = Variable<String>(sourceMangaId);
    map['number'] = Variable<double>(number);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || volume != null) {
      map['volume'] = Variable<int>(volume);
    }
    map['language'] = Variable<String>(language);
    if (!nullToAbsent || scanlator != null) {
      map['scanlator'] = Variable<String>(scanlator);
    }
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<int>(publishedAt);
    }
    if (!nullToAbsent || pageCount != null) {
      map['page_count'] = Variable<int>(pageCount);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  MangaChapterTableCompanion toCompanion(bool nullToAbsent) {
    return MangaChapterTableCompanion(
      sourceId: Value(sourceId),
      sourceChapterId: Value(sourceChapterId),
      mangaAnilistId: Value(mangaAnilistId),
      sourceMangaId: Value(sourceMangaId),
      number: Value(number),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      volume: volume == null && nullToAbsent
          ? const Value.absent()
          : Value(volume),
      language: Value(language),
      scanlator: scanlator == null && nullToAbsent
          ? const Value.absent()
          : Value(scanlator),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
      pageCount: pageCount == null && nullToAbsent
          ? const Value.absent()
          : Value(pageCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory MangaChapterTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MangaChapterTableData(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      sourceChapterId: serializer.fromJson<String>(json['sourceChapterId']),
      mangaAnilistId: serializer.fromJson<int>(json['mangaAnilistId']),
      sourceMangaId: serializer.fromJson<String>(json['sourceMangaId']),
      number: serializer.fromJson<double>(json['number']),
      title: serializer.fromJson<String?>(json['title']),
      volume: serializer.fromJson<int?>(json['volume']),
      language: serializer.fromJson<String>(json['language']),
      scanlator: serializer.fromJson<String?>(json['scanlator']),
      publishedAt: serializer.fromJson<int?>(json['publishedAt']),
      pageCount: serializer.fromJson<int?>(json['pageCount']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'sourceChapterId': serializer.toJson<String>(sourceChapterId),
      'mangaAnilistId': serializer.toJson<int>(mangaAnilistId),
      'sourceMangaId': serializer.toJson<String>(sourceMangaId),
      'number': serializer.toJson<double>(number),
      'title': serializer.toJson<String?>(title),
      'volume': serializer.toJson<int?>(volume),
      'language': serializer.toJson<String>(language),
      'scanlator': serializer.toJson<String?>(scanlator),
      'publishedAt': serializer.toJson<int?>(publishedAt),
      'pageCount': serializer.toJson<int?>(pageCount),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  MangaChapterTableData copyWith({
    String? sourceId,
    String? sourceChapterId,
    int? mangaAnilistId,
    String? sourceMangaId,
    double? number,
    Value<String?> title = const Value.absent(),
    Value<int?> volume = const Value.absent(),
    String? language,
    Value<String?> scanlator = const Value.absent(),
    Value<int?> publishedAt = const Value.absent(),
    Value<int?> pageCount = const Value.absent(),
    int? updatedAt,
  }) => MangaChapterTableData(
    sourceId: sourceId ?? this.sourceId,
    sourceChapterId: sourceChapterId ?? this.sourceChapterId,
    mangaAnilistId: mangaAnilistId ?? this.mangaAnilistId,
    sourceMangaId: sourceMangaId ?? this.sourceMangaId,
    number: number ?? this.number,
    title: title.present ? title.value : this.title,
    volume: volume.present ? volume.value : this.volume,
    language: language ?? this.language,
    scanlator: scanlator.present ? scanlator.value : this.scanlator,
    publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
    pageCount: pageCount.present ? pageCount.value : this.pageCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MangaChapterTableData copyWithCompanion(MangaChapterTableCompanion data) {
    return MangaChapterTableData(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourceChapterId: data.sourceChapterId.present
          ? data.sourceChapterId.value
          : this.sourceChapterId,
      mangaAnilistId: data.mangaAnilistId.present
          ? data.mangaAnilistId.value
          : this.mangaAnilistId,
      sourceMangaId: data.sourceMangaId.present
          ? data.sourceMangaId.value
          : this.sourceMangaId,
      number: data.number.present ? data.number.value : this.number,
      title: data.title.present ? data.title.value : this.title,
      volume: data.volume.present ? data.volume.value : this.volume,
      language: data.language.present ? data.language.value : this.language,
      scanlator: data.scanlator.present ? data.scanlator.value : this.scanlator,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MangaChapterTableData(')
          ..write('sourceId: $sourceId, ')
          ..write('sourceChapterId: $sourceChapterId, ')
          ..write('mangaAnilistId: $mangaAnilistId, ')
          ..write('sourceMangaId: $sourceMangaId, ')
          ..write('number: $number, ')
          ..write('title: $title, ')
          ..write('volume: $volume, ')
          ..write('language: $language, ')
          ..write('scanlator: $scanlator, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('pageCount: $pageCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    sourceChapterId,
    mangaAnilistId,
    sourceMangaId,
    number,
    title,
    volume,
    language,
    scanlator,
    publishedAt,
    pageCount,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MangaChapterTableData &&
          other.sourceId == this.sourceId &&
          other.sourceChapterId == this.sourceChapterId &&
          other.mangaAnilistId == this.mangaAnilistId &&
          other.sourceMangaId == this.sourceMangaId &&
          other.number == this.number &&
          other.title == this.title &&
          other.volume == this.volume &&
          other.language == this.language &&
          other.scanlator == this.scanlator &&
          other.publishedAt == this.publishedAt &&
          other.pageCount == this.pageCount &&
          other.updatedAt == this.updatedAt);
}

class MangaChapterTableCompanion
    extends UpdateCompanion<MangaChapterTableData> {
  final Value<String> sourceId;
  final Value<String> sourceChapterId;
  final Value<int> mangaAnilistId;
  final Value<String> sourceMangaId;
  final Value<double> number;
  final Value<String?> title;
  final Value<int?> volume;
  final Value<String> language;
  final Value<String?> scanlator;
  final Value<int?> publishedAt;
  final Value<int?> pageCount;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const MangaChapterTableCompanion({
    this.sourceId = const Value.absent(),
    this.sourceChapterId = const Value.absent(),
    this.mangaAnilistId = const Value.absent(),
    this.sourceMangaId = const Value.absent(),
    this.number = const Value.absent(),
    this.title = const Value.absent(),
    this.volume = const Value.absent(),
    this.language = const Value.absent(),
    this.scanlator = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MangaChapterTableCompanion.insert({
    required String sourceId,
    required String sourceChapterId,
    required int mangaAnilistId,
    required String sourceMangaId,
    required double number,
    this.title = const Value.absent(),
    this.volume = const Value.absent(),
    this.language = const Value.absent(),
    this.scanlator = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.pageCount = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       sourceChapterId = Value(sourceChapterId),
       mangaAnilistId = Value(mangaAnilistId),
       sourceMangaId = Value(sourceMangaId),
       number = Value(number),
       updatedAt = Value(updatedAt);
  static Insertable<MangaChapterTableData> custom({
    Expression<String>? sourceId,
    Expression<String>? sourceChapterId,
    Expression<int>? mangaAnilistId,
    Expression<String>? sourceMangaId,
    Expression<double>? number,
    Expression<String>? title,
    Expression<int>? volume,
    Expression<String>? language,
    Expression<String>? scanlator,
    Expression<int>? publishedAt,
    Expression<int>? pageCount,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (sourceChapterId != null) 'source_chapter_id': sourceChapterId,
      if (mangaAnilistId != null) 'manga_anilist_id': mangaAnilistId,
      if (sourceMangaId != null) 'source_manga_id': sourceMangaId,
      if (number != null) 'number': number,
      if (title != null) 'title': title,
      if (volume != null) 'volume': volume,
      if (language != null) 'language': language,
      if (scanlator != null) 'scanlator': scanlator,
      if (publishedAt != null) 'published_at': publishedAt,
      if (pageCount != null) 'page_count': pageCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MangaChapterTableCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? sourceChapterId,
    Value<int>? mangaAnilistId,
    Value<String>? sourceMangaId,
    Value<double>? number,
    Value<String?>? title,
    Value<int?>? volume,
    Value<String>? language,
    Value<String?>? scanlator,
    Value<int?>? publishedAt,
    Value<int?>? pageCount,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return MangaChapterTableCompanion(
      sourceId: sourceId ?? this.sourceId,
      sourceChapterId: sourceChapterId ?? this.sourceChapterId,
      mangaAnilistId: mangaAnilistId ?? this.mangaAnilistId,
      sourceMangaId: sourceMangaId ?? this.sourceMangaId,
      number: number ?? this.number,
      title: title ?? this.title,
      volume: volume ?? this.volume,
      language: language ?? this.language,
      scanlator: scanlator ?? this.scanlator,
      publishedAt: publishedAt ?? this.publishedAt,
      pageCount: pageCount ?? this.pageCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sourceChapterId.present) {
      map['source_chapter_id'] = Variable<String>(sourceChapterId.value);
    }
    if (mangaAnilistId.present) {
      map['manga_anilist_id'] = Variable<int>(mangaAnilistId.value);
    }
    if (sourceMangaId.present) {
      map['source_manga_id'] = Variable<String>(sourceMangaId.value);
    }
    if (number.present) {
      map['number'] = Variable<double>(number.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (volume.present) {
      map['volume'] = Variable<int>(volume.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (scanlator.present) {
      map['scanlator'] = Variable<String>(scanlator.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<int>(publishedAt.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
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
    return (StringBuffer('MangaChapterTableCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('sourceChapterId: $sourceChapterId, ')
          ..write('mangaAnilistId: $mangaAnilistId, ')
          ..write('sourceMangaId: $sourceMangaId, ')
          ..write('number: $number, ')
          ..write('title: $title, ')
          ..write('volume: $volume, ')
          ..write('language: $language, ')
          ..write('scanlator: $scanlator, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('pageCount: $pageCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MangaProgressTableTable extends MangaProgressTable
    with TableInfo<$MangaProgressTableTable, MangaProgressTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MangaProgressTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mangaAnilistIdMeta = const VerificationMeta(
    'mangaAnilistId',
  );
  @override
  late final GeneratedColumn<int> mangaAnilistId = GeneratedColumn<int>(
    'manga_anilist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceChapterIdMeta = const VerificationMeta(
    'sourceChapterId',
  );
  @override
  late final GeneratedColumn<String> sourceChapterId = GeneratedColumn<String>(
    'source_chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterNumberMeta = const VerificationMeta(
    'chapterNumber',
  );
  @override
  late final GeneratedColumn<double> chapterNumber = GeneratedColumn<double>(
    'chapter_number',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _scrollOffsetMeta = const VerificationMeta(
    'scrollOffset',
  );
  @override
  late final GeneratedColumn<double> scrollOffset = GeneratedColumn<double>(
    'scroll_offset',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readStateMeta = const VerificationMeta(
    'readState',
  );
  @override
  late final GeneratedColumn<String> readState = GeneratedColumn<String>(
    'read_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unread'),
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
    mangaAnilistId,
    sourceId,
    sourceChapterId,
    chapterNumber,
    pageIndex,
    scrollOffset,
    readState,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'manga_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<MangaProgressTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('manga_anilist_id')) {
      context.handle(
        _mangaAnilistIdMeta,
        mangaAnilistId.isAcceptableOrUnknown(
          data['manga_anilist_id']!,
          _mangaAnilistIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mangaAnilistIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('source_chapter_id')) {
      context.handle(
        _sourceChapterIdMeta,
        sourceChapterId.isAcceptableOrUnknown(
          data['source_chapter_id']!,
          _sourceChapterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceChapterIdMeta);
    }
    if (data.containsKey('chapter_number')) {
      context.handle(
        _chapterNumberMeta,
        chapterNumber.isAcceptableOrUnknown(
          data['chapter_number']!,
          _chapterNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterNumberMeta);
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    }
    if (data.containsKey('scroll_offset')) {
      context.handle(
        _scrollOffsetMeta,
        scrollOffset.isAcceptableOrUnknown(
          data['scroll_offset']!,
          _scrollOffsetMeta,
        ),
      );
    }
    if (data.containsKey('read_state')) {
      context.handle(
        _readStateMeta,
        readState.isAcceptableOrUnknown(data['read_state']!, _readStateMeta),
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
  Set<GeneratedColumn> get $primaryKey => {
    mangaAnilistId,
    sourceId,
    sourceChapterId,
  };
  @override
  MangaProgressTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MangaProgressTableData(
      mangaAnilistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manga_anilist_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      sourceChapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_chapter_id'],
      )!,
      chapterNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}chapter_number'],
      )!,
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      scrollOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}scroll_offset'],
      ),
      readState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}read_state'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MangaProgressTableTable createAlias(String alias) {
    return $MangaProgressTableTable(attachedDatabase, alias);
  }
}

class MangaProgressTableData extends DataClass
    implements Insertable<MangaProgressTableData> {
  final int mangaAnilistId;
  final String sourceId;
  final String sourceChapterId;
  final double chapterNumber;
  final int pageIndex;
  final double? scrollOffset;

  /// `unread` / `reading` / `completed`.
  final String readState;
  final int updatedAt;
  const MangaProgressTableData({
    required this.mangaAnilistId,
    required this.sourceId,
    required this.sourceChapterId,
    required this.chapterNumber,
    required this.pageIndex,
    this.scrollOffset,
    required this.readState,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['manga_anilist_id'] = Variable<int>(mangaAnilistId);
    map['source_id'] = Variable<String>(sourceId);
    map['source_chapter_id'] = Variable<String>(sourceChapterId);
    map['chapter_number'] = Variable<double>(chapterNumber);
    map['page_index'] = Variable<int>(pageIndex);
    if (!nullToAbsent || scrollOffset != null) {
      map['scroll_offset'] = Variable<double>(scrollOffset);
    }
    map['read_state'] = Variable<String>(readState);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  MangaProgressTableCompanion toCompanion(bool nullToAbsent) {
    return MangaProgressTableCompanion(
      mangaAnilistId: Value(mangaAnilistId),
      sourceId: Value(sourceId),
      sourceChapterId: Value(sourceChapterId),
      chapterNumber: Value(chapterNumber),
      pageIndex: Value(pageIndex),
      scrollOffset: scrollOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(scrollOffset),
      readState: Value(readState),
      updatedAt: Value(updatedAt),
    );
  }

  factory MangaProgressTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MangaProgressTableData(
      mangaAnilistId: serializer.fromJson<int>(json['mangaAnilistId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      sourceChapterId: serializer.fromJson<String>(json['sourceChapterId']),
      chapterNumber: serializer.fromJson<double>(json['chapterNumber']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      scrollOffset: serializer.fromJson<double?>(json['scrollOffset']),
      readState: serializer.fromJson<String>(json['readState']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mangaAnilistId': serializer.toJson<int>(mangaAnilistId),
      'sourceId': serializer.toJson<String>(sourceId),
      'sourceChapterId': serializer.toJson<String>(sourceChapterId),
      'chapterNumber': serializer.toJson<double>(chapterNumber),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'scrollOffset': serializer.toJson<double?>(scrollOffset),
      'readState': serializer.toJson<String>(readState),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  MangaProgressTableData copyWith({
    int? mangaAnilistId,
    String? sourceId,
    String? sourceChapterId,
    double? chapterNumber,
    int? pageIndex,
    Value<double?> scrollOffset = const Value.absent(),
    String? readState,
    int? updatedAt,
  }) => MangaProgressTableData(
    mangaAnilistId: mangaAnilistId ?? this.mangaAnilistId,
    sourceId: sourceId ?? this.sourceId,
    sourceChapterId: sourceChapterId ?? this.sourceChapterId,
    chapterNumber: chapterNumber ?? this.chapterNumber,
    pageIndex: pageIndex ?? this.pageIndex,
    scrollOffset: scrollOffset.present ? scrollOffset.value : this.scrollOffset,
    readState: readState ?? this.readState,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MangaProgressTableData copyWithCompanion(MangaProgressTableCompanion data) {
    return MangaProgressTableData(
      mangaAnilistId: data.mangaAnilistId.present
          ? data.mangaAnilistId.value
          : this.mangaAnilistId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourceChapterId: data.sourceChapterId.present
          ? data.sourceChapterId.value
          : this.sourceChapterId,
      chapterNumber: data.chapterNumber.present
          ? data.chapterNumber.value
          : this.chapterNumber,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      scrollOffset: data.scrollOffset.present
          ? data.scrollOffset.value
          : this.scrollOffset,
      readState: data.readState.present ? data.readState.value : this.readState,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MangaProgressTableData(')
          ..write('mangaAnilistId: $mangaAnilistId, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceChapterId: $sourceChapterId, ')
          ..write('chapterNumber: $chapterNumber, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('scrollOffset: $scrollOffset, ')
          ..write('readState: $readState, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    mangaAnilistId,
    sourceId,
    sourceChapterId,
    chapterNumber,
    pageIndex,
    scrollOffset,
    readState,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MangaProgressTableData &&
          other.mangaAnilistId == this.mangaAnilistId &&
          other.sourceId == this.sourceId &&
          other.sourceChapterId == this.sourceChapterId &&
          other.chapterNumber == this.chapterNumber &&
          other.pageIndex == this.pageIndex &&
          other.scrollOffset == this.scrollOffset &&
          other.readState == this.readState &&
          other.updatedAt == this.updatedAt);
}

class MangaProgressTableCompanion
    extends UpdateCompanion<MangaProgressTableData> {
  final Value<int> mangaAnilistId;
  final Value<String> sourceId;
  final Value<String> sourceChapterId;
  final Value<double> chapterNumber;
  final Value<int> pageIndex;
  final Value<double?> scrollOffset;
  final Value<String> readState;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const MangaProgressTableCompanion({
    this.mangaAnilistId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceChapterId = const Value.absent(),
    this.chapterNumber = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.scrollOffset = const Value.absent(),
    this.readState = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MangaProgressTableCompanion.insert({
    required int mangaAnilistId,
    required String sourceId,
    required String sourceChapterId,
    required double chapterNumber,
    this.pageIndex = const Value.absent(),
    this.scrollOffset = const Value.absent(),
    this.readState = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : mangaAnilistId = Value(mangaAnilistId),
       sourceId = Value(sourceId),
       sourceChapterId = Value(sourceChapterId),
       chapterNumber = Value(chapterNumber),
       updatedAt = Value(updatedAt);
  static Insertable<MangaProgressTableData> custom({
    Expression<int>? mangaAnilistId,
    Expression<String>? sourceId,
    Expression<String>? sourceChapterId,
    Expression<double>? chapterNumber,
    Expression<int>? pageIndex,
    Expression<double>? scrollOffset,
    Expression<String>? readState,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mangaAnilistId != null) 'manga_anilist_id': mangaAnilistId,
      if (sourceId != null) 'source_id': sourceId,
      if (sourceChapterId != null) 'source_chapter_id': sourceChapterId,
      if (chapterNumber != null) 'chapter_number': chapterNumber,
      if (pageIndex != null) 'page_index': pageIndex,
      if (scrollOffset != null) 'scroll_offset': scrollOffset,
      if (readState != null) 'read_state': readState,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MangaProgressTableCompanion copyWith({
    Value<int>? mangaAnilistId,
    Value<String>? sourceId,
    Value<String>? sourceChapterId,
    Value<double>? chapterNumber,
    Value<int>? pageIndex,
    Value<double?>? scrollOffset,
    Value<String>? readState,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return MangaProgressTableCompanion(
      mangaAnilistId: mangaAnilistId ?? this.mangaAnilistId,
      sourceId: sourceId ?? this.sourceId,
      sourceChapterId: sourceChapterId ?? this.sourceChapterId,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      pageIndex: pageIndex ?? this.pageIndex,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      readState: readState ?? this.readState,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mangaAnilistId.present) {
      map['manga_anilist_id'] = Variable<int>(mangaAnilistId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sourceChapterId.present) {
      map['source_chapter_id'] = Variable<String>(sourceChapterId.value);
    }
    if (chapterNumber.present) {
      map['chapter_number'] = Variable<double>(chapterNumber.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (scrollOffset.present) {
      map['scroll_offset'] = Variable<double>(scrollOffset.value);
    }
    if (readState.present) {
      map['read_state'] = Variable<String>(readState.value);
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
    return (StringBuffer('MangaProgressTableCompanion(')
          ..write('mangaAnilistId: $mangaAnilistId, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceChapterId: $sourceChapterId, ')
          ..write('chapterNumber: $chapterNumber, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('scrollOffset: $scrollOffset, ')
          ..write('readState: $readState, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MangaHistoryTableTable extends MangaHistoryTable
    with TableInfo<$MangaHistoryTableTable, MangaHistoryTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MangaHistoryTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mangaAnilistIdMeta = const VerificationMeta(
    'mangaAnilistId',
  );
  @override
  late final GeneratedColumn<int> mangaAnilistId = GeneratedColumn<int>(
    'manga_anilist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastChapterNumberMeta = const VerificationMeta(
    'lastChapterNumber',
  );
  @override
  late final GeneratedColumn<double> lastChapterNumber =
      GeneratedColumn<double>(
        'last_chapter_number',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastSourceIdMeta = const VerificationMeta(
    'lastSourceId',
  );
  @override
  late final GeneratedColumn<String> lastSourceId = GeneratedColumn<String>(
    'last_source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSourceChapterIdMeta =
      const VerificationMeta('lastSourceChapterId');
  @override
  late final GeneratedColumn<String> lastSourceChapterId =
      GeneratedColumn<String>(
        'last_source_chapter_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastPageIndexMeta = const VerificationMeta(
    'lastPageIndex',
  );
  @override
  late final GeneratedColumn<int> lastPageIndex = GeneratedColumn<int>(
    'last_page_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    mangaAnilistId,
    lastChapterNumber,
    lastSourceId,
    lastSourceChapterId,
    lastPageIndex,
    lastAccessedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'manga_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<MangaHistoryTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('manga_anilist_id')) {
      context.handle(
        _mangaAnilistIdMeta,
        mangaAnilistId.isAcceptableOrUnknown(
          data['manga_anilist_id']!,
          _mangaAnilistIdMeta,
        ),
      );
    }
    if (data.containsKey('last_chapter_number')) {
      context.handle(
        _lastChapterNumberMeta,
        lastChapterNumber.isAcceptableOrUnknown(
          data['last_chapter_number']!,
          _lastChapterNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastChapterNumberMeta);
    }
    if (data.containsKey('last_source_id')) {
      context.handle(
        _lastSourceIdMeta,
        lastSourceId.isAcceptableOrUnknown(
          data['last_source_id']!,
          _lastSourceIdMeta,
        ),
      );
    }
    if (data.containsKey('last_source_chapter_id')) {
      context.handle(
        _lastSourceChapterIdMeta,
        lastSourceChapterId.isAcceptableOrUnknown(
          data['last_source_chapter_id']!,
          _lastSourceChapterIdMeta,
        ),
      );
    }
    if (data.containsKey('last_page_index')) {
      context.handle(
        _lastPageIndexMeta,
        lastPageIndex.isAcceptableOrUnknown(
          data['last_page_index']!,
          _lastPageIndexMeta,
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
  Set<GeneratedColumn> get $primaryKey => {mangaAnilistId};
  @override
  MangaHistoryTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MangaHistoryTableData(
      mangaAnilistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manga_anilist_id'],
      )!,
      lastChapterNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_chapter_number'],
      )!,
      lastSourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_source_id'],
      ),
      lastSourceChapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_source_chapter_id'],
      ),
      lastPageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_page_index'],
      ),
      lastAccessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_accessed_at'],
      )!,
    );
  }

  @override
  $MangaHistoryTableTable createAlias(String alias) {
    return $MangaHistoryTableTable(attachedDatabase, alias);
  }
}

class MangaHistoryTableData extends DataClass
    implements Insertable<MangaHistoryTableData> {
  final int mangaAnilistId;
  final double lastChapterNumber;
  final String? lastSourceId;
  final String? lastSourceChapterId;
  final int? lastPageIndex;
  final int lastAccessedAt;
  const MangaHistoryTableData({
    required this.mangaAnilistId,
    required this.lastChapterNumber,
    this.lastSourceId,
    this.lastSourceChapterId,
    this.lastPageIndex,
    required this.lastAccessedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['manga_anilist_id'] = Variable<int>(mangaAnilistId);
    map['last_chapter_number'] = Variable<double>(lastChapterNumber);
    if (!nullToAbsent || lastSourceId != null) {
      map['last_source_id'] = Variable<String>(lastSourceId);
    }
    if (!nullToAbsent || lastSourceChapterId != null) {
      map['last_source_chapter_id'] = Variable<String>(lastSourceChapterId);
    }
    if (!nullToAbsent || lastPageIndex != null) {
      map['last_page_index'] = Variable<int>(lastPageIndex);
    }
    map['last_accessed_at'] = Variable<int>(lastAccessedAt);
    return map;
  }

  MangaHistoryTableCompanion toCompanion(bool nullToAbsent) {
    return MangaHistoryTableCompanion(
      mangaAnilistId: Value(mangaAnilistId),
      lastChapterNumber: Value(lastChapterNumber),
      lastSourceId: lastSourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSourceId),
      lastSourceChapterId: lastSourceChapterId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSourceChapterId),
      lastPageIndex: lastPageIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPageIndex),
      lastAccessedAt: Value(lastAccessedAt),
    );
  }

  factory MangaHistoryTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MangaHistoryTableData(
      mangaAnilistId: serializer.fromJson<int>(json['mangaAnilistId']),
      lastChapterNumber: serializer.fromJson<double>(json['lastChapterNumber']),
      lastSourceId: serializer.fromJson<String?>(json['lastSourceId']),
      lastSourceChapterId: serializer.fromJson<String?>(
        json['lastSourceChapterId'],
      ),
      lastPageIndex: serializer.fromJson<int?>(json['lastPageIndex']),
      lastAccessedAt: serializer.fromJson<int>(json['lastAccessedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mangaAnilistId': serializer.toJson<int>(mangaAnilistId),
      'lastChapterNumber': serializer.toJson<double>(lastChapterNumber),
      'lastSourceId': serializer.toJson<String?>(lastSourceId),
      'lastSourceChapterId': serializer.toJson<String?>(lastSourceChapterId),
      'lastPageIndex': serializer.toJson<int?>(lastPageIndex),
      'lastAccessedAt': serializer.toJson<int>(lastAccessedAt),
    };
  }

  MangaHistoryTableData copyWith({
    int? mangaAnilistId,
    double? lastChapterNumber,
    Value<String?> lastSourceId = const Value.absent(),
    Value<String?> lastSourceChapterId = const Value.absent(),
    Value<int?> lastPageIndex = const Value.absent(),
    int? lastAccessedAt,
  }) => MangaHistoryTableData(
    mangaAnilistId: mangaAnilistId ?? this.mangaAnilistId,
    lastChapterNumber: lastChapterNumber ?? this.lastChapterNumber,
    lastSourceId: lastSourceId.present ? lastSourceId.value : this.lastSourceId,
    lastSourceChapterId: lastSourceChapterId.present
        ? lastSourceChapterId.value
        : this.lastSourceChapterId,
    lastPageIndex: lastPageIndex.present
        ? lastPageIndex.value
        : this.lastPageIndex,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
  );
  MangaHistoryTableData copyWithCompanion(MangaHistoryTableCompanion data) {
    return MangaHistoryTableData(
      mangaAnilistId: data.mangaAnilistId.present
          ? data.mangaAnilistId.value
          : this.mangaAnilistId,
      lastChapterNumber: data.lastChapterNumber.present
          ? data.lastChapterNumber.value
          : this.lastChapterNumber,
      lastSourceId: data.lastSourceId.present
          ? data.lastSourceId.value
          : this.lastSourceId,
      lastSourceChapterId: data.lastSourceChapterId.present
          ? data.lastSourceChapterId.value
          : this.lastSourceChapterId,
      lastPageIndex: data.lastPageIndex.present
          ? data.lastPageIndex.value
          : this.lastPageIndex,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MangaHistoryTableData(')
          ..write('mangaAnilistId: $mangaAnilistId, ')
          ..write('lastChapterNumber: $lastChapterNumber, ')
          ..write('lastSourceId: $lastSourceId, ')
          ..write('lastSourceChapterId: $lastSourceChapterId, ')
          ..write('lastPageIndex: $lastPageIndex, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    mangaAnilistId,
    lastChapterNumber,
    lastSourceId,
    lastSourceChapterId,
    lastPageIndex,
    lastAccessedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MangaHistoryTableData &&
          other.mangaAnilistId == this.mangaAnilistId &&
          other.lastChapterNumber == this.lastChapterNumber &&
          other.lastSourceId == this.lastSourceId &&
          other.lastSourceChapterId == this.lastSourceChapterId &&
          other.lastPageIndex == this.lastPageIndex &&
          other.lastAccessedAt == this.lastAccessedAt);
}

class MangaHistoryTableCompanion
    extends UpdateCompanion<MangaHistoryTableData> {
  final Value<int> mangaAnilistId;
  final Value<double> lastChapterNumber;
  final Value<String?> lastSourceId;
  final Value<String?> lastSourceChapterId;
  final Value<int?> lastPageIndex;
  final Value<int> lastAccessedAt;
  const MangaHistoryTableCompanion({
    this.mangaAnilistId = const Value.absent(),
    this.lastChapterNumber = const Value.absent(),
    this.lastSourceId = const Value.absent(),
    this.lastSourceChapterId = const Value.absent(),
    this.lastPageIndex = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
  });
  MangaHistoryTableCompanion.insert({
    this.mangaAnilistId = const Value.absent(),
    required double lastChapterNumber,
    this.lastSourceId = const Value.absent(),
    this.lastSourceChapterId = const Value.absent(),
    this.lastPageIndex = const Value.absent(),
    required int lastAccessedAt,
  }) : lastChapterNumber = Value(lastChapterNumber),
       lastAccessedAt = Value(lastAccessedAt);
  static Insertable<MangaHistoryTableData> custom({
    Expression<int>? mangaAnilistId,
    Expression<double>? lastChapterNumber,
    Expression<String>? lastSourceId,
    Expression<String>? lastSourceChapterId,
    Expression<int>? lastPageIndex,
    Expression<int>? lastAccessedAt,
  }) {
    return RawValuesInsertable({
      if (mangaAnilistId != null) 'manga_anilist_id': mangaAnilistId,
      if (lastChapterNumber != null) 'last_chapter_number': lastChapterNumber,
      if (lastSourceId != null) 'last_source_id': lastSourceId,
      if (lastSourceChapterId != null)
        'last_source_chapter_id': lastSourceChapterId,
      if (lastPageIndex != null) 'last_page_index': lastPageIndex,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
    });
  }

  MangaHistoryTableCompanion copyWith({
    Value<int>? mangaAnilistId,
    Value<double>? lastChapterNumber,
    Value<String?>? lastSourceId,
    Value<String?>? lastSourceChapterId,
    Value<int?>? lastPageIndex,
    Value<int>? lastAccessedAt,
  }) {
    return MangaHistoryTableCompanion(
      mangaAnilistId: mangaAnilistId ?? this.mangaAnilistId,
      lastChapterNumber: lastChapterNumber ?? this.lastChapterNumber,
      lastSourceId: lastSourceId ?? this.lastSourceId,
      lastSourceChapterId: lastSourceChapterId ?? this.lastSourceChapterId,
      lastPageIndex: lastPageIndex ?? this.lastPageIndex,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mangaAnilistId.present) {
      map['manga_anilist_id'] = Variable<int>(mangaAnilistId.value);
    }
    if (lastChapterNumber.present) {
      map['last_chapter_number'] = Variable<double>(lastChapterNumber.value);
    }
    if (lastSourceId.present) {
      map['last_source_id'] = Variable<String>(lastSourceId.value);
    }
    if (lastSourceChapterId.present) {
      map['last_source_chapter_id'] = Variable<String>(
        lastSourceChapterId.value,
      );
    }
    if (lastPageIndex.present) {
      map['last_page_index'] = Variable<int>(lastPageIndex.value);
    }
    if (lastAccessedAt.present) {
      map['last_accessed_at'] = Variable<int>(lastAccessedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MangaHistoryTableCompanion(')
          ..write('mangaAnilistId: $mangaAnilistId, ')
          ..write('lastChapterNumber: $lastChapterNumber, ')
          ..write('lastSourceId: $lastSourceId, ')
          ..write('lastSourceChapterId: $lastSourceChapterId, ')
          ..write('lastPageIndex: $lastPageIndex, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }
}

class $MangaLibraryTableTable extends MangaLibraryTable
    with TableInfo<$MangaLibraryTableTable, MangaLibraryTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MangaLibraryTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mangaAnilistIdMeta = const VerificationMeta(
    'mangaAnilistId',
  );
  @override
  late final GeneratedColumn<int> mangaAnilistId = GeneratedColumn<int>(
    'manga_anilist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notifyNewChaptersMeta = const VerificationMeta(
    'notifyNewChapters',
  );
  @override
  late final GeneratedColumn<bool> notifyNewChapters = GeneratedColumn<bool>(
    'notify_new_chapters',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notify_new_chapters" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastNotifiedChapterMeta =
      const VerificationMeta('lastNotifiedChapter');
  @override
  late final GeneratedColumn<double> lastNotifiedChapter =
      GeneratedColumn<double>(
        'last_notified_chapter',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _autoDownloadNewChaptersMeta =
      const VerificationMeta('autoDownloadNewChapters');
  @override
  late final GeneratedColumn<bool> autoDownloadNewChapters =
      GeneratedColumn<bool>(
        'auto_download_new_chapters',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("auto_download_new_chapters" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _preferredLanguageMeta = const VerificationMeta(
    'preferredLanguage',
  );
  @override
  late final GeneratedColumn<String> preferredLanguage =
      GeneratedColumn<String>(
        'preferred_language',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _preferredScanlatorMeta =
      const VerificationMeta('preferredScanlator');
  @override
  late final GeneratedColumn<String> preferredScanlator =
      GeneratedColumn<String>(
        'preferred_scanlator',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _preferredSourceIdMeta = const VerificationMeta(
    'preferredSourceId',
  );
  @override
  late final GeneratedColumn<String> preferredSourceId =
      GeneratedColumn<String>(
        'preferred_source_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    mangaAnilistId,
    addedAt,
    notifyNewChapters,
    lastNotifiedChapter,
    autoDownloadNewChapters,
    preferredLanguage,
    preferredScanlator,
    preferredSourceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'manga_library';
  @override
  VerificationContext validateIntegrity(
    Insertable<MangaLibraryTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('manga_anilist_id')) {
      context.handle(
        _mangaAnilistIdMeta,
        mangaAnilistId.isAcceptableOrUnknown(
          data['manga_anilist_id']!,
          _mangaAnilistIdMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('notify_new_chapters')) {
      context.handle(
        _notifyNewChaptersMeta,
        notifyNewChapters.isAcceptableOrUnknown(
          data['notify_new_chapters']!,
          _notifyNewChaptersMeta,
        ),
      );
    }
    if (data.containsKey('last_notified_chapter')) {
      context.handle(
        _lastNotifiedChapterMeta,
        lastNotifiedChapter.isAcceptableOrUnknown(
          data['last_notified_chapter']!,
          _lastNotifiedChapterMeta,
        ),
      );
    }
    if (data.containsKey('auto_download_new_chapters')) {
      context.handle(
        _autoDownloadNewChaptersMeta,
        autoDownloadNewChapters.isAcceptableOrUnknown(
          data['auto_download_new_chapters']!,
          _autoDownloadNewChaptersMeta,
        ),
      );
    }
    if (data.containsKey('preferred_language')) {
      context.handle(
        _preferredLanguageMeta,
        preferredLanguage.isAcceptableOrUnknown(
          data['preferred_language']!,
          _preferredLanguageMeta,
        ),
      );
    }
    if (data.containsKey('preferred_scanlator')) {
      context.handle(
        _preferredScanlatorMeta,
        preferredScanlator.isAcceptableOrUnknown(
          data['preferred_scanlator']!,
          _preferredScanlatorMeta,
        ),
      );
    }
    if (data.containsKey('preferred_source_id')) {
      context.handle(
        _preferredSourceIdMeta,
        preferredSourceId.isAcceptableOrUnknown(
          data['preferred_source_id']!,
          _preferredSourceIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mangaAnilistId};
  @override
  MangaLibraryTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MangaLibraryTableData(
      mangaAnilistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manga_anilist_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
      notifyNewChapters: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notify_new_chapters'],
      )!,
      lastNotifiedChapter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_notified_chapter'],
      ),
      autoDownloadNewChapters: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_download_new_chapters'],
      )!,
      preferredLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_language'],
      ),
      preferredScanlator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_scanlator'],
      ),
      preferredSourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_source_id'],
      ),
    );
  }

  @override
  $MangaLibraryTableTable createAlias(String alias) {
    return $MangaLibraryTableTable(attachedDatabase, alias);
  }
}

class MangaLibraryTableData extends DataClass
    implements Insertable<MangaLibraryTableData> {
  final int mangaAnilistId;
  final int addedAt;
  final bool notifyNewChapters;

  /// Last chapter number for which a notification was sent (null = never).
  final double? lastNotifiedChapter;
  final bool autoDownloadNewChapters;

  /// BCP-47 preferred language for chapter listings of this manga.
  final String? preferredLanguage;

  /// Preferred scanlator name/id for chapter listings of this manga.
  final String? preferredScanlator;

  /// Preferred source plugin id for chapter listings of this manga
  /// (e.g. `mangadex`, `olympus`). When null, the composite repository
  /// fans out to every registered plugin and dedupes across them. When
  /// non-null, the composite restricts the fan-out to the picked
  /// plugin only.
  final String? preferredSourceId;
  const MangaLibraryTableData({
    required this.mangaAnilistId,
    required this.addedAt,
    required this.notifyNewChapters,
    this.lastNotifiedChapter,
    required this.autoDownloadNewChapters,
    this.preferredLanguage,
    this.preferredScanlator,
    this.preferredSourceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['manga_anilist_id'] = Variable<int>(mangaAnilistId);
    map['added_at'] = Variable<int>(addedAt);
    map['notify_new_chapters'] = Variable<bool>(notifyNewChapters);
    if (!nullToAbsent || lastNotifiedChapter != null) {
      map['last_notified_chapter'] = Variable<double>(lastNotifiedChapter);
    }
    map['auto_download_new_chapters'] = Variable<bool>(autoDownloadNewChapters);
    if (!nullToAbsent || preferredLanguage != null) {
      map['preferred_language'] = Variable<String>(preferredLanguage);
    }
    if (!nullToAbsent || preferredScanlator != null) {
      map['preferred_scanlator'] = Variable<String>(preferredScanlator);
    }
    if (!nullToAbsent || preferredSourceId != null) {
      map['preferred_source_id'] = Variable<String>(preferredSourceId);
    }
    return map;
  }

  MangaLibraryTableCompanion toCompanion(bool nullToAbsent) {
    return MangaLibraryTableCompanion(
      mangaAnilistId: Value(mangaAnilistId),
      addedAt: Value(addedAt),
      notifyNewChapters: Value(notifyNewChapters),
      lastNotifiedChapter: lastNotifiedChapter == null && nullToAbsent
          ? const Value.absent()
          : Value(lastNotifiedChapter),
      autoDownloadNewChapters: Value(autoDownloadNewChapters),
      preferredLanguage: preferredLanguage == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredLanguage),
      preferredScanlator: preferredScanlator == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredScanlator),
      preferredSourceId: preferredSourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredSourceId),
    );
  }

  factory MangaLibraryTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MangaLibraryTableData(
      mangaAnilistId: serializer.fromJson<int>(json['mangaAnilistId']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      notifyNewChapters: serializer.fromJson<bool>(json['notifyNewChapters']),
      lastNotifiedChapter: serializer.fromJson<double?>(
        json['lastNotifiedChapter'],
      ),
      autoDownloadNewChapters: serializer.fromJson<bool>(
        json['autoDownloadNewChapters'],
      ),
      preferredLanguage: serializer.fromJson<String?>(
        json['preferredLanguage'],
      ),
      preferredScanlator: serializer.fromJson<String?>(
        json['preferredScanlator'],
      ),
      preferredSourceId: serializer.fromJson<String?>(
        json['preferredSourceId'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mangaAnilistId': serializer.toJson<int>(mangaAnilistId),
      'addedAt': serializer.toJson<int>(addedAt),
      'notifyNewChapters': serializer.toJson<bool>(notifyNewChapters),
      'lastNotifiedChapter': serializer.toJson<double?>(lastNotifiedChapter),
      'autoDownloadNewChapters': serializer.toJson<bool>(
        autoDownloadNewChapters,
      ),
      'preferredLanguage': serializer.toJson<String?>(preferredLanguage),
      'preferredScanlator': serializer.toJson<String?>(preferredScanlator),
      'preferredSourceId': serializer.toJson<String?>(preferredSourceId),
    };
  }

  MangaLibraryTableData copyWith({
    int? mangaAnilistId,
    int? addedAt,
    bool? notifyNewChapters,
    Value<double?> lastNotifiedChapter = const Value.absent(),
    bool? autoDownloadNewChapters,
    Value<String?> preferredLanguage = const Value.absent(),
    Value<String?> preferredScanlator = const Value.absent(),
    Value<String?> preferredSourceId = const Value.absent(),
  }) => MangaLibraryTableData(
    mangaAnilistId: mangaAnilistId ?? this.mangaAnilistId,
    addedAt: addedAt ?? this.addedAt,
    notifyNewChapters: notifyNewChapters ?? this.notifyNewChapters,
    lastNotifiedChapter: lastNotifiedChapter.present
        ? lastNotifiedChapter.value
        : this.lastNotifiedChapter,
    autoDownloadNewChapters:
        autoDownloadNewChapters ?? this.autoDownloadNewChapters,
    preferredLanguage: preferredLanguage.present
        ? preferredLanguage.value
        : this.preferredLanguage,
    preferredScanlator: preferredScanlator.present
        ? preferredScanlator.value
        : this.preferredScanlator,
    preferredSourceId: preferredSourceId.present
        ? preferredSourceId.value
        : this.preferredSourceId,
  );
  MangaLibraryTableData copyWithCompanion(MangaLibraryTableCompanion data) {
    return MangaLibraryTableData(
      mangaAnilistId: data.mangaAnilistId.present
          ? data.mangaAnilistId.value
          : this.mangaAnilistId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      notifyNewChapters: data.notifyNewChapters.present
          ? data.notifyNewChapters.value
          : this.notifyNewChapters,
      lastNotifiedChapter: data.lastNotifiedChapter.present
          ? data.lastNotifiedChapter.value
          : this.lastNotifiedChapter,
      autoDownloadNewChapters: data.autoDownloadNewChapters.present
          ? data.autoDownloadNewChapters.value
          : this.autoDownloadNewChapters,
      preferredLanguage: data.preferredLanguage.present
          ? data.preferredLanguage.value
          : this.preferredLanguage,
      preferredScanlator: data.preferredScanlator.present
          ? data.preferredScanlator.value
          : this.preferredScanlator,
      preferredSourceId: data.preferredSourceId.present
          ? data.preferredSourceId.value
          : this.preferredSourceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MangaLibraryTableData(')
          ..write('mangaAnilistId: $mangaAnilistId, ')
          ..write('addedAt: $addedAt, ')
          ..write('notifyNewChapters: $notifyNewChapters, ')
          ..write('lastNotifiedChapter: $lastNotifiedChapter, ')
          ..write('autoDownloadNewChapters: $autoDownloadNewChapters, ')
          ..write('preferredLanguage: $preferredLanguage, ')
          ..write('preferredScanlator: $preferredScanlator, ')
          ..write('preferredSourceId: $preferredSourceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    mangaAnilistId,
    addedAt,
    notifyNewChapters,
    lastNotifiedChapter,
    autoDownloadNewChapters,
    preferredLanguage,
    preferredScanlator,
    preferredSourceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MangaLibraryTableData &&
          other.mangaAnilistId == this.mangaAnilistId &&
          other.addedAt == this.addedAt &&
          other.notifyNewChapters == this.notifyNewChapters &&
          other.lastNotifiedChapter == this.lastNotifiedChapter &&
          other.autoDownloadNewChapters == this.autoDownloadNewChapters &&
          other.preferredLanguage == this.preferredLanguage &&
          other.preferredScanlator == this.preferredScanlator &&
          other.preferredSourceId == this.preferredSourceId);
}

class MangaLibraryTableCompanion
    extends UpdateCompanion<MangaLibraryTableData> {
  final Value<int> mangaAnilistId;
  final Value<int> addedAt;
  final Value<bool> notifyNewChapters;
  final Value<double?> lastNotifiedChapter;
  final Value<bool> autoDownloadNewChapters;
  final Value<String?> preferredLanguage;
  final Value<String?> preferredScanlator;
  final Value<String?> preferredSourceId;
  const MangaLibraryTableCompanion({
    this.mangaAnilistId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.notifyNewChapters = const Value.absent(),
    this.lastNotifiedChapter = const Value.absent(),
    this.autoDownloadNewChapters = const Value.absent(),
    this.preferredLanguage = const Value.absent(),
    this.preferredScanlator = const Value.absent(),
    this.preferredSourceId = const Value.absent(),
  });
  MangaLibraryTableCompanion.insert({
    this.mangaAnilistId = const Value.absent(),
    required int addedAt,
    this.notifyNewChapters = const Value.absent(),
    this.lastNotifiedChapter = const Value.absent(),
    this.autoDownloadNewChapters = const Value.absent(),
    this.preferredLanguage = const Value.absent(),
    this.preferredScanlator = const Value.absent(),
    this.preferredSourceId = const Value.absent(),
  }) : addedAt = Value(addedAt);
  static Insertable<MangaLibraryTableData> custom({
    Expression<int>? mangaAnilistId,
    Expression<int>? addedAt,
    Expression<bool>? notifyNewChapters,
    Expression<double>? lastNotifiedChapter,
    Expression<bool>? autoDownloadNewChapters,
    Expression<String>? preferredLanguage,
    Expression<String>? preferredScanlator,
    Expression<String>? preferredSourceId,
  }) {
    return RawValuesInsertable({
      if (mangaAnilistId != null) 'manga_anilist_id': mangaAnilistId,
      if (addedAt != null) 'added_at': addedAt,
      if (notifyNewChapters != null) 'notify_new_chapters': notifyNewChapters,
      if (lastNotifiedChapter != null)
        'last_notified_chapter': lastNotifiedChapter,
      if (autoDownloadNewChapters != null)
        'auto_download_new_chapters': autoDownloadNewChapters,
      if (preferredLanguage != null) 'preferred_language': preferredLanguage,
      if (preferredScanlator != null) 'preferred_scanlator': preferredScanlator,
      if (preferredSourceId != null) 'preferred_source_id': preferredSourceId,
    });
  }

  MangaLibraryTableCompanion copyWith({
    Value<int>? mangaAnilistId,
    Value<int>? addedAt,
    Value<bool>? notifyNewChapters,
    Value<double?>? lastNotifiedChapter,
    Value<bool>? autoDownloadNewChapters,
    Value<String?>? preferredLanguage,
    Value<String?>? preferredScanlator,
    Value<String?>? preferredSourceId,
  }) {
    return MangaLibraryTableCompanion(
      mangaAnilistId: mangaAnilistId ?? this.mangaAnilistId,
      addedAt: addedAt ?? this.addedAt,
      notifyNewChapters: notifyNewChapters ?? this.notifyNewChapters,
      lastNotifiedChapter: lastNotifiedChapter ?? this.lastNotifiedChapter,
      autoDownloadNewChapters:
          autoDownloadNewChapters ?? this.autoDownloadNewChapters,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      preferredScanlator: preferredScanlator ?? this.preferredScanlator,
      preferredSourceId: preferredSourceId ?? this.preferredSourceId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mangaAnilistId.present) {
      map['manga_anilist_id'] = Variable<int>(mangaAnilistId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (notifyNewChapters.present) {
      map['notify_new_chapters'] = Variable<bool>(notifyNewChapters.value);
    }
    if (lastNotifiedChapter.present) {
      map['last_notified_chapter'] = Variable<double>(
        lastNotifiedChapter.value,
      );
    }
    if (autoDownloadNewChapters.present) {
      map['auto_download_new_chapters'] = Variable<bool>(
        autoDownloadNewChapters.value,
      );
    }
    if (preferredLanguage.present) {
      map['preferred_language'] = Variable<String>(preferredLanguage.value);
    }
    if (preferredScanlator.present) {
      map['preferred_scanlator'] = Variable<String>(preferredScanlator.value);
    }
    if (preferredSourceId.present) {
      map['preferred_source_id'] = Variable<String>(preferredSourceId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MangaLibraryTableCompanion(')
          ..write('mangaAnilistId: $mangaAnilistId, ')
          ..write('addedAt: $addedAt, ')
          ..write('notifyNewChapters: $notifyNewChapters, ')
          ..write('lastNotifiedChapter: $lastNotifiedChapter, ')
          ..write('autoDownloadNewChapters: $autoDownloadNewChapters, ')
          ..write('preferredLanguage: $preferredLanguage, ')
          ..write('preferredScanlator: $preferredScanlator, ')
          ..write('preferredSourceId: $preferredSourceId')
          ..write(')'))
        .toString();
  }
}

class $ChapterPageCacheTableTable extends ChapterPageCacheTable
    with TableInfo<$ChapterPageCacheTableTable, ChapterPageCacheTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChapterPageCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceChapterIdMeta = const VerificationMeta(
    'sourceChapterId',
  );
  @override
  late final GeneratedColumn<String> sourceChapterId = GeneratedColumn<String>(
    'source_chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _headersMeta = const VerificationMeta(
    'headers',
  );
  @override
  late final GeneratedColumn<String> headers = GeneratedColumn<String>(
    'headers',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    sourceId,
    sourceChapterId,
    pageIndex,
    imageUrl,
    headers,
    localPath,
    bytes,
    width,
    height,
    expiresAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapter_page_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChapterPageCacheTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('source_chapter_id')) {
      context.handle(
        _sourceChapterIdMeta,
        sourceChapterId.isAcceptableOrUnknown(
          data['source_chapter_id']!,
          _sourceChapterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceChapterIdMeta);
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIndexMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_imageUrlMeta);
    }
    if (data.containsKey('headers')) {
      context.handle(
        _headersMeta,
        headers.isAcceptableOrUnknown(data['headers']!, _headersMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
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
  Set<GeneratedColumn> get $primaryKey => {
    sourceId,
    sourceChapterId,
    pageIndex,
  };
  @override
  ChapterPageCacheTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChapterPageCacheTableData(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      sourceChapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_chapter_id'],
      )!,
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      )!,
      headers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headers'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ChapterPageCacheTableTable createAlias(String alias) {
    return $ChapterPageCacheTableTable(attachedDatabase, alias);
  }
}

class ChapterPageCacheTableData extends DataClass
    implements Insertable<ChapterPageCacheTableData> {
  final String sourceId;
  final String sourceChapterId;
  final int pageIndex;
  final String imageUrl;

  /// JSON-encoded `Map<String, String>` of HTTP headers required to
  /// fetch the image (Referer, Origin, Cookie pinning, etc.).
  final String? headers;

  /// Path to the cached file relative to the app cache dir, when
  /// downloaded. Null while only the URL is known.
  final String? localPath;
  final int? bytes;
  final int? width;
  final int? height;

  /// Epoch ms after which the cache row should be evicted; null means
  /// no TTL.
  final int? expiresAt;
  final int updatedAt;
  const ChapterPageCacheTableData({
    required this.sourceId,
    required this.sourceChapterId,
    required this.pageIndex,
    required this.imageUrl,
    this.headers,
    this.localPath,
    this.bytes,
    this.width,
    this.height,
    this.expiresAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['source_chapter_id'] = Variable<String>(sourceChapterId);
    map['page_index'] = Variable<int>(pageIndex);
    map['image_url'] = Variable<String>(imageUrl);
    if (!nullToAbsent || headers != null) {
      map['headers'] = Variable<String>(headers);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || bytes != null) {
      map['bytes'] = Variable<int>(bytes);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<int>(expiresAt);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ChapterPageCacheTableCompanion toCompanion(bool nullToAbsent) {
    return ChapterPageCacheTableCompanion(
      sourceId: Value(sourceId),
      sourceChapterId: Value(sourceChapterId),
      pageIndex: Value(pageIndex),
      imageUrl: Value(imageUrl),
      headers: headers == null && nullToAbsent
          ? const Value.absent()
          : Value(headers),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      bytes: bytes == null && nullToAbsent
          ? const Value.absent()
          : Value(bytes),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ChapterPageCacheTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChapterPageCacheTableData(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      sourceChapterId: serializer.fromJson<String>(json['sourceChapterId']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      imageUrl: serializer.fromJson<String>(json['imageUrl']),
      headers: serializer.fromJson<String?>(json['headers']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      bytes: serializer.fromJson<int?>(json['bytes']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      expiresAt: serializer.fromJson<int?>(json['expiresAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'sourceChapterId': serializer.toJson<String>(sourceChapterId),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'imageUrl': serializer.toJson<String>(imageUrl),
      'headers': serializer.toJson<String?>(headers),
      'localPath': serializer.toJson<String?>(localPath),
      'bytes': serializer.toJson<int?>(bytes),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'expiresAt': serializer.toJson<int?>(expiresAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ChapterPageCacheTableData copyWith({
    String? sourceId,
    String? sourceChapterId,
    int? pageIndex,
    String? imageUrl,
    Value<String?> headers = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    Value<int?> bytes = const Value.absent(),
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<int?> expiresAt = const Value.absent(),
    int? updatedAt,
  }) => ChapterPageCacheTableData(
    sourceId: sourceId ?? this.sourceId,
    sourceChapterId: sourceChapterId ?? this.sourceChapterId,
    pageIndex: pageIndex ?? this.pageIndex,
    imageUrl: imageUrl ?? this.imageUrl,
    headers: headers.present ? headers.value : this.headers,
    localPath: localPath.present ? localPath.value : this.localPath,
    bytes: bytes.present ? bytes.value : this.bytes,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ChapterPageCacheTableData copyWithCompanion(
    ChapterPageCacheTableCompanion data,
  ) {
    return ChapterPageCacheTableData(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourceChapterId: data.sourceChapterId.present
          ? data.sourceChapterId.value
          : this.sourceChapterId,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      headers: data.headers.present ? data.headers.value : this.headers,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChapterPageCacheTableData(')
          ..write('sourceId: $sourceId, ')
          ..write('sourceChapterId: $sourceChapterId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('headers: $headers, ')
          ..write('localPath: $localPath, ')
          ..write('bytes: $bytes, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    sourceChapterId,
    pageIndex,
    imageUrl,
    headers,
    localPath,
    bytes,
    width,
    height,
    expiresAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChapterPageCacheTableData &&
          other.sourceId == this.sourceId &&
          other.sourceChapterId == this.sourceChapterId &&
          other.pageIndex == this.pageIndex &&
          other.imageUrl == this.imageUrl &&
          other.headers == this.headers &&
          other.localPath == this.localPath &&
          other.bytes == this.bytes &&
          other.width == this.width &&
          other.height == this.height &&
          other.expiresAt == this.expiresAt &&
          other.updatedAt == this.updatedAt);
}

class ChapterPageCacheTableCompanion
    extends UpdateCompanion<ChapterPageCacheTableData> {
  final Value<String> sourceId;
  final Value<String> sourceChapterId;
  final Value<int> pageIndex;
  final Value<String> imageUrl;
  final Value<String?> headers;
  final Value<String?> localPath;
  final Value<int?> bytes;
  final Value<int?> width;
  final Value<int?> height;
  final Value<int?> expiresAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ChapterPageCacheTableCompanion({
    this.sourceId = const Value.absent(),
    this.sourceChapterId = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.headers = const Value.absent(),
    this.localPath = const Value.absent(),
    this.bytes = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChapterPageCacheTableCompanion.insert({
    required String sourceId,
    required String sourceChapterId,
    required int pageIndex,
    required String imageUrl,
    this.headers = const Value.absent(),
    this.localPath = const Value.absent(),
    this.bytes = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.expiresAt = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       sourceChapterId = Value(sourceChapterId),
       pageIndex = Value(pageIndex),
       imageUrl = Value(imageUrl),
       updatedAt = Value(updatedAt);
  static Insertable<ChapterPageCacheTableData> custom({
    Expression<String>? sourceId,
    Expression<String>? sourceChapterId,
    Expression<int>? pageIndex,
    Expression<String>? imageUrl,
    Expression<String>? headers,
    Expression<String>? localPath,
    Expression<int>? bytes,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? expiresAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (sourceChapterId != null) 'source_chapter_id': sourceChapterId,
      if (pageIndex != null) 'page_index': pageIndex,
      if (imageUrl != null) 'image_url': imageUrl,
      if (headers != null) 'headers': headers,
      if (localPath != null) 'local_path': localPath,
      if (bytes != null) 'bytes': bytes,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChapterPageCacheTableCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? sourceChapterId,
    Value<int>? pageIndex,
    Value<String>? imageUrl,
    Value<String?>? headers,
    Value<String?>? localPath,
    Value<int?>? bytes,
    Value<int?>? width,
    Value<int?>? height,
    Value<int?>? expiresAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ChapterPageCacheTableCompanion(
      sourceId: sourceId ?? this.sourceId,
      sourceChapterId: sourceChapterId ?? this.sourceChapterId,
      pageIndex: pageIndex ?? this.pageIndex,
      imageUrl: imageUrl ?? this.imageUrl,
      headers: headers ?? this.headers,
      localPath: localPath ?? this.localPath,
      bytes: bytes ?? this.bytes,
      width: width ?? this.width,
      height: height ?? this.height,
      expiresAt: expiresAt ?? this.expiresAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sourceChapterId.present) {
      map['source_chapter_id'] = Variable<String>(sourceChapterId.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (headers.present) {
      map['headers'] = Variable<String>(headers.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
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
    return (StringBuffer('ChapterPageCacheTableCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('sourceChapterId: $sourceChapterId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('headers: $headers, ')
          ..write('localPath: $localPath, ')
          ..write('bytes: $bytes, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MangaDownloadTableTable extends MangaDownloadTable
    with TableInfo<$MangaDownloadTableTable, MangaDownloadTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MangaDownloadTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mangaAnilistIdMeta = const VerificationMeta(
    'mangaAnilistId',
  );
  @override
  late final GeneratedColumn<int> mangaAnilistId = GeneratedColumn<int>(
    'manga_anilist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMangaIdMeta = const VerificationMeta(
    'sourceMangaId',
  );
  @override
  late final GeneratedColumn<String> sourceMangaId = GeneratedColumn<String>(
    'source_manga_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceChapterIdMeta = const VerificationMeta(
    'sourceChapterId',
  );
  @override
  late final GeneratedColumn<String> sourceChapterId = GeneratedColumn<String>(
    'source_chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterNumberMeta = const VerificationMeta(
    'chapterNumber',
  );
  @override
  late final GeneratedColumn<double> chapterNumber = GeneratedColumn<double>(
    'chapter_number',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _volumeMeta = const VerificationMeta('volume');
  @override
  late final GeneratedColumn<int> volume = GeneratedColumn<int>(
    'volume',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('en'),
  );
  static const VerificationMeta _scanlatorMeta = const VerificationMeta(
    'scanlator',
  );
  @override
  late final GeneratedColumn<String> scanlator = GeneratedColumn<String>(
    'scanlator',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mangaTitleMeta = const VerificationMeta(
    'mangaTitle',
  );
  @override
  late final GeneratedColumn<String> mangaTitle = GeneratedColumn<String>(
    'manga_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chapterTitleMeta = const VerificationMeta(
    'chapterTitle',
  );
  @override
  late final GeneratedColumn<String> chapterTitle = GeneratedColumn<String>(
    'chapter_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pagesDownloadedMeta = const VerificationMeta(
    'pagesDownloaded',
  );
  @override
  late final GeneratedColumn<int> pagesDownloaded = GeneratedColumn<int>(
    'pages_downloaded',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedBytesMeta = const VerificationMeta(
    'downloadedBytes',
  );
  @override
  late final GeneratedColumn<int> downloadedBytes = GeneratedColumn<int>(
    'downloaded_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cbzPathMeta = const VerificationMeta(
    'cbzPath',
  );
  @override
  late final GeneratedColumn<String> cbzPath = GeneratedColumn<String>(
    'cbz_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
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
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mangaAnilistId,
    sourceId,
    sourceMangaId,
    sourceChapterId,
    chapterNumber,
    volume,
    language,
    scanlator,
    mangaTitle,
    chapterTitle,
    status,
    pageCount,
    pagesDownloaded,
    totalBytes,
    downloadedBytes,
    cbzPath,
    errorMessage,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'manga_download';
  @override
  VerificationContext validateIntegrity(
    Insertable<MangaDownloadTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('manga_anilist_id')) {
      context.handle(
        _mangaAnilistIdMeta,
        mangaAnilistId.isAcceptableOrUnknown(
          data['manga_anilist_id']!,
          _mangaAnilistIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mangaAnilistIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('source_manga_id')) {
      context.handle(
        _sourceMangaIdMeta,
        sourceMangaId.isAcceptableOrUnknown(
          data['source_manga_id']!,
          _sourceMangaIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceMangaIdMeta);
    }
    if (data.containsKey('source_chapter_id')) {
      context.handle(
        _sourceChapterIdMeta,
        sourceChapterId.isAcceptableOrUnknown(
          data['source_chapter_id']!,
          _sourceChapterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceChapterIdMeta);
    }
    if (data.containsKey('chapter_number')) {
      context.handle(
        _chapterNumberMeta,
        chapterNumber.isAcceptableOrUnknown(
          data['chapter_number']!,
          _chapterNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterNumberMeta);
    }
    if (data.containsKey('volume')) {
      context.handle(
        _volumeMeta,
        volume.isAcceptableOrUnknown(data['volume']!, _volumeMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('scanlator')) {
      context.handle(
        _scanlatorMeta,
        scanlator.isAcceptableOrUnknown(data['scanlator']!, _scanlatorMeta),
      );
    }
    if (data.containsKey('manga_title')) {
      context.handle(
        _mangaTitleMeta,
        mangaTitle.isAcceptableOrUnknown(data['manga_title']!, _mangaTitleMeta),
      );
    }
    if (data.containsKey('chapter_title')) {
      context.handle(
        _chapterTitleMeta,
        chapterTitle.isAcceptableOrUnknown(
          data['chapter_title']!,
          _chapterTitleMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    }
    if (data.containsKey('pages_downloaded')) {
      context.handle(
        _pagesDownloadedMeta,
        pagesDownloaded.isAcceptableOrUnknown(
          data['pages_downloaded']!,
          _pagesDownloadedMeta,
        ),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('downloaded_bytes')) {
      context.handle(
        _downloadedBytesMeta,
        downloadedBytes.isAcceptableOrUnknown(
          data['downloaded_bytes']!,
          _downloadedBytesMeta,
        ),
      );
    }
    if (data.containsKey('cbz_path')) {
      context.handle(
        _cbzPathMeta,
        cbzPath.isAcceptableOrUnknown(data['cbz_path']!, _cbzPathMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
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
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MangaDownloadTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MangaDownloadTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mangaAnilistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manga_anilist_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      sourceMangaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_manga_id'],
      )!,
      sourceChapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_chapter_id'],
      )!,
      chapterNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}chapter_number'],
      )!,
      volume: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}volume'],
      ),
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      scanlator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scanlator'],
      ),
      mangaTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manga_title'],
      ),
      chapterTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_title'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      ),
      pagesDownloaded: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pages_downloaded'],
      ),
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      ),
      downloadedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_bytes'],
      ),
      cbzPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cbz_path'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $MangaDownloadTableTable createAlias(String alias) {
    return $MangaDownloadTableTable(attachedDatabase, alias);
  }
}

class MangaDownloadTableData extends DataClass
    implements Insertable<MangaDownloadTableData> {
  final String id;
  final int mangaAnilistId;
  final String sourceId;
  final String sourceMangaId;
  final String sourceChapterId;
  final double chapterNumber;
  final int? volume;
  final String language;
  final String? scanlator;

  /// Human-readable manga title (used for folder name and UI).
  final String? mangaTitle;

  /// Human-readable chapter title from the source.
  final String? chapterTitle;
  final String status;
  final int? pageCount;
  final int? pagesDownloaded;
  final int? totalBytes;
  final int? downloadedBytes;

  /// Final CBZ path on disk once the chapter is fully downloaded.
  final String? cbzPath;
  final String? errorMessage;
  final int createdAt;
  final int? updatedAt;
  const MangaDownloadTableData({
    required this.id,
    required this.mangaAnilistId,
    required this.sourceId,
    required this.sourceMangaId,
    required this.sourceChapterId,
    required this.chapterNumber,
    this.volume,
    required this.language,
    this.scanlator,
    this.mangaTitle,
    this.chapterTitle,
    required this.status,
    this.pageCount,
    this.pagesDownloaded,
    this.totalBytes,
    this.downloadedBytes,
    this.cbzPath,
    this.errorMessage,
    required this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['manga_anilist_id'] = Variable<int>(mangaAnilistId);
    map['source_id'] = Variable<String>(sourceId);
    map['source_manga_id'] = Variable<String>(sourceMangaId);
    map['source_chapter_id'] = Variable<String>(sourceChapterId);
    map['chapter_number'] = Variable<double>(chapterNumber);
    if (!nullToAbsent || volume != null) {
      map['volume'] = Variable<int>(volume);
    }
    map['language'] = Variable<String>(language);
    if (!nullToAbsent || scanlator != null) {
      map['scanlator'] = Variable<String>(scanlator);
    }
    if (!nullToAbsent || mangaTitle != null) {
      map['manga_title'] = Variable<String>(mangaTitle);
    }
    if (!nullToAbsent || chapterTitle != null) {
      map['chapter_title'] = Variable<String>(chapterTitle);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || pageCount != null) {
      map['page_count'] = Variable<int>(pageCount);
    }
    if (!nullToAbsent || pagesDownloaded != null) {
      map['pages_downloaded'] = Variable<int>(pagesDownloaded);
    }
    if (!nullToAbsent || totalBytes != null) {
      map['total_bytes'] = Variable<int>(totalBytes);
    }
    if (!nullToAbsent || downloadedBytes != null) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes);
    }
    if (!nullToAbsent || cbzPath != null) {
      map['cbz_path'] = Variable<String>(cbzPath);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    return map;
  }

  MangaDownloadTableCompanion toCompanion(bool nullToAbsent) {
    return MangaDownloadTableCompanion(
      id: Value(id),
      mangaAnilistId: Value(mangaAnilistId),
      sourceId: Value(sourceId),
      sourceMangaId: Value(sourceMangaId),
      sourceChapterId: Value(sourceChapterId),
      chapterNumber: Value(chapterNumber),
      volume: volume == null && nullToAbsent
          ? const Value.absent()
          : Value(volume),
      language: Value(language),
      scanlator: scanlator == null && nullToAbsent
          ? const Value.absent()
          : Value(scanlator),
      mangaTitle: mangaTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(mangaTitle),
      chapterTitle: chapterTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterTitle),
      status: Value(status),
      pageCount: pageCount == null && nullToAbsent
          ? const Value.absent()
          : Value(pageCount),
      pagesDownloaded: pagesDownloaded == null && nullToAbsent
          ? const Value.absent()
          : Value(pagesDownloaded),
      totalBytes: totalBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalBytes),
      downloadedBytes: downloadedBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedBytes),
      cbzPath: cbzPath == null && nullToAbsent
          ? const Value.absent()
          : Value(cbzPath),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory MangaDownloadTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MangaDownloadTableData(
      id: serializer.fromJson<String>(json['id']),
      mangaAnilistId: serializer.fromJson<int>(json['mangaAnilistId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      sourceMangaId: serializer.fromJson<String>(json['sourceMangaId']),
      sourceChapterId: serializer.fromJson<String>(json['sourceChapterId']),
      chapterNumber: serializer.fromJson<double>(json['chapterNumber']),
      volume: serializer.fromJson<int?>(json['volume']),
      language: serializer.fromJson<String>(json['language']),
      scanlator: serializer.fromJson<String?>(json['scanlator']),
      mangaTitle: serializer.fromJson<String?>(json['mangaTitle']),
      chapterTitle: serializer.fromJson<String?>(json['chapterTitle']),
      status: serializer.fromJson<String>(json['status']),
      pageCount: serializer.fromJson<int?>(json['pageCount']),
      pagesDownloaded: serializer.fromJson<int?>(json['pagesDownloaded']),
      totalBytes: serializer.fromJson<int?>(json['totalBytes']),
      downloadedBytes: serializer.fromJson<int?>(json['downloadedBytes']),
      cbzPath: serializer.fromJson<String?>(json['cbzPath']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mangaAnilistId': serializer.toJson<int>(mangaAnilistId),
      'sourceId': serializer.toJson<String>(sourceId),
      'sourceMangaId': serializer.toJson<String>(sourceMangaId),
      'sourceChapterId': serializer.toJson<String>(sourceChapterId),
      'chapterNumber': serializer.toJson<double>(chapterNumber),
      'volume': serializer.toJson<int?>(volume),
      'language': serializer.toJson<String>(language),
      'scanlator': serializer.toJson<String?>(scanlator),
      'mangaTitle': serializer.toJson<String?>(mangaTitle),
      'chapterTitle': serializer.toJson<String?>(chapterTitle),
      'status': serializer.toJson<String>(status),
      'pageCount': serializer.toJson<int?>(pageCount),
      'pagesDownloaded': serializer.toJson<int?>(pagesDownloaded),
      'totalBytes': serializer.toJson<int?>(totalBytes),
      'downloadedBytes': serializer.toJson<int?>(downloadedBytes),
      'cbzPath': serializer.toJson<String?>(cbzPath),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int?>(updatedAt),
    };
  }

  MangaDownloadTableData copyWith({
    String? id,
    int? mangaAnilistId,
    String? sourceId,
    String? sourceMangaId,
    String? sourceChapterId,
    double? chapterNumber,
    Value<int?> volume = const Value.absent(),
    String? language,
    Value<String?> scanlator = const Value.absent(),
    Value<String?> mangaTitle = const Value.absent(),
    Value<String?> chapterTitle = const Value.absent(),
    String? status,
    Value<int?> pageCount = const Value.absent(),
    Value<int?> pagesDownloaded = const Value.absent(),
    Value<int?> totalBytes = const Value.absent(),
    Value<int?> downloadedBytes = const Value.absent(),
    Value<String?> cbzPath = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    int? createdAt,
    Value<int?> updatedAt = const Value.absent(),
  }) => MangaDownloadTableData(
    id: id ?? this.id,
    mangaAnilistId: mangaAnilistId ?? this.mangaAnilistId,
    sourceId: sourceId ?? this.sourceId,
    sourceMangaId: sourceMangaId ?? this.sourceMangaId,
    sourceChapterId: sourceChapterId ?? this.sourceChapterId,
    chapterNumber: chapterNumber ?? this.chapterNumber,
    volume: volume.present ? volume.value : this.volume,
    language: language ?? this.language,
    scanlator: scanlator.present ? scanlator.value : this.scanlator,
    mangaTitle: mangaTitle.present ? mangaTitle.value : this.mangaTitle,
    chapterTitle: chapterTitle.present ? chapterTitle.value : this.chapterTitle,
    status: status ?? this.status,
    pageCount: pageCount.present ? pageCount.value : this.pageCount,
    pagesDownloaded: pagesDownloaded.present
        ? pagesDownloaded.value
        : this.pagesDownloaded,
    totalBytes: totalBytes.present ? totalBytes.value : this.totalBytes,
    downloadedBytes: downloadedBytes.present
        ? downloadedBytes.value
        : this.downloadedBytes,
    cbzPath: cbzPath.present ? cbzPath.value : this.cbzPath,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  MangaDownloadTableData copyWithCompanion(MangaDownloadTableCompanion data) {
    return MangaDownloadTableData(
      id: data.id.present ? data.id.value : this.id,
      mangaAnilistId: data.mangaAnilistId.present
          ? data.mangaAnilistId.value
          : this.mangaAnilistId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourceMangaId: data.sourceMangaId.present
          ? data.sourceMangaId.value
          : this.sourceMangaId,
      sourceChapterId: data.sourceChapterId.present
          ? data.sourceChapterId.value
          : this.sourceChapterId,
      chapterNumber: data.chapterNumber.present
          ? data.chapterNumber.value
          : this.chapterNumber,
      volume: data.volume.present ? data.volume.value : this.volume,
      language: data.language.present ? data.language.value : this.language,
      scanlator: data.scanlator.present ? data.scanlator.value : this.scanlator,
      mangaTitle: data.mangaTitle.present
          ? data.mangaTitle.value
          : this.mangaTitle,
      chapterTitle: data.chapterTitle.present
          ? data.chapterTitle.value
          : this.chapterTitle,
      status: data.status.present ? data.status.value : this.status,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      pagesDownloaded: data.pagesDownloaded.present
          ? data.pagesDownloaded.value
          : this.pagesDownloaded,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      downloadedBytes: data.downloadedBytes.present
          ? data.downloadedBytes.value
          : this.downloadedBytes,
      cbzPath: data.cbzPath.present ? data.cbzPath.value : this.cbzPath,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MangaDownloadTableData(')
          ..write('id: $id, ')
          ..write('mangaAnilistId: $mangaAnilistId, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceMangaId: $sourceMangaId, ')
          ..write('sourceChapterId: $sourceChapterId, ')
          ..write('chapterNumber: $chapterNumber, ')
          ..write('volume: $volume, ')
          ..write('language: $language, ')
          ..write('scanlator: $scanlator, ')
          ..write('mangaTitle: $mangaTitle, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('status: $status, ')
          ..write('pageCount: $pageCount, ')
          ..write('pagesDownloaded: $pagesDownloaded, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('cbzPath: $cbzPath, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mangaAnilistId,
    sourceId,
    sourceMangaId,
    sourceChapterId,
    chapterNumber,
    volume,
    language,
    scanlator,
    mangaTitle,
    chapterTitle,
    status,
    pageCount,
    pagesDownloaded,
    totalBytes,
    downloadedBytes,
    cbzPath,
    errorMessage,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MangaDownloadTableData &&
          other.id == this.id &&
          other.mangaAnilistId == this.mangaAnilistId &&
          other.sourceId == this.sourceId &&
          other.sourceMangaId == this.sourceMangaId &&
          other.sourceChapterId == this.sourceChapterId &&
          other.chapterNumber == this.chapterNumber &&
          other.volume == this.volume &&
          other.language == this.language &&
          other.scanlator == this.scanlator &&
          other.mangaTitle == this.mangaTitle &&
          other.chapterTitle == this.chapterTitle &&
          other.status == this.status &&
          other.pageCount == this.pageCount &&
          other.pagesDownloaded == this.pagesDownloaded &&
          other.totalBytes == this.totalBytes &&
          other.downloadedBytes == this.downloadedBytes &&
          other.cbzPath == this.cbzPath &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MangaDownloadTableCompanion
    extends UpdateCompanion<MangaDownloadTableData> {
  final Value<String> id;
  final Value<int> mangaAnilistId;
  final Value<String> sourceId;
  final Value<String> sourceMangaId;
  final Value<String> sourceChapterId;
  final Value<double> chapterNumber;
  final Value<int?> volume;
  final Value<String> language;
  final Value<String?> scanlator;
  final Value<String?> mangaTitle;
  final Value<String?> chapterTitle;
  final Value<String> status;
  final Value<int?> pageCount;
  final Value<int?> pagesDownloaded;
  final Value<int?> totalBytes;
  final Value<int?> downloadedBytes;
  final Value<String?> cbzPath;
  final Value<String?> errorMessage;
  final Value<int> createdAt;
  final Value<int?> updatedAt;
  final Value<int> rowid;
  const MangaDownloadTableCompanion({
    this.id = const Value.absent(),
    this.mangaAnilistId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceMangaId = const Value.absent(),
    this.sourceChapterId = const Value.absent(),
    this.chapterNumber = const Value.absent(),
    this.volume = const Value.absent(),
    this.language = const Value.absent(),
    this.scanlator = const Value.absent(),
    this.mangaTitle = const Value.absent(),
    this.chapterTitle = const Value.absent(),
    this.status = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.pagesDownloaded = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.cbzPath = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MangaDownloadTableCompanion.insert({
    required String id,
    required int mangaAnilistId,
    required String sourceId,
    required String sourceMangaId,
    required String sourceChapterId,
    required double chapterNumber,
    this.volume = const Value.absent(),
    this.language = const Value.absent(),
    this.scanlator = const Value.absent(),
    this.mangaTitle = const Value.absent(),
    this.chapterTitle = const Value.absent(),
    this.status = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.pagesDownloaded = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.cbzPath = const Value.absent(),
    this.errorMessage = const Value.absent(),
    required int createdAt,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mangaAnilistId = Value(mangaAnilistId),
       sourceId = Value(sourceId),
       sourceMangaId = Value(sourceMangaId),
       sourceChapterId = Value(sourceChapterId),
       chapterNumber = Value(chapterNumber),
       createdAt = Value(createdAt);
  static Insertable<MangaDownloadTableData> custom({
    Expression<String>? id,
    Expression<int>? mangaAnilistId,
    Expression<String>? sourceId,
    Expression<String>? sourceMangaId,
    Expression<String>? sourceChapterId,
    Expression<double>? chapterNumber,
    Expression<int>? volume,
    Expression<String>? language,
    Expression<String>? scanlator,
    Expression<String>? mangaTitle,
    Expression<String>? chapterTitle,
    Expression<String>? status,
    Expression<int>? pageCount,
    Expression<int>? pagesDownloaded,
    Expression<int>? totalBytes,
    Expression<int>? downloadedBytes,
    Expression<String>? cbzPath,
    Expression<String>? errorMessage,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mangaAnilistId != null) 'manga_anilist_id': mangaAnilistId,
      if (sourceId != null) 'source_id': sourceId,
      if (sourceMangaId != null) 'source_manga_id': sourceMangaId,
      if (sourceChapterId != null) 'source_chapter_id': sourceChapterId,
      if (chapterNumber != null) 'chapter_number': chapterNumber,
      if (volume != null) 'volume': volume,
      if (language != null) 'language': language,
      if (scanlator != null) 'scanlator': scanlator,
      if (mangaTitle != null) 'manga_title': mangaTitle,
      if (chapterTitle != null) 'chapter_title': chapterTitle,
      if (status != null) 'status': status,
      if (pageCount != null) 'page_count': pageCount,
      if (pagesDownloaded != null) 'pages_downloaded': pagesDownloaded,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (downloadedBytes != null) 'downloaded_bytes': downloadedBytes,
      if (cbzPath != null) 'cbz_path': cbzPath,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MangaDownloadTableCompanion copyWith({
    Value<String>? id,
    Value<int>? mangaAnilistId,
    Value<String>? sourceId,
    Value<String>? sourceMangaId,
    Value<String>? sourceChapterId,
    Value<double>? chapterNumber,
    Value<int?>? volume,
    Value<String>? language,
    Value<String?>? scanlator,
    Value<String?>? mangaTitle,
    Value<String?>? chapterTitle,
    Value<String>? status,
    Value<int?>? pageCount,
    Value<int?>? pagesDownloaded,
    Value<int?>? totalBytes,
    Value<int?>? downloadedBytes,
    Value<String?>? cbzPath,
    Value<String?>? errorMessage,
    Value<int>? createdAt,
    Value<int?>? updatedAt,
    Value<int>? rowid,
  }) {
    return MangaDownloadTableCompanion(
      id: id ?? this.id,
      mangaAnilistId: mangaAnilistId ?? this.mangaAnilistId,
      sourceId: sourceId ?? this.sourceId,
      sourceMangaId: sourceMangaId ?? this.sourceMangaId,
      sourceChapterId: sourceChapterId ?? this.sourceChapterId,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      volume: volume ?? this.volume,
      language: language ?? this.language,
      scanlator: scanlator ?? this.scanlator,
      mangaTitle: mangaTitle ?? this.mangaTitle,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      status: status ?? this.status,
      pageCount: pageCount ?? this.pageCount,
      pagesDownloaded: pagesDownloaded ?? this.pagesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      cbzPath: cbzPath ?? this.cbzPath,
      errorMessage: errorMessage ?? this.errorMessage,
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
    if (mangaAnilistId.present) {
      map['manga_anilist_id'] = Variable<int>(mangaAnilistId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sourceMangaId.present) {
      map['source_manga_id'] = Variable<String>(sourceMangaId.value);
    }
    if (sourceChapterId.present) {
      map['source_chapter_id'] = Variable<String>(sourceChapterId.value);
    }
    if (chapterNumber.present) {
      map['chapter_number'] = Variable<double>(chapterNumber.value);
    }
    if (volume.present) {
      map['volume'] = Variable<int>(volume.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (scanlator.present) {
      map['scanlator'] = Variable<String>(scanlator.value);
    }
    if (mangaTitle.present) {
      map['manga_title'] = Variable<String>(mangaTitle.value);
    }
    if (chapterTitle.present) {
      map['chapter_title'] = Variable<String>(chapterTitle.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (pagesDownloaded.present) {
      map['pages_downloaded'] = Variable<int>(pagesDownloaded.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (downloadedBytes.present) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes.value);
    }
    if (cbzPath.present) {
      map['cbz_path'] = Variable<String>(cbzPath.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
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
    return (StringBuffer('MangaDownloadTableCompanion(')
          ..write('id: $id, ')
          ..write('mangaAnilistId: $mangaAnilistId, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceMangaId: $sourceMangaId, ')
          ..write('sourceChapterId: $sourceChapterId, ')
          ..write('chapterNumber: $chapterNumber, ')
          ..write('volume: $volume, ')
          ..write('language: $language, ')
          ..write('scanlator: $scanlator, ')
          ..write('mangaTitle: $mangaTitle, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('status: $status, ')
          ..write('pageCount: $pageCount, ')
          ..write('pagesDownloaded: $pagesDownloaded, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('cbzPath: $cbzPath, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
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
  late final $AniSkipCacheTableTable aniSkipCacheTable =
      $AniSkipCacheTableTable(this);
  late final $DownloadTaskTableTable downloadTaskTable =
      $DownloadTaskTableTable(this);
  late final $HlsSegmentTableTable hlsSegmentTable = $HlsSegmentTableTable(
    this,
  );
  late final $LibraryEntryTableTable libraryEntryTable =
      $LibraryEntryTableTable(this);
  late final $AnilistCacheTableTable anilistCacheTable =
      $AnilistCacheTableTable(this);
  late final $TranslationCacheTableTable translationCacheTable =
      $TranslationCacheTableTable(this);
  late final $EpisodeCatalogCacheTableTable episodeCatalogCacheTable =
      $EpisodeCatalogCacheTableTable(this);
  late final $MangaCacheTableTable mangaCacheTable = $MangaCacheTableTable(
    this,
  );
  late final $MangaChapterTableTable mangaChapterTable =
      $MangaChapterTableTable(this);
  late final $MangaProgressTableTable mangaProgressTable =
      $MangaProgressTableTable(this);
  late final $MangaHistoryTableTable mangaHistoryTable =
      $MangaHistoryTableTable(this);
  late final $MangaLibraryTableTable mangaLibraryTable =
      $MangaLibraryTableTable(this);
  late final $ChapterPageCacheTableTable chapterPageCacheTable =
      $ChapterPageCacheTableTable(this);
  late final $MangaDownloadTableTable mangaDownloadTable =
      $MangaDownloadTableTable(this);
  late final ProgressDao progressDao = ProgressDao(this as AppDatabase);
  late final WatchHistoryDao watchHistoryDao = WatchHistoryDao(
    this as AppDatabase,
  );
  late final PlaybackPreferenceDao playbackPreferenceDao =
      PlaybackPreferenceDao(this as AppDatabase);
  late final SourceAvailabilityCacheDao sourceAvailabilityCacheDao =
      SourceAvailabilityCacheDao(this as AppDatabase);
  late final AniSkipCacheDao aniSkipCacheDao = AniSkipCacheDao(
    this as AppDatabase,
  );
  late final DownloadTaskDao downloadTaskDao = DownloadTaskDao(
    this as AppDatabase,
  );
  late final HlsSegmentDao hlsSegmentDao = HlsSegmentDao(this as AppDatabase);
  late final LibraryEntryDao libraryEntryDao = LibraryEntryDao(
    this as AppDatabase,
  );
  late final AnilistCacheDao anilistCacheDao = AnilistCacheDao(
    this as AppDatabase,
  );
  late final TranslationCacheDao translationCacheDao = TranslationCacheDao(
    this as AppDatabase,
  );
  late final EpisodeCacheDao episodeCacheDao = EpisodeCacheDao(
    this as AppDatabase,
  );
  late final MangaCacheDao mangaCacheDao = MangaCacheDao(this as AppDatabase);
  late final MangaChapterDao mangaChapterDao = MangaChapterDao(
    this as AppDatabase,
  );
  late final MangaProgressDao mangaProgressDao = MangaProgressDao(
    this as AppDatabase,
  );
  late final MangaLibraryDao mangaLibraryDao = MangaLibraryDao(
    this as AppDatabase,
  );
  late final ChapterPageCacheDao chapterPageCacheDao = ChapterPageCacheDao(
    this as AppDatabase,
  );
  late final MangaDownloadDao mangaDownloadDao = MangaDownloadDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    episodeProgressTable,
    watchHistoryTable,
    playbackPreferenceTable,
    sourceAvailabilityCacheTable,
    aniSkipCacheTable,
    downloadTaskTable,
    hlsSegmentTable,
    libraryEntryTable,
    anilistCacheTable,
    translationCacheTable,
    episodeCatalogCacheTable,
    mangaCacheTable,
    mangaChapterTable,
    mangaProgressTable,
    mangaHistoryTable,
    mangaLibraryTable,
    chapterPageCacheTable,
    mangaDownloadTable,
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
      Value<int> lastPositionSeconds,
      Value<int?> lastTotalDurationSeconds,
      required int lastAccessedAt,
    });
typedef $$WatchHistoryTableTableUpdateCompanionBuilder =
    WatchHistoryTableCompanion Function({
      Value<int> anilistId,
      Value<double> lastEpisodeNumber,
      Value<String?> lastSourcePluginId,
      Value<int> lastPositionSeconds,
      Value<int?> lastTotalDurationSeconds,
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

  ColumnFilters<int> get lastPositionSeconds => $composableBuilder(
    column: $table.lastPositionSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastTotalDurationSeconds => $composableBuilder(
    column: $table.lastTotalDurationSeconds,
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

  ColumnOrderings<int> get lastPositionSeconds => $composableBuilder(
    column: $table.lastPositionSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastTotalDurationSeconds => $composableBuilder(
    column: $table.lastTotalDurationSeconds,
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

  GeneratedColumn<int> get lastPositionSeconds => $composableBuilder(
    column: $table.lastPositionSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastTotalDurationSeconds => $composableBuilder(
    column: $table.lastTotalDurationSeconds,
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
                Value<int> lastPositionSeconds = const Value.absent(),
                Value<int?> lastTotalDurationSeconds = const Value.absent(),
                Value<int> lastAccessedAt = const Value.absent(),
              }) => WatchHistoryTableCompanion(
                anilistId: anilistId,
                lastEpisodeNumber: lastEpisodeNumber,
                lastSourcePluginId: lastSourcePluginId,
                lastPositionSeconds: lastPositionSeconds,
                lastTotalDurationSeconds: lastTotalDurationSeconds,
                lastAccessedAt: lastAccessedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                required double lastEpisodeNumber,
                Value<String?> lastSourcePluginId = const Value.absent(),
                Value<int> lastPositionSeconds = const Value.absent(),
                Value<int?> lastTotalDurationSeconds = const Value.absent(),
                required int lastAccessedAt,
              }) => WatchHistoryTableCompanion.insert(
                anilistId: anilistId,
                lastEpisodeNumber: lastEpisodeNumber,
                lastSourcePluginId: lastSourcePluginId,
                lastPositionSeconds: lastPositionSeconds,
                lastTotalDurationSeconds: lastTotalDurationSeconds,
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
typedef $$AniSkipCacheTableTableCreateCompanionBuilder =
    AniSkipCacheTableCompanion Function({
      required int anilistId,
      required int episodeNumber,
      required String payloadJson,
      required int updatedAt,
      Value<int?> requestedEpisodeLengthSeconds,
      Value<int> rowid,
    });
typedef $$AniSkipCacheTableTableUpdateCompanionBuilder =
    AniSkipCacheTableCompanion Function({
      Value<int> anilistId,
      Value<int> episodeNumber,
      Value<String> payloadJson,
      Value<int> updatedAt,
      Value<int?> requestedEpisodeLengthSeconds,
      Value<int> rowid,
    });

class $$AniSkipCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $AniSkipCacheTableTable> {
  $$AniSkipCacheTableTableFilterComposer({
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

  ColumnFilters<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
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

  ColumnFilters<int> get requestedEpisodeLengthSeconds => $composableBuilder(
    column: $table.requestedEpisodeLengthSeconds,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AniSkipCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AniSkipCacheTableTable> {
  $$AniSkipCacheTableTableOrderingComposer({
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

  ColumnOrderings<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
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

  ColumnOrderings<int> get requestedEpisodeLengthSeconds => $composableBuilder(
    column: $table.requestedEpisodeLengthSeconds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AniSkipCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AniSkipCacheTableTable> {
  $$AniSkipCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get anilistId =>
      $composableBuilder(column: $table.anilistId, builder: (column) => column);

  GeneratedColumn<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get requestedEpisodeLengthSeconds => $composableBuilder(
    column: $table.requestedEpisodeLengthSeconds,
    builder: (column) => column,
  );
}

class $$AniSkipCacheTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AniSkipCacheTableTable,
          AniSkipCacheTableData,
          $$AniSkipCacheTableTableFilterComposer,
          $$AniSkipCacheTableTableOrderingComposer,
          $$AniSkipCacheTableTableAnnotationComposer,
          $$AniSkipCacheTableTableCreateCompanionBuilder,
          $$AniSkipCacheTableTableUpdateCompanionBuilder,
          (
            AniSkipCacheTableData,
            BaseReferences<
              _$AppDatabase,
              $AniSkipCacheTableTable,
              AniSkipCacheTableData
            >,
          ),
          AniSkipCacheTableData,
          PrefetchHooks Function()
        > {
  $$AniSkipCacheTableTableTableManager(
    _$AppDatabase db,
    $AniSkipCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AniSkipCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AniSkipCacheTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AniSkipCacheTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                Value<int> episodeNumber = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> requestedEpisodeLengthSeconds =
                    const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AniSkipCacheTableCompanion(
                anilistId: anilistId,
                episodeNumber: episodeNumber,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                requestedEpisodeLengthSeconds: requestedEpisodeLengthSeconds,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int anilistId,
                required int episodeNumber,
                required String payloadJson,
                required int updatedAt,
                Value<int?> requestedEpisodeLengthSeconds =
                    const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AniSkipCacheTableCompanion.insert(
                anilistId: anilistId,
                episodeNumber: episodeNumber,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                requestedEpisodeLengthSeconds: requestedEpisodeLengthSeconds,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AniSkipCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AniSkipCacheTableTable,
      AniSkipCacheTableData,
      $$AniSkipCacheTableTableFilterComposer,
      $$AniSkipCacheTableTableOrderingComposer,
      $$AniSkipCacheTableTableAnnotationComposer,
      $$AniSkipCacheTableTableCreateCompanionBuilder,
      $$AniSkipCacheTableTableUpdateCompanionBuilder,
      (
        AniSkipCacheTableData,
        BaseReferences<
          _$AppDatabase,
          $AniSkipCacheTableTable,
          AniSkipCacheTableData
        >,
      ),
      AniSkipCacheTableData,
      PrefetchHooks Function()
    >;
typedef $$DownloadTaskTableTableCreateCompanionBuilder =
    DownloadTaskTableCompanion Function({
      required String id,
      required int anilistId,
      required double episodeNumber,
      required String sourceUrl,
      Value<String> status,
      Value<String?> fileName,
      Value<String?> filePath,
      Value<int?> totalBytes,
      Value<int?> downloadedBytes,
      Value<String?> sourcePluginId,
      Value<String?> serverName,
      Value<String?> detectedHost,
      Value<String?> errorMessage,
      required int createdAt,
      Value<int?> updatedAt,
      Value<String?> headers,
      Value<bool?> isHls,
      Value<String?> animeTitle,
      Value<String?> qualityLabel,
      Value<String?> episodeTitle,
      Value<int> rowid,
    });
typedef $$DownloadTaskTableTableUpdateCompanionBuilder =
    DownloadTaskTableCompanion Function({
      Value<String> id,
      Value<int> anilistId,
      Value<double> episodeNumber,
      Value<String> sourceUrl,
      Value<String> status,
      Value<String?> fileName,
      Value<String?> filePath,
      Value<int?> totalBytes,
      Value<int?> downloadedBytes,
      Value<String?> sourcePluginId,
      Value<String?> serverName,
      Value<String?> detectedHost,
      Value<String?> errorMessage,
      Value<int> createdAt,
      Value<int?> updatedAt,
      Value<String?> headers,
      Value<bool?> isHls,
      Value<String?> animeTitle,
      Value<String?> qualityLabel,
      Value<String?> episodeTitle,
      Value<int> rowid,
    });

class $$DownloadTaskTableTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadTaskTableTable> {
  $$DownloadTaskTableTableFilterComposer({
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

  ColumnFilters<int> get anilistId => $composableBuilder(
    column: $table.anilistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePluginId => $composableBuilder(
    column: $table.sourcePluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverName => $composableBuilder(
    column: $table.serverName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detectedHost => $composableBuilder(
    column: $table.detectedHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headers => $composableBuilder(
    column: $table.headers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isHls => $composableBuilder(
    column: $table.isHls,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get animeTitle => $composableBuilder(
    column: $table.animeTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qualityLabel => $composableBuilder(
    column: $table.qualityLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeTitle => $composableBuilder(
    column: $table.episodeTitle,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadTaskTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadTaskTableTable> {
  $$DownloadTaskTableTableOrderingComposer({
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

  ColumnOrderings<int> get anilistId => $composableBuilder(
    column: $table.anilistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePluginId => $composableBuilder(
    column: $table.sourcePluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverName => $composableBuilder(
    column: $table.serverName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detectedHost => $composableBuilder(
    column: $table.detectedHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headers => $composableBuilder(
    column: $table.headers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isHls => $composableBuilder(
    column: $table.isHls,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get animeTitle => $composableBuilder(
    column: $table.animeTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qualityLabel => $composableBuilder(
    column: $table.qualityLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeTitle => $composableBuilder(
    column: $table.episodeTitle,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadTaskTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadTaskTableTable> {
  $$DownloadTaskTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get anilistId =>
      $composableBuilder(column: $table.anilistId, builder: (column) => column);

  GeneratedColumn<double> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourcePluginId => $composableBuilder(
    column: $table.sourcePluginId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverName => $composableBuilder(
    column: $table.serverName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detectedHost => $composableBuilder(
    column: $table.detectedHost,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get headers =>
      $composableBuilder(column: $table.headers, builder: (column) => column);

  GeneratedColumn<bool> get isHls =>
      $composableBuilder(column: $table.isHls, builder: (column) => column);

  GeneratedColumn<String> get animeTitle => $composableBuilder(
    column: $table.animeTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get qualityLabel => $composableBuilder(
    column: $table.qualityLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get episodeTitle => $composableBuilder(
    column: $table.episodeTitle,
    builder: (column) => column,
  );
}

class $$DownloadTaskTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadTaskTableTable,
          DownloadTaskTableData,
          $$DownloadTaskTableTableFilterComposer,
          $$DownloadTaskTableTableOrderingComposer,
          $$DownloadTaskTableTableAnnotationComposer,
          $$DownloadTaskTableTableCreateCompanionBuilder,
          $$DownloadTaskTableTableUpdateCompanionBuilder,
          (
            DownloadTaskTableData,
            BaseReferences<
              _$AppDatabase,
              $DownloadTaskTableTable,
              DownloadTaskTableData
            >,
          ),
          DownloadTaskTableData,
          PrefetchHooks Function()
        > {
  $$DownloadTaskTableTableTableManager(
    _$AppDatabase db,
    $DownloadTaskTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadTaskTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadTaskTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadTaskTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> anilistId = const Value.absent(),
                Value<double> episodeNumber = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> fileName = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<int?> downloadedBytes = const Value.absent(),
                Value<String?> sourcePluginId = const Value.absent(),
                Value<String?> serverName = const Value.absent(),
                Value<String?> detectedHost = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<String?> headers = const Value.absent(),
                Value<bool?> isHls = const Value.absent(),
                Value<String?> animeTitle = const Value.absent(),
                Value<String?> qualityLabel = const Value.absent(),
                Value<String?> episodeTitle = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadTaskTableCompanion(
                id: id,
                anilistId: anilistId,
                episodeNumber: episodeNumber,
                sourceUrl: sourceUrl,
                status: status,
                fileName: fileName,
                filePath: filePath,
                totalBytes: totalBytes,
                downloadedBytes: downloadedBytes,
                sourcePluginId: sourcePluginId,
                serverName: serverName,
                detectedHost: detectedHost,
                errorMessage: errorMessage,
                createdAt: createdAt,
                updatedAt: updatedAt,
                headers: headers,
                isHls: isHls,
                animeTitle: animeTitle,
                qualityLabel: qualityLabel,
                episodeTitle: episodeTitle,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int anilistId,
                required double episodeNumber,
                required String sourceUrl,
                Value<String> status = const Value.absent(),
                Value<String?> fileName = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<int?> downloadedBytes = const Value.absent(),
                Value<String?> sourcePluginId = const Value.absent(),
                Value<String?> serverName = const Value.absent(),
                Value<String?> detectedHost = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                required int createdAt,
                Value<int?> updatedAt = const Value.absent(),
                Value<String?> headers = const Value.absent(),
                Value<bool?> isHls = const Value.absent(),
                Value<String?> animeTitle = const Value.absent(),
                Value<String?> qualityLabel = const Value.absent(),
                Value<String?> episodeTitle = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadTaskTableCompanion.insert(
                id: id,
                anilistId: anilistId,
                episodeNumber: episodeNumber,
                sourceUrl: sourceUrl,
                status: status,
                fileName: fileName,
                filePath: filePath,
                totalBytes: totalBytes,
                downloadedBytes: downloadedBytes,
                sourcePluginId: sourcePluginId,
                serverName: serverName,
                detectedHost: detectedHost,
                errorMessage: errorMessage,
                createdAt: createdAt,
                updatedAt: updatedAt,
                headers: headers,
                isHls: isHls,
                animeTitle: animeTitle,
                qualityLabel: qualityLabel,
                episodeTitle: episodeTitle,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadTaskTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadTaskTableTable,
      DownloadTaskTableData,
      $$DownloadTaskTableTableFilterComposer,
      $$DownloadTaskTableTableOrderingComposer,
      $$DownloadTaskTableTableAnnotationComposer,
      $$DownloadTaskTableTableCreateCompanionBuilder,
      $$DownloadTaskTableTableUpdateCompanionBuilder,
      (
        DownloadTaskTableData,
        BaseReferences<
          _$AppDatabase,
          $DownloadTaskTableTable,
          DownloadTaskTableData
        >,
      ),
      DownloadTaskTableData,
      PrefetchHooks Function()
    >;
typedef $$HlsSegmentTableTableCreateCompanionBuilder =
    HlsSegmentTableCompanion Function({
      required String id,
      required String downloadTaskId,
      required int segmentIndex,
      required String url,
      Value<String> status,
      Value<String?> localPath,
      Value<int?> byteSize,
      Value<int> retryCount,
      Value<int> rowid,
    });
typedef $$HlsSegmentTableTableUpdateCompanionBuilder =
    HlsSegmentTableCompanion Function({
      Value<String> id,
      Value<String> downloadTaskId,
      Value<int> segmentIndex,
      Value<String> url,
      Value<String> status,
      Value<String?> localPath,
      Value<int?> byteSize,
      Value<int> retryCount,
      Value<int> rowid,
    });

class $$HlsSegmentTableTableFilterComposer
    extends Composer<_$AppDatabase, $HlsSegmentTableTable> {
  $$HlsSegmentTableTableFilterComposer({
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

  ColumnFilters<String> get downloadTaskId => $composableBuilder(
    column: $table.downloadTaskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HlsSegmentTableTableOrderingComposer
    extends Composer<_$AppDatabase, $HlsSegmentTableTable> {
  $$HlsSegmentTableTableOrderingComposer({
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

  ColumnOrderings<String> get downloadTaskId => $composableBuilder(
    column: $table.downloadTaskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HlsSegmentTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $HlsSegmentTableTable> {
  $$HlsSegmentTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get downloadTaskId => $composableBuilder(
    column: $table.downloadTaskId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );
}

class $$HlsSegmentTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HlsSegmentTableTable,
          HlsSegmentTableData,
          $$HlsSegmentTableTableFilterComposer,
          $$HlsSegmentTableTableOrderingComposer,
          $$HlsSegmentTableTableAnnotationComposer,
          $$HlsSegmentTableTableCreateCompanionBuilder,
          $$HlsSegmentTableTableUpdateCompanionBuilder,
          (
            HlsSegmentTableData,
            BaseReferences<
              _$AppDatabase,
              $HlsSegmentTableTable,
              HlsSegmentTableData
            >,
          ),
          HlsSegmentTableData,
          PrefetchHooks Function()
        > {
  $$HlsSegmentTableTableTableManager(
    _$AppDatabase db,
    $HlsSegmentTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HlsSegmentTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HlsSegmentTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HlsSegmentTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> downloadTaskId = const Value.absent(),
                Value<int> segmentIndex = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int?> byteSize = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HlsSegmentTableCompanion(
                id: id,
                downloadTaskId: downloadTaskId,
                segmentIndex: segmentIndex,
                url: url,
                status: status,
                localPath: localPath,
                byteSize: byteSize,
                retryCount: retryCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String downloadTaskId,
                required int segmentIndex,
                required String url,
                Value<String> status = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int?> byteSize = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HlsSegmentTableCompanion.insert(
                id: id,
                downloadTaskId: downloadTaskId,
                segmentIndex: segmentIndex,
                url: url,
                status: status,
                localPath: localPath,
                byteSize: byteSize,
                retryCount: retryCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HlsSegmentTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HlsSegmentTableTable,
      HlsSegmentTableData,
      $$HlsSegmentTableTableFilterComposer,
      $$HlsSegmentTableTableOrderingComposer,
      $$HlsSegmentTableTableAnnotationComposer,
      $$HlsSegmentTableTableCreateCompanionBuilder,
      $$HlsSegmentTableTableUpdateCompanionBuilder,
      (
        HlsSegmentTableData,
        BaseReferences<
          _$AppDatabase,
          $HlsSegmentTableTable,
          HlsSegmentTableData
        >,
      ),
      HlsSegmentTableData,
      PrefetchHooks Function()
    >;
typedef $$LibraryEntryTableTableCreateCompanionBuilder =
    LibraryEntryTableCompanion Function({
      Value<int> anilistId,
      required int addedAt,
      Value<bool> notifyNewEpisodes,
      Value<int?> lastNotifiedEpisode,
      Value<bool> autoDownloadNewEpisodes,
      Value<String?> autoDownloadAudioPreference,
    });
typedef $$LibraryEntryTableTableUpdateCompanionBuilder =
    LibraryEntryTableCompanion Function({
      Value<int> anilistId,
      Value<int> addedAt,
      Value<bool> notifyNewEpisodes,
      Value<int?> lastNotifiedEpisode,
      Value<bool> autoDownloadNewEpisodes,
      Value<String?> autoDownloadAudioPreference,
    });

class $$LibraryEntryTableTableFilterComposer
    extends Composer<_$AppDatabase, $LibraryEntryTableTable> {
  $$LibraryEntryTableTableFilterComposer({
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

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notifyNewEpisodes => $composableBuilder(
    column: $table.notifyNewEpisodes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastNotifiedEpisode => $composableBuilder(
    column: $table.lastNotifiedEpisode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoDownloadNewEpisodes => $composableBuilder(
    column: $table.autoDownloadNewEpisodes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get autoDownloadAudioPreference => $composableBuilder(
    column: $table.autoDownloadAudioPreference,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LibraryEntryTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LibraryEntryTableTable> {
  $$LibraryEntryTableTableOrderingComposer({
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

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notifyNewEpisodes => $composableBuilder(
    column: $table.notifyNewEpisodes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastNotifiedEpisode => $composableBuilder(
    column: $table.lastNotifiedEpisode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoDownloadNewEpisodes => $composableBuilder(
    column: $table.autoDownloadNewEpisodes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get autoDownloadAudioPreference => $composableBuilder(
    column: $table.autoDownloadAudioPreference,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryEntryTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibraryEntryTableTable> {
  $$LibraryEntryTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get anilistId =>
      $composableBuilder(column: $table.anilistId, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<bool> get notifyNewEpisodes => $composableBuilder(
    column: $table.notifyNewEpisodes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastNotifiedEpisode => $composableBuilder(
    column: $table.lastNotifiedEpisode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoDownloadNewEpisodes => $composableBuilder(
    column: $table.autoDownloadNewEpisodes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get autoDownloadAudioPreference => $composableBuilder(
    column: $table.autoDownloadAudioPreference,
    builder: (column) => column,
  );
}

class $$LibraryEntryTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibraryEntryTableTable,
          LibraryEntryTableData,
          $$LibraryEntryTableTableFilterComposer,
          $$LibraryEntryTableTableOrderingComposer,
          $$LibraryEntryTableTableAnnotationComposer,
          $$LibraryEntryTableTableCreateCompanionBuilder,
          $$LibraryEntryTableTableUpdateCompanionBuilder,
          (
            LibraryEntryTableData,
            BaseReferences<
              _$AppDatabase,
              $LibraryEntryTableTable,
              LibraryEntryTableData
            >,
          ),
          LibraryEntryTableData,
          PrefetchHooks Function()
        > {
  $$LibraryEntryTableTableTableManager(
    _$AppDatabase db,
    $LibraryEntryTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryEntryTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryEntryTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryEntryTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<bool> notifyNewEpisodes = const Value.absent(),
                Value<int?> lastNotifiedEpisode = const Value.absent(),
                Value<bool> autoDownloadNewEpisodes = const Value.absent(),
                Value<String?> autoDownloadAudioPreference =
                    const Value.absent(),
              }) => LibraryEntryTableCompanion(
                anilistId: anilistId,
                addedAt: addedAt,
                notifyNewEpisodes: notifyNewEpisodes,
                lastNotifiedEpisode: lastNotifiedEpisode,
                autoDownloadNewEpisodes: autoDownloadNewEpisodes,
                autoDownloadAudioPreference: autoDownloadAudioPreference,
              ),
          createCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                required int addedAt,
                Value<bool> notifyNewEpisodes = const Value.absent(),
                Value<int?> lastNotifiedEpisode = const Value.absent(),
                Value<bool> autoDownloadNewEpisodes = const Value.absent(),
                Value<String?> autoDownloadAudioPreference =
                    const Value.absent(),
              }) => LibraryEntryTableCompanion.insert(
                anilistId: anilistId,
                addedAt: addedAt,
                notifyNewEpisodes: notifyNewEpisodes,
                lastNotifiedEpisode: lastNotifiedEpisode,
                autoDownloadNewEpisodes: autoDownloadNewEpisodes,
                autoDownloadAudioPreference: autoDownloadAudioPreference,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibraryEntryTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibraryEntryTableTable,
      LibraryEntryTableData,
      $$LibraryEntryTableTableFilterComposer,
      $$LibraryEntryTableTableOrderingComposer,
      $$LibraryEntryTableTableAnnotationComposer,
      $$LibraryEntryTableTableCreateCompanionBuilder,
      $$LibraryEntryTableTableUpdateCompanionBuilder,
      (
        LibraryEntryTableData,
        BaseReferences<
          _$AppDatabase,
          $LibraryEntryTableTable,
          LibraryEntryTableData
        >,
      ),
      LibraryEntryTableData,
      PrefetchHooks Function()
    >;
typedef $$AnilistCacheTableTableCreateCompanionBuilder =
    AnilistCacheTableCompanion Function({
      Value<int> anilistId,
      required String titleRomaji,
      Value<String?> titleEnglish,
      Value<String?> titleNative,
      Value<String?> synonyms,
      Value<String?> coverImageUrl,
      Value<String?> bannerImageUrl,
      Value<String?> status,
      Value<String?> season,
      Value<int?> averageScore,
      Value<int?> popularity,
      Value<String?> genres,
      Value<String?> synopsis,
      Value<String?> format,
      Value<int?> releaseYear,
      Value<int?> totalEpisodes,
      Value<int?> nextAiringEpisode,
      Value<int?> nextAiringAt,
      Value<String?> relations,
      required int updatedAt,
    });
typedef $$AnilistCacheTableTableUpdateCompanionBuilder =
    AnilistCacheTableCompanion Function({
      Value<int> anilistId,
      Value<String> titleRomaji,
      Value<String?> titleEnglish,
      Value<String?> titleNative,
      Value<String?> synonyms,
      Value<String?> coverImageUrl,
      Value<String?> bannerImageUrl,
      Value<String?> status,
      Value<String?> season,
      Value<int?> averageScore,
      Value<int?> popularity,
      Value<String?> genres,
      Value<String?> synopsis,
      Value<String?> format,
      Value<int?> releaseYear,
      Value<int?> totalEpisodes,
      Value<int?> nextAiringEpisode,
      Value<int?> nextAiringAt,
      Value<String?> relations,
      Value<int> updatedAt,
    });

class $$AnilistCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $AnilistCacheTableTable> {
  $$AnilistCacheTableTableFilterComposer({
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

  ColumnFilters<String> get titleRomaji => $composableBuilder(
    column: $table.titleRomaji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleEnglish => $composableBuilder(
    column: $table.titleEnglish,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleNative => $composableBuilder(
    column: $table.titleNative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get synonyms => $composableBuilder(
    column: $table.synonyms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverImageUrl => $composableBuilder(
    column: $table.coverImageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bannerImageUrl => $composableBuilder(
    column: $table.bannerImageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get averageScore => $composableBuilder(
    column: $table.averageScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get popularity => $composableBuilder(
    column: $table.popularity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genres => $composableBuilder(
    column: $table.genres,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get synopsis => $composableBuilder(
    column: $table.synopsis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get releaseYear => $composableBuilder(
    column: $table.releaseYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextAiringEpisode => $composableBuilder(
    column: $table.nextAiringEpisode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextAiringAt => $composableBuilder(
    column: $table.nextAiringAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relations => $composableBuilder(
    column: $table.relations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AnilistCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AnilistCacheTableTable> {
  $$AnilistCacheTableTableOrderingComposer({
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

  ColumnOrderings<String> get titleRomaji => $composableBuilder(
    column: $table.titleRomaji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleEnglish => $composableBuilder(
    column: $table.titleEnglish,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleNative => $composableBuilder(
    column: $table.titleNative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get synonyms => $composableBuilder(
    column: $table.synonyms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverImageUrl => $composableBuilder(
    column: $table.coverImageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bannerImageUrl => $composableBuilder(
    column: $table.bannerImageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get averageScore => $composableBuilder(
    column: $table.averageScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get popularity => $composableBuilder(
    column: $table.popularity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genres => $composableBuilder(
    column: $table.genres,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get synopsis => $composableBuilder(
    column: $table.synopsis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get releaseYear => $composableBuilder(
    column: $table.releaseYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextAiringEpisode => $composableBuilder(
    column: $table.nextAiringEpisode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextAiringAt => $composableBuilder(
    column: $table.nextAiringAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relations => $composableBuilder(
    column: $table.relations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnilistCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnilistCacheTableTable> {
  $$AnilistCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get anilistId =>
      $composableBuilder(column: $table.anilistId, builder: (column) => column);

  GeneratedColumn<String> get titleRomaji => $composableBuilder(
    column: $table.titleRomaji,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleEnglish => $composableBuilder(
    column: $table.titleEnglish,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleNative => $composableBuilder(
    column: $table.titleNative,
    builder: (column) => column,
  );

  GeneratedColumn<String> get synonyms =>
      $composableBuilder(column: $table.synonyms, builder: (column) => column);

  GeneratedColumn<String> get coverImageUrl => $composableBuilder(
    column: $table.coverImageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bannerImageUrl => $composableBuilder(
    column: $table.bannerImageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<int> get averageScore => $composableBuilder(
    column: $table.averageScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get popularity => $composableBuilder(
    column: $table.popularity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genres =>
      $composableBuilder(column: $table.genres, builder: (column) => column);

  GeneratedColumn<String> get synopsis =>
      $composableBuilder(column: $table.synopsis, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<int> get releaseYear => $composableBuilder(
    column: $table.releaseYear,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextAiringEpisode => $composableBuilder(
    column: $table.nextAiringEpisode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextAiringAt => $composableBuilder(
    column: $table.nextAiringAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relations =>
      $composableBuilder(column: $table.relations, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AnilistCacheTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnilistCacheTableTable,
          AnilistCacheTableData,
          $$AnilistCacheTableTableFilterComposer,
          $$AnilistCacheTableTableOrderingComposer,
          $$AnilistCacheTableTableAnnotationComposer,
          $$AnilistCacheTableTableCreateCompanionBuilder,
          $$AnilistCacheTableTableUpdateCompanionBuilder,
          (
            AnilistCacheTableData,
            BaseReferences<
              _$AppDatabase,
              $AnilistCacheTableTable,
              AnilistCacheTableData
            >,
          ),
          AnilistCacheTableData,
          PrefetchHooks Function()
        > {
  $$AnilistCacheTableTableTableManager(
    _$AppDatabase db,
    $AnilistCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnilistCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnilistCacheTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnilistCacheTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                Value<String> titleRomaji = const Value.absent(),
                Value<String?> titleEnglish = const Value.absent(),
                Value<String?> titleNative = const Value.absent(),
                Value<String?> synonyms = const Value.absent(),
                Value<String?> coverImageUrl = const Value.absent(),
                Value<String?> bannerImageUrl = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> season = const Value.absent(),
                Value<int?> averageScore = const Value.absent(),
                Value<int?> popularity = const Value.absent(),
                Value<String?> genres = const Value.absent(),
                Value<String?> synopsis = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<int?> releaseYear = const Value.absent(),
                Value<int?> totalEpisodes = const Value.absent(),
                Value<int?> nextAiringEpisode = const Value.absent(),
                Value<int?> nextAiringAt = const Value.absent(),
                Value<String?> relations = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => AnilistCacheTableCompanion(
                anilistId: anilistId,
                titleRomaji: titleRomaji,
                titleEnglish: titleEnglish,
                titleNative: titleNative,
                synonyms: synonyms,
                coverImageUrl: coverImageUrl,
                bannerImageUrl: bannerImageUrl,
                status: status,
                season: season,
                averageScore: averageScore,
                popularity: popularity,
                genres: genres,
                synopsis: synopsis,
                format: format,
                releaseYear: releaseYear,
                totalEpisodes: totalEpisodes,
                nextAiringEpisode: nextAiringEpisode,
                nextAiringAt: nextAiringAt,
                relations: relations,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                required String titleRomaji,
                Value<String?> titleEnglish = const Value.absent(),
                Value<String?> titleNative = const Value.absent(),
                Value<String?> synonyms = const Value.absent(),
                Value<String?> coverImageUrl = const Value.absent(),
                Value<String?> bannerImageUrl = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> season = const Value.absent(),
                Value<int?> averageScore = const Value.absent(),
                Value<int?> popularity = const Value.absent(),
                Value<String?> genres = const Value.absent(),
                Value<String?> synopsis = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<int?> releaseYear = const Value.absent(),
                Value<int?> totalEpisodes = const Value.absent(),
                Value<int?> nextAiringEpisode = const Value.absent(),
                Value<int?> nextAiringAt = const Value.absent(),
                Value<String?> relations = const Value.absent(),
                required int updatedAt,
              }) => AnilistCacheTableCompanion.insert(
                anilistId: anilistId,
                titleRomaji: titleRomaji,
                titleEnglish: titleEnglish,
                titleNative: titleNative,
                synonyms: synonyms,
                coverImageUrl: coverImageUrl,
                bannerImageUrl: bannerImageUrl,
                status: status,
                season: season,
                averageScore: averageScore,
                popularity: popularity,
                genres: genres,
                synopsis: synopsis,
                format: format,
                releaseYear: releaseYear,
                totalEpisodes: totalEpisodes,
                nextAiringEpisode: nextAiringEpisode,
                nextAiringAt: nextAiringAt,
                relations: relations,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnilistCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnilistCacheTableTable,
      AnilistCacheTableData,
      $$AnilistCacheTableTableFilterComposer,
      $$AnilistCacheTableTableOrderingComposer,
      $$AnilistCacheTableTableAnnotationComposer,
      $$AnilistCacheTableTableCreateCompanionBuilder,
      $$AnilistCacheTableTableUpdateCompanionBuilder,
      (
        AnilistCacheTableData,
        BaseReferences<
          _$AppDatabase,
          $AnilistCacheTableTable,
          AnilistCacheTableData
        >,
      ),
      AnilistCacheTableData,
      PrefetchHooks Function()
    >;
typedef $$TranslationCacheTableTableCreateCompanionBuilder =
    TranslationCacheTableCompanion Function({
      required String sourceText,
      required String targetLanguage,
      required String translatedText,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$TranslationCacheTableTableUpdateCompanionBuilder =
    TranslationCacheTableCompanion Function({
      Value<String> sourceText,
      Value<String> targetLanguage,
      Value<String> translatedText,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$TranslationCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $TranslationCacheTableTable> {
  $$TranslationCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetLanguage => $composableBuilder(
    column: $table.targetLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translatedText => $composableBuilder(
    column: $table.translatedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TranslationCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TranslationCacheTableTable> {
  $$TranslationCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetLanguage => $composableBuilder(
    column: $table.targetLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translatedText => $composableBuilder(
    column: $table.translatedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TranslationCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TranslationCacheTableTable> {
  $$TranslationCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceText => $composableBuilder(
    column: $table.sourceText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetLanguage => $composableBuilder(
    column: $table.targetLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translatedText => $composableBuilder(
    column: $table.translatedText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TranslationCacheTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TranslationCacheTableTable,
          TranslationCacheTableData,
          $$TranslationCacheTableTableFilterComposer,
          $$TranslationCacheTableTableOrderingComposer,
          $$TranslationCacheTableTableAnnotationComposer,
          $$TranslationCacheTableTableCreateCompanionBuilder,
          $$TranslationCacheTableTableUpdateCompanionBuilder,
          (
            TranslationCacheTableData,
            BaseReferences<
              _$AppDatabase,
              $TranslationCacheTableTable,
              TranslationCacheTableData
            >,
          ),
          TranslationCacheTableData,
          PrefetchHooks Function()
        > {
  $$TranslationCacheTableTableTableManager(
    _$AppDatabase db,
    $TranslationCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranslationCacheTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$TranslationCacheTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TranslationCacheTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sourceText = const Value.absent(),
                Value<String> targetLanguage = const Value.absent(),
                Value<String> translatedText = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranslationCacheTableCompanion(
                sourceText: sourceText,
                targetLanguage: targetLanguage,
                translatedText: translatedText,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceText,
                required String targetLanguage,
                required String translatedText,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TranslationCacheTableCompanion.insert(
                sourceText: sourceText,
                targetLanguage: targetLanguage,
                translatedText: translatedText,
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

typedef $$TranslationCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TranslationCacheTableTable,
      TranslationCacheTableData,
      $$TranslationCacheTableTableFilterComposer,
      $$TranslationCacheTableTableOrderingComposer,
      $$TranslationCacheTableTableAnnotationComposer,
      $$TranslationCacheTableTableCreateCompanionBuilder,
      $$TranslationCacheTableTableUpdateCompanionBuilder,
      (
        TranslationCacheTableData,
        BaseReferences<
          _$AppDatabase,
          $TranslationCacheTableTable,
          TranslationCacheTableData
        >,
      ),
      TranslationCacheTableData,
      PrefetchHooks Function()
    >;
typedef $$EpisodeCatalogCacheTableTableCreateCompanionBuilder =
    EpisodeCatalogCacheTableCompanion Function({
      required int anilistId,
      required double episodeNumber,
      required String title,
      Value<int?> airDate,
      Value<bool> isAired,
      Value<bool> isFiller,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$EpisodeCatalogCacheTableTableUpdateCompanionBuilder =
    EpisodeCatalogCacheTableCompanion Function({
      Value<int> anilistId,
      Value<double> episodeNumber,
      Value<String> title,
      Value<int?> airDate,
      Value<bool> isAired,
      Value<bool> isFiller,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$EpisodeCatalogCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $EpisodeCatalogCacheTableTable> {
  $$EpisodeCatalogCacheTableTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get airDate => $composableBuilder(
    column: $table.airDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAired => $composableBuilder(
    column: $table.isAired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFiller => $composableBuilder(
    column: $table.isFiller,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EpisodeCatalogCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $EpisodeCatalogCacheTableTable> {
  $$EpisodeCatalogCacheTableTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get airDate => $composableBuilder(
    column: $table.airDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAired => $composableBuilder(
    column: $table.isAired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFiller => $composableBuilder(
    column: $table.isFiller,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EpisodeCatalogCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpisodeCatalogCacheTableTable> {
  $$EpisodeCatalogCacheTableTableAnnotationComposer({
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

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get airDate =>
      $composableBuilder(column: $table.airDate, builder: (column) => column);

  GeneratedColumn<bool> get isAired =>
      $composableBuilder(column: $table.isAired, builder: (column) => column);

  GeneratedColumn<bool> get isFiller =>
      $composableBuilder(column: $table.isFiller, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EpisodeCatalogCacheTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpisodeCatalogCacheTableTable,
          EpisodeCatalogCacheTableData,
          $$EpisodeCatalogCacheTableTableFilterComposer,
          $$EpisodeCatalogCacheTableTableOrderingComposer,
          $$EpisodeCatalogCacheTableTableAnnotationComposer,
          $$EpisodeCatalogCacheTableTableCreateCompanionBuilder,
          $$EpisodeCatalogCacheTableTableUpdateCompanionBuilder,
          (
            EpisodeCatalogCacheTableData,
            BaseReferences<
              _$AppDatabase,
              $EpisodeCatalogCacheTableTable,
              EpisodeCatalogCacheTableData
            >,
          ),
          EpisodeCatalogCacheTableData,
          PrefetchHooks Function()
        > {
  $$EpisodeCatalogCacheTableTableTableManager(
    _$AppDatabase db,
    $EpisodeCatalogCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodeCatalogCacheTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$EpisodeCatalogCacheTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$EpisodeCatalogCacheTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                Value<double> episodeNumber = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int?> airDate = const Value.absent(),
                Value<bool> isAired = const Value.absent(),
                Value<bool> isFiller = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpisodeCatalogCacheTableCompanion(
                anilistId: anilistId,
                episodeNumber: episodeNumber,
                title: title,
                airDate: airDate,
                isAired: isAired,
                isFiller: isFiller,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int anilistId,
                required double episodeNumber,
                required String title,
                Value<int?> airDate = const Value.absent(),
                Value<bool> isAired = const Value.absent(),
                Value<bool> isFiller = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => EpisodeCatalogCacheTableCompanion.insert(
                anilistId: anilistId,
                episodeNumber: episodeNumber,
                title: title,
                airDate: airDate,
                isAired: isAired,
                isFiller: isFiller,
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

typedef $$EpisodeCatalogCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpisodeCatalogCacheTableTable,
      EpisodeCatalogCacheTableData,
      $$EpisodeCatalogCacheTableTableFilterComposer,
      $$EpisodeCatalogCacheTableTableOrderingComposer,
      $$EpisodeCatalogCacheTableTableAnnotationComposer,
      $$EpisodeCatalogCacheTableTableCreateCompanionBuilder,
      $$EpisodeCatalogCacheTableTableUpdateCompanionBuilder,
      (
        EpisodeCatalogCacheTableData,
        BaseReferences<
          _$AppDatabase,
          $EpisodeCatalogCacheTableTable,
          EpisodeCatalogCacheTableData
        >,
      ),
      EpisodeCatalogCacheTableData,
      PrefetchHooks Function()
    >;
typedef $$MangaCacheTableTableCreateCompanionBuilder =
    MangaCacheTableCompanion Function({
      Value<int> anilistId,
      required String titleRomaji,
      Value<String?> titleEnglish,
      Value<String?> titleNative,
      Value<String?> synonyms,
      Value<String?> coverImageUrl,
      Value<String?> bannerImageUrl,
      Value<String?> status,
      Value<String?> format,
      Value<String?> countryOfOrigin,
      Value<String?> originalLanguage,
      Value<int?> releaseYear,
      Value<int?> totalChapters,
      Value<int?> totalVolumes,
      Value<int?> averageScore,
      Value<int?> popularity,
      Value<String?> genres,
      Value<String?> tags,
      Value<String?> synopsis,
      Value<String?> relations,
      required int updatedAt,
    });
typedef $$MangaCacheTableTableUpdateCompanionBuilder =
    MangaCacheTableCompanion Function({
      Value<int> anilistId,
      Value<String> titleRomaji,
      Value<String?> titleEnglish,
      Value<String?> titleNative,
      Value<String?> synonyms,
      Value<String?> coverImageUrl,
      Value<String?> bannerImageUrl,
      Value<String?> status,
      Value<String?> format,
      Value<String?> countryOfOrigin,
      Value<String?> originalLanguage,
      Value<int?> releaseYear,
      Value<int?> totalChapters,
      Value<int?> totalVolumes,
      Value<int?> averageScore,
      Value<int?> popularity,
      Value<String?> genres,
      Value<String?> tags,
      Value<String?> synopsis,
      Value<String?> relations,
      Value<int> updatedAt,
    });

class $$MangaCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $MangaCacheTableTable> {
  $$MangaCacheTableTableFilterComposer({
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

  ColumnFilters<String> get titleRomaji => $composableBuilder(
    column: $table.titleRomaji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleEnglish => $composableBuilder(
    column: $table.titleEnglish,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleNative => $composableBuilder(
    column: $table.titleNative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get synonyms => $composableBuilder(
    column: $table.synonyms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverImageUrl => $composableBuilder(
    column: $table.coverImageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bannerImageUrl => $composableBuilder(
    column: $table.bannerImageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get countryOfOrigin => $composableBuilder(
    column: $table.countryOfOrigin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalLanguage => $composableBuilder(
    column: $table.originalLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get releaseYear => $composableBuilder(
    column: $table.releaseYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalVolumes => $composableBuilder(
    column: $table.totalVolumes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get averageScore => $composableBuilder(
    column: $table.averageScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get popularity => $composableBuilder(
    column: $table.popularity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genres => $composableBuilder(
    column: $table.genres,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get synopsis => $composableBuilder(
    column: $table.synopsis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relations => $composableBuilder(
    column: $table.relations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MangaCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MangaCacheTableTable> {
  $$MangaCacheTableTableOrderingComposer({
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

  ColumnOrderings<String> get titleRomaji => $composableBuilder(
    column: $table.titleRomaji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleEnglish => $composableBuilder(
    column: $table.titleEnglish,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleNative => $composableBuilder(
    column: $table.titleNative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get synonyms => $composableBuilder(
    column: $table.synonyms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverImageUrl => $composableBuilder(
    column: $table.coverImageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bannerImageUrl => $composableBuilder(
    column: $table.bannerImageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get countryOfOrigin => $composableBuilder(
    column: $table.countryOfOrigin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalLanguage => $composableBuilder(
    column: $table.originalLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get releaseYear => $composableBuilder(
    column: $table.releaseYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalVolumes => $composableBuilder(
    column: $table.totalVolumes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get averageScore => $composableBuilder(
    column: $table.averageScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get popularity => $composableBuilder(
    column: $table.popularity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genres => $composableBuilder(
    column: $table.genres,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get synopsis => $composableBuilder(
    column: $table.synopsis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relations => $composableBuilder(
    column: $table.relations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MangaCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MangaCacheTableTable> {
  $$MangaCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get anilistId =>
      $composableBuilder(column: $table.anilistId, builder: (column) => column);

  GeneratedColumn<String> get titleRomaji => $composableBuilder(
    column: $table.titleRomaji,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleEnglish => $composableBuilder(
    column: $table.titleEnglish,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleNative => $composableBuilder(
    column: $table.titleNative,
    builder: (column) => column,
  );

  GeneratedColumn<String> get synonyms =>
      $composableBuilder(column: $table.synonyms, builder: (column) => column);

  GeneratedColumn<String> get coverImageUrl => $composableBuilder(
    column: $table.coverImageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bannerImageUrl => $composableBuilder(
    column: $table.bannerImageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get countryOfOrigin => $composableBuilder(
    column: $table.countryOfOrigin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalLanguage => $composableBuilder(
    column: $table.originalLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get releaseYear => $composableBuilder(
    column: $table.releaseYear,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalVolumes => $composableBuilder(
    column: $table.totalVolumes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get averageScore => $composableBuilder(
    column: $table.averageScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get popularity => $composableBuilder(
    column: $table.popularity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genres =>
      $composableBuilder(column: $table.genres, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get synopsis =>
      $composableBuilder(column: $table.synopsis, builder: (column) => column);

  GeneratedColumn<String> get relations =>
      $composableBuilder(column: $table.relations, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MangaCacheTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MangaCacheTableTable,
          MangaCacheTableData,
          $$MangaCacheTableTableFilterComposer,
          $$MangaCacheTableTableOrderingComposer,
          $$MangaCacheTableTableAnnotationComposer,
          $$MangaCacheTableTableCreateCompanionBuilder,
          $$MangaCacheTableTableUpdateCompanionBuilder,
          (
            MangaCacheTableData,
            BaseReferences<
              _$AppDatabase,
              $MangaCacheTableTable,
              MangaCacheTableData
            >,
          ),
          MangaCacheTableData,
          PrefetchHooks Function()
        > {
  $$MangaCacheTableTableTableManager(
    _$AppDatabase db,
    $MangaCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MangaCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MangaCacheTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MangaCacheTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                Value<String> titleRomaji = const Value.absent(),
                Value<String?> titleEnglish = const Value.absent(),
                Value<String?> titleNative = const Value.absent(),
                Value<String?> synonyms = const Value.absent(),
                Value<String?> coverImageUrl = const Value.absent(),
                Value<String?> bannerImageUrl = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<String?> countryOfOrigin = const Value.absent(),
                Value<String?> originalLanguage = const Value.absent(),
                Value<int?> releaseYear = const Value.absent(),
                Value<int?> totalChapters = const Value.absent(),
                Value<int?> totalVolumes = const Value.absent(),
                Value<int?> averageScore = const Value.absent(),
                Value<int?> popularity = const Value.absent(),
                Value<String?> genres = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> synopsis = const Value.absent(),
                Value<String?> relations = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => MangaCacheTableCompanion(
                anilistId: anilistId,
                titleRomaji: titleRomaji,
                titleEnglish: titleEnglish,
                titleNative: titleNative,
                synonyms: synonyms,
                coverImageUrl: coverImageUrl,
                bannerImageUrl: bannerImageUrl,
                status: status,
                format: format,
                countryOfOrigin: countryOfOrigin,
                originalLanguage: originalLanguage,
                releaseYear: releaseYear,
                totalChapters: totalChapters,
                totalVolumes: totalVolumes,
                averageScore: averageScore,
                popularity: popularity,
                genres: genres,
                tags: tags,
                synopsis: synopsis,
                relations: relations,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                required String titleRomaji,
                Value<String?> titleEnglish = const Value.absent(),
                Value<String?> titleNative = const Value.absent(),
                Value<String?> synonyms = const Value.absent(),
                Value<String?> coverImageUrl = const Value.absent(),
                Value<String?> bannerImageUrl = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<String?> countryOfOrigin = const Value.absent(),
                Value<String?> originalLanguage = const Value.absent(),
                Value<int?> releaseYear = const Value.absent(),
                Value<int?> totalChapters = const Value.absent(),
                Value<int?> totalVolumes = const Value.absent(),
                Value<int?> averageScore = const Value.absent(),
                Value<int?> popularity = const Value.absent(),
                Value<String?> genres = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String?> synopsis = const Value.absent(),
                Value<String?> relations = const Value.absent(),
                required int updatedAt,
              }) => MangaCacheTableCompanion.insert(
                anilistId: anilistId,
                titleRomaji: titleRomaji,
                titleEnglish: titleEnglish,
                titleNative: titleNative,
                synonyms: synonyms,
                coverImageUrl: coverImageUrl,
                bannerImageUrl: bannerImageUrl,
                status: status,
                format: format,
                countryOfOrigin: countryOfOrigin,
                originalLanguage: originalLanguage,
                releaseYear: releaseYear,
                totalChapters: totalChapters,
                totalVolumes: totalVolumes,
                averageScore: averageScore,
                popularity: popularity,
                genres: genres,
                tags: tags,
                synopsis: synopsis,
                relations: relations,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MangaCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MangaCacheTableTable,
      MangaCacheTableData,
      $$MangaCacheTableTableFilterComposer,
      $$MangaCacheTableTableOrderingComposer,
      $$MangaCacheTableTableAnnotationComposer,
      $$MangaCacheTableTableCreateCompanionBuilder,
      $$MangaCacheTableTableUpdateCompanionBuilder,
      (
        MangaCacheTableData,
        BaseReferences<
          _$AppDatabase,
          $MangaCacheTableTable,
          MangaCacheTableData
        >,
      ),
      MangaCacheTableData,
      PrefetchHooks Function()
    >;
typedef $$MangaChapterTableTableCreateCompanionBuilder =
    MangaChapterTableCompanion Function({
      required String sourceId,
      required String sourceChapterId,
      required int mangaAnilistId,
      required String sourceMangaId,
      required double number,
      Value<String?> title,
      Value<int?> volume,
      Value<String> language,
      Value<String?> scanlator,
      Value<int?> publishedAt,
      Value<int?> pageCount,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$MangaChapterTableTableUpdateCompanionBuilder =
    MangaChapterTableCompanion Function({
      Value<String> sourceId,
      Value<String> sourceChapterId,
      Value<int> mangaAnilistId,
      Value<String> sourceMangaId,
      Value<double> number,
      Value<String?> title,
      Value<int?> volume,
      Value<String> language,
      Value<String?> scanlator,
      Value<int?> publishedAt,
      Value<int?> pageCount,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$MangaChapterTableTableFilterComposer
    extends Composer<_$AppDatabase, $MangaChapterTableTable> {
  $$MangaChapterTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mangaAnilistId => $composableBuilder(
    column: $table.mangaAnilistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceMangaId => $composableBuilder(
    column: $table.sourceMangaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scanlator => $composableBuilder(
    column: $table.scanlator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MangaChapterTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MangaChapterTableTable> {
  $$MangaChapterTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mangaAnilistId => $composableBuilder(
    column: $table.mangaAnilistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceMangaId => $composableBuilder(
    column: $table.sourceMangaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scanlator => $composableBuilder(
    column: $table.scanlator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MangaChapterTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MangaChapterTableTable> {
  $$MangaChapterTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mangaAnilistId => $composableBuilder(
    column: $table.mangaAnilistId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceMangaId => $composableBuilder(
    column: $table.sourceMangaId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get volume =>
      $composableBuilder(column: $table.volume, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get scanlator =>
      $composableBuilder(column: $table.scanlator, builder: (column) => column);

  GeneratedColumn<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MangaChapterTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MangaChapterTableTable,
          MangaChapterTableData,
          $$MangaChapterTableTableFilterComposer,
          $$MangaChapterTableTableOrderingComposer,
          $$MangaChapterTableTableAnnotationComposer,
          $$MangaChapterTableTableCreateCompanionBuilder,
          $$MangaChapterTableTableUpdateCompanionBuilder,
          (
            MangaChapterTableData,
            BaseReferences<
              _$AppDatabase,
              $MangaChapterTableTable,
              MangaChapterTableData
            >,
          ),
          MangaChapterTableData,
          PrefetchHooks Function()
        > {
  $$MangaChapterTableTableTableManager(
    _$AppDatabase db,
    $MangaChapterTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MangaChapterTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MangaChapterTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MangaChapterTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<String> sourceChapterId = const Value.absent(),
                Value<int> mangaAnilistId = const Value.absent(),
                Value<String> sourceMangaId = const Value.absent(),
                Value<double> number = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<int?> volume = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String?> scanlator = const Value.absent(),
                Value<int?> publishedAt = const Value.absent(),
                Value<int?> pageCount = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MangaChapterTableCompanion(
                sourceId: sourceId,
                sourceChapterId: sourceChapterId,
                mangaAnilistId: mangaAnilistId,
                sourceMangaId: sourceMangaId,
                number: number,
                title: title,
                volume: volume,
                language: language,
                scanlator: scanlator,
                publishedAt: publishedAt,
                pageCount: pageCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                required String sourceChapterId,
                required int mangaAnilistId,
                required String sourceMangaId,
                required double number,
                Value<String?> title = const Value.absent(),
                Value<int?> volume = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String?> scanlator = const Value.absent(),
                Value<int?> publishedAt = const Value.absent(),
                Value<int?> pageCount = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MangaChapterTableCompanion.insert(
                sourceId: sourceId,
                sourceChapterId: sourceChapterId,
                mangaAnilistId: mangaAnilistId,
                sourceMangaId: sourceMangaId,
                number: number,
                title: title,
                volume: volume,
                language: language,
                scanlator: scanlator,
                publishedAt: publishedAt,
                pageCount: pageCount,
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

typedef $$MangaChapterTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MangaChapterTableTable,
      MangaChapterTableData,
      $$MangaChapterTableTableFilterComposer,
      $$MangaChapterTableTableOrderingComposer,
      $$MangaChapterTableTableAnnotationComposer,
      $$MangaChapterTableTableCreateCompanionBuilder,
      $$MangaChapterTableTableUpdateCompanionBuilder,
      (
        MangaChapterTableData,
        BaseReferences<
          _$AppDatabase,
          $MangaChapterTableTable,
          MangaChapterTableData
        >,
      ),
      MangaChapterTableData,
      PrefetchHooks Function()
    >;
typedef $$MangaProgressTableTableCreateCompanionBuilder =
    MangaProgressTableCompanion Function({
      required int mangaAnilistId,
      required String sourceId,
      required String sourceChapterId,
      required double chapterNumber,
      Value<int> pageIndex,
      Value<double?> scrollOffset,
      Value<String> readState,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$MangaProgressTableTableUpdateCompanionBuilder =
    MangaProgressTableCompanion Function({
      Value<int> mangaAnilistId,
      Value<String> sourceId,
      Value<String> sourceChapterId,
      Value<double> chapterNumber,
      Value<int> pageIndex,
      Value<double?> scrollOffset,
      Value<String> readState,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$MangaProgressTableTableFilterComposer
    extends Composer<_$AppDatabase, $MangaProgressTableTable> {
  $$MangaProgressTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get mangaAnilistId => $composableBuilder(
    column: $table.mangaAnilistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get chapterNumber => $composableBuilder(
    column: $table.chapterNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get scrollOffset => $composableBuilder(
    column: $table.scrollOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readState => $composableBuilder(
    column: $table.readState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MangaProgressTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MangaProgressTableTable> {
  $$MangaProgressTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get mangaAnilistId => $composableBuilder(
    column: $table.mangaAnilistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get chapterNumber => $composableBuilder(
    column: $table.chapterNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get scrollOffset => $composableBuilder(
    column: $table.scrollOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readState => $composableBuilder(
    column: $table.readState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MangaProgressTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MangaProgressTableTable> {
  $$MangaProgressTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get mangaAnilistId => $composableBuilder(
    column: $table.mangaAnilistId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get chapterNumber => $composableBuilder(
    column: $table.chapterNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<double> get scrollOffset => $composableBuilder(
    column: $table.scrollOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get readState =>
      $composableBuilder(column: $table.readState, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MangaProgressTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MangaProgressTableTable,
          MangaProgressTableData,
          $$MangaProgressTableTableFilterComposer,
          $$MangaProgressTableTableOrderingComposer,
          $$MangaProgressTableTableAnnotationComposer,
          $$MangaProgressTableTableCreateCompanionBuilder,
          $$MangaProgressTableTableUpdateCompanionBuilder,
          (
            MangaProgressTableData,
            BaseReferences<
              _$AppDatabase,
              $MangaProgressTableTable,
              MangaProgressTableData
            >,
          ),
          MangaProgressTableData,
          PrefetchHooks Function()
        > {
  $$MangaProgressTableTableTableManager(
    _$AppDatabase db,
    $MangaProgressTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MangaProgressTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MangaProgressTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MangaProgressTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> mangaAnilistId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> sourceChapterId = const Value.absent(),
                Value<double> chapterNumber = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<double?> scrollOffset = const Value.absent(),
                Value<String> readState = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MangaProgressTableCompanion(
                mangaAnilistId: mangaAnilistId,
                sourceId: sourceId,
                sourceChapterId: sourceChapterId,
                chapterNumber: chapterNumber,
                pageIndex: pageIndex,
                scrollOffset: scrollOffset,
                readState: readState,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int mangaAnilistId,
                required String sourceId,
                required String sourceChapterId,
                required double chapterNumber,
                Value<int> pageIndex = const Value.absent(),
                Value<double?> scrollOffset = const Value.absent(),
                Value<String> readState = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MangaProgressTableCompanion.insert(
                mangaAnilistId: mangaAnilistId,
                sourceId: sourceId,
                sourceChapterId: sourceChapterId,
                chapterNumber: chapterNumber,
                pageIndex: pageIndex,
                scrollOffset: scrollOffset,
                readState: readState,
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

typedef $$MangaProgressTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MangaProgressTableTable,
      MangaProgressTableData,
      $$MangaProgressTableTableFilterComposer,
      $$MangaProgressTableTableOrderingComposer,
      $$MangaProgressTableTableAnnotationComposer,
      $$MangaProgressTableTableCreateCompanionBuilder,
      $$MangaProgressTableTableUpdateCompanionBuilder,
      (
        MangaProgressTableData,
        BaseReferences<
          _$AppDatabase,
          $MangaProgressTableTable,
          MangaProgressTableData
        >,
      ),
      MangaProgressTableData,
      PrefetchHooks Function()
    >;
typedef $$MangaHistoryTableTableCreateCompanionBuilder =
    MangaHistoryTableCompanion Function({
      Value<int> mangaAnilistId,
      required double lastChapterNumber,
      Value<String?> lastSourceId,
      Value<String?> lastSourceChapterId,
      Value<int?> lastPageIndex,
      required int lastAccessedAt,
    });
typedef $$MangaHistoryTableTableUpdateCompanionBuilder =
    MangaHistoryTableCompanion Function({
      Value<int> mangaAnilistId,
      Value<double> lastChapterNumber,
      Value<String?> lastSourceId,
      Value<String?> lastSourceChapterId,
      Value<int?> lastPageIndex,
      Value<int> lastAccessedAt,
    });

class $$MangaHistoryTableTableFilterComposer
    extends Composer<_$AppDatabase, $MangaHistoryTableTable> {
  $$MangaHistoryTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get mangaAnilistId => $composableBuilder(
    column: $table.mangaAnilistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lastChapterNumber => $composableBuilder(
    column: $table.lastChapterNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSourceId => $composableBuilder(
    column: $table.lastSourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSourceChapterId => $composableBuilder(
    column: $table.lastSourceChapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPageIndex => $composableBuilder(
    column: $table.lastPageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MangaHistoryTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MangaHistoryTableTable> {
  $$MangaHistoryTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get mangaAnilistId => $composableBuilder(
    column: $table.mangaAnilistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lastChapterNumber => $composableBuilder(
    column: $table.lastChapterNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSourceId => $composableBuilder(
    column: $table.lastSourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSourceChapterId => $composableBuilder(
    column: $table.lastSourceChapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPageIndex => $composableBuilder(
    column: $table.lastPageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MangaHistoryTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MangaHistoryTableTable> {
  $$MangaHistoryTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get mangaAnilistId => $composableBuilder(
    column: $table.mangaAnilistId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get lastChapterNumber => $composableBuilder(
    column: $table.lastChapterNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSourceId => $composableBuilder(
    column: $table.lastSourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSourceChapterId => $composableBuilder(
    column: $table.lastSourceChapterId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastPageIndex => $composableBuilder(
    column: $table.lastPageIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => column,
  );
}

class $$MangaHistoryTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MangaHistoryTableTable,
          MangaHistoryTableData,
          $$MangaHistoryTableTableFilterComposer,
          $$MangaHistoryTableTableOrderingComposer,
          $$MangaHistoryTableTableAnnotationComposer,
          $$MangaHistoryTableTableCreateCompanionBuilder,
          $$MangaHistoryTableTableUpdateCompanionBuilder,
          (
            MangaHistoryTableData,
            BaseReferences<
              _$AppDatabase,
              $MangaHistoryTableTable,
              MangaHistoryTableData
            >,
          ),
          MangaHistoryTableData,
          PrefetchHooks Function()
        > {
  $$MangaHistoryTableTableTableManager(
    _$AppDatabase db,
    $MangaHistoryTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MangaHistoryTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MangaHistoryTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MangaHistoryTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> mangaAnilistId = const Value.absent(),
                Value<double> lastChapterNumber = const Value.absent(),
                Value<String?> lastSourceId = const Value.absent(),
                Value<String?> lastSourceChapterId = const Value.absent(),
                Value<int?> lastPageIndex = const Value.absent(),
                Value<int> lastAccessedAt = const Value.absent(),
              }) => MangaHistoryTableCompanion(
                mangaAnilistId: mangaAnilistId,
                lastChapterNumber: lastChapterNumber,
                lastSourceId: lastSourceId,
                lastSourceChapterId: lastSourceChapterId,
                lastPageIndex: lastPageIndex,
                lastAccessedAt: lastAccessedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> mangaAnilistId = const Value.absent(),
                required double lastChapterNumber,
                Value<String?> lastSourceId = const Value.absent(),
                Value<String?> lastSourceChapterId = const Value.absent(),
                Value<int?> lastPageIndex = const Value.absent(),
                required int lastAccessedAt,
              }) => MangaHistoryTableCompanion.insert(
                mangaAnilistId: mangaAnilistId,
                lastChapterNumber: lastChapterNumber,
                lastSourceId: lastSourceId,
                lastSourceChapterId: lastSourceChapterId,
                lastPageIndex: lastPageIndex,
                lastAccessedAt: lastAccessedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MangaHistoryTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MangaHistoryTableTable,
      MangaHistoryTableData,
      $$MangaHistoryTableTableFilterComposer,
      $$MangaHistoryTableTableOrderingComposer,
      $$MangaHistoryTableTableAnnotationComposer,
      $$MangaHistoryTableTableCreateCompanionBuilder,
      $$MangaHistoryTableTableUpdateCompanionBuilder,
      (
        MangaHistoryTableData,
        BaseReferences<
          _$AppDatabase,
          $MangaHistoryTableTable,
          MangaHistoryTableData
        >,
      ),
      MangaHistoryTableData,
      PrefetchHooks Function()
    >;
typedef $$MangaLibraryTableTableCreateCompanionBuilder =
    MangaLibraryTableCompanion Function({
      Value<int> mangaAnilistId,
      required int addedAt,
      Value<bool> notifyNewChapters,
      Value<double?> lastNotifiedChapter,
      Value<bool> autoDownloadNewChapters,
      Value<String?> preferredLanguage,
      Value<String?> preferredScanlator,
      Value<String?> preferredSourceId,
    });
typedef $$MangaLibraryTableTableUpdateCompanionBuilder =
    MangaLibraryTableCompanion Function({
      Value<int> mangaAnilistId,
      Value<int> addedAt,
      Value<bool> notifyNewChapters,
      Value<double?> lastNotifiedChapter,
      Value<bool> autoDownloadNewChapters,
      Value<String?> preferredLanguage,
      Value<String?> preferredScanlator,
      Value<String?> preferredSourceId,
    });

class $$MangaLibraryTableTableFilterComposer
    extends Composer<_$AppDatabase, $MangaLibraryTableTable> {
  $$MangaLibraryTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get mangaAnilistId => $composableBuilder(
    column: $table.mangaAnilistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notifyNewChapters => $composableBuilder(
    column: $table.notifyNewChapters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lastNotifiedChapter => $composableBuilder(
    column: $table.lastNotifiedChapter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoDownloadNewChapters => $composableBuilder(
    column: $table.autoDownloadNewChapters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredLanguage => $composableBuilder(
    column: $table.preferredLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredScanlator => $composableBuilder(
    column: $table.preferredScanlator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredSourceId => $composableBuilder(
    column: $table.preferredSourceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MangaLibraryTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MangaLibraryTableTable> {
  $$MangaLibraryTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get mangaAnilistId => $composableBuilder(
    column: $table.mangaAnilistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notifyNewChapters => $composableBuilder(
    column: $table.notifyNewChapters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lastNotifiedChapter => $composableBuilder(
    column: $table.lastNotifiedChapter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoDownloadNewChapters => $composableBuilder(
    column: $table.autoDownloadNewChapters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredLanguage => $composableBuilder(
    column: $table.preferredLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredScanlator => $composableBuilder(
    column: $table.preferredScanlator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredSourceId => $composableBuilder(
    column: $table.preferredSourceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MangaLibraryTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MangaLibraryTableTable> {
  $$MangaLibraryTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get mangaAnilistId => $composableBuilder(
    column: $table.mangaAnilistId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<bool> get notifyNewChapters => $composableBuilder(
    column: $table.notifyNewChapters,
    builder: (column) => column,
  );

  GeneratedColumn<double> get lastNotifiedChapter => $composableBuilder(
    column: $table.lastNotifiedChapter,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoDownloadNewChapters => $composableBuilder(
    column: $table.autoDownloadNewChapters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredLanguage => $composableBuilder(
    column: $table.preferredLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredScanlator => $composableBuilder(
    column: $table.preferredScanlator,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredSourceId => $composableBuilder(
    column: $table.preferredSourceId,
    builder: (column) => column,
  );
}

class $$MangaLibraryTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MangaLibraryTableTable,
          MangaLibraryTableData,
          $$MangaLibraryTableTableFilterComposer,
          $$MangaLibraryTableTableOrderingComposer,
          $$MangaLibraryTableTableAnnotationComposer,
          $$MangaLibraryTableTableCreateCompanionBuilder,
          $$MangaLibraryTableTableUpdateCompanionBuilder,
          (
            MangaLibraryTableData,
            BaseReferences<
              _$AppDatabase,
              $MangaLibraryTableTable,
              MangaLibraryTableData
            >,
          ),
          MangaLibraryTableData,
          PrefetchHooks Function()
        > {
  $$MangaLibraryTableTableTableManager(
    _$AppDatabase db,
    $MangaLibraryTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MangaLibraryTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MangaLibraryTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MangaLibraryTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> mangaAnilistId = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<bool> notifyNewChapters = const Value.absent(),
                Value<double?> lastNotifiedChapter = const Value.absent(),
                Value<bool> autoDownloadNewChapters = const Value.absent(),
                Value<String?> preferredLanguage = const Value.absent(),
                Value<String?> preferredScanlator = const Value.absent(),
                Value<String?> preferredSourceId = const Value.absent(),
              }) => MangaLibraryTableCompanion(
                mangaAnilistId: mangaAnilistId,
                addedAt: addedAt,
                notifyNewChapters: notifyNewChapters,
                lastNotifiedChapter: lastNotifiedChapter,
                autoDownloadNewChapters: autoDownloadNewChapters,
                preferredLanguage: preferredLanguage,
                preferredScanlator: preferredScanlator,
                preferredSourceId: preferredSourceId,
              ),
          createCompanionCallback:
              ({
                Value<int> mangaAnilistId = const Value.absent(),
                required int addedAt,
                Value<bool> notifyNewChapters = const Value.absent(),
                Value<double?> lastNotifiedChapter = const Value.absent(),
                Value<bool> autoDownloadNewChapters = const Value.absent(),
                Value<String?> preferredLanguage = const Value.absent(),
                Value<String?> preferredScanlator = const Value.absent(),
                Value<String?> preferredSourceId = const Value.absent(),
              }) => MangaLibraryTableCompanion.insert(
                mangaAnilistId: mangaAnilistId,
                addedAt: addedAt,
                notifyNewChapters: notifyNewChapters,
                lastNotifiedChapter: lastNotifiedChapter,
                autoDownloadNewChapters: autoDownloadNewChapters,
                preferredLanguage: preferredLanguage,
                preferredScanlator: preferredScanlator,
                preferredSourceId: preferredSourceId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MangaLibraryTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MangaLibraryTableTable,
      MangaLibraryTableData,
      $$MangaLibraryTableTableFilterComposer,
      $$MangaLibraryTableTableOrderingComposer,
      $$MangaLibraryTableTableAnnotationComposer,
      $$MangaLibraryTableTableCreateCompanionBuilder,
      $$MangaLibraryTableTableUpdateCompanionBuilder,
      (
        MangaLibraryTableData,
        BaseReferences<
          _$AppDatabase,
          $MangaLibraryTableTable,
          MangaLibraryTableData
        >,
      ),
      MangaLibraryTableData,
      PrefetchHooks Function()
    >;
typedef $$ChapterPageCacheTableTableCreateCompanionBuilder =
    ChapterPageCacheTableCompanion Function({
      required String sourceId,
      required String sourceChapterId,
      required int pageIndex,
      required String imageUrl,
      Value<String?> headers,
      Value<String?> localPath,
      Value<int?> bytes,
      Value<int?> width,
      Value<int?> height,
      Value<int?> expiresAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ChapterPageCacheTableTableUpdateCompanionBuilder =
    ChapterPageCacheTableCompanion Function({
      Value<String> sourceId,
      Value<String> sourceChapterId,
      Value<int> pageIndex,
      Value<String> imageUrl,
      Value<String?> headers,
      Value<String?> localPath,
      Value<int?> bytes,
      Value<int?> width,
      Value<int?> height,
      Value<int?> expiresAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$ChapterPageCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $ChapterPageCacheTableTable> {
  $$ChapterPageCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headers => $composableBuilder(
    column: $table.headers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChapterPageCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ChapterPageCacheTableTable> {
  $$ChapterPageCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headers => $composableBuilder(
    column: $table.headers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChapterPageCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChapterPageCacheTableTable> {
  $$ChapterPageCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get headers =>
      $composableBuilder(column: $table.headers, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ChapterPageCacheTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChapterPageCacheTableTable,
          ChapterPageCacheTableData,
          $$ChapterPageCacheTableTableFilterComposer,
          $$ChapterPageCacheTableTableOrderingComposer,
          $$ChapterPageCacheTableTableAnnotationComposer,
          $$ChapterPageCacheTableTableCreateCompanionBuilder,
          $$ChapterPageCacheTableTableUpdateCompanionBuilder,
          (
            ChapterPageCacheTableData,
            BaseReferences<
              _$AppDatabase,
              $ChapterPageCacheTableTable,
              ChapterPageCacheTableData
            >,
          ),
          ChapterPageCacheTableData,
          PrefetchHooks Function()
        > {
  $$ChapterPageCacheTableTableTableManager(
    _$AppDatabase db,
    $ChapterPageCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChapterPageCacheTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ChapterPageCacheTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ChapterPageCacheTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<String> sourceChapterId = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<String> imageUrl = const Value.absent(),
                Value<String?> headers = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int?> bytes = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<int?> expiresAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChapterPageCacheTableCompanion(
                sourceId: sourceId,
                sourceChapterId: sourceChapterId,
                pageIndex: pageIndex,
                imageUrl: imageUrl,
                headers: headers,
                localPath: localPath,
                bytes: bytes,
                width: width,
                height: height,
                expiresAt: expiresAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                required String sourceChapterId,
                required int pageIndex,
                required String imageUrl,
                Value<String?> headers = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int?> bytes = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<int?> expiresAt = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ChapterPageCacheTableCompanion.insert(
                sourceId: sourceId,
                sourceChapterId: sourceChapterId,
                pageIndex: pageIndex,
                imageUrl: imageUrl,
                headers: headers,
                localPath: localPath,
                bytes: bytes,
                width: width,
                height: height,
                expiresAt: expiresAt,
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

typedef $$ChapterPageCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChapterPageCacheTableTable,
      ChapterPageCacheTableData,
      $$ChapterPageCacheTableTableFilterComposer,
      $$ChapterPageCacheTableTableOrderingComposer,
      $$ChapterPageCacheTableTableAnnotationComposer,
      $$ChapterPageCacheTableTableCreateCompanionBuilder,
      $$ChapterPageCacheTableTableUpdateCompanionBuilder,
      (
        ChapterPageCacheTableData,
        BaseReferences<
          _$AppDatabase,
          $ChapterPageCacheTableTable,
          ChapterPageCacheTableData
        >,
      ),
      ChapterPageCacheTableData,
      PrefetchHooks Function()
    >;
typedef $$MangaDownloadTableTableCreateCompanionBuilder =
    MangaDownloadTableCompanion Function({
      required String id,
      required int mangaAnilistId,
      required String sourceId,
      required String sourceMangaId,
      required String sourceChapterId,
      required double chapterNumber,
      Value<int?> volume,
      Value<String> language,
      Value<String?> scanlator,
      Value<String?> mangaTitle,
      Value<String?> chapterTitle,
      Value<String> status,
      Value<int?> pageCount,
      Value<int?> pagesDownloaded,
      Value<int?> totalBytes,
      Value<int?> downloadedBytes,
      Value<String?> cbzPath,
      Value<String?> errorMessage,
      required int createdAt,
      Value<int?> updatedAt,
      Value<int> rowid,
    });
typedef $$MangaDownloadTableTableUpdateCompanionBuilder =
    MangaDownloadTableCompanion Function({
      Value<String> id,
      Value<int> mangaAnilistId,
      Value<String> sourceId,
      Value<String> sourceMangaId,
      Value<String> sourceChapterId,
      Value<double> chapterNumber,
      Value<int?> volume,
      Value<String> language,
      Value<String?> scanlator,
      Value<String?> mangaTitle,
      Value<String?> chapterTitle,
      Value<String> status,
      Value<int?> pageCount,
      Value<int?> pagesDownloaded,
      Value<int?> totalBytes,
      Value<int?> downloadedBytes,
      Value<String?> cbzPath,
      Value<String?> errorMessage,
      Value<int> createdAt,
      Value<int?> updatedAt,
      Value<int> rowid,
    });

class $$MangaDownloadTableTableFilterComposer
    extends Composer<_$AppDatabase, $MangaDownloadTableTable> {
  $$MangaDownloadTableTableFilterComposer({
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

  ColumnFilters<int> get mangaAnilistId => $composableBuilder(
    column: $table.mangaAnilistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceMangaId => $composableBuilder(
    column: $table.sourceMangaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get chapterNumber => $composableBuilder(
    column: $table.chapterNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scanlator => $composableBuilder(
    column: $table.scanlator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mangaTitle => $composableBuilder(
    column: $table.mangaTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pagesDownloaded => $composableBuilder(
    column: $table.pagesDownloaded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cbzPath => $composableBuilder(
    column: $table.cbzPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MangaDownloadTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MangaDownloadTableTable> {
  $$MangaDownloadTableTableOrderingComposer({
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

  ColumnOrderings<int> get mangaAnilistId => $composableBuilder(
    column: $table.mangaAnilistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceMangaId => $composableBuilder(
    column: $table.sourceMangaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get chapterNumber => $composableBuilder(
    column: $table.chapterNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scanlator => $composableBuilder(
    column: $table.scanlator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mangaTitle => $composableBuilder(
    column: $table.mangaTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pagesDownloaded => $composableBuilder(
    column: $table.pagesDownloaded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cbzPath => $composableBuilder(
    column: $table.cbzPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MangaDownloadTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MangaDownloadTableTable> {
  $$MangaDownloadTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get mangaAnilistId => $composableBuilder(
    column: $table.mangaAnilistId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get sourceMangaId => $composableBuilder(
    column: $table.sourceMangaId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceChapterId => $composableBuilder(
    column: $table.sourceChapterId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get chapterNumber => $composableBuilder(
    column: $table.chapterNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get volume =>
      $composableBuilder(column: $table.volume, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get scanlator =>
      $composableBuilder(column: $table.scanlator, builder: (column) => column);

  GeneratedColumn<String> get mangaTitle => $composableBuilder(
    column: $table.mangaTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<int> get pagesDownloaded => $composableBuilder(
    column: $table.pagesDownloaded,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cbzPath =>
      $composableBuilder(column: $table.cbzPath, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MangaDownloadTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MangaDownloadTableTable,
          MangaDownloadTableData,
          $$MangaDownloadTableTableFilterComposer,
          $$MangaDownloadTableTableOrderingComposer,
          $$MangaDownloadTableTableAnnotationComposer,
          $$MangaDownloadTableTableCreateCompanionBuilder,
          $$MangaDownloadTableTableUpdateCompanionBuilder,
          (
            MangaDownloadTableData,
            BaseReferences<
              _$AppDatabase,
              $MangaDownloadTableTable,
              MangaDownloadTableData
            >,
          ),
          MangaDownloadTableData,
          PrefetchHooks Function()
        > {
  $$MangaDownloadTableTableTableManager(
    _$AppDatabase db,
    $MangaDownloadTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MangaDownloadTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MangaDownloadTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MangaDownloadTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> mangaAnilistId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> sourceMangaId = const Value.absent(),
                Value<String> sourceChapterId = const Value.absent(),
                Value<double> chapterNumber = const Value.absent(),
                Value<int?> volume = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String?> scanlator = const Value.absent(),
                Value<String?> mangaTitle = const Value.absent(),
                Value<String?> chapterTitle = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> pageCount = const Value.absent(),
                Value<int?> pagesDownloaded = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<int?> downloadedBytes = const Value.absent(),
                Value<String?> cbzPath = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MangaDownloadTableCompanion(
                id: id,
                mangaAnilistId: mangaAnilistId,
                sourceId: sourceId,
                sourceMangaId: sourceMangaId,
                sourceChapterId: sourceChapterId,
                chapterNumber: chapterNumber,
                volume: volume,
                language: language,
                scanlator: scanlator,
                mangaTitle: mangaTitle,
                chapterTitle: chapterTitle,
                status: status,
                pageCount: pageCount,
                pagesDownloaded: pagesDownloaded,
                totalBytes: totalBytes,
                downloadedBytes: downloadedBytes,
                cbzPath: cbzPath,
                errorMessage: errorMessage,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int mangaAnilistId,
                required String sourceId,
                required String sourceMangaId,
                required String sourceChapterId,
                required double chapterNumber,
                Value<int?> volume = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String?> scanlator = const Value.absent(),
                Value<String?> mangaTitle = const Value.absent(),
                Value<String?> chapterTitle = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> pageCount = const Value.absent(),
                Value<int?> pagesDownloaded = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<int?> downloadedBytes = const Value.absent(),
                Value<String?> cbzPath = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                required int createdAt,
                Value<int?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MangaDownloadTableCompanion.insert(
                id: id,
                mangaAnilistId: mangaAnilistId,
                sourceId: sourceId,
                sourceMangaId: sourceMangaId,
                sourceChapterId: sourceChapterId,
                chapterNumber: chapterNumber,
                volume: volume,
                language: language,
                scanlator: scanlator,
                mangaTitle: mangaTitle,
                chapterTitle: chapterTitle,
                status: status,
                pageCount: pageCount,
                pagesDownloaded: pagesDownloaded,
                totalBytes: totalBytes,
                downloadedBytes: downloadedBytes,
                cbzPath: cbzPath,
                errorMessage: errorMessage,
                createdAt: createdAt,
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

typedef $$MangaDownloadTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MangaDownloadTableTable,
      MangaDownloadTableData,
      $$MangaDownloadTableTableFilterComposer,
      $$MangaDownloadTableTableOrderingComposer,
      $$MangaDownloadTableTableAnnotationComposer,
      $$MangaDownloadTableTableCreateCompanionBuilder,
      $$MangaDownloadTableTableUpdateCompanionBuilder,
      (
        MangaDownloadTableData,
        BaseReferences<
          _$AppDatabase,
          $MangaDownloadTableTable,
          MangaDownloadTableData
        >,
      ),
      MangaDownloadTableData,
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
  $$AniSkipCacheTableTableTableManager get aniSkipCacheTable =>
      $$AniSkipCacheTableTableTableManager(_db, _db.aniSkipCacheTable);
  $$DownloadTaskTableTableTableManager get downloadTaskTable =>
      $$DownloadTaskTableTableTableManager(_db, _db.downloadTaskTable);
  $$HlsSegmentTableTableTableManager get hlsSegmentTable =>
      $$HlsSegmentTableTableTableManager(_db, _db.hlsSegmentTable);
  $$LibraryEntryTableTableTableManager get libraryEntryTable =>
      $$LibraryEntryTableTableTableManager(_db, _db.libraryEntryTable);
  $$AnilistCacheTableTableTableManager get anilistCacheTable =>
      $$AnilistCacheTableTableTableManager(_db, _db.anilistCacheTable);
  $$TranslationCacheTableTableTableManager get translationCacheTable =>
      $$TranslationCacheTableTableTableManager(_db, _db.translationCacheTable);
  $$EpisodeCatalogCacheTableTableTableManager get episodeCatalogCacheTable =>
      $$EpisodeCatalogCacheTableTableTableManager(
        _db,
        _db.episodeCatalogCacheTable,
      );
  $$MangaCacheTableTableTableManager get mangaCacheTable =>
      $$MangaCacheTableTableTableManager(_db, _db.mangaCacheTable);
  $$MangaChapterTableTableTableManager get mangaChapterTable =>
      $$MangaChapterTableTableTableManager(_db, _db.mangaChapterTable);
  $$MangaProgressTableTableTableManager get mangaProgressTable =>
      $$MangaProgressTableTableTableManager(_db, _db.mangaProgressTable);
  $$MangaHistoryTableTableTableManager get mangaHistoryTable =>
      $$MangaHistoryTableTableTableManager(_db, _db.mangaHistoryTable);
  $$MangaLibraryTableTableTableManager get mangaLibraryTable =>
      $$MangaLibraryTableTableTableManager(_db, _db.mangaLibraryTable);
  $$ChapterPageCacheTableTableTableManager get chapterPageCacheTable =>
      $$ChapterPageCacheTableTableTableManager(_db, _db.chapterPageCacheTable);
  $$MangaDownloadTableTableTableManager get mangaDownloadTable =>
      $$MangaDownloadTableTableTableManager(_db, _db.mangaDownloadTable);
}
