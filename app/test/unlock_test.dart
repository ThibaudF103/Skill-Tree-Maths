import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'test_app.dart';

/// Analyse › Suites : définition et théorème vus il y a un mois (en
/// retard), le théorème s'appuyant sur la définition. Analyse › Séries : un
/// corollaire nouveau qui s'appuie sur le théorème, et un exercice nouveau
/// dont le prérequis (suspendu, jamais vu) est ailleurs.
Future<void> seed(VergerStore store) async {
  final scheduler = const SchedulerSettings().build();
  final month = DateTime.now().subtract(const Duration(days: 30));
  final tree = await store.createNode(title: 'Analyse');
  final suites = await store.createNode(title: 'Suites', parentId: tree.id);
  final series = await store.createNode(title: 'Séries', parentId: tree.id);
  final topo = await store.createNode(title: 'Topologie');
  Future<KnowledgeItem> item(KnowledgeNode n, ItemKind kind, String t) =>
      store.createItem(nodeId: n.id, kind: kind, title: t);
  final def = await item(suites, ItemKind.definition, 'Suite de Cauchy');
  final thm = await item(suites, ItemKind.theorem, 'Complétude de R');
  final cor = await item(series, ItemKind.corollary, 'Convergence absolue');
  final ex = await item(series, ItemKind.exercise, 'Série et compacité');
  final compact = await item(topo, ItemKind.definition, 'Compacité');
  await store.updateItem(compact.id, suspended: true);
  for (final seen in [def, thm]) {
    await store.applyReview(
      seen.id,
      scheduler.record(seen.scheduling, Rating.good, month, fuzzKey: seen.id),
    );
  }
  await store.addPrerequisite(thm.id, def.id);
  await store.addPrerequisite(cor.id, thm.id);
  await store.addPrerequisite(ex.id, compact.id);
}

Future<void> openReviews(WidgetTester tester) async {
  await tester.tap(find.text('Révisions'));
  await settle(tester);
}

void main() {
  testWidgets('déblocage progressif : nouvelles en attente, réglage', (
    tester,
  ) async {
    await pumpTestApp(tester, seed: seed);
    await openReviews(tester);
    expect(
      find.text('2 à réviser · 1 nouvelle · 1 en attente de prérequis'),
      findsOneWidget,
    );
    expect(find.text('Exercice · verrouillée'), findsOneWidget);

    await tester.tap(find.text('Déblocage progressif'));
    await settle(tester);
    expect(find.text('2 à réviser · 2 nouvelles'), findsOneWidget);
    expect(find.text('Exercice · verrouillée'), findsNothing);
    await unmountTestApp(tester);
  });

  testWidgets('réussir le théorème revoit la définition', (tester) async {
    final store = await pumpTestApp(tester, seed: seed);
    await openReviews(tester);
    await tester.tap(find.text('Complétude de R'));
    await settle(tester);
    expect(find.text('1 / 3'), findsOneWidget);
    await tester.tap(find.text('Révéler'));
    await settle(tester);
    await tester.tap(find.text('Correct'));
    await settle(tester);

    expect(
      find.text('Revu en même temps : « Suite de Cauchy ».'),
      findsOneWidget,
    );
    // La définition, revue, n'est pas reproposée.
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('Convergence absolue'), findsOneWidget);

    final items = (await tester.runAsync(store.allItems))!;
    final def = items.firstWhere((i) => i.title == 'Suite de Cauchy');
    final thm = items.firstWhere((i) => i.title == 'Complétude de R');
    final history = (await tester.runAsync(() => store.history(def.id)))!;
    expect(history.last.impliedBy, thm.id);
    expect(history.last.rating, Rating.good);
    await tester.tap(find.byTooltip('Terminer'));
    await settle(tester);

    // L'historique de la fiche indique la révision implicite.
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.text('Suites').last);
    await settle(tester);
    await tester.tap(find.text('Suite de Cauchy'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Correct · via « Complétude de R »'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Correct · via « Complétude de R »'), findsOneWidget);
    await unmountTestApp(tester);
  });

  testWidgets('oublier propose d\'ajouter les prérequis fragiles', (
    tester,
  ) async {
    await pumpTestApp(tester, seed: seed);
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.text('Séries').last);
    await settle(tester);
    await tester.tap(find.byTooltip('Actions'));
    await settle(tester);
    await tester.tap(find.text('Réviser cette branche'));
    await settle(tester);

    // L'exercice attend son prérequis : seul le corollaire est proposé.
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('Convergence absolue'), findsOneWidget);
    await tester.tap(find.text('Révéler'));
    await settle(tester);
    await tester.tap(find.text('À revoir'));
    await settle(tester);
    expect(
      find.textContaining('s\'appuie sur « Complétude de R »'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ajouter à la séance'));
    await settle(tester);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Complétude de R'), findsOneWidget);
    await unmountTestApp(tester);
  });
}
