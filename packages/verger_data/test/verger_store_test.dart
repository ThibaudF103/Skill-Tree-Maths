import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late VergerStore store;
  var now = DateTime.utc(2026, 3, 2, 9);

  setUp(() {
    now = DateTime.utc(2026, 3, 2, 9);
    store = VergerStore(
      VergerDatabase(NativeDatabase.memory()),
      clock: () => now,
    );
  });
  tearDown(() => store.close());

  group('hiérarchie', () {
    test('arbres, branches et rameaux de profondeur libre', () async {
      final algebre = await store.createNode(title: 'Algèbre');
      final ev = await store.createNode(
        title: 'Espaces vectoriels',
        parentId: algebre.id,
      );
      final base = await store.createNode(title: 'Bases', parentId: ev.id);
      final reduction = await store.createNode(
        title: 'Réduction',
        parentId: algebre.id,
      );
      await store.createNode(title: 'Analyse');

      final nodes = await store.allNodes();
      expect(nodes, hasLength(5));
      expect(nodes.where((n) => n.isTree).map((n) => n.title), [
        'Algèbre',
        'Analyse',
      ]);
      expect(base.parentId, ev.id);
      expect(ev.sortIndex, 0);
      expect(reduction.sortIndex, 1);
      expect(algebre.origin, NodeOrigin.user);
    });

    test('renommer et déplacer en conservant un ordre compact', () async {
      final a = await store.createNode(title: 'A');
      final b1 = await store.createNode(title: 'B1', parentId: a.id);
      final b2 = await store.createNode(title: 'B2', parentId: a.id);
      final b3 = await store.createNode(title: 'B3', parentId: a.id);
      final c = await store.createNode(title: 'C');

      await store.renameNode(b2.id, '  B2 bis ');
      await store.moveNode(b3.id, newParentId: a.id, index: 0);
      await store.moveNode(b1.id, newParentId: c.id);

      Future<List<String>> children(String id) async => [
        for (final n in await store.allNodes())
          if (n.parentId == id) '${n.sortIndex}:${n.title}',
      ];
      expect(await children(a.id), ['0:B3', '1:B2 bis']);
      expect(await children(c.id), ['0:B1']);
    });

    test('interdit de déplacer un nœud dans sa descendance', () async {
      final a = await store.createNode(title: 'A');
      final b = await store.createNode(title: 'B', parentId: a.id);
      final c = await store.createNode(title: 'C', parentId: b.id);
      expect(
        () => store.moveNode(a.id, newParentId: c.id),
        throwsArgumentError,
      );
      expect(
        () => store.moveNode(a.id, newParentId: a.id),
        throwsArgumentError,
      );
    });

    test('suppression : refusée si non vide, sauf en récursif', () async {
      final a = await store.createNode(title: 'A');
      final b = await store.createNode(title: 'B', parentId: a.id);
      final item = await store.createItem(
        nodeId: b.id,
        kind: ItemKind.theorem,
        title: 'Cayley-Hamilton',
      );
      final scheduler = const SchedulerSettings().build();
      await store.applyReview(
        item.id,
        scheduler.record(item.scheduling, Rating.good, now),
      );

      expect(
        () => store.deleteNode(a.id),
        throwsA(isA<NodeNotEmptyException>()),
      );
      expect(
        () => store.deleteNode(b.id),
        throwsA(isA<NodeNotEmptyException>()),
      );

      await store.deleteNode(a.id, recursive: true);
      expect(await store.allNodes(), isEmpty);
      expect(await store.allItems(), isEmpty);
      expect(await store.history(item.id), isEmpty);
    });
  });

  group('connaissances', () {
    test('création : bourgeon rattaché à son nœud', () async {
      final node = await store.createNode(title: 'Réduction');
      final item = await store.createItem(
        nodeId: node.id,
        kind: ItemKind.definition,
        title: ' Endomorphisme diagonalisable ',
        body: '   ',
      );
      final stored = (await store.item(item.id))!;
      expect(stored.title, 'Endomorphisme diagonalisable');
      expect(stored.body, isNull);
      expect(stored.kind, ItemKind.definition);
      expect(stored.nodeId, node.id);
      expect(stored.scheduling, SchedulingState.initial);
      expect(GrowthStage.of(stored.scheduling), GrowthStage.bud);
      expect(stored.createdAt, now);
    });

    test('difficulté des exercices et ordre dans le nœud', () async {
      final n1 = await store.createNode(title: 'N1');
      final n2 = await store.createNode(title: 'N2');
      final ex = await store.createItem(
        nodeId: n1.id,
        kind: ItemKind.exercise,
        title: 'Ex',
        level: ExerciseLevel.easy,
      );
      final def = await store.createItem(
        nodeId: n1.id,
        kind: ItemKind.definition,
        title: 'Déf',
        level: ExerciseLevel.hard, // ignorée : pas un exercice
      );
      expect((ex.sortIndex, def.sortIndex), (0, 1));
      expect(def.level, isNull);
      await store.updateItem(ex.id, level: () => ExerciseLevel.hard);
      expect((await store.item(ex.id))!.level, ExerciseLevel.hard);
      await store.updateItem(ex.id, kind: ItemKind.statement);
      expect((await store.item(ex.id))!.level, isNull);

      await store.createItem(nodeId: n2.id, kind: ItemKind.lemma, title: 'L');
      await store.updateItem(def.id, nodeId: n2.id);
      expect((await store.item(def.id))!.sortIndex, 1); // après « L »
    });

    test('réorganisation : ordre manuel et changement de nœud', () async {
      final n1 = await store.createNode(title: 'N1');
      final n2 = await store.createNode(title: 'N2');
      Future<List<String>> titles(String nodeId) async => [
        for (final i in await store.watchItems(nodeId: nodeId).first) i.title,
      ];
      final ids = <String, String>{};
      for (final t in ['a', 'b', 'c']) {
        ids[t] = (await store.createItem(
          nodeId: n1.id,
          kind: ItemKind.definition,
          title: t,
        )).id;
      }
      await store.moveItem(ids['c']!, nodeId: n1.id, index: 0);
      expect(await titles(n1.id), ['c', 'a', 'b']);
      await store.moveItem(ids['c']!, nodeId: n1.id, index: 2);
      expect(await titles(n1.id), ['a', 'b', 'c']);
      await store.moveItem(ids['a']!, nodeId: n2.id);
      expect(await titles(n1.id), ['b', 'c']);
      expect(await titles(n2.id), ['a']);
      await store.moveItem(ids['b']!, nodeId: n2.id, index: 0);
      expect(await titles(n2.id), ['b', 'a']);
      expect(
        () => store.moveItem(ids['b']!, nodeId: 'inconnu'),
        throwsArgumentError,
      );
    });

    test('modification du contenu sans toucher à la révision', () async {
      final n1 = await store.createNode(title: 'N1');
      final n2 = await store.createNode(title: 'N2');
      final item = await store.createItem(
        nodeId: n1.id,
        kind: ItemKind.exercise,
        title: 'Exo',
        body: 'Énoncé',
      );
      now = now.add(const Duration(hours: 1));
      await store.updateItem(
        item.id,
        title: 'Exercice 3',
        body: () => null,
        kind: ItemKind.lemma,
        nodeId: n2.id,
        suspended: true,
      );
      final stored = (await store.item(item.id))!;
      expect(stored.title, 'Exercice 3');
      expect(stored.body, isNull);
      expect(stored.kind, ItemKind.lemma);
      expect(stored.nodeId, n2.id);
      expect(stored.suspended, isTrue);
      expect(stored.updatedAt, now);
      expect(stored.createdAt, item.createdAt);
    });

    test('watchItems suit les changements d\'un nœud', () async {
      final node = await store.createNode(title: 'N');
      final stream = store.watchItems(nodeId: node.id);
      final counts = <int>[];
      final sub = stream.listen((items) => counts.add(items.length));
      await pumpEventQueue();
      await store.createItem(
        nodeId: node.id,
        kind: ItemKind.theorem,
        title: 'T',
      );
      await pumpEventQueue();
      await sub.cancel();
      expect(counts, [0, 1]);
    });
  });

  group('révisions', () {
    test('historique et état mis à jour ensemble', () async {
      final node = await store.createNode(title: 'N');
      var item = await store.createItem(
        nodeId: node.id,
        kind: ItemKind.theorem,
        title: 'Théorème spectral',
      );
      final scheduler = const SchedulerSettings().build();

      for (final rating in [Rating.again, Rating.good, Rating.good]) {
        final at = item.scheduling.due ?? now;
        final record = scheduler.record(
          item.scheduling,
          rating,
          at,
          fuzzKey: item.id,
          duration: const Duration(seconds: 90),
        );
        await store.applyReview(item.id, record);
        item = (await store.item(item.id))!;
        expect(item.scheduling, record.after);
      }

      final history = await store.history(item.id);
      expect(history.map((r) => r.rating), [
        Rating.again,
        Rating.good,
        Rating.good,
      ]);
      expect(history.first.before, SchedulingState.initial);
      expect(history.last.after, item.scheduling);
      expect(history.first.duration, const Duration(seconds: 90));
      expect(history.first.schedulerId, scheduler.id);
      expect(item.scheduling.phase, LearningPhase.review);

      // L'historique suffit à reconstruire l'état.
      expect(
        scheduler.replay([
          for (final r in history) (rating: r.rating, at: r.reviewedAt),
        ], fuzzKey: item.id),
        item.scheduling,
      );
    });

    test('refuse une révision calculée sur un état périmé', () async {
      final node = await store.createNode(title: 'N');
      final item = await store.createItem(
        nodeId: node.id,
        kind: ItemKind.definition,
        title: 'D',
      );
      final scheduler = const SchedulerSettings().build();
      final first = scheduler.record(item.scheduling, Rating.good, now);
      await store.applyReview(item.id, first);
      expect(
        () => store.applyReview(item.id, first),
        throwsA(isA<StaleReviewException>()),
      );
      expect(await store.history(item.id), hasLength(1));
    });
  });

  group('réglages', () {
    test('valeurs par défaut puis sauvegarde', () async {
      expect(
        (await store.schedulerSettings()).toJson(),
        const SchedulerSettings().toJson(),
      );
      const custom = SchedulerSettings(desiredRetention: 0.85);
      await store.saveSchedulerSettings(custom);
      await store.saveSchedulerSettings(custom);
      expect((await store.schedulerSettings()).desiredRetention, 0.85);
    });

    test('périmètre des révisions', () async {
      expect(await store.watchReviewScope().first, isEmpty);
      await store.setReviewScope({'a', 'b'});
      expect(await store.watchReviewScope().first, {'a', 'b'});
      await store.setReviewScope({});
      expect(await store.watchReviewScope().first, isEmpty);
    });

    test('dernière branche utilisée, oubliée si elle est supprimée', () async {
      expect(await store.lastNode(), isNull);
      final tree = await store.createNode(title: 'Algèbre');
      final branch = await store.createNode(
        title: 'Groupes',
        parentId: tree.id,
      );
      await store.setLastNode(tree.id);
      await store.setLastNode(branch.id);
      expect((await store.lastNode())?.title, 'Groupes');
      await store.deleteNode(branch.id);
      expect(await store.lastNode(), isNull);
    });
  });

  test('les données survivent à la fermeture de la base (fichier)', () async {
    final dir = await Directory.systemTemp.createTemp('verger_test');
    final file = File('${dir.path}/verger.sqlite');
    try {
      var fileStore = VergerStore(VergerDatabase(NativeDatabase(file)));
      final node = await fileStore.createNode(title: 'Algèbre');
      final item = await fileStore.createItem(
        nodeId: node.id,
        kind: ItemKind.theorem,
        title: 'Cayley-Hamilton',
      );
      final scheduler = const SchedulerSettings().build();
      final record = scheduler.record(
        item.scheduling,
        Rating.easy,
        DateTime.utc(2026, 3, 2, 9, 30, 15, 123),
      );
      await fileStore.applyReview(item.id, record);
      await fileStore.close();

      fileStore = VergerStore(VergerDatabase(NativeDatabase(file)));
      final reopened = (await fileStore.item(item.id))!;
      expect(reopened.title, 'Cayley-Hamilton');
      expect(reopened.scheduling, record.after);
      expect(reopened.scheduling.lastReview!.millisecond, 123);
      expect((await fileStore.allNodes()).single.title, 'Algèbre');
      expect(await fileStore.history(item.id), hasLength(1));
      await fileStore.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
