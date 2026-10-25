import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/features/notes/ink_view.dart';
import 'package:verger/features/notes/note_split.dart';
import 'package:verger/features/notes/notes_panel.dart';
import 'package:verger/features/review/review_session_page.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'test_app.dart';

Future<void> seed(VergerStore store) async {
  final tree = await store.createNode(title: 'Algèbre');
  await store.createItem(
    nodeId: tree.id,
    kind: ItemKind.theorem,
    title: 'Théorème spectral',
    body: 'Tout endomorphisme autoadjoint est diagonalisable en BON.',
  );
}

/// Lance une session sur l'unique connaissance, zone de notes ouverte.
Future<void> startWithNotes(WidgetTester tester) async {
  await tester.tap(find.text('Révisions'));
  await settle(tester);
  await tester.tap(find.text('Commencer (1)'));
  await settle(tester);
  await tester.tap(find.byTooltip('Prendre des notes'));
  await settle(tester);
}

void main() {
  setUp(() {
    NoteEditor.forgetMode();
    NoteSplit.resetSize();
    ReviewSessionPage.closeNotes();
  });

  testWidgets('tentative au clavier : comparée au verso, enregistrée', (
    tester,
  ) async {
    final store = await pumpTestApp(tester, seed: seed);
    await startWithNotes(tester);
    expect(find.text('Votre tentative'), findsOneWidget);
    await tester.tap(find.text('Clavier'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Autoadjoint : BON');
    // Espace pendant la saisie : écrit, ne révèle pas.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.textContaining('diagonalisable'), findsNothing);

    await tester.tap(find.text('Révéler'));
    await settle(tester);
    // Verso et tentative à l'écran ensemble.
    expect(find.textContaining('diagonalisable'), findsOneWidget);
    expect(find.text('Autoadjoint : BON'), findsOneWidget);
    expect(find.text('Votre tentative : comparez au verso'), findsOneWidget);
    // Révéler rend la main aux raccourcis ; mais un chiffre tapé dans la
    // tentative (de nouveau touchée) ne note pas la carte.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump();
    expect(find.text('Session terminée'), findsNothing);

    await tester.tap(find.text('Difficile'));
    await settle(tester);
    expect(find.text('Session terminée'), findsOneWidget);

    final item = (await tester.runAsync(store.allItems))!.single;
    final note = (await tester.runAsync(
      () => store.notes(itemId: item.id),
    ))!.single;
    expect(note.body, 'Autoadjoint : BON');
    expect(note.isReviewAttempt, isTrue);
    expect(note.reviewRating, Rating.hard);
    await unmountTestApp(tester);
  });

  testWidgets('tentative au stylet, enregistrée', (tester) async {
    final store = await pumpTestApp(tester, seed: seed);
    await startWithNotes(tester);
    await tester.tap(find.text('Stylet'));
    await tester.pump();
    final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is InkPainter,
    );
    final pen = await tester.startGesture(
      tester.getTopLeft(canvas.first) + const Offset(40, 40),
      kind: PointerDeviceKind.stylus,
    );
    for (var i = 1; i <= 10; i++) {
      await pen.moveBy(const Offset(10, 3));
    }
    await pen.up();
    await tester.pump();
    await tester.tap(find.text('Révéler'));
    await settle(tester);
    await tester.tap(find.text('À revoir'));
    await settle(tester);

    final item = (await tester.runAsync(store.allItems))!.single;
    final note = (await tester.runAsync(
      () => store.notes(itemId: item.id),
    ))!.single;
    expect(note.ink!.strokes, hasLength(1));
    expect(note.reviewRating, Rating.again);

    await unmountTestApp(tester);
  });

  testWidgets('une tentative passée n\'est pas reprise au verso', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      seed: (store) async {
        await seed(store);
        final item = (await store.allItems()).single;
        await store.createNote(
          body: 'Ancien essai',
          itemId: item.id,
          reviewRating: Rating.again,
        );
      },
    );
    await tester.tap(find.text('Révisions'));
    await settle(tester);
    await tester.tap(find.text('Commencer (1)'));
    await settle(tester);
    await tester.tap(find.text('Révéler'));
    await settle(tester);
    expect(find.textContaining('diagonalisable'), findsOneWidget);
    expect(find.text('Ancien essai'), findsNothing);
    await tester.tap(find.byTooltip('Terminer'));
    await settle(tester);
    await unmountTestApp(tester);
  });

  testWidgets('tentative vide : rien d\'enregistré', (tester) async {
    final store = await pumpTestApp(tester, seed: seed);
    await startWithNotes(tester);
    await tester.tap(find.text('Révéler'));
    await settle(tester);
    await tester.tap(find.text('Correct'));
    await settle(tester);
    expect(find.text('Session terminée'), findsOneWidget);
    expect(await tester.runAsync(store.notes), isEmpty);
    await unmountTestApp(tester);
  });

  testWidgets('fiche : tentatives en historique, la plus récente d\'abord', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      seed: (store) async {
        await seed(store);
        final item = (await store.allItems()).single;
        await store.createNote(body: 'Démonstration', itemId: item.id);
        await store.createNote(
          body: 'Premier essai',
          itemId: item.id,
          reviewRating: Rating.again,
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await store.createNote(
          body: 'Second essai',
          itemId: item.id,
          reviewRating: Rating.good,
        );
      },
    );
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.text('Théorème spectral'));
    await settle(tester);
    await tester.ensureVisible(find.text('Tentatives en révision (2)'));
    await tester.pump();

    final header = tester.getTopLeft(find.text('Tentatives en révision (2)'));
    final first = tester.getTopLeft(find.text('Second essai'));
    final second = tester.getTopLeft(find.text('Premier essai'));
    // La note ordinaire avant l'historique, puis du plus récent au plus ancien.
    expect(
      tester.getTopLeft(find.text('Démonstration')).dy,
      lessThan(header.dy),
    );
    expect(first.dy, greaterThan(header.dy));
    expect(second.dy, greaterThan(first.dy));
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('À revoir'), findsOneWidget);
    expect(find.textContaining('Révision du '), findsNWidgets(2));
    await unmountTestApp(tester);
  });

  testWidgets('écrire, révéler : 1 à 4 notent la carte', (tester) async {
    final store = await pumpTestApp(tester, seed: seed);
    await startWithNotes(tester);
    await tester.tap(find.text('Clavier'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'BON');
    await tester.tap(find.text('Révéler'));
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await settle(tester);
    expect(find.text('Session terminée'), findsOneWidget);
    final note = (await tester.runAsync(store.notes))!.single;
    expect(note.reviewRating, Rating.good);
    await unmountTestApp(tester);
  });

  testWidgets('zone de notes fermée en pleine saisie : Espace révèle', (
    tester,
  ) async {
    await pumpTestApp(tester, seed: seed);
    await startWithNotes(tester);
    await tester.tap(find.text('Clavier'));
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.byTooltip('Fermer la note'));
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect(find.textContaining('diagonalisable'), findsOneWidget);
    await tester.tap(find.byTooltip('Terminer'));
    await settle(tester);
    await unmountTestApp(tester);
  });

  testWidgets('passage au stylet depuis la saisie : Espace révèle', (
    tester,
  ) async {
    await pumpTestApp(tester, seed: seed);
    await startWithNotes(tester);
    await tester.tap(find.text('Clavier'));
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.text('Stylet'));
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect(find.textContaining('diagonalisable'), findsOneWidget);
    await tester.tap(find.byTooltip('Terminer'));
    await settle(tester);
    await unmountTestApp(tester);
  });

  testWidgets('quitter avec une tentative : garder ou jeter', (tester) async {
    final store = await pumpTestApp(tester, seed: seed);
    await startWithNotes(tester);
    await tester.tap(find.text('Clavier'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Brouillon');

    // Jeter : rien d'enregistré, la session se ferme.
    await tester.tap(find.byTooltip('Terminer'));
    await settle(tester);
    expect(find.text('Garder votre tentative ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await settle(tester);
    expect(find.text('Brouillon'), findsOneWidget); // toujours là
    await tester.tap(find.byTooltip('Terminer'));
    await settle(tester);
    await tester.tap(find.text('Jeter'));
    await settle(tester);
    expect(find.byType(ReviewSessionPage), findsNothing);
    expect(await tester.runAsync(store.notes), isEmpty);

    // Garder : note ordinaire de la connaissance, sans note de révision.
    await tester.tap(find.text('Commencer (1)'));
    await settle(tester);
    await tester.tap(find.text('Clavier'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'À garder');
    await tester.tap(find.byTooltip('Terminer'));
    await settle(tester);
    await tester.tap(find.text('Garder'));
    await settle(tester);
    expect(find.byType(ReviewSessionPage), findsNothing);
    final item = (await tester.runAsync(store.allItems))!.single;
    final note = (await tester.runAsync(store.notes))!.single;
    expect(note.body, 'À garder');
    expect(note.itemId, item.id);
    expect(note.isReviewAttempt, isFalse);
    // La carte n'a pas été révisée.
    expect(item.scheduling.reps, 0);
    await unmountTestApp(tester);
  });

  testWidgets('révisée ailleurs entre-temps : tentative gardée sans note', (
    tester,
  ) async {
    final store = await pumpTestApp(tester, seed: seed);
    await startWithNotes(tester);
    await tester.tap(find.text('Clavier'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Essai');
    await tester.tap(find.text('Révéler'));
    await settle(tester);
    // Révision concurrente (autre appareil, autre fenêtre).
    await tester.runAsync(() async {
      final item = (await store.allItems()).single;
      await store.applyReview(
        item.id,
        const SchedulerSettings().build().record(
          item.scheduling,
          Rating.easy,
          DateTime.now(),
        ),
      );
    });
    await tester.tap(find.text('À revoir'));
    await settle(tester);
    final note = (await tester.runAsync(store.notes))!.single;
    expect(note.body, 'Essai');
    expect(note.isReviewAttempt, isFalse);
    final history = (await tester.runAsync(() => store.history(note.itemId!)))!;
    expect(history.single.rating, Rating.easy);
    await unmountTestApp(tester);
  });
}
