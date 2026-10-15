import 'dart:convert';
import 'dart:typed_data';

import '../domain/anchor.dart';
import '../domain/item_kind.dart';
import '../domain/knowledge_item.dart';
import '../domain/knowledge_node.dart';
import '../domain/note.dart';
import '../domain/rating.dart';
import '../domain/review_record.dart';
import '../domain/scheduling_state.dart';
import '../domain/source_document.dart';
import '../scheduling/scheduler_settings.dart';

/// Révision archivée, rattachée à sa connaissance.
typedef ArchivedReview = ({String itemId, ReviewRecord record});

/// Le fichier ne peut pas être lu comme une archive du Verger.
class ArchiveFormatException implements Exception {
  const ArchiveFormatException(this.message);
  final String message;
  @override
  String toString() => 'ArchiveFormatException: $message';
}

/// Contenu d'un fichier d'échange JSON.
///
/// Sert à la fois de **sauvegarde complète** (structure, connaissances,
/// historique, réglages) et de **modèle d'arbre** à partager : un modèle n'a
/// ni historique ni état de révision, et ses identifiants sont renouvelés à
/// l'import.
final class VergerArchive {
  const VergerArchive({
    required this.nodes,
    required this.items,
    this.reviews = const [],
    this.documents = const [],
    this.anchors = const [],
    this.notes = const [],
    this.resourceLinks = const [],
    this.settings,
    this.title,
  });

  static const format = 'verger';

  /// 2 : contenus (PDF, vidéos) rattachés aux nœuds, ancres sans page.
  static const currentVersion = 2;

  final List<KnowledgeNode> nodes;
  final List<KnowledgeItem> items;
  final List<ArchivedReview> reviews;

  /// PDF de la bibliothèque (métadonnées et empreintes, sans le contenu).
  final List<SourceDocument> documents;

  /// Ancres recto/verso, avec leurs miniatures.
  final List<Anchor> anchors;

  /// Notes de travail (avec leurs miniatures).
  final List<Note> notes;

  /// Rattachement des contenus aux nœuds.
  final List<ResourceLink> resourceLinks;
  final SchedulerSettings? settings;

  /// Nom lisible (ex. « Algèbre — exemple »).
  final String? title;

  factory VergerArchive.fromJson(Map<String, Object?> json) {
    if (json['format'] != format) {
      throw const ArchiveFormatException(
        'Ce fichier n\'est pas une archive du Verger.',
      );
    }
    final version = json['version'];
    if (version is! int || version > currentVersion) {
      throw ArchiveFormatException(
        'Version d\'archive non prise en charge : $version.',
      );
    }
    try {
      DateTime date(Object? v) => DateTime.parse(v as String).toUtc();
      List<Map<String, Object?>> list(String key) => [
        for (final e in (json[key] as List? ?? const [])) (e as Map).cast(),
      ];

      final nodes = [
        for (final n in list('nodes'))
          KnowledgeNode(
            id: n['id'] as String,
            parentId: n['parentId'] as String?,
            title: n['title'] as String,
            sortIndex: n['sortIndex'] as int? ?? 0,
            curriculumKey: n['curriculumKey'] as String?,
            origin: NodeOrigin.values.byName(n['origin'] as String? ?? 'user'),
            createdAt: n['createdAt'] == null
                ? DateTime.now().toUtc()
                : date(n['createdAt']),
          ),
      ];
      final items = [
        for (final i in list('items'))
          KnowledgeItem(
            id: i['id'] as String,
            nodeId: i['nodeId'] as String,
            kind: ItemKind.values.byName(i['kind'] as String),
            title: i['title'] as String,
            body: i['body'] as String?,
            level: i['level'] == null
                ? null
                : ExerciseLevel.values.byName(i['level'] as String),
            sortIndex: (i['sortIndex'] as num?)?.toInt() ?? 0,
            suspended: i['suspended'] as bool? ?? false,
            createdAt: i['createdAt'] == null
                ? DateTime.now().toUtc()
                : date(i['createdAt']),
            updatedAt: i['updatedAt'] == null
                ? DateTime.now().toUtc()
                : date(i['updatedAt']),
            scheduling: i['scheduling'] == null
                ? SchedulingState.initial
                : SchedulingState.fromJson((i['scheduling'] as Map).cast()),
          ),
      ];
      final reviews = <ArchivedReview>[
        for (final r in list('reviews'))
          (
            itemId: r['itemId'] as String,
            record: ReviewRecord(
              rating: Rating.values.byName(r['rating'] as String),
              reviewedAt: date(r['reviewedAt']),
              before: SchedulingState.fromJson((r['before'] as Map).cast()),
              after: SchedulingState.fromJson((r['after'] as Map).cast()),
              schedulerId: r['schedulerId'] as String,
              duration: r['durationMs'] == null
                  ? null
                  : Duration(milliseconds: r['durationMs'] as int),
            ),
          ),
      ];
      Uint8List? bytes(Object? v) =>
          v == null ? null : base64Decode(v as String);
      final documents = [
        for (final d in list('documents'))
          SourceDocument(
            id: d['id'] as String,
            title: d['title'] as String,
            // Avant les vidéos, seul un « rôle » (cours / notes) existait.
            kind: ResourceKind.values.byName(d['kind'] as String? ?? 'pdf'),
            url: d['url'] as String?,
            pageCount: d['pageCount'] as int? ?? 0,
            contentHash: d['contentHash'] as String? ?? '',
            importedAt: date(d['importedAt']),
            version: d['version'] as int? ?? 1,
            fingerprints: [
              for (final f in (d['fingerprints'] as List? ?? const []))
                bytes(f)!,
            ],
            newPages: List<int>.from(d['newPages'] as List? ?? const []),
            lastPage: d['lastPage'] as int? ?? 1,
          ),
      ];
      final anchors = [
        for (final a in list('anchors'))
          Anchor(
            id: a['id'] as String,
            itemId: a['itemId'] as String,
            documentId: a['documentId'] as String,
            role: AnchorRole.values.byName(a['role'] as String),
            page: a['page'] as int?,
            startMs: a['startMs'] as int?,
            endMs: a['endMs'] as int?,
            region: a['region'] == null
                ? null
                : NormalizedRect(
                    ((a['region'] as List)[0] as num).toDouble(),
                    ((a['region'] as List)[1] as num).toDouble(),
                    ((a['region'] as List)[2] as num).toDouble(),
                    ((a['region'] as List)[3] as num).toDouble(),
                  ),
            textSnippet: a['textSnippet'] as String?,
            snapshot: bytes(a['snapshot']),
            needsReview: a['needsReview'] as bool? ?? false,
            createdAt: date(a['createdAt']),
          ),
      ];
      NormalizedRect? region(Object? v) {
        if (v == null) return null;
        final r = [for (final x in v as List) (x as num).toDouble()];
        return NormalizedRect(r[0], r[1], r[2], r[3]);
      }

      final notes = [
        for (final n in list('notes'))
          Note(
            id: n['id'] as String,
            body: n['body'] as String? ?? '',
            documentId: n['documentId'] as String?,
            page: n['page'] as int?,
            startMs: n['startMs'] as int?,
            endMs: n['endMs'] as int?,
            region: region(n['region']),
            snapshot: bytes(n['snapshot']),
            itemId: n['itemId'] as String?,
            createdAt: date(n['createdAt']),
            updatedAt: n['updatedAt'] == null
                ? date(n['createdAt'])
                : date(n['updatedAt']),
          ),
      ];
      final settings = json['settings'] == null
          ? null
          : SchedulerSettings.fromJson((json['settings'] as Map).cast());
      final archive = VergerArchive(
        nodes: nodes,
        items: items,
        reviews: reviews,
        documents: documents,
        anchors: anchors,
        notes: notes,
        resourceLinks: version < 2
            ? _linksFromAnchors(nodes, items, anchors)
            : [
                for (final l in list('resourceLinks'))
                  (
                    documentId: l['documentId'] as String,
                    nodeId: l['nodeId'] as String,
                  ),
              ],
        settings: settings,
        title: json['title'] as String?,
      );
      archive.validate();
      return archive;
    } on ArchiveFormatException {
      rethrow;
    } catch (e) {
      throw ArchiveFormatException('Contenu invalide : $e');
    }
  }

  /// Archives antérieures aux rattachements : chaque PDF est rattaché à la
  /// racine des arbres où il sert, comme lors de la migration de la base.
  static List<ResourceLink> _linksFromAnchors(
    List<KnowledgeNode> nodes,
    List<KnowledgeItem> items,
    List<Anchor> anchors,
  ) {
    final parent = {for (final n in nodes) n.id: n.parentId};
    final nodeOf = {for (final i in items) i.id: i.nodeId};
    String rootOf(String id) {
      var current = id;
      for (var i = 0; parent[current] != null && i < nodes.length; i++) {
        current = parent[current]!;
      }
      return current;
    }

    final links = <ResourceLink>{};
    for (final a in anchors) {
      final node = nodeOf[a.itemId];
      if (node != null && parent.containsKey(node)) {
        links.add((documentId: a.documentId, nodeId: rootOf(node)));
      }
    }
    return links.toList();
  }

  /// Vérifie la cohérence des références (parents, nœuds, connaissances).
  void validate() {
    final nodeIds = <String>{};
    for (final n in nodes) {
      if (!nodeIds.add(n.id)) {
        throw ArchiveFormatException('Nœud en double : ${n.id}');
      }
    }
    for (final n in nodes) {
      if (n.parentId != null && !nodeIds.contains(n.parentId)) {
        throw ArchiveFormatException('Parent inconnu pour « ${n.title} »');
      }
    }
    final parentOf = {for (final n in nodes) n.id: n.parentId};
    for (final n in nodes) {
      final seen = <String>{};
      for (String? c = n.id; c != null; c = parentOf[c]) {
        if (!seen.add(c)) {
          throw ArchiveFormatException(
            'Cycle dans la hiérarchie (« ${n.title} »)',
          );
        }
      }
    }
    final itemIds = <String>{};
    for (final i in items) {
      if (!itemIds.add(i.id)) {
        throw ArchiveFormatException('Connaissance en double : ${i.id}');
      }
      if (!nodeIds.contains(i.nodeId)) {
        throw ArchiveFormatException('Nœud inconnu pour « ${i.title} »');
      }
    }
    void unique(Iterable<String> ids, String what) {
      final seen = <String>{};
      for (final id in ids) {
        if (!seen.add(id)) {
          throw ArchiveFormatException('$what en double : $id');
        }
      }
    }

    unique(documents.map((d) => d.id), 'Document');
    unique(anchors.map((a) => a.id), 'Ancre');
    unique(notes.map((n) => n.id), 'Note');
    final documentIds = {for (final d in documents) d.id};
    for (final a in anchors) {
      if (!itemIds.contains(a.itemId) || !documentIds.contains(a.documentId)) {
        throw const ArchiveFormatException('Ancre vers un élément inconnu');
      }
    }
    for (final n in notes) {
      if ((n.documentId != null && !documentIds.contains(n.documentId)) ||
          (n.itemId != null && !itemIds.contains(n.itemId))) {
        throw const ArchiveFormatException('Note vers un élément inconnu');
      }
    }
    for (final l in resourceLinks) {
      if (!documentIds.contains(l.documentId) || !nodeIds.contains(l.nodeId)) {
        throw const ArchiveFormatException('Contenu rattaché à un inconnu');
      }
    }
    for (final r in reviews) {
      if (!itemIds.contains(r.itemId)) {
        throw const ArchiveFormatException(
          'Révision d\'une connaissance inconnue',
        );
      }
    }
  }

  Map<String, Object?> toJson() => {
    'format': format,
    'version': currentVersion,
    'title': ?title,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'settings': ?settings?.toJson(),
    'nodes': [
      for (final n in nodes)
        {
          'id': n.id,
          'parentId': n.parentId,
          'title': n.title,
          'sortIndex': n.sortIndex,
          'curriculumKey': ?n.curriculumKey,
          'origin': n.origin.name,
          'createdAt': n.createdAt.toUtc().toIso8601String(),
        },
    ],
    'items': [
      for (final i in items)
        {
          'id': i.id,
          'nodeId': i.nodeId,
          'kind': i.kind.name,
          'title': i.title,
          'body': ?i.body,
          'level': ?i.level?.name,
          'sortIndex': i.sortIndex,
          'suspended': i.suspended,
          'createdAt': i.createdAt.toUtc().toIso8601String(),
          'updatedAt': i.updatedAt.toUtc().toIso8601String(),
          'scheduling': i.scheduling.toJson(),
        },
    ],
    'documents': [
      for (final d in documents)
        {
          'id': d.id,
          'title': d.title,
          'kind': d.kind.name,
          'url': ?d.url,
          'pageCount': d.pageCount,
          'contentHash': d.contentHash,
          'importedAt': d.importedAt.toUtc().toIso8601String(),
          'version': d.version,
          'fingerprints': [for (final f in d.fingerprints) base64Encode(f)],
          'newPages': d.newPages,
          'lastPage': d.lastPage,
        },
    ],
    'anchors': [
      for (final a in anchors)
        {
          'id': a.id,
          'itemId': a.itemId,
          'documentId': a.documentId,
          'role': a.role.name,
          'page': ?a.page,
          'startMs': ?a.startMs,
          'endMs': ?a.endMs,
          'region': ?(a.region == null
              ? null
              : [
                  a.region!.left,
                  a.region!.top,
                  a.region!.right,
                  a.region!.bottom,
                ]),
          'textSnippet': ?a.textSnippet,
          'snapshot': ?(a.snapshot == null ? null : base64Encode(a.snapshot!)),
          'needsReview': a.needsReview,
          'createdAt': a.createdAt.toUtc().toIso8601String(),
        },
    ],
    'notes': [
      for (final n in notes)
        {
          'id': n.id,
          'body': n.body,
          'documentId': ?n.documentId,
          'page': ?n.page,
          'startMs': ?n.startMs,
          'endMs': ?n.endMs,
          'region': ?(n.region == null
              ? null
              : [
                  n.region!.left,
                  n.region!.top,
                  n.region!.right,
                  n.region!.bottom,
                ]),
          'snapshot': ?(n.snapshot == null ? null : base64Encode(n.snapshot!)),
          'itemId': ?n.itemId,
          'createdAt': n.createdAt.toUtc().toIso8601String(),
          'updatedAt': n.updatedAt.toUtc().toIso8601String(),
        },
    ],
    'resourceLinks': [
      for (final l in resourceLinks)
        {'documentId': l.documentId, 'nodeId': l.nodeId},
    ],
    'reviews': [
      for (final r in reviews)
        {
          'itemId': r.itemId,
          'reviewedAt': r.record.reviewedAt.toUtc().toIso8601String(),
          'rating': r.record.rating.name,
          'durationMs': r.record.duration?.inMilliseconds,
          'schedulerId': r.record.schedulerId,
          'before': r.record.before.toJson(),
          'after': r.record.after.toJson(),
        },
    ],
  };
}
