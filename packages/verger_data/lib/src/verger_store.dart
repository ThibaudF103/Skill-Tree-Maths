import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:verger_core/verger_core.dart';

import 'database.dart';

/// Un nœud ne peut pas être supprimé : il contient encore des sous-nœuds ou
/// des connaissances (utiliser `recursive: true`).
class NodeNotEmptyException implements Exception {
  const NodeNotEmptyException(this.nodeId);
  final String nodeId;
  @override
  String toString() => 'NodeNotEmptyException($nodeId)';
}

/// La révision a été calculée à partir d'un état qui n'est plus l'état
/// enregistré (révision concurrente ou écran périmé).
class StaleReviewException implements Exception {
  const StaleReviewException(this.itemId);
  final String itemId;
  @override
  String toString() => 'StaleReviewException($itemId)';
}

/// Bilan d'une mise à jour de PDF.
typedef DocumentUpdate = ({
  /// Ancres déplacées vers une autre page (pages insérées ou supprimées).
  int moved,

  /// Ancres dont la page n'a pas été retrouvée : à vérifier.
  int flagged,

  /// Pages apparues (à partir de 1), pour y attacher les nouveaux versos.
  List<int> newPages,
});

/// Accès aux données du Verger. L'application ne manipule que des types du
/// domaine (`verger_core`) ; drift reste un détail d'implémentation.
class VergerStore {
  VergerStore(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final VergerDatabase _db;
  final DateTime Function() _clock;

  DateTime _now() => _clock().toUtc();

  Future<void> close() => _db.close();

  // --- Nœuds ---------------------------------------------------------------

  Future<List<KnowledgeNode>> allNodes() async =>
      (await _nodesQuery().get()).map(_toNode).toList();

  Stream<List<KnowledgeNode>> watchNodes() =>
      _nodesQuery().watch().map((rows) => rows.map(_toNode).toList());

  Future<KnowledgeNode?> node(String id) async {
    final row = await (_db.select(
      _db.nodes,
    )..where((n) => n.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toNode(row);
  }

  /// Crée un nœud à la fin de ses frères (un arbre si [parentId] est `null`).
  Future<KnowledgeNode> createNode({
    required String title,
    String? parentId,
    String? curriculumKey,
    NodeOrigin origin = NodeOrigin.user,
  }) => _db.transaction(() async {
    final row = NodeRow(
      id: newId(),
      parentId: parentId,
      title: title.trim(),
      sortIndex: (await _siblings(parentId)).length,
      curriculumKey: curriculumKey,
      origin: origin,
      createdAt: _now(),
    );
    await _db.into(_db.nodes).insert(row);
    return _toNode(row);
  });

  Future<void> renameNode(String id, String title) =>
      (_db.update(_db.nodes)..where((n) => n.id.equals(id))).write(
        NodesCompanion(title: Value(title.trim())),
      );

  /// Déplace un nœud sous [newParentId] (`null` : en fait un arbre), à la
  /// position [index] parmi ses nouveaux frères (à la fin par défaut).
  Future<void> moveNode(String id, {String? newParentId, int? index}) =>
      _db.transaction(() async {
        // Interdit de déplacer un nœud dans sa propre descendance.
        for (String? cursor = newParentId; cursor != null;) {
          if (cursor == id) {
            throw ArgumentError(
              'Un nœud ne peut pas devenir son propre '
              'descendant.',
            );
          }
          cursor = (await node(cursor))?.parentId;
        }
        final moving = await node(id);
        if (moving == null) throw ArgumentError.value(id, 'id', 'inconnu');

        final oldSiblings = (await _siblings(
          moving.parentId,
        )).where((n) => n.id != id).toList();
        await _renumber(oldSiblings.map((n) => n.id).toList());

        final newSiblings = moving.parentId == newParentId
            ? oldSiblings
            : await _siblings(newParentId);
        final ids = newSiblings.map((n) => n.id).toList()
          ..insert(
            (index ?? newSiblings.length).clamp(0, newSiblings.length),
            id,
          );
        await (_db.update(_db.nodes)..where((n) => n.id.equals(id))).write(
          NodesCompanion(parentId: Value(newParentId)),
        );
        await _renumber(ids);
      });

  /// Supprime un nœud. Sans [recursive], refuse s'il n'est pas vide ; avec,
  /// supprime aussi sous-nœuds, connaissances et historiques.
  Future<void> deleteNode(String id, {bool recursive = false}) =>
      _db.transaction(() async {
        final victim = await node(id);
        if (victim == null) return;
        final all = await allNodes();
        final subtree = <String>[id];
        for (var i = 0; i < subtree.length; i++) {
          subtree.addAll(
            all.where((n) => n.parentId == subtree[i]).map((n) => n.id),
          );
        }
        if (!recursive) {
          final hasItems =
              await (_db.select(_db.items)
                    ..where((i) => i.nodeId.equals(id))
                    ..limit(1))
                  .getSingleOrNull() !=
              null;
          if (subtree.length > 1 || hasItems) throw NodeNotEmptyException(id);
        }
        await (_db.delete(
          _db.items,
        )..where((i) => i.nodeId.isIn(subtree))).go();
        // Des feuilles vers la racine, pour respecter les clés étrangères.
        for (final nodeId in subtree.reversed) {
          await (_db.delete(_db.nodes)..where((n) => n.id.equals(nodeId))).go();
        }
        await _renumber(
          (await _siblings(victim.parentId)).map((n) => n.id).toList(),
        );
      });

  // --- Connaissances -------------------------------------------------------

  Future<List<KnowledgeItem>> allItems() async =>
      (await _itemsQuery().get()).map(_toItem).toList();

  Stream<List<KnowledgeItem>> watchItems({String? nodeId}) => _itemsQuery(
    nodeId: nodeId,
  ).watch().map((rows) => rows.map(_toItem).toList());

  Future<KnowledgeItem?> item(String id) async {
    final row = await (_db.select(
      _db.items,
    )..where((i) => i.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toItem(row);
  }

  Future<KnowledgeItem> createItem({
    required String nodeId,
    required ItemKind kind,
    required String title,
    String? body,
  }) async {
    final now = _now();
    final item = KnowledgeItem(
      id: newId(),
      nodeId: nodeId,
      kind: kind,
      title: title.trim(),
      body: _blankToNull(body),
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.items).insert(_itemCompanion(item));
    return item;
  }

  /// Modifie le contenu d'une connaissance (jamais son état de révision).
  Future<void> updateItem(
    String id, {
    String? title,
    String? Function()? body,
    ItemKind? kind,
    String? nodeId,
    bool? suspended,
  }) => (_db.update(_db.items)..where((i) => i.id.equals(id))).write(
    ItemsCompanion(
      title: title == null ? const Value.absent() : Value(title.trim()),
      body: body == null ? const Value.absent() : Value(_blankToNull(body())),
      kind: Value.absentIfNull(kind),
      nodeId: Value.absentIfNull(nodeId),
      suspended: Value.absentIfNull(suspended),
      updatedAt: Value(_now()),
    ),
  );

  Future<void> deleteItem(String id) =>
      (_db.delete(_db.items)..where((i) => i.id.equals(id))).go();

  // --- Révisions -----------------------------------------------------------

  /// Enregistre une révision : ajoute la trace et met à jour l'état de la
  /// connaissance, de façon atomique.
  Future<void> applyReview(String itemId, ReviewRecord record) =>
      _db.transaction(() async {
        final current = await item(itemId);
        if (current == null) {
          throw ArgumentError.value(itemId, 'itemId', 'inconnu');
        }
        if (current.scheduling != record.before) {
          throw StaleReviewException(itemId);
        }
        await _insertReview(itemId, record);
        await (_db.update(_db.items)..where((i) => i.id.equals(itemId))).write(
          _schedulingCompanion(record.after),
        );
      });

  /// Historique d'une connaissance, du plus ancien au plus récent.
  Future<List<ReviewRecord>> history(String itemId) async {
    final rows =
        await (_db.select(_db.reviewLogs)
              ..where((r) => r.itemId.equals(itemId))
              ..orderBy([(r) => OrderingTerm.asc(r.reviewedAt)]))
            .get();
    return rows.map(_toRecord).toList();
  }

  // --- Réglages ------------------------------------------------------------

  static const _schedulerKey = 'scheduler';

  Future<SchedulerSettings> schedulerSettings() async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(_schedulerKey))).getSingleOrNull();
    return row == null
        ? const SchedulerSettings()
        : SchedulerSettings.fromJson(
            jsonDecode(row.value) as Map<String, Object?>,
          );
  }

  Future<void> saveSchedulerSettings(SchedulerSettings settings) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingRow(key: _schedulerKey, value: jsonEncode(settings.toJson())),
      );

  // --- Documents PDF -------------------------------------------------------

  Future<List<SourceDocument>> allDocuments() async =>
      (await _documentsQuery().get()).map(_toDocument).toList();

  Stream<List<SourceDocument>> watchDocuments() =>
      _documentsQuery().watch().map((rows) => rows.map(_toDocument).toList());

  Future<SourceDocument?> document(String id) async {
    final row = await (_db.select(
      _db.documents,
    )..where((d) => d.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDocument(row);
  }

  /// Contenu du PDF, ou `null` s'il n'est pas sur cet appareil (sauvegarde
  /// restaurée ailleurs, par exemple).
  Future<Uint8List?> documentBytes(String id) async {
    final row = await (_db.select(
      _db.documentFiles,
    )..where((f) => f.documentId.equals(id))).getSingleOrNull();
    return row?.bytes;
  }

  /// Ajoute un PDF à la bibliothèque. [fingerprints] : une empreinte par page.
  Future<SourceDocument> importDocument({
    required String title,
    required DocumentRole role,
    required Uint8List bytes,
    required String contentHash,
    required List<Uint8List> fingerprints,
  }) => _db.transaction(() async {
    final row = DocumentRow(
      id: newId(),
      title: title.trim(),
      role: role,
      pageCount: fingerprints.length,
      contentHash: contentHash,
      importedAt: _now(),
      version: 1,
      fingerprints: _packFingerprints(fingerprints),
      newPages: '[]',
    );
    await _db.into(_db.documents).insert(row);
    await _db
        .into(_db.documentFiles)
        .insert(DocumentFileRow(documentId: row.id, bytes: bytes));
    return _toDocument(row);
  });

  Future<void> renameDocument(String id, String title) =>
      (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
        DocumentsCompanion(title: Value(title.trim())),
      );

  /// Supprime le PDF et toutes les ancres qui y renvoient.
  Future<void> deleteDocument(String id) =>
      (_db.delete(_db.documents)..where((d) => d.id.equals(id))).go();

  /// Remplace le fichier par une nouvelle version (carnet réexporté) et
  /// recale les ancres d'après les empreintes des pages.
  Future<DocumentUpdate> updateDocument(
    String id, {
    required Uint8List bytes,
    required String contentHash,
    required List<Uint8List> fingerprints,
  }) => _db.transaction(() async {
    final old = await document(id);
    if (old == null) throw ArgumentError.value(id, 'id', 'inconnu');
    final remap = remapPages(old.fingerprints, fingerprints);

    var moved = 0;
    var flagged = 0;
    for (final anchor in await _anchorsQuery(documentId: id).get()) {
      final match = remap.matches[anchor.page];
      if (match?.page != null) {
        if (match!.page != anchor.page) moved++;
        await (_db.update(_db.anchors)..where((a) => a.id.equals(anchor.id)))
            .write(AnchorsCompanion(page: Value(match.page!)));
      } else if (!anchor.needsReview) {
        flagged++;
        await (_db.update(_db.anchors)..where((a) => a.id.equals(anchor.id)))
            .write(const AnchorsCompanion(needsReview: Value(true)));
      }
    }

    await (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(
        pageCount: Value(fingerprints.length),
        contentHash: Value(contentHash),
        importedAt: Value(_now()),
        version: Value(old.version + 1),
        fingerprints: Value(_packFingerprints(fingerprints)),
        newPages: Value(jsonEncode(remap.newPages)),
      ),
    );
    await _db
        .into(_db.documentFiles)
        .insertOnConflictUpdate(DocumentFileRow(documentId: id, bytes: bytes));
    return (moved: moved, flagged: flagged, newPages: remap.newPages);
  });

  // --- Ancres (recto / verso) ----------------------------------------------

  Future<Anchor> addAnchor({
    required String itemId,
    required String documentId,
    required AnchorRole role,
    required int page,
    NormalizedRect? region,
    String? textSnippet,
    Uint8List? snapshot,
  }) async {
    final anchor = Anchor(
      id: newId(),
      itemId: itemId,
      documentId: documentId,
      role: role,
      page: page,
      region: region,
      textSnippet: _blankToNull(textSnippet),
      snapshot: snapshot,
      createdAt: _now(),
    );
    await _db.into(_db.anchors).insert(_anchorRow(anchor));
    return anchor;
  }

  Future<List<Anchor>> anchorsOf(String itemId) async =>
      (await _anchorsQuery(itemId: itemId).get()).map(_toAnchor).toList();

  Stream<List<Anchor>> watchAnchors({String? itemId, String? documentId}) =>
      _anchorsQuery(
        itemId: itemId,
        documentId: documentId,
      ).watch().map((rows) => rows.map(_toAnchor).toList());

  /// Recale une ancre à la main (page et zone) ; elle n'est plus à vérifier.
  Future<void> relocateAnchor(
    String id, {
    required int page,
    NormalizedRect? region,
    Uint8List? snapshot,
  }) => (_db.update(_db.anchors)..where((a) => a.id.equals(id))).write(
    AnchorsCompanion(
      page: Value(page),
      left: Value(region?.left),
      top: Value(region?.top),
      right: Value(region?.right),
      bottom: Value(region?.bottom),
      snapshot: snapshot == null ? const Value.absent() : Value(snapshot),
      needsReview: const Value(false),
    ),
  );

  Future<void> deleteAnchor(String id) =>
      (_db.delete(_db.anchors)..where((a) => a.id.equals(id))).go();

  // --- Échange (sauvegarde, modèles) --------------------------------------

  /// Sauvegarde complète : structure, connaissances, historique, réglages.
  Future<VergerArchive> exportArchive() async {
    final reviews = await (_db.select(
      _db.reviewLogs,
    )..orderBy([(r) => OrderingTerm.asc(r.reviewedAt)])).get();
    return VergerArchive(
      nodes: await allNodes(),
      items: await allItems(),
      reviews: [
        for (final row in reviews) (itemId: row.itemId, record: _toRecord(row)),
      ],
      settings: await schedulerSettings(),
      documents: await allDocuments(),
      anchors: (await _anchorsQuery().get()).map(_toAnchor).toList(),
    );
  }

  /// Remplace **toutes** les données par celles de l'archive (restauration
  /// d'une sauvegarde), en conservant identifiants et dates.
  Future<void> restoreArchive(VergerArchive archive) =>
      _db.transaction(() async {
        archive.validate();
        await _db.delete(_db.reviewLogs).go();
        await _db.delete(_db.anchors).go();
        await _db.delete(_db.items).go();
        await _db.delete(_db.nodes).go();
        // Les PDF déjà présents sur l'appareil sont conservés s'ils figurent
        // dans la sauvegarde (qui ne contient pas les fichiers eux-mêmes).
        final keptDocuments = {for (final d in archive.documents) d.id};
        await (_db.delete(
          _db.documents,
        )..where((d) => d.id.isNotIn(keptDocuments))).go();
        for (final d in archive.documents) {
          await _db
              .into(_db.documents)
              .insertOnConflictUpdate(
                DocumentRow(
                  id: d.id,
                  title: d.title,
                  role: d.role,
                  pageCount: d.pageCount,
                  contentHash: d.contentHash,
                  importedAt: d.importedAt.toUtc(),
                  version: d.version,
                  fingerprints: _packFingerprints(d.fingerprints),
                  newPages: jsonEncode(d.newPages),
                ),
              );
        }
        await _insertNodes(archive.nodes);
        for (final item in archive.items) {
          await _db.into(_db.items).insert(_itemCompanion(item));
        }
        for (final anchor in archive.anchors) {
          await _db.into(_db.anchors).insert(_anchorRow(anchor));
        }
        for (final review in archive.reviews) {
          await _insertReview(review.itemId, review.record);
        }
        if (archive.settings != null) {
          await saveSchedulerSettings(archive.settings!);
        }
      });

  /// Ajoute le contenu d'un modèle (arbres et connaissances) à côté des
  /// données existantes : nouveaux identifiants, aucune progression reprise.
  /// Renvoie les arbres créés.
  Future<List<KnowledgeNode>> importTemplate(VergerArchive archive) =>
      _db.transaction(() async {
        archive.validate();
        final now = _now();
        final newIds = {for (final n in archive.nodes) n.id: newId()};
        final trees = await _siblings(null);
        var nextTreeIndex = trees.length;
        final nodes = [
          for (final n in archive.nodes)
            KnowledgeNode(
              id: newIds[n.id]!,
              parentId: n.parentId == null ? null : newIds[n.parentId],
              title: n.title,
              sortIndex: n.parentId == null ? nextTreeIndex++ : n.sortIndex,
              curriculumKey: n.curriculumKey,
              origin: n.origin,
              createdAt: now,
            ),
        ];
        await _insertNodes(nodes);
        for (final (i, item) in archive.items.indexed) {
          // Décalage d'une milliseconde : conserve l'ordre du modèle.
          final created = now.add(Duration(milliseconds: i));
          await _db
              .into(_db.items)
              .insert(
                _itemCompanion(
                  KnowledgeItem(
                    id: newId(),
                    nodeId: newIds[item.nodeId]!,
                    kind: item.kind,
                    title: item.title,
                    body: item.body,
                    createdAt: created,
                    updatedAt: created,
                  ),
                ),
              );
        }
        return nodes.where((n) => n.isTree).toList();
      });

  /// Insère des nœuds parents avant enfants (clés étrangères).
  Future<void> _insertNodes(List<KnowledgeNode> nodes) async {
    final pending = [...nodes];
    final inserted = <String>{};
    while (pending.isNotEmpty) {
      final ready = pending
          .where((n) => n.parentId == null || inserted.contains(n.parentId))
          .toList();
      if (ready.isEmpty) throw StateError('Hiérarchie incohérente');
      for (final n in ready) {
        await _db
            .into(_db.nodes)
            .insert(
              NodeRow(
                id: n.id,
                parentId: n.parentId,
                title: n.title,
                sortIndex: n.sortIndex,
                curriculumKey: n.curriculumKey,
                origin: n.origin,
                createdAt: n.createdAt.toUtc(),
              ),
            );
        inserted.add(n.id);
        pending.remove(n);
      }
    }
  }

  Future<void> _insertReview(String itemId, ReviewRecord record) => _db
      .into(_db.reviewLogs)
      .insert(
        ReviewLogRow(
          id: newId(),
          itemId: itemId,
          reviewedAt: record.reviewedAt.toUtc(),
          rating: record.rating,
          durationMs: record.duration?.inMilliseconds,
          schedulerId: record.schedulerId,
          stateBefore: jsonEncode(record.before.toJson()),
          stateAfter: jsonEncode(record.after.toJson()),
        ),
      );

  static ReviewRecord _toRecord(ReviewLogRow row) => ReviewRecord(
    rating: row.rating,
    reviewedAt: row.reviewedAt.toUtc(),
    before: SchedulingState.fromJson(
      jsonDecode(row.stateBefore) as Map<String, Object?>,
    ),
    after: SchedulingState.fromJson(
      jsonDecode(row.stateAfter) as Map<String, Object?>,
    ),
    schedulerId: row.schedulerId,
    duration: row.durationMs == null
        ? null
        : Duration(milliseconds: row.durationMs!),
  );

  // --- Interne -------------------------------------------------------------

  SimpleSelectStatement<$NodesTable, NodeRow> _nodesQuery() =>
      _db.select(_db.nodes)..orderBy([
        (n) => OrderingTerm.asc(n.sortIndex),
        (n) => OrderingTerm.asc(n.createdAt),
      ]);

  SimpleSelectStatement<$ItemsTable, ItemRow> _itemsQuery({String? nodeId}) {
    final query = _db.select(_db.items)
      ..orderBy([(i) => OrderingTerm.asc(i.createdAt)]);
    if (nodeId != null) query.where((i) => i.nodeId.equals(nodeId));
    return query;
  }

  Future<List<NodeRow>> _siblings(String? parentId) {
    final query = _db.select(_db.nodes)
      ..where(
        (n) => parentId == null
            ? n.parentId.isNull()
            : n.parentId.equals(parentId),
      )
      ..orderBy([(n) => OrderingTerm.asc(n.sortIndex)]);
    return query.get();
  }

  Future<void> _renumber(List<String> orderedIds) async {
    for (final (index, id) in orderedIds.indexed) {
      await (_db.update(_db.nodes)..where((n) => n.id.equals(id))).write(
        NodesCompanion(sortIndex: Value(index)),
      );
    }
  }

  SimpleSelectStatement<$DocumentsTable, DocumentRow> _documentsQuery() =>
      _db.select(_db.documents)..orderBy([
        (d) => OrderingTerm.asc(d.role),
        (d) => OrderingTerm.asc(d.title),
      ]);

  SimpleSelectStatement<$AnchorsTable, AnchorRow> _anchorsQuery({
    String? itemId,
    String? documentId,
  }) {
    final query = _db.select(_db.anchors)
      ..orderBy([
        (a) => OrderingTerm.asc(a.role),
        (a) => OrderingTerm.asc(a.createdAt),
      ]);
    if (itemId != null) query.where((a) => a.itemId.equals(itemId));
    if (documentId != null) query.where((a) => a.documentId.equals(documentId));
    return query;
  }

  static Uint8List _packFingerprints(List<Uint8List> fingerprints) {
    final builder = BytesBuilder(copy: false);
    for (final f in fingerprints) {
      builder.add(f);
    }
    return builder.takeBytes();
  }

  static List<Uint8List> _unpackFingerprints(Uint8List packed, int pageCount) {
    if (pageCount == 0 || packed.isEmpty) return const [];
    final size = packed.length ~/ pageCount;
    return [
      for (var i = 0; i < pageCount; i++)
        Uint8List.sublistView(packed, i * size, (i + 1) * size),
    ];
  }

  static SourceDocument _toDocument(DocumentRow row) => SourceDocument(
    id: row.id,
    title: row.title,
    role: row.role,
    pageCount: row.pageCount,
    contentHash: row.contentHash,
    importedAt: row.importedAt.toUtc(),
    version: row.version,
    fingerprints: _unpackFingerprints(row.fingerprints, row.pageCount),
    newPages: (jsonDecode(row.newPages) as List).cast<int>(),
  );

  static Anchor _toAnchor(AnchorRow row) => Anchor(
    id: row.id,
    itemId: row.itemId,
    documentId: row.documentId,
    role: row.role,
    page: row.page,
    region:
        row.left == null ||
            row.top == null ||
            row.right == null ||
            row.bottom == null
        ? null
        : NormalizedRect(row.left!, row.top!, row.right!, row.bottom!),
    textSnippet: row.textSnippet,
    snapshot: row.snapshot,
    needsReview: row.needsReview,
    createdAt: row.createdAt.toUtc(),
  );

  static AnchorRow _anchorRow(Anchor a) => AnchorRow(
    id: a.id,
    itemId: a.itemId,
    documentId: a.documentId,
    role: a.role,
    page: a.page,
    left: a.region?.left,
    top: a.region?.top,
    right: a.region?.right,
    bottom: a.region?.bottom,
    textSnippet: a.textSnippet,
    snapshot: a.snapshot,
    needsReview: a.needsReview,
    createdAt: a.createdAt.toUtc(),
  );

  static String? _blankToNull(String? text) =>
      text == null || text.trim().isEmpty ? null : text.trim();

  static KnowledgeNode _toNode(NodeRow row) => KnowledgeNode(
    id: row.id,
    parentId: row.parentId,
    title: row.title,
    sortIndex: row.sortIndex,
    curriculumKey: row.curriculumKey,
    origin: row.origin,
    createdAt: row.createdAt.toUtc(),
  );

  static KnowledgeItem _toItem(ItemRow row) => KnowledgeItem(
    id: row.id,
    nodeId: row.nodeId,
    kind: row.kind,
    title: row.title,
    body: row.body,
    suspended: row.suspended,
    createdAt: row.createdAt.toUtc(),
    updatedAt: row.updatedAt.toUtc(),
    scheduling: SchedulingState(
      phase: row.phase,
      step: row.step,
      stability: row.stability,
      difficulty: row.difficulty,
      due: row.due?.toUtc(),
      lastReview: row.lastReview?.toUtc(),
      reps: row.reps,
      lapses: row.lapses,
    ),
  );

  static ItemsCompanion _itemCompanion(KnowledgeItem item) =>
      _schedulingCompanion(item.scheduling).copyWith(
        id: Value(item.id),
        nodeId: Value(item.nodeId),
        kind: Value(item.kind),
        title: Value(item.title),
        body: Value(item.body),
        suspended: Value(item.suspended),
        createdAt: Value(item.createdAt),
        updatedAt: Value(item.updatedAt),
      );

  static ItemsCompanion _schedulingCompanion(SchedulingState s) =>
      ItemsCompanion(
        phase: Value(s.phase),
        step: Value(s.step),
        stability: Value(s.stability),
        difficulty: Value(s.difficulty),
        due: Value(s.due?.toUtc()),
        lastReview: Value(s.lastReview?.toUtc()),
        reps: Value(s.reps),
        lapses: Value(s.lapses),
      );
}
