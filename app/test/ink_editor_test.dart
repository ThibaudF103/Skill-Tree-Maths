import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/features/notes/ink_editor_page.dart';
import 'package:verger/features/notes/ink_view.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'test_app.dart';

InkPoint pt(double x, double y) => (x: x, y: y, pressure: 0.5);

Future<void> seed(VergerStore store) async {
  final tree = await store.createNode(title: 'Analyse');
  await store.createItem(
    nodeId: tree.id,
    kind: ItemKind.theorem,
    title: 'Théorème de Rolle',
  );
}

void main() {
  group('contrôleur', () {
    test('tracer, annuler, rétablir', () {
      final c = InkEditorController(InkDrawing.empty);
      c.down(pt(10, 10));
      c.move(pt(10.2, 10.1)); // trop proche : ignoré
      c.move(pt(50, 10));
      expect(c.current!.points, hasLength(2));
      expect(c.up(), isTrue);
      expect(c.ink.strokes, hasLength(1));
      expect(c.ink.strokes.single.color, inkColors.first.color);

      c.undo();
      expect(c.ink.isEmpty, isTrue);
      c.redo();
      expect(c.ink.strokes, hasLength(1));
    });

    test('surligneur, couleur, gomme et bout gomme du stylet', () {
      final c = InkEditorController(InkDrawing.empty);
      c.setColor(inkColors[2].color);
      c.down(pt(0, 0));
      c.move(pt(100, 0));
      c.up();
      c.select(InkMode.highlighter);
      c.down(pt(0, 100));
      c.move(pt(100, 100));
      c.up();
      expect(c.ink.strokes.map((s) => s.tool), [
        InkTool.pen,
        InkTool.highlighter,
      ]);
      expect(c.ink.strokes.first.color, inkColors[2].color);

      // Bout gomme : efface sans changer d'outil, un seul « annuler ».
      c.down(pt(50, 1), erasing: true);
      c.move(pt(50, 99));
      expect(c.up(), isTrue);
      expect(c.ink.isEmpty, isTrue);
      expect(c.mode, InkMode.highlighter);
      c.undo();
      expect(c.ink.strokes, hasLength(2));

      // Gomme dans le vide : rien ne change.
      c.select(InkMode.eraser);
      c.down(pt(500, 500));
      expect(c.up(), isFalse);
    });
  });

  testWidgets('note manuscrite au stylet ; le doigt fait défiler', (
    tester,
  ) async {
    final store = await pumpTestApp(tester, seed: seed);
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.text('Théorème de Rolle'));
    await settle(tester);
    await tester.ensureVisible(find.text('Note manuscrite'));
    await tester.tap(find.text('Note manuscrite'));
    await settle(tester);
    expect(find.text('Écriture manuscrite'), findsOneWidget);

    final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is InkPainter,
    );
    final origin = tester.getTopLeft(canvas);

    // Le doigt n'écrit pas.
    final finger = await tester.startGesture(
      origin + const Offset(40, 40),
      kind: PointerDeviceKind.touch,
    );
    await finger.moveBy(const Offset(60, 0));
    await finger.up();
    await tester.pump();
    expect(find.byTooltip('Annuler'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo))
          .onPressed,
      isNull,
    );

    // Le stylet écrit.
    final pen = await tester.startGesture(
      origin + const Offset(40, 80),
      kind: PointerDeviceKind.stylus,
    );
    for (var i = 1; i <= 10; i++) {
      await pen.moveBy(const Offset(10, 3));
    }
    await pen.up();
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo))
          .onPressed,
      isNotNull,
    );

    await tester.pageBack();
    await settle(tester);
    final notes = (await tester.runAsync(store.notes))!;
    expect(notes, hasLength(1));
    expect(notes.single.ink!.strokes, hasLength(1));
    expect(notes.single.ink!.strokes.single.points.length, greaterThan(5));
    // La fiche montre l'écriture.
    expect(find.byType(InkView), findsOneWidget);
    await unmountTestApp(tester);
  });

  testWidgets('note manuscrite laissée vide : supprimée', (tester) async {
    final store = await pumpTestApp(tester, seed: seed);
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.text('Théorème de Rolle'));
    await settle(tester);
    await tester.ensureVisible(find.text('Note manuscrite'));
    await tester.tap(find.text('Note manuscrite'));
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    expect((await tester.runAsync(store.notes))!, isEmpty);
    await unmountTestApp(tester);
  });
}
