import 'dart:js_interop';

import 'progress_store.dart';

const _key = 'chess_practice_progress_v1';

class _WebStore implements ProgressStore {
  const _WebStore();

  @override
  Future<String?> readString() async => webStorageGet(_key);

  @override
  Future<void> writeString(String value) async =>
      webStorageSet(_key, value);
}

ProgressStore createStore() => const _WebStore();

@JS('localStorage.getItem')
external String? webStorageGet(String key);

@JS('localStorage.setItem')
external void webStorageSet(String key, String value);
