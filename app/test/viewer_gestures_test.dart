import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/features/documents/viewer_gestures.dart';

/// Pas de PDFium dans les tests de widgets : les gestes de la visionneuse
/// sont testés sur leurs briques, posées sur une fausse visionneuse.
Widget host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 400, height: 400, child: child),
    ),
  ),
);

void main() {
  group('molette sur un cadre (#24)', () {
    testWidgets('le calque transmet la molette, sans doublon', (tester) async {
      final viewer = <Offset>[];
      final overlay = <Offset>[];
      var taps = 0;
      await tester.pumpWidget(
        host(
          Stack(
            children: [
              // La visionneuse, sous le calque.
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerSignal: (e) {
                    if (e is PointerScrollEvent) viewer.add(e.scrollDelta);
                  },
                ),
              ),
              ScrollPassThrough(
                onScroll: (e) => overlay.add(e.scrollDelta),
                child: Stack(
                  children: [
                    // Une zone encadrée cliquable.
                    Positioned(
                      left: 50,
                      top: 50,
                      width: 100,
                      height: 100,
                      child: GestureDetector(
                        onTap: () => taps++,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(color: Color(0x10000000)),
                        ),
                      ),
                    ),
                    FrameResizer(
                      rect: const Rect.fromLTWH(200, 200, 100, 100),
                      bounds: const Size(400, 400),
                      minSize: const Size(10, 10),
                      color: Colors.blue,
                      onResized: (_) {},
                      child: const SizedBox(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      Future<void> wheel(Offset at) async {
        await tester.sendEventToBinding(pointer.hover(at));
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, 40)));
      }

      // Sur la zone encadrée : le calque fait défiler.
      await wheel(const Offset(100, 100));
      expect(overlay, [const Offset(0, 40)]);
      expect(viewer, isEmpty);
      // Sur une poignée de redimensionnement aussi.
      await wheel(const Offset(300, 300));
      expect(overlay, hasLength(2));
      expect(viewer, isEmpty);
      // Ailleurs, la visionneuse reçoit la molette elle-même.
      await wheel(const Offset(350, 20));
      expect(overlay, hasLength(2));
      expect(viewer, [const Offset(0, 40)]);

      // La zone reste cliquable.
      await tester.tapAt(const Offset(100, 100));
      expect(taps, 1);
    });

    testWidgets('pavé tactile à deux doigts sur un cadre', (tester) async {
      final pans = <Offset>[];
      await tester.pumpWidget(
        host(
          ScrollPassThrough(
            onScroll: (_) {},
            onPan: pans.add,
            child: const SizedBox.expand(child: ColoredBox(color: Colors.red)),
          ),
        ),
      );
      final pointer = TestPointer(2, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(
        pointer.panZoomStart(const Offset(100, 100)),
      );
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(
          const Offset(100, 100),
          pan: const Offset(0, -30),
        ),
      );
      await tester.sendEventToBinding(pointer.panZoomEnd());
      expect(pans, [const Offset(0, -30)]);
    });
  });

  group('ordinateur : barre de défilement, clic molette (#30)', () {
    testWidgets('glisser le curseur, cliquer sur la piste', (tester) async {
      var offset = 0.0;
      Widget bar() => host(
        Align(
          alignment: Alignment.topRight,
          child: ViewerScrollbar(
            extent: 1000,
            viewport: 100,
            offset: offset,
            onScrollTo: (v) => offset = v,
          ),
        ),
      );
      await tester.pumpWidget(bar());
      final thumb = find.byKey(const ValueKey('viewer-scroll-thumb'));
      // Piste de 400 px, curseur de 40 px : 360 px pour 900 de document.
      expect(tester.getSize(thumb).height, 40);

      final gesture = await tester.startGesture(
        tester.getCenter(thumb),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 90));
      await gesture.up();
      expect(offset, closeTo(225, 0.01));

      // Clic sous le curseur : un écran plus bas.
      await tester.pumpWidget(bar());
      await tester.tapAt(const Offset(393, 390), kind: PointerDeviceKind.mouse);
      expect(offset, closeTo(325, 0.01));
      // Au-dessus : un écran plus haut.
      await tester.pumpWidget(bar());
      await tester.tapAt(const Offset(393, 5), kind: PointerDeviceKind.mouse);
      expect(offset, closeTo(225, 0.01));
    });

    testWidgets('rien à faire défiler : pas de barre', (tester) async {
      await tester.pumpWidget(
        host(
          ViewerScrollbar(
            extent: 100,
            viewport: 200,
            offset: 0,
            onScrollTo: (_) {},
          ),
        ),
      );
      expect(find.byKey(const ValueKey('viewer-scroll-thumb')), findsNothing);
    });

    test('vitesse proportionnelle à la distance, zone morte', () {
      expect(
        MiddleClickAutoscroll.velocityFor(const Offset(5, -8)),
        Offset.zero,
      );
      final near = MiddleClickAutoscroll.velocityFor(const Offset(0, 40));
      final far = MiddleClickAutoscroll.velocityFor(const Offset(0, 140));
      expect(near.dy, greaterThan(0));
      expect(far.dy, greaterThan(near.dy * 4));
      expect(
        MiddleClickAutoscroll.velocityFor(const Offset(-40, 0)).dx,
        -near.dy,
      );
    });

    testWidgets('clic molette maintenu : défile, puis s\'arrête', (
      tester,
    ) async {
      var scrolled = Offset.zero;
      var underTaps = 0;
      await tester.pumpWidget(
        host(
          MiddleClickAutoscroll(
            onScroll: (d) => scrolled += d,
            // La visionneuse : ne doit pas voir le geste du bouton du milieu.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => underTaps++,
              onPanStart: (_) => underTaps++,
            ),
          ),
        ),
      );
      final anchor = find.byKey(const ValueKey('autoscroll-anchor'));
      final gesture = await tester.startGesture(
        const Offset(200, 200),
        kind: PointerDeviceKind.mouse,
        buttons: kMiddleMouseButton,
      );
      await tester.pump();
      expect(anchor, findsOneWidget);
      expect(tester.getCenter(anchor), const Offset(200, 200));

      await gesture.moveTo(const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 500));
      expect(scrolled.dy, greaterThan(100));
      expect(scrolled.dx, 0);

      await gesture.up();
      await tester.pump();
      expect(anchor, findsNothing);
      final after = scrolled;
      await tester.pump(const Duration(milliseconds: 500));
      expect(scrolled, after);
      expect(underTaps, 0);
    });

    testWidgets('simple clic molette : défile jusqu\'au clic suivant', (
      tester,
    ) async {
      var scrolled = Offset.zero;
      var underTaps = 0;
      await tester.pumpWidget(
        host(
          MiddleClickAutoscroll(
            onScroll: (d) => scrolled += d,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => underTaps++,
            ),
          ),
        ),
      );
      final anchor = find.byKey(const ValueKey('autoscroll-anchor'));
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kMiddleMouseButton,
      );
      await mouse.addPointer(location: const Offset(200, 200));
      await mouse.down(const Offset(200, 200));
      await mouse.up();
      await tester.pump();
      expect(anchor, findsOneWidget);

      // La souris, sans bouton, s'éloigne vers le haut.
      await mouse.moveTo(const Offset(200, 100));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 500));
      expect(scrolled.dy, lessThan(-100));

      // Un clic gauche arrête, sans toucher la visionneuse.
      await tester.tapAt(const Offset(200, 100), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(anchor, findsNothing);
      final after = scrolled;
      await tester.pump(const Duration(milliseconds: 500));
      expect(scrolled, after);
      expect(underTaps, 0);

      // Ensuite, les clics reviennent à la visionneuse.
      await tester.tapAt(const Offset(200, 100), kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 500));
      expect(underTaps, 1);
      await mouse.removePointer();
    });
  });

  group('arrêt du défilement automatique (#30)', () {
    Future<(ValueGetter<Offset>, Finder)> startToggle(
      WidgetTester tester,
    ) async {
      var scrolled = Offset.zero;
      await tester.pumpWidget(
        host(
          MiddleClickAutoscroll(
            onScroll: (d) => scrolled += d,
            child: const SizedBox.expand(),
          ),
        ),
      );
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kMiddleMouseButton,
      );
      await mouse.addPointer(location: const Offset(200, 200));
      await mouse.down(const Offset(200, 200));
      await mouse.up();
      await mouse.moveTo(const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      addTearDown(mouse.removePointer);
      return (() => scrolled, find.byKey(const ValueKey('autoscroll-anchor')));
    }

    testWidgets('clic hors de la visionneuse', (tester) async {
      final (scrolled, anchor) = await startToggle(tester);
      expect(anchor, findsOneWidget);
      expect(scrolled().dy, greaterThan(0));
      await tester.tapAt(const Offset(600, 500), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(anchor, findsNothing);
      final after = scrolled();
      await tester.pump(const Duration(milliseconds: 300));
      expect(scrolled(), after);
    });

    testWidgets('touche Échap', (tester) async {
      final (scrolled, anchor) = await startToggle(tester);
      expect(anchor, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(anchor, findsNothing);
      final after = scrolled();
      await tester.pump(const Duration(milliseconds: 300));
      expect(scrolled(), after);
    });
  });

  group('redimensionner un cadre (#31)', () {
    Future<List<Rect>> pumpFrame(
      WidgetTester tester, {
      List<String>? drawn,
      Rect rect = const Rect.fromLTWH(100, 100, 100, 100),
      ValueNotifier<Offset>? shift,
      ValueNotifier<Size>? bounds,
      VoidCallback? onHandleTap,
    }) async {
      final resized = <Rect>[];
      shift ??= ValueNotifier(Offset.zero);
      bounds ??= ValueNotifier(const Size(400, 400));
      await tester.pumpWidget(
        host(
          ListenableBuilder(
            listenable: Listenable.merge([shift, bounds]),
            // La page, qui peut défiler (décalage) ou être zoomée (taille).
            builder: (context, _) => Transform.translate(
              offset: shift!.value,
              child: Stack(
                children: [
                  // Zone de tracé d'un nouveau cadre, sous les poignées.
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => drawn?.add('tracé'),
                    ),
                  ),
                  FrameResizer(
                    rect: rect,
                    bounds: bounds!.value,
                    minSize: const Size(20, 20),
                    color: Colors.blue,
                    onResized: resized.add,
                    onHandleTap: onHandleTap,
                    child: const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return resized;
    }

    testWidgets('coin et côtés, bornés à la page et à la taille minimale', (
      tester,
    ) async {
      final resized = await pumpFrame(tester);
      Future<void> drag(Offset from, Offset by, PointerDeviceKind kind) async {
        final g = await tester.startGesture(from, kind: kind);
        await g.moveBy(by / 2);
        await g.moveBy(by / 2);
        await g.up();
        await tester.pump();
      }

      // Coin bas droit, au stylet.
      await drag(
        const Offset(200, 200),
        const Offset(50, 30),
        PointerDeviceKind.stylus,
      );
      expect(resized.last, const Rect.fromLTRB(100, 100, 250, 230));

      // Côté gauche, au doigt, un peu à l'extérieur du bord : borné à la page.
      await drag(
        const Offset(90, 160),
        const Offset(-300, 40),
        PointerDeviceKind.touch,
      );
      expect(resized.last, const Rect.fromLTRB(0, 100, 250, 230));

      // Côté haut, à la souris, au-delà du bas : taille minimale.
      await drag(
        const Offset(120, 100),
        const Offset(0, 300),
        PointerDeviceKind.mouse,
      );
      expect(resized.last, const Rect.fromLTRB(0, 210, 250, 230));
    });

    testWidgets('l\'intérieur du cadre reste libre pour tracer', (
      tester,
    ) async {
      final drawn = <String>[];
      final resized = await pumpFrame(tester, drawn: drawn);
      final g = await tester.startGesture(
        const Offset(150, 150),
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(30, 30));
      await g.up();
      expect(drawn, ['tracé']);
      expect(resized, isEmpty);
    });

    testWidgets('curseurs de redimensionnement à la souris', (tester) async {
      await pumpFrame(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(380, 380));
      addTearDown(mouse.removePointer);
      Future<MouseCursor?> cursorAt(Offset at) async {
        await mouse.moveTo(at);
        await tester.pump();
        return RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1);
      }

      expect(
        await cursorAt(const Offset(100, 100)),
        SystemMouseCursors.resizeUpLeftDownRight,
      );
      expect(
        await cursorAt(const Offset(200, 100)),
        SystemMouseCursors.resizeUpRightDownLeft,
      );
      expect(
        await cursorAt(const Offset(150, 200)),
        SystemMouseCursors.resizeUpDown,
      );
      expect(
        await cursorAt(const Offset(200, 150)),
        SystemMouseCursors.resizeLeftRight,
      );
      expect(await cursorAt(const Offset(150, 150)), SystemMouseCursors.basic);
    });

    testWidgets('le pavé tactile ne redimensionne pas', (tester) async {
      final resized = await pumpFrame(tester);
      final pointer = TestPointer(3, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(
        pointer.panZoomStart(const Offset(200, 200)),
      );
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(
          const Offset(200, 200),
          pan: const Offset(40, 40),
        ),
      );
      await tester.sendEventToBinding(pointer.panZoomEnd());
      await tester.pump();
      expect(resized, isEmpty);
    });

    testWidgets('petit cadre, ou près du bord intérieur : on trace', (
      tester,
    ) async {
      Future<List<String>> drawAt(Rect rect, Offset at) async {
        final drawn = <String>[];
        await pumpFrame(tester, drawn: drawn, rect: rect);
        final g = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
        await g.moveBy(const Offset(20, 20));
        await g.up();
        await tester.pump();
        return drawn;
      }

      // Cadre de 20 × 20 : son centre reste libre.
      expect(
        await drawAt(
          const Rect.fromLTWH(100, 100, 20, 20),
          const Offset(110, 110),
        ),
        ['tracé'],
      );
      // À 15 px à l'intérieur du bord gauche d'un grand cadre.
      expect(
        await drawAt(
          const Rect.fromLTWH(100, 100, 100, 100),
          const Offset(115, 150),
        ),
        ['tracé'],
      );
      // À 15 px à l'extérieur : c'est une poignée.
      expect(
        await drawAt(
          const Rect.fromLTWH(100, 100, 100, 100),
          const Offset(85, 150),
        ),
        isEmpty,
      );
    });

    test('jamais hors de la page, même à la taille minimale', () {
      const page = Size(400, 400);
      const min = Size(20, 20);
      // Cadre collé au bord droit, plus étroit que le minimum.
      var r = FrameResizer.resize(
        const Rect.fromLTRB(390, 10, 400, 100),
        1,
        0,
        const Offset(50, 0),
        page,
        min,
      );
      expect(r, const Rect.fromLTRB(380, 10, 400, 100));
      r = FrameResizer.resize(
        const Rect.fromLTRB(0, 395, 100, 400),
        0,
        -1,
        const Offset(0, 30),
        page,
        min,
      );
      expect(r, const Rect.fromLTRB(0, 380, 100, 400));
      r = FrameResizer.resize(
        const Rect.fromLTRB(-5, 0, 420, 50),
        -1,
        1,
        const Offset(-10, 10),
        page,
        min,
      );
      expect(r, const Rect.fromLTRB(0, 0, 400, 60));
    });

    testWidgets('défilement pendant le geste : suit la page', (tester) async {
      final shift = ValueNotifier(Offset.zero);
      final resized = await pumpFrame(tester, shift: shift);
      final g = await tester.startGesture(
        const Offset(200, 200),
        kind: PointerDeviceKind.touch,
      );
      await g.moveBy(const Offset(0, 20));
      await g.moveBy(const Offset(0, 10));
      // La page remonte de 50 px sous le doigt immobile.
      shift.value = const Offset(0, -50);
      await tester.pump();
      await g.moveBy(Offset.zero);
      await g.up();
      await tester.pump();
      expect(resized.single, const Rect.fromLTRB(100, 100, 200, 280));
    });

    testWidgets('zoom pendant le geste : annulé', (tester) async {
      final bounds = ValueNotifier(const Size(400, 400));
      final resized = await pumpFrame(tester, bounds: bounds);
      final g = await tester.startGesture(
        const Offset(200, 200),
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(30, 30));
      bounds.value = const Size(800, 800);
      await tester.pump();
      await g.moveBy(const Offset(30, 30));
      await g.up();
      await tester.pump();
      expect(resized, isEmpty);
    });

    testWidgets('poignée touchée sans glisser', (tester) async {
      var taps = 0;
      final resized = await pumpFrame(tester, onHandleTap: () => taps++);
      await tester.tapAt(const Offset(200, 200));
      await tester.pump(const Duration(milliseconds: 500));
      expect(taps, 1);
      expect(resized, isEmpty);
    });

    test('cadres superposés : ordre des poignées', () {
      const keys = ['note-a', 'anchor-b', 'anchor-c'];
      // Par défaut, le dernier cadre a la priorité.
      expect(stackFrames(keys), keys);
      // La note active passe dessus.
      expect(stackFrames(keys, front: 'note-a'), [
        'anchor-b',
        'anchor-c',
        'note-a',
      ]);
      // Un cadre touché sans glisser passe dessous, même la note active.
      expect(stackFrames(keys, sentBack: ['anchor-c']), [
        'anchor-c',
        'note-a',
        'anchor-b',
      ]);
      expect(stackFrames(keys, sentBack: ['note-a'], front: 'note-a'), [
        'note-a',
        'anchor-b',
        'anchor-c',
      ]);
      // Clés disparues ignorées.
      expect(stackFrames(['anchor-b'], sentBack: ['x'], front: 'y'), [
        'anchor-b',
      ]);
    });
  });
}
