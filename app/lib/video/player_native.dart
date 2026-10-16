import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'youtube_player.dart';

/// Lecteur dans une vue web (Windows, iPad…).
///
/// YouTube refuse un lecteur intégré sans page hôte identifiable
/// (« erreur 153 ») : l'application sert donc elle-même, sur
/// `http://localhost`, une petite page qui intègre le lecteur avec l'API
/// IFrame officielle, comme le ferait un site. La vue web ouvre cette page
/// et l'application pilote le lecteur par les fonctions `verger…` de la page.
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

/// Page hôte du lecteur : paramètres `v` (vidéo), `start` et `end` (s).
const _page = r'''<!doctype html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;height:100%;background:#000;overflow:hidden}
#player{width:100%;height:100%}</style></head>
<body><div id="player"></div>
<script>
var q = new URLSearchParams(location.search);
var start = parseFloat(q.get('start') || '0');
var end = q.get('end') ? parseFloat(q.get('end')) : null;
var player = null;
window.vergerStopAt = end;
window.vergerTime = function () { return player && player.getCurrentTime ? player.getCurrentTime() : null; };
window.vergerDuration = function () { return player && player.getDuration ? player.getDuration() : null; };
function jump(s, play) {
  if (!player || !player.seekTo) return;
  player.seekTo(s, true); if (play) player.playVideo();
}
// Un saut libre annule l'arrêt programmé d'un extrait.
window.vergerSeek = function (s, play) { window.vergerStopAt = null; jump(s, play); };
window.vergerPause = function () { if (player && player.pauseVideo) player.pauseVideo(); };
window.vergerSegment = function (a, b) { window.vergerStopAt = b; jump(a, true); };
setInterval(function () {
  var t = window.vergerTime();
  if (t !== null && window.vergerStopAt !== null && t >= window.vergerStopAt) {
    window.vergerPause(); window.vergerStopAt = null;
  }
}, 250);
function onYouTubeIframeAPIReady() {
  player = new YT.Player('player', {
    videoId: q.get('v'),
    playerVars: { start: Math.floor(start), playsinline: 1, rel: 0, origin: location.origin },
  });
}
</script>
<script src="https://www.youtube.com/iframe_api"></script>
</body></html>''';

/// Serveur local de la page hôte, démarré au premier lecteur.
Future<int>? _port;

/// Seule l'adresse de bouclage écoute : la page n'est pas visible du réseau.
/// `localhost` pouvant désigner 127.0.0.1 ou ::1, les deux écoutent.
Future<int> _serve() => _port ??= () async {
  void handle(HttpRequest request) {
    final response = request.response;
    if (request.uri.path == '/player') {
      response.headers.contentType = ContentType.html;
      response.add(utf8.encode(_page));
    } else {
      response.statusCode = HttpStatus.notFound;
    }
    response.close();
  }

  final v4 = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  v4.listen(handle);
  try {
    (await HttpServer.bind(
      InternetAddress.loopbackIPv6,
      v4.port,
    )).listen(handle);
  } on SocketException {
    // Pas d'IPv6 sur cette machine : 127.0.0.1 suffit.
  }
  return v4.port;
}();

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
  late final Future<int> _ready = _serve();

  @override
  void dispose() {
    widget.controller._web = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _ready,
      builder: (context, port) {
        if (port.hasError) {
          return Center(
            child: Text(
              'Lecteur indisponible : ${port.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }
        if (!port.hasData) return const SizedBox.shrink();
        final url = Uri.http('localhost:${port.data}', '/player', {
          'v': widget.videoId,
          'start': '${widget.startMs / 1000}',
          if (widget.endMs != null) 'end': '${widget.endMs! / 1000}',
        });
        return InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(url.toString())),
          initialSettings: InAppWebViewSettings(
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
          ),
          onWebViewCreated: (web) => widget.controller._web = web,
        );
      },
    );
  }
}
