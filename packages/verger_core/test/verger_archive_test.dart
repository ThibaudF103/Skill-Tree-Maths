import 'dart:convert';

import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';

void main() {
  final t = DateTime.utc(2026, 3, 2, 9);
  final scheduler = const SchedulerSettings().build();

  VergerArchive sample() {
    final tree = KnowledgeNode(
      id: 'n1',
      title: 'Algèbre',
      sortIndex: 0,
      createdAt: t,
    );
    final branch = KnowledgeNode(
      id: 'n2',
      parentId: 'n1',
      title: 'Réduction',
      sortIndex: 0,
      createdAt: t,
      curriculumKey: 'alg.reduction',
      origin: NodeOrigin.official,
    );
    final record = scheduler.record(SchedulingState.initial, Rating.good, t);
    final item = KnowledgeItem(
      id: 'i1',
      nodeId: 'n2',
      kind: ItemKind.theorem,
      title: 'Cayley-Hamilton',
      body: 'χ_u(u) = 0',
      createdAt: t,
      updatedAt: t,
      scheduling: record.after,
    );
    return VergerArchive(
      nodes: [tree, branch],
      items: [item],
      reviews: [(itemId: 'i1', record: record)],
      settings: const SchedulerSettings(desiredRetention: 0.88),
      title: 'Test',
    );
  }

  test('aller-retour JSON sans perte', () {
    final original = sample();
    final text = jsonEncode(original.toJson());
    final copy = VergerArchive.fromJson(
      (jsonDecode(text) as Map).cast<String, Object?>(),
    );
    expect(copy.title, 'Test');
    expect(copy.nodes.map((n) => n.id), ['n1', 'n2']);
    expect(copy.nodes[1].curriculumKey, 'alg.reduction');
    expect(copy.nodes[1].origin, NodeOrigin.official);
    expect(copy.items.single.body, 'χ_u(u) = 0');
    expect(copy.items.single.scheduling, original.items.single.scheduling);
    expect(
      copy.reviews.single.record.after,
      original.reviews.single.record.after,
    );
    expect(copy.reviews.single.record.rating, Rating.good);
    expect(copy.settings!.desiredRetention, 0.88);
  });

  test('un modèle minimal (sans état ni dates) est accepté', () {
    final archive = VergerArchive.fromJson({
      'format': 'verger',
      'version': 1,
      'nodes': [
        {'id': 'a', 'title': 'Analyse'},
        {'id': 'b', 'parentId': 'a', 'title': 'Séries'},
      ],
      'items': [
        {
          'id': 'x',
          'nodeId': 'b',
          'kind': 'definition',
          'title': 'Série convergente',
        },
      ],
    });
    expect(archive.items.single.scheduling, SchedulingState.initial);
    expect(archive.reviews, isEmpty);
  });

  test('refuse un fichier étranger, trop récent ou incohérent', () {
    expect(
      () => VergerArchive.fromJson({'format': 'autre'}),
      throwsA(isA<ArchiveFormatException>()),
    );
    expect(
      () => VergerArchive.fromJson({'format': 'verger', 'version': 99}),
      throwsA(isA<ArchiveFormatException>()),
    );
    expect(
      () => VergerArchive.fromJson({
        'format': 'verger',
        'version': 1,
        'nodes': [
          {'id': 'a', 'parentId': 'b', 'title': 'A'},
          {'id': 'b', 'parentId': 'a', 'title': 'B'},
        ],
      }),
      throwsA(isA<ArchiveFormatException>()),
    );
    expect(
      () => VergerArchive.fromJson({
        'format': 'verger',
        'version': 1,
        'nodes': [],
        'items': [
          {'id': 'x', 'nodeId': 'absent', 'kind': 'definition', 'title': 'X'},
        ],
      }),
      throwsA(isA<ArchiveFormatException>()),
    );
    expect(
      () => VergerArchive.fromJson({
        'format': 'verger',
        'version': 1,
        'nodes': [
          {'id': 'a', 'title': 'A'},
        ],
        'items': [
          {'id': 'x', 'nodeId': 'a', 'kind': 'inconnu', 'title': 'X'},
        ],
      }),
      throwsA(isA<ArchiveFormatException>()),
    );
  });
}
