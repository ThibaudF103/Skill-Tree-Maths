import 'dart:async';

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
  static bool _attaching = false;

  static void addListener(ValueChanged<PencilGesture> listener) {
    _listeners.add(listener);
    if (_attached ||
        _attaching ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    unawaited(_attach());
  }

  /// Branche l'interaction native ; en cas d'échec (vue pas encore prête),
  /// le prochain auditeur réessaie.
  static Future<void> _attach() async {
    _attaching = true;
    _channel.setMethodCallHandler(_handle);
    try {
      _attached = await _channel.invokeMethod<bool>('attach') ?? false;
    } on PlatformException {
      _attached = false;
    } on MissingPluginException {
      _attached = false;
    } finally {
      _attaching = false;
    }
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

  /// Transmet [gesture] au dernier auditeur inscrit : l'éditeur ouvert en
  /// dernier, celui qui est à l'écran (aussi utilisé par les tests).
  @visibleForTesting
  static void dispatch(PencilGesture gesture) {
    if (_listeners.isNotEmpty) _listeners.last(gesture);
  }
}
