import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

/// Glyphe botanique d'une connaissance : feuille (définition), fleur (énoncé),
/// fruit (exercice). Sa forme et sa taille suivent le stade de croissance.
/// Réutilisé par le verger.
class ItemGlyph extends StatelessWidget {
  const ItemGlyph({
    super.key,
    required this.family,
    required this.stage,
    this.size = 28,
  });

  final ItemFamily family;
  final GrowthStage stage;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: ItemGlyphPainter(family, stage)),
    );
  }
}

class ItemGlyphPainter extends CustomPainter {
  ItemGlyphPainter(this.family, this.stage);

  final ItemFamily family;
  final GrowthStage stage;

  static const _stem = Color(0xFF6B8F5E);
  static const _bud = Color(0xFF9DB58A);
  static const _leaf = Color(0xFF4F8A4B);
  static const _leafLight = Color(0xFF8DBF7A);
  static const _petal = Color(0xFFF2D7DE);
  static const _petalEdge = Color(0xFFD9A5B3);
  static const _heart = Color(0xFFE0B04A);
  static const _fruitYoung = Color(0xFFB9C96A);
  static const _fruitRipe = Color(0xFFC8553D);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    switch (stage) {
      case GrowthStage.bud:
        _drawBud(canvas, s);
      case GrowthStage.sprout:
        _drawSprout(canvas, s);
      case GrowthStage.young || GrowthStage.developed || GrowthStage.mature:
        final scale = switch (stage) {
          GrowthStage.young => 0.62,
          GrowthStage.developed => 0.82,
          _ => 1.0,
        };
        canvas.save();
        canvas.translate(s / 2, s / 2);
        canvas.scale(scale);
        canvas.translate(-s / 2, -s / 2);
        switch (family) {
          case ItemFamily.definition:
            _drawLeaf(canvas, s);
          case ItemFamily.statement:
            _drawFlower(canvas, s);
          case ItemFamily.exercise:
            _drawFruit(canvas, s, ripe: stage == GrowthStage.mature);
        }
        canvas.restore();
    }
  }

  void _drawBud(Canvas canvas, double s) {
    final stem = Paint()
      ..color = _stem
      ..strokeWidth = s * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s * .5, s * .9), Offset(s * .5, s * .62), stem);
    final bud = Path()
      ..moveTo(s * .5, s * .3)
      ..quadraticBezierTo(s * .66, s * .5, s * .5, s * .66)
      ..quadraticBezierTo(s * .34, s * .5, s * .5, s * .3);
    canvas.drawPath(bud, Paint()..color = _bud);
  }

  void _drawSprout(Canvas canvas, double s) {
    final stem = Paint()
      ..color = _stem
      ..strokeWidth = s * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s * .5, s * .92), Offset(s * .5, s * .45), stem);
    final paint = Paint()..color = _leafLight;
    for (final dir in [-1.0, 1.0]) {
      final leaf = Path()
        ..moveTo(s * .5, s * .52)
        ..quadraticBezierTo(
          s * (.5 + dir * .12),
          s * .24,
          s * (.5 + dir * .34),
          s * .3,
        )
        ..quadraticBezierTo(s * (.5 + dir * .3), s * .5, s * .5, s * .52);
      canvas.drawPath(leaf, paint);
    }
  }

  void _drawLeaf(Canvas canvas, double s) {
    final leaf = Path()
      ..moveTo(s * .2, s * .82)
      ..cubicTo(s * .15, s * .35, s * .5, s * .12, s * .86, s * .12)
      ..cubicTo(s * .86, s * .5, s * .62, s * .86, s * .2, s * .82)
      ..close();
    canvas.drawPath(leaf, Paint()..color = _leaf);
    final rib = Paint()
      ..color = _leafLight
      ..strokeWidth = s * 0.035
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(s * .14, s * .88)
        ..quadraticBezierTo(s * .45, s * .52, s * .78, s * .2),
      rib,
    );
  }

  void _drawFlower(Canvas canvas, double s) {
    final center = Offset(s * .5, s * .5);
    final petal = Paint()..color = _petal;
    final edge = Paint()
      ..color = _petalEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03;
    for (var i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / 5;
      final c = center + Offset(math.cos(angle), math.sin(angle)) * s * .22;
      final rect = Rect.fromCircle(center: c, radius: s * .19);
      canvas.drawOval(rect, petal);
      canvas.drawOval(rect, edge);
    }
    canvas.drawCircle(center, s * .12, Paint()..color = _heart);
  }

  void _drawFruit(Canvas canvas, double s, {required bool ripe}) {
    final body = Paint()..color = ripe ? _fruitRipe : _fruitYoung;
    final fruit = Path()
      ..moveTo(s * .5, s * .34)
      ..cubicTo(s * .78, s * .18, s * .94, s * .5, s * .76, s * .78)
      ..cubicTo(s * .66, s * .94, s * .56, s * .9, s * .5, s * .86)
      ..cubicTo(s * .44, s * .9, s * .34, s * .94, s * .24, s * .78)
      ..cubicTo(s * .06, s * .5, s * .22, s * .18, s * .5, s * .34)
      ..close();
    canvas.drawPath(fruit, body);
    final stem = Paint()
      ..color = _stem
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(s * .5, s * .34), Offset(s * .54, s * .14), stem);
    final leaf = Path()
      ..moveTo(s * .54, s * .2)
      ..quadraticBezierTo(s * .7, s * .06, s * .8, s * .14)
      ..quadraticBezierTo(s * .68, s * .26, s * .54, s * .2);
    canvas.drawPath(leaf, Paint()..color = _leaf);
  }

  @override
  bool shouldRepaint(ItemGlyphPainter old) =>
      old.family != family || old.stage != stage;
}
