import 'dart:async';
import 'dart:isolate';

import '../models/nexus_ws_models.dart';
import 'ws_client.dart';

final class NexusPlaybackSessionWorkerException implements Exception {
  const NexusPlaybackSessionWorkerException(this.message);

  final String message;

  @override
  String toString() => 'NexusPlaybackSessionWorkerException: $message';
}

final class NexusPlaybackSessionWorker {
  NexusPlaybackSessionWorker._({
    required Isolate isolate,
    required SendPort commandPort,
    required ReceivePort eventPort,
  }) : _isolate = isolate,
       _commandPort = commandPort,
       _eventPort = eventPort {
    _subscription = _eventPort.listen(_handleMessage);
  }

  final Isolate _isolate;
  final SendPort _commandPort;
  final ReceivePort _eventPort;
  final Map<int, Completer<Map<String, dynamic>>> _pending =
      <int, Completer<Map<String, dynamic>>>{};

  late final StreamSubscription<dynamic> _subscription;
  int _requestId = 0;
  bool _closed = false;

  static Future<NexusPlaybackSessionWorker> spawn({
    required String episodeId,
    required String fingerprint,
    required String? cookieHeader,
    required String m3u8Url,
    required String wsRef,
  }) async {
    final readyPort = ReceivePort();
    final eventPort = ReceivePort();

    final isolate = await Isolate.spawn(_workerMain, <String, Object?>{
      'readyPort': readyPort.sendPort,
      'eventPort': eventPort.sendPort,
      'episodeId': episodeId,
      'fingerprint': fingerprint,
      'cookieHeader': cookieHeader,
      'm3u8Url': m3u8Url,
      'wsRef': wsRef,
    });

    final readyMessage = await readyPort.first.timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw const NexusPlaybackSessionWorkerException(
        'Anime Nexus worker startup timed out.',
      ),
    );
    readyPort.close();

    final ready = Map<String, dynamic>.from(readyMessage as Map);
    if (ready['ok'] != true) {
      isolate.kill(priority: Isolate.immediate);
      throw NexusPlaybackSessionWorkerException(
        ready['error']?.toString().trim() ??
            'Anime Nexus worker failed to start.',
      );
    }

    final commandPort = ready['commandPort'];
    if (commandPort is! SendPort) {
      isolate.kill(priority: Isolate.immediate);
      eventPort.close();
      throw const NexusPlaybackSessionWorkerException(
        'Anime Nexus worker did not provide a command port.',
      );
    }

    return NexusPlaybackSessionWorker._(
      isolate: isolate,
      commandPort: commandPort,
      eventPort: eventPort,
    );
  }

  Future<void> ensureReady({bool forceReconnect = false}) async {
    await _request('ensureReady', <String, Object?>{
      'forceReconnect': forceReconnect,
    });
  }

  Future<void> refreshSession({bool requestResetStream = false}) async {
    await _request('refreshSession', <String, Object?>{
      'requestResetStream': requestResetStream,
    });
  }

  Future<String> getSessionId() async {
    final payload = await _request('getSessionId');
    final sessionId = payload['sessionId']?.toString().trim() ?? '';
    if (sessionId.isEmpty) {
      throw const NexusPlaybackSessionWorkerException(
        'Anime Nexus worker returned an empty session id.',
      );
    }
    return sessionId;
  }

  Future<NexusStreamToken> getInitialManifestToken() async {
    final payload = await _request('getInitialManifestToken');
    return NexusStreamToken.fromMap(payload);
  }

  Future<NexusStreamToken> getManifestToken({
    required String manifestPath,
    required String videoId,
  }) async {
    final payload = await _request('getManifestToken', <String, Object?>{
      'manifestPath': manifestPath,
      'videoId': videoId,
    });
    return NexusStreamToken.fromMap(payload);
  }

  Future<NexusStreamToken> getSegmentToken({
    required String variant,
    required int segmentIndex,
    required int track,
    required String videoId,
  }) async {
    final payload = await _request('getSegmentToken', <String, Object?>{
      'variant': variant,
      'segmentIndex': segmentIndex,
      'track': track,
      'videoId': videoId,
    });
    return NexusStreamToken.fromMap(payload);
  }

  Future<void> sendProgress({required int segmentIndex}) async {
    await _request('sendProgress', <String, Object?>{
      'segmentIndex': segmentIndex,
    });
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }

    try {
      await _request('close');
    } catch (_) {
      // The worker may already be shutting down.
    } finally {
      _closed = true;
      for (final completer in _pending.values) {
        if (!completer.isCompleted) {
          completer.completeError(
            const NexusPlaybackSessionWorkerException(
              'Anime Nexus worker was closed.',
            ),
          );
        }
      }
      _pending.clear();
      await _subscription.cancel();
      _eventPort.close();
      _isolate.kill(priority: Isolate.immediate);
    }
  }

  Future<Map<String, dynamic>> _request(
    String type, [
    Map<String, Object?> payload = const <String, Object?>{},
  ]) async {
    if (_closed) {
      throw const NexusPlaybackSessionWorkerException(
        'Anime Nexus worker is already closed.',
      );
    }

    final id = _requestId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    _commandPort.send(<String, Object?>{'id': id, 'type': type, ...payload});

    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        _pending.remove(id);
        throw NexusPlaybackSessionWorkerException(
          'Anime Nexus worker command timed out: $type',
        );
      },
    );
  }

  void _handleMessage(dynamic raw) {
    if (raw is! Map) {
      return;
    }

    final message = Map<String, dynamic>.from(raw);
    final id = message['id'];
    if (id is! int) {
      return;
    }

    final completer = _pending.remove(id);
    if (completer == null) {
      return;
    }

    if (message['ok'] == true) {
      final data = message['data'];
      if (data is Map) {
        completer.complete(Map<String, dynamic>.from(data));
      } else {
        completer.complete(const <String, dynamic>{});
      }
      return;
    }

    completer.completeError(
      NexusPlaybackSessionWorkerException(
        message['error']?.toString().trim() ??
            'Anime Nexus worker command failed.',
      ),
    );
  }
}

Future<void> _workerMain(Map<String, Object?> args) async {
  final readyPort = args['readyPort'] as SendPort;
  final eventPort = args['eventPort'] as SendPort;
  final commandPort = ReceivePort();

  final runtime = _NexusPlaybackSessionWorkerRuntime(
    eventPort: eventPort,
    episodeId: args['episodeId']! as String,
    fingerprint: args['fingerprint']! as String,
    cookieHeader: args['cookieHeader'] as String?,
    m3u8Url: args['m3u8Url']! as String,
    wsRef: args['wsRef']! as String,
  );

  try {
    await runtime.initialize();
    readyPort.send(<String, Object?>{
      'ok': true,
      'commandPort': commandPort.sendPort,
    });
  } catch (error) {
    readyPort.send(<String, Object?>{'ok': false, 'error': error.toString()});
    commandPort.close();
    return;
  }

  await runtime.run(commandPort);
}

final class _NexusPlaybackSessionWorkerRuntime {
  _NexusPlaybackSessionWorkerRuntime({
    required SendPort eventPort,
    required String episodeId,
    required String fingerprint,
    required String? cookieHeader,
    required String m3u8Url,
    required String wsRef,
  }) : _eventPort = eventPort,
       _wsRef = wsRef,
       _client = NexusWsClient(
         episodeId: episodeId,
         fingerprint: fingerprint,
         cookieHeader: cookieHeader,
         m3u8Url: m3u8Url,
       );

  final SendPort _eventPort;
  final String _wsRef;
  final NexusWsClient _client;

  bool _closed = false;

  Future<void> initialize() async {
    await _client.connect(wsRef: _wsRef);
    await _client.getInitialManifestToken();
  }

  Future<void> run(ReceivePort commandPort) async {
    try {
      await for (final dynamic raw in commandPort) {
        if (raw is! Map) {
          continue;
        }

        final command = Map<String, dynamic>.from(raw);
        final id = command['id'];
        if (id is! int) {
          continue;
        }

        final type = command['type']?.toString() ?? '';
        try {
          final data = await _handleCommand(type, command);
          _eventPort.send(<String, Object?>{
            'id': id,
            'ok': true,
            'data': data,
          });
          if (type == 'close') {
            break;
          }
        } catch (error) {
          _eventPort.send(<String, Object?>{
            'id': id,
            'ok': false,
            'error': error.toString(),
          });
        }
      }
    } finally {
      commandPort.close();
      if (!_closed) {
        await _client.close();
        _closed = true;
      }
      Isolate.exit();
    }
  }

  Future<Map<String, Object?>> _handleCommand(
    String type,
    Map<String, dynamic> command,
  ) async {
    switch (type) {
      case 'ensureReady':
        await _client.ensureActiveSession(
          forceReconnect: command['forceReconnect'] == true,
        );
        return _client.session.toMap();
      case 'refreshSession':
        await _client.refreshSession(
          requestResetStream: command['requestResetStream'] == true,
        );
        return _client.session.toMap();
      case 'getSessionId':
        await _client.ensureActiveSession();
        return <String, Object?>{'sessionId': _client.session.sessionId};
      case 'getInitialManifestToken':
        final token = await _client.getInitialManifestToken();
        return token.toMap();
      case 'getManifestToken':
        final token = await _client.getManifestToken(
          manifestPath: command['manifestPath']! as String,
          videoId: command['videoId']! as String,
        );
        return token.toMap();
      case 'getSegmentToken':
        final token = await _client.getSegmentToken(
          variant: command['variant']! as String,
          segmentIndex: command['segmentIndex']! as int,
          track: command['track']! as int,
          videoId: command['videoId']! as String,
        );
        return token.toMap();
      case 'sendProgress':
        await _client.sendProgress(
          segmentIndex: command['segmentIndex']! as int,
        );
        return const <String, Object?>{};
      case 'close':
        if (!_closed) {
          await _client.close();
          _closed = true;
        }
        return const <String, Object?>{};
      default:
        throw NexusPlaybackSessionWorkerException(
          'Anime Nexus worker received unknown command: $type',
        );
    }
  }
}
