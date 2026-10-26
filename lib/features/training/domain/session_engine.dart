/// Training session engine shared by Learn, Practice, Drill and Time Trial.
///
/// The engine walks repertoire lines ply by ply. At opponent plies it picks a
/// sibling line weighted by real-game frequency (the "moves real humans play"
/// idea from chessreps); at student plies it waits for a board tap and grades
/// the move against the repertoire.
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/chess/chess.dart';
import '../../catalog/domain/course.dart';

enum TrainingMode { learn, practice, drill, timeTrial }

/// Called once per finished line so the UI can persist SRS progress.
typedef LineEndCallback = void Function(
    String lineId, bool completed, int mistakes, int points);

class SessionEngine extends ChangeNotifier {
  SessionEngine({
    required this.course,
    required this.mode,
    required List<String> queue,
    Random? random,
    this.onLineEnd,
  })  : _queue = [...queue],
        _rng = random ?? Random(),
        secondsLeft = mode == TrainingMode.timeTrial ? 60 : 0 {
    start();
  }

  final Course course;
  final TrainingMode mode;
  final LineEndCallback? onLineEnd;
  final Random _rng;
  List<String> _queue;
  int _queuePos = 0;

  late OpeningLine _line;
  int _ply = 0;
  final List<String> _sanLog = [];

  ChessPosition position = ChessPosition.initial();
  int? selected;
  List<Move> selectedMoves = const [];
  int? lastFrom;
  int? lastTo;

  String? blurb;
  String? banner;
  bool showHint = false;
  bool awaitingContinue = false; // drill failure needs a tap to move on
  bool finished = false;

  int mistakesOnLine = 0;
  int hintsOnLine = 0;
  int _wrongAtPly = 0;
  int _pointsOnLine = 0;

  int linesCompleted = 0;
  int linesFailed = 0;
  int totalMistakes = 0;
  int totalHints = 0;
  int studentMoves = 0;
  int points = 0;
  int streak = 0;
  int bestStreak = 0;
  int secondsLeft;

  bool get _studentWhite => course.side == Side.white;
  bool get studentTurn =>
      !finished && !awaitingContinue && position.whiteToMove == _studentWhite;

  String get lineName => _line.name;
  int get queuePosition => _queuePos >= _queue.length ? _queue.length : _queuePos + 1;
  int get queueLength => _queue.length;
  List<String> get sanLog => List.unmodifiable(_sanLog);

  static String _norm(String san) => san.replaceAll(RegExp(r'[+#!?]'), '');

  void start() {
    _loadLine(_queue.first);
  }

  void _loadLine(String id) {
    _line = course.lineById(id);
    _ply = 0;
    _sanLog.clear();
    position = ChessPosition.initial();
    selected = null;
    selectedMoves = const [];
    lastFrom = lastTo = null;
    blurb = banner = null;
    showHint = false;
    awaitingContinue = false;
    mistakesOnLine = hintsOnLine = _wrongAtPly = _pointsOnLine = 0;
    _advanceToStudent();
    notifyListeners();
  }

  void _advanceToStudent() {
    while (!studentTurn && _ply < _line.moves.length) {
      final chosen = _pickOpponentLine();
      _line = chosen;
      final san = _line.moves[_ply];
      final move = position.sanToMove(san);
      position = position.apply(move);
      lastFrom = move.from;
      lastTo = move.to;
      _sanLog.add(position.toSan(move));
      _ply++;
    }
    if (_ply >= _line.moves.length) _endLine(completed: true);
  }

  OpeningLine _pickOpponentLine() {
    final candidates = course.lines
        .where((l) => l.moves.length > _ply && _matchesPrefix(l.moves))
        .toList();
    if (candidates.length <= 1) return candidates.isEmpty ? _line : candidates.first;
    final total = candidates.fold<int>(0, (s, l) => s + l.weight);
    var roll = _rng.nextInt(total);
    for (final l in candidates) {
      roll -= l.weight;
      if (roll < 0) return l;
    }
    return candidates.last;
  }

  bool _matchesPrefix(List<String> moves) {
    for (var i = 0; i < _sanLog.length; i++) {
      if (_norm(moves[i]) != _norm(_sanLog[i])) return false;
    }
    return true;
  }

  Move? get expectedMove {
    if (!studentTurn || _ply >= _line.moves.length) return null;
    return position.sanToMove(_line.moves[_ply]);
  }

  void useHint() {
    if (mode == TrainingMode.drill || mode == TrainingMode.timeTrial) return;
    if (!studentTurn) return;
    hintsOnLine++;
    totalHints++;
    showHint = true;
    blurb = _line.blurbs[_ply] ?? 'Repertoire move: ${_line.moves[_ply]}';
    notifyListeners();
  }

  void tapSquare(int sq) {
    if (finished || awaitingContinue || !studentTurn) return;
    final piece = position.board[sq];
    if (selected == null) {
      if (piece != null && piece.isWhite == _studentWhite) _select(sq);
      return;
    }
    if (piece != null && piece.isWhite == _studentWhite) {
      _select(sq); // reselect another own piece
      return;
    }
    final matches = selectedMoves.where((m) => m.to == sq);
    final move = matches.isEmpty ? null : matches.first;
    if (move == null) {
      selected = null;
      selectedMoves = const [];
      notifyListeners();
      return;
    }
    _attempt(move);
  }

  void _select(int sq) {
    selected = sq;
    selectedMoves = position.legalMoves(from: sq);
    notifyListeners();
  }

  void _attempt(Move move) {
    final actualSan = _norm(position.toSan(move));
    // A move is correct if ANY repertoire line sharing the current prefix
    // continues with it — students may choose their own branch.
    final matches = course.lines
        .where((l) =>
            l.moves.length > _ply &&
            _matchesPrefix(l.moves) &&
            _norm(l.moves[_ply]) == actualSan)
        .toList();
    if (matches.isEmpty) {
      _onWrong();
      return;
    }
    if (!matches.contains(_line)) _line = matches.first;
    position = position.apply(move);
    lastFrom = move.from;
    lastTo = move.to;
    _sanLog.add(position.toSan(move));
    _ply++;
    studentMoves++;
    _pointsOnLine += 10;
    points += 10;
    selected = null;
    selectedMoves = const [];
    _wrongAtPly = 0;
    showHint = false;
    blurb = _line.blurbs[_ply - 1];
    banner = switch (mode) {
      TrainingMode.learn => blurb ?? 'Correct — that is the repertoire move.',
      TrainingMode.practice => blurb ?? 'Nice.',
      TrainingMode.drill => null,
      TrainingMode.timeTrial => null,
    };
    if (mode == TrainingMode.timeTrial) {
      secondsLeft = min(90, secondsLeft + 3);
    }
    _advanceToStudent();
    notifyListeners();
  }

  void _onWrong() {
    totalMistakes++;
    mistakesOnLine++;
    _wrongAtPly++;
    final expected = _line.moves[_ply];
    switch (mode) {
      case TrainingMode.learn:
        showHint = true;
        banner = _line.blurbs[_ply] ?? 'Not quite — the repertoire move is $expected.';
      case TrainingMode.practice:
        showHint = _wrongAtPly >= 2;
        banner = showHint
            ? 'Repertoire move: $expected'
            : 'Wrong move — try again from memory.';
      case TrainingMode.drill:
        streak = 0;
        banner = 'The move was $expected.';
        awaitingContinue = true;
      case TrainingMode.timeTrial:
        secondsLeft = max(0, secondsLeft - 3);
        banner = 'Nope! −3 seconds. Repertoire move: $expected';
    }
    notifyListeners();
  }

  /// Drill only: acknowledge the failed line and move to the next one.
  void continueAfterFailure() {
    if (!awaitingContinue) return;
    _endLine(completed: false);
  }

  void _endLine({required bool completed}) {
    if (completed) {
      linesCompleted++;
      streak++;
      bestStreak = max(bestStreak, streak);
      _pointsOnLine += 50;
      points += 50;
    } else {
      linesFailed++;
    }
    onLineEnd?.call(_line.id, completed, mistakesOnLine, _pointsOnLine);
    _queuePos++;
    if (_queuePos >= _queue.length) {
      if (mode == TrainingMode.timeTrial) {
        _queue = [for (final l in course.lines) l.id]..shuffle(_rng);
        _queuePos = 0;
      } else {
        finished = true;
        notifyListeners();
        return;
      }
    }
    _loadLine(_queue[_queuePos]);
  }

  /// Time Trial countdown; called once per second by the UI.
  void tick() {
    if (mode != TrainingMode.timeTrial || finished) return;
    secondsLeft--;
    if (secondsLeft <= 0) {
      secondsLeft = 0;
      finished = true;
    }
    notifyListeners();
  }

  double get accuracy => studentMoves == 0
      ? 0
      : ((studentMoves - totalMistakes) / studentMoves).clamp(0, 1);
}
