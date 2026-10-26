/// Catalog domain: a course is a repertoire for one side made of named lines.
enum Side { white, black }

class OpeningLine {
  const OpeningLine({
    required this.id,
    required this.name,
    required this.weight,
    required this.moves,
    this.blurbs = const {},
  });

  /// Stable id used as the progress-storage key.
  final String id;

  /// Human label, e.g. "Main line vs ...Nf6".
  final String name;

  /// Relative real-game frequency used when the opponent chooses a branch.
  /// Higher = the reply humans actually play more often.
  final int weight;

  /// Full SAN sequence from the starting position, both sides included.
  final List<String> moves;

  /// Coach note for a ply (0-based). Allowed on student plies only.
  final Map<int, String> blurbs;
}

class Course {
  const Course({
    required this.id,
    required this.title,
    required this.author,
    required this.emoji,
    required this.side,
    required this.description,
    required this.lines,
  });

  final String id;
  final String title;
  final String author;
  final String emoji;
  final Side side;
  final String description;
  final List<OpeningLine> lines;

  OpeningLine lineById(String id) => lines.firstWhere((l) => l.id == id);
}
