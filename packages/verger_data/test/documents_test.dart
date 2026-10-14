import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

const _n = fingerprintSide * fingerprintSide;

/// Empreinte d'une page de notes (fond blanc, encre aléatoire reproductible).
Uint8List page(int seed) {
  final random = Random(seed);
  final pixels = Uint8List(_n)..fillRange(0, _n, 250);
  for (var s = 0; s < 60; s++) {
    pixels[random.nextInt(_n)] = 70;
  }
  return pixels;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late VergerStore store;
  late KnowledgeItem item;

  setUp(() async {
    store = VergerStore(VergerDatabase(NativeDatabase.memory()));
    final node = await store.createNode(title: 'Réduction');
    item = await store.createItem(
      nodeId: node.id,
      kind: ItemKind.theorem,
      title: 'Cayley-Hamilton',
    );
  });
  tearDown(() => store.close());

  Future<SourceDocument> importNotes(List<Uint8List> pages) =>
      store.importDocument(
        title: 'Carnet',
        role: DocumentRole.notes,
        bytes: Uint8List.fromList([1, 2, 3]),
        contentHash: 'h${pages.length}',
        fingerprints: pages,
      );

  test('import : métadonnées, empreintes et contenu', () async {
    final doc = await importNotes([page(0), page(1), page(2)]);
    final stored = (await store.document(doc.id))!;
    expect(stored.title, 'Carnet');
    expect(stored.role, DocumentRole.notes);
    expect(stored.pageCount, 3);
    expect(stored.version, 1);
    expect(stored.fingerprints[2], page(2));
    expect(await store.documentBytes(doc.id), [1, 2, 3]);
    expect((await store.allDocuments()).single.id, doc.id);
  });

  test(
    'ancres recto/verso : ajout, lecture, recalage manuel, suppression',
    () async {
      final course = await store.importDocument(
        title: 'Algèbre.pdf',
        role: DocumentRole.course,
        bytes: Uint8List(1),
        contentHash: 'c',
        fingerprints: [page(10), page(11)],
      );
      final notes = await importNotes([page(0)]);
      final recto = await store.addAnchor(
        itemId: item.id,
        documentId: course.id,
        role: AnchorRole.source,
        page: 2,
        region: const NormalizedRect(0.1, 0.2, 0.9, 0.4),
        textSnippet: 'Théorème (Cayley-Hamilton)',
        snapshot: Uint8List.fromList([137, 80, 78, 71]),
      );
      await store.addAnchor(
        itemId: item.id,
        documentId: notes.id,
        role: AnchorRole.work,
        page: 1,
      );

      final anchors = await store.anchorsOf(item.id);
      expect(anchors.map((a) => a.role), [AnchorRole.source, AnchorRole.work]);
      expect(anchors.first.region, const NormalizedRect(0.1, 0.2, 0.9, 0.4));
      expect(anchors.first.snapshot, [137, 80, 78, 71]);
      expect(anchors.last.region, isNull);

      await store.relocateAnchor(recto.id, page: 1);
      final moved = (await store.anchorsOf(item.id)).first;
      expect(moved.page, 1);
      expect(moved.region, isNull);

      await store.deleteAnchor(recto.id);
      expect(await store.anchorsOf(item.id), hasLength(1));
    },
  );

  test(
    'mise à jour du carnet : pages insérées, recalage, nouvelles pages',
    () async {
      final notes = await importNotes([page(0), page(1), page(2)]);
      Future<Anchor> verso(int p) => store.addAnchor(
        itemId: item.id,
        documentId: notes.id,
        role: AnchorRole.work,
        page: p,
      );
      final a1 = await verso(1);
      final a3 = await verso(3);
      final a2 = await verso(2);

      // Page insérée au début, page 2 supprimée, une page ajoutée à la fin.
      final update = await store.updateDocument(
        notes.id,
        bytes: Uint8List.fromList([9]),
        contentHash: 'v2',
        fingerprints: [page(50), page(0), page(2), page(3)],
      );
      expect(update.moved, 1);
      expect(update.flagged, 1);
      expect(update.newPages, [1, 4]);

      final byId = {for (final a in await store.anchorsOf(item.id)) a.id: a};
      expect(byId[a1.id]!.page, 2);
      expect(byId[a1.id]!.needsReview, isFalse);
      expect(byId[a3.id]!.page, 3);
      expect(byId[a2.id]!.needsReview, isTrue);

      final doc = (await store.document(notes.id))!;
      expect(doc.version, 2);
      expect(doc.pageCount, 4);
      expect(doc.newPages, [1, 4]);
      expect(await store.documentBytes(notes.id), [9]);
    },
  );

  test(
    'supprimer un document supprime ses ancres, pas la connaissance',
    () async {
      final notes = await importNotes([page(0)]);
      await store.addAnchor(
        itemId: item.id,
        documentId: notes.id,
        role: AnchorRole.work,
        page: 1,
      );
      await store.deleteDocument(notes.id);
      expect(await store.allDocuments(), isEmpty);
      expect(await store.anchorsOf(item.id), isEmpty);
      expect(await store.item(item.id), isNotNull);
      expect(await store.documentBytes(notes.id), isNull);
    },
  );

  test('supprimer une connaissance supprime ses ancres', () async {
    final notes = await importNotes([page(0)]);
    await store.addAnchor(
      itemId: item.id,
      documentId: notes.id,
      role: AnchorRole.work,
      page: 1,
    );
    await store.deleteItem(item.id);
    final remaining = await store.watchAnchors(documentId: notes.id).first;
    expect(remaining, isEmpty);
  });
}
