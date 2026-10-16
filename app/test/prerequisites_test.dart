import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'test_app.dart';

Future<void> seed(VergerStore store) async {
  final tree = await store.createNode(title: 'Algèbre');
  Future<KnowledgeItem> item(ItemKind kind, String title) =>
      store.createItem(nodeId: tree.id, kind: kind, title: title);
  final def = await item(ItemKind.definition, 'Polynôme caractéristique');
  final thm = await item(ItemKind.theorem, 'Cayley-Hamilton');
  await item(ItemKind.exercise, 'Matrice compagnon');
  await store.addPrerequisite(thm.id, def.id);
}

void main() {
  testWidgets('fiche : prérequis, utilisations, cycle refusé', (tester) async {
    final store = await pumpTestApp(tester, seed: seed);
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.text('Cayley-Hamilton'));
    await settle(tester);

    await tester.ensureVisible(find.text('Utilisée par'));
    await settle(tester);
    expect(find.text('Définition · Polynôme caractéristique'), findsOneWidget);
    expect(
      find.text('Aucune connaissance ne s\'appuie sur celle-ci.'),
      findsOneWidget,
    );

    // L'exercice s'appuie sur le théorème.
    await tester.tap(find.widgetWithText(TextButton, 'Utilisation'));
    await settle(tester);
    await tester.tap(find.text('Matrice compagnon'));
    await settle(tester);
    expect(find.text('Exercice · Matrice compagnon'), findsOneWidget);

    // Le théorème ne peut pas s'appuyer sur l'exercice : cycle.
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Prérequis'));
    await tester.tap(find.widgetWithText(TextButton, 'Prérequis'));
    await settle(tester);
    await tester.tap(find.text('Matrice compagnon'));
    await settle(tester);
    expect(find.textContaining('Lien refusé'), findsOneWidget);
    final edges = (await tester.runAsync(store.prerequisites))!;
    expect(edges, hasLength(2));

    // Retirer le prérequis.
    await tester.tap(find.byTooltip('Retirer le lien').first);
    await settle(tester);
    expect(find.text('Définition · Polynôme caractéristique'), findsNothing);
    expect(find.text('Aucun prérequis.'), findsOneWidget);
    await unmountTestApp(tester);
  });
}
