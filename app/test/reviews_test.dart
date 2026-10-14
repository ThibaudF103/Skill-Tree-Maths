import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'test_app.dart';

/// Un arbre avec : une connaissance en retard, une nouvelle, une prévue demain.
Future<void> seed(VergerStore store) async {
  final scheduler = const SchedulerSettings().build();
  final now = DateTime.now();
  final tree = await store.createNode(title: 'Algèbre');
  final branch = await store.createNode(title: 'Réduction', parentId: tree.id);

  final late = await store.createItem(
    nodeId: branch.id,
    kind: ItemKind.theorem,
    title: 'Théorème spectral',
    body: 'Tout endomorphisme autoadjoint est diagonalisable en BON.',
  );
  await store.applyReview(
    late.id,
    scheduler.record(
      late.scheduling,
      Rating.easy,
      now.subtract(const Duration(days: 30)),
      fuzzKey: late.id,
    ),
  );

  await store.createItem(
    nodeId: branch.id,
    kind: ItemKind.definition,
    title: 'Polynôme minimal',
  );

  final tomorrow = await store.createItem(
    nodeId: branch.id,
    kind: ItemKind.exercise,
    title: 'Exercice diagonalisation',
  );
  await store.applyReview(
    tomorrow.id,
    scheduler.record(tomorrow.scheduling, Rating.good, now),
  );
}

Future<void> openReviews(WidgetTester tester) async {
  await tester.tap(find.text('Révisions'));
  await settle(tester);
}

void main() {
  testWidgets('liste des révisions groupée et triée', (tester) async {
    await pumpTestApp(tester, seed: seed);
    // Badge : une connaissance due.
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('1')),
      findsOneWidget,
    );
    await openReviews(tester);

    expect(find.text('1 à réviser · 1 nouvelle'), findsOneWidget);
    expect(find.text('Commencer (2)'), findsOneWidget);
    expect(find.text('En retard'), findsOneWidget);
    expect(find.text('Demain'), findsOneWidget);
    expect(find.text('Nouvelles'), findsOneWidget);
    expect(find.text('Algèbre → Réduction'), findsNWidgets(3));
    expect(find.textContaining('retard : '), findsOneWidget);
    expect(find.text('prévu demain'), findsOneWidget);
    await unmountTestApp(tester);
  });

  testWidgets('session : révéler, noter, bilan', (tester) async {
    final store = await pumpTestApp(tester, seed: seed);
    await openReviews(tester);
    await tester.tap(find.text('Commencer (2)'));
    await settle(tester);

    // 1re carte : la connaissance en retard (priorité), contenu masqué.
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Théorème spectral'), findsOneWidget);
    expect(find.textContaining('autoadjoint'), findsNothing);
    await tester.tap(find.text('Révéler'));
    await settle(tester);
    expect(find.textContaining('autoadjoint'), findsOneWidget);
    for (final label in ['À revoir', 'Difficile', 'Correct', 'Facile']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('6 h'), findsOneWidget); // « À revoir » → réapprentissage
    await tester.tap(find.text('Correct'));
    await settle(tester);

    // 2e carte : la nouvelle définition, notée au clavier.
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Polynôme minimal'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect(find.textContaining('comparez avec vos notes'), findsOneWidget);
    expect(find.text('1 j'), findsOneWidget); // « Correct » → 1 jour
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await settle(tester);

    expect(find.text('Session terminée'), findsOneWidget);
    expect(find.text('2 connaissances révisées'), findsOneWidget);

    final items = (await tester.runAsync(store.allItems))!;
    final spectral = items.firstWhere((i) => i.title == 'Théorème spectral');
    final minimal = items.firstWhere((i) => i.title == 'Polynôme minimal');
    expect(spectral.scheduling.reps, 2);
    expect(spectral.scheduling.due!.isAfter(DateTime.now()), isTrue);
    expect(minimal.scheduling.phase, LearningPhase.learning);
    final history = (await tester.runAsync(() => store.history(minimal.id)))!;
    expect(history.single.rating, Rating.good);
    expect(history.single.duration, isNotNull);

    await tester.tap(find.text('Retour'));
    await settle(tester);
    expect(find.text('Rien à réviser pour le moment.'), findsOneWidget);
    await unmountTestApp(tester);
  });

  testWidgets('toucher une connaissance la révise en premier', (tester) async {
    await pumpTestApp(tester, seed: seed);
    await openReviews(tester);
    await tester.tap(find.text('Exercice diagonalisation'));
    await settle(tester);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('Exercice diagonalisation'), findsOneWidget);
    await tester.tap(find.byTooltip('Terminer'));
    await settle(tester);
    await unmountTestApp(tester);
  });
}
