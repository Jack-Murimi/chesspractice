import 'package:chess_practice/core/chess/chess.dart';
import 'package:flutter_test/flutter_test.dart';

int perft(ChessPosition pos, int depth) {
  if (depth == 0) return 1;
  var total = 0;
  for (final m in pos.legalMoves()) {
    total += perft(pos.apply(m), depth - 1);
  }
  return total;
}

void main() {
  test('perft starting position', () {
    final pos = ChessPosition.initial();
    expect(perft(pos, 1), 20);
    expect(perft(pos, 2), 400);
    expect(perft(pos, 3), 8902);
  });

  test('perft Kiwipete (castling, pins, en passant)', () {
    final pos = ChessPosition.fromFen(
        'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1');
    expect(perft(pos, 1), 48);
    expect(perft(pos, 2), 2039);
  });

  test('perft position 3 (pins / en passant)', () {
    final pos = ChessPosition.fromFen(
        '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1');
    expect(perft(pos, 1), 14);
    expect(perft(pos, 2), 191);
  });

  test('perft position 6 (promotion-rich)', () {
    final pos = ChessPosition.fromFen(
        'r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 11');
    expect(perft(pos, 1), 46);
    expect(perft(pos, 2), 2079);
  });

  test('SAN round trip and disambiguation', () {
    var pos = ChessPosition.initial();
    for (final san in ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5', 'c3', 'Nf6']) {
      final move = pos.sanToMove(san);
      expect(pos.toSan(move), san);
      pos = pos.apply(move);
    }
  });

  test('SAN rank disambiguation when knights share a file', () {
    // Caro-Kann 3.Nd2 line reaches N1f3: knights on g1 and g5 both hit f3.
    var pos = ChessPosition.initial();
    const seq = [
      'e4', 'c6', 'd4', 'd5', 'Nd2', 'dxe4', 'Nxe4', 'Nd7', 'Bc4', 'Ngf6',
      'Ng5', 'e6',
    ];
    for (final san in seq) {
      pos = pos.applySan(san);
    }
    final move = pos.sanToMove('N1f3');
    expect(pos.toSan(move), 'N1f3');
  });

  test('castling updates rook and rights', () {
    var pos = ChessPosition.initial();
    for (final san in ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5', 'O-O']) {
      pos = pos.applySan(san);
    }
    expect(pos.board[7], isNull); // h1 rook moved to f1
    expect(pos.board[5]?.kind, PieceKind.rook);
    expect(pos.wk, isFalse); // castling rights consumed
  });
}
