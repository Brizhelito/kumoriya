import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_doodstream/kumoriya_resolver_doodstream.dart';
import 'package:kumoriya_resolver_jkplayer/kumoriya_resolver_jkplayer.dart';
import 'package:kumoriya_resolver_mp4upload/kumoriya_resolver_mp4upload.dart';
import 'package:kumoriya_resolver_pixeldrain/kumoriya_resolver_pixeldrain.dart';
import 'package:kumoriya_resolver_streamtape/kumoriya_resolver_streamtape.dart';
import 'package:kumoriya_resolver_streamwish/kumoriya_resolver_streamwish.dart';
import 'package:kumoriya_resolver_yourupload/kumoriya_resolver_yourupload.dart';
import 'package:kumoriya_resolver_zilla/kumoriya_resolver_zilla.dart';

void main() {
  test('registry selects streamwish resolver for streamwish host url', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        JkPlayerResolverPlugin(),
        StreamwishResolverPlugin(),
        DoodstreamResolverPlugin(),
      ],
    );

    final selection = registry.selectFor(
      Uri.parse('https://streamwish.to/e/abc123'),
    );

    expect(selection, isA<ResolverSelected>());
    final selected = selection as ResolverSelected;
    expect(selected.resolver.manifest.id, 'kumoriya.resolver.streamwish');
  });

  test('registry selects doodstream resolver for dood.la host url', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        JkPlayerJkResolverPlugin(),
        DoodstreamResolverPlugin(),
        Mp4uploadResolverPlugin(),
      ],
    );

    final selection = registry.selectFor(Uri.parse('https://dood.la/e/xyz123'));

    expect(selection, isA<ResolverSelected>());
    final selected = selection as ResolverSelected;
    expect(selected.resolver.manifest.id, 'kumoriya.resolver.doodstream');
  });

  test('registry selects streamtape resolver for streamtape host', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        JkPlayerJkResolverPlugin(),
        StreamtapeResolverPlugin(),
        StreamwishResolverPlugin(),
      ],
    );

    final selection = registry.selectFor(
      Uri.parse('https://streamtape.com/e/xyz123'),
    );

    expect(selection, isA<ResolverSelected>());
    final selected = selection as ResolverSelected;
    expect(selected.resolver.manifest.id, 'kumoriya.resolver.streamtape');
  });

  test('registry remains deterministic with multiple active resolvers', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        StreamwishResolverPlugin(),
        DoodstreamResolverPlugin(),
        Mp4uploadResolverPlugin(),
        JkPlayerResolverPlugin(),
      ],
    );

    final swSelection = registry.selectFor(
      Uri.parse('https://streamwish.to/e/a1'),
    );
    final jkSelection = registry.selectFor(
      Uri.parse('https://jkanime.net/jkplayer/um?e=abc'),
    );

    expect(swSelection, isA<ResolverSelected>());
    expect(jkSelection, isA<ResolverSelected>());
    expect(
      (swSelection as ResolverSelected).resolver.manifest.id,
      'kumoriya.resolver.streamwish',
    );
    expect(
      (jkSelection as ResolverSelected).resolver.manifest.id,
      'kumoriya.resolver.jkplayer.um',
    );
  });

  test('registry selects doodstream resolver for dsvplay alias host', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        StreamwishResolverPlugin(),
        DoodstreamResolverPlugin(),
        Mp4uploadResolverPlugin(),
      ],
    );

    final selection = registry.selectFor(
      Uri.parse('https://dsvplay.com/e/abcd1234'),
    );

    expect(selection, isA<ResolverSelected>());
    final selected = selection as ResolverSelected;
    expect(selected.resolver.manifest.id, 'kumoriya.resolver.doodstream');
  });

  test('registry selects streamtape resolver for streamtape.com host', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        StreamwishResolverPlugin(),
        StreamtapeResolverPlugin(),
      ],
    );

    final selection = registry.selectFor(
      Uri.parse('https://streamtape.com/e/xyz321'),
    );

    expect(selection, isA<ResolverSelected>());
    final selected = selection as ResolverSelected;
    expect(selected.resolver.manifest.id, 'kumoriya.resolver.streamtape');
  });

  test('registry returns not_found for unknown host', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        StreamwishResolverPlugin(),
        DoodstreamResolverPlugin(),
        Mp4uploadResolverPlugin(),
      ],
    );

    final selection = registry.selectFor(
      Uri.parse('https://unknown-video-host.com/e/xyz321'),
    );

    expect(selection, isA<ResolverNotFound>());
  });

  test('registry selects mp4upload resolver for mp4upload host', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        StreamwishResolverPlugin(),
        Mp4uploadResolverPlugin(),
      ],
    );

    final selection = registry.selectFor(
      Uri.parse('https://www.mp4upload.com/embed-abc123.html'),
    );

    expect(selection, isA<ResolverSelected>());
    final selected = selection as ResolverSelected;
    expect(selected.resolver.manifest.id, 'kumoriya.resolver.mp4upload');
  });

  test('registry selects yourupload resolver for yourupload host', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        StreamwishResolverPlugin(),
        YouruploadResolverPlugin(),
        Mp4uploadResolverPlugin(),
      ],
    );

    final selection = registry.selectFor(
      Uri.parse('https://www.yourupload.com/embed/abc123'),
    );

    expect(selection, isA<ResolverSelected>());
    final selected = selection as ResolverSelected;
    expect(selected.resolver.manifest.id, 'kumoriya.resolver.yourupload');
  });

  test('registry selects pixeldrain resolver for pixeldrain share host', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        StreamwishResolverPlugin(),
        PixeldrainResolverPlugin(),
        Mp4uploadResolverPlugin(),
      ],
    );

    final selection = registry.selectFor(
      Uri.parse('https://pixeldrain.com/u/qi2eVVgY?embed'),
    );

    expect(selection, isA<ResolverSelected>());
    final selected = selection as ResolverSelected;
    expect(selected.resolver.manifest.id, 'kumoriya.resolver.pixeldrain');
  });

  test('registry selects zilla resolver for zilla player host', () {
    final registry = ResolverRegistry(
      resolvers: <ResolverPlugin>[
        StreamwishResolverPlugin(),
        PixeldrainResolverPlugin(),
        ZillaResolverPlugin(),
      ],
    );

    final selection = registry.selectFor(
      Uri.parse(
        'https://player.zilla-networks.com/play/6918779582b6c03ddb61dfd86129d3cd',
      ),
    );

    expect(selection, isA<ResolverSelected>());
    final selected = selection as ResolverSelected;
    expect(selected.resolver.manifest.id, 'kumoriya.resolver.zilla');
  });
}
