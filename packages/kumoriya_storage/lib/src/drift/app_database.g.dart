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
          ..write('updatedAt: $updatedAt')
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
          other.updatedAt == this.updatedAt);
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
  @override
  List<GeneratedColumn> get $columns => [
    anilistId,
    addedAt,
    notifyNewEpisodes,
    lastNotifiedEpisode,
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
  const LibraryEntryTableData({
    required this.anilistId,
    required this.addedAt,
    required this.notifyNewEpisodes,
    this.lastNotifiedEpisode,
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
    };
  }

  LibraryEntryTableData copyWith({
    int? anilistId,
    int? addedAt,
    bool? notifyNewEpisodes,
    Value<int?> lastNotifiedEpisode = const Value.absent(),
  }) => LibraryEntryTableData(
    anilistId: anilistId ?? this.anilistId,
    addedAt: addedAt ?? this.addedAt,
    notifyNewEpisodes: notifyNewEpisodes ?? this.notifyNewEpisodes,
    lastNotifiedEpisode: lastNotifiedEpisode.present
        ? lastNotifiedEpisode.value
        : this.lastNotifiedEpisode,
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
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryEntryTableData(')
          ..write('anilistId: $anilistId, ')
          ..write('addedAt: $addedAt, ')
          ..write('notifyNewEpisodes: $notifyNewEpisodes, ')
          ..write('lastNotifiedEpisode: $lastNotifiedEpisode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(anilistId, addedAt, notifyNewEpisodes, lastNotifiedEpisode);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryEntryTableData &&
          other.anilistId == this.anilistId &&
          other.addedAt == this.addedAt &&
          other.notifyNewEpisodes == this.notifyNewEpisodes &&
          other.lastNotifiedEpisode == this.lastNotifiedEpisode);
}

class LibraryEntryTableCompanion
    extends UpdateCompanion<LibraryEntryTableData> {
  final Value<int> anilistId;
  final Value<int> addedAt;
  final Value<bool> notifyNewEpisodes;
  final Value<int?> lastNotifiedEpisode;
  const LibraryEntryTableCompanion({
    this.anilistId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.notifyNewEpisodes = const Value.absent(),
    this.lastNotifiedEpisode = const Value.absent(),
  });
  LibraryEntryTableCompanion.insert({
    this.anilistId = const Value.absent(),
    required int addedAt,
    this.notifyNewEpisodes = const Value.absent(),
    this.lastNotifiedEpisode = const Value.absent(),
  }) : addedAt = Value(addedAt);
  static Insertable<LibraryEntryTableData> custom({
    Expression<int>? anilistId,
    Expression<int>? addedAt,
    Expression<bool>? notifyNewEpisodes,
    Expression<int>? lastNotifiedEpisode,
  }) {
    return RawValuesInsertable({
      if (anilistId != null) 'anilist_id': anilistId,
      if (addedAt != null) 'added_at': addedAt,
      if (notifyNewEpisodes != null) 'notify_new_episodes': notifyNewEpisodes,
      if (lastNotifiedEpisode != null)
        'last_notified_episode': lastNotifiedEpisode,
    });
  }

  LibraryEntryTableCompanion copyWith({
    Value<int>? anilistId,
    Value<int>? addedAt,
    Value<bool>? notifyNewEpisodes,
    Value<int?>? lastNotifiedEpisode,
  }) {
    return LibraryEntryTableCompanion(
      anilistId: anilistId ?? this.anilistId,
      addedAt: addedAt ?? this.addedAt,
      notifyNewEpisodes: notifyNewEpisodes ?? this.notifyNewEpisodes,
      lastNotifiedEpisode: lastNotifiedEpisode ?? this.lastNotifiedEpisode,
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryEntryTableCompanion(')
          ..write('anilistId: $anilistId, ')
          ..write('addedAt: $addedAt, ')
          ..write('notifyNewEpisodes: $notifyNewEpisodes, ')
          ..write('lastNotifiedEpisode: $lastNotifiedEpisode')
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
    coverImageUrl,
    bannerImageUrl,
    status,
    averageScore,
    genres,
    synopsis,
    format,
    releaseYear,
    totalEpisodes,
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
    if (data.containsKey('average_score')) {
      context.handle(
        _averageScoreMeta,
        averageScore.isAcceptableOrUnknown(
          data['average_score']!,
          _averageScoreMeta,
        ),
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
      averageScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}average_score'],
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
  final String? coverImageUrl;
  final String? bannerImageUrl;
  final String? status;
  final int? averageScore;
  final String? genres;
  final String? synopsis;
  final String? format;
  final int? releaseYear;
  final int? totalEpisodes;
  final int updatedAt;
  const AnilistCacheTableData({
    required this.anilistId,
    required this.titleRomaji,
    this.titleEnglish,
    this.titleNative,
    this.coverImageUrl,
    this.bannerImageUrl,
    this.status,
    this.averageScore,
    this.genres,
    this.synopsis,
    this.format,
    this.releaseYear,
    this.totalEpisodes,
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
    if (!nullToAbsent || coverImageUrl != null) {
      map['cover_image_url'] = Variable<String>(coverImageUrl);
    }
    if (!nullToAbsent || bannerImageUrl != null) {
      map['banner_image_url'] = Variable<String>(bannerImageUrl);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || averageScore != null) {
      map['average_score'] = Variable<int>(averageScore);
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
      coverImageUrl: coverImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverImageUrl),
      bannerImageUrl: bannerImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(bannerImageUrl),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      averageScore: averageScore == null && nullToAbsent
          ? const Value.absent()
          : Value(averageScore),
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
      coverImageUrl: serializer.fromJson<String?>(json['coverImageUrl']),
      bannerImageUrl: serializer.fromJson<String?>(json['bannerImageUrl']),
      status: serializer.fromJson<String?>(json['status']),
      averageScore: serializer.fromJson<int?>(json['averageScore']),
      genres: serializer.fromJson<String?>(json['genres']),
      synopsis: serializer.fromJson<String?>(json['synopsis']),
      format: serializer.fromJson<String?>(json['format']),
      releaseYear: serializer.fromJson<int?>(json['releaseYear']),
      totalEpisodes: serializer.fromJson<int?>(json['totalEpisodes']),
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
      'coverImageUrl': serializer.toJson<String?>(coverImageUrl),
      'bannerImageUrl': serializer.toJson<String?>(bannerImageUrl),
      'status': serializer.toJson<String?>(status),
      'averageScore': serializer.toJson<int?>(averageScore),
      'genres': serializer.toJson<String?>(genres),
      'synopsis': serializer.toJson<String?>(synopsis),
      'format': serializer.toJson<String?>(format),
      'releaseYear': serializer.toJson<int?>(releaseYear),
      'totalEpisodes': serializer.toJson<int?>(totalEpisodes),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  AnilistCacheTableData copyWith({
    int? anilistId,
    String? titleRomaji,
    Value<String?> titleEnglish = const Value.absent(),
    Value<String?> titleNative = const Value.absent(),
    Value<String?> coverImageUrl = const Value.absent(),
    Value<String?> bannerImageUrl = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<int?> averageScore = const Value.absent(),
    Value<String?> genres = const Value.absent(),
    Value<String?> synopsis = const Value.absent(),
    Value<String?> format = const Value.absent(),
    Value<int?> releaseYear = const Value.absent(),
    Value<int?> totalEpisodes = const Value.absent(),
    int? updatedAt,
  }) => AnilistCacheTableData(
    anilistId: anilistId ?? this.anilistId,
    titleRomaji: titleRomaji ?? this.titleRomaji,
    titleEnglish: titleEnglish.present ? titleEnglish.value : this.titleEnglish,
    titleNative: titleNative.present ? titleNative.value : this.titleNative,
    coverImageUrl: coverImageUrl.present
        ? coverImageUrl.value
        : this.coverImageUrl,
    bannerImageUrl: bannerImageUrl.present
        ? bannerImageUrl.value
        : this.bannerImageUrl,
    status: status.present ? status.value : this.status,
    averageScore: averageScore.present ? averageScore.value : this.averageScore,
    genres: genres.present ? genres.value : this.genres,
    synopsis: synopsis.present ? synopsis.value : this.synopsis,
    format: format.present ? format.value : this.format,
    releaseYear: releaseYear.present ? releaseYear.value : this.releaseYear,
    totalEpisodes: totalEpisodes.present
        ? totalEpisodes.value
        : this.totalEpisodes,
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
      coverImageUrl: data.coverImageUrl.present
          ? data.coverImageUrl.value
          : this.coverImageUrl,
      bannerImageUrl: data.bannerImageUrl.present
          ? data.bannerImageUrl.value
          : this.bannerImageUrl,
      status: data.status.present ? data.status.value : this.status,
      averageScore: data.averageScore.present
          ? data.averageScore.value
          : this.averageScore,
      genres: data.genres.present ? data.genres.value : this.genres,
      synopsis: data.synopsis.present ? data.synopsis.value : this.synopsis,
      format: data.format.present ? data.format.value : this.format,
      releaseYear: data.releaseYear.present
          ? data.releaseYear.value
          : this.releaseYear,
      totalEpisodes: data.totalEpisodes.present
          ? data.totalEpisodes.value
          : this.totalEpisodes,
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
          ..write('coverImageUrl: $coverImageUrl, ')
          ..write('bannerImageUrl: $bannerImageUrl, ')
          ..write('status: $status, ')
          ..write('averageScore: $averageScore, ')
          ..write('genres: $genres, ')
          ..write('synopsis: $synopsis, ')
          ..write('format: $format, ')
          ..write('releaseYear: $releaseYear, ')
          ..write('totalEpisodes: $totalEpisodes, ')
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
    coverImageUrl,
    bannerImageUrl,
    status,
    averageScore,
    genres,
    synopsis,
    format,
    releaseYear,
    totalEpisodes,
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
          other.coverImageUrl == this.coverImageUrl &&
          other.bannerImageUrl == this.bannerImageUrl &&
          other.status == this.status &&
          other.averageScore == this.averageScore &&
          other.genres == this.genres &&
          other.synopsis == this.synopsis &&
          other.format == this.format &&
          other.releaseYear == this.releaseYear &&
          other.totalEpisodes == this.totalEpisodes &&
          other.updatedAt == this.updatedAt);
}

class AnilistCacheTableCompanion
    extends UpdateCompanion<AnilistCacheTableData> {
  final Value<int> anilistId;
  final Value<String> titleRomaji;
  final Value<String?> titleEnglish;
  final Value<String?> titleNative;
  final Value<String?> coverImageUrl;
  final Value<String?> bannerImageUrl;
  final Value<String?> status;
  final Value<int?> averageScore;
  final Value<String?> genres;
  final Value<String?> synopsis;
  final Value<String?> format;
  final Value<int?> releaseYear;
  final Value<int?> totalEpisodes;
  final Value<int> updatedAt;
  const AnilistCacheTableCompanion({
    this.anilistId = const Value.absent(),
    this.titleRomaji = const Value.absent(),
    this.titleEnglish = const Value.absent(),
    this.titleNative = const Value.absent(),
    this.coverImageUrl = const Value.absent(),
    this.bannerImageUrl = const Value.absent(),
    this.status = const Value.absent(),
    this.averageScore = const Value.absent(),
    this.genres = const Value.absent(),
    this.synopsis = const Value.absent(),
    this.format = const Value.absent(),
    this.releaseYear = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AnilistCacheTableCompanion.insert({
    this.anilistId = const Value.absent(),
    required String titleRomaji,
    this.titleEnglish = const Value.absent(),
    this.titleNative = const Value.absent(),
    this.coverImageUrl = const Value.absent(),
    this.bannerImageUrl = const Value.absent(),
    this.status = const Value.absent(),
    this.averageScore = const Value.absent(),
    this.genres = const Value.absent(),
    this.synopsis = const Value.absent(),
    this.format = const Value.absent(),
    this.releaseYear = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    required int updatedAt,
  }) : titleRomaji = Value(titleRomaji),
       updatedAt = Value(updatedAt);
  static Insertable<AnilistCacheTableData> custom({
    Expression<int>? anilistId,
    Expression<String>? titleRomaji,
    Expression<String>? titleEnglish,
    Expression<String>? titleNative,
    Expression<String>? coverImageUrl,
    Expression<String>? bannerImageUrl,
    Expression<String>? status,
    Expression<int>? averageScore,
    Expression<String>? genres,
    Expression<String>? synopsis,
    Expression<String>? format,
    Expression<int>? releaseYear,
    Expression<int>? totalEpisodes,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (anilistId != null) 'anilist_id': anilistId,
      if (titleRomaji != null) 'title_romaji': titleRomaji,
      if (titleEnglish != null) 'title_english': titleEnglish,
      if (titleNative != null) 'title_native': titleNative,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      if (bannerImageUrl != null) 'banner_image_url': bannerImageUrl,
      if (status != null) 'status': status,
      if (averageScore != null) 'average_score': averageScore,
      if (genres != null) 'genres': genres,
      if (synopsis != null) 'synopsis': synopsis,
      if (format != null) 'format': format,
      if (releaseYear != null) 'release_year': releaseYear,
      if (totalEpisodes != null) 'total_episodes': totalEpisodes,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AnilistCacheTableCompanion copyWith({
    Value<int>? anilistId,
    Value<String>? titleRomaji,
    Value<String?>? titleEnglish,
    Value<String?>? titleNative,
    Value<String?>? coverImageUrl,
    Value<String?>? bannerImageUrl,
    Value<String?>? status,
    Value<int?>? averageScore,
    Value<String?>? genres,
    Value<String?>? synopsis,
    Value<String?>? format,
    Value<int?>? releaseYear,
    Value<int?>? totalEpisodes,
    Value<int>? updatedAt,
  }) {
    return AnilistCacheTableCompanion(
      anilistId: anilistId ?? this.anilistId,
      titleRomaji: titleRomaji ?? this.titleRomaji,
      titleEnglish: titleEnglish ?? this.titleEnglish,
      titleNative: titleNative ?? this.titleNative,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      status: status ?? this.status,
      averageScore: averageScore ?? this.averageScore,
      genres: genres ?? this.genres,
      synopsis: synopsis ?? this.synopsis,
      format: format ?? this.format,
      releaseYear: releaseYear ?? this.releaseYear,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
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
    if (coverImageUrl.present) {
      map['cover_image_url'] = Variable<String>(coverImageUrl.value);
    }
    if (bannerImageUrl.present) {
      map['banner_image_url'] = Variable<String>(bannerImageUrl.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (averageScore.present) {
      map['average_score'] = Variable<int>(averageScore.value);
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
          ..write('coverImageUrl: $coverImageUrl, ')
          ..write('bannerImageUrl: $bannerImageUrl, ')
          ..write('status: $status, ')
          ..write('averageScore: $averageScore, ')
          ..write('genres: $genres, ')
          ..write('synopsis: $synopsis, ')
          ..write('format: $format, ')
          ..write('releaseYear: $releaseYear, ')
          ..write('totalEpisodes: $totalEpisodes, ')
          ..write('updatedAt: $updatedAt')
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
  late final $DownloadTaskTableTable downloadTaskTable =
      $DownloadTaskTableTable(this);
  late final $LibraryEntryTableTable libraryEntryTable =
      $LibraryEntryTableTable(this);
  late final $AnilistCacheTableTable anilistCacheTable =
      $AnilistCacheTableTable(this);
  late final ProgressDao progressDao = ProgressDao(this as AppDatabase);
  late final WatchHistoryDao watchHistoryDao = WatchHistoryDao(
    this as AppDatabase,
  );
  late final PlaybackPreferenceDao playbackPreferenceDao =
      PlaybackPreferenceDao(this as AppDatabase);
  late final SourceAvailabilityCacheDao sourceAvailabilityCacheDao =
      SourceAvailabilityCacheDao(this as AppDatabase);
  late final DownloadTaskDao downloadTaskDao = DownloadTaskDao(
    this as AppDatabase,
  );
  late final LibraryEntryDao libraryEntryDao = LibraryEntryDao(
    this as AppDatabase,
  );
  late final AnilistCacheDao anilistCacheDao = AnilistCacheDao(
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
    downloadTaskTable,
    libraryEntryTable,
    anilistCacheTable,
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
typedef $$LibraryEntryTableTableCreateCompanionBuilder =
    LibraryEntryTableCompanion Function({
      Value<int> anilistId,
      required int addedAt,
      Value<bool> notifyNewEpisodes,
      Value<int?> lastNotifiedEpisode,
    });
typedef $$LibraryEntryTableTableUpdateCompanionBuilder =
    LibraryEntryTableCompanion Function({
      Value<int> anilistId,
      Value<int> addedAt,
      Value<bool> notifyNewEpisodes,
      Value<int?> lastNotifiedEpisode,
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
              }) => LibraryEntryTableCompanion(
                anilistId: anilistId,
                addedAt: addedAt,
                notifyNewEpisodes: notifyNewEpisodes,
                lastNotifiedEpisode: lastNotifiedEpisode,
              ),
          createCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                required int addedAt,
                Value<bool> notifyNewEpisodes = const Value.absent(),
                Value<int?> lastNotifiedEpisode = const Value.absent(),
              }) => LibraryEntryTableCompanion.insert(
                anilistId: anilistId,
                addedAt: addedAt,
                notifyNewEpisodes: notifyNewEpisodes,
                lastNotifiedEpisode: lastNotifiedEpisode,
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
      Value<String?> coverImageUrl,
      Value<String?> bannerImageUrl,
      Value<String?> status,
      Value<int?> averageScore,
      Value<String?> genres,
      Value<String?> synopsis,
      Value<String?> format,
      Value<int?> releaseYear,
      Value<int?> totalEpisodes,
      required int updatedAt,
    });
typedef $$AnilistCacheTableTableUpdateCompanionBuilder =
    AnilistCacheTableCompanion Function({
      Value<int> anilistId,
      Value<String> titleRomaji,
      Value<String?> titleEnglish,
      Value<String?> titleNative,
      Value<String?> coverImageUrl,
      Value<String?> bannerImageUrl,
      Value<String?> status,
      Value<int?> averageScore,
      Value<String?> genres,
      Value<String?> synopsis,
      Value<String?> format,
      Value<int?> releaseYear,
      Value<int?> totalEpisodes,
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

  ColumnFilters<int> get averageScore => $composableBuilder(
    column: $table.averageScore,
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

  ColumnOrderings<int> get averageScore => $composableBuilder(
    column: $table.averageScore,
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

  GeneratedColumn<int> get averageScore => $composableBuilder(
    column: $table.averageScore,
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
                Value<String?> coverImageUrl = const Value.absent(),
                Value<String?> bannerImageUrl = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<int?> averageScore = const Value.absent(),
                Value<String?> genres = const Value.absent(),
                Value<String?> synopsis = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<int?> releaseYear = const Value.absent(),
                Value<int?> totalEpisodes = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => AnilistCacheTableCompanion(
                anilistId: anilistId,
                titleRomaji: titleRomaji,
                titleEnglish: titleEnglish,
                titleNative: titleNative,
                coverImageUrl: coverImageUrl,
                bannerImageUrl: bannerImageUrl,
                status: status,
                averageScore: averageScore,
                genres: genres,
                synopsis: synopsis,
                format: format,
                releaseYear: releaseYear,
                totalEpisodes: totalEpisodes,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                required String titleRomaji,
                Value<String?> titleEnglish = const Value.absent(),
                Value<String?> titleNative = const Value.absent(),
                Value<String?> coverImageUrl = const Value.absent(),
                Value<String?> bannerImageUrl = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<int?> averageScore = const Value.absent(),
                Value<String?> genres = const Value.absent(),
                Value<String?> synopsis = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<int?> releaseYear = const Value.absent(),
                Value<int?> totalEpisodes = const Value.absent(),
                required int updatedAt,
              }) => AnilistCacheTableCompanion.insert(
                anilistId: anilistId,
                titleRomaji: titleRomaji,
                titleEnglish: titleEnglish,
                titleNative: titleNative,
                coverImageUrl: coverImageUrl,
                bannerImageUrl: bannerImageUrl,
                status: status,
                averageScore: averageScore,
                genres: genres,
                synopsis: synopsis,
                format: format,
                releaseYear: releaseYear,
                totalEpisodes: totalEpisodes,
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
  $$DownloadTaskTableTableTableManager get downloadTaskTable =>
      $$DownloadTaskTableTableTableManager(_db, _db.downloadTaskTable);
  $$LibraryEntryTableTableTableManager get libraryEntryTable =>
      $$LibraryEntryTableTableTableManager(_db, _db.libraryEntryTable);
  $$AnilistCacheTableTableTableManager get anilistCacheTable =>
      $$AnilistCacheTableTableTableManager(_db, _db.anilistCacheTable);
}
