import 'package:drift/drift.dart';
import 'package:verger_core/verger_core.dart';

import 'database.steps.dart';

part 'database.g.dart';

/// Structure des connaissances. Un nœud sans parent est un arbre du verger.
@DataClassName('NodeRow')
@TableIndex(name: 'nodes_parent', columns: {#parentId})
class Nodes extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable().references(Nodes, #id)();
  TextColumn get title => text()();
  IntColumn get sortIndex => integer()();
  TextColumn get curriculumKey => text().nullable()();
  TextColumn get origin => textEnum<NodeOrigin>()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Connaissances personnelles et leur état d'ordonnancement (aplati pour
/// pouvoir filtrer et trier sur l'échéance).
@DataClassName('ItemRow')
@TableIndex(name: 'items_node', columns: {#nodeId})
@TableIndex(name: 'items_due', columns: {#due})
class Items extends Table {
  TextColumn get id => text()();
  TextColumn get nodeId => text().references(Nodes, #id)();
  TextColumn get kind => textEnum<ItemKind>()();
  TextColumn get title => text()();
  TextColumn get body => text().nullable()();
  TextColumn get level => textEnum<ExerciseLevel>().nullable()();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();
  BoolColumn get suspended => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  TextColumn get phase => textEnum<LearningPhase>()();
  IntColumn get step => integer().nullable()();
  RealColumn get stability => real().nullable()();
  RealColumn get difficulty => real().nullable()();
  DateTimeColumn get due => dateTime().nullable()();
  DateTimeColumn get lastReview => dateTime().nullable()();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Historique des révisions, en ajout seul.
@DataClassName('ReviewLogRow')
@TableIndex(name: 'review_logs_item', columns: {#itemId})
class ReviewLogs extends Table {
  TextColumn get id => text()();
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get reviewedAt => dateTime()();
  TextColumn get rating => textEnum<Rating>()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get schedulerId => text()();

  /// États avant/après (JSON de `SchedulingState`).
  TextColumn get stateBefore => text()();
  TextColumn get stateAfter => text()();

  /// Révision implicite : connaissance réussie qui s'appuie sur celle-ci
  /// (v7). Sans clé étrangère : la trace survit à sa suppression.
  TextColumn get impliedBy => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Contenus pédagogiques : PDF importés (le fichier est dans
/// [DocumentFiles]) ou vidéos (adresse seule).
@DataClassName('DocumentRow')
class Documents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();

  /// Nature du contenu (v5, remplace le rôle cours / notes).
  TextColumn get kind =>
      textEnum<ResourceKind>().withDefault(const Constant('pdf'))();

  /// Adresse d'origine : vidéo, ou PDF téléchargeable (v5).
  TextColumn get url => text().nullable()();
  IntColumn get pageCount => integer()();
  TextColumn get contentHash => text()();
  DateTimeColumn get importedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  /// Empreintes des pages, concaténées (pageCount × fingerprintSide²).
  BlobColumn get fingerprints => blob()();

  /// Pages apparues à la dernière mise à jour (JSON : liste d'entiers).
  TextColumn get newPages => text().withDefault(const Constant('[]'))();

  /// Dernière page consultée (v3).
  IntColumn get lastPage => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Contenu des PDF, séparé pour ne pas le charger en listant les documents.
@DataClassName('DocumentFileRow')
class DocumentFiles extends Table {
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.cascade)();
  BlobColumn get bytes => blob()();

  @override
  Set<Column> get primaryKey => {documentId};
}

/// Rattachement des contenus aux nœuds (v5).
@DataClassName('ResourceLinkRow')
@TableIndex(name: 'resource_links_node', columns: {#nodeId})
class ResourceLinks extends Table {
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.cascade)();
  TextColumn get nodeId =>
      text().references(Nodes, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {documentId, nodeId};
}

/// Prérequis entre connaissances : [itemId] s'appuie sur [requiresId] (v6).
/// Le graphe reste sans cycle (vérifié par le magasin).
@DataClassName('PrerequisiteRow')
@TableIndex(name: 'prerequisites_requires', columns: {#requiresId})
class Prerequisites extends Table {
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();
  TextColumn get requiresId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {itemId, requiresId};
}

/// Liens connaissance ↔ endroit d'un contenu : zone d'une page de PDF, ou
/// extrait de vidéo (v5).
@DataClassName('AnchorRow')
@TableIndex(name: 'anchors_item', columns: {#itemId})
@TableIndex(name: 'anchors_document', columns: {#documentId})
class Anchors extends Table {
  TextColumn get id => text()();
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => textEnum<AnchorRole>()();

  /// Page d'un PDF (nulle pour une vidéo depuis v5).
  IntColumn get page => integer().nullable()();

  /// Extrait d'une vidéo, en millisecondes (v5).
  IntColumn get startMs => integer().nullable()();
  IntColumn get endMs => integer().nullable()();
  RealColumn get left => real().nullable()();
  RealColumn get top => real().nullable()();
  RealColumn get right => real().nullable()();
  RealColumn get bottom => real().nullable()();
  TextColumn get textSnippet => text().nullable()();
  BlobColumn get snapshot => blob().nullable()();
  BoolColumn get needsReview => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Notes de travail (v3). Les liens vers le PDF et la connaissance sont
/// retirés (pas la note) si ceux-ci sont supprimés.
@DataClassName('NoteRow')
@TableIndex(name: 'notes_document', columns: {#documentId})
@TableIndex(name: 'notes_item', columns: {#itemId})
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get body => text()();
  TextColumn get documentId => text().nullable().references(
    Documents,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get page => integer().nullable()();

  /// Moment ou extrait d'une vidéo, en millisecondes (v5).
  IntColumn get startMs => integer().nullable()();
  IntColumn get endMs => integer().nullable()();
  RealColumn get left => real().nullable()();
  RealColumn get top => real().nullable()();
  RealColumn get right => real().nullable()();
  RealColumn get bottom => real().nullable()();
  BlobColumn get snapshot => blob().nullable()();
  TextColumn get itemId =>
      text().nullable().references(Items, #id, onDelete: KeyAction.setNull)();

  /// Écriture manuscrite, JSON de `Ink` (v8).
  TextColumn get ink => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Réglages clé → valeur JSON.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Nodes,
    Items,
    ReviewLogs,
    Settings,
    Documents,
    DocumentFiles,
    Anchors,
    Notes,
    ResourceLinks,
    Prerequisites,
  ],
)
class VergerDatabase extends _$VergerDatabase {
  VergerDatabase(super.executor);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Migrations version par version, sur le schéma exact de chaque version
    // (database.steps.dart, généré par `drift_dev make-migrations`).
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        // v2 : PDF et ancres recto/verso.
        await m.createTable(schema.documents);
        await m.createTable(schema.documentFiles);
        await m.createTable(schema.anchors);
        await m.createIndex(schema.anchorsItem);
        await m.createIndex(schema.anchorsDocument);
      },
      from2To3: (m, schema) async {
        // v3 : notes de travail, reprise de lecture.
        await m.addColumn(schema.documents, schema.documents.lastPage);
        await m.createTable(schema.notes);
        await m.createIndex(schema.notesDocument);
        await m.createIndex(schema.notesItem);
      },
      from3To4: (m, schema) async {
        // v4 : difficulté des exercices, ordre manuel des connaissances
        // (0 partout : l'ordre de création départage, rien ne bouge).
        await m.addColumn(schema.items, schema.items.level);
        await m.addColumn(schema.items, schema.items.sortIndex);
      },
      from4To5: (m, schema) async {
        // v5 : contenus (PDF ou vidéo) rattachés aux nœuds ; ancres et notes
        // vers un extrait de vidéo. Le rôle cours / notes disparaît.
        await m.alterTable(
          TableMigration(
            schema.documents,
            newColumns: [schema.documents.kind, schema.documents.url],
          ),
        );
        await m.alterTable(
          TableMigration(
            schema.anchors,
            newColumns: [schema.anchors.startMs, schema.anchors.endMs],
          ),
        );
        await m.addColumn(schema.notes, schema.notes.startMs);
        await m.addColumn(schema.notes, schema.notes.endMs);
        await m.createTable(schema.resourceLinks);
        await m.createIndex(schema.resourceLinksNode);
        // Chaque PDF existant est rattaché aux arbres des connaissances qui
        // l'utilisent déjà.
        await customStatement('''
          WITH RECURSIVE up(id, root) AS (
            SELECT id, id FROM nodes WHERE parent_id IS NULL
            UNION ALL
            SELECT n.id, up.root FROM nodes n JOIN up ON n.parent_id = up.id
          )
          INSERT OR IGNORE INTO resource_links (document_id, node_id)
          SELECT DISTINCT a.document_id, up.root
          FROM anchors a
          JOIN items i ON i.id = a.item_id
          JOIN up ON up.id = i.node_id
        ''');
      },
      from5To6: (m, schema) async {
        // v6 : prérequis entre connaissances.
        await m.createTable(schema.prerequisites);
        await m.createIndex(schema.prerequisitesRequires);
      },
      from6To7: (m, schema) async {
        // v7 : révisions implicites (via une connaissance qui s'appuie
        // sur celle révisée).
        await m.addColumn(schema.reviewLogs, schema.reviewLogs.impliedBy);
      },
      from7To8: (m, schema) async {
        // v8 : écriture manuscrite des notes.
        await m.addColumn(schema.notes, schema.notes.ink);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
