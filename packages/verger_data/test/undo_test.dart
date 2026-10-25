import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late VergerStore store;
  late KnowledgeNode node;
  late KnowledgeItem def, thm, cor;
  late SourceDocument course;

  setUp(() async {
    store = VergerStore(VergerDatabase(NativeDatabase.memory()));
    node = await store.createNode(title: 'Suites');
    Future<KnowledgeItem> item(ItemKind kind, String t) =>
        store.createItem(nodeId: node.id, kind: kind, title: t);
    def = await item(ItemKind.definition, 'Suite de Cauchy');
    thm = await item(ItemKind.theorem, 'Complétude de R');
    cor = await item(ItemKind.corollary, 'Critère de Cauchy');
    await store.addPrerequisite(thm.id, def.id);
    await store.addPrerequisite(cor.id, thm.id);
    course = await store.importDocument(
      title: 'Analyse.pdf',
      bytes: Uint8List.fromList([1]),
      contentHash: 'c',
      fingerprints: [Uint8List(4), Uint8List(4)],
    );
  });
  tearDown(() => store.close());

  test('annuler la suppression d\'une connaissance rétablit tout', () async {
    final scheduler = const SchedulerSettings().build();
    final record = scheduler.record(
      thm.scheduling,
      Rating.good,
      DateTime.utc(2026, 3, 2),
      fuzzKey: thm.id,
    );
    await store.applyReview(thm.id, record);
    final reviewed = (await store.item(thm.id))!;
    final anchor = await store.addAnchor(
      itemId: thm.id,
      documentId: course.id,
      role: AnchorRole.source,
      page: 2,
      region: const NormalizedRect(0.1, 0.2, 0.9, 0.5),
      snapshot: Uint8List.fromList([137, 80]),
    );
    final note = await store.createNote(body: 'Preuve', itemId: thm.id);

    final deletion = await store.deleteItem(thm.id);
    expect(await store.item(thm.id), isNull);
    expect(await store.prerequisites(), isEmpty);
    expect((await store.note(note.id))!.itemId, isNull);

    await store.undoDeletion(deletion);
    final restored = (await store.item(thm.id))!;
    expect(restored.title, 'Complétude de R');
    expect(restored.scheduling, reviewed.scheduling);
    expect(await store.history(thm.id), hasLength(1));
    expect(await store.prerequisites(), hasLength(2));
    final anchors = await store.anchorsOf(thm.id);
    expect(anchors.single.id, anchor.id);
    expect(anchors.single.snapshot, [137, 80]);
    expect((await store.note(note.id))!.itemId, thm.id);
  });

  test('l\'annulation ignore les liens devenus impossibles', () async {
    final deletion = await store.deleteItem(thm.id);
    await store.deleteItem(cor.id); // l'autre bout d'un prérequis
    await store.undoDeletion(deletion);
    expect(await store.prerequisites(), [(itemId: thm.id, requiresId: def.id)]);
  });

  test('l\'annulation est refusée si la branche a disparu', () async {
    final deletion = await store.deleteItem(thm.id);
    await store.deleteNode(node.id, recursive: true);
    expect(() => store.undoDeletion(deletion), throwsA(isA<StateError>()));
  });

  test(
    'annuler le retrait d\'un lien recto / verso ou d\'un prérequis',
    () async {
      final anchor = await store.addAnchor(
        itemId: def.id,
        documentId: course.id,
        role: AnchorRole.work,
        page: 1,
        snapshot: Uint8List.fromList([1, 2, 3]),
      );
      final unlinked = await store.deleteAnchor(anchor.id);
      expect(await store.anchorsOf(def.id), isEmpty);
      await store.undoDeletion(unlinked);
      expect((await store.anchorsOf(def.id)).single.snapshot, [1, 2, 3]);

      final removed = await store.removePrerequisite(thm.id, def.id);
      expect(await store.prerequisites(), hasLength(1));
      await store.undoDeletion(removed);
      expect(await store.prerequisites(), hasLength(2));
    },
  );

  test('annulation impossible : message clair, pas d\'erreur SQL', () async {
    Matcher refused(String message) =>
        throwsA(isA<StateError>().having((e) => e.message, 'message', message));

    // Déjà revenue (sauvegarde restaurée avec le même identifiant).
    final deletion = await store.deleteItem(cor.id);
    await store.undoDeletion(deletion);
    expect(
      () => store.undoDeletion(deletion),
      refused('La connaissance est déjà revenue (sauvegarde restaurée ?).'),
    );

    final anchor = await store.addAnchor(
      itemId: def.id,
      documentId: course.id,
      role: AnchorRole.source,
      page: 1,
    );
    final unlinked = await store.deleteAnchor(anchor.id);
    await store.undoDeletion(unlinked);
    expect(
      () => store.undoDeletion(unlinked),
      refused('Ce lien est déjà revenu (sauvegarde restaurée ?).'),
    );
    final again = await store.deleteAnchor(anchor.id);
    await store.deleteDocument(course.id);
    expect(
      () => store.undoDeletion(again),
      refused('Le contenu (PDF ou vidéo) a été supprimé.'),
    );

    final removed = await store.removePrerequisite(thm.id, def.id);
    await store.deleteItem(def.id);
    expect(
      () => store.undoDeletion(removed),
      refused('L\'une des deux connaissances a été supprimée.'),
    );
  });
}
