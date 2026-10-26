/// Tiny JSON-string persistence with no third-party plugins.
/// The platform implementation is selected by a native conditional import:
/// browser localStorage on web, a dotfile in the home directory otherwise.
/// Failures degrade to in-memory progress instead of crashing training.
library;

import 'progress_store_stub.dart'
    if (dart.library.io) 'progress_store_io.dart'
    if (dart.library.js_interop) 'progress_store_web.dart';

abstract class ProgressStore {
  Future<String?> readString();
  Future<void> writeString(String value);

  factory ProgressStore.detect() => createStore();
}
