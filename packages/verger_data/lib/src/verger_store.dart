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

/// Ce qu'une suppression a retiré, pour la défaire avec
/// [VergerStore.undoDeletion] (bouton « Annuler »). Les lignes sont remises
/// telles quelles, avec les mêmes identifiants.
final class Deletion {
  Deletion._(this._undo);
  final Future<void> Function() _undo;
}

/// Bilan d'une mise à jour de PDF.
/// PDF joint à un paquet (ou téléchargé à l'import), déjà analysé.
typedef PackPdf = ({
  Uint8List bytes,
  String contentHash,
  List<Uint8List> fingerprints,
});

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
    ExerciseLevel? level,
    String? autoExercise,
  }) => _db.transaction(() async {
    final now = _now();
    final item = KnowledgeItem(
      id: newId(),
      nodeId: nodeId,
      kind: kind,
      title: title.trim(),
      body: _blankToNull(body),
      level: kind.family == ItemFamily.exercise ? level : null,
      autoExercise: kind.family == ItemFamily.exercise
          ? _blankToNull(autoExercise)
          : null,
      sortIndex: await _nextItemIndex(nodeId),
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.items).insert(_itemCompanion(item));
    return item;
  });

  /// Position après la dernière connaissance de [nodeId].
  Future<int> _nextItemIndex(String nodeId) async {
    final max = _db.items.sortIndex.max();
    final row =
        await (_db.selectOnly(_db.items)
              ..addColumns([max])
              ..where(_db.items.nodeId.equals(nodeId)))
            .getSingle();
    final value = row.read(max);
    return value == null ? 0 : value + 1;
  }

  /// Modifie le contenu d'une connaissance (jamais son état de révision).
  /// Changée de nœud, elle se place après les connaissances de celui-ci ;
  /// la difficulté et l'exercice corrigé ne concernent que les exercices.
  Future<void> updateItem(
    String id, {
    String? title,
    String? Function()? body,
    ItemKind? kind,
    ExerciseLevel? Function()? level,
    String? Function()? autoExercise,
    String? nodeId,
    bool? suspended,
  }) => _db.transaction(() async {
    final current = await item(id);
    if (current == null) return;
    final moved = nodeId != null && nodeId != current.nodeId;
    final family = (kind ?? current.kind).family;
    final newLevel = family != ItemFamily.exercise
        ? const Value<ExerciseLevel?>(null)
        : level == null
        ? const Value<ExerciseLevel?>.absent()
        : Value(level());
    final newAuto = family != ItemFamily.exercise
        ? const Value<String?>(null)
        : autoExercise == null
        ? const Value<String?>.absent()
        : Value(_blankToNull(autoExercise()));
    await (_db.update(_db.items)..where((i) => i.id.equals(id))).write(
      ItemsCompanion(
        title: title == null ? const Value.absent() : Value(title.trim()),
        body: body == null ? const Value.absent() : Value(_blankToNull(body())),
        kind: Value.absentIfNull(kind),
        level: newLevel,
        autoExercise: newAuto,
        nodeId: moved ? Value(nodeId) : const Value.absent(),
        sortIndex: moved
            ? Value(await _nextItemIndex(nodeId))
            : const Value.absent(),
        suspended: Value.absentIfNull(suspended),
        updatedAt: Value(_now()),
      ),
    );
  });

  /// Place une connaissance dans [nodeId] à la position [index] parmi les
  /// autres connaissances de ce nœud (à la fin par défaut).
  Future<void> moveItem(String id, {required String nodeId, int? index}) =>
      _db.transaction(() async {
        final moving = await item(id);
        if (moving == null) throw ArgumentError.value(id, 'id', 'inconnu');
        if (await node(nodeId) == null) {
          throw ArgumentError.value(nodeId, 'nodeId', 'inconnu');
        }
        if (moving.nodeId != nodeId) {
          final left = (await _itemsQuery(
            nodeId: moving.nodeId,
          ).get()).where((i) => i.id != id).map((i) => i.id).toList();
          await _renumberItems(left);
        }
        final siblings = (await _itemsQuery(
          nodeId: nodeId,
        ).get()).where((i) => i.id != id).map((i) => i.id).toList();
        siblings.insert(
          (index ?? siblings.length).clamp(0, siblings.length),
          id,
        );
        if (moving.nodeId != nodeId) {
          await (_db.update(_db.items)..where((i) => i.id.equals(id))).write(
            ItemsCompanion(nodeId: Value(nodeId), updatedAt: Value(_now())),
          );
        }
        await _renumberItems(siblings);
      });

  Future<void> _renumberItems(List<String> orderedIds) async {
    for (final (index, id) in orderedIds.indexed) {
      await (_db.update(_db.items)..where((i) => i.id.equals(id))).write(
        ItemsCompanion(sortIndex: Value(index)),
      );
    }
  }

  /// Supprime une connaissance avec son historique de révision et ses liens
  /// (prérequis, recto / verso) ; ses notes restent, détachées. L'annulation
  /// rétablit tout, notes rattachées comprises.
  Future<Deletion> deleteItem(String id) => _db.transaction(() async {
    final item = await (_db.select(
      _db.items,
    )..where((i) => i.id.equals(id))).getSingleOrNull();
    final logs = await (_db.select(
      _db.reviewLogs,
    )..where((l) => l.itemId.equals(id))).get();
    final edges = await (_db.select(
      _db.prerequisites,
    )..where((p) => p.itemId.equals(id) | p.requiresId.equals(id))).get();
    final anchors = await _anchorsQuery(itemId: id).get();
    final noteIds = [
      for (final n in await (_db.select(
        _db.notes,
      )..where((n) => n.itemId.equals(id))).get())
        n.id,
    ];
    await (_db.delete(_db.items)..where((i) => i.id.equals(id))).go();
    return Deletion._(() async {
      if (item == null) return;
      if (await node(item.nodeId) == null) {
        throw StateError('La branche de la connaissance a été supprimée.');
      }
      await _db.into(_db.items).insert(item);
      for (final log in logs) {
        await _db.into(_db.reviewLogs).insert(log);
      }
      // Seulement les liens vers des connaissances et contenus encore là, et
      // sans cycle (un autre lien a pu être ajouté entre-temps).
      final items = {for (final i in await _db.select(_db.items).get()) i.id};
      for (final edge in edges) {
        if (!items.contains(edge.itemId) || !items.contains(edge.requiresId)) {
          continue;
        }
        final graph = PrerequisiteGraph(await prerequisites());
        if (graph.wouldCreateCycle(edge.itemId, edge.requiresId)) continue;
        await _db.into(_db.prerequisites).insertOnConflictUpdate(edge);
      }
      final documents = {
        for (final d in await _db.select(_db.documents).get()) d.id,
      };
      for (final anchor in anchors) {
        if (documents.contains(anchor.documentId)) {
          await _db.into(_db.anchors).insert(anchor);
        }
      }
      await (_db.update(_db.notes)
            ..where((n) => n.id.isIn(noteIds) & n.itemId.isNull()))
          .write(NotesCompanion(itemId: Value(id)));
    });
  });

  /// Défait une suppression ([deleteItem], [deleteAnchor],
  /// [removePrerequisite]). Lève une erreur si ce dont elle dépend a disparu
  /// entre-temps (branche, connaissance…).
  Future<void> undoDeletion(Deletion deletion) =>
      _db.transaction(deletion._undo);

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
    if (row == null) return const SchedulerSettings();
    try {
      return SchedulerSettings.fromJson(
        jsonDecode(row.value) as Map<String, Object?>,
      );
    } catch (_) {
      // Valeur illisible ou hors bornes : l'application doit démarrer.
      return const SchedulerSettings();
    }
  }

  Future<void> saveSchedulerSettings(SchedulerSettings settings) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingRow(key: _schedulerKey, value: jsonEncode(settings.toJson())),
      );

  static const _lastNodeKey = 'lastNode';

  /// Dernière branche choisie pour créer une connaissance, si elle existe
  /// encore.
  Future<KnowledgeNode?> lastNode() async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(_lastNodeKey))).getSingleOrNull();
    if (row == null) return null;
    final id = jsonDecode(row.value);
    return id is String ? node(id) : null;
  }

  Future<void> setLastNode(String nodeId) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingRow(key: _lastNodeKey, value: jsonEncode(nodeId)),
      );

  static const _reviewScopeKey = 'reviewScope';

  /// Nœuds auxquels les révisions sont restreintes (vide : tout le verger).
  Stream<Set<String>> watchReviewScope() =>
      (_db.select(_db.settings)..where((s) => s.key.equals(_reviewScopeKey)))
          .watchSingleOrNull()
          .map((row) {
            if (row == null) return const <String>{};
            final ids = jsonDecode(row.value);
            return ids is List ? ids.whereType<String>().toSet() : const {};
          });

  Future<void> setReviewScope(Set<String> nodeIds) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingRow(key: _reviewScopeKey, value: jsonEncode(nodeIds.toList())),
      );

  static const _strictKey = 'strictPrerequisites';

  /// Déblocage progressif : une nouvelle connaissance n'est proposée qu'une
  /// fois tous ses prérequis vus (activé par défaut).
  Stream<bool> watchStrictPrerequisites() =>
      (_db.select(_db.settings)..where((s) => s.key.equals(_strictKey)))
          .watchSingleOrNull()
          .map((row) => row == null || jsonDecode(row.value) != false);

  Future<bool> strictPrerequisites() => watchStrictPrerequisites().first;

  Future<void> setStrictPrerequisites(bool strict) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingRow(key: _strictKey, value: jsonEncode(strict)),
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

  /// Joint le fichier d'un PDF connu par ses seules empreintes (paquet
  /// importé sans le PDF, sauvegarde restaurée ailleurs). Sans effet si le
  /// fichier est déjà là ; renvoie `true` s'il a été ajouté.
  Future<bool> attachDocumentFile(String id, Uint8List bytes) =>
      _db.transaction(() async {
        if (await documentBytes(id) != null) return false;
        await _db
            .into(_db.documentFiles)
            .insert(DocumentFileRow(documentId: id, bytes: bytes));
        return true;
      });

  /// Ajoute un PDF à la bibliothèque. [fingerprints] : une empreinte par page.
  /// Le contenu est rattaché aux nœuds [nodeIds].
  Future<SourceDocument> importDocument({
    required String title,
    required Uint8List bytes,
    required String contentHash,
    required List<Uint8List> fingerprints,
    String? url,
    Iterable<String> nodeIds = const [],
  }) => _db.transaction(() async {
    final row = DocumentRow(
      id: newId(),
      title: title.trim(),
      kind: ResourceKind.pdf,
      url: _blankToNull(url),
      pageCount: fingerprints.length,
      contentHash: contentHash,
      importedAt: _now(),
      version: 1,
      fingerprints: _packFingerprints(fingerprints),
      newPages: '[]',
      lastPage: 1,
    );
    await _db.into(_db.documents).insert(row);
    await _db
        .into(_db.documentFiles)
        .insert(DocumentFileRow(documentId: row.id, bytes: bytes));
    for (final nodeId in nodeIds) {
      await linkResource(row.id, nodeId);
    }
    return _toDocument(row);
  });

  /// Ajoute une vidéo en ligne ([videoId] : identifiant YouTube), rattachée
  /// aux nœuds [nodeIds].
  Future<SourceDocument> addVideo({
    required String title,
    required String url,
    required String videoId,
    Iterable<String> nodeIds = const [],
  }) => _db.transaction(() async {
    final row = DocumentRow(
      id: newId(),
      title: title.trim(),
      kind: ResourceKind.video,
      url: url.trim(),
      pageCount: 0,
      contentHash: videoId,
      importedAt: _now(),
      version: 1,
      fingerprints: Uint8List(0),
      newPages: '[]',
      lastPage: 1,
    );
    await _db.into(_db.documents).insert(row);
    for (final nodeId in nodeIds) {
      await linkResource(row.id, nodeId);
    }
    return _toDocument(row);
  });

  // --- Rattachement des contenus aux nœuds ----------------------------------

  Future<void> linkResource(String documentId, String nodeId) => _db
      .into(_db.resourceLinks)
      .insertOnConflictUpdate(
        ResourceLinkRow(documentId: documentId, nodeId: nodeId),
      );

  Future<void> unlinkResource(String documentId, String nodeId) =>
      (_db.delete(_db.resourceLinks)..where(
            (l) => l.documentId.equals(documentId) & l.nodeId.equals(nodeId),
          ))
          .go();

  Future<List<ResourceLink>> resourceLinks() async =>
      (await _db.select(_db.resourceLinks).get()).map(_toLink).toList();

  Stream<List<ResourceLink>> watchResourceLinks() => _db
      .select(_db.resourceLinks)
      .watch()
      .map((rows) => rows.map(_toLink).toList());

  static ResourceLink _toLink(ResourceLinkRow row) =>
      (documentId: row.documentId, nodeId: row.nodeId);

  // --- Prérequis entre connaissances ---------------------------------------

  /// Ajoute « [itemId] s'appuie sur [requiresId] » (sans effet s'il existe
  /// déjà). Lève [StateError] si le lien créerait un cycle.
  Future<void> addPrerequisite(String itemId, String requiresId) =>
      _db.transaction(() async {
        final graph = PrerequisiteGraph(await prerequisites());
        if (graph.wouldCreateCycle(itemId, requiresId)) {
          throw StateError(
            'Prérequis refusé : la connaissance en dépendrait d\'elle-même.',
          );
        }
        await _db
            .into(_db.prerequisites)
            .insertOnConflictUpdate(
              PrerequisiteRow(itemId: itemId, requiresId: requiresId),
            );
      });

  /// Retire un prérequis ; l'annulation le remet (refusée par [StateError]
  /// s'il créerait désormais un cycle).
  Future<Deletion> removePrerequisite(String itemId, String requiresId) async {
    await (_db.delete(_db.prerequisites)..where(
          (p) => p.itemId.equals(itemId) & p.requiresId.equals(requiresId),
        ))
        .go();
    return Deletion._(() => addPrerequisite(itemId, requiresId));
  }

  Future<List<Prerequisite>> prerequisites() async =>
      (await _db.select(_db.prerequisites).get()).map(_toPrerequisite).toList();

  Stream<List<Prerequisite>> watchPrerequisites() => _db
      .select(_db.prerequisites)
      .watch()
      .map((rows) => rows.map(_toPrerequisite).toList());

  static Prerequisite _toPrerequisite(PrerequisiteRow row) =>
      (itemId: row.itemId, requiresId: row.requiresId);

  Future<void> _insertPrerequisites(Iterable<Prerequisite> edges) async {
    for (final e in edges) {
      await _db
          .into(_db.prerequisites)
          .insertOnConflictUpdate(
            PrerequisiteRow(itemId: e.itemId, requiresId: e.requiresId),
          );
    }
  }

  /// Adresse de téléchargement d'un PDF (paquets « par référence »).
  Future<void> setDocumentUrl(String id, String? url) =>
      (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
        DocumentsCompanion(url: Value(_blankToNull(url))),
      );

  Future<void> renameDocument(String id, String title) =>
      (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
        DocumentsCompanion(title: Value(title.trim())),
      );

  /// Supprime le contenu, ses rattachements et toutes les ancres qui y
  /// renvoient.
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
      // Déjà à vérifier : son numéro de page ne désigne plus rien de sûr dans
      // la version actuelle, on ne le recale pas au hasard.
      if (anchor.needsReview || anchor.page == null) continue;
      final match = remap.matches[anchor.page!];
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

    // Les notes suivent leurs pages ; une page introuvable garde son numéro.
    for (final note in await _notesQuery(documentId: id).get()) {
      final page = note.page;
      final target = page == null ? null : remap.matches[page]?.page;
      if (target != null && target != page) {
        await (_db.update(_db.notes)..where((n) => n.id.equals(note.id))).write(
          NotesCompanion(page: Value(target)),
        );
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
    int? page,
    int? startMs,
    int? endMs,
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
      startMs: startMs,
      endMs: endMs,
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

  /// Retire un lien recto / verso ; l'annulation le remet tel quel
  /// (miniature comprise).
  Future<Deletion> deleteAnchor(String id) => _db.transaction(() async {
    final row = await (_db.select(
      _db.anchors,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    await (_db.delete(_db.anchors)..where((a) => a.id.equals(id))).go();
    return Deletion._(() async {
      if (row != null) await _db.into(_db.anchors).insert(row);
    });
  });

  // --- Notes de travail ---------------------------------------------------

  Future<Note> createNote({
    String body = '',
    String? documentId,
    int? page,
    int? startMs,
    int? endMs,
    NormalizedRect? region,
    Uint8List? snapshot,
    String? itemId,
    InkDrawing? ink,
    Rating? reviewRating,
  }) async {
    final now = _now();
    final note = Note(
      id: newId(),
      body: body,
      documentId: documentId,
      page: page,
      startMs: startMs,
      endMs: endMs,
      region: region,
      snapshot: snapshot,
      itemId: itemId,
      ink: ink,
      reviewRating: reviewRating,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.notes).insert(_noteRow(note));
    return note;
  }

  Future<Note?> note(String id) async {
    final row = await (_db.select(
      _db.notes,
    )..where((n) => n.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toNote(row);
  }

  /// Suit une note (`null` si elle est supprimée).
  Stream<Note?> watchNote(String id) =>
      (_db.select(_db.notes)..where((n) => n.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : _toNote(row));

  /// Notes d'un PDF (par page puis date) ou d'une connaissance (tentatives
  /// de révision comprises : [Note.isReviewAttempt]).
  Future<List<Note>> notes({String? documentId, String? itemId}) async =>
      (await _notesQuery(
        documentId: documentId,
        itemId: itemId,
      ).get()).map(_toNote).toList();

  Stream<List<Note>> watchNotes({String? documentId, String? itemId}) =>
      _notesQuery(
        documentId: documentId,
        itemId: itemId,
      ).watch().map((rows) => rows.map(_toNote).toList());

  /// Modifie le texte, l'écriture manuscrite ([ink] vide : effacée) et/ou
  /// la connaissance liée ([itemId] : fonction renvoyant le nouvel
  /// identifiant, `null` pour délier).
  Future<void> updateNote(
    String id, {
    String? body,
    InkDrawing? ink,
    String? Function()? itemId,
  }) => (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
    NotesCompanion(
      body: Value.absentIfNull(body),
      ink: ink == null
          ? const Value.absent()
          : Value(ink.isEmpty ? null : ink.encode()),
      itemId: itemId == null ? const Value.absent() : Value(itemId()),
      updatedAt: Value(_now()),
    ),
  );

  Future<void> deleteNote(String id) =>
      (_db.delete(_db.notes)..where((n) => n.id.equals(id))).go();

  /// Supprime la note seulement si elle est toujours vide (ni texte, ni
  /// écriture, ni zone d'un PDF), en une seule requête : une modification
  /// enregistrée entre-temps n'est jamais perdue. Vrai si elle est supprimée.
  Future<bool> deleteNoteIfBlank(String id) async {
    final count =
        await (_db.delete(_db.notes)..where(
              (n) =>
                  n.id.equals(id) &
                  n.body.trim().equals('') &
                  n.ink.isNull() &
                  n.left.isNull(),
            ))
            .go();
    return count > 0;
  }

  /// Mémorise la page consultée pour reprendre la lecture.
  Future<void> setLastPage(String documentId, int page) =>
      (_db.update(_db.documents)..where((d) => d.id.equals(documentId))).write(
        DocumentsCompanion(lastPage: Value(page)),
      );

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
      notes: (await _notesQuery().get()).map(_toNote).toList(),
      resourceLinks: await resourceLinks(),
      prerequisites: await prerequisites(),
    );
  }

  /// Remplace **toutes** les données par celles de l'archive (restauration
  /// d'une sauvegarde), en conservant identifiants et dates.
  Future<void> restoreArchive(VergerArchive archive) =>
      _db.transaction(() async {
        archive.validate();
        await _db.delete(_db.reviewLogs).go();
        await _db.delete(_db.prerequisites).go();
        await _db.delete(_db.resourceLinks).go();
        await _db.delete(_db.notes).go();
        await _db.delete(_db.anchors).go();
        await _db.delete(_db.items).go();
        await _db.delete(_db.nodes).go();
        // Les PDF déjà présents sur l'appareil sont conservés s'ils figurent
        // dans la sauvegarde (qui ne contient pas les fichiers eux-mêmes).
        final keptDocuments = {for (final d in archive.documents) d.id};
        // Un PDF présent sur l'appareil n'est gardé que s'il est bien la
        // version décrite par la sauvegarde ; sinon il faudra le réimporter
        // (ancres et notes restent cohérentes avec leurs pages).
        final archived = {for (final d in archive.documents) d.id: d};
        for (final current in await allDocuments()) {
          final saved = archived[current.id];
          if (saved != null && saved.contentHash != current.contentHash) {
            await (_db.delete(
              _db.documentFiles,
            )..where((f) => f.documentId.equals(current.id))).go();
          }
        }
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
                  kind: d.kind,
                  url: d.url,
                  pageCount: d.pageCount,
                  contentHash: d.contentHash,
                  importedAt: d.importedAt.toUtc(),
                  version: d.version,
                  fingerprints: _packFingerprints(d.fingerprints),
                  newPages: jsonEncode(d.newPages),
                  lastPage: d.lastPage,
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
        for (final note in archive.notes) {
          await _db.into(_db.notes).insert(_noteRow(note));
        }
        for (final link in archive.resourceLinks) {
          await linkResource(link.documentId, link.nodeId);
        }
        await _insertPrerequisites(archive.prerequisites);
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
        return (await _importStructure(archive)).$1;
      });

  /// Insère nœuds et connaissances d'une archive sous de nouveaux
  /// identifiants (arbres placés après les existants, sans progression).
  /// Renvoie les arbres créés et les correspondances d'identifiants.
  Future<(List<KnowledgeNode>, Map<String, String>, Map<String, String>)>
  _importStructure(VergerArchive archive) async {
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
    final itemIds = <String, String>{};
    for (final (i, item) in archive.items.indexed) {
      // Décalage d'une milliseconde : conserve l'ordre du modèle.
      final created = now.add(Duration(milliseconds: i));
      final id = itemIds[item.id] = newId();
      await _db
          .into(_db.items)
          .insert(
            _itemCompanion(
              KnowledgeItem(
                id: id,
                nodeId: newIds[item.nodeId]!,
                kind: item.kind,
                title: item.title,
                body: item.body,
                level: item.level,
                autoExercise: item.autoExercise,
                sortIndex: item.sortIndex,
                createdAt: created,
                updatedAt: created,
              ),
            ),
          );
    }
    await _insertPrerequisites([
      for (final e in archive.prerequisites)
        (itemId: itemIds[e.itemId]!, requiresId: itemIds[e.requiresId]!),
    ]);
    return (nodes.where((n) => n.isTree).toList(), newIds, itemIds);
  }

  /// Paquet d'un nœud (arbre ou branche, qui devient un arbre à l'import) :
  /// descendance, connaissances (sans état de révision), contenus rattachés
  /// (y compris hérités des ancêtres) ou utilisés, ancres et notes.
  Future<VergerArchive> exportTree(String nodeId) async {
    final all = await allNodes();
    final root = all.firstWhere((n) => n.id == nodeId);
    final subtree = <String>{nodeId};
    for (var grew = true; grew;) {
      grew = false;
      for (final n in all) {
        if (n.parentId != null &&
            subtree.contains(n.parentId) &&
            subtree.add(n.id)) {
          grew = true;
        }
      }
    }
    final ancestors = <String>{};
    for (var p = root.parentId; p != null;) {
      ancestors.add(p);
      p = all.where((n) => n.id == p).firstOrNull?.parentId;
    }
    final nodes = [
      for (final n in all)
        if (subtree.contains(n.id))
          n.id == nodeId
              ? KnowledgeNode(
                  id: n.id,
                  title: n.title,
                  sortIndex: 0,
                  curriculumKey: n.curriculumKey,
                  origin: n.origin,
                  createdAt: n.createdAt,
                )
              : n,
    ];
    final items = [
      for (final i in await allItems())
        if (subtree.contains(i.nodeId))
          KnowledgeItem(
            id: i.id,
            nodeId: i.nodeId,
            kind: i.kind,
            title: i.title,
            body: i.body,
            level: i.level,
            autoExercise: i.autoExercise,
            sortIndex: i.sortIndex,
            createdAt: i.createdAt,
            updatedAt: i.updatedAt,
          ),
    ];
    final itemIds = {for (final i in items) i.id};
    final links = <ResourceLink>{
      for (final l in await resourceLinks())
        if (subtree.contains(l.nodeId))
          l
        // Contenus hérités des ancêtres : rattachés à la racine du paquet.
        else if (ancestors.contains(l.nodeId))
          (documentId: l.documentId, nodeId: nodeId),
    };
    final anchors = [
      for (final row in await _anchorsQuery().get())
        if (itemIds.contains(row.itemId)) _toAnchor(row),
    ];
    final documentIds = {
      for (final l in links) l.documentId,
      for (final a in anchors) a.documentId,
    };
    final notes = [
      // Sans les tentatives de révision : personnelles, comme l'historique.
      for (final row in await _notesQuery().get())
        if (row.reviewRating == null &&
            (itemIds.contains(row.itemId) ||
                (row.itemId == null && documentIds.contains(row.documentId))))
          _toNote(row),
    ];
    documentIds.addAll([
      for (final n in notes)
        if (n.documentId != null) n.documentId!,
    ]);
    return VergerArchive(
      nodes: nodes,
      items: items,
      documents: [
        for (final d in await allDocuments())
          if (documentIds.contains(d.id)) d,
      ],
      anchors: anchors,
      notes: notes,
      resourceLinks: links.toList(),
      // Prérequis internes au paquet (ceux vers d'autres arbres sont omis).
      prerequisites: [
        for (final e in await prerequisites())
          if (itemIds.contains(e.itemId) && itemIds.contains(e.requiresId)) e,
      ],
      title: root.title,
    );
  }

  /// Ajoute un paquet à côté des données existantes : nouveaux identifiants,
  /// aucune progression. Un contenu déjà présent (même empreinte) est
  /// réutilisé ; un PDF fourni dans [files] (inclus ou téléchargé) est
  /// enregistré, et s'il diffère de la version décrite par le paquet, ses
  /// ancres sont recalées comme lors d'une mise à jour. Renvoie les arbres
  /// créés.
  Future<List<KnowledgeNode>> importPack(
    VergerArchive archive, {
    Map<String, PackPdf> files = const {},
  }) => _db.transaction(() async {
    archive.validate();
    final (trees, nodeIds, itemIds) = await _importStructure(archive);
    final local = {for (final d in await allDocuments()) d.contentHash: d};
    final documentIds = <String, String>{};
    final outdated = <String, PackPdf>{};
    for (final d in archive.documents) {
      final file = files[d.id];
      final existing = d.contentHash.isEmpty ? null : local[d.contentHash];
      if (existing != null && existing.kind == d.kind) {
        documentIds[d.id] = existing.id;
        if (file != null) await attachDocumentFile(existing.id, file.bytes);
        continue;
      }
      final id = newId();
      documentIds[d.id] = id;
      await _db
          .into(_db.documents)
          .insert(
            DocumentRow(
              id: id,
              title: d.title,
              kind: d.kind,
              url: d.url,
              pageCount: d.pageCount,
              contentHash: d.contentHash,
              importedAt: _now(),
              version: 1,
              fingerprints: _packFingerprints(d.fingerprints),
              newPages: '[]',
              lastPage: 1,
            ),
          );
      if (file != null) {
        await _db
            .into(_db.documentFiles)
            .insert(DocumentFileRow(documentId: id, bytes: file.bytes));
        if (file.contentHash != d.contentHash) outdated[id] = file;
      }
    }
    for (final l in archive.resourceLinks) {
      await linkResource(documentIds[l.documentId]!, nodeIds[l.nodeId]!);
    }
    for (final a in archive.anchors) {
      await _db
          .into(_db.anchors)
          .insert(
            _anchorRow(
              Anchor(
                id: newId(),
                itemId: itemIds[a.itemId]!,
                documentId: documentIds[a.documentId]!,
                role: a.role,
                page: a.page,
                startMs: a.startMs,
                endMs: a.endMs,
                region: a.region,
                textSnippet: a.textSnippet,
                snapshot: a.snapshot,
                needsReview: a.needsReview,
                createdAt: _now(),
              ),
            ),
          );
    }
    for (final n in archive.notes) {
      await _db
          .into(_db.notes)
          .insert(
            _noteRow(
              Note(
                id: newId(),
                body: n.body,
                documentId: n.documentId == null
                    ? null
                    : documentIds[n.documentId],
                page: n.page,
                startMs: n.startMs,
                endMs: n.endMs,
                region: n.region,
                snapshot: n.snapshot,
                itemId: n.itemId == null ? null : itemIds[n.itemId],
                ink: n.ink,
                reviewRating: n.reviewRating,
                createdAt: n.createdAt,
                updatedAt: n.updatedAt,
              ),
            ),
          );
    }
    // Version différente de celle du paquet : recalage des pages.
    for (final e in outdated.entries) {
      await updateDocument(
        e.key,
        bytes: e.value.bytes,
        contentHash: e.value.contentHash,
        fingerprints: e.value.fingerprints,
      );
    }
    return trees;
  });

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
          impliedBy: record.impliedBy,
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
    impliedBy: row.impliedBy,
  );

  // --- Interne -------------------------------------------------------------

  SimpleSelectStatement<$NodesTable, NodeRow> _nodesQuery() =>
      _db.select(_db.nodes)..orderBy([
        (n) => OrderingTerm.asc(n.sortIndex),
        (n) => OrderingTerm.asc(n.createdAt),
      ]);

  SimpleSelectStatement<$ItemsTable, ItemRow> _itemsQuery({String? nodeId}) {
    final query = _db.select(_db.items)
      ..orderBy([
        (i) => OrderingTerm.asc(i.sortIndex),
        (i) => OrderingTerm.asc(i.createdAt),
      ]);
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
      _db.select(_db.documents)
        ..orderBy([(d) => OrderingTerm.asc(d.title.lower())]);

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

  SimpleSelectStatement<$NotesTable, NoteRow> _notesQuery({
    String? documentId,
    String? itemId,
  }) {
    final query = _db.select(_db.notes)
      ..orderBy([
        (n) => OrderingTerm.asc(n.page),
        (n) => OrderingTerm.asc(n.createdAt),
      ]);
    if (documentId != null) query.where((n) => n.documentId.equals(documentId));
    if (itemId != null) query.where((n) => n.itemId.equals(itemId));
    return query;
  }

  static Note _toNote(NoteRow row) => Note(
    id: row.id,
    body: row.body,
    documentId: row.documentId,
    page: row.page,
    startMs: row.startMs,
    endMs: row.endMs,
    region:
        row.left == null ||
            row.top == null ||
            row.right == null ||
            row.bottom == null
        ? null
        : NormalizedRect(row.left!, row.top!, row.right!, row.bottom!),
    snapshot: row.snapshot,
    itemId: row.itemId,
    ink: row.ink == null ? null : InkDrawing.decode(row.ink!),
    reviewRating: row.reviewRating,
    createdAt: row.createdAt.toUtc(),
    updatedAt: row.updatedAt.toUtc(),
  );

  static NoteRow _noteRow(Note n) => NoteRow(
    id: n.id,
    body: n.body,
    documentId: n.documentId,
    page: n.page,
    startMs: n.startMs,
    endMs: n.endMs,
    left: n.region?.left,
    top: n.region?.top,
    right: n.region?.right,
    bottom: n.region?.bottom,
    snapshot: n.snapshot,
    itemId: n.itemId,
    ink: n.ink == null || n.ink!.isEmpty ? null : n.ink!.encode(),
    reviewRating: n.reviewRating,
    createdAt: n.createdAt.toUtc(),
    updatedAt: n.updatedAt.toUtc(),
  );

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
    kind: row.kind,
    url: row.url,
    pageCount: row.pageCount,
    contentHash: row.contentHash,
    importedAt: row.importedAt.toUtc(),
    version: row.version,
    fingerprints: _unpackFingerprints(row.fingerprints, row.pageCount),
    newPages: (jsonDecode(row.newPages) as List).cast<int>(),
    lastPage: row.lastPage,
  );

  static Anchor _toAnchor(AnchorRow row) => Anchor(
    id: row.id,
    itemId: row.itemId,
    documentId: row.documentId,
    role: row.role,
    page: row.page,
    startMs: row.startMs,
    endMs: row.endMs,
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
    startMs: a.startMs,
    endMs: a.endMs,
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
    level: row.level,
    autoExercise: row.autoExercise,
    sortIndex: row.sortIndex,
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
        level: Value(item.level),
        autoExercise: Value(item.autoExercise),
        sortIndex: Value(item.sortIndex),
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
