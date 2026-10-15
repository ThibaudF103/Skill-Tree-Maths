import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger_core/verger_core.dart';

import 'test_app.dart';

Future<void> openTrees(WidgetTester tester) async {
  await tester.tap(find.text('Arbres'));
  await settle(tester);
}

Future<void> typeAndConfirm(
  WidgetTester tester,
  String text,
  String button,
) async {
  final dialog = find.byType(AlertDialog);
  await tester.enterText(
    find.descendant(of: dialog, matching: find.byType(TextField)).first,
    text,
  );
  await tester.pump();
  await tester.tap(
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(FilledButton, button),
    ),
  );
  await settle(tester);
}

void main() {
  testWidgets('créer un arbre, une branche et des connaissances', (
    tester,
  ) async {
    final store = await pumpTestApp(tester);
    await openTrees(tester);

    // Verger vide → planter un arbre.
    expect(find.text('Le verger est vide'), findsOneWidget);
    await tester.tap(find.text('Planter un arbre'));
    await settle(tester);
    await typeAndConfirm(tester, 'Algèbre', 'Créer');
    expect(find.text('Algèbre'), findsWidgets);

    // Une branche.
    await tester.tap(find.widgetWithText(TextButton, 'Branche'));
    await settle(tester);
    await typeAndConfirm(tester, 'Réduction', 'Créer');
    expect(find.text('Réduction'), findsWidgets);

    // Aller dans la branche et ajouter une définition.
    await tester.tap(find.widgetWithText(ListTile, 'Réduction'));
    await settle(tester);
    expect(find.textContaining('rameau en hiver'), findsOneWidget);
    await tester.tap(find.text('Ajouter'));
    await settle(tester);
    await tester.tap(find.text('Définition').last);
    await settle(tester);
    await typeAndConfirm(tester, 'Endomorphisme diagonalisable', 'Ajouter');
    expect(find.text('Endomorphisme diagonalisable'), findsOneWidget);
    expect(find.textContaining('Définition · Bourgeon'), findsOneWidget);

    // Un théorème déjà connu : compte comme une première révision.
    await tester.tap(find.text('Ajouter'));
    await settle(tester);
    await tester.tap(find.text('Propriété / théorème'));
    await settle(tester);
    await tester.tap(find.text('Théorème'));
    await tester.tap(find.text('Connue'));
    await typeAndConfirm(tester, 'Théorème de Cayley-Hamilton', 'Ajouter');
    expect(find.textContaining('Théorème · Pousse · demain'), findsOneWidget);

    final items = await tester.runAsync(store.allItems);
    expect(items!.map((i) => i.kind), [ItemKind.definition, ItemKind.theorem]);
    final nodes = await tester.runAsync(store.allNodes);
    final reduction = nodes!.firstWhere((n) => n.title == 'Réduction');
    expect(items.every((i) => i.nodeId == reduction.id), isTrue);
    expect(items.last.scheduling.reps, 1);

    // Le plan affiche le nombre de connaissances de l'arbre.
    expect(find.text('2'), findsWidgets);

    // Fiche de la connaissance et son historique.
    await tester.tap(find.text('Théorème de Cayley-Hamilton'));
    await settle(tester);
    expect(find.text('Algèbre › Réduction'), findsOneWidget);
    expect(find.text('Historique'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    await unmountTestApp(tester);
  });

  testWidgets('supprimer une branche non vide après confirmation', (
    tester,
  ) async {
    final store = await pumpTestApp(
      tester,
      seed: (store) async {
        final tree = await store.createNode(title: 'Analyse');
        final branch = await store.createNode(
          title: 'Séries',
          parentId: tree.id,
        );
        await store.createItem(
          nodeId: branch.id,
          kind: ItemKind.exercise,
          title: 'Série harmonique',
        );
      },
    );
    await openTrees(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Séries'));
    await settle(tester);

    await tester.tap(find.byTooltip('Actions'));
    await settle(tester);
    await tester.tap(find.text('Supprimer'));
    await settle(tester);
    expect(find.textContaining('1 connaissance(s)'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await settle(tester);

    expect(find.text('Séries'), findsNothing);
    expect(await tester.runAsync(store.allItems), isEmpty);
    expect((await tester.runAsync(store.allNodes))!.single.title, 'Analyse');
    await unmountTestApp(tester);
  });

  testWidgets('sur téléphone, la navigation se fait par pages', (tester) async {
    await pumpTestApp(
      tester,
      size: const Size(390, 844),
      seed: (store) async {
        final tree = await store.createNode(title: 'Géométrie');
        await store.createNode(title: 'Coniques', parentId: tree.id);
      },
    );
    await openTrees(tester);
    await tester.tap(find.text('Géométrie'));
    await settle(tester);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Coniques'));
    await settle(tester);
    expect(find.text('Coniques'), findsWidgets);
    expect(find.textContaining('rameau en hiver'), findsOneWidget);
    await unmountTestApp(tester);
  });
}
