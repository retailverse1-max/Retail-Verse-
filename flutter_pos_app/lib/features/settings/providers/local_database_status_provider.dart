import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Whether local SQLite file exists (created after first DB open).
final localDatabaseStatusProvider = FutureProvider<String>((ref) async {
  try {
    final dir = await getDatabasesPath();
    final file = File(p.join(dir, 'pos_app.db'));
    if (await file.exists()) {
      final len = await file.length();
      return 'Ready · ${(len / 1024).toStringAsFixed(1)} KB';
    }
    return 'Not initialized (opens on first local use)';
  } catch (e) {
    return 'Unknown ($e)';
  }
});
