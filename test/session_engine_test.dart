import 'dart:math';

import 'package:chess_practice/features/catalog/data/courses.dart';
import 'package:chess_practice/features/catalog/domain/course.dart';
import 'package:chess_practice/features/training/domain/session_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Course courseById(String id) => courses.firstWhere((c) => c.id == id);

/// Plays the currently expected repertoire move through the board-tap API.
void playExpected(SessionEngine engine) {
  final move = engine.expectedMove!;
  engine.tapSquare(move.from);
  engine.tapSquare(move.to);
}

void main() {
  test('perfect Learn run completes a line with no mistakes', () {
    final london = courseById('london');
    final engine = SessionEngine(
      course: london,
      mode: TrainingMode.learn,
      queue: [london.lines.first.id],
      random: Random(1),
    );
    while (!engine.finished) {
      expect(engine.studentTurn, isTrue);
      playExpected(engine);
    }
    expect(engine.linesCompleted, 1);
    expect(engine.totalMistakes, 0);
    expect(engine.points, greaterThan(0));
  });

  test('a non-repertoire legal move is rejected and counted', () {
    final london = courseById('london');
    final engine = SessionEngine(
      course: london,
      mode: TrainingMode.practice,
      queue: [london.lines.first.id],
      random: Random(1),
    );
    final expected = engine.expectedMove!;
    final wrong = engine.position
        .legalMoves()
        .firstWhere((m) => m.from != expected.from || m.to != expected.to);
    final before = engine.position.board[wrong.to];
    engine.tapSquare(wrong.from);
    engine.tapSquare(wrong.to);
    expect(engine.totalMistakes, 1);
    expect(engine.position.board[wrong.to], before); // move not applied
    expect(engine.finished, isFalse);

    while (!engine.finished) {
      playExpected(engine);
    }
    expect(engine.linesCompleted, 1);
  });

  test('Drill failure ends the line and resets the streak', () {
    final italian = courseById('italian');
    final engine = SessionEngine(
      course: italian,
      mode: TrainingMode.drill,
      queue: [italian.lines.first.id],
      random: Random(1),
    );
    final expected = engine.expectedMove!;
    final wrong = engine.position
        .legalMoves()
        .firstWhere((m) => m.from != expected.from || m.to != expected.to);
    engine.tapSquare(wrong.from);
    engine.tapSquare(wrong.to);
    expect(engine.awaitingContinue, isTrue);
    expect(engine.streak, 0);
    engine.continueAfterFailure();
    expect(engine.linesFailed, 1);
    expect(engine.finished, isTrue);
  });

  test('student-side branch: Evans b4 is accepted from the piano queue', () {
    final italian = courseById('italian');
    final piano = italian.lines.firstWhere((l) => l.id == 'italian-piano');
    final engine = SessionEngine(
      course: italian,
      mode: TrainingMode.learn,
      queue: [piano.id],
      random: Random(1),
    );
    // Walk the shared prefix 1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5 (plies 0..5).
    for (var i = 0; i < 6; i++) {
      playExpected(engine);
    }
    // At ply 6 choose the Evans Gambit branch (b4) instead of piano c3.
    final b4 = engine.position.sanToMove('b4');
    engine.tapSquare(b4.from);
    engine.tapSquare(b4.to);
    expect(engine.totalMistakes, 0); // another repertoire line, not an error
    while (!engine.finished) {
      playExpected(engine);
    }
    expect(engine.linesCompleted, 1);
  });

  test('Time Trial ends when the clock hits zero', () {
    final london = courseById('london');
    final engine = SessionEngine(
      course: london,
      mode: TrainingMode.timeTrial,
      queue: [london.lines.first.id],
      random: Random(1),
    );
    for (var i = 0; i < 60; i++) {
      engine.tick();
    }
    expect(engine.finished, isTrue);
    expect(engine.secondsLeft, 0);
  });

  test('weighted opponent branch stays inside the repertoire', () {
    final sicilian = courseById('sicilian'); // Black course, 5 lines
    for (final seed in List.generate(10, (i) => i)) {
      final engine = SessionEngine(
        course: sicilian,
        mode: TrainingMode.learn,
        queue: [sicilian.lines.first.id],
        random: Random(seed),
      );
      while (!engine.finished) {
        // expectedMove must always resolve against the current position
        expect(engine.expectedMove, isNotNull);
        playExpected(engine);
      }
      expect(engine.linesCompleted, 1);
    }
  });
}
