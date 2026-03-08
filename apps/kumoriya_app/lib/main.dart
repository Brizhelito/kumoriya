import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: KumoriyaApp()));
}

class KumoriyaApp extends StatelessWidget {
  const KumoriyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kumoriya',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D9488)),
      ),
      home: const _BootstrapHome(),
    );
  }
}

class _BootstrapHome extends StatelessWidget {
  const _BootstrapHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Kumoriya bootstrap ready')),
    );
  }
}
