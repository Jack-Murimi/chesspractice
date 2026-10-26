import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../progress/domain/progress_controller.dart';
import '../../../progress/domain/srs.dart';
import '../../../training/domain/session_engine.dart';
import '../../../training/presentation/training_screen.dart';
import '../../domain/course.dart';

class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({
    super.key,
    required this.course,
    required this.progress,
  });

  final Course course;
  final ProgressController progress;

  void _start(BuildContext context, TrainingMode mode) {
    if (mode == TrainingMode.practice &&
        (progress.learnedCount(course) == 0 ||
            progress.reviewDueCount(course) == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nothing to review yet — learn a few lines first.'),
      ));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TrainingScreen(
        course: course,
        mode: mode,
        progress: progress,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(course.title)),
      body: ListenableBuilder(
        listenable: progress,
        builder: (context, _) {
          final mastery = progress.courseMastery(course);
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Text(course.emoji, style: const TextStyle(fontSize: 44)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(course.title,
                            style: Theme.of(context).textTheme.headlineSmall),
                        Text('Play ${course.side == Side.white ? 'White' : 'Black'} · '
                            'by ${course.author}'),
                      ],
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(course.description),
              ),
              const SizedBox(height: 12),
              _StatsRow(
                mastery: mastery,
                learned: progress.learnedCount(course),
                total: course.lines.length,
                due: progress.reviewDueCount(course),
              ),
              const SizedBox(height: 8),
              for (final mode in TrainingMode.values)
                _ModeTile(
                  mode: mode,
                  onTap: () => _start(context, mode),
                ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Lines (${course.lines.length})',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final line in course.lines)
                _LineTile(
                  line: line,
                  state: progress.of(course.id, line.id),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.mastery,
    required this.learned,
    required this.total,
    required this.due,
  });

  final double mastery;
  final int learned;
  final int total;
  final int due;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _stat('Mastery', '${(mastery * 100).round()}%'),
        _stat('Learned', '$learned/$total'),
        _stat('Due now', '$due'),
      ],
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.mode, required this.onTap});

  final TrainingMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = modeColor(mode);
    final icon = switch (mode) {
      TrainingMode.learn => Icons.school_outlined,
      TrainingMode.practice => Icons.repeat,
      TrainingMode.drill => Icons.local_fire_department_outlined,
      TrainingMode.timeTrial => Icons.timer_outlined,
    };
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Text(modeTitle(mode)),
        subtitle: Text(modeBlurb(mode)),
        trailing: const Icon(Icons.play_arrow_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line, required this.state});

  final OpeningLine line;
  final LineProgress? state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _status(state);
    return ListTile(
      dense: true,
      leading: Icon(label.$1, color: color, size: 20),
      title: Text(line.name),
      subtitle: Text('~${line.weight}% frequency weight'),
      trailing: Text(label.$2, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  (IconData, String, Color) _status(LineProgress? s) {
    if (s == null || !s.isLearned) {
      return (Icons.fiber_new, 'New', Colors.grey);
    }
    final days = s.due.difference(DateTime.now()).inDays;
    if (days <= 0) {
      return (Icons.schedule, 'Due now', Colors.deepOrange);
    }
    return (Icons.check_circle_outline, 'Due in $days d', Colors.teal);
  }
}
