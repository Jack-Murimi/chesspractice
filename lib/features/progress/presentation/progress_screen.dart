import 'package:flutter/material.dart';

import '../../../catalog/data/courses.dart';
import '../domain/progress_controller.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.progress});

  final ProgressController progress;

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset all progress?'),
        content: const Text(
            'This erases every SRS schedule, XP and streak on this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (ok == true) await progress.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            tooltip: 'Reset progress',
            onPressed: () => _confirmReset(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: progress,
        builder: (context, _) {
          final learned = courses
              .map(progress.learnedCount)
              .fold<int>(0, (a, b) => a + b);
          final totalLines =
              courses.fold<int>(0, (a, c) => a + c.lines.length);
          final due = courses
              .map(progress.reviewDueCount)
              .fold<int>(0, (a, b) => a + b);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Row(children: [
                _statCard(Icons.star_border, '${progress.xp}', 'XP'),
                _statCard(Icons.local_fire_department,
                    '${progress.streak}', 'day streak'),
                _statCard(Icons.school_outlined,
                    '$learned/$totalLines', 'lines learned'),
                _statCard(Icons.schedule, '$due', 'due now'),
              ]),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Mastery by course',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final course in courses)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Text(course.emoji,
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(course.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: progress.courseMastery(course),
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                            '${(progress.courseMastery(course) * 100).round()}%'),
                      ],
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Reviews are spaced automatically: lines you miss come '
                  'back sooner, solid lines return on a 1 → 3 → 4 → 6+ day '
                  'ladder.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label) => Expanded(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Icon(icon),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
      );
}
