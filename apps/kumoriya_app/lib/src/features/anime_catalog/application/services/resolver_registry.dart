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

  ResolverPlugin? resolverById(String resolverId) {
    for (final resolver in _resolvers) {
      if (resolver.manifest.id == resolverId) {
        return resolver;
      }
    }
    return null;
  }

  ResolverSelection selectFor(Uri url) {
    final host = url.host;
    final cached = _hostCache[host];
    if (cached != null) return cached;

    final candidates = _resolvers
        .where((resolver) => resolver.supports(url))
        .toList(growable: false);

    if (candidates.isEmpty) {
      // Deliberately do NOT cache `ResolverNotFound`. Two reasons:
      //
      // 1. Cache key is the host, but `resolver.supports(url)` also filters
      //    on the URL path; a host that has a resolver for `/e/…` but not
      //    for `/weird/…` would otherwise get stuck as `NotFound` for
      //    every future lookup of that host.
      //
      // 2. When a resolver grows support for a previously-unknown host
      //    (e.g. a new StreamWish mirror), we want the next call to pick
      //    it up without forcing the user to restart the app.
      //
      // The recomputation cost is O(resolvers) of a simple `supports`
      // check — negligible compared to a resolver round-trip.
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
