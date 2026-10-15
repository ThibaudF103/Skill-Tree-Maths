import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/app/app_scope.dart';
import 'package:verger/features/items/item_editor.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'test_app.dart';

/// Formulaire ouvert sans branche imposée, comme depuis un encadrement.
Future<void> pumpEditorLauncher(WidgetTester tester, VergerStore store) async {
  await tester.pumpWidget(
    AppScope(
      store: store,
      scheduler: const SchedulerSettings().build(),
      reloadSettings: () async {},
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showItemEditor(
                context,
                family: ItemFamily.statement,
                initialTitle: 'Lemme de Schur',
              ),
              child: const Text('Encadrer'),
            ),
          ),
        ),
      ),
    ),
  );
  await settle(tester);
  await tester.tap(find.text('Encadrer'));
  await settle(tester);
}

void main() {
  testWidgets('création : dernière branche, « Changer », arbre repliable, '
      'sous-branche créée sur place', (tester) async {
    late KnowledgeNode groups;
    final store = await pumpTestApp(
      tester,
      seed: (s) async {
        final algebra = await s.createNode(title: 'Algèbre');
        groups = await s.createNode(title: 'Groupes', parentId: algebra.id);
        await s.createNode(title: 'Anneaux', parentId: algebra.id);
        await s.createNode(title: 'Analyse');
        await s.setLastNode(groups.id);
      },
    );
    await pumpEditorLauncher(tester, store);

    // #3 : la dernière branche est indiquée et présélectionnée.
    expect(find.text('Algèbre › Groupes'), findsOneWidget);
    await tester.tap(find.text('Changer'));
    await settle(tester);

    // #5 : arbre replié sauf le chemin de la sélection.
    expect(find.text('Analyse'), findsOneWidget);
    expect(find.text('Anneaux'), findsOneWidget);
    await tester.tap(find.byTooltip('Replier'));
    await settle(tester);
    expect(find.text('Anneaux'), findsNothing);
    await tester.tap(find.byTooltip('Déplier'));
    await settle(tester);

    // #2 : créer une sous-branche depuis le sélecteur.
    await tester.tap(find.byTooltip('Nouvelle branche dans « Groupes »'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Représentations');
    await tester.tap(find.text('Créer'));
    await settle(tester);
    expect(find.text('Représentations'), findsOneWidget);
    await tester.tap(find.text('Choisir'));
    await settle(tester);
    expect(find.text('Algèbre › Groupes › Représentations'), findsOneWidget);

    await tester.tap(find.text('Ajouter'));
    await settle(tester);
    final item = (await tester.runAsync(store.allItems))!.single;
    final node = (await tester.runAsync(() => store.node(item.nodeId)))!;
    expect(node.title, 'Représentations');
    expect(node.parentId, groups.id);
    expect((await tester.runAsync(store.lastNode))!.id, node.id);
    await unmountTestApp(tester);
  });

  testWidgets('sans branche connue : il faut en choisir une', (tester) async {
    final store = await pumpTestApp(
      tester,
      seed: (s) => s.createNode(title: 'Algèbre'),
    );
    await pumpEditorLauncher(tester, store);
    expect(find.text('Aucune branche choisie'), findsOneWidget);
    final add = find.widgetWithText(FilledButton, 'Ajouter');
    expect(tester.widget<FilledButton>(add).onPressed, isNull);

    await tester.tap(find.text('Choisir'));
    await settle(tester);
    await tester.tap(find.text('Algèbre'));
    await settle(tester);
    expect(tester.widget<FilledButton>(add).onPressed, isNotNull);
    await unmountTestApp(tester);
  });

  testWidgets('type d\'énoncé facultatif, difficulté des exercices (#11)', (
    tester,
  ) async {
    final store = await pumpTestApp(
      tester,
      seed: (s) async {
        final tree = await s.createNode(title: 'Algèbre');
        await s.setLastNode(tree.id);
      },
    );
    await pumpEditorLauncher(tester, store);

    // Énoncé : aucune précision par défaut ; un second appui la retire.
    bool selected(String label) => tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
        .selected;
    expect(selected('Théorème'), isFalse);
    await tester.tap(find.text('Lemme'));
    await tester.pump();
    expect(selected('Lemme'), isTrue);
    await tester.tap(find.text('Lemme'));
    await tester.pump();
    expect(selected('Lemme'), isFalse);
    await tester.tap(find.text('Ajouter'));
    await settle(tester);
    expect(
      (await tester.runAsync(store.allItems))!.single.kind,
      ItemKind.statement,
    );

    // Exercice avec difficulté.
    await tester.tap(find.text('Encadrer'));
    await settle(tester);
    await tester.tap(find.text('Exercice'));
    await tester.pump();
    await tester.tap(find.text('Difficile'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Sylow');
    await tester.tap(find.text('Ajouter'));
    await settle(tester);
    final exercise = (await tester.runAsync(store.allItems))!.last;
    expect(
      (exercise.kind, exercise.level),
      (ItemKind.exercise, ExerciseLevel.hard),
    );
    await unmountTestApp(tester);
  });
}
