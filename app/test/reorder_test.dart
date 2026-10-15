import 'package:flutter_test/flutter_test.dart';
import 'package:verger/features/items/item_tile.dart';
import 'package:verger/features/trees/reorder.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'test_app.dart';

/// Fait glisser la poignée située dans [from] jusqu'au point [to].
Future<void> dragHandle(WidgetTester tester, Finder from, Offset to) async {
  final handle = find.descendant(
    of: from,
    matching: find.byType(TreeDragHandle),
  );
  final gesture = await tester.startGesture(tester.getCenter(handle.first));
  await tester.pump();
  // Plusieurs étapes : le glisser démarre puis survole la cible.
  final start = tester.getCenter(handle.first);
  for (var k = 1; k <= 8; k++) {
    await gesture.moveTo(Offset.lerp(start, to, k / 8)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await settle(tester);
}

Future<List<String>> titlesIn(
  WidgetTester tester,
  VergerStore store,
  String nodeId,
) async => [
  for (final i in (await tester.runAsync(store.allItems))!)
    if (i.nodeId == nodeId) i.title,
];

void main() {
  testWidgets('glisser-déposer : connaissances et branches (#7)', (
    tester,
  ) async {
    late KnowledgeNode tree, a, b;
    final store = await pumpTestApp(
      tester,
      seed: (s) async {
        tree = await s.createNode(title: 'Algèbre');
        a = await s.createNode(title: 'Groupes', parentId: tree.id);
        b = await s.createNode(title: 'Anneaux', parentId: tree.id);
        for (final t in ['x', 'y', 'z']) {
          await s.createItem(
            nodeId: tree.id,
            kind: ItemKind.definition,
            title: t,
          );
        }
      },
    );
    await tester.tap(find.text('Arbres'));
    await settle(tester);

    // « z » déposée sur le haut de « x » : elle passe en tête.
    final x = find.widgetWithText(ItemTile, 'x');
    await dragHandle(
      tester,
      find.widgetWithText(ItemTile, 'z'),
      tester.getTopLeft(x) + const Offset(200, 4),
    );
    expect(await titlesIn(tester, store, tree.id), ['z', 'x', 'y']);

    // « y » déposée sur la branche « Anneaux » du plan : elle y part.
    final outlineB = find.text('Anneaux').first;
    await dragHandle(
      tester,
      find.widgetWithText(ItemTile, 'y'),
      tester.getCenter(outlineB),
    );
    expect(await titlesIn(tester, store, tree.id), ['z', 'x']);
    expect(await titlesIn(tester, store, b.id), ['y']);

    // « Anneaux » glissée sur le haut de « Groupes » : avant elle.
    final rowA = find.ancestor(
      of: find.text('Groupes').first,
      matching: find.byType(TreeDropTarget),
    );
    final rowB = find.ancestor(
      of: find.text('Anneaux').first,
      matching: find.byType(TreeDropTarget),
    );
    await dragHandle(
      tester,
      rowB.first,
      tester.getTopLeft(rowA.first) + const Offset(100, 2),
    );
    final nodes =
        (await tester.runAsync(
            store.allNodes,
          ))!.where((n) => n.parentId == tree.id).toList()
          ..sort((p, q) => p.sortIndex.compareTo(q.sortIndex));
    expect(nodes.map((n) => n.title), ['Anneaux', 'Groupes']);

    // « Groupes » déposée au milieu de « Anneaux » : elle devient sa
    // sous-branche ; l'inverse (dans sa propre descendance) est refusé.
    await dragHandle(
      tester,
      find
          .ancestor(
            of: find.text('Groupes').first,
            matching: find.byType(TreeDropTarget),
          )
          .first,
      tester.getCenter(
        find
            .ancestor(
              of: find.text('Anneaux').first,
              matching: find.byType(TreeDropTarget),
            )
            .first,
      ),
    );
    expect((await tester.runAsync(() => store.node(a.id)))!.parentId, b.id);

    // « Anneaux » sur sa sous-branche « Groupes » (dépliée) : refusé.
    Finder row(String title) => find
        .ancestor(
          of: find.text(title).first,
          matching: find.byType(TreeDropTarget),
        )
        .first;
    await dragHandle(tester, row('Anneaux'), tester.getCenter(row('Groupes')));
    expect((await tester.runAsync(() => store.node(b.id)))!.parentId, tree.id);
    expect((await tester.runAsync(() => store.node(a.id)))!.parentId, b.id);
    await unmountTestApp(tester);
  });
}
