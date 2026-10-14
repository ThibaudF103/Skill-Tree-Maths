import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/features/orchard/orchard_page.dart';
import 'package:verger_core/verger_core.dart';

import 'test_app.dart';

void main() {
  testWidgets('verger : un arbre par domaine, puis vue rapprochée', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      seed: (store) async {
        final algebre = await store.createNode(title: 'Algèbre');
        final reduction = await store.createNode(
          title: 'Réduction',
          parentId: algebre.id,
        );
        await store.createItem(
          nodeId: reduction.id,
          kind: ItemKind.theorem,
          title: 'Cayley-Hamilton',
        );
        await store.createNode(title: 'Analyse');
      },
    );

    expect(find.text('Algèbre'), findsOneWidget);
    expect(find.text('Analyse'), findsOneWidget);
    expect(find.textContaining('1 connaissance'), findsOneWidget);
    expect(find.text('Hiver : aucune connaissance'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    await tester.tap(find.text('Algèbre'));
    await settle(tester);
    expect(find.byType(OrchardFocusPage), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await unmountTestApp(tester);
  });
}
