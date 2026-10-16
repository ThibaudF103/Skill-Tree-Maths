import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:verger/video/youtube.dart';
import 'package:verger/video/youtube_player.dart';

void main() {
  test('identifiant d\'une vidéo depuis toutes les formes d\'adresse', () {
    const id = 'dQw4w9WgXcQ';
    for (final url in [
      id,
      'https://www.youtube.com/watch?v=$id',
      'https://youtube.com/watch?v=$id&list=PL1&t=42',
      'youtube.com/watch?v=$id',
      'https://m.youtube.com/watch?v=$id',
      'https://youtu.be/$id?si=abc',
      'https://www.youtube.com/shorts/$id',
      'https://www.youtube.com/embed/$id?start=10',
      'https://www.youtube-nocookie.com/embed/$id',
      'https://www.youtube.com/live/$id',
    ]) {
      expect(youtubeId(url), id, reason: url);
    }
    for (final bad in [
      '',
      'https://vimeo.com/123',
      'https://www.youtube.com/watch?v=court',
      'https://www.youtube.com/@chaine',
    ]) {
      expect(youtubeId(bad), isNull, reason: bad);
    }
  });

  test('moment de départ indiqué dans l\'adresse', () {
    expect(youtubeStartMs('https://youtu.be/dQw4w9WgXcQ?t=90'), 90000);
    expect(youtubeStartMs('https://youtu.be/dQw4w9WgXcQ?t=1m30s'), 90000);
    expect(youtubeStartMs('https://youtu.be/dQw4w9WgXcQ?t=1h2m3s'), 3723000);
    expect(youtubeStartMs('https://youtube.com/embed/x?start=12'), 12000);
    expect(youtubeStartMs('https://youtu.be/dQw4w9WgXcQ'), isNull);
  });

  test('titre via oEmbed, null en cas d\'échec', () async {
    final ok = MockClient(
      (_) async =>
          http.Response.bytes(utf8.encode('{"title":"Cours 1 — Suites"}'), 200),
    );
    expect(await youtubeTitle('dQw4w9WgXcQ', client: ok), 'Cours 1 — Suites');
    final ko = MockClient((_) async => http.Response('', 404));
    expect(await youtubeTitle('dQw4w9WgXcQ', client: ko), isNull);
  });

  test('adresse du lecteur intégré', () {
    final url = Uri.parse(
      embedUrl('dQw4w9WgXcQ', startMs: 90500, origin: 'https://verger.app'),
    );
    expect(url.path, '/embed/dQw4w9WgXcQ');
    expect(url.queryParameters['start'], '90');
    expect(url.queryParameters['enablejsapi'], '1');
    expect(url.queryParameters['origin'], 'https://verger.app');
    expect(
      Uri.parse(embedUrl('dQw4w9WgXcQ')).queryParameters,
      isNot(contains('start')),
    );
  });
}
