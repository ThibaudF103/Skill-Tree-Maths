import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'test_app.dart';

/// Un paquet dont le PDF n'a pas pu être téléchargé : zones sans miniature
/// ni fichier. Plus une zone sur une page qui n'existe pas.
Future<void> seed(VergerStore store) async {
  final tree = await store.createNode(title: 'Poly');
  final item = await store.createItem(
    nodeId: tree.id,
    kind: ItemKind.theorem,
    title: 'Cayley-Hamilton',
  );
  final poly = await store.importDocument(
    title: 'Poly-Agreg.pdf',
    url: 'https://exemple.fr/Poly-Agreg.pdf',
    bytes: Uint8List.fromList([1]),
    contentHash: 'poly',
    fingerprints: [Uint8List(4), Uint8List(4), Uint8List(4)],
  );
  await store.addAnchor(
    itemId: item.id,
    documentId: poly.id,
    role: AnchorRole.source,
    page: 2,
    region: const NormalizedRect(0.1, 0.2, 0.9, 0.4),
  );
  final archive = await store.exportTree(tree.id);
  await store.deleteNode(tree.id, recursive: true);
  await store.deleteDocument(poly.id);
  await store.importPack(archive); // sans le fichier

  final other = await store.createNode(title: 'Algèbre');
  final lemma = await store.createItem(
    nodeId: other.id,
    kind: ItemKind.lemma,
    title: 'Lemme des noyaux',
  );
  final course = await store.importDocument(
    title: 'Cours.pdf',
    bytes: Uint8List.fromList([2]),
    contentHash: 'cours',
    fingerprints: [Uint8List(4)],
  );
  await store.addAnchor(
    itemId: lemma.id,
    documentId: course.id,
    role: AnchorRole.source,
    page: 5,
    region: const NormalizedRect(0, 0, 1, 0.5),
  );
}

void main() {
  testWidgets('zone sans PDF sur l\'appareil : la raison et l\'import', (
    tester,
  ) async {
    await pumpTestApp(tester, seed: seed);
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.text('Poly').first);
    await settle(tester);
    await tester.tap(find.text('Cayley-Hamilton'));
    await settle(tester);

    expect(find.text('PDF absent de cet appareil'), findsOneWidget);
    expect(find.textContaining('Importez « Poly-Agreg.pdf »'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Importer le PDF…'),
      findsOneWidget,
    );
    await unmountTestApp(tester);
  });

  testWidgets('zone sur une page absente du PDF', (tester) async {
    await pumpTestApp(tester, seed: seed);
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.text('Algèbre'));
    await settle(tester);
    await tester.tap(find.text('Lemme des noyaux'));
    await settle(tester);

    expect(find.text('Page 5 introuvable'), findsOneWidget);
    expect(find.text('Le PDF n\'a qu\'une page.'), findsOneWidget);
    expect(find.text('Importer le PDF…'), findsNothing);
    await unmountTestApp(tester);
  });
}
