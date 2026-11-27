import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/features/board/board_canvas.dart';
import 'package:verger/features/items/item_detail_page.dart';
import 'package:verger/features/trees/trees_page.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'test_app.dart';

void main() {
  /// « Mécanique » > « Oscillateurs » (deux cartes) et « Optique ».
  Future<void> seed(VergerStore store) async {
    final meca = await store.createNode(title: 'Mécanique');
    final osc = await store.createNode(
      title: 'Oscillateurs',
      parentId: meca.id,
    );
    await store.createNode(title: 'Optique');
    await store.createItem(
      nodeId: osc.id,
      kind: ItemKind.definition,
      title: 'Oscillateur harmonique',
    );
    await store.createItem(
      nodeId: osc.id,
      kind: ItemKind.theorem,
      title: r'Résonance en $\omega_0$',
    );
  }

  Future<void> openBoard(WidgetTester tester) async {
    await tester.tap(find.text('Tableau'));
    await settle(tester);
  }

  testWidgets('régions et cartes tirées de l\'arbre, géométrie enregistrée', (
    tester,
  ) async {
    final store = await pumpTestApp(tester, seed: seed);
    await openBoard(tester);

    expect(find.text('Mécanique'), findsOneWidget);
    expect(find.text('Oscillateurs'), findsOneWidget);
    expect(find.text('Optique'), findsOneWidget);
    expect(find.byType(BoardCard), findsNWidgets(2));
    expect(find.text('Oscillateur harmonique'), findsOneWidget);
    expect(find.text('Recentrer'), findsOneWidget);

    // Première ouverture : la mise en page est enregistrée.
    final nodes = (await tester.runAsync(store.allNodes))!;
    final items = (await tester.runAsync(store.allItems))!;
    expect(nodes.every((n) => n.board != null), isTrue);
    expect(items.every((i) => i.boardPosition != null), isTrue);

    // Une nouvelle connaissance apparaît, placée automatiquement.
    final osc = nodes.firstWhere((n) => n.title == 'Oscillateurs');
    await tester.runAsync(
      () => store.createItem(
        nodeId: osc.id,
        kind: ItemKind.exercise,
        title: 'Pendule amorti',
      ),
    );
    await settle(tester);
    expect(find.text('Pendule amorti'), findsOneWidget);
    final added = (await tester.runAsync(
      store.allItems,
    ))!.firstWhere((i) => i.title == 'Pendule amorti');
    expect(added.boardPosition, isNotNull);
    // Les cartes déjà là n'ont pas bougé.
    final again = (await tester.runAsync(store.allItems))!;
    for (final i in items) {
      expect(
        again.firstWhere((a) => a.id == i.id).boardPosition,
        i.boardPosition,
      );
    }
    await unmountTestApp(tester);
  });

  testWidgets('toucher une carte ouvre sa fiche, un titre de région son '
      'nœud', (tester) async {
    await pumpTestApp(tester, seed: seed);
    await openBoard(tester);

    await tester.tap(find.text('Oscillateur harmonique'));
    await settle(tester);
    expect(find.byType(ItemDetailPage), findsOneWidget);
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.text('Oscillateurs'));
    await settle(tester);
    expect(find.byType(NodePage), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    await unmountTestApp(tester);
  });

  testWidgets('la vue est retenue', (tester) async {
    final store = await pumpTestApp(tester, seed: seed);
    await openBoard(tester);
    expect(await tester.runAsync(store.boardViewport), equals(null));
    // Glisser déplace la vue, retenue après un court délai.
    await tester.drag(find.text('Optique'), const Offset(-120, -40));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    final view = (await tester.runAsync(store.boardViewport))!;
    expect(view.scale, greaterThan(0));
    // « Recentrer » cadre tout de nouveau : chaque titre est visible.
    await tester.tap(find.text('Recentrer'));
    await settle(tester);
    for (final title in ['Mécanique', 'Optique', 'Oscillateur harmonique']) {
      final center = tester.getCenter(find.text(title));
      expect((Offset.zero & tester.view.physicalSize).contains(center), isTrue);
    }
    await unmountTestApp(tester);
  });

  group('rendu selon la vue', () {
    final t = DateTime.utc(2026, 11, 2);
    // Une région de 400 cartes : bien plus grande que la vue.
    final nodes = [
      KnowledgeNode(
        id: 'r',
        title: 'Thermodynamique',
        sortIndex: 0,
        createdAt: t,
      ),
    ];
    final items = [
      for (var k = 0; k < 400; k++)
        KnowledgeItem(
          id: 'c$k',
          nodeId: 'r',
          kind: ItemKind.definition,
          title: 'Carte $k',
          sortIndex: k,
          createdAt: t,
          updatedAt: t,
        ),
    ];
    final scene = BoardScene.build(
      nodes: nodes,
      items: items,
      layout: layoutBoard(nodes, items),
    );

    Future<TransformationController> pump(
      WidgetTester tester,
      double scale,
    ) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = TransformationController(
        Matrix4.identity()
          ..translateByDouble(
            -BoardScene.margin * scale,
            -BoardScene.margin * scale,
            0,
            1,
          )
          ..scaleByDouble(scale, scale, scale, 1),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveViewer(
              transformationController: controller,
              constrained: false,
              minScale: 0.01,
              child: BoardCanvas(
                scene: scene,
                controller: controller,
                viewport: const Size(1000, 700),
              ),
            ),
          ),
        ),
      );
      return controller;
    }

    testWidgets('de près : seules les cartes proches de la vue existent', (
      tester,
    ) async {
      final controller = await pump(tester, 1);
      final built = tester.widgetList(find.byType(BoardCard)).length;
      expect(built, greaterThan(0));
      // Environ 26 cartes visibles (1000 × 700) : à peine plus de deux
      // fois autant sont construites.
      expect(built, lessThan(70));
      expect(find.text('Carte 0'), findsOneWidget);
      expect(find.text('Carte 399'), findsNothing);

      // Défiler jusqu'en bas à droite : la dernière carte est construite.
      final last = scene.cards.last.rect;
      controller.value = Matrix4.identity()
        ..translateByDouble(-last.left + 200, -last.top + 200, 0, 1);
      await tester.pump();
      expect(find.text('Carte 399'), findsOneWidget);
      expect(find.text('Carte 0'), findsNothing);
    });

    testWidgets('de loin : titres des régions seulement, cartes en blocs', (
      tester,
    ) async {
      final controller = await pump(tester, 1);
      expect(find.byType(BoardCard), findsWidgets);

      controller.value = Matrix4.identity()..scaleByDouble(0.1, 0.1, 0.1, 1);
      await tester.pump();
      expect(find.byType(BoardCard), findsNothing);
      expect(find.text('Carte 0'), findsNothing);
      // Le titre, en grand : une taille constante à l'écran.
      final label = tester.widget<Text>(find.text('Thermodynamique'));
      expect(label.style!.fontSize! * 0.1, closeTo(26, 26 * 0.25));
    });

    testWidgets('à mi-distance : texte simple, de près : formules', (
      tester,
    ) async {
      final controller = await pump(tester, 0.5);
      final card = tester.widget<BoardCard>(find.byType(BoardCard).first);
      expect(card.latex, isFalse);
      controller.value = Matrix4.identity()..scaleByDouble(1, 1, 1, 1);
      await tester.pump();
      expect(
        tester.widget<BoardCard>(find.byType(BoardCard).first).latex,
        isTrue,
      );
    });
  });
}
