import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Action d'un geste de l'Apple Pencil, telle que choisie dans les
/// réglages de l'iPad (Réglages > Apple Pencil).
enum PencilAction {
  /// Basculer entre la gomme et l'outil en cours.
  eraser,

  /// Revenir à l'outil précédent.
  previous,

  /// Afficher la palette d'outils.
  palette,
}

/// Geste reçu ; [at] : position du stylet au-dessus de l'écran, en
/// coordonnées globales (inconnue avant iOS 17.5).
typedef PencilGesture = ({PencilAction action, Offset? at});

/// Gestes de l'Apple Pencil (toucher deux fois ; presser, sur l'Apple
/// Pencil Pro), reçus du code natif iOS. Sans effet ailleurs.
abstract final class PencilGestures {
  static const _channel = MethodChannel('verger/pencil');
  static final _listeners = <ValueChanged<PencilGesture>>[];
  static bool _attached = false;

  static void addListener(ValueChanged<PencilGesture> listener) {
    _listeners.add(listener);
    if (_attached || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    _attached = true;
    _channel.setMethodCallHandler(_handle);
    _channel.invokeMethod<void>('attach').ignore();
  }

  static void removeListener(ValueChanged<PencilGesture> listener) =>
      _listeners.remove(listener);

  static Future<void> _handle(MethodCall call) async {
    if (call.method != 'gesture') return;
    final args = (call.arguments as Map).cast<String, Object?>();
    final action = switch (args['action']) {
      'eraser' => PencilAction.eraser,
      'previous' => PencilAction.previous,
      'palette' => PencilAction.palette,
      _ => null,
    };
    if (action == null) return;
    final (x, y) = (args['x'], args['y']);
    dispatch((
      action: action,
      at: x is num && y is num ? Offset(x.toDouble(), y.toDouble()) : null,
    ));
  }

  /// Transmet [gesture] aux auditeurs (aussi utilisé par les tests).
  @visibleForTesting
  static void dispatch(PencilGesture gesture) {
    for (final listener in List.of(_listeners)) {
      listener(gesture);
    }
  }
}
