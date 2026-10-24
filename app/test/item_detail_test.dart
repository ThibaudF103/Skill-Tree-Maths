import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'test_app.dart';

Future<void> seed(VergerStore store) async {
  final tree = await store.createNode(title: 'Algèbre');
  final def = await store.createItem(
    nodeId: tree.id,
    kind: ItemKind.definition,
    title: 'Polynôme caractéristique',
  );
  final thm = await store.createItem(
    nodeId: tree.id,
    kind: ItemKind.theorem,
    title: 'Cayley-Hamilton',
  );
  await store.addPrerequisite(thm.id, def.id);
  final scheduler = const SchedulerSettings().build();
  await store.applyReview(
    thm.id,
    scheduler.record(
      thm.scheduling,
      Rating.good,
      DateTime.now(),
      fuzzKey: thm.id,
    ),
  );
  await store.createNote(body: r'Preuve par densité', itemId: thm.id);
}

void main() {
  testWidgets('fiche : les notes juste après le recto / verso', (tester) async {
    await pumpTestApp(tester, seed: seed);
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.text('Cayley-Hamilton'));
    await settle(tester);

    double top(String title) => tester.getTopLeft(find.text(title).first).dy;
    expect(top('Recto / verso'), lessThan(top('Notes')));
    expect(top('Notes'), lessThan(top('Prérequis')));
    expect(top('Prérequis'), lessThan(top('Progression')));
    await unmountTestApp(tester);
  });
}
