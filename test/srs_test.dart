import 'package:chess_practice/features/progress/domain/srs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interval ladder grows on clean passes', () {
    LineProgress? p;
    final intervals = <int>[];
    final now = DateTime(2026, 1, 1);
    for (var i = 0; i < 4; i++) {
      p = Srs.grade(p, passed: true, mistakes: 0, now: now);
      intervals.add(p.due.difference(now).inDays);
    }
    expect(intervals, [1, 3, 4, 6]);
    expect(p!.isLearned, isTrue);
  });

  test('a lapse resets reps and makes the line due immediately', () {
    final now = DateTime(2026, 1, 1);
    var p = Srs.grade(null, passed: true, mistakes: 0, now: now);
    p = Srs.grade(p, passed: true, mistakes: 0, now: now);
    p = Srs.grade(p, passed: false, mistakes: 3, now: now);
    expect(p.reps, 0);
    expect(p.lapses, 1);
    expect(p.due, now);
    expect(p.ease, closeTo(2.5, 1e-9)); // 2.5 + 0.1 + 0.1 - 0.2
  });

  test('mastery stays in 0..1 and increases with practice', () {
    final now = DateTime(2026, 1, 1);
    final fresh = LineProgress();
    expect(fresh.mastery, 0);
    final practiced = Srs.grade(null, passed: true, mistakes: 0, now: now);
    expect(practiced.mastery, greaterThan(0));
    expect(practiced.mastery, lessThanOrEqualTo(1));
  });
}
