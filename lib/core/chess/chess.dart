/// Minimal, dependency-free chess engine: board state, legal move generation
/// and SAN parsing/emission. Only what an opening trainer needs (no draw
/// claims, no PGN, no engine evaluation).
///
/// Board indexing: 0 = a1 ... 63 = h8 (rank * 8 + file), White moves toward
/// higher indices. The Python twin in `tools/chess_validate.py` mirrors this
/// file one-to-one and is verified with perft against reference node counts.
library;

enum PieceKind { pawn, knight, bishop, rook, queen, king }

class Piece {
  const Piece(this.kind, this.isWhite);
  final PieceKind kind;
  final bool isWhite;

  @override
  bool operator ==(Object other) =>
      other is Piece && other.kind == kind && other.isWhite == isWhite;

  @override
  int get hashCode => Object.hash(kind, isWhite);
}

class Move {
  const Move(this.from, this.to, {this.promotion});
  final int from;
  final int to;
  final PieceKind? promotion;
}

class ChessPosition {
  ChessPosition(this.board,
      {this.whiteToMove = true,
      this.wk = true,
      this.wq = true,
      this.bk = true,
      this.bq = true,
      this.ep});

  factory ChessPosition.initial() {
    const back = [
      PieceKind.rook, PieceKind.knight, PieceKind.bishop, PieceKind.queen,
      PieceKind.king, PieceKind.bishop, PieceKind.knight, PieceKind.rook,
    ];
    final board = List<Piece?>.filled(64, null);
    for (var f = 0; f < 8; f++) {
      board[f] = Piece(back[f], true);
      board[8 + f] = Piece(PieceKind.pawn, true);
      board[48 + f] = Piece(PieceKind.pawn, false);
      board[56 + f] = Piece(back[f], false);
    }
    return ChessPosition(board);
  }

  factory ChessPosition.fromFen(String fen) {
    final parts = fen.split(RegExp(r'\s+'));
    final board = List<Piece?>.filled(64, null);
    final rows = parts[0].split('/');
    for (var r = 0; r < 8; r++) {
      var f = 0;
      for (final ch in rows[r].split('')) {
        if (RegExp(r'[1-8]').hasMatch(ch)) {
          f += int.parse(ch);
        } else {
          final kind = PieceKind.values['pnbrqk'.indexOf(ch.toLowerCase())];
          board[(7 - r) * 8 + f] = Piece(kind, ch == ch.toUpperCase());
          f++;
        }
      }
    }
    final side = parts[1];
    final rights = parts[2];
    final epPart = parts[3];
    return ChessPosition(
      board,
      whiteToMove: side == 'w',
      wk: rights.contains('K'),
      wq: rights.contains('Q'),
      bk: rights.contains('k'),
      bq: rights.contains('q'),
      ep: epPart == '-'
          ? null
          : (int.parse(epPart[1]) - 1) * 8 + epPart.codeUnitAt(0) - 97,
    );
  }

  final List<Piece?> board;
  bool whiteToMove;
  bool wk, wq, bk, bq;
  int? ep;

  static const _knightDeltas = [
    [-2, -1], [-2, 1], [-1, -2], [-1, 2],
    [1, -2], [1, 2], [2, -1], [2, 1],
  ];
  static const _kingDeltas = [
    [-1, -1], [-1, 0], [-1, 1], [0, -1],
    [0, 1], [1, -1], [1, 0], [1, 1],
  ];
  static const _bishopDirs = [
    [-1, -1], [-1, 1], [1, -1], [1, 1],
  ];
  static const _rookDirs = [
    [-1, 0], [1, 0], [0, -1], [0, 1],
  ];

  ChessPosition copy() => ChessPosition(board.toList(),
      whiteToMove: whiteToMove, wk: wk, wq: wq, bk: bk, bq: bq, ep: ep);

  int kingSquare(bool white) {
    for (var i = 0; i < 64; i++) {
      final p = board[i];
      if (p != null && p.kind == PieceKind.king && p.isWhite == white) {
        return i;
      }
    }
    throw StateError('king missing');
  }

  bool isAttacked(int sq, bool byWhite) {
    final r = sq ~/ 8, f = sq % 8;
    final pawnDir = byWhite ? 1 : -1;
    for (final df in [-1, 1]) {
      final rr = r - pawnDir, ff = f + df;
      if (rr >= 0 && rr < 8 && ff >= 0 && ff < 8) {
        final p = board[rr * 8 + ff];
        if (p != null && p.isWhite == byWhite && p.kind == PieceKind.pawn) {
          return true;
        }
      }
    }
    for (final d in _knightDeltas) {
      final rr = r + d[0], ff = f + d[1];
      if (rr >= 0 && rr < 8 && ff >= 0 && ff < 8) {
        final p = board[rr * 8 + ff];
        if (p != null && p.isWhite == byWhite && p.kind == PieceKind.knight) {
          return true;
        }
      }
    }
    for (final d in _kingDeltas) {
      final rr = r + d[0], ff = f + d[1];
      if (rr >= 0 && rr < 8 && ff >= 0 && ff < 8) {
        final p = board[rr * 8 + ff];
        if (p != null && p.isWhite == byWhite && p.kind == PieceKind.king) {
          return true;
        }
      }
    }
    for (final entry in [
      [_bishopDirs, [PieceKind.bishop, PieceKind.queen]],
      [_rookDirs, [PieceKind.rook, PieceKind.queen]],
    ]) {
      for (final d in entry[0] as List<List<int>>) {
        var rr = r + d[0], ff = f + d[1];
        while (rr >= 0 && rr < 8 && ff >= 0 && ff < 8) {
          final p = board[rr * 8 + ff];
          if (p != null) {
            if (p.isWhite == byWhite &&
                (entry[1] as List<PieceKind>).contains(p.kind)) {
              return true;
            }
            break;
          }
          rr += d[0];
          ff += d[1];
        }
      }
    }
    return false;
  }

  bool get inCheck => isAttacked(kingSquare(whiteToMove), !whiteToMove);

  // -- move generation -----------------------------------------------------

  List<Move> _pseudoMoves() {
    final moves = <Move>[];
    for (var sq = 0; sq < 64; sq++) {
      final p = board[sq];
      if (p == null || p.isWhite != whiteToMove) continue;
      final r = sq ~/ 8, f = sq % 8;
      switch (p.kind) {
        case PieceKind.pawn:
          final d = p.isWhite ? 1 : -1;
          final startRank = p.isWhite ? 1 : 6;
          final promoRank = p.isWhite ? 7 : 0;
          final one = sq + 8 * d;
          if (one >= 0 && one < 64 && board[one] == null) {
            _addPawn(moves, sq, one, r + d == promoRank);
            final two = sq + 16 * d;
            if (r == startRank && board[two] == null) {
              moves.add(Move(sq, two));
            }
          }
          for (final df in [-1, 1]) {
            final ff = f + df;
            if (ff < 0 || ff > 7) continue;
            final cap = sq + 8 * d + df;
            if (cap < 0 || cap > 63) continue;
            final target = board[cap];
            if (cap == ep ||
                (target != null &&
                    target.isWhite != p.isWhite &&
                    target.kind != PieceKind.king)) {
              _addPawn(moves, sq, cap, r + d == promoRank);
            }
          }
        case PieceKind.knight:
          for (final d in _knightDeltas) {
            _step(moves, p, sq, r + d[0], f + d[1]);
          }
        case PieceKind.king:
          for (final d in _kingDeltas) {
            _step(moves, p, sq, r + d[0], f + d[1]);
          }
          _castling(moves, p);
        case PieceKind.bishop:
          _slides(moves, p, sq, _bishopDirs);
        case PieceKind.rook:
          _slides(moves, p, sq, _rookDirs);
        case PieceKind.queen:
          _slides(moves, p, sq, [..._bishopDirs, ..._rookDirs]);
      }
    }
    return moves;
  }

  void _addPawn(List<Move> moves, int from, int to, bool promo) {
    if (promo) {
      for (final kind in [
        PieceKind.queen, PieceKind.rook, PieceKind.bishop, PieceKind.knight,
      ]) {
        moves.add(Move(from, to, promotion: kind));
      }
    } else {
      moves.add(Move(from, to));
    }
  }

  void _step(List<Move> moves, Piece p, int from, int rr, int ff) {
    if (rr < 0 || rr > 7 || ff < 0 || ff > 7) return;
    final to = rr * 8 + ff;
    final target = board[to];
    if (target == null ||
        (target.isWhite != p.isWhite && target.kind != PieceKind.king)) {
      moves.add(Move(from, to));
    }
  }

  void _slides(List<Move> moves, Piece p, int sq, List<List<int>> dirs) {
    final r = sq ~/ 8, f = sq % 8;
    for (final d in dirs) {
      var rr = r + d[0], ff = f + d[1];
      while (rr >= 0 && rr < 8 && ff >= 0 && ff < 8) {
        final to = rr * 8 + ff;
        final target = board[to];
        if (target == null) {
          moves.add(Move(sq, to));
        } else {
          if (target.isWhite != p.isWhite && target.kind != PieceKind.king) {
            moves.add(Move(sq, to));
          }
          break;
        }
        rr += d[0];
        ff += d[1];
      }
    }
  }

  void _castling(List<Move> moves, Piece king) {
    if (isAttacked(kingSquare(king.isWhite), !king.isWhite)) return;
    if (king.isWhite) {
      if (wk && board[5] == null && board[6] == null &&
          !isAttacked(5, false) && !isAttacked(6, false)) {
        moves.add(const Move(4, 6));
      }
      if (wq && board[3] == null && board[2] == null && board[1] == null &&
          !isAttacked(3, false) && !isAttacked(2, false)) {
        moves.add(const Move(4, 2));
      }
    } else {
      if (bk && board[61] == null && board[62] == null &&
          !isAttacked(61, true) && !isAttacked(62, true)) {
        moves.add(const Move(60, 62));
      }
      if (bq && board[59] == null && board[58] == null && board[57] == null &&
          !isAttacked(59, true) && !isAttacked(58, true)) {
        moves.add(const Move(60, 58));
      }
    }
  }

  List<Move> legalMoves({int? from}) {
    final result = <Move>[];
    for (final m in _pseudoMoves()) {
      if (from != null && m.from != from) continue;
      final next = apply(m);
      if (!next.isAttacked(next.kingSquare(whiteToMove), !whiteToMove)) {
        result.add(m);
      }
    }
    return result;
  }

  ChessPosition apply(Move m) {
    final p = board[m.from]!;
    final next = copy();
    final b = next.board;
    b[m.from] = null;
    if (p.kind == PieceKind.pawn && m.promotion != null) {
      b[m.to] = Piece(m.promotion!, p.isWhite);
    } else {
      b[m.to] = p;
    }
    if (p.kind == PieceKind.pawn && m.to == ep) {
      b[m.to + (p.isWhite ? -8 : 8)] = null;
    }
    next.ep = null;
    if (p.kind == PieceKind.pawn && (m.to - m.from).abs() == 16) {
      next.ep = (m.from + m.to) ~/ 2;
    }
    if (p.kind == PieceKind.king) {
      if (p.isWhite) {
        next.wk = next.wq = false;
        if (m.to - m.from == 2) {
          b[5] = const Piece(PieceKind.rook, true);
          b[7] = null;
        }
        if (m.to - m.from == -2) {
          b[3] = const Piece(PieceKind.rook, true);
          b[0] = null;
        }
      } else {
        next.bk = next.bq = false;
        if (m.to - m.from == 2) {
          b[61] = const Piece(PieceKind.rook, false);
          b[63] = null;
        }
        if (m.to - m.from == -2) {
          b[59] = const Piece(PieceKind.rook, false);
          b[56] = null;
        }
      }
    }
    const rights = {0: 'wq', 7: 'wk', 56: 'bq', 63: 'bk'};
    final flag = rights[m.from] ?? rights[m.to];
    if (flag != null) {
      switch (flag) {
        case 'wk': next.wk = false;
        case 'wq': next.wq = false;
        case 'bk': next.bk = false;
        case 'bq': next.bq = false;
      }
    }
    next.whiteToMove = !whiteToMove;
    return next;
  }

  // -- SAN -----------------------------------------------------------------

  static final _sanRe = RegExp(
      r'^(?:(O-O(?:-O)?)|([NBRQK]?)([a-h])?([1-8])?(x)?([a-h][1-8])(=[NBRQK])?)([+#])?$');
  static const _kindByLetter = {
    '': PieceKind.pawn, 'N': PieceKind.knight, 'B': PieceKind.bishop,
    'R': PieceKind.rook, 'Q': PieceKind.queen, 'K': PieceKind.king,
  };
  static const _letterByKind = ['', 'N', 'B', 'R', 'Q', 'K'];

  Move sanToMove(String san) {
    final clean = san.replaceAll(RegExp(r'[+#!?]'), '');
    final mm = _sanRe.firstMatch(clean);
    if (mm == null) throw ArgumentError('bad SAN: $san');
    final castle = mm.group(1);
    if (castle != null) {
      final target = castle == 'O-O-O'
          ? (whiteToMove ? 2 : 58)
          : (whiteToMove ? 6 : 62);
      for (final m in legalMoves()) {
        final p = board[m.from];
        if (p != null && p.kind == PieceKind.king && m.to == target) return m;
      }
      throw ArgumentError('illegal castle: $san');
    }
    // groups: 1 castle, 2 piece, 3 file, 4 rank, 5 capture-x,
    // 6 destination, 7 promotion, 8 check suffix
    final dest = mm.group(6)!;
    final to = (int.parse(dest[1]) - 1) * 8 + dest.codeUnitAt(0) - 97;
    final kind = _kindByLetter[mm.group(2)!]!;
    final promoLetter = mm.group(7);
    final promo = promoLetter == null
        ? null
        : _kindByLetter[promoLetter.substring(1)];
    final df = mm.group(3);
    final dr = mm.group(4);
    final candidates = legalMoves().where((m) {
      final p = board[m.from]!;
      return m.to == to &&
          p.kind == kind &&
          (df == null || m.from % 8 == df.codeUnitAt(0) - 97) &&
          (dr == null || m.from ~/ 8 == int.parse(dr) - 1) &&
          m.promotion == promo;
    }).toList();
    if (candidates.length != 1) {
      throw ArgumentError('SAN $san resolved to ${candidates.length} moves');
    }
    return candidates.single;
  }

  ChessPosition applySan(String san) => apply(sanToMove(san));

  String toSan(Move m) {
    final p = board[m.from]!;
    String san;
    if (p.kind == PieceKind.king && (m.to - m.from).abs() == 2) {
      san = m.to % 8 == 2 ? 'O-O-O' : 'O-O';
    } else {
      san = _letterByKind[p.kind.index];
      if (p.kind != PieceKind.pawn) {
        final same = legalMoves().where((x) =>
            x.to == m.to &&
            board[x.from]!.kind == p.kind &&
            x.from != m.from);
        if (same.isNotEmpty) {
          final sameFile = same.any((x) => x.from % 8 == m.from % 8);
          final sameRank = same.any((x) => x.from ~/ 8 == m.from ~/ 8);
          final fileChar = String.fromCharCode(97 + m.from % 8);
          final rankChar = (m.from ~/ 8 + 1).toString();
          // File alone distinguishes unless a twin shares the file; then
          // rank is required; both only when file and rank each have a twin.
          san += !sameFile
              ? fileChar
              : !sameRank
                  ? rankChar
                  : fileChar + rankChar;
        }
      } else if (board[m.to] != null || m.to == ep) {
        san += '${String.fromCharCode(97 + m.from % 8)}x';
      }
      if (p.kind != PieceKind.pawn && board[m.to] != null) san += 'x';
      san += String.fromCharCode(97 + m.to % 8) + (m.to ~/ 8 + 1).toString();
      if (m.promotion != null) san += '=${_letterByKind[m.promotion!.index]}';
    }
    final next = apply(m);
    if (next.inCheck) san += next.legalMoves().isEmpty ? '#' : '+';
    return san;
  }
}
