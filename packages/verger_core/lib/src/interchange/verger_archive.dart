import '../domain/item_kind.dart';
import '../domain/knowledge_item.dart';
import '../domain/knowledge_node.dart';
import '../domain/rating.dart';
import '../domain/review_record.dart';
import '../domain/scheduling_state.dart';
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
    this.settings,
    this.title,
  });

  static const format = 'verger';
  static const currentVersion = 1;

  final List<KnowledgeNode> nodes;
  final List<KnowledgeItem> items;
  final List<ArchivedReview> reviews;
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
      final settings = json['settings'] == null
          ? null
          : SchedulerSettings.fromJson((json['settings'] as Map).cast());
      final archive = VergerArchive(
        nodes: nodes,
        items: items,
        reviews: reviews,
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
          'suspended': i.suspended,
          'createdAt': i.createdAt.toUtc().toIso8601String(),
          'updatedAt': i.updatedAt.toUtc().toIso8601String(),
          'scheduling': i.scheduling.toJson(),
        },
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
