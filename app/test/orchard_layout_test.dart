import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:verger/orchard/orchard_layout.dart';
import 'package:verger_core/verger_core.dart';

SceneItem item(String id, {bool due = false}) => (
  id: id,
  family: ItemFamily.values[id.hashCode % 3],
  stage: GrowthStage.developed,
  isDue: due,
);

void main() {
  const size = Size(800, 600);
  final rect = Offset.zero & size;

  test('arbre en hiver : un tronc nu, rien d\'autre', () {
    final layout = layoutOrchard((
      id: 'a',
      branches: const [],
      items: const [],
    ), size);
    expect(layout.wood, hasLength(1));
    expect(layout.wood.single.bare, isTrue);
    expect(layout.glyphs, isEmpty);
    expect(layout.labels, isEmpty);
  });

  final scene = (
    id: 'algebre',
    branches: [
      (
        id: 'reduction',
        title: 'Réduction',
        twigs: 2,
        items: [for (var i = 0; i < 30; i++) item('r$i', due: i == 0)],
      ),
      (id: 'ev', title: 'Espaces vectoriels', twigs: 0, items: [item('e1')]),
      (id: 'vide', title: 'Formes bilinéaires', twigs: 0, items: <SceneItem>[]),
    ],
    items: [item('direct')],
  );

  test('branches, rameaux, connaissances et étiquettes', () {
    final layout = layoutOrchard(scene, size, maxGlyphsPerBranch: 18);
    // Tronc + 3 branches + 2 rameaux.
    expect(layout.wood, hasLength(6));
    expect(layout.wood.where((w) => w.bare), hasLength(1));
    expect(layout.labels.map((l) => l.text), [
      'Réduction',
      'Espaces vectoriels',
      'Formes bilinéaires',
    ]);
    final reduction = layout.labels.first;
    expect(reduction.isDue, isTrue);
    final shownReduction = layout.glyphs
        .where((g) => g.item.id.startsWith('r'))
        .length;
    expect(shownReduction, lessThanOrEqualTo(18));
    expect(reduction.hidden, 30 - shownReduction);
    expect(layout.glyphs.any((g) => g.item.id == 'direct'), isTrue);
    expect(layout.glyphs.any((g) => g.item.id == 'e1'), isTrue);
    for (final g in layout.glyphs) {
      expect(rect.contains(g.center), isTrue, reason: g.item.id);
    }
  });

  test('toucher : connaissance en priorité, sinon branche', () {
    final layout = layoutOrchard(scene, size);
    final glyph = layout.glyphs.firstWhere((g) => g.item.id == 'e1');
    expect(layout.hitTest(glyph.center)?.itemId, 'e1');

    final bare = layout.wood.firstWhere((w) => w.bare);
    final hit = layout.hitTest(Offset.lerp(bare.from, bare.to, 0.9)!);
    expect(hit?.branchId, 'vide');
    expect(layout.hitTest(const Offset(2, 2)), isNull);
  });

  test('même scène, même image', () {
    final a = layoutOrchard(scene, size);
    final b = layoutOrchard(scene, size);
    expect(
      a.glyphs.map((g) => g.center).toList(),
      b.glyphs.map((g) => g.center).toList(),
    );
    expect(a.wood.map((w) => w.to).toList(), b.wood.map((w) => w.to).toList());
  });

  test('rameau sans sous-branche : connaissances le long du bois', () {
    final layout = layoutOrchard((
      id: 'cayley',
      branches: const [],
      items: [for (var i = 0; i < 5; i++) item('c$i')],
    ), size);
    expect(layout.glyphs, hasLength(5));
    expect(layout.wood.single.bare, isFalse);
  });
}
