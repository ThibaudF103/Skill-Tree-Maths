import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/features/notes/note_split.dart';
import 'package:verger/features/notes/notes_panel.dart';

import 'notes_widgets_test.dart' show seedItem;
import 'test_app.dart';

const _content = Key('content');
const _note = Key('note');

/// Écran partagé de [height] pixels, note ouverte ou non.
Widget _split({double height = 800, bool open = true, VoidCallback? onClose}) =>
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: height,
            child: NoteSplit(
              onClose: onClose,
              content: const ColoredBox(key: _content, color: Colors.blue),
              note: open
                  ? const ColoredBox(key: _note, color: Colors.green)
                  : null,
            ),
          ),
        ),
      ),
    );

double _height(WidgetTester tester, Key key) =>
    tester.getSize(find.byKey(key)).height;

void main() {
  setUp(NoteSplit.resetSize);

  Future<void> pumpSplit(WidgetTester tester, Widget split) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(split);
  }

  testWidgets('la poignée règle la hauteur de la note, dans ses bornes', (
    tester,
  ) async {
    await pumpSplit(tester, _split());
    const handle = NoteSplit.handleHeight;
    // Hauteur par défaut : 45 % de l'écran.
    expect(_height(tester, _note), closeTo(800 * 0.45, 0.01));
    expect(
      _height(tester, _content) + handle + _height(tester, _note),
      closeTo(800, 0.01),
    );
    final before = _height(tester, _note);

    // Vers le haut : la note grandit d'autant.
    await tester.drag(find.byKey(NoteSplit.handleKey), const Offset(0, -100));
    await tester.pump();
    expect(_height(tester, _note), closeTo(before + 100, 1));

    // Tout en haut : le contenu garde sa hauteur minimale.
    await tester.drag(find.byKey(NoteSplit.handleKey), const Offset(0, -2000));
    await tester.pump();
    expect(_height(tester, _content), closeTo(NoteSplit.minContentHeight, 1));

    // Tout en bas : la note garde sa hauteur minimale.
    await tester.drag(find.byKey(NoteSplit.handleKey), const Offset(0, 2000));
    await tester.pump();
    expect(_height(tester, _note), closeTo(NoteSplit.minNoteHeight, 1));

    // La hauteur choisie est retenue pour la prochaine note.
    await pumpSplit(tester, _split(open: false));
    expect(find.byKey(_note), findsNothing);
    expect(_height(tester, _content), 800);
    await pumpSplit(tester, _split());
    expect(_height(tester, _note), closeTo(NoteSplit.minNoteHeight, 1));
  });

  testWidgets('agrandir, réduire, fermer', (tester) async {
    var closed = false;
    await pumpSplit(tester, _split(onClose: () => closed = true));
    await tester.tap(find.byTooltip('Agrandir la note'));
    await tester.pump();
    // Le contenu est masqué (mais conservé), la note prend tout.
    expect(find.byKey(_content), findsNothing);
    expect(find.byKey(_content, skipOffstage: false), findsOneWidget);
    expect(_height(tester, _note), 800 - NoteSplit.handleHeight);

    await tester.tap(find.byTooltip('Réduire la note'));
    await tester.pump();
    expect(find.byKey(_content), findsOneWidget);

    // Glisser depuis le plein écran revient à l'écran partagé.
    await tester.tap(find.byTooltip('Agrandir la note'));
    await tester.pump();
    await tester.drag(find.byKey(NoteSplit.handleKey), const Offset(0, 200));
    await tester.pump();
    expect(find.byKey(_content), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer la note'));
    expect(closed, isTrue);
  });

  testWidgets('écran trop bas : la note prend toute la hauteur', (
    tester,
  ) async {
    await pumpSplit(tester, _split(height: 300));
    expect(find.byKey(_content), findsNothing);
    expect(_height(tester, _note), 300 - NoteSplit.handleHeight);
    expect(find.byTooltip('Agrandir la note'), findsNothing);
  });

  testWidgets('fiche : la note s\'ouvre sous la fiche, qui reste visible', (
    tester,
  ) async {
    final store = await pumpTestApp(tester, seed: seedItem);
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.text('Cayley-Hamilton'));
    await settle(tester);
    await tester.ensureVisible(find.text('Nouvelle note'));
    await tester.tap(find.text('Nouvelle note'));
    await settle(tester);

    // Fiche et note à l'écran ensemble.
    expect(find.byType(NoteEditor), findsOneWidget);
    expect(find.text('Cayley-Hamilton'), findsWidgets);
    expect(
      tester.getTopLeft(find.byType(NoteEditor)).dy,
      greaterThan(tester.getTopLeft(find.text('Cayley-Hamilton').first).dy),
    );
    await tester.tap(find.text('Clavier'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Récurrence');
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);

    await tester.tap(find.byTooltip('Fermer la note'));
    await settle(tester);
    expect(find.byType(NoteEditor), findsNothing);
    final notes = (await tester.runAsync(store.notes))!;
    expect(notes.single.body, 'Récurrence');
    expect(find.text('Récurrence'), findsOneWidget); // rendue dans la fiche
    await unmountTestApp(tester);
  });
}
