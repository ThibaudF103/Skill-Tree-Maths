import 'package:drift/drift.dart';
import 'package:verger_core/verger_core.dart';

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

  @override
  Set<Column> get primaryKey => {id};
}

/// PDF importés (métadonnées ; le contenu est dans [DocumentFiles]).
@DataClassName('DocumentRow')
class Documents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get role => textEnum<DocumentRole>()();
  IntColumn get pageCount => integer()();
  TextColumn get contentHash => text()();
  DateTimeColumn get importedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  /// Empreintes des pages, concaténées (pageCount × fingerprintSide²).
  BlobColumn get fingerprints => blob()();

  /// Pages apparues à la dernière mise à jour (JSON : liste d'entiers).
  TextColumn get newPages => text().withDefault(const Constant('[]'))();

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

/// Liens connaissance ↔ zone d'un PDF (recto : cours, verso : notes).
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
  IntColumn get page => integer()();
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
  ],
)
class VergerDatabase extends _$VergerDatabase {
  VergerDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v2 : PDF et ancres recto/verso.
        await m.createTable(documents);
        await m.createTable(documentFiles);
        await m.createTable(anchors);
        await m.createIndex(anchorsItem);
        await m.createIndex(anchorsDocument);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
