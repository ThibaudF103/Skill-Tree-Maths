import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:verger/data/pack_file.dart';
import 'package:verger_core/verger_core.dart';

void main() {
  final t = DateTime.utc(2026, 3, 2);
  final archive = VergerArchive(
    nodes: [
      KnowledgeNode(id: 'n', title: 'Analyse', sortIndex: 0, createdAt: t),
    ],
    items: const [],
    documents: [
      SourceDocument(
        id: 'inclus',
        title: 'Poly',
        pageCount: 1,
        contentHash: 'h1',
        importedAt: t,
      ),
      SourceDocument(
        id: 'reference',
        title: 'Poly en ligne',
        url: 'https://exemple.fr/p.pdf',
        pageCount: 1,
        contentHash: 'h2',
        importedAt: t,
      ),
    ],
    resourceLinks: const [
      (documentId: 'inclus', nodeId: 'n'),
      (documentId: 'reference', nodeId: 'n'),
    ],
    title: 'Analyse',
  );

  test('aller-retour : manifeste et PDF inclus', () {
    final bytes = PackFile.encode(archive, {
      'inclus': Uint8List.fromList([1, 2, 3]),
    });
    final (copy, pdfs) = PackFile.decode(bytes);
    expect(copy.title, 'Analyse');
    expect(copy.documents, hasLength(2));
    expect(copy.resourceLinks, hasLength(2));
    expect(pdfs.keys, ['inclus']);
    expect(pdfs['inclus'], [1, 2, 3]);
  });

  test('fichier étranger ou incomplet refusé', () {
    expect(
      () => PackFile.decode(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<ArchiveFormatException>()),
    );
  });
}
