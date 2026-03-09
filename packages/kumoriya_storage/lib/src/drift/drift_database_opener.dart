import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(dir.path, 'kumoriya', 'kumoriya.db');
  await Directory(p.dirname(dbPath)).create(recursive: true);
  final executor = NativeDatabase.createInBackground(File(dbPath));
  return AppDatabase(executor);
}

AppDatabase openInMemoryDatabase() {
  return AppDatabase(NativeDatabase.memory());
}
