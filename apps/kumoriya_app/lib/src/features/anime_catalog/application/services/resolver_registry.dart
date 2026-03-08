import 'package:kumoriya_plugins/kumoriya_plugins.dart';

final class ResolverRegistry {
  const ResolverRegistry({required List<ResolverPlugin> resolvers})
    : _resolvers = resolvers;

  final List<ResolverPlugin> _resolvers;

  ResolverPlugin? findFor(Uri url) {
    for (final resolver in _resolvers) {
      if (resolver.supports(url)) {
        return resolver;
      }
    }
    return null;
  }
}
