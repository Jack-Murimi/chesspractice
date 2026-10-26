import 'package:flutter/material.dart';

import '../../../progress/domain/progress_controller.dart';
import '../../data/courses.dart';
import '../../domain/course.dart';
import 'course_detail_screen.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, required this.progress});

  final ProgressController progress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess Practice'),
        actions: [
          ListenableBuilder(
            listenable: progress,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Chip(
                  avatar: const Icon(Icons.local_fire_department, size: 18),
                  label: Text('${progress.streak} day streak'),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: progress,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Reps for your openings — learn the move, then repeat it '
                'until it is automatic.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            for (final course in courses) _CourseCard(
              course: course,
              progress: progress,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CourseDetailScreen(
                  course: course,
                  progress: progress,
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.progress,
    required this.onTap,
  });

  final Course course;
  final ProgressController progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mastery = progress.courseMastery(course);
    final learned = progress.learnedCount(course);
    final newLines = course.lines.length - learned;
    final due = progress.reviewDueCount(course);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(course.emoji,
                    style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      '${course.side == Side.white ? 'White' : 'Black'} · '
                      '$newLines new · $due review due',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: mastery,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${(mastery * 100).round()}%  ·  $learned/'
                            '${course.lines.length}'),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
