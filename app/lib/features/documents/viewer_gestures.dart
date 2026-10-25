import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Ordinateur (souris, molette, pavé tactile) plutôt que tablette.
bool get isDesktopPlatform => switch (defaultTargetPlatform) {
  TargetPlatform.windows ||
  TargetPlatform.macOS ||
  TargetPlatform.linux => true,
  _ => false,
};

/// Appareils qui tracent ou redimensionnent un cadre : le pavé tactile (deux
/// doigts) fait défiler la page à la place.
const frameDevices = {
  PointerDeviceKind.mouse,
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
};

/// Calque posé sur la visionneuse (zones encadrées, poignées, barre de
/// défilement) : la molette et le pavé tactile y font défiler la page.
///
/// Sans lui, le calque reçoit l'événement à la place de la visionneuse
/// placée dessous, et la page ne défile plus sous le pointeur. Seuls les
/// événements qui touchent un élément du calque passent ici : ailleurs, la
/// visionneuse les reçoit elle-même (pas de double défilement).
class ScrollPassThrough extends StatelessWidget {
  const ScrollPassThrough({
    super.key,
    required this.onScroll,
    this.onPan,
    required this.child,
  });

  /// Molette (et pavé tactile sur le web).
  final ValueChanged<PointerScrollEvent> onScroll;

  /// Pavé tactile à deux doigts : déplacement du contenu.
  final ValueChanged<Offset>? onPan;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) onScroll(event);
      },
      onPointerPanZoomUpdate: onPan == null
          ? null
          : (event) => onPan!(event.panDelta),
      child: child,
    );
  }
}

/// Barre de défilement verticale (version ordinateur) : le curseur se
/// glisse, un clic sur la piste avance ou recule d'un écran.
///
/// [extent], [viewport] et [offset] sont dans la même unité (hauteur du
/// document, hauteur visible, position du haut de la vue).
class ViewerScrollbar extends StatefulWidget {
  const ViewerScrollbar({
    super.key,
    required this.extent,
    required this.viewport,
    required this.offset,
    required this.onScrollTo,
    this.thickness = 14,
    this.minThumb = 36,
  });

  final double extent;
  final double viewport;
  final double offset;
  final ValueChanged<double> onScrollTo;
  final double thickness;
  final double minThumb;

  @override
  State<ViewerScrollbar> createState() => _ViewerScrollbarState();
}

class _ViewerScrollbarState extends State<ViewerScrollbar> {
  var _hover = false;
  double? _dragOffset;
  var _dragY = 0.0;

  @override
  Widget build(BuildContext context) {
    final range = widget.extent - widget.viewport;
    if (range <= 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final track = constraints.maxHeight;
        final thumb = math.min(
          track,
          math.max(widget.minThumb, track * widget.viewport / widget.extent),
        );
        final travel = track - thumb;
        final top = travel * (widget.offset / range).clamp(0.0, 1.0);
        final active = _hover || _dragOffset != null;
        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Clic sur la piste : un écran plus haut ou plus bas.
            onTapUp: (d) {
              final y = d.localPosition.dy;
              if (y < top) {
                widget.onScrollTo(math.max(0, widget.offset - widget.viewport));
              } else if (y > top + thumb) {
                widget.onScrollTo(
                  math.min(range, widget.offset + widget.viewport),
                );
              }
            },
            child: Container(
              width: widget.thickness,
              color: scheme.surface.withValues(alpha: active ? 0.7 : 0.4),
              child: Stack(
                children: [
                  Positioned(
                    top: top,
                    left: 2,
                    right: 2,
                    height: thumb,
                    child: GestureDetector(
                      key: const ValueKey('viewer-scroll-thumb'),
                      behavior: HitTestBehavior.opaque,
                      dragStartBehavior: DragStartBehavior.down,
                      onVerticalDragStart: (d) => setState(() {
                        _dragOffset = widget.offset;
                        _dragY = d.globalPosition.dy;
                      }),
                      onVerticalDragUpdate: (d) {
                        final start = _dragOffset;
                        if (start == null || travel <= 0) return;
                        final moved = d.globalPosition.dy - _dragY;
                        widget.onScrollTo(
                          (start + moved * range / travel).clamp(0.0, range),
                        );
                      },
                      onVerticalDragEnd: (_) =>
                          setState(() => _dragOffset = null),
                      onVerticalDragCancel: () =>
                          setState(() => _dragOffset = null),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withValues(
                            alpha: active ? 0.55 : 0.35,
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Défilement automatique au bouton du milieu (clic molette), comme dans les
/// navigateurs : une ancre apparaît, la page défile vers le pointeur, d'autant
/// plus vite qu'il s'en éloigne.
///
/// - Appui maintenu et déplacement : le défilement s'arrête au relâchement.
/// - Simple clic (relâché sans bouger) : le défilement continue en déplaçant
///   la souris, jusqu'au clic suivant (n'importe quel bouton), qui est
///   consommé. Un clic ailleurs (barre d'outils, notes) ou Échap l'arrêtent
///   aussi.
class MiddleClickAutoscroll extends StatefulWidget {
  const MiddleClickAutoscroll({
    super.key,
    required this.onScroll,
    required this.child,
  });

  /// Défilement demandé (positif : vers le bas ou la droite, comme la
  /// molette), en pixels.
  final ValueChanged<Offset> onScroll;

  final Widget child;

  /// Zone morte autour de l'ancre, en pixels.
  static const deadZone = 12.0;

  /// Vitesse, en pixels par seconde et par pixel au-delà de la zone morte.
  static const speed = 6.0;

  /// Vitesse maximale, en pixels par seconde.
  static const maxSpeed = 5000.0;

  /// Vitesse de défilement pour un pointeur à [distance] de l'ancre.
  @visibleForTesting
  static Offset velocityFor(Offset distance) {
    double axis(double d) {
      final beyond = d.abs() - deadZone;
      if (beyond <= 0) return 0;
      return d.sign * math.min(maxSpeed, beyond * speed);
    }

    return Offset(axis(distance.dx), axis(distance.dy));
  }

  @override
  State<MiddleClickAutoscroll> createState() => _MiddleClickAutoscrollState();
}

class _MiddleClickAutoscrollState extends State<MiddleClickAutoscroll>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);

  /// Ancre et pointeur, en coordonnées globales ; `null` : inactif.
  Offset? _anchor;
  var _pointer = Offset.zero;
  var _moved = false;
  var _last = Duration.zero;

  @override
  void dispose() {
    _unlisten();
    _ticker.dispose();
    super.dispose();
  }

  void _start(Offset global) {
    setState(() {
      _anchor = _pointer = global;
      _moved = false;
    });
    _last = Duration.zero;
    _ticker
      ..stop()
      ..start();
    if (!_listening) {
      _listening = true;
      GestureBinding.instance.pointerRouter.addGlobalRoute(_onAnyPointer);
      HardwareKeyboard.instance.addHandler(_onKey);
    }
  }

  /// Clics et touche Échap écoutés partout pendant le défilement.
  var _listening = false;

  void _unlisten() {
    if (!_listening) return;
    _listening = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onAnyPointer);
    HardwareKeyboard.instance.removeHandler(_onKey);
  }

  /// Clic hors de la visionneuse : arrêt (dedans, le geste s'en charge).
  void _onAnyPointer(PointerEvent event) {
    if (event is! PointerDownEvent || _anchor == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if (!(Offset.zero & box.size).contains(box.globalToLocal(event.position))) {
      _stop();
    }
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape ||
        _anchor == null) {
      return false;
    }
    _stop();
    return true;
  }

  void _move(Offset global) {
    final anchor = _anchor;
    if (anchor == null) return;
    _pointer = global;
    if ((global - anchor).distance > MiddleClickAutoscroll.deadZone) {
      _moved = true;
    }
  }

  void _release(Offset global) {
    _move(global);
    // Appui maintenu avec déplacement : on s'arrête ; simple clic : on
    // continue jusqu'au clic suivant.
    if (_moved) _stop();
  }

  void _stop() {
    if (_anchor == null) return;
    _unlisten();
    _ticker.stop();
    setState(() => _anchor = null);
  }

  void _tick(Duration elapsed) {
    final anchor = _anchor;
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (anchor == null || dt <= 0) return;
    final velocity = MiddleClickAutoscroll.velocityFor(_pointer - anchor);
    if (velocity != Offset.zero) widget.onScroll(velocity * dt);
  }

  @override
  Widget build(BuildContext context) {
    final anchor = _anchor;
    final box = context.findRenderObject() as RenderBox?;
    final local = anchor == null || box == null || !box.hasSize
        ? null
        : box.globalToLocal(anchor);
    final scheme = Theme.of(context).colorScheme;
    return RawGestureDetector(
      gestures: {
        _AutoscrollRecognizer:
            GestureRecognizerFactoryWithHandlers<_AutoscrollRecognizer>(
              () => _AutoscrollRecognizer(debugOwner: this),
              (r) => r
                ..active = (() => _anchor != null)
                ..onStart = _start
                ..onMove = _move
                ..onRelease = _release
                ..onStop = _stop,
            ),
      },
      child: MouseRegion(
        cursor: anchor == null
            ? MouseCursor.defer
            : SystemMouseCursors.allScroll,
        onHover: (e) => _move(e.position),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            if (local != null)
              Positioned(
                left: local.dx - 16,
                top: local.dy - 16,
                child: IgnorePointer(
                  child: Container(
                    key: const ValueKey('autoscroll-anchor'),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.outline),
                    ),
                    child: Icon(
                      Icons.open_with,
                      size: 20,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bouton du milieu de la souris : remporte aussitôt le geste, pour que la
/// visionneuse ne fasse pas glisser la page en même temps. Pendant le
/// défilement automatique, prend aussi le clic qui l'arrête (il n'ouvre
/// alors ni lien ni zone).
class _AutoscrollRecognizer extends OneSequenceGestureRecognizer {
  _AutoscrollRecognizer({super.debugOwner})
    : super(supportedDevices: const {PointerDeviceKind.mouse});

  bool Function() active = _never;
  ValueChanged<Offset>? onStart;
  ValueChanged<Offset>? onMove;
  ValueChanged<Offset>? onRelease;
  VoidCallback? onStop;

  /// Le clic en cours arrête le défilement (son relâchement est ignoré).
  var _stopping = false;

  static bool _never() => false;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      super.isPointerAllowed(event) &&
      (active() || event.buttons == kMiddleMouseButton);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
    _stopping = active();
    if (_stopping) {
      onStop?.call();
    } else {
      onStart?.call(event.position);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      if (!_stopping) onMove?.call(event.position);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (!_stopping) {
        if (event is PointerUpEvent) {
          onRelease?.call(event.position);
        } else {
          onStop?.call();
        }
      }
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) => _stopping = false;

  @override
  String get debugDescription => 'autoscroll';
}

/// Poignées pour redimensionner un cadre existant (mode « Encadrer ») :
/// quatre coins et quatre côtés, avec le curseur adapté à la souris.
///
/// Les zones de prise débordent largement à l'extérieur du bord (doigt,
/// stylet) mais peu à l'intérieur : on peut encore tracer un nouveau cadre
/// dans celui-ci, même petit.
///
/// À placer dans le [Stack] de la page ; [rect], [bounds] et [minSize] sont
/// en pixels de la page.
class FrameResizer extends StatefulWidget {
  const FrameResizer({
    super.key,
    required this.rect,
    required this.bounds,
    required this.minSize,
    required this.color,
    required this.onResized,
    required this.child,
    this.onHandleTap,
    this.outerExtent = 18,
    this.innerExtent = 10,
  });

  final Rect rect;
  final Size bounds;
  final Size minSize;
  final Color color;

  /// Nouveau rectangle, à la fin du geste.
  final ValueChanged<Rect> onResized;

  /// Poignée touchée sans glisser (cadres superposés : passer à celui de
  /// dessous).
  final VoidCallback? onHandleTap;

  /// Dessin du cadre, qui suit le redimensionnement.
  final Widget child;

  /// Largeur des zones de prise à l'extérieur du bord.
  final double outerExtent;

  /// Largeur maximale des zones de prise à l'intérieur du bord (réduite sur
  /// un petit cadre, pour lui laisser un intérieur libre).
  final double innerExtent;

  /// Rectangle [start] dont on déplace les côtés désignés par [h] et [v]
  /// (-1 : gauche ou haut, 1 : droite ou bas, 0 : aucun) de [delta], borné à
  /// [bounds] et à la taille minimale.
  static Rect resize(
    Rect start,
    int h,
    int v,
    Offset delta,
    Size bounds,
    Size minSize,
  ) {
    (double, double) axis(
      double lo,
      double hi,
      int side,
      double d,
      double max,
      double min,
    ) {
      min = math.min(min, max);
      lo = lo.clamp(0.0, max);
      hi = hi.clamp(lo, max);
      if (side < 0) lo = (lo + d).clamp(0.0, math.max(0.0, hi - min));
      if (side > 0) hi = (hi + d).clamp(math.min(lo + min, max), max);
      // Taille minimale, sans sortir de la page.
      if (side != 0 && hi - lo < min) {
        if (side < 0) {
          hi = math.min(max, lo + min);
        } else {
          lo = math.max(0, hi - min);
        }
      }
      return (lo, hi);
    }

    final (left, right) = axis(
      start.left,
      start.right,
      h,
      delta.dx,
      bounds.width,
      minSize.width,
    );
    final (top, bottom) = axis(
      start.top,
      start.bottom,
      v,
      delta.dy,
      bounds.height,
      minSize.height,
    );
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  State<FrameResizer> createState() => _FrameResizerState();
}

class _FrameResizerState extends State<FrameResizer> {
  /// Rectangle affiché pendant le geste, puis jusqu'à l'enregistrement.
  Rect? _live;
  Rect? _start;

  /// Point de départ du geste, dans le repère de la page (suit un
  /// défilement pendant le geste).
  var _origin = Offset.zero;

  @override
  void didUpdateWidget(FrameResizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bounds != oldWidget.bounds) {
      // Zoom pendant le geste : les pixels de départ ne valent plus rien.
      _start = null;
      _live = null;
    } else if (_start == null && widget.rect != oldWidget.rect) {
      // Nouveau rectangle enregistré.
      _live = null;
    }
  }

  /// [global] dans le repère de la page (le [Stack] qui contient le cadre).
  Offset _toPage(Offset global) {
    final page = context.findAncestorRenderObjectOfType<RenderStack>();
    return page == null ? global : page.globalToLocal(global);
  }

  static MouseCursor _cursor(int h, int v) => switch ((h, v)) {
    (0, _) => SystemMouseCursors.resizeUpDown,
    (_, 0) => SystemMouseCursors.resizeLeftRight,
    (-1, -1) || (1, 1) => SystemMouseCursors.resizeUpLeftDownRight,
    _ => SystemMouseCursors.resizeUpRightDownLeft,
  };

  Widget _handle(
    int h,
    int v, {
    double? left,
    double? top,
    double? right,
    double? bottom,
    double? width,
    double? height,
  }) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: _cursor(h, v),
        child: GestureDetector(
          key: ValueKey('frame-handle-$h,$v'),
          behavior: HitTestBehavior.opaque,
          supportedDevices: frameDevices,
          dragStartBehavior: DragStartBehavior.down,
          onTap: widget.onHandleTap,
          onPanStart: (d) => setState(() {
            _start = _live ?? widget.rect;
            _origin = _toPage(d.globalPosition);
          }),
          onPanUpdate: (d) {
            final start = _start;
            if (start == null) return;
            setState(
              () => _live = FrameResizer.resize(
                start,
                h,
                v,
                _toPage(d.globalPosition) - _origin,
                widget.bounds,
                widget.minSize,
              ),
            );
          },
          onPanEnd: (_) {
            final live = _live;
            final dragging = _start != null;
            setState(() => _start = null);
            if (dragging && live != null && live != widget.rect) {
              widget.onResized(live);
            }
          },
          onPanCancel: () => setState(() {
            _start = null;
            _live = null;
          }),
        ),
      ),
    );
  }

  Widget _knob(Offset at, bool round) => Positioned(
    left: at.dx - 5,
    top: at.dy - 5,
    width: 10,
    height: 10,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: widget.color, width: 1.5),
        shape: round ? BoxShape.circle : BoxShape.rectangle,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final rect = _live ?? widget.rect;
    final o = widget.outerExtent;
    // Part intérieure : au plus le quart du cadre, qui garde la moitié de
    // sa largeur et de sa hauteur libre pour tracer.
    final ix = math.min(widget.innerExtent, rect.width / 4);
    final iy = math.min(widget.innerExtent, rect.height / 4);
    final w = rect.width + 2 * o;
    final h = rect.height + 2 * o;
    return Positioned.fromRect(
      rect: rect.inflate(o),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: o,
            top: o,
            right: o,
            bottom: o,
            child: IgnorePointer(child: widget.child),
          ),
          // Côtés entre les coins (pas sur un cadre minuscule), puis coins.
          if (rect.width - 2 * ix >= 8) ...[
            _handle(0, -1, left: o + ix, right: o + ix, top: 0, height: o + iy),
            _handle(
              0,
              1,
              left: o + ix,
              right: o + ix,
              bottom: 0,
              height: o + iy,
            ),
          ],
          if (rect.height - 2 * iy >= 8) ...[
            _handle(-1, 0, top: o + iy, bottom: o + iy, left: 0, width: o + ix),
            _handle(1, 0, top: o + iy, bottom: o + iy, right: 0, width: o + ix),
          ],
          for (final (cx, cy) in const [(-1, -1), (1, -1), (-1, 1), (1, 1)])
            _handle(
              cx,
              cy,
              left: cx < 0 ? 0 : null,
              right: cx > 0 ? 0 : null,
              top: cy < 0 ? 0 : null,
              bottom: cy > 0 ? 0 : null,
              width: o + ix,
              height: o + iy,
            ),
          IgnorePointer(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final (x, y) in [
                  (o, o),
                  (w - o, o),
                  (o, h - o),
                  (w - o, h - o),
                ])
                  _knob(Offset(x, y), false),
                if (rect.width - 2 * ix >= 8) ...[
                  _knob(Offset(w / 2, o), true),
                  _knob(Offset(w / 2, h - o), true),
                ],
                if (rect.height - 2 * iy >= 8) ...[
                  _knob(Offset(o, h / 2), true),
                  _knob(Offset(w - o, h / 2), true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ordre d'empilement des cadres en mode « Encadrer » : le dernier reçoit
/// les poignées en priorité. Les cadres de [sentBack] (touchés sans glisser,
/// du plus récent au plus ancien) passent dessous ; [front] (la note
/// active) passe dessus.
List<String> stackFrames(
  List<String> keys, {
  List<String> sentBack = const [],
  String? front,
}) {
  final top = front != null && sentBack.contains(front) ? null : front;
  final back = [
    for (final k in sentBack)
      if (keys.contains(k) && k != top) k,
  ];
  return [
    ...back,
    for (final k in keys)
      if (!back.contains(k) && k != top) k,
    if (top != null && keys.contains(top)) top,
  ];
}
