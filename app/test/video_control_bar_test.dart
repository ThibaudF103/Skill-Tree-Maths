import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/ui/coverage.dart';
import 'package:verger/video/video_control_bar.dart';
import 'package:verger/video/youtube_player.dart';
import 'package:verger_core/verger_core.dart';

/// Lecteur factice : un état modifiable et le journal des commandes.
class FakePlayer implements YoutubePlayerController {
  VideoPlayback? state;
  final calls = <String>[];

  @override
  Future<VideoPlayback?> playback() async => state;

  @override
  Future<int?> currentMs() async => state?.positionMs;

  @override
  Future<int?> durationMs() async => state?.durationMs;

  @override
  Future<void> seek(int ms, {bool play = true}) async => calls.add('seek $ms');

  @override
  Future<void> playSegment(int startMs, int? endMs) async =>
      calls.add('segment $startMs');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> setMuted(bool muted) async => calls.add('muted $muted');

  @override
  Future<void> setRate(double rate) async {
    calls.add('rate $rate');
    final s = state!;
    state = (
      positionMs: s.positionMs,
      durationMs: s.durationMs,
      playing: s.playing,
      muted: s.muted,
      rate: rate,
    );
  }
}

VideoPlayback at(int ms, {bool playing = false}) => (
  positionMs: ms,
  durationMs: 100000,
  playing: playing,
  muted: false,
  rate: 1.0,
);

/// Extrait recto de 20 s à 40 s, note à 70 s.
final spans = <TimeSpan>[
  (
    start: 20000,
    end: 40000,
    role: AnchorRole.source,
    label: 'Théorème de Pythagore',
    id: 'i1',
  ),
  (start: 70000, end: null, role: null, label: 'Penser à revoir', id: 'n1'),
];

void main() {
  late FakePlayer player;
  TimeSpan? opened;

  setUp(() {
    player = FakePlayer();
    opened = null;
  });

  Future<void> pumpBar(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 1000,
              child: VideoControlBar(
                controller: player,
                spans: spans,
                rectoColor: Colors.blue,
                versoColor: Colors.orange,
                noteColor: Colors.green,
                onOpen: (s) => opened = s,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Point de la frise à [ms] (vidéo de 100 s, frise de 1000 px).
  Offset trackAt(WidgetTester tester, int ms) {
    final box = tester.getRect(find.byKey(const Key('video-track')));
    return Offset(box.left + ms / 100000 * box.width, box.bottom - 11);
  }

  testWidgets('avant le chargement : commandes inactives', (tester) async {
    await pumpBar(tester);
    expect(find.text('–:– / –:–'), findsOneWidget);
    final play = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.play_arrow),
    );
    expect(play.onPressed, isNull);
    expect(find.byKey(const Key('video-track')), findsNothing);
  });

  testWidgets('temps courant, durée et titre de l\'extrait en cours', (
    tester,
  ) async {
    player.state = at(5000);
    await pumpBar(tester);
    expect(find.text('0:05 / 1:40'), findsOneWidget);
    expect(find.byKey(const Key('video-current')), findsNothing);

    // La lecture avance dans l'extrait : son titre s'affiche, et l'ouvre.
    player.state = at(25000, playing: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('0:25 / 1:40'), findsOneWidget);
    expect(find.text('Théorème de Pythagore'), findsOneWidget);
    await tester.tap(find.byKey(const Key('video-current')));
    expect(opened?.id, 'i1');

    // Une note sans fin reste affichée quelques secondes.
    player.state = at(71000, playing: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Penser à revoir'), findsOneWidget);
    player.state = at(80000, playing: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('video-current')), findsNothing);
  });

  testWidgets('lecture, pause, son et vitesse', (tester) async {
    player.state = at(0);
    await pumpBar(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(player.calls, ['play']);
    expect(find.byIcon(Icons.pause), findsOneWidget);
    player.state = at(1000, playing: true);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.pause));
    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pump();
    expect(player.calls, ['play', 'pause', 'muted true']);

    await tester.tap(find.text('1×'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1,5×').last);
    await tester.pumpAndSettle();
    expect(player.calls.last, 'rate 1.5');
    expect(find.text('1,5×'), findsOneWidget);
  });

  testWidgets('un appui sur un extrait saute à son début, ailleurs au point '
      'touché', (tester) async {
    player.state = at(0);
    await pumpBar(tester);
    await tester.tapAt(trackAt(tester, 30000));
    await tester.pump();
    expect(player.calls, ['seek 20000']);
    // Le titre de l'extrait s'affiche sous la tête de lecture.
    expect(find.byKey(const Key('video-preview')), findsOneWidget);
    expect(find.text('0:20 · Théorème de Pythagore'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('video-preview')), findsNothing);

    await tester.tapAt(trackAt(tester, 55000));
    await tester.pump();
    expect(player.calls.last, 'seek 55000');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('glisser la tête de lecture', (tester) async {
    player.state = at(0);
    await pumpBar(tester);
    final gesture = await tester.startGesture(trackAt(tester, 10000));
    await gesture.moveTo(trackAt(tester, 20000));
    await gesture.moveTo(trackAt(tester, 30000));
    await tester.pump();
    // Pendant le glissement, temps et titre suivent le doigt.
    expect(find.text('0:30 / 1:40'), findsOneWidget);
    expect(find.text('0:30 · Théorème de Pythagore'), findsOneWidget);
    expect(player.calls, isEmpty);
    await gesture.up();
    await tester.pump();
    expect(player.calls, ['seek 30000']);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('le survol à la souris affiche le titre de l\'extrait', (
    tester,
  ) async {
    player.state = at(0);
    await pumpBar(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(trackAt(tester, 35000));
    await tester.pump();
    expect(find.text('0:35 · Théorème de Pythagore'), findsOneWidget);
    await mouse.moveTo(trackAt(tester, 60000));
    await tester.pump();
    expect(find.text('1:00'), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(find.byKey(const Key('video-preview')), findsNothing);
  });

  test('extraits actifs et libellés de vitesse', () {
    expect(spansAt(spans, 19999), isEmpty);
    expect(spansAt(spans, 20000).single.id, 'i1');
    expect(spansAt(spans, 72999).single.id, 'n1');
    expect(spansAt(spans, 73000), isEmpty);
    expect(rateLabel(1), '1×');
    expect(rateLabel(0.75), '0,75×');
  });
}
