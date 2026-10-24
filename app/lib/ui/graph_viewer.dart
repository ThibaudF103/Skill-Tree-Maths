import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// [InteractiveViewer] pensé aussi pour la souris et le pavé tactile.
///
/// - molette : défilement vertical ; Maj + molette ou défilement latéral :
///   horizontal ;
/// - Ctrl (ou Cmd) + molette : zoom autour du pointeur ;
/// - pavé tactile (deux doigts) : déplacement libre, pincer pour zoomer ;
/// - toucher et stylet : inchangés (glisser, pincer).
class GraphViewer extends StatefulWidget {
  const GraphViewer({
    super.key,
    required this.child,
    this.transformationController,
    this.constrained = true,
    this.minScale = 0.8,
    this.maxScale = 2.5,
    this.boundaryMargin = EdgeInsets.zero,
  });

  final Widget child;
  final TransformationController? transformationController;
  final bool constrained;
  final double minScale;
  final double maxScale;
  final EdgeInsets boundaryMargin;

  @override
  State<GraphViewer> createState() => _GraphViewerState();
}

class _GraphViewerState extends State<GraphViewer> {
  final _childKey = GlobalKey();
  TransformationController? _ownController;

  TransformationController get _controller =>
      widget.transformationController ??
      (_ownController ??= TransformationController());

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  /// Reçu avant l'[InteractiveViewer], qui zoome sur toute molette : hors
  /// Ctrl, on note la transformation pour la rétablir une fois l'évènement
  /// distribué, puis on fait défiler à la place.
  void _onPointerSignal(PointerSignalEvent event) {
    // Le défilement « trackpad » (web) est déjà un déplacement.
    if (event is! PointerScrollEvent ||
        event.kind == PointerDeviceKind.trackpad) {
      return;
    }
    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed || keys.isMetaPressed) return;
    var delta = event.scrollDelta;
    if (keys.isShiftPressed && delta.dx == 0) delta = Offset(delta.dy, 0);
    final before = _controller.value.clone();
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (!mounted) return;
      _controller.value = _panned(before, delta);
    });
  }

  /// [matrix] décalée de -[delta] (pixels écran), sans sortir des bornes :
  /// le contenu élargi de [GraphViewer.boundaryMargin] couvre la vue, comme
  /// pour un glissé dans l'[InteractiveViewer].
  Matrix4 _panned(Matrix4 matrix, Offset delta) {
    final viewport = (context.findRenderObject()! as RenderBox).size;
    final content =
        (_childKey.currentContext!.findRenderObject()! as RenderBox).size;
    final bounds = widget.boundaryMargin.inflateRect(Offset.zero & content);
    final scale = matrix.getMaxScaleOnAxis();
    final t = matrix.getTranslation();
    // Sur un axe où le contenu est plus petit que la vue, on ne bouge pas.
    double clampAxis(
      double current,
      double d,
      double view,
      double a,
      double b,
    ) {
      final low = view - b * scale;
      final high = -a * scale;
      return low <= high ? (current - d).clamp(low, high) : current;
    }

    return matrix.clone()..setTranslationRaw(
      clampAxis(t.x, delta.dx, viewport.width, bounds.left, bounds.right),
      clampAxis(t.y, delta.dy, viewport.height, bounds.top, bounds.bottom),
      t.z,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            transformationController: _controller,
            constrained: widget.constrained,
            minScale: widget.minScale,
            maxScale: widget.maxScale,
            boundaryMargin: widget.boundaryMargin,
            child: KeyedSubtree(key: _childKey, child: widget.child),
          ),
        ),
        // Au-dessus et transparent : touché en premier, il laisse passer les
        // évènements vers l'InteractiveViewer.
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerSignal: _onPointerSignal,
          ),
        ),
      ],
    );
  }
}
