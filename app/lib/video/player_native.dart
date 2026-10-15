import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'youtube_player.dart';

/// Lecteur dans une vue web (Windows, iPad…) : la vue ouvre directement le
/// lecteur intégré de YouTube, avec un référent (exigé par YouTube), et
/// l'application pilote son élément `<video>`.
class PlatformYoutubeController implements YoutubePlayerController {
  InAppWebViewController? _web;

  Future<Object?> _js(String source) async =>
      _web?.evaluateJavascript(source: source);

  @override
  Future<int?> currentMs() async {
    final value = await _js('window.vergerTime ? window.vergerTime() : null');
    return value is num ? (value * 1000).round() : null;
  }

  @override
  Future<void> seek(int ms, {bool play = true}) =>
      _js('window.vergerSeek && window.vergerSeek(${ms / 1000}, $play)');

  @override
  Future<void> playSegment(int startMs, int? endMs) => _js(
    'window.vergerSegment && window.vergerSegment(${startMs / 1000}, '
    '${endMs == null ? 'null' : endMs / 1000})',
  );

  @override
  Future<void> pause() => _js('window.vergerPause && window.vergerPause()');
}

/// Fonctions injectées dans la page du lecteur.
const _bridge = '''
(function () {
  if (window.vergerTime) return;
  function video() { return document.querySelector('video'); }
  window.vergerStopAt = null;
  window.vergerTime = function () { var v = video(); return v ? v.currentTime : null; };
  window.vergerSeek = function (s, play) {
    var v = video(); if (!v) return;
    v.currentTime = s; if (play) v.play();
  };
  window.vergerPause = function () { var v = video(); if (v) v.pause(); };
  window.vergerSegment = function (a, b) { window.vergerStopAt = b; window.vergerSeek(a, true); };
  setInterval(function () {
    var v = video();
    if (v && window.vergerStopAt !== null && v.currentTime >= window.vergerStopAt) {
      v.pause(); window.vergerStopAt = null;
    }
  }, 250);
})();
''';

Widget buildPlayer({
  required String videoId,
  required PlatformYoutubeController controller,
  required int startMs,
  required int? endMs,
}) => _NativePlayer(
  videoId: videoId,
  controller: controller,
  startMs: startMs,
  endMs: endMs,
);

class _NativePlayer extends StatefulWidget {
  const _NativePlayer({
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
  State<_NativePlayer> createState() => _NativePlayerState();
}

class _NativePlayerState extends State<_NativePlayer> {
  @override
  void dispose() {
    widget.controller._web = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(
          embedUrl(widget.videoId, startMs: widget.startMs, origin: appOrigin),
        ),
        headers: const {'Referer': '$appOrigin/'},
      ),
      initialSettings: InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
      ),
      onWebViewCreated: (web) => widget.controller._web = web,
      onLoadStop: (web, _) async {
        await web.evaluateJavascript(source: _bridge);
        final end = widget.endMs;
        if (end != null) {
          await web.evaluateJavascript(
            source: 'window.vergerStopAt = ${end / 1000};',
          );
        }
      },
    );
  }
}
