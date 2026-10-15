import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:test/test.dart';
import 'package:verger_data/verger_data.dart';

import 'generated/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('le schéma obtenu par migration est celui attendu', () {
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      for (final toVersion in versions.skip(i + 1)) {
        test('v$fromVersion → v$toVersion', () async {
          final schema = await verifier.schemaAt(fromVersion);
          final db = VergerDatabase(schema.newConnection());
          await verifier.migrateAndValidate(db, toVersion);
          await db.close();
        });
      }
    }
  });

  test('v1 → v2 conserve les données existantes', () async {
    final schema = await verifier.schemaAt(1);
    // Données écrites avec le schéma v1 (format des dates : texte ISO-8601).
    schema.rawDatabase.execute(
      "INSERT INTO nodes (id, parent_id, title, sort_index, curriculum_key, "
      "origin, created_at) VALUES ('n1', NULL, 'Algèbre', 0, NULL, 'user', "
      "'2026-03-02T09:00:00.000Z')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO items (id, node_id, kind, title, body, suspended, "
      "created_at, updated_at, phase, step, stability, difficulty, due, "
      "last_review, reps, lapses) VALUES ('i1', 'n1', 'theorem', "
      "'Cayley-Hamilton', NULL, 0, '2026-03-02T09:00:00.000Z', "
      "'2026-03-02T09:00:00.000Z', 'review', NULL, 12.5, 4.2, "
      "'2026-03-14T09:00:00.000Z', '2026-03-02T09:00:00.000Z', 3, 0)",
    );

    final store = VergerStore(VergerDatabase(schema.newConnection()));
    final item = (await store.item('i1'))!;
    expect(item.title, 'Cayley-Hamilton');
    expect(item.scheduling.stability, 12.5);
    expect(item.scheduling.due, DateTime.utc(2026, 3, 14, 9));
    expect((await store.allNodes()).single.title, 'Algèbre');
    expect(await store.allDocuments(), isEmpty);
    expect(await store.anchorsOf('i1'), isEmpty);
    await store.close();
  });

  test('v2 → v3 conserve documents et ancres, ajoute les notes', () async {
    final schema = await verifier.schemaAt(2);
    final db = schema.rawDatabase;
    db.execute(
      "INSERT INTO nodes (id, parent_id, title, sort_index, curriculum_key, "
      "origin, created_at) VALUES ('n1', NULL, 'Algèbre', 0, NULL, 'user', "
      "'2026-03-02T09:00:00.000Z')",
    );
    db.execute(
      "INSERT INTO items (id, node_id, kind, title, body, suspended, "
      "created_at, updated_at, phase, step, stability, difficulty, due, "
      "last_review, reps, lapses) VALUES ('i1', 'n1', 'theorem', 'CH', NULL, "
      "0, '2026-03-02T09:00:00.000Z', '2026-03-02T09:00:00.000Z', 'new', "
      "NULL, NULL, NULL, NULL, NULL, 0, 0)",
    );
    db.execute(
      "INSERT INTO documents (id, title, role, page_count, content_hash, "
      "imported_at, version, fingerprints, new_pages) VALUES ('d1', "
      "'Carnet', 'notes', 2, 'h', '2026-03-02T09:00:00.000Z', 3, x'0000', "
      "'[2]')",
    );
    db.execute(
      "INSERT INTO anchors (id, item_id, document_id, role, page, "
      "needs_review, created_at) VALUES ('a1', 'i1', 'd1', 'work', 2, 0, "
      "'2026-03-02T09:00:00.000Z')",
    );

    final store = VergerStore(VergerDatabase(schema.newConnection()));
    final doc = (await store.document('d1'))!;
    expect((doc.title, doc.version, doc.lastPage), ('Carnet', 3, 1));
    expect(doc.newPages, [2]);
    expect((await store.anchorsOf('i1')).single.page, 2);
    final note = await store.createNote(body: 'ok', documentId: 'd1');
    expect((await store.note(note.id))!.body, 'ok');
    await store.close();
  });
}
