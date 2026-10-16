import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'youtube_player.dart';

/// Lecteur de la version web : iframe du lecteur intégré de YouTube, pilotée
/// par son protocole `postMessage` (celui de l'API IFrame).
class PlatformYoutubeController implements YoutubePlayerController {
  web.HTMLIFrameElement? _frame;
  double? _time;
  double? _duration;
  double? _stopAt;

  void _post(String func, [List<Object?> args = const []]) {
    _frame?.contentWindow?.postMessage(
      jsonEncode({
        'event': 'command',
        'func': func,
        'args': args,
        'channel': 'widget',
      }).toJS,
      '*'.toJS,
    );
  }

  void _onMessage(Map<String, Object?> message) {
    final info = message['info'];
    if (info is Map && info['duration'] is num) {
      final duration = (info['duration'] as num).toDouble();
      if (duration > 0) _duration = duration;
    }
    if (info is Map && info['currentTime'] is num) {
      _time = (info['currentTime'] as num).toDouble();
      final stop = _stopAt;
      if (stop != null && _time! >= stop) {
        _stopAt = null;
        _post('pauseVideo');
      }
    }
  }

  @override
  Future<int?> currentMs() async =>
      _time == null ? null : (_time! * 1000).round();

  @override
  Future<int?> durationMs() async =>
      _duration == null ? null : (_duration! * 1000).round();

  @override
  Future<void> seek(int ms, {bool play = true}) async {
    // Un saut libre annule l'arrêt programmé d'un extrait.
    _stopAt = null;
    _jump(ms, play);
  }

  void _jump(int ms, bool play) {
    _time = ms / 1000;
    _post('seekTo', [ms / 1000, true]);
    if (play) _post('playVideo');
  }

  @override
  Future<void> playSegment(int startMs, int? endMs) async {
    _stopAt = endMs == null ? null : endMs / 1000;
    _jump(startMs, true);
  }

  @override
  Future<void> pause() async => _post('pauseVideo');
}

var _views = 0;

Widget buildPlayer({
  required String videoId,
  required PlatformYoutubeController controller,
  required int startMs,
  required int? endMs,
}) => _WebPlayer(
  videoId: videoId,
  controller: controller,
  startMs: startMs,
  endMs: endMs,
);

class _WebPlayer extends StatefulWidget {
  const _WebPlayer({
    required this.videoId,
    required this.controller,
    required this.startMs,
    required this.endMs,
  });

  final String videoId;
  final PlatformYoutubeController controller;
  final int startMs;
  final int? endMs;

  @override
  State<_WebPlayer> createState() => _WebPlayerState();
}

class _WebPlayerState extends State<_WebPlayer> {
  late final String _viewType = 'verger-youtube-${_views++}';
  late final JSFunction _listener = ((web.Event event) {
    final message = event as web.MessageEvent;
    final frame = widget.controller._frame;
    if (frame == null || !message.origin.contains('youtube')) return;
    final data = message.data;
    if (data == null || !data.isA<JSString>()) return;
    try {
      final decoded = jsonDecode((data as JSString).toDart);
      if (decoded is Map) {
        widget.controller._onMessage(decoded.cast<String, Object?>());
      }
    } on FormatException {
      // Message étranger au lecteur.
    }
  }).toJS;

  @override
  void initState() {
    super.initState();
    final controller = widget.controller;
    controller._stopAt = widget.endMs == null ? null : widget.endMs! / 1000;
    controller._time = widget.startMs / 1000;
    final frame = web.HTMLIFrameElement()
      ..src = embedUrl(
        widget.videoId,
        startMs: widget.startMs,
        origin: web.window.location.origin,
      )
      ..allow = 'autoplay; encrypted-media; picture-in-picture; fullscreen'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    frame.addEventListener(
      'load',
      ((web.Event _) {
        // Demande au lecteur d'envoyer son état (temps courant…).
        frame.contentWindow?.postMessage(
          jsonEncode({
            'event': 'listening',
            'id': _viewType,
            'channel': 'widget',
          }).toJS,
          '*'.toJS,
        );
      }).toJS,
    );
    controller._frame = frame;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => frame);
    web.window.addEventListener('message', _listener);
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _listener);
    widget.controller._frame = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
