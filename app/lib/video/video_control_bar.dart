import 'dart:async';

import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../ui/coverage.dart';
import '../ui/labels.dart';
import 'youtube_player.dart';

/// Vitesses proposées par la barre de lecture.
const playbackRates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/// « 1× », « 1,25× ».
String rateLabel(double rate) =>
    '${rate == rate.roundToDouble() ? rate.toInt() : '$rate'.replaceAll('.', ',')}×';

/// Barre de lecture maison, à la façon de YouTube, qui remplace les
/// commandes du lecteur : lecture / pause, son, temps, vitesse et une frise
/// où la tête de lecture glisse sur la couverture de la vidéo (extraits recto
/// en bleu, verso en orange, notes, extrait en cours de marquage).
///
/// Le survol (souris) ou le glissement (doigt) d'un extrait affiche son
/// titre ; un appui sur un extrait y saute, ailleurs il déplace la lecture.
/// Le titre de ce qui est en cours de lecture s'affiche près du temps, et
/// l'ouvre ([onOpen]).
class VideoControlBar extends StatefulWidget {
  const VideoControlBar({
    super.key,
    required this.controller,
    this.spans = const [],
    this.selection,
    required this.rectoColor,
    required this.versoColor,
    required this.noteColor,
    this.onOpen,
    this.onFullscreen,
    this.fullscreen = false,
    this.pollInterval = const Duration(milliseconds: 250),
  });

  final YoutubePlayerController controller;
  final List<TimeSpan> spans;

  /// Extrait en cours de marquage (début, fin éventuelle).
  final (int, int?)? selection;
  final Color rectoColor;
  final Color versoColor;
  final Color noteColor;

  /// Ouvre la connaissance ou la note d'un extrait.
  final void Function(TimeSpan span)? onOpen;

  /// Bascule le plein cadre (pas de bouton si `null`).
  final VoidCallback? onFullscreen;
  final bool fullscreen;

  /// Fréquence de relevé de l'état du lecteur.
  final Duration pollInterval;

  @override
  State<VideoControlBar> createState() => _VideoControlBarState();
}

class _VideoControlBarState extends State<VideoControlBar> {
  VideoPlayback? _state;
  Timer? _poll;
  var _polling = false;

  /// Position sous le doigt pendant un glissement.
  int? _dragMs;

  /// Position sous la souris.
  int? _hoverMs;

  /// Position touchée, dont le titre reste affiché un instant.
  int? _flashMs;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(widget.pollInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_polling) return;
    _polling = true;
    try {
      final state = await widget.controller.playback();
      if (mounted && state != null) setState(() => _state = state);
    } catch (_) {
      // Lecteur pas encore prêt, ou vue web fermée.
    } finally {
      _polling = false;
    }
  }

  void _update({int? positionMs, bool? playing, bool? muted, double? rate}) {
    final s = _state;
    if (s == null) return;
    setState(
      () => _state = (
        positionMs: positionMs ?? s.positionMs,
        durationMs: s.durationMs,
        playing: playing ?? s.playing,
        muted: muted ?? s.muted,
        rate: rate ?? s.rate,
      ),
    );
  }

  void _seek(int ms) {
    widget.controller.seek(ms, play: _state?.playing ?? false);
    _update(positionMs: ms);
  }

  void _flash(int ms) {
    _flashTimer?.cancel();
    setState(() => _flashMs = ms);
    _flashTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _flashMs = null);
    });
  }

  void _togglePlay() {
    final playing = _state?.playing ?? false;
    playing ? widget.controller.pause() : widget.controller.play();
    _update(playing: !playing);
  }

  void _toggleMute() {
    final muted = !(_state?.muted ?? false);
    widget.controller.setMuted(muted);
    _update(muted: muted);
  }

  void _setRate(double rate) {
    widget.controller.setRate(rate);
    _update(rate: rate);
  }

  Color _colorOf(AnchorRole? role) => switch (role) {
    AnchorRole.source => widget.rectoColor,
    AnchorRole.work => widget.versoColor,
    null => widget.noteColor,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = _state;
    final duration = state?.durationMs;
    final position = _dragMs ?? state?.positionMs ?? 0;
    final current = duration == null
        ? const <TimeSpan>[]
        : (spansAt(widget.spans, position)
            // Les connaissances passent avant les notes.
            ..sort(
              (a, b) => (a.role == null ? 1 : 0) - (b.role == null ? 1 : 0),
            ));
    final playing = state?.playing ?? false;
    final muted = state?.muted ?? false;
    final rate = state?.rate ?? 1.0;
    final ready = state != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _track(theme, duration, position),
        Row(
          children: [
            IconButton(
              tooltip: playing ? 'Pause' : 'Lecture',
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: ready ? _togglePlay : null,
            ),
            IconButton(
              tooltip: muted ? 'Rétablir le son' : 'Couper le son',
              icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
              onPressed: ready ? _toggleMute : null,
            ),
            Text(
              duration == null
                  ? '–:– / –:–'
                  : '${formatClock(position)} / ${formatClock(duration)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: current.isEmpty
                  ? const SizedBox.shrink()
                  : _current(theme, current),
            ),
            PopupMenuButton<double>(
              tooltip: 'Vitesse de lecture',
              enabled: ready,
              initialValue: rate,
              onSelected: _setRate,
              itemBuilder: (context) => [
                for (final r in playbackRates)
                  PopupMenuItem(
                    value: r,
                    child: Text(r == 1 ? 'Normale' : rateLabel(r)),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(rateLabel(rate)),
              ),
            ),
            if (widget.onFullscreen != null)
              IconButton(
                tooltip: widget.fullscreen
                    ? 'Quitter le plein cadre'
                    : 'Plein cadre',
                icon: Icon(
                  widget.fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                ),
                onPressed: widget.onFullscreen,
              ),
          ],
        ),
      ],
    );
  }

  /// Titre de ce qui est en cours de lecture (le premier ; « +n » pour les
  /// autres), qui ouvre la connaissance ou la note.
  Widget _current(ThemeData theme, List<TimeSpan> current) {
    final first = current.first;
    final more = current.length > 1 ? '  +${current.length - 1}' : '';
    final open = widget.onOpen;
    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: open == null ? first.label : 'Ouvrir « ${first.label} »',
        child: InkWell(
          key: const Key('video-current'),
          borderRadius: BorderRadius.circular(6),
          onTap: open == null ? null : () => open(first),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  first.role == null ? Icons.edit_note : Icons.circle,
                  size: first.role == null ? 16 : 10,
                  color: _colorOf(first.role),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${first.label}$more',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _track(ThemeData theme, int? duration, int position) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double x(int ms) =>
            duration == null ? 0 : (ms / duration).clamp(0.0, 1.0) * width;
        int msAt(double dx) =>
            ((dx / width).clamp(0.0, 1.0) * (duration ?? 0)).round();
        // Extraits sous [dx], avec une marge pour les doigts et les points.
        List<TimeSpan> near(double dx) => [
          for (final s in widget.spans)
            if (dx >= x(s.start) - 4 &&
                dx <= (s.end == null ? x(s.start) + 3 : x(s.end!)) + 4)
              s,
        ];
        final preview = _dragMs ?? _hoverMs ?? _flashMs;
        final previewSpans = preview == null
            ? const <TimeSpan>[]
            : near(x(preview));
        final active = _dragMs != null || _hoverMs != null;
        Widget track = SizedBox(
          height: 44,
          child: Stack(
            children: [
              if (preview != null && duration != null)
                Align(
                  alignment: Alignment(
                    width == 0 ? 0 : x(preview) / width * 2 - 1,
                    -1,
                  ),
                  child: IgnorePointer(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: width * 0.6),
                      child: Container(
                        key: const Key('video-preview'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.inverseSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          [
                            formatClock(preview),
                            ...previewSpans.map((s) => s.label),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onInverseSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 22,
                child: CustomPaint(
                  painter: _TrackPainter(
                    duration: duration,
                    position: position,
                    spans: widget.spans,
                    selection: widget.selection,
                    hover: _hoverMs,
                    active: active,
                    background: theme.colorScheme.surfaceContainerHighest,
                    played: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                    head: theme.colorScheme.primary,
                    selectionColor: theme.colorScheme.primary,
                    colorOf: _colorOf,
                  ),
                ),
              ),
            ],
          ),
        );
        if (duration == null) return track;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onHover: (e) => setState(() => _hoverMs = msAt(e.localPosition.dx)),
          onExit: (_) => setState(() => _hoverMs = null),
          child: GestureDetector(
            key: const Key('video-track'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final dx = d.localPosition.dx;
              final spans = near(dx);
              final target = spans.isEmpty ? msAt(dx) : spans.last.start;
              _seek(target);
              _flash(target);
            },
            onHorizontalDragStart: (d) =>
                setState(() => _dragMs = msAt(d.localPosition.dx)),
            onHorizontalDragUpdate: (d) =>
                setState(() => _dragMs = msAt(d.localPosition.dx)),
            onHorizontalDragEnd: (_) {
              final target = _dragMs;
              setState(() => _dragMs = null);
              if (target != null) {
                _seek(target);
                _flash(target);
              }
            },
            onHorizontalDragCancel: () => setState(() => _dragMs = null),
            child: track,
          ),
        );
      },
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.duration,
    required this.position,
    required this.spans,
    required this.selection,
    required this.hover,
    required this.active,
    required this.background,
    required this.played,
    required this.head,
    required this.selectionColor,
    required this.colorOf,
  });

  final int? duration;
  final int position;
  final List<TimeSpan> spans;
  final (int, int?)? selection;
  final int? hover;

  /// Survol ou glissement : la frise s'épaissit, comme sur YouTube.
  final bool active;
  final Color background;
  final Color played;
  final Color head;
  final Color selectionColor;
  final Color Function(AnchorRole?) colorOf;

  @override
  void paint(Canvas canvas, Size size) {
    final d = duration;
    double x(int ms) =>
        d == null || d == 0 ? 0 : (ms / d).clamp(0.0, 1.0) * size.width;
    final thickness = active ? 8.0 : 5.0;
    final mid = size.height / 2;
    final bar = Rect.fromLTRB(
      0,
      mid - thickness / 2,
      size.width,
      mid + thickness / 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(3)),
      Paint()..color = background,
    );
    if (d == null) return;
    final playX = x(position);
    canvas.drawRect(
      Rect.fromLTRB(0, bar.top, playX, bar.bottom),
      Paint()..color = played,
    );
    // Extraits : pâles devant la tête de lecture, francs derrière.
    void drawSpans(double alpha) {
      for (final s in spans) {
        final left = x(s.start);
        final right = s.end == null ? left + 3 : x(s.end!);
        canvas.drawRect(
          Rect.fromLTRB(
            left,
            bar.top,
            right - left < 3 ? left + 3 : right,
            bar.bottom,
          ),
          Paint()..color = colorOf(s.role).withValues(alpha: alpha),
        );
      }
    }

    drawSpans(0.55);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, playX, size.height));
    drawSpans(1);
    canvas.restore();

    final sel = selection;
    if (sel != null) {
      final left = x(sel.$1);
      final right = sel.$2 == null ? left + 2 : x(sel.$2!);
      canvas.drawRect(
        Rect.fromLTRB(
          left,
          bar.top - 4,
          right < left + 2 ? left + 2 : right,
          bar.bottom + 4,
        ),
        Paint()
          ..color = selectionColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final h = hover;
    if (h != null) {
      canvas.drawRect(
        Rect.fromLTWH(x(h) - 1, bar.top, 2, bar.height),
        Paint()..color = head.withValues(alpha: 0.6),
      );
    }
    canvas.drawCircle(
      Offset(playX, mid),
      active ? 8 : 6,
      Paint()..color = head,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.duration != duration ||
      old.position != position ||
      old.spans != spans ||
      old.selection != selection ||
      old.hover != hover ||
      old.active != active ||
      old.head != head;
}
