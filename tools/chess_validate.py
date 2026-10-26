"""Reference chess engine + course validator.

The Flutter app ships a hand-written, dependency-free chess engine in
lib/core/chess/chess.dart.  This script is the Python twin of that engine:
same board layout, same move rules, same SAN grammar.  It exists so the move
generator can be verified with perft against known node counts and so every
opening line authored in lib/features/catalog/data/courses.dart is proven
legal before the app ever runs.

Run:  python3 tools/chess_validate.py
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

# Board: index 0 = a1 ... 63 = h8 (rank * 8 + file). White moves "up".
PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING = range(6)
KNIGHT_DELTAS = [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)]
KING_DELTAS = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
BISHOP_DIRS = [(-1, -1), (-1, 1), (1, -1), (1, 1)]
ROOK_DIRS = [(-1, 0), (1, 0), (0, -1), (0, 1)]


@dataclass(frozen=True)
class Piece:
    kind: int
    white: bool


@dataclass(frozen=True)
class Move:
    frm: int
    to: int
    promotion: int | None = None


@dataclass
class Position:
    board: list[Piece | None]
    white_to_move: bool = True
    wk: bool = True
    wq: bool = True
    bk: bool = True
    bq: bool = True
    ep: int | None = None

    @classmethod
    def initial(cls) -> "Position":
        back = [ROOK, KNIGHT, BISHOP, QUEEN, KING, BISHOP, KNIGHT, ROOK]
        board: list[Piece | None] = [None] * 64
        for f in range(8):
            board[f] = Piece(back[f], True)
            board[8 + f] = Piece(PAWN, True)
            board[48 + f] = Piece(PAWN, False)
            board[56 + f] = Piece(back[f], False)
        return cls(board)

    def copy(self) -> "Position":
        return Position(self.board.copy(), self.white_to_move,
                        self.wk, self.wq, self.bk, self.bq, self.ep)

    def king_square(self, white: bool) -> int:
        return next(i for i, p in enumerate(self.board)
                    if p and p.kind == KING and p.white == white)

    # -- attacks -----------------------------------------------------------
    def is_attacked(self, sq: int, by_white: bool) -> bool:
        r, f = divmod(sq, 8)
        pawn_dir = 1 if by_white else -1
        for df in (-1, 1):
            x = r - pawn_dir, f + df  # attacker sits one rank "behind"
            if 0 <= x[0] < 8 and 0 <= x[1] < 8:
                p = self.board[x[0] * 8 + x[1]]
                if p and p.white == by_white and p.kind == PAWN:
                    return True
        for dr, df in KNIGHT_DELTAS:
            rr, ff = r + dr, f + df
            if 0 <= rr < 8 and 0 <= ff < 8:
                p = self.board[rr * 8 + ff]
                if p and p.white == by_white and p.kind == KNIGHT:
                    return True
        for dr, df in KING_DELTAS:
            rr, ff = r + dr, f + df
            if 0 <= rr < 8 and 0 <= ff < 8:
                p = self.board[rr * 8 + ff]
                if p and p.white == by_white and p.kind == KING:
                    return True
        for dirs, kinds in ((BISHOP_DIRS, (BISHOP, QUEEN)), (ROOK_DIRS, (ROOK, QUEEN))):
            for dr, df in dirs:
                rr, ff = r + dr, f + df
                while 0 <= rr < 8 and 0 <= ff < 8:
                    p = self.board[rr * 8 + ff]
                    if p:
                        if p.white == by_white and p.kind in kinds:
                            return True
                        break
                    rr += dr
                    ff += df
        return False

    @property
    def in_check(self) -> bool:
        return self.is_attacked(self.king_square(self.white_to_move), not self.white_to_move)

    # -- move generation ---------------------------------------------------
    def _pseudo_moves(self) -> list[Move]:
        moves: list[Move] = []
        for sq, p in enumerate(self.board):
            if not p or p.white != self.white_to_move:
                continue
            r, f = divmod(sq, 8)
            if p.kind == PAWN:
                d = 1 if p.white else -1
                start_rank = 1 if p.white else 6
                promo_rank = 7 if p.white else 0
                one = sq + 8 * d
                if 0 <= one < 64 and self.board[one] is None:
                    self._add_pawn(moves, sq, one, r + d == promo_rank)
                    two = sq + 16 * d
                    if r == start_rank and self.board[two] is None:
                        moves.append(Move(sq, two))
                for df in (-1, 1):
                    ff = f + df
                    if not 0 <= ff < 8:
                        continue
                    cap = sq + 8 * d + df
                    if not 0 <= cap < 64:
                        continue
                    target = self.board[cap]
                    if cap == self.ep or (target and target.white != p.white and target.kind != KING):
                        self._add_pawn(moves, sq, cap, r + d == promo_rank)
            elif p.kind == KNIGHT:
                for dr, df in KNIGHT_DELTAS:
                    self._step(moves, p, sq, r + dr, f + df)
            elif p.kind == KING:
                for dr, df in KING_DELTAS:
                    self._step(moves, p, sq, r + dr, f + df)
                self._castling(moves, p)
            else:
                dirs = BISHOP_DIRS if p.kind == BISHOP else ROOK_DIRS if p.kind == ROOK else BISHOP_DIRS + ROOK_DIRS
                for dr, df in dirs:
                    rr, ff = r + dr, f + df
                    while 0 <= rr < 8 and 0 <= ff < 8:
                        to = rr * 8 + ff
                        target = self.board[to]
                        if target is None:
                            moves.append(Move(sq, to))
                        else:
                            if target.white != p.white and target.kind != KING:
                                moves.append(Move(sq, to))
                            break
                        rr += dr
                        ff += df
        return moves

    def _add_pawn(self, moves: list[Move], frm: int, to: int, promo: bool) -> None:
        if promo:
            for kind in (QUEEN, ROOK, BISHOP, KNIGHT):
                moves.append(Move(frm, to, kind))
        else:
            moves.append(Move(frm, to))

    def _step(self, moves: list[Move], p: Piece, frm: int, rr: int, ff: int) -> None:
        if 0 <= rr < 8 and 0 <= ff < 8:
            to = rr * 8 + ff
            target = self.board[to]
            if target is None or (target.white != p.white and target.kind != KING):
                moves.append(Move(frm, to))

    def _castling(self, moves: list[Move], p: Piece) -> None:
        if self.is_attacked(self.king_square(p.white), not p.white):
            return
        if p.white:
            if self.wk and self.board[5] is None and self.board[6] is None and not self.is_attacked(5, False) and not self.is_attacked(6, False):
                moves.append(Move(4, 6))
            if self.wq and self.board[3] is None and self.board[2] is None and self.board[1] is None and not self.is_attacked(3, False) and not self.is_attacked(2, False):
                moves.append(Move(4, 2))
        else:
            if self.bk and self.board[61] is None and self.board[62] is None and not self.is_attacked(61, True) and not self.is_attacked(62, True):
                moves.append(Move(60, 62))
            if self.bq and self.board[59] is None and self.board[58] is None and self.board[57] is None and not self.is_attacked(59, True) and not self.is_attacked(58, True):
                moves.append(Move(60, 58))

    def legal_moves(self, frm: int | None = None) -> list[Move]:
        out = []
        for m in self._pseudo_moves():
            if frm is not None and m.frm != frm:
                continue
            nxt = self.apply(m)
            if not nxt.is_attacked(nxt.king_square(self.white_to_move), not self.white_to_move):
                out.append(m)
        return out

    def apply(self, m: Move) -> "Position":
        p = self.board[m.frm]
        assert p
        nxt = self.copy()
        b = nxt.board
        b[m.frm] = None
        b[m.to] = Piece(m.promotion or p.kind, p.white) if p.kind == PAWN and m.promotion else p
        if p.kind == PAWN and m.to == self.ep:  # en passant capture
            b[m.to + (-8 if p.white else 8)] = None
        nxt.ep = None
        if p.kind == PAWN and abs(m.to - m.frm) == 16:
            nxt.ep = (m.frm + m.to) // 2
        if p.kind == KING:
            if p.white:
                nxt.wk = nxt.wq = False
                if m.to - m.frm == 2:
                    b[5], b[7] = Piece(ROOK, True), None
                if m.to - m.frm == -2:
                    b[3], b[0] = Piece(ROOK, True), None
            else:
                nxt.bk = nxt.bq = False
                if m.to - m.frm == 2:
                    b[61], b[63] = Piece(ROOK, False), None
                if m.to - m.frm == -2:
                    b[59], b[56] = Piece(ROOK, False), None
        # rook moves / captures remove rights
        for sq, rights in ((0, ("wq",)), (7, ("wk",)), (56, ("bq",)), (63, ("bk",))):
            if m.frm == sq or m.to == sq:
                setattr(nxt, rights[0], False)
        nxt.white_to_move = not self.white_to_move
        return nxt

    # -- SAN ---------------------------------------------------------------
    _SAN_RE = re.compile(
        r"^(?:(O-O(?:-O)?)|([NBRQK]?)([a-h])?([1-8])?(x)?([a-h][1-8])(=[NBRQK])?)([+#])?$"
    )

    def apply_san(self, san: str) -> "Position":
        m = self.san_to_move(san)
        return self.apply(m)

    def san_to_move(self, san: str) -> Move:
        clean = san.strip().replace("+", "").replace("#", "").replace("!", "").replace("?", "")
        mm = self._SAN_RE.match(clean)
        if not mm:
            raise ValueError(f"bad SAN: {san}")
        castle, piece_letter, df, dr, _capture, dest, promo, _suffix = mm.groups()
        if castle:
            target = 6 if self.white_to_move else 62
            if castle == "O-O-O":
                target = 2 if self.white_to_move else 58
            for m in self.legal_moves():
                if self.board[m.frm] and self.board[m.frm].kind == KING and m.to == target:
                    return m
            raise ValueError(f"illegal castle: {san}")
        to = (int(dest[1]) - 1) * 8 + ord(dest[0]) - 97
        kind = {"": PAWN, "N": KNIGHT, "B": BISHOP, "R": ROOK, "Q": QUEEN, "K": KING}[piece_letter]
        promo = {"Q": QUEEN, "R": ROOK, "B": BISHOP, "N": KNIGHT}[promo[1]] if promo else None
        candidates = [
            m for m in self.legal_moves()
            if m.to == to
            and self.board[m.frm].kind == kind
            and (df is None or chr(97 + m.frm % 8) == df)
            and (dr is None or str(m.frm // 8 + 1) == dr)
            and m.promotion == promo
        ]
        if len(candidates) != 1:
            raise ValueError(f"SAN {san} resolved to {len(candidates)} moves")
        return candidates[0]

    def to_san(self, m: Move) -> str:
        p = self.board[m.frm]
        if p.kind == KING and abs(m.to - m.frm) == 2:
            san = "O-O-O" if m.to % 8 == 2 else "O-O"
        else:
            san = ""
            if p.kind != PAWN:
                san += ["", "N", "B", "R", "Q", "K"][p.kind]
                same = [
                    x for x in self.legal_moves()
                    if x.to == m.to and self.board[x.frm].kind == p.kind and x.frm != m.frm
                ]
                if same:
                    same_file = any(x.frm % 8 == m.frm % 8 for x in same)
                    same_rank = any(x.frm // 8 == m.frm // 8 for x in same)
                    if not same_file:
                        san += chr(97 + m.frm % 8)
                    elif not same_rank:
                        san += str(m.frm // 8 + 1)
                    else:
                        san += chr(97 + m.frm % 8) + str(m.frm // 8 + 1)
            elif self.board[m.to] is not None or m.to == self.ep:
                san += chr(97 + m.frm % 8) + "x"
            if p.kind != PAWN and self.board[m.to] is not None:
                san += "x"
            san += chr(97 + m.to % 8) + str(m.to // 8 + 1)
            if m.promotion is not None:
                san += "=" + ["", "N", "B", "R", "Q", "K"][m.promotion]
        nxt = self.apply(m)
        if nxt.in_check:
            san += "#" if not nxt.legal_moves() else "+"
        return san


def parse_fen(fen: str) -> Position:
    rows, rest = fen.split(" ", 1)
    board: list[Piece | None] = [None] * 64
    for r, row in enumerate(rows.split("/")):
        f = 0
        for ch in row:
            if ch.isdigit():
                f += int(ch)
            else:
                kind = "pnbrqk".index(ch.lower())
                board[(7 - r) * 8 + f] = Piece(kind, ch.isupper())
                f += 1
    side, rights, ep = rest.split()[:3]
    pos = Position(board, side == "w",
                   "K" in rights, "Q" in rights, "k" in rights, "q" in rights,
                   None if ep == "-" else (int(ep[1]) - 1) * 8 + ord(ep[0]) - 97)
    return pos


def perft(pos: Position, depth: int) -> int:
    if depth == 0:
        return 1
    total = 0
    for m in pos.legal_moves():
        total += perft(pos.apply(m), depth - 1)
    return total


# --------------------------------------------------------------------------
# Course extraction + validation
# --------------------------------------------------------------------------

MOVE_RE = re.compile(r"'([^']+)'")
BLURB_RE = re.compile(r"(\d+):\s*'((?:[^'\\]|\\.)*)'")


def _balanced_blocks(text: str, keyword: str):
    """Yield the substring inside each `keyword(...)` call (paren matched)."""
    needle = keyword + "("
    i = 0
    while True:
        i = text.find(needle, i)
        if i < 0:
            return
        depth = 0
        for j in range(i + len(needle) - 1, len(text)):
            if text[j] == "(":
                depth += 1
            elif text[j] == ")":
                depth -= 1
                if depth == 0:
                    yield text[i + len(needle):j]
                    i = j + 1
                    break
        else:
            return


def _field(block: str, name: str) -> str:
    m = re.search(name + r":\s*'((?:[^'\\]|\\.)*)'", block)
    return m.group(1) if m else ""


def extract_courses(text: str):
    courses = []
    for block in _balanced_blocks(text, "Course"):
        side_m = re.search(r"side:\s*Side\.(white|black)", block)
        lines = []
        for lb in _balanced_blocks(block, "OpeningLine"):
            moves_raw = re.search(r"moves:\s*\[(.*?)\]", lb, re.S).group(1)
            blurbs_raw = re.search(r"blurbs:\s*\{(.*?)\}", lb, re.S)
            lines.append(dict(
                id=_field(lb, "id"),
                name=_field(lb, "name"),
                weight=int(re.search(r"weight:\s*(\d+)", lb).group(1)),
                moves=MOVE_RE.findall(moves_raw),
                blurbs={int(k): v for k, v in BLURB_RE.findall(blurbs_raw.group(1) if blurbs_raw else "")},
            ))
        courses.append(dict(
            id=_field(block, "id"),
            title=_field(block, "title"),
            side=side_m.group(1) if side_m else "white",
            lines=lines,
        ))
    return courses


def validate_course(course: dict) -> list[str]:
    errors = []
    white_side = course["side"] == "white"
    if len(course["lines"]) < 3:
        errors.append(f"{course['id']}: needs >= 3 lines")
    seen_paths: dict[tuple, str] = {}
    for line in course["lines"]:
        pos = Position.initial()
        path = []
        for ply, san in enumerate(line["moves"]):
            try:
                m = pos.san_to_move(san)
            except ValueError as e:
                errors.append(f"{course['id']}/{line['id']} ply {ply}: {e}")
                break
            if _norm(san) != _norm(pos.to_san(m)):
                errors.append(
                    f"{course['id']}/{line['id']} ply {ply}: non-canonical SAN "
                    f"'{san}' (engine emits '{pos.to_san(m)}')")
            mover_white = pos.white_to_move
            my_ply = mover_white == white_side
            # blurbs may only sit on our own plies
            if ply in line["blurbs"] and not my_ply:
                errors.append(f"{course['id']}/{line['id']} blurb at ply {ply} is not a student ply")
            path.append(pos.to_san(m))
            pos = pos.apply(m)
        else:
            if tuple(path) in seen_paths:
                errors.append(f"{course['id']}/{line['id']} duplicates {seen_paths[tuple(path)]}")
            seen_paths[tuple(path)] = line["id"]
            for key in line["blurbs"]:
                if key >= len(line["moves"]):
                    errors.append(f"{course['id']}/{line['id']} blurb index {key} out of range")
    # Lines may diverge on either side's move: student branches are alternative
    # repertoire choices, opponent branches carry the frequency weights.
    return errors


def simulate_perfect_run(course: dict, line: dict) -> list[str]:
    """Walk one line exactly the way SessionEngine does: opponent plies follow
    the target line, student plies verify the repertoire SAN stays legal and
    resolves uniquely. Returns the canonical SAN log."""
    pos = Position.initial()
    san_log: list[str] = []
    white_side = course["side"] == "white"
    for ply, san in enumerate(line["moves"]):
        student_ply = pos.white_to_move == white_side
        move = pos.san_to_move(san)
        if student_ply:
            # every sibling line at this prefix must offer a legal continuation
            siblings = [l for l in course["lines"]
                        if len(l["moves"]) > ply
                        and all(_norm(l["moves"][i]) == _norm(san_log[i])
                                for i in range(len(san_log)))]
            assert siblings, f"{course['id']}/{line['id']} ply {ply}: no sibling"
        canonical = pos.to_san(move)
        san_log.append(canonical)
        pos = pos.apply(move)
    return san_log


def _norm(san: str) -> str:
    return re.sub(r"[+#!?]", "", san)


def simulate_weighted_session(course: dict, seed: int) -> None:
    """Mirror of SessionEngine: opponent plies pick a weighted sibling line,
    student plies play the currently selected line's repertoire move. Runs
    every line in the queue and must always finish legally."""
    import random
    rng = random.Random(seed)
    for target in course["lines"]:
        pos = Position.initial()
        san_log: list[str] = []
        line = target
        ply = 0
        white_side = course["side"] == "white"
        while ply < len(line["moves"]):
            student_ply = pos.white_to_move == white_side
            if not student_ply:
                siblings = [l for l in course["lines"]
                            if len(l["moves"]) > ply
                            and all(_norm(l["moves"][i]) == _norm(san_log[i])
                                    for i in range(ply))]
                total = sum(l["weight"] for l in siblings)
                roll = rng.randrange(total)
                for cand in siblings:
                    roll -= cand["weight"]
                    if roll < 0:
                        line = cand
                        break
            move = pos.san_to_move(line["moves"][ply])
            san_log.append(pos.to_san(move))
            pos = pos.apply(move)
            ply += 1


def main() -> int:
    failures = []

    # 1. perft: starting position
    start = Position.initial()
    expected_start = [20, 400, 8902, 197281]
    for d, want in enumerate(expected_start, 1):
        got = perft(start, d)
        print(f"perft startpos d{d}: {got} (want {want})")
        if got != want:
            failures.append(f"startpos d{d}: {got} != {want}")

    # 2. perft: Kiwipete
    kiwi = parse_fen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
    for d, want in ((1, 48), (2, 2039), (3, 97862)):
        got = perft(kiwi, d)
        print(f"perft kiwipete d{d}: {got} (want {want})")
        if got != want:
            failures.append(f"kiwipete d{d}: {got} != {want}")

    # 2b. perft: position 3 (en passant / pins)
    pos3 = parse_fen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
    for d, want in ((1, 14), (2, 191), (3, 2812), (4, 43238)):
        got = perft(pos3, d)
        print(f"perft position3 d{d}: {got} (want {want})")
        if got != want:
            failures.append(f"position3 d{d}: {got} != {want}")

    # 2c. perft: position 6 (promotion-rich)
    pos6 = parse_fen("r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 11")
    for d, want in ((1, 46), (2, 2079), (3, 89890)):
        got = perft(pos6, d)
        print(f"perft position6 d{d}: {got} (want {want})")
        if got != want:
            failures.append(f"position6 d{d}: {got} != {want}")

    # 3. SAN round trip through a real opening
    pos = Position.initial()
    italian = "e4 e5 Nf3 Nc6 Bc4 Bc5 c3 Nf6 d3 d6 O-O O-O".split()
    for san in italian:
        m = pos.san_to_move(san)
        if pos.to_san(m) != san:
            failures.append(f"SAN round trip failed: {san} -> {pos.to_san(m)}")
        pos = pos.apply(m)
    print("SAN round trip Italian Game: OK")

    # 4. every authored course line is legal and structurally sound
    courses_file = Path(__file__).resolve().parents[1] / "lib/features/catalog/data/courses.dart"
    if not courses_file.exists():
        print("courses.dart not present yet, skipping course validation")
        courses = []
    else:
        courses = extract_courses(courses_file.read_text())
    print(f"extracted {len(courses)} courses, {sum(len(c['lines']) for c in courses)} lines")
    if len(courses) < 4:
        failures.append("expected >= 4 courses")
    for c in courses:
        errs = validate_course(c)
        for e in errs:
            print("  FAIL", e)
        failures.extend(errs)
        weights = sorted({l["weight"] for l in c["lines"]})
        print(f"  {c['id']}: {len(c['lines'])} lines, weights {weights}")
        for line in c["lines"]:
            try:
                simulate_perfect_run(c, line)
            except (ValueError, AssertionError) as e:
                failures.append(f"session sim {c['id']}/{line['id']}: {e}")
        for seed in range(10):
            try:
                simulate_weighted_session(c, seed)
            except (ValueError, AssertionError) as e:
                failures.append(f"weighted sim {c['id']} seed {seed}: {e}")
    print("session simulation over all lines: OK" if not any(
        f.startswith("session sim") for f in failures) else "session simulation FAILED")

    # 5. SRS ladder parity check (mirror of Srs.grade in srs.dart)
    def grade(p, passed, mistakes):
        p = dict(p or {"reps": 0, "ease": 2.5, "lapses": 0})
        q = 1 if not passed else (5 if mistakes == 0 else 3 if mistakes == 1 else 2)
        if q < 3:
            p["reps"] = 0; p["lapses"] += 1
            p["ease"] = max(1.3, p["ease"] - 0.2)
            return 0, p
        p["reps"] += 1
        interval = 1 if p["reps"] == 1 else 3 if p["reps"] == 2 else (p["reps"] - 1) * 2
        return interval, p

    state = None
    intervals = []
    for _ in range(4):
        iv, state = grade(state, True, 0)
        intervals.append(iv)
    if intervals != [1, 3, 4, 6]:
        failures.append(f"SRS interval ladder wrong: {intervals}")
    iv, state = grade(state, False, 3)
    if iv != 0 or state["reps"] != 0 or state["lapses"] != 1:
        failures.append("SRS lapse reset wrong")
    print(f"SRS ladder {intervals} + lapse reset: OK" if intervals == [1, 3, 4, 6] else "SRS FAILED")

    if failures:
        print(f"\n{len(failures)} FAILURE(S)")
        return 1
    print("\nALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
