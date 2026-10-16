import 'package:flutter_test/flutter_test.dart';
import 'package:verger/features/skills/skill_layout.dart';
import 'package:verger_core/verger_core.dart';

Prerequisite p(String item, String requires) =>
    (itemId: item, requiresId: requires);

void main() {
  test('une colonne par niveau, dans l\'ordre du cours', () {
    final graph = PrerequisiteGraph([p('t', 'd1'), p('c', 't'), p('x', 'c')]);
    final layout = SkillLayout.of(['d1', 'd2', 't', 'c', 'x'], graph);
    expect(layout.columnCount, 4);
    expect(layout.cells['d1'], (column: 0, band: 0, row: 0));
    expect(layout.cells['d2'], (column: 0, band: 0, row: 1));
    expect(layout.cells['x'], (column: 3, band: 0, row: 0));
    expect(layout.rowCount, 2);
  });

  test('les barycentres évitent un croisement', () {
    // a → c et b → d, mais l'ordre de départ met d avant c.
    final graph = PrerequisiteGraph([p('c', 'a'), p('d', 'b')]);
    final layout = SkillLayout.of(['a', 'b', 'd', 'c'], graph);
    expect(layout.cells['c']!.row, layout.cells['a']!.row);
    expect(layout.cells['d']!.row, layout.cells['b']!.row);
  });

  test('graphe vide', () {
    final layout = SkillLayout.of([], PrerequisiteGraph([]));
    expect((layout.columnCount, layout.rowCount), (0, 0));
  });

  test('une bande par groupe, dans l\'ordre d\'apparition', () {
    final graph = PrerequisiteGraph([p('t', 'd'), p('e', 't'), p('f', 'd')]);
    final group = {'d': 'A', 't': 'A', 'e': 'B', 'f': 'B', 'g': 'A'};
    final layout = SkillLayout.of(
      ['d', 't', 'e', 'f', 'g'],
      graph,
      groupOf: (i) => group[i]!,
    );
    expect(layout.bands, [
      (group: 'A', rowCount: 2),
      (group: 'B', rowCount: 1),
    ]);
    expect(layout.cells['g'], (column: 0, band: 0, row: 1));
    expect(layout.cells['f'], (column: 1, band: 1, row: 0));
    expect(layout.cells['e'], (column: 2, band: 1, row: 0));
    expect(layout.rowCount, 3);
  });
}
