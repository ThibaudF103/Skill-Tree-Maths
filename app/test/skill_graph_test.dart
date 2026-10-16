import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger/features/skills/skill_graph_page.dart';
import 'package:verger_data/verger_data.dart';

import 'test_app.dart';

/// Une définition vue, un théorème prêt qui s'appuie dessus, un corollaire
/// verrouillé, un exercice sans lien et un prérequis d'une autre branche.
Future<void> seed(VergerStore store) async {
  final scheduler = const SchedulerSettings().build();
  final tree = await store.createNode(title: 'Algèbre');
  final other = await store.createNode(title: 'Topologie');
  Future<KnowledgeItem> item(String node, ItemKind kind, String title) =>
      store.createItem(nodeId: node, kind: kind, title: title);
  final compact = await item(other.id, ItemKind.definition, 'Compacité');
  final def = await item(
    tree.id,
    ItemKind.definition,
    'Polynôme caractéristique',
  );
  final thm = await item(tree.id, ItemKind.theorem, 'Cayley-Hamilton');
  final cor = await item(tree.id, ItemKind.corollary, 'Polynôme minimal');
  await item(tree.id, ItemKind.exercise, 'Matrice compagnon');
  await store.addPrerequisite(thm.id, def.id);
  await store.addPrerequisite(cor.id, thm.id);
  await store.addPrerequisite(thm.id, compact.id);
  await store.applyReview(
    def.id,
    scheduler.record(def.scheduling, Rating.good, DateTime.now()),
  );
  await store.applyReview(
    compact.id,
    scheduler.record(compact.scheduling, Rating.good, DateTime.now()),
  );
}

void main() {
  testWidgets('arbre de compétences : états, autre branche, sélection', (
    tester,
  ) async {
    await pumpTestApp(tester, seed: seed);
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.byTooltip('Arbre de compétences'));
    await settle(tester);

    expect(find.text('Compétences · Algèbre'), findsOneWidget);
    expect(find.text('Cayley-Hamilton'), findsOneWidget);
    expect(find.text('Définition · autre branche'), findsOneWidget);
    // L'exercice sans lien est masqué par défaut.
    expect(find.text('Matrice compagnon'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    await tester.tap(find.text('Sans lien (1)'));
    await settle(tester);
    expect(find.text('Matrice compagnon'), findsOneWidget);

    await tester.tap(find.text('Polynôme minimal'));
    await settle(tester);
    expect(
      find.text('Verrouillée : des prérequis restent à voir.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ouvrir la fiche'));
    await settle(tester);
    expect(find.text('S\'appuie sur'), findsOneWidget);
    await unmountTestApp(tester);
  });

  test('numéro de l\'énoncé affiché à part', () {
    expect(splitTitle('Proposition I.6.19 : Soit f convexe'), (
      number: 'I.6.19',
      text: 'Soit f convexe',
    ));
    expect(splitTitle('Théorème de Rolle · I.3.40'), (
      number: 'I.3.40',
      text: 'Théorème de Rolle',
    ));
    expect(splitTitle('Cayley-Hamilton'), (
      number: null,
      text: 'Cayley-Hamilton',
    ));
  });
}
