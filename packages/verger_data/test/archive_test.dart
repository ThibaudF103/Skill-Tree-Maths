import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

VergerStore memoryStore() =>
    VergerStore(VergerDatabase(NativeDatabase.memory()));

const autoModel = '{"v": 1, "statement": "", "questions": [{"answer": "1"}]}';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final scheduler = const SchedulerSettings().build();

  Future<VergerStore> populated() async {
    final store = memoryStore();
    final tree = await store.createNode(title: 'Algèbre');
    final branch = await store.createNode(
      title: 'Réduction',
      parentId: tree.id,
    );
    await store.createNode(title: 'Polynômes', parentId: branch.id);
    final item = await store.createItem(
      nodeId: branch.id,
      kind: ItemKind.theorem,
      title: 'Cayley-Hamilton',
      body: 'χ_u(u) = 0',
    );
    var state = item.scheduling;
    for (final rating in [Rating.good, Rating.good, Rating.easy]) {
      final record = scheduler.record(
        state,
        rating,
        state.due ?? DateTime.utc(2026, 3, 2, 9),
        fuzzKey: item.id,
      );
      await store.applyReview(item.id, record);
      state = record.after;
    }
    await store.createItem(
      nodeId: tree.id,
      kind: ItemKind.definition,
      title: 'Groupe',
    );
    await store.createItem(
      nodeId: tree.id,
      kind: ItemKind.exercise,
      title: 'Équation',
      autoExercise: autoModel,
    );
    await store.saveSchedulerSettings(
      const SchedulerSettings(desiredRetention: 0.92),
    );
    return store;
  }

  test('sauvegarde puis restauration à l\'identique (via JSON)', () async {
    final source = await populated();
    final archive = await source.exportArchive();
    final json = jsonEncode(archive.toJson());

    final target = memoryStore();
    await target.createNode(title: 'Données à remplacer');
    await target.restoreArchive(
      VergerArchive.fromJson((jsonDecode(json) as Map).cast()),
    );

    final a = await source.allNodes();
    final b = await target.allNodes();
    expect(
      b.map((n) => (n.id, n.parentId, n.title, n.sortIndex)),
      a.map((n) => (n.id, n.parentId, n.title, n.sortIndex)),
    );
    final itemsA = await source.allItems();
    final itemsB = await target.allItems();
    expect(
      itemsB.map((i) => (i.id, i.title, i.body, i.autoExercise, i.scheduling)),
      itemsA.map((i) => (i.id, i.title, i.body, i.autoExercise, i.scheduling)),
    );
    final theorem = itemsA.firstWhere((i) => i.title == 'Cayley-Hamilton');
    final historyA = await source.history(theorem.id);
    final historyB = await target.history(theorem.id);
    expect(
      historyB.map((r) => (r.rating, r.reviewedAt, r.after)),
      historyA.map((r) => (r.rating, r.reviewedAt, r.after)),
    );
    expect((await target.schedulerSettings()).desiredRetention, 0.92);

    await source.close();
    await target.close();
  });

  test(
    'un modèle s\'ajoute sans progression, avec de nouveaux identifiants',
    () async {
      final source = await populated();
      final template = await source.exportArchive();

      final target = memoryStore();
      final existing = await target.createNode(title: 'Analyse');
      final trees = await target.importTemplate(template);
      expect(trees.single.title, 'Algèbre');
      expect(trees.single.sortIndex, 1);

      final nodes = await target.allNodes();
      expect(nodes.map((n) => n.title).toSet(), {
        'Analyse',
        'Algèbre',
        'Réduction',
        'Polynômes',
      });
      expect(nodes.where((n) => n.id == existing.id), hasLength(1));
      final sourceIds = (await source.allNodes()).map((n) => n.id).toSet();
      expect(nodes.where((n) => sourceIds.contains(n.id)), isEmpty);

      final items = await target.allItems();
      expect(items.map((i) => i.title), [
        'Cayley-Hamilton',
        'Groupe',
        'Équation',
      ]);
      expect(items.last.autoExercise, autoModel);
      expect(
        items.every((i) => i.scheduling == SchedulingState.initial),
        isTrue,
      );
      expect(await target.history(items.first.id), isEmpty);
      final reduction = nodes.firstWhere((n) => n.title == 'Réduction');
      expect(items.first.nodeId, reduction.id);

      // Importer deux fois le même modèle : deux arbres distincts.
      await target.importTemplate(template);
      expect(
        (await target.allNodes()).where((n) => n.title == 'Algèbre'),
        hasLength(2),
      );

      await source.close();
      await target.close();
    },
  );

  test(
    'sauvegarde : ancres et documents ; PDF conservés sur l\'appareil',
    () async {
      final store = await populated();
      final item = (await store.allItems()).first;
      final notes = await store.importDocument(
        title: 'Carnet',
        bytes: Uint8List.fromList([1, 2, 3]),
        contentHash: 'h',
        fingerprints: [Uint8List(4), Uint8List(4)],
      );
      await store.addAnchor(
        itemId: item.id,
        documentId: notes.id,
        role: AnchorRole.work,
        page: 2,
        region: const NormalizedRect(0, 0.5, 1, 1),
        snapshot: Uint8List.fromList([137, 80, 78, 71]),
      );
      final json = jsonEncode((await store.exportArchive()).toJson());
      expect(json.contains('"bytes"'), isFalse);

      // Même appareil : on supprime l'ancre puis on restaure.
      await store.deleteAnchor((await store.anchorsOf(item.id)).single.id);
      await store.restoreArchive(
        VergerArchive.fromJson((jsonDecode(json) as Map).cast()),
      );
      final restored = (await store.anchorsOf(item.id)).single;
      expect(restored.page, 2);
      expect(restored.region, const NormalizedRect(0, 0.5, 1, 1));
      expect(restored.snapshot, [137, 80, 78, 71]);
      expect(await store.documentBytes(notes.id), [1, 2, 3]);

      // Autre appareil : le document est connu mais son PDF manque.
      final other = memoryStore();
      await other.restoreArchive(
        VergerArchive.fromJson((jsonDecode(json) as Map).cast()),
      );
      expect((await other.allDocuments()).single.title, 'Carnet');
      expect(await other.documentBytes(notes.id), isNull);
      expect((await other.anchorsOf(item.id)).single.snapshot, isNotNull);

      await store.close();
      await other.close();
    },
  );

  test(
    'restauration : un PDF d\'une autre version que la sauvegarde est retiré',
    () async {
      final store = await populated();
      final notes = await store.importDocument(
        title: 'Carnet',
        bytes: Uint8List.fromList([1]),
        contentHash: 'v1',
        fingerprints: [Uint8List(4)],
      );
      final json = jsonEncode((await store.exportArchive()).toJson());
      await store.updateDocument(
        notes.id,
        bytes: Uint8List.fromList([2]),
        contentHash: 'v2',
        fingerprints: [Uint8List(4), Uint8List(4)],
      );
      await store.restoreArchive(
        VergerArchive.fromJson((jsonDecode(json) as Map).cast()),
      );
      expect(await store.documentBytes(notes.id), isNull);
      expect((await store.document(notes.id))!.contentHash, 'v1');
      await store.close();
    },
  );
}
