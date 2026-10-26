import 'package:flutter/material.dart';
import '../features/training/domain/session_engine.dart';

ThemeData buildTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C4DFF), // chessreps-style violet
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      cardTheme: const CardThemeData(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );

/// Chessreps assigns each mode its own identity color.
Color modeColor(TrainingMode mode) => switch (mode) {
      TrainingMode.learn => const Color(0xFF7C4DFF),
      TrainingMode.practice => const Color(0xFF00897B),
      TrainingMode.drill => const Color(0xFFD32F2F),
      TrainingMode.timeTrial => const Color(0xFF1E88E5),
    };

String modeTitle(TrainingMode mode) => switch (mode) {
      TrainingMode.learn => 'Learn',
      TrainingMode.practice => 'Practice',
      TrainingMode.drill => 'Drill',
      TrainingMode.timeTrial => 'Time Trial',
    };

String modeBlurb(TrainingMode mode) => switch (mode) {
      TrainingMode.learn => 'Hints and coach notes on every move',
      TrainingMode.practice => 'No hints — pure recall of lines you have learned',
      TrainingMode.drill => 'How many lines can you nail in a row?',
      TrainingMode.timeTrial => '60 seconds. Correct moves buy more clock.',
    };
