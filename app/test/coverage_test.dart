import 'package:flutter_test/flutter_test.dart';
import 'package:verger/ui/coverage.dart';
import 'package:verger_core/verger_core.dart';

void main() {
  final t = DateTime.utc(2026, 3, 2);
  Anchor anchor(String id, AnchorRole role, {int? page, int? start}) => Anchor(
    id: id,
    itemId: 'i',
    documentId: 'd',
    role: role,
    page: page,
    startMs: start,
    endMs: start == null ? null : start + 1000,
    createdAt: t,
  );

  test('couverture par page : recto, verso, notes', () {
    final coverage = pageCoverage(
      [
        anchor('a', AnchorRole.source, page: 2),
        anchor('b', AnchorRole.source, page: 2),
        anchor('c', AnchorRole.work, page: 5),
        anchor('v', AnchorRole.work, start: 1000), // vidéo : ignorée
      ],
      [
        Note(id: 'n', body: '', page: 5, createdAt: t, updatedAt: t),
        Note(id: 'm', body: '', createdAt: t, updatedAt: t),
      ],
    );
    expect(coverage.keys, unorderedEquals([2, 5]));
    expect(coverage[2], (recto: 2, verso: 0, notes: 0));
    expect(coverage[5], (recto: 0, verso: 1, notes: 1));
  });

  test('frise d\'une vidéo : extraits et notes triés', () {
    final spans = videoCoverage(
      [
        anchor('b', AnchorRole.work, start: 60000),
        anchor('a', AnchorRole.source, start: 1000),
        anchor('p', AnchorRole.source, page: 1), // PDF : ignoré
      ],
      [Note(id: 'n', body: '', startMs: 30000, createdAt: t, updatedAt: t)],
      titles: {'i': 'Pythagore'},
    );
    expect(spans.map((s) => s.start), [1000, 30000, 60000]);
    expect(spans[1].role, isNull);
    expect(spans.map((s) => s.label), ['Pythagore', 'Note', 'Pythagore']);
    expect(spans[1].id, 'n');
  });
}
