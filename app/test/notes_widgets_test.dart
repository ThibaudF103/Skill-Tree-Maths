import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/app/app_scope.dart';
import 'package:verger/features/notes/notes_panel.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'test_app.dart';

Future<KnowledgeItem> seedItem(VergerStore store) async {
  final tree = await store.createNode(title: 'Algèbre');
  return store.createItem(
    nodeId: tree.id,
    kind: ItemKind.theorem,
    title: 'Cayley-Hamilton',
  );
}

void main() {
  testWidgets('fiche : rédiger une note (enregistrée, rendue en LaTeX)', (
    tester,
  ) async {
    final store = await pumpTestApp(tester, seed: seedItem);
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.text('Cayley-Hamilton'));
    await settle(tester);

    expect(find.text('Notes'), findsOneWidget);
    await tester.ensureVisible(find.text('Nouvelle note'));
    await tester.tap(find.text('Nouvelle note'));
    await settle(tester);

    await tester.enterText(
      find.byType(TextField).first,
      r'Par densité : $\chi_u(u) = 0$.',
    );
    await tester.pump(const Duration(milliseconds: 700)); // enregistrement
    await settle(tester);
    expect(find.byType(Math), findsOneWidget); // aperçu

    await tester.pageBack();
    await settle(tester);
    final items = (await tester.runAsync(store.allItems))!;
    final notes = (await tester.runAsync(
      () => store.notes(itemId: items.single.id),
    ))!;
    expect(notes.single.body, r'Par densité : $\chi_u(u) = 0$.');
    expect(find.byType(Math), findsOneWidget); // rendu dans la fiche
    await unmountTestApp(tester);
  });

  testWidgets('révision : la note liée apparaît au verso', (tester) async {
    await pumpTestApp(
      tester,
      seed: (store) async {
        final item = await seedItem(store);
        await store.createNote(
          body: r'Démonstration : $$\det(XI - A)$$',
          itemId: item.id,
        );
      },
    );
    await tester.tap(find.text('Révisions'));
    await settle(tester);
    await tester.tap(find.text('Commencer (1)'));
    await settle(tester);
    expect(find.byType(Math), findsNothing);
    await tester.tap(find.text('Révéler'));
    await settle(tester);
    expect(find.byType(Math), findsOneWidget);
    expect(find.textContaining('comparez avec vos notes'), findsNothing);
    await tester.tap(find.byTooltip('Terminer'));
    await settle(tester);
    await unmountTestApp(tester);
  });

  testWidgets('panneau de notes : liste par page, édition, lien', (
    tester,
  ) async {
    late VergerStore store;
    late SourceDocument doc;
    late KnowledgeItem item;
    await pumpTestApp(
      tester,
      seed: (s) async {
        store = s;
        item = await seedItem(s);
        doc = await s.importDocument(
          title: 'Cours',
          bytes: Uint8List(1),
          contentHash: 'h',
          fingerprints: [Uint8List(4), Uint8List(4)],
        );
        await s.createNote(body: 'Sur la page 2', documentId: doc.id, page: 2);
        await s.createNote(
          body: 'Liée',
          documentId: doc.id,
          page: 1,
          itemId: item.id,
        );
      },
    );

    String? active;
    var notes = (await tester.runAsync(() => store.notes(documentId: doc.id)))!;
    Widget panel() => AppScope(
      store: store,
      scheduler: const SchedulerSettings().build(),
      reloadSettings: () async {},
      child: MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => NotesPanel(
              document: doc,
              notes: notes,
              activeNoteId: active,
              currentPage: 2,
              onSelect: (id) => setState(() => active = id),
              onClose: () {},
              onGoTo: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(panel());
    await settle(tester);

    expect(find.text('Liée'), findsOneWidget);
    expect(find.text('Sur la page 2'), findsOneWidget);
    expect(find.text('Liée à une connaissance'), findsOneWidget);
    expect(find.text('Note p. 2'), findsOneWidget);

    await tester.tap(find.text('Liée'));
    await settle(tester);
    expect(find.text('Note · p. 1'), findsOneWidget);
    expect(find.text('Cette note est son verso'), findsOneWidget);
    expect(find.text('Cayley-Hamilton'), findsOneWidget);

    // Délier.
    await tester.tap(find.byTooltip('Délier'));
    await settle(tester);
    notes = (await tester.runAsync(() => store.notes(documentId: doc.id)))!;
    expect(notes.firstWhere((n) => n.body == 'Liée').itemId, isNull);
    await unmountTestApp(tester);
  });

  testWidgets('lier une note de cours : verso + zone devenue recto', (
    tester,
  ) async {
    late VergerStore store;
    late Note note;
    late KnowledgeItem item;
    late SourceDocument doc;
    await pumpTestApp(
      tester,
      seed: (s) async {
        store = s;
        item = await seedItem(s);
        doc = await s.importDocument(
          title: 'Cours',
          bytes: Uint8List(1),
          contentHash: 'h',
          fingerprints: [Uint8List(4)],
        );
        note = await s.createNote(
          body: 'Ma preuve',
          documentId: doc.id,
          page: 1,
          region: const NormalizedRect(0.1, 0.1, 0.9, 0.3),
          snapshot: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
          ),
        );
      },
    );
    await tester.pumpWidget(
      AppScope(
        store: store,
        scheduler: const SchedulerSettings().build(),
        reloadSettings: () async {},
        child: MaterialApp(
          home: Scaffold(
            body: NoteEditor(
              note: note,
              document: doc,
              onGoTo: null,
              onDeleted: () {},
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Lier à une connaissance'));
    await settle(tester);
    await tester.tap(find.text('Cayley-Hamilton'));
    await settle(tester);

    final linked = (await tester.runAsync(() => store.note(note.id)))!;
    expect(linked.itemId, item.id);
    final anchors = (await tester.runAsync(() => store.anchorsOf(item.id)))!;
    expect(anchors.single.role, AnchorRole.source);
    expect(anchors.single.region, const NormalizedRect(0.1, 0.1, 0.9, 0.3));
    expect(find.textContaining('Note liée'), findsOneWidget);
    await unmountTestApp(tester);
  });

  testWidgets('une note créée puis laissée vide est supprimée', (tester) async {
    final store = await pumpTestApp(tester, seed: seedItem);
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.text('Cayley-Hamilton'));
    await settle(tester);
    await tester.ensureVisible(find.text('Nouvelle note'));
    await tester.tap(find.text('Nouvelle note'));
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    expect(await tester.runAsync(store.notes), isEmpty);
    expect(find.text('Note vide'), findsNothing);
    await unmountTestApp(tester);
  });
}
