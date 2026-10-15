import 'dart:convert';

import 'package:http/http.dart' as http;

/// Identifiant d'une vidéo YouTube à partir d'une adresse (watch, youtu.be,
/// shorts, embed, live) ou de l'identifiant lui-même ; `null` sinon.
String? youtubeId(String input) {
  final text = input.trim();
  final id = RegExp(r'^[A-Za-z0-9_-]{11}$');
  if (id.hasMatch(text)) return text;
  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  if (uri == null) return null;
  final host = uri.host.replaceFirst(RegExp(r'^(www\.|m\.|music\.)'), '');
  String? candidate;
  if (host == 'youtu.be') {
    candidate = uri.pathSegments.firstOrNull;
  } else if (host == 'youtube.com' || host == 'youtube-nocookie.com') {
    final segments = uri.pathSegments;
    if (segments.firstOrNull == 'watch') {
      candidate = uri.queryParameters['v'];
    } else if (segments.length >= 2 &&
        const {'embed', 'shorts', 'live', 'v'}.contains(segments.first)) {
      candidate = segments[1];
    }
  }
  return candidate != null && id.hasMatch(candidate) ? candidate : null;
}

/// Moment de départ indiqué dans l'adresse (`t=90`, `t=1m30s`, `start=90`),
/// en millisecondes ; `null` sinon.
int? youtubeStartMs(String input) {
  final uri = Uri.tryParse(input.trim());
  final t = uri?.queryParameters['t'] ?? uri?.queryParameters['start'];
  if (t == null) return null;
  final plain = int.tryParse(t.replaceAll('s', ''));
  if (plain != null) return plain * 1000;
  final m = RegExp(r'^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$').firstMatch(t);
  if (m == null) return null;
  int part(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
  return ((part(1) * 60 + part(2)) * 60 + part(3)) * 1000;
}

/// Adresse canonique d'une vidéo.
String youtubeUrl(String id) => 'https://www.youtube.com/watch?v=$id';

/// Titre de la vidéo (service oEmbed de YouTube), ou `null` hors ligne.
Future<String?> youtubeTitle(String id, {http.Client? client}) async {
  final uri = Uri.https('www.youtube.com', '/oembed', {
    'url': youtubeUrl(id),
    'format': 'json',
  });
  try {
    final response = await (client ?? http.Client())
        .get(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    return json is Map ? json['title'] as String? : null;
  } catch (_) {
    return null;
  }
}
