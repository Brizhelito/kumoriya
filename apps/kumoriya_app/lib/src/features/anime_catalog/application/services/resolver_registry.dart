import 'package:kumoriya_plugins/kumoriya_plugins.dart';

sealed class ResolverSelection {
  const ResolverSelection();
}

final class ResolverSelected extends ResolverSelection {
  const ResolverSelected({required this.resolver});

  final ResolverPlugin resolver;
}

final class ResolverNotFound extends ResolverSelection {
  const ResolverNotFound();
}

final class ResolverAmbiguous extends ResolverSelection {
  const ResolverAmbiguous({required this.resolvers});

  final List<ResolverPlugin> resolvers;
}

final class ResolverRegistry {
  ResolverRegistry({required List<ResolverPlugin> resolvers})
    : _resolvers = resolvers;

  final List<ResolverPlugin> _resolvers;
  final _hostCache = <String, ResolverSelection>{};

  ResolverSelection selectFor(Uri url) {
    final host = url.host;
    final cached = _hostCache[host];
    if (cached != null) return cached;

    final candidates = _resolvers
        .where((resolver) => resolver.supports(url))
        .toList(growable: false);

    if (candidates.isEmpty) {
      _hostCache[host] = const ResolverNotFound();
      return const ResolverNotFound();
    }

    final sorted = [...candidates]
      ..sort((a, b) {
        final priorityCompare = b.priority.compareTo(a.priority);
        if (priorityCompare != 0) {
          return priorityCompare;
        }
        return a.manifest.id.compareTo(b.manifest.id);
      });

    ResolverSelection result;
    if (sorted.length > 1 && sorted.first.priority == sorted[1].priority) {
      result = ResolverAmbiguous(resolvers: sorted);
    } else {
      result = ResolverSelected(resolver: sorted.first);
    }
    _hostCache[host] = result;
    return result;
  }
}
