/// Point du tableau, en unités du tableau (pixels logiques au zoom 1).
final class BoardPoint {
  const BoardPoint(this.x, this.y);

  final double x;
  final double y;

  BoardPoint translate(double dx, double dy) => BoardPoint(x + dx, y + dy);

  @override
  bool operator ==(Object other) =>
      other is BoardPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'BoardPoint($x, $y)';
}

/// Rectangle du tableau (région d'un nœud, carte d'une connaissance), en
/// unités du tableau.
final class BoardRect {
  const BoardRect(this.x, this.y, this.width, this.height);

  static BoardRect at(BoardPoint p, double width, double height) =>
      BoardRect(p.x, p.y, width, height);

  final double x;
  final double y;
  final double width;
  final double height;

  double get right => x + width;
  double get bottom => y + height;
  BoardPoint get topLeft => BoardPoint(x, y);
  double get area => width * height;

  BoardRect translate(double dx, double dy) =>
      BoardRect(x + dx, y + dy, width, height);

  /// Agrandi de [margin] de chaque côté.
  BoardRect inflate(double margin) => BoardRect(
    x - margin,
    y - margin,
    width + 2 * margin,
    height + 2 * margin,
  );

  /// Intersection d'intérieur non vide (des bords communs ne comptent pas).
  bool overlaps(BoardRect other) =>
      x < other.right &&
      other.x < right &&
      y < other.bottom &&
      other.y < bottom;

  /// [other] entièrement dedans (bords compris).
  bool contains(BoardRect other) =>
      other.x >= x &&
      other.y >= y &&
      other.right <= right &&
      other.bottom <= bottom;

  bool containsPoint(BoardPoint p) =>
      p.x >= x && p.y >= y && p.x <= right && p.y <= bottom;

  /// Plus petit rectangle contenant les deux.
  BoardRect union(BoardRect other) {
    final left = x < other.x ? x : other.x;
    final top = y < other.y ? y : other.y;
    final r = right > other.right ? right : other.right;
    final b = bottom > other.bottom ? bottom : other.bottom;
    return BoardRect(left, top, r - left, b - top);
  }

  @override
  bool operator ==(Object other) =>
      other is BoardRect &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'BoardRect($x, $y, $width × $height)';
}
