import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'test_app.dart';

void main() {
  /// « Mécanique » > « Oscillateurs » (deux cartes) et « Optique ».
  Future<void> seed(VergerStore store) async {
    final meca = await store.createNode(title: 'Mécanique');
    final osc = await store.createNode(
      title: 'Oscillateurs',
      parentId: meca.id,
    );
    await store.createNode(title: 'Optique');
    await store.createItem(
      nodeId: osc.id,
      kind: ItemKind.definition,
      title: 'Oscillateur harmonique',
    );
    await store.createItem(
      nodeId: osc.id,
      kind: ItemKind.theorem,
      title: 'Résonance',
    );
  }

  Future<VergerStore> openBoard(WidgetTester tester, {bool edit = true}) async {
    final store = await pumpTestApp(tester, seed: seed);
    await tester.tap(find.text('Tableau'));
    await settle(tester);
    if (edit) {
      await tester.tap(find.text('Édition'));
      await settle(tester);
    }
    return store;
  }

  /// Glissé à un doigt, par petits pas, l'écran redessiné entre chaque.
  Future<void> dragFromTo(WidgetTester tester, Offset from, Offset to) async {
    final gesture = await tester.startGesture(from);
    await tester.pump();
    for (var i = 1; i <= 6; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 6)!);
      await tester.pump();
    }
    await gesture.up();
    await settle(tester);
  }

  Future<KnowledgeNode> nodeNamed(
    WidgetTester tester,
    VergerStore store,
    String title,
  ) async => (await tester.runAsync(
    store.allNodes,
  ))!.firstWhere((n) => n.title == title);

  Future<KnowledgeItem> itemNamed(
    WidgetTester tester,
    VergerStore store,
    String title,
  ) async => (await tester.runAsync(
    store.allItems,
  ))!.firstWhere((i) => i.title == title);

  Rect regionOnScreen(WidgetTester tester, String nodeId) =>
      tester.getRect(find.byKey(ValueKey('region $nodeId')));

  /// Point de l'écran hors de toute région (en bas à gauche du tableau).
  Offset emptySpot(WidgetTester tester) {
    final rail = tester.getRect(find.byType(NavigationRail));
    return Offset(rail.right + 30, rail.bottom - 30);
  }

  testWidgets('édition désactivée par défaut : glisser une carte déplace la '
      'vue, rien ne change', (tester) async {
    final store = await openBoard(tester, edit: false);
    final chip = tester.widget<FilterChip>(find.byType(FilterChip));
    expect(chip.selected, isFalse);
    final before = await itemNamed(tester, store, 'Résonance');
    final card = tester.getCenter(find.text('Résonance'));
    await dragFromTo(tester, card, card + const Offset(0, 150));
    expect(tester.getCenter(find.text('Résonance')).dy, greaterThan(card.dy));
    final after = await itemNamed(tester, store, 'Résonance');
    expect(after.boardPosition, before.boardPosition);
    expect(find.text('Annuler'), findsNothing);

    await tester.tap(find.text('Édition'));
    await settle(tester);
    expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, isTrue);
    await unmountTestApp(tester);
  });

  testWidgets('carte déposée dans une autre région : elle change de nœud ; '
      '« Annuler » la remet', (tester) async {
    final store = await openBoard(tester);
    final optique = await nodeNamed(tester, store, 'Optique');
    final osc = await nodeNamed(tester, store, 'Oscillateurs');
    final before = await itemNamed(tester, store, 'Résonance');
    final target = regionOnScreen(tester, optique.id);
    await dragFromTo(
      tester,
      tester.getCenter(find.text('Résonance')),
      target.center + const Offset(0, 20),
    );
    final moved = await itemNamed(tester, store, 'Résonance');
    expect(moved.nodeId, optique.id);
    final region = (await nodeNamed(tester, store, 'Optique')).board!;
    expect(
      region.contains(BoardRect.at(moved.boardPosition!, 220, 96)),
      isTrue,
    );
    expect(
      find.textContaining('Carte rangée dans « Optique »'),
      findsOneWidget,
    );

    await tester.tap(find.text('Annuler'));
    await settle(tester);
    final back = await itemNamed(tester, store, 'Résonance');
    expect(back.nodeId, osc.id);
    expect(back.boardPosition, before.boardPosition);
    await unmountTestApp(tester);
  });

  testWidgets('carte déposée hors de toute région : « Non classées »', (
    tester,
  ) async {
    final store = await openBoard(tester);
    await dragFromTo(
      tester,
      tester.getCenter(find.text('Résonance')),
      emptySpot(tester),
    );
    final moved = await itemNamed(tester, store, 'Résonance');
    expect(moved.nodeId, KnowledgeNode.unsortedId);
    // Placée automatiquement dans sa région, affichée.
    await settle(tester);
    expect(
      (await itemNamed(tester, store, 'Résonance')).boardPosition,
      isNotNull,
    );
    expect(find.text('Non classées'), findsOneWidget);
    await unmountTestApp(tester);
  });

  testWidgets('région déplacée par son bandeau : son contenu suit', (
    tester,
  ) async {
    final store = await openBoard(tester);
    final osc = await nodeNamed(tester, store, 'Oscillateurs');
    final card = await itemNamed(tester, store, 'Résonance');
    final title = tester.getCenter(find.text('Oscillateurs'));
    await dragFromTo(tester, title, title + const Offset(0, 120));
    final movedOsc = await nodeNamed(tester, store, 'Oscillateurs');
    final movedCard = await itemNamed(tester, store, 'Résonance');
    expect(movedOsc.parentId, osc.parentId);
    final dy = movedOsc.board!.y - osc.board!.y;
    expect(dy, greaterThan(40));
    expect(movedOsc.board!.x, osc.board!.x);
    expect(movedCard.boardPosition!.y - card.boardPosition!.y, dy);
    expect(movedCard.boardPosition!.x, card.boardPosition!.x);
    expect(find.text('Région déplacée'), findsOneWidget);
    await unmountTestApp(tester);
  });

  testWidgets('redimensionner : agrandie, son parent suit ; jamais plus '
      'petite que son contenu', (tester) async {
    final store = await openBoard(tester);
    final osc = await nodeNamed(tester, store, 'Oscillateurs');
    final meca = (await nodeNamed(tester, store, 'Mécanique')).board!;

    // Agrandie par le coin bas droit : le parent grandit avec elle.
    var rect = regionOnScreen(tester, osc.id);
    await dragFromTo(
      tester,
      rect.bottomRight - const Offset(2, 2),
      rect.bottomRight + const Offset(150, 150),
    );
    final grown = (await nodeNamed(tester, store, 'Oscillateurs')).board!;
    expect(grown.width, greaterThan(osc.board!.width + 100));
    expect(grown.topLeft, osc.board!.topLeft);
    final mecaAfter = (await nodeNamed(tester, store, 'Mécanique')).board!;
    expect(mecaAfter.contains(grown), isTrue);
    expect(mecaAfter.height, greaterThan(meca.height));
    expect(find.text('Région redimensionnée'), findsOneWidget);

    // Réduite à l'extrême : ramenée à son contenu.
    final editor = BoardEditor(
      (await tester.runAsync(store.allNodes))!,
      (await tester.runAsync(store.allItems))!,
    );
    final expected = editor.clampResize(
      osc.id,
      BoardRect(grown.x, grown.y, 1, 1),
    );
    rect = regionOnScreen(tester, osc.id);
    await dragFromTo(
      tester,
      rect.bottomRight - const Offset(2, 2),
      rect.topLeft + const Offset(10, 10),
    );
    final shrunk = (await nodeNamed(tester, store, 'Oscillateurs')).board!;
    expect(shrunk, expected);
    expect(shrunk.width, lessThan(grown.width));
    expect(shrunk.width, osc.board!.width);
    await unmountTestApp(tester);
  });

  testWidgets('en édition, glisser sur le vide déplace toujours la vue', (
    tester,
  ) async {
    final store = await openBoard(tester);
    final meca = await nodeNamed(tester, store, 'Mécanique');
    final before = regionOnScreen(tester, meca.id);
    final from = emptySpot(tester);
    await dragFromTo(tester, from, from + const Offset(80, -60));
    final after = regionOnScreen(tester, meca.id);
    expect(after.left - before.left, closeTo(80, 20));
    expect((await nodeNamed(tester, store, 'Mécanique')).board, meca.board);
    expect(find.text('Annuler'), findsNothing);
    await unmountTestApp(tester);
  });

  testWidgets('un deuxième doigt annule le déplacement', (tester) async {
    final store = await openBoard(tester);
    final before = await itemNamed(tester, store, 'Résonance');
    final card = tester.getCenter(find.text('Résonance'));
    final first = await tester.startGesture(card);
    await tester.pump();
    await first.moveBy(const Offset(40, 40));
    await tester.pump();
    final second = await tester.startGesture(
      card + const Offset(200, 0),
      pointer: 7,
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    await first.moveBy(const Offset(40, 40));
    await second.moveBy(const Offset(-40, -40));
    await tester.pump();
    await first.up();
    await second.up();
    await settle(tester);
    expect(
      (await itemNamed(tester, store, 'Résonance')).boardPosition,
      before.boardPosition,
    );
    expect(find.text('Annuler'), findsNothing);
    await unmountTestApp(tester);
  });
}
