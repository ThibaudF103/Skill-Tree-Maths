import 'dart:convert';

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
        await _db
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
    return [
      for (final row in rows)
        ReviewRecord(
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
        ),
    ];
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
