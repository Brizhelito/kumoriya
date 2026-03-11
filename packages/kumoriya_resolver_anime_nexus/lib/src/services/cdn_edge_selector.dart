import 'dart:async';

import 'package:dio/dio.dart';

import '../utils/nexus_constants.dart';

final class NexusCdnEdgeSelector {
  NexusCdnEdgeSelector(this._dio);

  final Dio _dio;

  static List<String>? _cachedHosts;
  static DateTime? _cachedAt;

  Future<List<String>> candidateHosts({required String fallbackHost}) async {
    final now = DateTime.now();
    final cachedHosts = _cachedHosts;
    final cachedAt = _cachedAt;
    if (cachedHosts != null &&
        cachedAt != null &&
        now.difference(cachedAt) < const Duration(minutes: 10)) {
      return _mergeHosts(fallbackHost: fallbackHost, hosts: cachedHosts);
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${NexusConstants.cdnBase}/api/edges',
        options: Options(
          headers: <String, String>{
            'Accept': 'application/json, text/plain, */*',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final payload = response.data;
      final currentRegion = payload?['current_region']?.toString().trim();
      final rawEdges = payload?['edges'];
      if (rawEdges is! List<dynamic> || rawEdges.isEmpty) {
        return <String>[fallbackHost];
      }

      final edges = rawEdges
          .whereType<Map<String, dynamic>>()
          .map(_NexusEdge.fromMap)
          .where((edge) => edge.host.isNotEmpty)
          .toList(growable: false);
      if (edges.isEmpty) {
        return <String>[fallbackHost];
      }

      final regionHost = currentRegion == null
          ? null
          : edges
                .where((edge) => edge.id == currentRegion)
                .map((edge) => edge.host)
                .cast<String?>()
                .firstWhere((host) => host != null, orElse: () => null);
      final orderedHosts = <String>[
        if (regionHost != null && regionHost.isNotEmpty) regionHost,
        ...edges.map((edge) => edge.host),
      ];
      final mergedHosts = _mergeHosts(
        fallbackHost: fallbackHost,
        hosts: orderedHosts,
      );
      _cachedHosts = mergedHosts;
      _cachedAt = now;
      return mergedHosts;
    } catch (_) {
      return <String>[fallbackHost];
    }
  }

  List<String> _mergeHosts({
    required String fallbackHost,
    required List<String> hosts,
  }) {
    final ordered = <String>[];
    final seen = <String>{};

    void add(String host) {
      final trimmed = host.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        return;
      }
      ordered.add(trimmed);
    }

    add(fallbackHost);
    for (final host in hosts) {
      add(host);
    }
    return ordered;
  }
}

final class _NexusEdge {
  const _NexusEdge({required this.id, required this.host});

  final String id;
  final String host;

  factory _NexusEdge.fromMap(Map<String, dynamic> map) {
    return _NexusEdge(
      id: map['id']?.toString().trim() ?? '',
      host: map['host']?.toString().trim() ?? '',
    );
  }
}
