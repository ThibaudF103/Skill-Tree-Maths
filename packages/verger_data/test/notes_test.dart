import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late VergerStore store;
  late KnowledgeItem item;
  late SourceDocument course;
  var now = DateTime.utc(2026, 3, 2, 9);

  setUp(() async {
    now = DateTime.utc(2026, 3, 2, 9);
    store = VergerStore(
      VergerDatabase(NativeDatabase.memory()),
      clock: () => now,
    );
    final node = await store.createNode(title: 'Réduction');
    item = await store.createItem(
      nodeId: node.id,
      kind: ItemKind.theorem,
      title: 'Cayley-Hamilton',
    );
    course = await store.importDocument(
      title: 'Algèbre.pdf',
      bytes: Uint8List.fromList([1]),
      contentHash: 'c',
      fingerprints: [Uint8List(4), Uint8List(4), Uint8List(4)],
    );
  });
  tearDown(() => store.close());

  test('créer, lire, modifier, lier, supprimer une note', () async {
    final note = await store.createNote(
      body: r'Preuve : $\chi_u(u) = 0$ par densité.',
      documentId: course.id,
      page: 2,
      region: const NormalizedRect(0.1, 0.2, 0.9, 0.5),
      snapshot: Uint8List.fromList([137, 80]),
    );
    var stored = (await store.note(note.id))!;
    expect(stored.page, 2);
    expect(stored.region, const NormalizedRect(0.1, 0.2, 0.9, 0.5));
    expect(stored.snapshot, [137, 80]);
    expect(stored.itemId, isNull);

    now = now.add(const Duration(minutes: 5));
    await store.updateNote(note.id, body: 'Version 2', itemId: () => item.id);
    stored = (await store.note(note.id))!;
    expect(stored.body, 'Version 2');
    expect(stored.itemId, item.id);
    expect(stored.updatedAt, now);
    expect(stored.createdAt, note.createdAt);
    expect((await store.notes(itemId: item.id)).single.id, note.id);

    await store.updateNote(note.id, itemId: () => null);
    expect(await store.notes(itemId: item.id), isEmpty);

    await store.deleteNote(note.id);
    expect(await store.note(note.id), isNull);
  });

  test('notes d\'un PDF triées par page', () async {
    await store.createNote(body: 'p3', documentId: course.id, page: 3);
    await store.createNote(body: 'p1', documentId: course.id, page: 1);
    await store.createNote(body: 'libre');
    final notes = await store.notes(documentId: course.id);
    expect(notes.map((n) => n.body), ['p1', 'p3']);
  });

  test(
    'la note survit à la suppression du PDF ou de la connaissance',
    () async {
      final note = await store.createNote(
        body: 'Ma rédaction',
        documentId: course.id,
        page: 1,
        itemId: item.id,
      );
      await store.deleteItem(item.id);
      var stored = (await store.note(note.id))!;
      expect(stored.itemId, isNull);
      expect(stored.documentId, course.id);

      await store.deleteDocument(course.id);
      stored = (await store.note(note.id))!;
      expect(stored.documentId, isNull);
      expect(stored.body, 'Ma rédaction');
    },
  );

  test('reprise de lecture : dernière page mémorisée', () async {
    expect((await store.document(course.id))!.lastPage, 1);
    await store.setLastPage(course.id, 3);
    expect((await store.document(course.id))!.lastPage, 3);
  });

  test('sauvegarde et restauration avec les notes', () async {
    await store.createNote(
      body: r'$$\int_0^1 f$$',
      documentId: course.id,
      page: 2,
      itemId: item.id,
      snapshot: Uint8List.fromList([7]),
    );
    await store.setLastPage(course.id, 2);
    final json = jsonEncode((await store.exportArchive()).toJson());

    final other = VergerStore(VergerDatabase(NativeDatabase.memory()));
    await other.restoreArchive(
      VergerArchive.fromJson((jsonDecode(json) as Map).cast()),
    );
    final note = (await other.notes(itemId: item.id)).single;
    expect(note.body, r'$$\int_0^1 f$$');
    expect(note.snapshot, [7]);
    expect((await other.document(course.id))!.lastPage, 2);

    // Restaurer par-dessus des données existantes remplace les notes.
    await store.createNote(body: 'à remplacer');
    await store.restoreArchive(
      VergerArchive.fromJson((jsonDecode(json) as Map).cast()),
    );
    expect((await store.notes()).map((n) => n.body), [r'$$\int_0^1 f$$']);
    await other.close();
  });

  test('mise à jour du PDF : les notes suivent leurs pages', () async {
    Uint8List page(int seed) {
      final pixels = Uint8List(fingerprintSide * fingerprintSide)
        ..fillRange(0, fingerprintSide * fingerprintSide, 250);
      for (var i = 0; i < 40; i++) {
        pixels[(seed * 97 + i * 31) % pixels.length] = 60;
      }
      return pixels;
    }

    final notes = await store.importDocument(
      title: 'Carnet',
      bytes: Uint8List(1),
      contentHash: 'v1',
      fingerprints: [page(1), page(2), page(3)],
    );
    final onPage3 = await store.createNote(
      body: 'p3',
      documentId: notes.id,
      page: 3,
    );
    final free = await store.createNote(body: 'libre', documentId: notes.id);
    // Deux pages insérées au début.
    await store.updateDocument(
      notes.id,
      bytes: Uint8List(1),
      contentHash: 'v2',
      fingerprints: [page(8), page(9), page(1), page(2), page(3)],
    );
    expect((await store.note(onPage3.id))!.page, 5);
    expect((await store.note(free.id))!.page, isNull);
  });

  test('watchNote suit les modifications et la suppression', () async {
    final note = await store.createNote(body: 'a');
    final values = <String?>[];
    final sub = store.watchNote(note.id).listen((n) => values.add(n?.body));
    await pumpEventQueue();
    await store.updateNote(note.id, body: 'b');
    await pumpEventQueue();
    await store.deleteNote(note.id);
    await pumpEventQueue();
    await sub.cancel();
    expect(values, ['a', 'b', null]);
  });

  test(
    'écriture manuscrite : enregistrée, modifiée, effacée, sauvegardée',
    () async {
      final ink = InkDrawing([
        InkStroke(
          points: [
            (x: 10, y: 20, pressure: 0.4),
            (x: 30, y: 25, pressure: 0.8),
          ],
          color: 0xFF000000,
          width: 2.5,
        ),
      ]);
      final note = await store.createNote(itemId: item.id, ink: ink);
      expect((await store.note(note.id))!.ink!.strokes, ink.strokes);
      expect((await store.note(note.id))!.isBlank, isFalse);

      // Modifier le texte ne touche pas à l'encre.
      await store.updateNote(note.id, body: 'Démonstration');
      expect((await store.note(note.id))!.ink!.strokes, hasLength(1));

      final archive = VergerArchive.fromJson(
        (await store.exportArchive()).toJson(),
      );
      final copy = VergerStore(VergerDatabase(NativeDatabase.memory()));
      await copy.restoreArchive(archive);
      expect((await copy.note(note.id))!.ink!.strokes, ink.strokes);
      await copy.close();

      // Encre vide : effacée.
      await store.updateNote(note.id, body: '', ink: InkDrawing.empty);
      final blank = (await store.note(note.id))!;
      expect(blank.ink, isNull);
      expect(blank.isBlank, isTrue);
    },
  );

  test('suppression d\'une note vide seulement', () async {
    final blank = await store.createNote(itemId: item.id);
    final written = await store.createNote(itemId: item.id, body: 'Texte');
    final zoned = await store.createNote(
      documentId: course.id,
      page: 1,
      region: const NormalizedRect(0.1, 0.1, 0.5, 0.5),
    );
    expect(await store.deleteNoteIfBlank(blank.id), isTrue);
    expect(await store.deleteNoteIfBlank(written.id), isFalse);
    expect(await store.deleteNoteIfBlank(zoned.id), isFalse);
    expect(await store.note(blank.id), isNull);
    expect(await store.note(written.id), isNotNull);
  });
}
