import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(_openConnection());
  ref.onDispose(database.close);
  return database;
});

final conversationLocalStoreProvider = Provider<ConversationLocalStore>((ref) {
  return ref.watch(appDatabaseProvider).conversationLocalDao;
});

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    if (_isRunningInFlutterTest()) {
      return NativeDatabase.memory();
    }

    final file = await _resolveDatabaseFile();
    return NativeDatabase.createInBackground(file);
  });
}

bool _isRunningInFlutterTest() {
  return Platform.environment.containsKey('FLUTTER_TEST') ||
      Platform.environment.containsKey('DART_TEST');
}

Future<File> _resolveDatabaseFile() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    return File(p.join(directory.path, 'slock_local_data.sqlite'));
  } on MissingPluginException {
    return _fallbackDatabaseFile();
  } on FlutterError {
    return _fallbackDatabaseFile();
  }
}

Future<File> _fallbackDatabaseFile() async {
  final directory = await Directory.systemTemp.createTemp('slock_local_data.');
  return File(p.join(directory.path, 'slock_local_data.sqlite'));
}
