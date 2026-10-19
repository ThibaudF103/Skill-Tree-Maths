import 'dart:convert';
import 'dart:math' as math;

/// Point d'un trait : position dans la page (largeur [InkDrawing.pageWidth]) et
/// pression du stylet entre 0 et 1 (0,5 sans capteur de pression).
typedef InkPoint = ({double x, double y, double pressure});

/// Outil d'un trait.
enum InkTool {
  /// Stylo : trait opaque, épaisseur modulée par la pression.
  pen,

  /// Surligneur : trait large et translucide, sous l'écriture.
  highlighter,
}

/// Trait continu, du posé au levé du stylet.
final class InkStroke {
  const InkStroke({
    required this.points,
    required this.color,
    required this.width,
    this.tool = InkTool.pen,
  });

  final List<InkPoint> points;

  /// Couleur ARGB sur 32 bits (0xFF000000 : noir opaque).
  final int color;

  /// Épaisseur nominale, en unités de page.
  final double width;
  final InkTool tool;

  /// Rectangle englobant (gauche, haut, droite, bas), épaisseur comprise.
  ({double left, double top, double right, double bottom}) get bounds {
    var left = double.infinity, top = double.infinity;
    var right = double.negativeInfinity, bottom = double.negativeInfinity;
    for (final p in points) {
      left = math.min(left, p.x);
      top = math.min(top, p.y);
      right = math.max(right, p.x);
      bottom = math.max(bottom, p.y);
    }
    final m = width;
    return (left: left - m, top: top - m, right: right + m, bottom: bottom + m);
  }

  /// Vrai si le trait passe à moins de [radius] du point ([x], [y]) :
  /// sert à la gomme.
  bool hits(double x, double y, double radius) {
    final r = radius + width / 2;
    if (points.length == 1) {
      final p = points.single;
      return _dist2(p.x, p.y, x, y) <= r * r;
    }
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (_segmentDist2(x, y, a.x, a.y, b.x, b.y) <= r * r) return true;
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      other is InkStroke &&
      other.color == color &&
      other.width == width &&
      other.tool == tool &&
      _samePoints(other.points, points);

  @override
  int get hashCode => Object.hash(color, width, tool, points.length);
}

bool _samePoints(List<InkPoint> a, List<InkPoint> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

double _dist2(double ax, double ay, double bx, double by) =>
    (ax - bx) * (ax - bx) + (ay - by) * (ay - by);

double _segmentDist2(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  if (len2 == 0) return _dist2(px, py, ax, ay);
  final t = (((px - ax) * dx + (py - ay) * dy) / len2).clamp(0.0, 1.0);
  return _dist2(px, py, ax + t * dx, ay + t * dy);
}

/// Écriture manuscrite d'une note : des traits sur une page de largeur
/// fixe ([pageWidth] unités), qui s'allonge vers le bas. L'affichage met la
/// page à l'échelle de la place disponible : l'écriture garde ses
/// proportions sur iPad comme sur Windows.
final class InkDrawing {
  const InkDrawing(this.strokes);

  static const empty = InkDrawing([]);

  /// Largeur de la page, en unités.
  static const double pageWidth = 1000;

  final List<InkStroke> strokes;

  bool get isEmpty => strokes.isEmpty;

  /// Bas de l'écriture (0 si vide).
  double get bottom => strokes.fold(
    0,
    (m, s) => s.points.isEmpty ? m : math.max(m, s.bounds.bottom),
  );

  InkDrawing add(InkStroke stroke) => InkDrawing([...strokes, stroke]);

  /// Sans les traits touchés par la gomme en ([x], [y]).
  InkDrawing erase(double x, double y, double radius) => InkDrawing([
    for (final s in strokes)
      if (!s.hits(x, y, radius)) s,
  ]);

  /// Format compact : coordonnées au dixième d'unité, pression au
  /// centième, à plat dans une liste par trait.
  Map<String, Object?> toJson() => {
    'v': 1,
    'strokes': [
      for (final s in strokes)
        {
          'c': s.color,
          'w': _round(s.width, 10),
          if (s.tool != InkTool.pen) 't': s.tool.name,
          'p': [
            for (final p in s.points) ...[
              _round(p.x, 10),
              _round(p.y, 10),
              _round(p.pressure, 100),
            ],
          ],
        },
    ],
  };

  /// Lit le format compact ; refuse une version inconnue, un trait mal
  /// formé ou des valeurs aberrantes (épaisseur, pression, position hors
  /// bornes). Un trait sans point est ignoré.
  factory InkDrawing.fromJson(Map<String, Object?> json) {
    if (json['v'] != 1 || json['strokes'] is! List) {
      throw const FormatException('Écriture manuscrite : format inconnu');
    }
    final strokes = <InkStroke>[];
    for (final s in json['strokes'] as List) {
      final m = (s as Map).cast<String, Object?>();
      final flat = (m['p'] as List).cast<num>();
      final width = (m['w'] as num).toDouble();
      if (flat.length % 3 != 0 || !(width > 0 && width <= maxStrokeWidth)) {
        throw const FormatException('Trait mal formé');
      }
      final points = <InkPoint>[
        for (var i = 0; i < flat.length; i += 3)
          (
            x: flat[i].toDouble(),
            y: flat[i + 1].toDouble(),
            pressure: flat[i + 2].toDouble(),
          ),
      ];
      for (final p in points) {
        if (!(p.x >= -pageWidth && p.x <= 2 * pageWidth) ||
            !(p.y >= -pageWidth && p.y <= maxHeight) ||
            !(p.pressure >= 0 && p.pressure <= 1)) {
          throw const FormatException('Point hors de la page');
        }
      }
      if (points.isEmpty) continue;
      strokes.add(
        InkStroke(
          color: m['c'] as int,
          width: width,
          tool: m['t'] == null
              ? InkTool.pen
              : InkTool.values.byName(m['t'] as String),
          points: points,
        ),
      );
    }
    return InkDrawing(strokes);
  }

  /// Bornes acceptées à la lecture.
  static const double maxStrokeWidth = 100;
  static const double maxHeight = 200000;

  String encode() => jsonEncode(toJson());

  static InkDrawing decode(String source) =>
      InkDrawing.fromJson((jsonDecode(source) as Map).cast<String, Object?>());

  static num _round(double v, int scale) {
    final r = (v * scale).round() / scale;
    return r == r.roundToDouble() ? r.toInt() : r;
  }
}
