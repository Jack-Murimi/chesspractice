/// Session screen shared by all four training modes. The mode only changes
/// queue planning and feedback rules — everything else is reused.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../catalog/domain/course.dart';
import '../../../progress/domain/progress_controller.dart';
import '../domain/session_engine.dart';
import 'board_widget.dart';

/// Decides which lines this session contains.
List<String> planQueue(
    Course course, TrainingMode mode, ProgressController progress, Random rng) {
  final all = course.lines.map((l) => l.id).toList();
  final now = DateTime.now();
  switch (mode) {
    case TrainingMode.learn:
      final fresh = all.where((id) => !progress.isLearned(course.id, id)).toList();
      final cohort = fresh.take(3).toList();
      if (cohort.length < 3) {
        final reviews = all
            .where((id) => progress.isLearned(course.id, id))
            .where((id) => progress.isDue(progress.of(course.id, id), now))
            .where((id) => !cohort.contains(id))
            .take(3 - cohort.length);
        cohort.addAll(reviews);
      }
      return cohort.isEmpty ? all.take(3).toList() : cohort;
    case TrainingMode.practice:
      return all
          .where((id) => progress.isLearned(course.id, id))
          .where((id) => progress.isDue(progress.of(course.id, id), now))
          .take(10)
          .toList();
    case TrainingMode.drill:
      return (all..shuffle(rng)).take(10).toList();
    case TrainingMode.timeTrial:
      return all..shuffle(rng);
  }
}

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({
    super.key,
    required this.course,
    required this.mode,
    required this.progress,
  });

  final Course course;
  final TrainingMode mode;
  final ProgressController progress;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  late final SessionEngine _engine;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    final queue =
        planQueue(widget.course, widget.mode, widget.progress, Random());
    _engine = SessionEngine(
      course: widget.course,
      mode: widget.mode,
      queue: queue,
      onLineEnd: (lineId, completed, mistakes, points) {
        widget.progress.recordLine(
          widget.course.id,
          lineId,
          completed: completed,
          mistakes: mistakes,
          points: points,
        );
      },
    );
    if (widget.mode == TrainingMode.timeTrial) {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) _engine.tick();
      });
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = modeColor(widget.mode);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        title: Text('${modeTitle(widget.mode)} · ${widget.course.title}'),
      ),
      body: ListenableBuilder(
        listenable: _engine,
        builder: (context, _) =>
            _engine.finished ? _results(context, color) : _session(color),
      ),
    );
  }

  Widget _session(Color color) {
    final hint = _engine.showHint ? _engine.expectedMove : null;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _Hud(engine: _engine, color: color),
        const SizedBox(height: 10),
        ChessBoard(
          position: _engine.position,
          selected: _engine.selected,
          legalMoves: _engine.selectedMoves,
          lastFrom: _engine.lastFrom,
          lastTo: _engine.lastTo,
          hintFrom: hint?.from,
          hintTo: hint?.to,
          flipped: widget.course.side == Side.black,
          onSquare: _engine.tapSquare,
        ),
        const SizedBox(height: 10),
        _Banner(engine: _engine, color: color),
        const SizedBox(height: 8),
        _MoveLog(sanLog: _engine.sanLog),
        const SizedBox(height: 8),
        Row(
          children: [
            if (widget.mode == TrainingMode.learn ||
                widget.mode == TrainingMode.practice)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _engine.studentTurn ? _engine.useHint : null,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text('Hint (${_engine.totalHints})'),
                ),
              ),
            if (widget.mode == TrainingMode.learn ||
                widget.mode == TrainingMode.practice)
              const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('End session'),
              ),
            ),
          ],
        ),
        if (_engine.awaitingContinue)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: _engine.continueAfterFailure,
              child: const Text('Next line'),
            ),
          ),
      ],
    );
  }

  Widget _results(BuildContext context, Color color) {
    final e = _engine;
    final pct = (e.accuracy * 100).round();
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.emoji_events_rounded, size: 48, color: color),
            const SizedBox(height: 8),
            Text('Session complete',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _statRow('Lines completed', '${e.linesCompleted}'),
            if (e.linesFailed > 0) _statRow('Lines failed', '${e.linesFailed}'),
            _statRow('Accuracy', '$pct%'),
            if (widget.mode == TrainingMode.drill)
              _statRow('Best streak', '${e.bestStreak}'),
            _statRow('Mistakes', '${e.totalMistakes}'),
            _statRow('Hints used', '${e.totalHints}'),
            _statRow('XP earned', '+${e.points}'),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Back to course'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
        ),
      );
}

class _Hud extends StatelessWidget {
  const _Hud({required this.engine, required this.color});
  final SessionEngine engine;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.12),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(engine.lineName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Line ${engine.queuePosition}/${engine.queueLength}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (engine.mode == TrainingMode.timeTrial)
              _timeChip(engine.secondsLeft)
            else if (engine.mode == TrainingMode.drill)
              _chip('Streak', '${engine.streak}', Icons.local_fire_department)
            else
              _chip('XP', '${engine.points}', Icons.star_border),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, IconData icon) => Chip(
        avatar: Icon(icon, size: 18),
        label: Text('$label $value'),
        visualDensity: VisualDensity.compact,
      );

  Widget _timeChip(int seconds) {
    final urgent = seconds <= 10;
    return Chip(
      avatar: Icon(Icons.timer,
          size: 18, color: urgent ? Colors.red : null),
      label: Text('${seconds}s',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: urgent ? Colors.red : null)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.engine, required this.color});
  final SessionEngine engine;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = engine.banner ?? engine.blurb;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey(text),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Text(text ?? 'Your move — find the repertoire move.'),
      ),
    );
  }
}

class _MoveLog extends StatelessWidget {
  const _MoveLog({required this.sanLog});
  final List<String> sanLog;

  @override
  Widget build(BuildContext context) {
    if (sanLog.isEmpty) return const SizedBox.shrink();
    final pairs = <String>[];
    for (var i = 0; i < sanLog.length; i += 2) {
      final num = i ~/ 2 + 1;
      final black = i + 1 < sanLog.length ? ' ${sanLog[i + 1]}' : '';
      pairs.add('$num. ${sanLog[i]}$black');
    }
    final shown = pairs.length > 6 ? pairs.sublist(pairs.length - 6) : pairs;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shown.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => Chip(
          label: Text(shown[i]),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
