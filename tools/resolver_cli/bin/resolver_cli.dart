import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'package:resolver_cli/resolver_catalog.dart';

// ──────────────────────────────────────────────────────────────────────────────
// ANSI colors
// ──────────────────────────────────────────────────────────────────────────────
const _green = '\x1B[32m';
const _red = '\x1B[31m';
const _yellow = '\x1B[33m';
const _cyan = '\x1B[36m';
const _bold = '\x1B[1m';
const _dim = '\x1B[2m';
const _reset = '\x1B[0m';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('list')
    ..addCommand('test')
    ..addCommand('benchmark')
    ..addCommand('validate')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage');

  final testParser = ArgParser()
    ..addOption('url', abbr: 'u', help: 'URL to resolve')
    ..addOption('resolver', abbr: 'r', help: 'Resolver name (optional)')
    ..addOption(
      'iterations',
      abbr: 'n',
      defaultsTo: '1',
      help: 'Number of iterations',
    )
    ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Verbose output');

  final benchmarkParser = ArgParser()
    ..addOption('url', abbr: 'u', help: 'URL to benchmark')
    ..addOption('resolver', abbr: 'r', help: 'Resolver name (optional)')
    ..addOption(
      'iterations',
      abbr: 'n',
      defaultsTo: '5',
      help: 'Number of iterations',
    )
    ..addFlag('json', negatable: false, help: 'Output JSON');

  final validateParser = ArgParser()
    ..addOption('url', abbr: 'u', help: 'URL to validate')
    ..addOption('resolver', abbr: 'r', help: 'Resolver name (optional)')
    ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Verbose output');

  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } catch (_) {
    _printUsage();
    exit(1);
  }

  if (results['help'] as bool || results.command == null) {
    _printUsage();
    exit(0);
  }

  final command = results.command!;
  switch (command.name) {
    case 'list':
      _runList();
    case 'test':
      await _runTest(testParser.parse(command.arguments));
    case 'benchmark':
      await _runBenchmark(benchmarkParser.parse(command.arguments));
    case 'validate':
      await _runValidate(validateParser.parse(command.arguments));
    default:
      _printUsage();
      exit(1);
  }
}

void _printUsage() {
  print('''
${_bold}Kumoriya Resolver CLI$_reset

${_cyan}Commands:$_reset
  list                     List all resolvers with priority/hosts
  test  --url=<URL>        Resolve a URL and show results
  benchmark --url=<URL>    Benchmark resolution speed
  validate --url=<URL>     Validate URL support and resolution

${_cyan}Examples:$_reset
  dart run bin/resolver_cli.dart list
  dart run bin/resolver_cli.dart test --url=https://ok.ru/videoembed/12345
  dart run bin/resolver_cli.dart benchmark --url=https://streamtape.com/e/abc -n 5
  dart run bin/resolver_cli.dart validate --url=https://voe.sx/e/xyz
''');
}

// ──────────────────────────────────────────────────────────────────────────────
// LIST command
// ──────────────────────────────────────────────────────────────────────────────
void _runList() {
  final resolvers = buildAllResolvers();
  print('');
  print('$_bold#   Priority  Resolver                     Hosts$_reset');
  print('$_dim${'─' * 80}$_reset');

  for (var i = 0; i < resolvers.length; i++) {
    final r = resolvers[i];
    final num = '${i + 1}'.padLeft(2);
    final pri = '${r.priority}'.padLeft(3);
    final name = r.manifest.displayName.padRight(28);
    final hosts = r.manifest.supportedHosts.take(4).join(', ');
    final extra = r.manifest.supportedHosts.length > 4
        ? ' (+${r.manifest.supportedHosts.length - 4} more)'
        : '';
    print('$num   $_cyan$pri$_reset    $name $_dim$hosts$extra$_reset');
  }
  print('');
  print('${_bold}Total: ${resolvers.length} resolvers$_reset');
  print('');
}

// ──────────────────────────────────────────────────────────────────────────────
// TEST command
// ──────────────────────────────────────────────────────────────────────────────
Future<void> _runTest(ArgResults args) async {
  final urlStr = args['url'] as String?;
  if (urlStr == null || urlStr.isEmpty) {
    print('${_red}Error: --url is required$_reset');
    exit(1);
  }
  final url = Uri.parse(urlStr);
  final resolvers = buildAllResolvers();
  final iterations = int.tryParse(args['iterations'] as String) ?? 1;
  final verbose = args['verbose'] as bool;
  final resolverName = args['resolver'] as String?;

  ResolverPlugin? resolver;
  if (resolverName != null) {
    resolver = findResolverByName(resolverName, resolvers);
    if (resolver == null) {
      print('${_red}Error: Resolver "$resolverName" not found$_reset');
      exit(1);
    }
  } else {
    resolver = findResolverFor(url, resolvers);
    if (resolver == null) {
      print('${_red}Error: No resolver supports URL: $url$_reset');
      exit(1);
    }
  }

  print('');
  print(
    '${_bold}Testing: ${resolver.manifest.displayName}$_reset $_dim(priority: ${resolver.priority})$_reset',
  );
  print('${_dim}URL: $url$_reset');
  print('${_dim}Iterations: $iterations$_reset');
  print('$_dim${'─' * 60}$_reset');

  final durations = <Duration>[];
  var successes = 0;
  var failures = 0;

  for (var i = 0; i < iterations; i++) {
    final sw = Stopwatch()..start();
    final result = await resolver.resolve(url);
    sw.stop();
    durations.add(sw.elapsed);

    result.fold(
      onSuccess: (resolveResult) {
        successes++;
        final streams = resolveResult.streams;
        final subs = resolveResult.externalSubtitles;
        if (verbose || i == 0) {
          print('');
          print(
            '$_green✓ Iteration ${i + 1}$_reset $_dim(${sw.elapsedMilliseconds}ms)$_reset',
          );
          print('  Streams: ${streams.length}  |  Subtitles: ${subs.length}');
          for (final s in streams) {
            final hlsTag = s.isHls ? ' [HLS]' : '';
            print(
              '    $_cyan${s.qualityLabel ?? "?"}$_reset  ${s.url.toString().substring(0, (s.url.toString().length).clamp(0, 80))}$hlsTag',
            );
            if (verbose) {
              print('    ${_dim}mime: ${s.mimeType ?? "null"}$_reset');
              if (s.headers.isNotEmpty) {
                print(
                  '    ${_dim}headers: ${s.headers.keys.join(", ")}$_reset',
                );
              }
            }
          }
          for (final sub in subs) {
            print(
              '    ${_yellow}SUB$_reset ${sub.label} [${sub.language}]${sub.isDefault ? " (default)" : ""}',
            );
          }
        }
      },
      onFailure: (error) {
        failures++;
        print(
          '$_red✗ Iteration ${i + 1}$_reset $_dim(${sw.elapsedMilliseconds}ms)$_reset',
        );
        print('  $_red${error.code}: ${error.message}$_reset');
      },
    );
  }

  _printTimingSummary(durations, successes, failures);
}

// ──────────────────────────────────────────────────────────────────────────────
// BENCHMARK command
// ──────────────────────────────────────────────────────────────────────────────
Future<void> _runBenchmark(ArgResults args) async {
  final urlStr = args['url'] as String?;
  if (urlStr == null || urlStr.isEmpty) {
    print('${_red}Error: --url is required$_reset');
    exit(1);
  }
  final url = Uri.parse(urlStr);
  final resolvers = buildAllResolvers();
  final iterations = int.tryParse(args['iterations'] as String) ?? 5;
  final jsonOutput = args['json'] as bool;
  final resolverName = args['resolver'] as String?;

  ResolverPlugin? resolver;
  if (resolverName != null) {
    resolver = findResolverByName(resolverName, resolvers);
    if (resolver == null) {
      print('${_red}Error: Resolver "$resolverName" not found$_reset');
      exit(1);
    }
  } else {
    resolver = findResolverFor(url, resolvers);
    if (resolver == null) {
      print('${_red}Error: No resolver supports URL: $url$_reset');
      exit(1);
    }
  }

  if (!jsonOutput) {
    print('');
    print('${_bold}Benchmarking: ${resolver.manifest.displayName}$_reset');
    print('${_dim}URL: $url$_reset');
    print('${_dim}Iterations: $iterations$_reset');
    print('$_dim${'─' * 60}$_reset');
  }

  final durations = <int>[];
  var successes = 0;
  var failures = 0;
  final errors = <String>[];

  for (var i = 0; i < iterations; i++) {
    final sw = Stopwatch()..start();
    final result = await resolver.resolve(url);
    sw.stop();
    durations.add(sw.elapsedMilliseconds);

    result.fold(
      onSuccess: (_) {
        successes++;
        if (!jsonOutput) {
          print('  $_green✓$_reset Iter ${i + 1}: ${sw.elapsedMilliseconds}ms');
        }
      },
      onFailure: (error) {
        failures++;
        errors.add(error.message);
        if (!jsonOutput) {
          print(
            '  $_red✗$_reset Iter ${i + 1}: ${sw.elapsedMilliseconds}ms — ${error.code}',
          );
        }
      },
    );
  }

  if (jsonOutput) {
    final sorted = [...durations]..sort();
    final report = <String, dynamic>{
      'resolver': resolver.manifest.id,
      'displayName': resolver.manifest.displayName,
      'priority': resolver.priority,
      'url': url.toString(),
      'iterations': iterations,
      'successes': successes,
      'failures': failures,
      'successRate': iterations > 0
          ? (successes / iterations * 100).toStringAsFixed(1)
          : '0.0',
      'timingMs': <String, dynamic>{
        'min': sorted.first,
        'max': sorted.last,
        'avg': (sorted.reduce((a, b) => a + b) / sorted.length).round(),
        'median': sorted[sorted.length ~/ 2],
        'p95':
            sorted[(sorted.length * 0.95).floor().clamp(0, sorted.length - 1)],
        'all': sorted,
      },
      if (errors.isNotEmpty) 'errors': errors,
    };
    print(const JsonEncoder.withIndent('  ').convert(report));
  } else {
    print('');
    final sorted = [...durations]..sort();
    final avg = (sorted.reduce((a, b) => a + b) / sorted.length).round();
    final median = sorted[sorted.length ~/ 2];
    final p95 =
        sorted[(sorted.length * 0.95).floor().clamp(0, sorted.length - 1)];

    print('${_bold}Results:$_reset');
    print(
      '  Success rate: ${_successColor(successes, iterations)}$successes/$iterations$_reset',
    );
    print('  Min:    ${sorted.first}ms');
    print('  Max:    ${sorted.last}ms');
    print('  Avg:    ${avg}ms');
    print('  Median: ${median}ms');
    print('  P95:    ${p95}ms');
    print('');
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// VALIDATE command
// ──────────────────────────────────────────────────────────────────────────────
Future<void> _runValidate(ArgResults args) async {
  final urlStr = args['url'] as String?;
  if (urlStr == null || urlStr.isEmpty) {
    print('${_red}Error: --url is required$_reset');
    exit(1);
  }
  final url = Uri.parse(urlStr);
  final resolvers = buildAllResolvers();
  final verbose = args['verbose'] as bool;
  final resolverName = args['resolver'] as String?;

  print('');
  print('${_bold}Validating: $url$_reset');
  print('$_dim${'─' * 60}$_reset');

  // Phase 1: support check across all resolvers
  final supporting = <ResolverPlugin>[];
  for (final r in resolvers) {
    if (r.supports(url)) {
      supporting.add(r);
    }
  }

  if (supporting.isEmpty) {
    print('$_red✗ No resolver supports this URL$_reset');
    if (verbose) {
      print('$_dim  Host: ${url.host}$_reset');
      print('$_dim  Path: ${url.path}$_reset');
    }
    exit(1);
  }

  print('$_green✓ ${supporting.length} resolver(s) support this URL:$_reset');
  for (final r in supporting) {
    print('  $_cyan${r.manifest.displayName}$_reset (priority: ${r.priority})');
  }

  // Phase 2: pick highest priority and resolve
  final resolver = resolverName != null
      ? findResolverByName(resolverName, resolvers) ?? supporting.first
      : supporting.first;

  print('');
  print('${_bold}Resolving with: ${resolver.manifest.displayName}$_reset');

  final sw = Stopwatch()..start();
  final result = await resolver.resolve(url);
  sw.stop();

  result.fold(
    onSuccess: (resolveResult) {
      print(
        '$_green✓ Resolution successful$_reset $_dim(${sw.elapsedMilliseconds}ms)$_reset',
      );
      print('');
      print('${_bold}Streams:$_reset');
      for (final s in resolveResult.streams) {
        final hlsTag = s.isHls ? ' [HLS]' : ' [MP4]';
        print('  $_cyan${s.qualityLabel ?? "unknown"}$_reset$hlsTag');
        print('    URL: ${s.url}');
        if (verbose) {
          print('    ${_dim}mime: ${s.mimeType ?? "null"}$_reset');
          if (s.headers.isNotEmpty) {
            for (final e in s.headers.entries) {
              print('    $_dim$_dim${e.key}: ${e.value}$_reset');
            }
          }
        }
      }
      if (resolveResult.externalSubtitles.isNotEmpty) {
        print('');
        print('${_bold}Subtitles:$_reset');
        for (final sub in resolveResult.externalSubtitles) {
          print(
            '  $_yellow${sub.label}$_reset [${sub.language}]${sub.isDefault ? " (default)" : ""}',
          );
          if (sub.uri != null) {
            print('    URI: ${sub.uri}');
          }
          if (sub.data != null && verbose) {
            print('    ${_dim}data: ${sub.data!.length} chars$_reset');
          }
        }
      }
    },
    onFailure: (error) {
      print(
        '$_red✗ Resolution failed$_reset $_dim(${sw.elapsedMilliseconds}ms)$_reset',
      );
      print('  ${_red}Code: ${error.code}$_reset');
      print('  ${_red}Message: ${error.message}$_reset');
      print('  ${_red}Kind: ${error.kind}$_reset');
    },
  );
  print('');
}

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────
void _printTimingSummary(
  List<Duration> durations,
  int successes,
  int failures,
) {
  if (durations.isEmpty) return;
  final ms = durations.map((d) => d.inMilliseconds).toList()..sort();
  final avg = (ms.reduce((a, b) => a + b) / ms.length).round();
  final median = ms[ms.length ~/ 2];

  print('');
  print('$_dim${'─' * 60}$_reset');
  print('${_bold}Summary:$_reset');
  print(
    '  Success: ${_successColor(successes, successes + failures)}$successes/${successes + failures}$_reset',
  );
  print(
    '  Min: ${ms.first}ms  Max: ${ms.last}ms  Avg: ${avg}ms  Median: ${median}ms',
  );
  print('');
}

String _successColor(int successes, int total) {
  if (total == 0) return _dim;
  final rate = successes / total;
  if (rate >= 0.9) return _green;
  if (rate >= 0.5) return _yellow;
  return _red;
}
