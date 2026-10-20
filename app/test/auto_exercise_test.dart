import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/app/app_scope.dart';
import 'package:verger/features/items/item_editor.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'test_app.dart';

/// Sans paramètre : le même énoncé à chaque tirage.
const model = r'''
{"v": 1,
 "statement": "Calculer $2 + 3$.",
 "questions": [
   {"prompt": "Résultat :", "answer": "2 + 3"},
   {"prompt": "Ce nombre est-il pair ?", "choices": ["non", "oui"]}
 ]}''';

Future<String> seed(VergerStore store) async {
  final tree = await store.createNode(title: 'Calcul');
  final item = await store.createItem(
    nodeId: tree.id,
    kind: ItemKind.exercise,
    title: 'Somme',
    autoExercise: model,
  );
  return item.id;
}

Future<void> startSession(WidgetTester tester) async {
  await tester.tap(find.text('Révisions'));
  await settle(tester);
  await tester.tap(find.text('Commencer (1)'));
  await settle(tester);
}

/// Bouton de note mis en avant (fond plein) par la correction.
bool isSuggested(WidgetTester tester, String label) {
  final button = tester.widget<OutlinedButton>(
    find.ancestor(of: find.text(label), matching: find.byType(OutlinedButton)),
  );
  return button.style?.backgroundColor?.resolve({}) != null;
}

void main() {
  testWidgets('révision : réponses vérifiées, note proposée et appliquée', (
    tester,
  ) async {
    late String id;
    final store = await pumpTestApp(
      tester,
      seed: (s) async => id = await seed(s),
    );
    await startSession(tester);
    expect(find.text('Vérifier'), findsOneWidget);
    expect(find.text('Révéler'), findsNothing);

    // Rien de saisi : on le signale, pas de correction.
    await tester.tap(find.text('Vérifier'));
    await settle(tester);
    expect(find.text('Réponse illisible ou manquante'), findsOneWidget);
    expect(find.text('Choisissez une réponse'), findsOneWidget);
    expect(find.text('Correct'), findsNothing);

    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.text('non'));
    await tester.tap(find.text('Vérifier'));
    await settle(tester);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(isSuggested(tester, 'Correct'), isTrue);
    expect(isSuggested(tester, 'Facile'), isFalse);

    await tester.tap(find.text('Correct'));
    await settle(tester);
    expect(find.text('1 connaissance révisée'), findsOneWidget);
    final history = (await tester.runAsync(() => store.history(id)))!;
    expect(history.single.rating, Rating.good);
    await unmountTestApp(tester);
  });

  testWidgets('révision : réponse fausse → correction et « Difficile »', (
    tester,
  ) async {
    await pumpTestApp(tester, seed: seed);
    await startSession(tester);
    await tester.enterText(find.byType(TextField), '6');
    await tester.tap(find.text('non'));
    await tester.tap(find.text('Vérifier'));
    await settle(tester);
    expect(find.byIcon(Icons.cancel), findsOneWidget);
    expect(find.text('Réponse : 5'), findsOneWidget);
    expect(isSuggested(tester, 'Difficile'), isTrue);
    await unmountTestApp(tester);
  });

  testWidgets('éditeur : exemple, aperçu, modèle invalide refusé', (
    tester,
  ) async {
    final store = await pumpTestApp(
      tester,
      seed: (s) async {
        final tree = await s.createNode(title: 'Calcul');
        await s.setLastNode(tree.id);
      },
    );
    await tester.pumpWidget(
      AppScope(
        store: store,
        scheduler: const SchedulerSettings().build(),
        reloadSettings: () async {},
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showItemEditor(context, family: ItemFamily.exercise),
                child: const Text('Nouvel exercice'),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Nouvel exercice'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Équation');
    await tester.tap(find.text('Corrigé automatiquement (facultatif)'));
    await settle(tester);
    await tester.tap(find.text('Partir d\'un exemple'));
    await settle(tester);
    expect(find.text('Aperçu d\'un tirage'), findsOneWidget);
    final add = find.widgetWithText(FilledButton, 'Ajouter');
    expect(tester.widget<FilledButton>(add).onPressed, isNotNull);

    final json = find.widgetWithText(TextField, 'Modèle (JSON)');
    await tester.enterText(json, '{"v": 1, "statement": "[[z]]"}');
    await settle(tester);
    expect(find.textContaining('« z » non défini'), findsOneWidget);
    expect(tester.widget<FilledButton>(add).onPressed, isNull);

    await tester.enterText(json, model);
    await settle(tester);
    await tester.tap(add);
    await settle(tester);
    final item = (await tester.runAsync(store.allItems))!.single;
    expect(item.autoExercise, model);
    await unmountTestApp(tester);
  });
}
