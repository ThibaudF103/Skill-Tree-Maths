import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/features/notes/ink_editor.dart';
import 'package:verger/features/notes/ink_view.dart';
import 'package:verger/features/notes/notes_panel.dart';
import 'package:verger/features/notes/pencil_gestures.dart';
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

/// Nouvelle note sur « Théorème de Rolle », passée au stylet.
Future<void> openHandwriting(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Nouvelle note'));
  await tester.tap(find.text('Nouvelle note'));
  await settle(tester);
  await tester.tap(find.text('Stylet'));
  await settle(tester);
}

void main() {
  setUp(NoteEditor.forgetMode);

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

      // Gomme rapide : un trait traversé entre deux positions est effacé.
      c.select(InkMode.pen);
      c.down(pt(200, 0));
      c.move(pt(200, 300));
      c.up();
      c.select(InkMode.eraser);
      c.down(pt(100, 150));
      c.move(pt(300, 150)); // 200 unités d'un coup, à travers le trait
      expect(c.up(), isTrue);
      expect(c.ink.strokes.where((s) => s.points.first.x == 200), isEmpty);

      // Gomme dans le vide : rien ne change.
      c.select(InkMode.eraser);
      c.down(pt(500, 500));
      expect(c.up(), isFalse);
    });
    test('le trait en cours ne reconstruit pas la page', () {
      final c = InkEditorController(InkDrawing.empty);
      var page = 0, live = 0;
      c.addListener(() => page++);
      c.live.addListener(() => live++);
      c.down(pt(0, 0));
      for (var i = 1; i <= 5; i++) {
        c.move(pt(i * 10, 0));
      }
      expect(page, 0);
      expect(live, 6);
      c.up();
      expect(page, 1);
      expect(c.ink.strokes.single.points.last.x, 50);
    });

    test('gestes du stylet : gomme et outil précédent', () {
      final c = InkEditorController(InkDrawing.empty);
      c.select(InkMode.highlighter);
      c.toggleEraser();
      expect(c.mode, InkMode.eraser);
      c.toggleEraser();
      expect(c.mode, InkMode.highlighter);
      c.setColor(inkColors[1].color);
      expect(c.mode, InkMode.pen);
      c.switchPrevious();
      expect(c.mode, InkMode.highlighter);
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
    await openHandwriting(tester);

    final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is InkPainter,
    );
    final origin = tester.getTopLeft(canvas.first);

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

    // La note se referme sous la fiche.
    await tester.tap(find.byTooltip('Fermer la note'));
    await settle(tester);
    final notes = (await tester.runAsync(store.notes))!;
    expect(notes, hasLength(1));
    expect(notes.single.ink!.strokes, hasLength(1));
    expect(notes.single.ink!.strokes.single.points.length, greaterThan(5));
    // La fiche montre l'écriture.
    expect(find.byType(InkView), findsOneWidget);
    await unmountTestApp(tester);
  });

  testWidgets('gestes de l\'Apple Pencil : gomme et palette', (tester) async {
    await pumpTestApp(tester, seed: seed);
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.text('Théorème de Rolle'));
    await settle(tester);
    await openHandwriting(tester);

    bool selected(String tool) => tester
        .widgetList<IconButton>(
          find.ancestor(
            of: find.byTooltip(tool),
            matching: find.byType(IconButton),
          ),
        )
        .first
        .isSelected!;

    PencilGestures.dispatch((action: PencilAction.eraser, at: null));
    await tester.pump();
    expect(selected('Gomme'), isTrue);
    PencilGestures.dispatch((action: PencilAction.eraser, at: null));
    await tester.pump();
    expect(selected('Stylo'), isTrue);

    // Palette près du stylet ; un choix la referme.
    PencilGestures.dispatch((
      action: PencilAction.palette,
      at: const Offset(300, 400),
    ));
    await tester.pump();
    expect(find.byTooltip('Surligneur'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Surligneur').last);
    await tester.pump();
    expect(find.byTooltip('Surligneur'), findsOneWidget);
    expect(selected('Surligneur'), isTrue);

    // Second geste : la palette se referme.
    PencilGestures.dispatch((action: PencilAction.palette, at: null));
    await tester.pump();
    expect(find.byTooltip('Surligneur'), findsNWidgets(2));
    PencilGestures.dispatch((action: PencilAction.palette, at: null));
    await tester.pump();
    expect(find.byTooltip('Surligneur'), findsOneWidget);

    // Geste « gomme » palette ouverte : la palette se referme.
    PencilGestures.dispatch((action: PencilAction.palette, at: null));
    await tester.pump();
    PencilGestures.dispatch((action: PencilAction.eraser, at: null));
    await tester.pump();
    expect(find.byTooltip('Surligneur'), findsOneWidget);
    expect(selected('Gomme'), isTrue);

    await tester.pageBack();
    await settle(tester);
    await unmountTestApp(tester);
  });

  testWidgets('une même note : texte au clavier puis écriture au stylet', (
    tester,
  ) async {
    final store = await pumpTestApp(tester, seed: seed);
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.text('Théorème de Rolle'));
    await settle(tester);
    await tester.ensureVisible(find.text('Nouvelle note'));
    await tester.tap(find.text('Nouvelle note'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Par Rolle');
    await tester.tap(find.text('Stylet'));
    await settle(tester);
    final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is InkPainter,
    );
    final pen = await tester.startGesture(
      tester.getTopLeft(canvas.first) + const Offset(40, 80),
      kind: PointerDeviceKind.stylus,
    );
    for (var i = 1; i <= 10; i++) {
      await pen.moveBy(const Offset(10, 3));
    }
    await pen.up();
    await tester.pump();
    // Retour au clavier : le texte est là, l'écriture en aperçu.
    await tester.tap(find.text('Clavier'));
    await settle(tester);
    expect(find.text('Par Rolle'), findsWidgets);
    // Aperçu dans l'éditeur, et dans la fiche au-dessus.
    expect(find.byType(InkView), findsNWidgets(2));

    await tester.pageBack();
    await settle(tester);
    final note = (await tester.runAsync(store.notes))!.single;
    expect(note.body, 'Par Rolle');
    expect(note.ink!.strokes, hasLength(1));
    await unmountTestApp(tester);
  });

  testWidgets('note manuscrite laissée vide : supprimée', (tester) async {
    final store = await pumpTestApp(tester, seed: seed);
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.text('Théorème de Rolle'));
    await settle(tester);
    await openHandwriting(tester);
    await tester.pageBack();
    await settle(tester);
    expect((await tester.runAsync(store.notes))!, isEmpty);
    await unmountTestApp(tester);
  });

  testWidgets('texte vidé puis note fermée aussitôt : note supprimée', (
    tester,
  ) async {
    final store = await pumpTestApp(
      tester,
      seed: (store) async {
        await seed(store);
        final item = (await store.allItems()).single;
        await store.createNote(itemId: item.id, body: 'Brouillon');
      },
    );
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.text('Théorème de Rolle'));
    await settle(tester);
    await tester.ensureVisible(find.text('Brouillon'));
    await tester.tap(find.text('Brouillon'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '');
    await tester.pageBack(); // avant la fin du délai d'enregistrement
    await settle(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    expect((await tester.runAsync(store.notes))!, isEmpty);
    await unmountTestApp(tester);
  });
}
