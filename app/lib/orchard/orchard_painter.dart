import 'package:flutter/material.dart';

import '../ui/item_glyph.dart';
import 'orchard_layout.dart';

/// Dessine une [OrchardLayout] : sol, bois, connaissances, étiquettes.
class OrchardPainter extends CustomPainter {
  OrchardPainter({
    required this.layout,
    required this.labelStyle,
    required this.accent,
  });

  final OrchardLayout layout;
  final TextStyle labelStyle;

  /// Couleur des indications « à réviser ».
  final Color accent;

  static const _bark = Color(0xFF7A6248);
  static const _bareBark = Color(0xFFA79C8E);
  static const _ground = Color(0x225B7F5E);

  @override
  void paint(Canvas canvas, Size size) {
    final s = layout.size;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s.width / 2, s.height * 0.95),
        width: s.width * 0.5,
        height: s.height * 0.05,
      ),
      Paint()..color = _ground,
    );

    for (final segment in layout.wood) {
      canvas.drawLine(
        segment.from,
        segment.to,
        Paint()
          ..color = segment.bare ? _bareBark : _bark
          ..strokeWidth = segment.width
          ..strokeCap = StrokeCap.round,
      );
    }

    final halo = Paint()..color = accent.withValues(alpha: 0.16);
    for (final glyph in layout.glyphs) {
      if (glyph.item.isDue) {
        canvas.drawCircle(glyph.center, glyph.size * 0.72, halo);
      }
      canvas.save();
      canvas.translate(
        glyph.center.dx - glyph.size / 2,
        glyph.center.dy - glyph.size / 2,
      );
      ItemGlyphPainter(
        glyph.item.family,
        glyph.item.stage,
      ).paint(canvas, Size.square(glyph.size));
      canvas.restore();
    }

    for (final label in layout.labels) {
      final text = [
        label.text,
        if (label.hidden > 0) '+${label.hidden}',
      ].join('  ');
      final painter = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: s.width * 0.3);
      var dx = label.alignRight
          ? label.anchor.dx - painter.width
          : label.anchor.dx;
      dx = dx.clamp(4, s.width - painter.width - 4);
      final dy = (label.anchor.dy - painter.height / 2).clamp(
        4.0,
        s.height - painter.height - 4,
      );
      painter.paint(canvas, Offset(dx, dy));
      if (label.isDue) {
        final drop = Offset(
          label.alignRight ? dx - 10 : dx + painter.width + 10,
          dy + painter.height / 2,
        );
        canvas.drawCircle(drop, 4, Paint()..color = accent);
      }
    }
  }

  @override
  bool shouldRepaint(OrchardPainter old) =>
      old.layout != layout ||
      old.labelStyle != labelStyle ||
      old.accent != accent;
}
