import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

const _n = fingerprintSide * fingerprintSide;

/// Empreinte d'une page distincte des autres.
Uint8List page(int seed) {
  final random = Random(seed);
  final pixels = Uint8List(_n)..fillRange(0, _n, 250);
  for (var s = 0; s < 60; s++) {
    pixels[random.nextInt(_n)] = 70;
  }
  return pixels;
}

VergerStore newStore() => VergerStore(VergerDatabase(NativeDatabase.memory()));

final _scheduler = const SchedulerSettings().build();

Future<void> review(VergerStore store, String itemId, DateTime at) async {
  final item = (await store.item(itemId))!;
  await store.applyReview(
    itemId,
    _scheduler.record(item.scheduling, Rating.good, at),
  );
}

Future<KnowledgeNode> nodeNamed(VergerStore store, String title) async =>
    (await store.allNodes()).singleWhere((n) => n.title == title);

Future<KnowledgeItem> itemNamed(VergerStore store, String title) async =>
    (await store.allItems()).singleWhere((i) => i.title == title);

/// Réimport d'un paquet `.verger` dont l'arbre est déjà sur l'appareil :
/// remplacer ou combiner.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // L'auteur publie « Analyse » (v1), l'élève l'importe et travaille dessus,
  // puis l'auteur publie une v2 : « Séries » supprimée, Cesàro déplacé dans
  // une nouvelle branche et renommé, une connaissance ajoutée.
  late VergerStore author;
  late VergerStore student;
  late VergerArchive v1;
  late VergerArchive v2;

  setUp(() async {
    author = newStore();
    student = newStore();
    final tree = await author.createNode(title: 'Analyse');
    final suites = await author.createNode(title: 'Suites', parentId: tree.id);
    final series = await author.createNode(title: 'Séries', parentId: tree.id);
    final cesaro = await author.createItem(
      nodeId: suites.id,
      kind: ItemKind.theorem,
      title: 'Cesàro',
    );
    await author.createItem(
      nodeId: series.id,
      kind: ItemKind.theorem,
      title: 'Critère de d\'Alembert',
    );
    final poly = await author.importDocument(
      title: 'Poly',
      bytes: Uint8List.fromList([1, 2, 3]),
      contentHash: 'poly',
      fingerprints: [Uint8List(4), Uint8List(4)],
      nodeIds: [tree.id],
    );
    await author.addAnchor(
      itemId: cesaro.id,
      documentId: poly.id,
      role: AnchorRole.source,
      page: 2,
    );
    await author.createNote(body: 'Preuve', itemId: cesaro.id);
    v1 = await author.exportTree(tree.id);

    await author.deleteNode(series.id, recursive: true);
    final reelles = await author.createNode(
      title: 'Suites réelles',
      parentId: suites.id,
    );
    await author.updateItem(
      cesaro.id,
      title: 'Théorème de Cesàro',
      nodeId: reelles.id,
    );
    await author.createItem(
      nodeId: reelles.id,
      kind: ItemKind.definition,
      title: 'Suite de Cauchy',
    );
    v2 = await author.exportTree(tree.id);

    await student.importPack(v1);
    final studentTree = await nodeNamed(student, 'Analyse');
    final studentCesaro = await itemNamed(student, 'Cesàro');
    await review(student, studentCesaro.id, DateTime.utc(2026, 3, 1));
    await student.createNote(body: 'Ma remarque', itemId: studentCesaro.id);
    final cahier = await student.importDocument(
      title: 'Cahier',
      bytes: Uint8List.fromList([7]),
      contentHash: 'cahier',
      fingerprints: [Uint8List(4)],
    );
    await student.addAnchor(
      itemId: studentCesaro.id,
      documentId: cahier.id,
      role: AnchorRole.work,
      page: 1,
    );
    final mine = await student.createNode(
      title: 'Mes ajouts',
      parentId: studentTree.id,
    );
    await student.linkResource(cahier.id, mine.id);
    final lemma = await student.createItem(
      nodeId: mine.id,
      kind: ItemKind.proposition,
      title: 'Lemme perso',
    );
    await student.createNote(body: 'Idée', itemId: lemma.id);
    await review(student, lemma.id, DateTime.utc(2026, 3, 2));
  });

  tearDown(() async {
    await author.close();
    await student.close();
  });

  test('paquet inconnu : rien à remplacer, arbre ajouté', () async {
    final fresh = newStore();
    addTearDown(fresh.close);
    final preview = await fresh.previewPack(v1);
    expect(preview.updatesExisting, isFalse);
    expect(preview.wouldLose, isFalse);
    final trees = await fresh.importPack(v1);
    // Identifiants conservés : un réimport retrouvera l'arbre.
    expect(trees.single.id, v1.nodes.firstWhere((n) => n.isTree).id);
  });

  test('réimport sans perte : mis à jour sans question ni doublon', () async {
    final fresh = newStore();
    addTearDown(fresh.close);
    await fresh.importPack(v1);
    final cesaro = await itemNamed(fresh, 'Cesàro');
    await review(fresh, cesaro.id, DateTime.utc(2026, 3, 1));

    final preview = await fresh.previewPack(v2);
    expect(preview.existing.single.title, 'Analyse');
    // Seule « Séries » disparaît côté local.
    expect(
      (preview.branches, preview.items, preview.notes, preview.anchors),
      (1, 1, 0, 0),
    );
    final again = await fresh.previewPack(v1);
    expect(again.updatesExisting, isTrue);
    expect(again.wouldLose, isFalse);
    await fresh.importPack(v1);
    expect(await fresh.allNodes(), hasLength(3));
    expect(await fresh.allItems(), hasLength(2));
    expect((await fresh.item(cesaro.id))!.scheduling.reps, 1);
  });

  test('aperçu : ce que « Remplacer » supprimerait', () async {
    final preview = await student.previewPack(v2);
    expect(preview.existing.single.title, 'Analyse');
    expect(preview.branches, 2); // Séries, Mes ajouts
    expect(preview.items, 2); // d'Alembert, Lemme perso
    expect(preview.notes, 2); // Ma remarque, Idée
    expect(preview.anchors, 1); // verso dans le cahier
    expect(preview.reviews, 1); // révision du lemme
    expect(preview.wouldLose, isTrue);
  });

  test('remplacer : l\'arbre local devient celui du paquet', () async {
    final cesaroId = (await itemNamed(student, 'Cesàro')).id;
    final trees = await student.importPack(v2);

    expect(trees.single.title, 'Analyse');
    expect((await student.allNodes()).map((n) => n.title).toSet(), {
      'Analyse',
      'Suites',
      'Suites réelles',
    });
    expect((await student.allItems()).map((i) => i.title).toSet(), {
      'Théorème de Cesàro',
      'Suite de Cauchy',
    });
    // Connaissance déplacée et renommée : progression et historique gardés.
    final cesaro = (await student.item(cesaroId))!;
    expect(cesaro.title, 'Théorème de Cesàro');
    expect(cesaro.nodeId, (await nodeNamed(student, 'Suites réelles')).id);
    expect(cesaro.scheduling.reps, 1);
    expect(await student.history(cesaroId), hasLength(1));
    expect((await student.notes(itemId: cesaroId)).map((n) => n.body), [
      'Preuve',
    ]);
    expect((await student.anchorsOf(cesaroId)).single.role, AnchorRole.source);
    // Notes du lemme supprimé : parties avec lui.
    expect((await student.notes()).map((n) => n.body).toSet(), {'Preuve'});
    // Les contenus restent dans la bibliothèque, sans doublon ; les
    // rattachements de l'arbre sont ceux du paquet.
    final docs = await student.allDocuments();
    expect(docs.map((d) => d.title).toSet(), {'Poly', 'Cahier'});
    final poly = docs.firstWhere((d) => d.title == 'Poly');
    expect(await student.resourceLinks(), [
      (documentId: poly.id, nodeId: trees.single.id),
    ]);
  });

  test('combiner : le paquet met à jour, rien de local ne se perd', () async {
    final cesaroId = (await itemNamed(student, 'Cesàro')).id;
    final lemmaId = (await itemNamed(student, 'Lemme perso')).id;
    final trees = await student.importPack(v2, mode: PackImportMode.combine);

    expect(trees.single.title, 'Analyse');
    expect((await student.allNodes()).where((n) => n.isTree), hasLength(1));
    final mine = await nodeNamed(student, 'Mes ajouts');
    expect(mine.parentId, trees.single.id);
    expect(await nodeNamed(student, 'Séries'), isNotNull);
    expect((await student.allItems()).map((i) => i.title).toSet(), {
      'Théorème de Cesàro',
      'Suite de Cauchy',
      'Critère de d\'Alembert',
      'Lemme perso',
    });
    // Connaissance déplacée par le paquet, progression conservée.
    final cesaro = (await student.item(cesaroId))!;
    expect(cesaro.nodeId, (await nodeNamed(student, 'Suites réelles')).id);
    expect(cesaro.scheduling.reps, 1);
    expect(await student.history(cesaroId), hasLength(1));
    expect((await student.notes(itemId: cesaroId)).map((n) => n.body).toSet(), {
      'Preuve',
      'Ma remarque',
    });
    expect(await student.anchorsOf(cesaroId), hasLength(2));
    // Ajouts locaux intacts, historique compris.
    final lemma = (await student.item(lemmaId))!;
    expect(lemma.nodeId, mine.id);
    expect(lemma.scheduling.reps, 1);
    expect(await student.history(lemmaId), hasLength(1));
    expect((await student.notes(itemId: lemmaId)).single.body, 'Idée');
    final cahier = (await student.allDocuments()).firstWhere(
      (d) => d.title == 'Cahier',
    );
    expect(
      await student.resourceLinks(),
      contains((documentId: cahier.id, nodeId: mine.id)),
    );
    expect(await student.allDocuments(), hasLength(2));
    // Positions renumérotées : pas d'ex æquo parmi les branches.
    final branches = (await student.allNodes())
        .where((n) => n.parentId == trees.single.id)
        .map((n) => n.sortIndex)
        .toList();
    expect(branches.toSet(), hasLength(branches.length));
  });

  test('une branche partagée puis réimportée reste dans son arbre', () async {
    final suites = await nodeNamed(author, 'Suites');
    final pack = await author.exportTree(suites.id);
    await author.importPack(pack);
    final after = await nodeNamed(author, 'Suites');
    expect(after.parentId, suites.parentId);
    expect(after.sortIndex, suites.sortIndex);
    expect((await author.allNodes()).where((n) => n.isTree), hasLength(1));
    expect(await author.allItems(), hasLength(2));
  });

  test('identifiant déjà pris dans un autre arbre : renouvelé', () async {
    final cesaro = await itemNamed(student, 'Cesàro');
    final now = DateTime.utc(2026, 4, 1);
    final archive = VergerArchive(
      nodes: [
        KnowledgeNode(
          id: 'autre',
          title: 'Autre',
          sortIndex: 0,
          createdAt: now,
        ),
      ],
      items: [
        KnowledgeItem(
          id: cesaro.id,
          nodeId: 'autre',
          kind: ItemKind.theorem,
          title: 'Homonyme',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    expect((await student.previewPack(archive)).updatesExisting, isFalse);
    await student.importPack(archive);
    expect((await student.item(cesaro.id))!.title, 'Cesàro');
    final copy = await itemNamed(student, 'Homonyme');
    expect(copy.id, isNot(cesaro.id));
    expect(copy.nodeId, 'autre');
  });

  test('parent disparu : rattaché au plus proche ancêtre conservé', () async {
    final store = newStore();
    addTearDown(store.close);
    final root = await store.createNode(title: 'Racine');
    final middle = await store.createNode(title: 'Milieu', parentId: root.id);
    final leaf = await store.createNode(title: 'Feuille', parentId: middle.id);
    await store.createItem(
      nodeId: leaf.id,
      kind: ItemKind.definition,
      title: 'Def',
    );
    // Paquet à deux racines, sans le nœud intermédiaire.
    final archive = VergerArchive(
      nodes: [
        KnowledgeNode(
          id: root.id,
          title: 'Racine',
          sortIndex: 0,
          createdAt: root.createdAt,
        ),
        KnowledgeNode(
          id: leaf.id,
          title: 'Feuille',
          sortIndex: 1,
          createdAt: leaf.createdAt,
        ),
      ],
      items: [for (final i in await store.allItems()) i],
    );
    final preview = await store.previewPack(archive);
    expect(preview.branches, 1);

    final copy = newStore();
    addTearDown(copy.close);
    await copy.restoreArchive(await store.exportArchive());
    await copy.importPack(archive, mode: PackImportMode.combine);
    expect((await copy.node(leaf.id))!.parentId, middle.id);

    await store.importPack(archive);
    expect(await store.node(middle.id), isNull);
    expect((await store.node(leaf.id))!.parentId, root.id);
    expect(await store.allItems(), hasLength(1));
  });

  test(
    'prérequis : ceux du paquet, sans cycle avec les liens locaux',
    () async {
      final a = await author.createItem(
        nodeId: (await nodeNamed(author, 'Suites')).id,
        kind: ItemKind.definition,
        title: 'A',
      );
      final b = await author.createItem(
        nodeId: (await nodeNamed(author, 'Suites')).id,
        kind: ItemKind.theorem,
        title: 'B',
      );
      await author.addPrerequisite(b.id, a.id);
      final pack = await author.exportTree(
        (await nodeNamed(author, 'Analyse')).id,
      );
      final fresh = newStore();
      addTearDown(fresh.close);
      await fresh.importPack(pack);
      await fresh.removePrerequisite(b.id, a.id);
      await fresh.addPrerequisite(a.id, b.id); // sens inverse, local

      await fresh.importPack(pack, mode: PackImportMode.combine);
      expect(await fresh.prerequisites(), [(itemId: a.id, requiresId: b.id)]);

      await fresh.importPack(pack);
      expect(await fresh.prerequisites(), [(itemId: b.id, requiresId: a.id)]);
    },
  );

  test('lien ou prérequis ajouté localement : la question est posée', () async {
    final fresh = newStore();
    addTearDown(fresh.close);
    await fresh.importPack(v1);
    expect((await fresh.previewPack(v1)).wouldLose, isFalse);

    final series = await nodeNamed(fresh, 'Séries');
    final poly = (await fresh.allDocuments()).single;
    await fresh.linkResource(poly.id, series.id);
    final cesaro = await itemNamed(fresh, 'Cesàro');
    final alembert = await itemNamed(fresh, 'Critère de d\'Alembert');
    await fresh.addPrerequisite(alembert.id, cesaro.id);

    final preview = await fresh.previewPack(v1);
    expect((preview.links, preview.prerequisites), (1, 1));
    expect(preview.wouldLose, isTrue);

    await fresh.importPack(v1, mode: PackImportMode.combine);
    expect(
      await fresh.resourceLinks(),
      contains((documentId: poly.id, nodeId: series.id)),
    );
    expect(await fresh.prerequisites(), hasLength(1));

    await fresh.importPack(v1);
    expect(await fresh.resourceLinks(), hasLength(1));
    expect(await fresh.prerequisites(), isEmpty);
  });

  test(
    'contenu local plus récent (même identifiant) : conservé, pages recalées',
    () async {
      final source = newStore();
      addTearDown(source.close);
      final tree = await source.createNode(title: 'Algèbre');
      final item = await source.createItem(
        nodeId: tree.id,
        kind: ItemKind.theorem,
        title: 'Cayley-Hamilton',
      );
      final pages = [page(1), page(2), page(3)];
      final poly = await source.importDocument(
        title: 'Poly',
        bytes: Uint8List.fromList([1]),
        contentHash: 'v1',
        fingerprints: pages,
        nodeIds: [tree.id],
      );
      await source.addAnchor(
        itemId: item.id,
        documentId: poly.id,
        role: AnchorRole.source,
        page: 2,
      );
      await source.createNote(body: 'Du poly', documentId: poly.id, page: 3);
      final pack = await source.exportTree(tree.id);

      final local = newStore();
      addTearDown(local.close);
      await local.importPack(pack);
      // Nouvelle version locale : une page insérée en tête.
      await local.updateDocument(
        poly.id,
        bytes: Uint8List.fromList([2]),
        contentHash: 'v2',
        fingerprints: [page(99), ...pages],
      );
      final mine = await local.createNote(
        body: 'Ma note',
        documentId: poly.id,
        page: 4,
      );

      for (final mode in PackImportMode.values) {
        await local.importPack(pack, mode: mode);
        final doc = (await local.allDocuments()).single;
        expect((doc.id, doc.contentHash, doc.pageCount), (poly.id, 'v2', 4));
        expect(await local.documentBytes(poly.id), [2]);
        final anchor = (await local.anchorsOf(item.id)).single;
        expect((anchor.documentId, anchor.page), (poly.id, 3));
        expect(anchor.needsReview, isFalse);
        final notes = await local.notes(documentId: poly.id);
        expect(notes.map((n) => (n.body, n.page)).toSet(), {
          ('Du poly', 4),
          ('Ma note', 4),
        });
        expect((await local.note(mine.id))!.documentId, poly.id);
        expect(await local.resourceLinks(), [
          (documentId: poly.id, nodeId: tree.id),
        ]);
      }
    },
  );

  test('note d\'un contenu étranger à l\'arbre : jamais écrasée', () async {
    final other = await student.importDocument(
      title: 'Autre',
      bytes: Uint8List.fromList([5]),
      contentHash: 'autre',
      fingerprints: [Uint8List(4)],
    );
    final note = await student.createNote(
      body: 'Remarque',
      documentId: other.id,
      page: 1,
    );
    final poly = v1.documents.single;
    final now = DateTime.utc(2026, 4, 1);
    final pack = VergerArchive(
      nodes: v1.nodes,
      items: v1.items,
      documents: v1.documents,
      anchors: v1.anchors,
      resourceLinks: v1.resourceLinks,
      notes: [
        ...v1.notes,
        Note(
          id: note.id,
          body: 'Du paquet',
          documentId: poly.id,
          page: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      title: v1.title,
    );
    await student.importPack(pack, mode: PackImportMode.combine);
    final kept = (await student.note(note.id))!;
    expect((kept.body, kept.documentId), ('Remarque', other.id));
    final copy = (await student.notes()).singleWhere(
      (n) => n.body == 'Du paquet',
    );
    expect(copy.id, isNot(note.id));
  });
}
