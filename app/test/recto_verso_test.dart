import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'test_app.dart';

/// PNG 1×1 valide.
final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

Future<void> seed(VergerStore store) async {
  final tree = await store.createNode(title: 'Algèbre');
  final item = await store.createItem(
    nodeId: tree.id,
    kind: ItemKind.theorem,
    title: 'Cayley-Hamilton',
  );
  final course = await store.importDocument(
    title: 'Algèbre.pdf',
    bytes: Uint8List.fromList([1]),
    contentHash: 'c',
    fingerprints: [Uint8List(4), Uint8List(4)],
  );
  final notes = await store.importDocument(
    title: 'Carnet CollaNote',
    bytes: Uint8List.fromList([2]),
    contentHash: 'n',
    fingerprints: [Uint8List(4)],
  );
  await store.addAnchor(
    itemId: item.id,
    documentId: course.id,
    role: AnchorRole.source,
    page: 2,
    region: const NormalizedRect(0.1, 0.1, 0.9, 0.3),
    snapshot: Uint8List.fromList(png),
  );
  final verso = await store.addAnchor(
    itemId: item.id,
    documentId: notes.id,
    role: AnchorRole.work,
    page: 1,
    snapshot: Uint8List.fromList(png),
  );
  // Simule une mise à jour qui n'a pas retrouvé la page du verso.
  await store.updateDocument(
    notes.id,
    bytes: Uint8List.fromList([3]),
    contentHash: 'n2',
    fingerprints: [
      Uint8List.fromList([255, 255, 255, 255]),
    ],
  );
  expect((await store.anchorsOf(item.id)).last.id, verso.id);
}

void main() {
  testWidgets('bibliothèque : contenus, rattachements, filtre par arbre', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      seed: (store) async {
        await seed(store);
        final analysis = await store.createNode(title: 'Analyse');
        final docs = await store.allDocuments();
        final course = docs.firstWhere((d) => d.title == 'Algèbre.pdf');
        final tree = (await store.allNodes()).firstWhere(
          (n) => n.title == 'Algèbre',
        );
        await store.linkResource(course.id, tree.id);
        await store.addVideo(
          title: 'Cours filmé',
          url: 'https://youtu.be/abc',
          videoId: 'abc',
          nodeIds: [analysis.id],
        );
      },
    );
    await tester.tap(find.text('Bibliothèque'));
    await settle(tester);

    expect(find.text('Importer un PDF'), findsOneWidget);
    expect(find.text('Algèbre.pdf'), findsOneWidget);
    expect(find.text('Carnet CollaNote'), findsOneWidget);
    expect(find.text('Cours filmé'), findsOneWidget);
    expect(find.textContaining('1 recto'), findsOneWidget);
    expect(find.textContaining('1 verso'), findsOneWidget);
    expect(find.textContaining('version 2'), findsOneWidget);
    expect(find.textContaining('1 lien(s) à vérifier'), findsOneWidget);
    expect(find.textContaining('Rattaché à aucune branche'), findsOneWidget);

    // Filtre : seulement les contenus de l'arbre « Analyse ».
    await tester.tap(find.widgetWithText(ChoiceChip, 'Analyse'));
    await settle(tester);
    expect(find.text('Cours filmé'), findsOneWidget);
    expect(find.text('Algèbre.pdf'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Non rattachés'));
    await settle(tester);
    expect(find.text('Carnet CollaNote'), findsOneWidget);
    expect(find.text('Cours filmé'), findsNothing);
    await unmountTestApp(tester);
  });

  testWidgets('contenus d\'un nœud : rattachés et hérités', (tester) async {
    late String courseId;
    final store = await pumpTestApp(
      tester,
      seed: (store) async {
        await seed(store);
        final tree = (await store.allNodes()).single;
        await store.createNode(title: 'Réduction', parentId: tree.id);
        courseId = (await store.allDocuments())
            .firstWhere((d) => d.title == 'Algèbre.pdf')
            .id;
        await store.linkResource(courseId, tree.id);
      },
    );
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    expect(find.text('Contenus'), findsOneWidget);
    expect(find.text('Algèbre.pdf'), findsOneWidget);

    // La branche hérite du contenu de l'arbre.
    await tester.tap(find.text('Réduction').last);
    await settle(tester);
    expect(find.text('Algèbre.pdf'), findsOneWidget);
    expect(find.textContaining('via « Algèbre »'), findsOneWidget);
    expect(find.byTooltip('Détacher de cette branche'), findsNothing);

    // Rattacher le carnet à la branche, puis le détacher.
    await tester.ensureVisible(find.text('Contenu'));
    await tester.tap(find.text('Contenu'));
    await settle(tester);
    await tester.tap(find.text('Rattacher un contenu existant'));
    await settle(tester);
    // Le contenu hérité reste proposé (rattachement direct possible).
    expect(
      find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.text('Algèbre.pdf'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Carnet CollaNote'));
    await settle(tester);
    expect(find.byTooltip('Détacher de cette branche'), findsOneWidget);
    await tester.tap(find.byTooltip('Détacher de cette branche'));
    await settle(tester);
    expect(find.text('Carnet CollaNote'), findsNothing);
    expect(await tester.runAsync(store.resourceLinks), [
      (
        documentId: courseId,
        nodeId: (await tester.runAsync(
          store.allNodes,
        ))!.firstWhere((n) => n.title == 'Algèbre').id,
      ),
    ]);
    await unmountTestApp(tester);
  });

  testWidgets('fiche : section recto / verso', (tester) async {
    await pumpTestApp(tester, seed: seed);
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.text('Cayley-Hamilton'));
    await settle(tester);

    expect(find.text('Recto / verso'), findsOneWidget);
    expect(find.text('Recto'), findsOneWidget);
    expect(find.text('Verso'), findsOneWidget);
    expect(find.textContaining('Algèbre.pdf · p. 2'), findsOneWidget);
    expect(find.text('Page à vérifier'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('Attacher une zone d\'un PDF'), findsOneWidget);

    // Retirer le verso.
    await tester.tap(find.byTooltip('Retirer ce lien').last);
    await settle(tester);
    expect(find.text('Verso'), findsNothing);
    expect(find.byType(Image), findsOneWidget);

    // … puis annuler : il revient tel quel, miniature comprise.
    expect(find.text('Verso retiré'), findsOneWidget);
    await tester.tap(find.widgetWithText(SnackBarAction, 'Annuler'));
    await settle(tester);
    expect(find.text('Verso'), findsOneWidget);
    expect(find.text('Page à vérifier'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    await unmountTestApp(tester);
  });

  testWidgets('révision : recto visible, verso révélé', (tester) async {
    await pumpTestApp(tester, seed: seed);
    await tester.tap(find.text('Révisions'));
    await settle(tester);
    await tester.tap(find.text('Commencer (1)'));
    await settle(tester);

    expect(find.text('Cayley-Hamilton'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget); // recto seulement
    await tester.tap(find.text('Révéler'));
    await settle(tester);
    expect(find.byType(Image), findsNWidgets(2)); // + verso
    expect(find.textContaining('comparez avec vos notes'), findsNothing);
    await tester.tap(find.byTooltip('Terminer'));
    await settle(tester);
    await unmountTestApp(tester);
  });
}
