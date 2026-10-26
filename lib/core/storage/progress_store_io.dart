import 'dart:io';

import 'progress_store.dart';

class _FileStore implements ProgressStore {
  const _FileStore();

  String get _path {
    final home = Platform.environment['HOME'] ??
        Platform.environment['APPDATA'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    return '$home/.chess_practice_progress.json';
  }

  @override
  Future<String?> readString() async {
    try {
      final f = File(_path);
      return await f.exists() ? f.readString() : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeString(String value) async {
    try {
      await File(_path).writeString(value);
    } catch (_) {/* memory-only fallback */}
  }
}

ProgressStore createStore() => const _FileStore();
