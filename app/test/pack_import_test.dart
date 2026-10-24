import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/features/data/pack_actions.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

void main() {
  final t = DateTime.utc(2026, 3, 2);
  final tree = KnowledgeNode(
    id: 'n',
    title: 'Analyse',
    sortIndex: 0,
    createdAt: t,
  );
  final archive = VergerArchive(
    nodes: [tree],
    items: const [],
    title: 'Analyse',
  );

  /// Ouvre le dialogue et renvoie le choix après un appui sur [button].
  Future<PackImportMode?> choose(
    WidgetTester tester,
    PackImportPreview preview,
    String button,
  ) async {
    PackImportMode? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showDialog<PackImportMode>(
              context: context,
              builder: (_) =>
                  PackImportDialog(archive: archive, preview: preview),
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('arbre déjà présent, éléments en moins : remplacer ou combiner', (
    tester,
  ) async {
    final preview = PackImportPreview(
      existing: [tree],
      branches: 1,
      items: 2,
      notes: 3,
      reviews: 4,
    );
    expect(await choose(tester, preview, 'Combiner'), PackImportMode.combine);
    expect(await choose(tester, preview, 'Remplacer'), PackImportMode.replace);
    expect(await choose(tester, preview, 'Annuler'), isNull);

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        '1 branche(s), 2 connaissance(s) et 4 révision(s), 3 note(s)',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('« Analyse » est déjà'), findsOneWidget);
  });

  testWidgets('rien ne serait perdu : simple mise à jour', (tester) async {
    final preview = PackImportPreview(existing: [tree]);
    expect(
      await choose(tester, preview, 'Mettre à jour'),
      PackImportMode.replace,
    );
    expect(find.text('Combiner'), findsNothing);
  });

  testWidgets('arbre nouveau : import simple', (tester) async {
    expect(
      await choose(tester, const PackImportPreview(), 'Importer'),
      PackImportMode.replace,
    );
  });
}
