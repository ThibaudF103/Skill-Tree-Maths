import 'dart:convert';
import 'dart:typed_data';

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
      kind: ItemKind.exercise,
      title: 'Cayley-Hamilton',
      body: 'χ_u(u) = 0',
      level: ExerciseLevel.medium,
      sortIndex: 2,
      createdAt: t,
      updatedAt: t,
      scheduling: record.after,
    );
    final doc = SourceDocument(
      id: 'd1',
      title: 'Carnet',
      pageCount: 2,
      contentHash: 'abc',
      importedAt: t,
      version: 3,
      fingerprints: [
        Uint8List.fromList([1, 2]),
        Uint8List.fromList([3, 4]),
      ],
      newPages: const [2],
    );
    final anchor = Anchor(
      id: 'a1',
      itemId: 'i1',
      documentId: 'd1',
      role: AnchorRole.work,
      page: 2,
      region: const NormalizedRect(0.1, 0.2, 0.5, 0.6),
      snapshot: Uint8List.fromList([137, 80, 78, 71]),
      createdAt: t,
    );
    return VergerArchive(
      nodes: [tree, branch],
      items: [item],
      documents: [doc],
      anchors: [anchor],
      notes: [
        Note(
          id: 'note1',
          body: r'Preuve : on pose $P = \chi_u$.',
          documentId: 'd1',
          page: 2,
          region: const NormalizedRect(0, 0.1, 1, 0.4),
          snapshot: Uint8List.fromList([1, 2, 3]),
          itemId: 'i1',
          createdAt: t,
          updatedAt: t.add(const Duration(hours: 1)),
        ),
      ],
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
    expect(copy.items.single.level, ExerciseLevel.medium);
    expect(copy.items.single.sortIndex, 2);
    expect(copy.items.single.scheduling, original.items.single.scheduling);
    expect(
      copy.reviews.single.record.after,
      original.reviews.single.record.after,
    );
    expect(copy.reviews.single.record.rating, Rating.good);
    expect(copy.settings!.desiredRetention, 0.88);
    final doc = copy.documents.single;
    expect(
      (doc.title, doc.kind, doc.pageCount, doc.version),
      ('Carnet', ResourceKind.pdf, 2, 3),
    );
    expect(doc.newPages, [2]);
    expect(doc.fingerprints.last, [3, 4]);
    final anchor = copy.anchors.single;
    expect(anchor.region, const NormalizedRect(0.1, 0.2, 0.5, 0.6));
    expect(anchor.snapshot, [137, 80, 78, 71]);
    expect(anchor.role, AnchorRole.work);
    final note = copy.notes.single;
    expect(note.body, r'Preuve : on pose $P = \chi_u$.');
    expect(note.headline, r'Preuve : on pose P = \chi_u.');
    expect((note.documentId, note.page, note.itemId), ('d1', 2, 'i1'));
    expect(note.region, const NormalizedRect(0, 0.1, 1, 0.4));
    expect(note.snapshot, [1, 2, 3]);
    expect(note.updatedAt, t.add(const Duration(hours: 1)));
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

  test('titre lisible d\'une note', () {
    Note note(String body) =>
        Note(id: 'n', body: body, createdAt: t, updatedAt: t);
    expect(
      note('\n\n# Théorème spectral\nPreuve…').headline,
      'Théorème spectral',
    );
    expect(note(r'- Soit $x_n \to 0$').headline, r'Soit x_n \to 0');
    expect(note('   ').headline, '');
  });

  test('refuse des réglages hors bornes et des identifiants en double', () {
    final base = sample().toJson();
    final badSettings = {
      ...base,
      'settings': {
        ...(base['settings']! as Map<String, Object?>),
        'desiredRetention': 1,
      },
    };
    expect(
      () => VergerArchive.fromJson(badSettings),
      throwsA(isA<ArchiveFormatException>()),
    );
    final notes = base['notes']! as List;
    final duplicated = {
      ...base,
      'notes': [notes.first, notes.first],
    };
    expect(
      () => VergerArchive.fromJson(duplicated),
      throwsA(isA<ArchiveFormatException>()),
    );
    expect(const SchedulerSettings(desiredRetention: 0.9).isValid, isTrue);
    expect(const SchedulerSettings(desiredRetention: 90).isValid, isFalse);
    expect(
      const SchedulerSettings(learningSteps: [Duration.zero]).isValid,
      isFalse,
    );
  });

  test('contenus : vidéo, extrait, rattachement aux nœuds, ancien format', () {
    final t = DateTime.utc(2026, 3, 2);
    final archive = VergerArchive(
      nodes: [
        KnowledgeNode(id: 'n1', title: 'Analyse', sortIndex: 0, createdAt: t),
      ],
      items: [
        KnowledgeItem(
          id: 'i1',
          nodeId: 'n1',
          kind: ItemKind.theorem,
          title: 'Rolle',
          createdAt: t,
          updatedAt: t,
        ),
      ],
      documents: [
        SourceDocument(
          id: 'v1',
          title: 'Cours filmé',
          kind: ResourceKind.video,
          url: 'https://www.youtube.com/watch?v=abc',
          pageCount: 0,
          contentHash: 'abc',
          importedAt: t,
        ),
      ],
      anchors: [
        Anchor(
          id: 'a1',
          itemId: 'i1',
          documentId: 'v1',
          role: AnchorRole.work,
          startMs: 750000,
          endMs: 845000,
          createdAt: t,
        ),
      ],
      resourceLinks: const [(documentId: 'v1', nodeId: 'n1')],
    );
    final copy = VergerArchive.fromJson(
      (jsonDecode(jsonEncode(archive.toJson())) as Map).cast(),
    );
    final video = copy.documents.single;
    expect(
      (video.isVideo, video.url),
      (true, 'https://www.youtube.com/watch?v=abc'),
    );
    final a = copy.anchors.single;
    expect((a.page, a.startMs, a.endMs), (null, 750000, 845000));
    expect(copy.resourceLinks.single, (documentId: 'v1', nodeId: 'n1'));

    // Archive d'avant les contenus : « role » au lieu de « kind ».
    final json = archive.toJson();
    (json['documents'] as List).first
      ..remove('kind')
      ..['role'] = 'notes';
    json.remove('resourceLinks');
    final legacy = VergerArchive.fromJson(
      (jsonDecode(jsonEncode(json)) as Map).cast(),
    );
    expect(legacy.documents.single.kind, ResourceKind.pdf);
    expect(legacy.resourceLinks, isEmpty);

    // Rattachement vers un nœud inconnu refusé.
    expect(
      () => VergerArchive(
        nodes: archive.nodes,
        items: archive.items,
        documents: archive.documents,
        resourceLinks: const [(documentId: 'v1', nodeId: 'x')],
      ).validate(),
      throwsA(isA<ArchiveFormatException>()),
    );
  });
}
