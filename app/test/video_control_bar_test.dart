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
  Future<void> playSegment(int startMs, int? endMs, {bool play = true}) async =>
      calls.add('segment $startMs $endMs $play');

  @override
  Future<void> setCaptions(bool on) async => calls.add('captions $on');

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

  Future<void> pumpBar(
    WidgetTester tester, {
    (int, int?)? selection,
    bool stopAtSelectionEnd = false,
    List<Widget> actions = const [],
  }) async {
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
                selection: selection,
                stopAtSelectionEnd: stopAtSelectionEnd,
                actions: actions,
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

  testWidgets('un appui saute au point touché, même dans un extrait', (
    tester,
  ) async {
    player.state = at(0);
    await pumpBar(tester);
    await tester.tapAt(trackAt(tester, 30000));
    await tester.pump();
    expect(player.calls, ['seek 30000']);
    // Le titre de l'extrait s'affiche sous la tête de lecture.
    expect(find.byKey(const Key('video-preview')), findsOneWidget);
    expect(find.text('0:30 · Théorème de Pythagore'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('video-preview')), findsNothing);

    await tester.tapAt(trackAt(tester, 55000));
    await tester.pump();
    expect(player.calls.last, 'seek 55000');
    await tester.pump(const Duration(seconds: 3));

    // Près d'une note ponctuelle : saut sur la note.
    await tester.tapAt(trackAt(tester, 70200));
    await tester.pump();
    expect(player.calls.last, 'seek 70000');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('le bouton voisin du titre reprend l\'extrait au début', (
    tester,
  ) async {
    player.state = at(30000, playing: true);
    await pumpBar(tester);
    await tester.tap(find.byKey(const Key('video-current-start')));
    await tester.pump();
    expect(player.calls, ['seek 20000']);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('après un saut ou une pause, l\'ancien état relevé ne fait pas '
      'reculer la tête de lecture', (tester) async {
    player.state = at(10000, playing: true);
    await pumpBar(tester);
    await tester.tapAt(trackAt(tester, 55000));
    await tester.tap(find.byIcon(Icons.pause));
    // Le lecteur rend encore l'ancien état pendant deux relevés.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('0:55 / 1:40'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    // Le lecteur rattrape la commande : son état fait foi de nouveau.
    player.state = at(55100);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('0:55 / 1:40'), findsOneWidget);
    player.state = at(56000);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('0:56 / 1:40'), findsOneWidget);

    // Sans réponse du lecteur, l'état relevé reprend la main au bout de
    // 600 ms.
    await tester.tapAt(trackAt(tester, 90000));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('1:30 / 1:40'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('0:56 / 1:40'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('« Revoir l\'extrait » : un saut dans l\'extrait garde l\'arrêt '
      'à sa fin', (tester) async {
    player.state = at(20000);
    await pumpBar(tester, selection: (20000, 40000), stopAtSelectionEnd: true);
    await tester.tapAt(trackAt(tester, 30000));
    await tester.pump();
    expect(player.calls, ['segment 30000 40000 false']);
    await tester.tapAt(trackAt(tester, 60000));
    await tester.pump();
    expect(player.calls.last, 'seek 60000');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('sous-titres et boutons ajoutés', (tester) async {
    player.state = at(0);
    var marked = 0;
    await pumpBar(
      tester,
      actions: [
        IconButton(
          icon: const Icon(Icons.first_page),
          onPressed: () => marked++,
        ),
      ],
    );
    await tester.tap(find.byIcon(Icons.closed_caption_off_outlined));
    await tester.pump();
    expect(player.calls, ['captions true']);
    await tester.tap(find.byIcon(Icons.closed_caption));
    await tester.pump();
    expect(player.calls.last, 'captions false');
    await tester.tap(find.byIcon(Icons.first_page));
    expect(marked, 1);
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
