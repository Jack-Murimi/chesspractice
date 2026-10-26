/// SM-2 style spaced-repetition scheduler ("Reps").
///
/// Correct completions push the next review further out; a failed line resets
/// and comes back immediately. Deliberately tiny: no card fields, no FSRS
/// parameter fitting — openings only need a reliable interval ladder.
library;

class LineProgress {
  LineProgress({
    this.reps = 0,
    this.ease = 2.5,
    DateTime? due,
    this.lapses = 0,
    this.attempts = 0,
    this.successes = 0,
    this.lastPracticed,
  }) : due = due ?? DateTime.fromMillisecondsSinceEpoch(0);

  int reps;
  double ease;
  DateTime due;
  int lapses;
  int attempts;
  int successes;
  DateTime? lastPracticed;

  bool get isLearned => reps > 0;

  /// 0..1 blend of accuracy so far and SRS maturity.
  double get mastery {
    final accuracy = attempts == 0 ? 0.0 : successes / attempts;
    return (0.5 * accuracy + 0.5 * (reps / 4).clamp(0, 1)).toDouble();
  }

  Map<String, dynamic> toJson() => {
        'reps': reps,
        'ease': ease,
        'due': due.toIso8601String(),
        'lapses': lapses,
        'attempts': attempts,
        'successes': successes,
        'lastPracticed': lastPracticed?.toIso8601String(),
      };

  factory LineProgress.fromJson(Map<String, dynamic> j) => LineProgress(
        reps: j['reps'] as int? ?? 0,
        ease: (j['ease'] as num?)?.toDouble() ?? 2.5,
        due: DateTime.tryParse(j['due'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        lapses: j['lapses'] as int? ?? 0,
        attempts: j['attempts'] as int? ?? 0,
        successes: j['successes'] as int? ?? 0,
        lastPracticed: DateTime.tryParse(j['lastPracticed'] as String? ?? ''),
      );
}

class Srs {
  /// Returns the updated progress after one line attempt.
  /// [passed] = the line was completed (a drill failure passes false).
  static LineProgress grade(
    LineProgress? prior, {
    required bool passed,
    required int mistakes,
    DateTime? now,
  }) {
    final p = prior ?? LineProgress();
    final current = now ?? DateTime.now();
    final quality = !passed
        ? 1
        : mistakes == 0
            ? 5
            : mistakes == 1
                ? 3
                : 2;

    p.attempts++;
    if (passed) p.successes++;
    p.lastPracticed = current;

    if (quality < 3) {
      p.reps = 0;
      p.lapses++;
      p.ease = (p.ease - 0.2).clamp(1.3, 5.0).toDouble();
      p.due = current; // see it again right away
      return p;
    }
    p.reps++;
    p.ease = (p.ease + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)))
        .clamp(1.3, 5.0)
        .toDouble();
    final intervalDays = p.reps == 1 ? 1 : p.reps == 2 ? 3 : (p.reps - 1) * 2;
    p.due = current.add(Duration(days: intervalDays));
    return p;
  }
}
