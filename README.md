# Chess Practice — opening reps trainer

A Flutter app that teaches chess openings the way [chessreps.com](https://www.chessreps.com)
does: **play the moves of a real repertoire against the replies humans actually
make, repeat them on a spaced schedule, and turn recall into instinct.**

Zero third-party packages — the chess engine, SRS scheduler, persistence and
board rendering are all built on the Flutter SDK and Dart core libraries.

## How chessreps works (research summary)

Reverse-engineered from chessreps' public site and app listing:

- **Courses are repertoires, not theory dumps.** Each course (e.g. Caro-Kann,
  40 lines) is a tree of named lines. Every move carries a short, witty coach
  note ("tweet-sized blurbs") explaining *why*, not just *what*.
- **Train the replies real humans play.** Opponent branches are weighted by
  how often they occur in millions of real games — you drill hope-chess moves,
  not engine-only sidelines.
- **Four training modes**, each a stage of memory formation:
  1. **Learn** — hints + coach notes; mistakes are corrected, not punished.
  2. **Practice** — no hints, pure recall of lines already learned.
  3. **Drill** — how many lines can you nail in a row under a red spotlight.
  4. **Time Trial** — 60 seconds; correct moves buy more clock.
- **"Reps" = spaced repetition.** Lines you miss come back sooner; solid
  lines return on a growing interval ladder until recall is automatic.
- **Progress as a game:** mastery per course, XP, daily streaks.

## What this app builds

| chessreps concept | This app |
| --- | --- |
| Opening courses with named lines | 4 hand-authored courses, 19 verified lines (London, Italian, Sicilian, Caro-Kann) |
| Real-game opponent branches | Weighted sibling-line selection (`OpeningLine.weight`) |
| Tweet-sized move blurbs | `blurbs` map on every line, shown in Learn mode and on hints |
| Learn / Practice / Drill / Time Trial | Same four modes in `SessionEngine`, one engine, mode-driven rules |
| Spaced "Reps" | SM-2-style scheduler in `Srs.grade` (1 → 3 → 4 → 6+ day ladder, lapse resets) |
| Mastery, XP, streak | `ProgressController` with per-line mastery, XP and daily streak |
| Persistence | JSON via native conditional imports: `localStorage` on web, home-directory file otherwise |

Deliberately **not** built (YAGNI — no backend, no subscription, no speculative
needs): leaderboards, accounts, Puzzles mode, PGN import, course creator,
cloud sync, analytics. Each can be added as its own feature folder later.

## Feature-first architecture

```
lib/
  main.dart                      entry point, loads saved progress
  app.dart                       MaterialApp + bottom-nav shell
  core/
    chess/chess.dart             dependency-free engine: movegen, SAN, FEN, castling/en passant
    storage/                     ProgressStore + conditional web/io implementations
    theme.dart                   Material 3 theme + per-mode identity colors
  features/
    catalog/                     courses domain + authored data + catalog/detail screens
      data/courses.dart
      domain/course.dart
      presentation/
    training/                    session engine + board widget + training screen
      domain/session_engine.dart
      presentation/
    progress/                    SRS, progress controller, stats screen
      domain/srs.dart
      domain/progress_controller.dart
      presentation/
test/                            flutter test suites (engine perft, SRS, sessions)
tools/chess_validate.py         Python twin engine: perft proofs + course legality gates
```

State management is plain `ChangeNotifier` + `ListenableBuilder`; navigation is
Navigator 1.0. No package is pulled in for what the SDK already does.

## Ponytail / YAGNI decisions

The Ponytail ladder (does it need to exist? → reuse → stdlib → platform
feature → installed dependency → one-liner → minimum new code) was applied
throughout:

- **No chess package** — the engine is ~450 lines and provably correct (below).
- **No storage plugin** — `dart:io` file / `dart:js_interop` localStorage chosen
  by a native conditional import, ~60 lines total.
- **No state-management package** — `ChangeNotifier` already ships with Flutter.
- **No image/font assets** — the board is a `CustomPainter` using Unicode
  piece glyphs.
- Protected, not cut: input validation (SAN errors, trust boundary on stored
  JSON), error handling (corrupt save → fresh start, never a crash),
  accessibility (`Semantics` on the board).

## Correctness: how the engine is verified without trusting it

`tools/chess_validate.py` is a line-for-line Python twin of the Dart engine.
It runs the standard **perft** node-count proofs (start position, Kiwipete,
the en-passant/pin and promotion reference positions), canonical-SAN
round-trips, then parses `courses.dart` and proves **every authored line is
legal, canonically notated, and session-simulable** with weighted opponent
picks across 10 seeds:

```bash
python3 tools/chess_validate.py     # ALL CHECKS PASSED
```

The same guarantees are expressed as Dart tests for `flutter test`:

```bash
flutter pub get
flutter test
flutter run          # or: flutter run -d chrome / -d windows / -d macos / -d linux
```

## Adding a course

Add a `Course(...)` entry to `lib/features/catalog/data/courses.dart` with
`OpeningLine`s (full SAN from the start position, branch weights, blurbs on
your own plies), then run `python3 tools/chess_validate.py` — it fails loudly
on any illegal or non-canonical move, mis-placed blurb, or broken branch.
