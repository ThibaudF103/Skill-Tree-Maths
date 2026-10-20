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
    final store = await openEditor(tester);
    await tapVisible(tester, find.text('Partir d\'un exemple'));
    expect(find.text('Aperçu d\'un tirage'), findsOneWidget);
    final add = find.widgetWithText(FilledButton, 'Ajouter');
    expect(tester.widget<FilledButton>(add).onPressed, isNotNull);

    // L'exemple se lit dans le formulaire.
    expect(find.widgetWithText(TextFormField, 'a'), findsOneWidget);
    await tapVisible(tester, find.text('JSON'));
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

  testWidgets('formulaire : modèle écrit sans JSON, QCM, nom en double', (
    tester,
  ) async {
    final store = await openEditor(tester);
    Finder field(String label) => find.widgetWithText(TextFormField, label);
    Future<void> tap(Finder finder) => tapVisible(tester, finder);

    Future<void> type(Finder finder, String text) async {
      await tester.ensureVisible(finder);
      await tester.enterText(finder, text);
      await settle(tester);
    }

    await tap(find.text('Ajouter un paramètre'));
    await type(field('Nom'), 'n');
    await type(field('Min'), '2');
    await type(field('Max'), '5');
    await type(field('Énoncé'), r'Calculer $[[n]] \times 3$.');
    await type(field('Réponse (expression)'), '3n');
    expect(find.text('Aperçu d\'un tirage'), findsOneWidget);

    await tap(find.text('Ajouter une question'));
    await tap(find.text('QCM').last);
    await type(field('Choix 1'), 'pair');
    await type(field('Choix 2'), 'impair');
    // Bonne réponse retirée : à cocher de nouveau, pas de choix par défaut.
    await tap(find.text('Ajouter un choix'));
    await tap(find.byType(Radio<int>).last);
    await tap(find.byTooltip('Retirer le choix').last);
    expect(find.text('Cocher la bonne réponse'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Ajouter'))
          .onPressed,
      isNull,
    );
    await tap(find.byType(Radio<int>).last);
    expect(find.text('Cocher la bonne réponse'), findsNothing);

    await tap(find.text('Ajouter une valeur'));
    await type(field('Nom').last, 'n');
    expect(find.text('« n » est défini deux fois'), findsOneWidget);
    final add = find.widgetWithText(FilledButton, 'Ajouter');
    expect(tester.widget<FilledButton>(add).onPressed, isNull);
    await tap(find.byTooltip('Retirer la valeur'));

    // Le JSON écrit par le formulaire.
    await tap(find.text('JSON'));
    final written = tester
        .widget<TextField>(find.widgetWithText(TextField, 'Modèle (JSON)'))
        .controller!
        .text;
    final q = ExerciseTemplate.parse(written).generate(0).questions;
    expect(
      (q[1] as ChoiceQuestion).choices[(q[1] as ChoiceQuestion).correct],
      'impair',
    );
    expect(ExerciseDraft.tryParse(written)!.params.single.max, '5');
    await tap(find.text('Formulaire'));

    // Tout effacer puis tout retirer : plus de modèle, enregistrable.
    await type(field('Énoncé'), '');
    await type(field('Énoncé'), r'Calculer $[[n]] \times 3$.');
    await tap(find.text('Retirer le modèle'));
    expect(find.text('Retirer le modèle'), findsNothing);
    expect(tester.widget<FilledButton>(add).onPressed, isNotNull);
    await tap(find.text('Ajouter un paramètre'));
    await type(field('Nom'), 'x');
    await type(field('Nom'), '');
    await tap(find.byTooltip('Retirer le paramètre'));
    expect(find.text('Retirer le modèle'), findsNothing);

    // Puis le modèle de nouveau.
    await tap(find.text('Partir d\'un exemple'));
    expect(find.text('Retirer le modèle'), findsOneWidget);
    await tap(add);
    final item = (await tester.runAsync(store.allItems))!.single;
    expect(item.autoExercise, contains('Résoudre'));
    await unmountTestApp(tester);
  });
}

/// Fait défiler jusqu'à [finder], puis le touche.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
  await settle(tester);
}

/// Ouvre l'éditeur d'un nouvel exercice, rubrique « Corrigé
/// automatiquement » déployée, titre saisi.
Future<VergerStore> openEditor(WidgetTester tester) async {
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
  await tester.enterText(find.byType(TextField).first, 'Parité');
  await tester.tap(find.text('Corrigé automatiquement (facultatif)'));
  await settle(tester);
  return store;
}
