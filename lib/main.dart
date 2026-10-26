import 'package:flutter/material.dart';

import 'app.dart';
import 'core/storage/progress_store.dart';
import 'features/progress/domain/progress_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final progress = ProgressController(ProgressStore.detect());
  await progress.load();
  runApp(ChessPracticeApp(progress: progress));
}
