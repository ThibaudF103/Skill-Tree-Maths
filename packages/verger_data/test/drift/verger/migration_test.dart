import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';
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

  test('v3 → v4 : ordre des connaissances inchangé, difficulté vide', () async {
    final schema = await verifier.schemaAt(3);
    final db = schema.rawDatabase;
    db.execute(
      "INSERT INTO nodes (id, parent_id, title, sort_index, curriculum_key, "
      "origin, created_at) VALUES ('n1', NULL, 'Algèbre', 0, NULL, 'user', "
      "'2026-03-02T09:00:00.000Z')",
    );
    for (final (id, minute) in [('b', 1), ('a', 2), ('c', 3)]) {
      db.execute(
        "INSERT INTO items (id, node_id, kind, title, body, suspended, "
        "created_at, updated_at, phase, step, stability, difficulty, due, "
        "last_review, reps, lapses) VALUES ('$id', 'n1', 'exercise', '$id', "
        "NULL, 0, '2026-03-02T09:0$minute:00.000Z', "
        "'2026-03-02T09:00:00.000Z', 'newItem', NULL, NULL, NULL, NULL, NULL, "
        "0, 0)",
      );
    }

    final store = VergerStore(VergerDatabase(schema.newConnection()));
    final items = await store.allItems();
    expect(items.map((i) => i.id), ['b', 'a', 'c']);
    expect(items.every((i) => i.level == null), isTrue);
    final added = await store.createItem(
      nodeId: 'n1',
      kind: ItemKind.exercise,
      title: 'd',
      level: ExerciseLevel.hard,
    );
    expect(added.sortIndex, 1);
    expect((await store.allItems()).last.level, ExerciseLevel.hard);
    await store.close();
  });

  test('v4 → v5 : PDF rattachés à leurs arbres, ancres conservées', () async {
    final schema = await verifier.schemaAt(4);
    final db = schema.rawDatabase;
    db.execute(
      "INSERT INTO nodes (id, parent_id, title, sort_index, curriculum_key, "
      "origin, created_at) VALUES ('t', NULL, 'Analyse', 0, NULL, 'user', "
      "'2026-03-02T09:00:00.000Z'), ('b', 't', 'Suites', 0, NULL, 'user', "
      "'2026-03-02T09:00:00.000Z')",
    );
    db.execute(
      "INSERT INTO items (id, node_id, kind, title, body, level, sort_index, "
      "suspended, created_at, updated_at, phase, step, stability, difficulty, "
      "due, last_review, reps, lapses) VALUES ('i', 'b', 'theorem', 'Cesàro', "
      "NULL, NULL, 0, 0, '2026-03-02T09:00:00.000Z', "
      "'2026-03-02T09:00:00.000Z', 'newItem', NULL, NULL, NULL, NULL, NULL, "
      "0, 0)",
    );
    db.execute(
      "INSERT INTO documents (id, title, role, page_count, content_hash, "
      "imported_at, version, fingerprints, new_pages, last_page) VALUES "
      "('d', 'Poly', 'notes', 2, 'h', '2026-03-02T09:00:00.000Z', 1, "
      "x'0000', '[]', 2)",
    );
    db.execute(
      "INSERT INTO anchors (id, item_id, document_id, role, page, "
      "needs_review, created_at) VALUES ('a', 'i', 'd', 'source', 2, 0, "
      "'2026-03-02T09:00:00.000Z')",
    );

    final store = VergerStore(VergerDatabase(schema.newConnection()));
    final doc = (await store.document('d'))!;
    expect((doc.title, doc.kind, doc.lastPage), ('Poly', ResourceKind.pdf, 2));
    expect((await store.anchorsOf('i')).single.page, 2);
    // Rattaché à l'arbre de la connaissance qui l'utilise.
    expect(await store.resourceLinks(), [(documentId: 'd', nodeId: 't')]);
    await store.close();
  });
  test('v5 → v6 : connaissances conservées, prérequis disponibles', () async {
    final schema = await verifier.schemaAt(5);
    final db = schema.rawDatabase;
    db.execute(
      "INSERT INTO nodes (id, parent_id, title, sort_index, curriculum_key, "
      "origin, created_at) VALUES ('n1', NULL, 'Analyse', 0, NULL, 'user', "
      "'2026-03-02T09:00:00.000Z')",
    );
    for (final (id, kind) in [('d', 'definition'), ('t', 'theorem')]) {
      db.execute(
        "INSERT INTO items (id, node_id, kind, title, body, level, "
        "sort_index, suspended, created_at, updated_at, phase, step, "
        "stability, difficulty, due, last_review, reps, lapses) VALUES "
        "('$id', 'n1', '$kind', '$id', NULL, NULL, 0, 0, "
        "'2026-03-02T09:00:00.000Z', '2026-03-02T09:00:00.000Z', 'newItem', "
        "NULL, NULL, NULL, NULL, NULL, 0, 0)",
      );
    }

    final store = VergerStore(VergerDatabase(schema.newConnection()));
    expect((await store.allItems()).map((i) => i.id), ['d', 't']);
    expect(await store.prerequisites(), isEmpty);
    await store.addPrerequisite('t', 'd');
    expect(await store.prerequisites(), [(itemId: 't', requiresId: 'd')]);
    await store.deleteItem('d');
    expect(await store.prerequisites(), isEmpty);
    await store.close();
  });

  test('v6 → v7 : historique conservé, révisions implicites tracées', () async {
    final schema = await verifier.schemaAt(6);
    final db = schema.rawDatabase;
    final state = jsonEncode(SchedulingState.initial.toJson());
    db.execute(
      "INSERT INTO nodes (id, parent_id, title, sort_index, curriculum_key, "
      "origin, created_at) VALUES ('n1', NULL, 'Analyse', 0, NULL, 'user', "
      "'2026-03-02T09:00:00.000Z')",
    );
    for (final id in ['d', 't']) {
      db.execute(
        "INSERT INTO items (id, node_id, kind, title, body, level, "
        "sort_index, suspended, created_at, updated_at, phase, step, "
        "stability, difficulty, due, last_review, reps, lapses) VALUES "
        "('$id', 'n1', 'theorem', '$id', NULL, NULL, 0, 0, "
        "'2026-03-02T09:00:00.000Z', '2026-03-02T09:00:00.000Z', 'newItem', "
        "NULL, NULL, NULL, NULL, NULL, 0, 0)",
      );
    }
    db.execute(
      "INSERT INTO review_logs (id, item_id, reviewed_at, rating, "
      "duration_ms, scheduler_id, state_before, state_after) VALUES "
      "('r1', 'd', '2026-03-02T10:00:00.000Z', 'good', NULL, 'fsrs', "
      "'$state', '$state')",
    );

    final store = VergerStore(VergerDatabase(schema.newConnection()));
    final old = await store.history('d');
    expect(old.single.rating, Rating.good);
    expect(old.single.impliedBy, equals(null));
    final item = (await store.item('d'))!;
    await store.applyReview(
      'd',
      ReviewRecord(
        rating: Rating.good,
        reviewedAt: DateTime.utc(2026, 3, 3),
        before: item.scheduling,
        after: item.scheduling,
        schedulerId: 'fsrs',
        impliedBy: 't',
      ),
    );
    expect((await store.history('d')).last.impliedBy, 't');
    await store.close();
  });

  test('v7 → v8 : notes conservées, écriture manuscrite disponible', () async {
    final schema = await verifier.schemaAt(7);
    final db = schema.rawDatabase;
    db.execute(
      "INSERT INTO notes (id, body, document_id, page, start_ms, end_ms, "
      "\"left\", top, \"right\", bottom, snapshot, item_id, created_at, "
      "updated_at) VALUES ('n1', 'Texte', NULL, NULL, NULL, NULL, NULL, NULL, "
      "NULL, NULL, NULL, NULL, '2026-03-02T09:00:00.000Z', "
      "'2026-03-02T09:00:00.000Z')",
    );

    final store = VergerStore(VergerDatabase(schema.newConnection()));
    final old = (await store.note('n1'))!;
    expect(old.body, 'Texte');
    expect(old.ink, equals(null));
    await store.updateNote(
      'n1',
      ink: InkDrawing([
        InkStroke(points: [(x: 1, y: 2, pressure: 0.5)], color: 0, width: 1),
      ]),
    );
    expect((await store.note('n1'))!.ink!.strokes, hasLength(1));
    await store.close();
  });
}
