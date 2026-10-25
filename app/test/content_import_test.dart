import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/features/documents/content_import.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'test_app.dart';

void main() {
  late String branchId;

  Future<void> seed(VergerStore store) async {
    final tree = await store.createNode(title: 'Analyse');
    branchId = (await store.createNode(title: 'Séries', parentId: tree.id)).id;
  }

  /// Ouvre le formulaire par-dessus l'application ; le résultat arrive dans
  /// le futur renvoyé.
  Future<ContentImport?> open(
    WidgetTester tester, {
    String? nodeId,
    Future<(String, Uint8List)?> Function()? pickPdf,
    Future<String?> Function(String)? fetchTitle,
  }) {
    final future = showDialog<ContentImport>(
      context: tester.element(find.byType(Scaffold).first),
      builder: (_) => ContentImportDialog(
        initialNodeId: nodeId,
        pickPdf: pickPdf ?? () async => null,
        fetchTitle: fetchTitle ?? (_) async => null,
      ),
    );
    return future;
  }

  FilledButton importButton(WidgetTester tester) =>
      tester.widget(find.widgetWithText(FilledButton, 'Importer'));

  testWidgets('un seul bouton dans la bibliothèque et le menu d\'une branche', (
    tester,
  ) async {
    await pumpTestApp(tester, seed: seed);
    await tester.tap(find.text('Bibliothèque'));
    await settle(tester);
    expect(find.text('Importer un contenu'), findsOneWidget);
    expect(find.text('Importer un PDF'), findsNothing);
    expect(find.text('Vidéo'), findsNothing);

    // Depuis une branche : elle est présélectionnée.
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Séries'));
    await settle(tester);
    await tester.tap(find.byTooltip('Actions'));
    await settle(tester);
    await tester.tap(find.text('Importer un contenu (PDF, vidéo)…'));
    await settle(tester);
    expect(find.text('Importer un contenu'), findsOneWidget);
    expect(find.text('Analyse › Séries'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await settle(tester);
    await unmountTestApp(tester);
  });

  testWidgets('PDF : fichier choisi, titre proposé, branche retirée', (
    tester,
  ) async {
    await pumpTestApp(tester, seed: seed);
    final bytes = Uint8List.fromList([1, 2, 3]);
    final result = open(
      tester,
      nodeId: branchId,
      pickPdf: () async => ('Poly de séries', bytes),
    );
    await settle(tester);
    expect(find.text('Analyse › Séries'), findsOneWidget);
    expect(importButton(tester).onPressed, isNull);

    await tester.tap(find.text('Choisir un fichier PDF…'));
    await settle(tester);
    expect(find.text('Poly de séries.pdf (changer)'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Poly de séries'), findsOneWidget);
    await tester.tap(find.byTooltip('Ne pas rattacher'));
    await settle(tester);
    expect(
      find.text('Aucune branche (bibliothèque seulement)'),
      findsOneWidget,
    );

    await tester.tap(find.text('Importer'));
    await settle(tester);
    final choice = (await result)!;
    expect(choice.kind, ResourceKind.pdf);
    expect(choice.title, 'Poly de séries');
    expect(choice.nodeId, isNull);
    expect(choice.bytes, bytes);
    await unmountTestApp(tester);
  });

  testWidgets('vidéo YouTube : adresse vérifiée, rattachée à la branche', (
    tester,
  ) async {
    await pumpTestApp(tester, seed: seed);
    final result = open(tester, nodeId: branchId);
    await settle(tester);
    await tester.tap(find.text('Vidéo YouTube'));
    await settle(tester);

    final url = find.widgetWithText(TextField, 'Adresse de la vidéo');
    await tester.enterText(url, 'https://vimeo.com/1');
    await settle(tester);
    expect(find.text('Adresse YouTube non reconnue'), findsOneWidget);
    expect(importButton(tester).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Titre'),
      'Cours sur les séries',
    );
    await tester.enterText(url, 'https://youtu.be/dQw4w9WgXcQ');
    await settle(tester);
    expect(find.text('Adresse YouTube non reconnue'), findsNothing);

    await tester.tap(find.text('Importer'));
    await settle(tester);
    final choice = (await result)!;
    expect(choice.kind, ResourceKind.video);
    expect(choice.videoId, 'dQw4w9WgXcQ');
    expect(choice.title, 'Cours sur les séries');
    expect(choice.nodeId, branchId);
    await unmountTestApp(tester);
  });

  testWidgets(
    'titre en cours de recherche, adresse effacée : plus d\'attente',
    (tester) async {
      await pumpTestApp(tester, seed: seed);
      final pending = Completer<String?>();
      open(tester, fetchTitle: (_) => pending.future);
      await settle(tester);
      await tester.tap(find.text('Vidéo YouTube'));
      await settle(tester);
      final url = find.widgetWithText(TextField, 'Adresse de la vidéo');
      await tester.enterText(url, 'https://youtu.be/dQw4w9WgXcQ');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.enterText(url, 'https://youtu.be/');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // La réponse tardive ne relance rien.
      pending.complete('Ancien titre');
      await settle(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.widgetWithText(TextField, 'Ancien titre'), findsNothing);
      await tester.tap(find.text('Annuler'));
      await settle(tester);
      await unmountTestApp(tester);
    },
  );
}
