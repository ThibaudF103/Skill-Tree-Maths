import 'dart:async';

import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../ui/coverage.dart';
import 'youtube_player.dart';

/// Frise de couverture d'une vidéo : extraits recto (bleu) et verso
/// (orange), notes (repères), extrait en cours de marquage. Un appui
/// déplace la lecture.
class VideoTimeline extends StatefulWidget {
  const VideoTimeline({
    super.key,
    required this.controller,
    required this.spans,
    this.selection,
    required this.rectoColor,
    required this.versoColor,
    required this.noteColor,
  });

  final YoutubePlayerController controller;
  final List<TimeSpan> spans;

  /// Extrait en cours de marquage (début, fin éventuelle).
  final (int, int?)? selection;
  final Color rectoColor;
  final Color versoColor;
  final Color noteColor;

  @override
  State<VideoTimeline> createState() => _VideoTimelineState();
}

class _VideoTimelineState extends State<VideoTimeline> {
  int? _duration;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // La durée n'est connue qu'une fois la vidéo chargée.
    _poll = Timer.periodic(const Duration(seconds: 1), (_) async {
      final duration = await widget.controller.durationMs();
      if (!mounted || duration == null) return;
      _poll?.cancel();
      setState(() => _duration = duration);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = _duration;
    if (duration == null) return const SizedBox(height: 16);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => widget.controller.seek(
          (d.localPosition.dx / constraints.maxWidth * duration).round(),
        ),
        child: Tooltip(
          message: 'Couverture de la vidéo : appuyer pour s\'y rendre',
          child: SizedBox(
            height: 16,
            width: double.infinity,
            child: CustomPaint(
              painter: _TimelinePainter(
                duration: duration,
                spans: widget.spans,
                selection: widget.selection,
                background: theme.colorScheme.surfaceContainerHighest,
                selectionColor: theme.colorScheme.primary,
                colorOf: (role) => switch (role) {
                  AnchorRole.source => widget.rectoColor,
                  AnchorRole.work => widget.versoColor,
                  null => widget.noteColor,
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.duration,
    required this.spans,
    required this.selection,
    required this.background,
    required this.selectionColor,
    required this.colorOf,
  });

  final int duration;
  final List<TimeSpan> spans;
  final (int, int?)? selection;
  final Color background;
  final Color selectionColor;
  final Color Function(AnchorRole?) colorOf;

  @override
  void paint(Canvas canvas, Size size) {
    double x(int ms) => (ms / duration).clamp(0.0, 1.0) * size.width;
    final bar = Rect.fromLTWH(0, 4, size.width, size.height - 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(4)),
      Paint()..color = background,
    );
    for (final s in spans) {
      final paint = Paint()..color = colorOf(s.role);
      final left = x(s.start);
      final right = s.end == null ? left + 3 : x(s.end!);
      canvas.drawRect(
        Rect.fromLTRB(
          left,
          bar.top,
          (right - left < 3 ? left + 3 : right),
          bar.bottom,
        ),
        paint,
      );
    }
    final sel = selection;
    if (sel != null) {
      final left = x(sel.$1);
      final right = sel.$2 == null ? left + 2 : x(sel.$2!);
      canvas.drawRect(
        Rect.fromLTRB(
          left,
          0,
          right < left + 2 ? left + 2 : right,
          size.height,
        ),
        Paint()
          ..color = selectionColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.duration != duration ||
      old.spans != spans ||
      old.selection != selection;
}
