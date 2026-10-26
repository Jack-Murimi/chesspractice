/// Interactive chess board rendered with CustomPainter — no image assets,
/// no chess packages. Unicode glyphs stand in for piece art.
library;

import 'package:flutter/material.dart';

import '../../../../core/chess/chess.dart';

class ChessBoard extends StatelessWidget {
  const ChessBoard({
    super.key,
    required this.position,
    required this.onSquare,
    this.selected,
    this.legalMoves = const [],
    this.lastFrom,
    this.lastTo,
    this.hintFrom,
    this.hintTo,
    this.flipped = false,
  });

  final ChessPosition position;
  final ValueChanged<int> onSquare;
  final int? selected;
  final List<Move> legalMoves;
  final int? lastFrom;
  final int? lastTo;
  final int? hintFrom;
  final int? hintTo;
  final bool flipped;

  static const _light = Color(0xFFEBECD0);
  static const _dark = Color(0xFF739552);
  static const _glyphs = ['♟', '♞', '♝', '♜', '♛', '♚'];

  int _squareAt(int row, int col) =>
      flipped ? row * 8 + (7 - col) : (7 - row) * 8 + col;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Chess board, ${flipped ? 'black' : 'white'} at the bottom',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sq = constraints.maxWidth / 8;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final col = (d.localPosition.dx / sq).floor().clamp(0, 7);
              final row = (d.localPosition.dy / sq).floor().clamp(0, 7);
              onSquare(_squareAt(row, col));
            },
            child: CustomPaint(
              size: Size.square(constraints.maxWidth),
              painter: _BoardPainter(this, sq),
            ),
          );
        },
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.widget, this.sq);

  final ChessBoard widget;
  final double sq;

  @override
  void paint(Canvas canvas, Size size) {
    final pos = widget.position;
    final fill = Paint();
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final square = widget._squareAt(row, col);
        final rect = Rect.fromLTWH(col * sq, row * sq, sq, sq);
        fill.color = (row + col) % 2 == 0 ? ChessBoard._light : ChessBoard._dark;
        canvas.drawRect(rect, fill);

        if (square == widget.lastFrom || square == widget.lastTo) {
          canvas.drawRect(rect, Paint()..color = const Color(0x66F6E05E));
        }
        if (square == widget.selected) {
          canvas.drawRect(rect, Paint()..color = const Color(0x99F59E0B));
        }
        if (square == widget.hintFrom || square == widget.hintTo) {
          canvas.drawRect(rect, Paint()..color = const Color(0x887C4DFF));
        }
        final piece = pos.board[square];
        if (piece != null) _paintPiece(canvas, rect, piece);
      }
    }

    // check glow on the side-to-move king
    final kingSq = pos.kingSquare(pos.whiteToMove);
    if (pos.inCheck) {
      final r = (kingSq % 8);
      final row = widget.flipped ? 7 - kingSq ~/ 8 : kingSq ~/ 8;
      final col = widget.flipped ? 7 - r : r;
      final center = Offset((col + 0.5) * sq, (row + 0.5) * sq);
      canvas.drawCircle(
        center,
        sq * 0.42,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0xCCEF5350), Color(0x00EF5350)])
              .createShader(Rect.fromCircle(center: center, radius: sq * 0.42)),
      );
    }

    // legal-target markers
    for (final m in widget.legalMoves) {
      final row = widget.flipped ? 7 - m.to ~/ 8 : m.to ~/ 8;
      final col = widget.flipped ? 7 - m.to % 8 : m.to % 8;
      final center = Offset((col + 0.5) * sq, (row + 0.5) * sq);
      final occupied = pos.board[m.to] != null || m.to == pos.ep;
      final marker = Paint()..color = const Color(0x55263238);
      if (occupied) {
        marker.style = PaintingStyle.stroke;
        marker.strokeWidth = sq * 0.06;
        canvas.drawCircle(center, sq * 0.44, marker);
      } else {
        canvas.drawCircle(center, sq * 0.16, marker);
      }
    }
  }

  void _paintPiece(Canvas canvas, Rect rect, Piece piece) {
    final glyph = ChessBoard._glyphs[piece.kind.index];
    final fontSize = sq * 0.74;
    void paintWith(Paint? foreground, Color? color) {
      final painter = TextPainter(
        text: TextSpan(
          text: glyph,
          style: TextStyle(
            fontSize: fontSize,
            height: 1,
            color: color,
            foreground: foreground,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Alignment.center.inscribe(painter.size, rect).topLeft,
      );
    }

    if (piece.isWhite) {
      // outline first so the white-filled glyph reads on light squares
      paintWith(
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = fontSize * 0.045
          ..color = const Color(0xFF263238),
        null,
      );
      paintWith(null, Colors.white);
    } else {
      paintWith(null, const Color(0xFF1B1B1B));
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) =>
      old.widget != widget || old.sq != sq;
}
