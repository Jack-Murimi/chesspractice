/// App-wide progress: per-line SRS state, XP and daily streak.
/// ChangeNotifier is enough state management for this app size — no package.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/storage/progress_store.dart';
import '../../catalog/domain/course.dart';
import 'srs.dart';

class ProgressController extends ChangeNotifier {
  ProgressController(this._store);

  final ProgressStore _store;
  final Map<String, Map<String, LineProgress>> _data = {};

  int xp = 0;
  int streak = 0;
  DateTime? lastActiveDay;
  bool loaded = false;

  Future<void> load() async {
    final raw = await _store.readString();
    if (raw == null || raw.isEmpty) {
      loaded = true;
      return;
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in (j['courses'] as Map<String, dynamic>? ?? {}).entries) {
        final lines = (entry.value as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, LineProgress.fromJson(v as Map<String, dynamic>)),
        );
        _data[entry.key] = lines;
      }
      xp = j['xp'] as int? ?? 0;
      streak = j['streak'] as int? ?? 0;
      lastActiveDay = DateTime.tryParse(j['lastActiveDay'] as String? ?? '');
    } catch (_) {/* corrupt file: start fresh, never block training */}
    loaded = true;
  }

  Future<void> _save() async {
    await _store.writeString(jsonEncode({
      'courses': _data.map((c, lines) =>
          MapEntry(c, lines.map((k, v) => MapEntry(k, v.toJson())))),
      'xp': xp,
      'streak': streak,
      'lastActiveDay': lastActiveDay?.toIso8601String(),
    }));
  }

  LineProgress? of(String courseId, String lineId) =>
      _data[courseId]?[lineId];

  Map<String, LineProgress> _courseMap(String courseId) =>
      _data.putIfAbsent(courseId, () => {});

  bool isLearned(String courseId, String lineId) =>
      (of(courseId, lineId)?.isLearned) ?? false;

  bool isDue(LineProgress? p, DateTime now) =>
      p == null || !p.isLearned || !p.due.isAfter(now);

  int learnedCount(Course course) =>
      course.lines.where((l) => isLearned(course.id, l.id)).length;

  int dueCount(Course course, {DateTime? now}) {
    final t = now ?? DateTime.now();
    return course.lines
        .where((l) => isDue(of(course.id, l.id), t))
        .length;
  }

  /// Learned lines whose SRS schedule says they are due for review.
  int reviewDueCount(Course course, {DateTime? now}) {
    final t = now ?? DateTime.now();
    return course.lines.where((l) {
      final p = of(course.id, l.id);
      return p != null && p.isLearned && isDue(p, t);
    }).length;
  }

  double courseMastery(Course course) {
    if (course.lines.isEmpty) return 0;
    final sum = course.lines
        .map((l) => of(course.id, l.id)?.mastery ?? 0)
        .reduce((a, b) => a + b);
    return sum / course.lines.length;
  }

  /// Wipes all local progress (user-controlled reset).
  Future<void> reset() async {
    _data.clear();
    xp = 0;
    streak = 0;
    lastActiveDay = null;
    notifyListeners();
    await _save();
  }

  /// Records one finished line attempt and applies the SRS ladder.
  Future<void> recordLine(
    String courseId,
    String lineId, {
    required bool completed,
    required int mistakes,
    required int points,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    _bumpStreak(current);
    final map = _courseMap(courseId);
    map[lineId] = Srs.grade(map[lineId],
        passed: completed, mistakes: mistakes, now: current);
    xp += points;
    notifyListeners();
    await _save();
  }

  void _bumpStreak(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (lastActiveDay == null) {
      streak = 1;
    } else {
      final last = DateTime(
          lastActiveDay!.year, lastActiveDay!.month, lastActiveDay!.day);
      final gap = today.difference(last).inDays;
      streak = gap == 0 ? streak : gap == 1 ? streak + 1 : 1;
    }
    lastActiveDay = today;
  }
}
