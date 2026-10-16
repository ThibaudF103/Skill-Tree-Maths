import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

VergerStore newStore() => VergerStore(VergerDatabase(NativeDatabase.memory()));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late VergerStore store;
  late KnowledgeNode tree, suites, series;
  late KnowledgeItem def, thm, cor, other;

  setUp(() async {
    store = newStore();
    tree = await store.createNode(title: 'Analyse');
    suites = await store.createNode(title: 'Suites', parentId: tree.id);
    series = await store.createNode(title: 'Séries', parentId: tree.id);
    Future<KnowledgeItem> item(KnowledgeNode n, ItemKind kind, String t) =>
        store.createItem(nodeId: n.id, kind: kind, title: t);
    def = await item(suites, ItemKind.definition, 'Suite de Cauchy');
    thm = await item(suites, ItemKind.theorem, 'Complétude de R');
    cor = await item(series, ItemKind.corollary, 'Convergence absolue');
    other = await item(series, ItemKind.exercise, 'Série harmonique');
    await store.addPrerequisite(thm.id, def.id);
    await store.addPrerequisite(cor.id, thm.id); // d'une branche à l'autre
  });
  tearDown(() => store.close());

  test('ajout, doublon sans effet, retrait', () async {
    await store.addPrerequisite(thm.id, def.id);
    expect(await store.prerequisites(), hasLength(2));
    await store.removePrerequisite(cor.id, thm.id);
    expect(await store.prerequisites(), [(itemId: thm.id, requiresId: def.id)]);
  });

  test('un cycle est refusé, même indirect', () async {
    expect(
      () => store.addPrerequisite(def.id, cor.id),
      throwsA(isA<StateError>()),
    );
    expect(
      () => store.addPrerequisite(def.id, def.id),
      throwsA(isA<StateError>()),
    );
    expect(await store.prerequisites(), hasLength(2));
  });

  test('supprimer une connaissance retire ses liens', () async {
    await store.deleteItem(thm.id);
    expect(await store.prerequisites(), isEmpty);
    expect(await store.item(def.id), isNotNull);
  });

  test('sauvegarde puis restauration : liens conservés', () async {
    final archive = await store.exportArchive();
    expect(archive.prerequisites, hasLength(2));
    final target = newStore();
    addTearDown(target.close);
    await target.restoreArchive(archive);
    expect(
      (await target.prerequisites()).toSet(),
      (await store.prerequisites()).toSet(),
    );
  });

  test(
    'modèle importé : liens recréés entre les nouvelles connaissances',
    () async {
      final target = newStore();
      addTearDown(target.close);
      await target.importTemplate(await store.exportArchive());
      final byTitle = {for (final i in await target.allItems()) i.title: i.id};
      expect((await target.prerequisites()).toSet(), {
        (
          itemId: byTitle['Complétude de R']!,
          requiresId: byTitle['Suite de Cauchy']!,
        ),
        (
          itemId: byTitle['Convergence absolue']!,
          requiresId: byTitle['Complétude de R']!,
        ),
      });
    },
  );

  test("paquet d'une branche : seuls les liens internes voyagent", () async {
    await store.addPrerequisite(other.id, cor.id);
    final pack = await store.exportTree(series.id);
    expect(pack.prerequisites, [(itemId: other.id, requiresId: cor.id)]);
    final target = newStore();
    addTearDown(target.close);
    await target.importPack(pack);
    expect(await target.prerequisites(), hasLength(1));
  });
}
