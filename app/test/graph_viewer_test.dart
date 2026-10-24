import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/ui/graph_viewer.dart';

/// Un contenu de 2000 × 1500 dans une vue de 800 × 600.
Future<TransformationController> pumpViewer(WidgetTester tester) async {
  final controller = TransformationController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: GraphViewer(
        transformationController: controller,
        constrained: false,
        minScale: 0.2,
        maxScale: 2,
        child: const SizedBox(width: 2000, height: 1500),
      ),
    ),
  );
  return controller;
}

const center = Offset(400, 300);

Offset translation(TransformationController c) {
  final t = c.value.getTranslation();
  return Offset(t.x, t.y);
}

double scale(TransformationController c) => c.value.getMaxScaleOnAxis();

Future<void> wheel(
  WidgetTester tester,
  Offset delta, {
  Offset at = center,
}) async {
  final mouse = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(at));
  await tester.sendEventToBinding(mouse.scroll(delta));
  await tester.pump();
}

void main() {
  testWidgets('molette : défilement vertical, borné au contenu', (
    tester,
  ) async {
    final c = await pumpViewer(tester);
    await wheel(tester, const Offset(0, 100));
    expect(translation(c), const Offset(0, -100));
    expect(scale(c), 1);

    await wheel(tester, const Offset(0, -300));
    expect(translation(c), Offset.zero);

    await wheel(tester, const Offset(0, 5000));
    expect(translation(c), const Offset(0, -900));
  });

  testWidgets('Maj + molette et défilement latéral : horizontal', (
    tester,
  ) async {
    final c = await pumpViewer(tester);
    await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await wheel(tester, const Offset(0, 100));
    await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(translation(c), const Offset(-100, 0));

    await wheel(tester, const Offset(60, 0));
    expect(translation(c), const Offset(-160, 0));

    // Maj + défilement oblique : rien de vertical.
    await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await wheel(tester, const Offset(40, 100));
    await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(translation(c), const Offset(-200, 0));
    expect(scale(c), 1);
  });

  testWidgets('Ctrl + molette : zoom autour du pointeur, borné', (
    tester,
  ) async {
    final c = await pumpViewer(tester);
    await wheel(tester, const Offset(0, 200));
    // Pointeur loin du centre : le point de la scène sous lui ne bouge pas.
    const pointer = Offset(150, 120);
    final anchor = c.toScene(pointer);

    await simulateKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await wheel(tester, const Offset(0, -100), at: pointer);
    expect(scale(c), greaterThan(1));
    expect(c.toScene(pointer).dx, moreOrLessEquals(anchor.dx));
    expect(c.toScene(pointer).dy, moreOrLessEquals(anchor.dy));

    for (var i = 0; i < 10; i++) {
      await wheel(tester, const Offset(0, -100));
    }
    expect(scale(c), moreOrLessEquals(2));

    for (var i = 0; i < 20; i++) {
      await wheel(tester, const Offset(0, 100));
    }
    await simulateKeyUpEvent(LogicalKeyboardKey.controlLeft);
    // Le contenu ne peut pas devenir plus petit que la vue.
    expect(scale(c), moreOrLessEquals(0.4));
  });

  testWidgets('pavé tactile : deux doigts pour se déplacer, pincer', (
    tester,
  ) async {
    final c = await pumpViewer(tester);
    final pad = TestPointer(2, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pad.panZoomStart(center));
    for (var i = 1; i <= 10; i++) {
      await tester.sendEventToBinding(
        pad.panZoomUpdate(center, pan: Offset(-10.0 * i, -8.0 * i)),
      );
      await tester.pump();
    }
    await tester.sendEventToBinding(pad.panZoomEnd());
    await tester.pumpAndSettle();
    expect(translation(c).dx, lessThan(-20));
    expect(translation(c).dy, lessThan(-20));
    expect(scale(c), 1);

    await tester.sendEventToBinding(pad.panZoomStart(center));
    for (var i = 1; i <= 10; i++) {
      await tester.sendEventToBinding(
        pad.panZoomUpdate(center, scale: 1 + i / 20),
      );
      await tester.pump();
    }
    await tester.sendEventToBinding(pad.panZoomEnd());
    await tester.pumpAndSettle();
    expect(scale(c), greaterThan(1.2));
  });

  testWidgets('toucher : glisser déplace toujours', (tester) async {
    final c = await pumpViewer(tester);
    await tester.dragFrom(center, const Offset(-200, -150));
    await tester.pumpAndSettle();
    expect(translation(c).dx, lessThan(-100));
    expect(translation(c).dy, lessThan(-100));
    expect(scale(c), 1);
  });
}
