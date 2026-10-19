import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

/// Espacement des lignes du papier, en unités de page.
const inkLineSpacing = 60.0;

/// Dessine [ink] à l'échelle [scale] (pixels par unité de page). Le
/// surligneur passe sous l'écriture.
class InkPainter extends CustomPainter {
  InkPainter({
    required this.ink,
    required this.scale,
    this.current,
    this.lines,
  });

  final InkDrawing ink;
  final double scale;

  /// Trait en cours de tracé.
  final InkStroke? current;

  /// Couleur des lignes du papier (`null` : page blanche).
  final Color? lines;

  @override
  void paint(Canvas canvas, Size size) {
    final lines = this.lines;
    if (lines != null) {
      final paint = Paint()
        ..color = lines
        ..strokeWidth = 1;
      for (
        var y = inkLineSpacing * scale;
        y < size.height;
        y += inkLineSpacing * scale
      ) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
    final strokes = [...ink.strokes, ?current];
    for (final s in strokes) {
      if (s.tool == InkTool.highlighter) _paintStroke(canvas, s);
    }
    for (final s in strokes) {
      if (s.tool == InkTool.pen) _paintStroke(canvas, s);
    }
  }

  void _paintStroke(Canvas canvas, InkStroke s) {
    if (s.points.isEmpty) return;
    final highlighter = s.tool == InkTool.highlighter;
    final paint = Paint()
      ..color = Color(s.color)
      ..strokeCap = highlighter ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    Offset at(InkPoint p) => Offset(p.x * scale, p.y * scale);
    double widthAt(InkPoint p) =>
        highlighter ? s.width * scale : s.width * scale * (0.5 + p.pressure);
    if (s.points.length == 1) {
      final p = s.points.single;
      canvas.drawCircle(
        at(p),
        widthAt(p) / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }
    if (highlighter) {
      // Un seul chemin : la transparence ne s'additionne pas aux jonctions.
      final path = Path()..moveTo(at(s.points.first).dx, at(s.points.first).dy);
      for (final p in s.points.skip(1)) {
        path.lineTo(at(p).dx, at(p).dy);
      }
      canvas.drawPath(path, paint..strokeWidth = widthAt(s.points.first));
      return;
    }
    // Stylo : courbe lissée (milieux reliés par des courbes). Les segments
    // d'épaisseur voisine forment un seul chemin : pas de surépaisseur aux
    // jonctions ; on n'en commence un nouveau que si la pression change
    // nettement.
    var path = Path()..moveTo(at(s.points.first).dx, at(s.points.first).dy);
    var pathWidth = widthAt(s.points.first);
    for (var i = 1; i < s.points.length; i++) {
      final control = at(s.points[i - 1]);
      final next = at(s.points[i]);
      final to = i == s.points.length - 1
          ? next
          : Offset((control.dx + next.dx) / 2, (control.dy + next.dy) / 2);
      if (i == 1) {
        path.lineTo(to.dx, to.dy);
      } else {
        path.quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
      }
      final w = widthAt(s.points[i]);
      final last = i == s.points.length - 1;
      if (last || (w - pathWidth).abs() > 0.15 * pathWidth) {
        canvas.drawPath(path, paint..strokeWidth = pathWidth);
        path = Path()..moveTo(to.dx, to.dy);
        pathWidth = w;
      }
    }
  }

  @override
  bool shouldRepaint(InkPainter old) =>
      old.ink != ink ||
      old.scale != scale ||
      // Trait en cours : sa liste de points grandit sur place.
      !identical(old.current, current) ||
      old.lines != lines;
}

/// Écriture manuscrite en lecture seule, à la largeur disponible.
class InkView extends StatelessWidget {
  const InkView({super.key, required this.ink});

  final InkDrawing ink;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 900.0);
        final scale = width / InkDrawing.pageWidth;
        return SizedBox(
          width: width,
          height: (ink.bottom + 20) * scale,
          child: CustomPaint(
            painter: InkPainter(ink: ink, scale: scale),
          ),
        );
      },
    );
  }
}
