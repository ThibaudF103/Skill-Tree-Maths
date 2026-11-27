import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/app/app_scope.dart';
import 'package:verger/app/resume.dart';
import 'package:verger/features/items/item_detail_page.dart';
import 'package:verger_core/verger_core.dart';

import 'test_app.dart';

/// Reprise au lancement : l'application rouvre la page où l'on était (#68).
void main() {
  tearDown(() => ResumeTracker.debugPageBuilder = null);

  /// Remplace les pages PDF et vidéo (pas de lecteur dans les tests) ; la
  /// fiche d'une connaissance reste la vraie.
  List<OpenPage> captureBuiltPages() {
    final built = <OpenPage>[];
    ResumeTracker.debugPageBuilder = (page) {
      built.add(page);
      if (page.kind == OpenPageKind.item) return ResumeTracker.build(page);
      return Scaffold(
        appBar: AppBar(),
        body: Text('${page.kind.name} ${page.page ?? page.positionMs ?? ''}'),
      );
    };
    return built;
  }

  testWidgets('rouvre le PDF, la fiche et la vidéo enregistrés', (
    tester,
  ) async {
    final built = captureBuiltPages();
    late List<OpenPage> saved;
    final store = await pumpTestApp(
      tester,
      seed: (store) async {
        final tree = await store.createNode(title: 'Algèbre');
        final item = await store.createItem(
          nodeId: tree.id,
          kind: ItemKind.theorem,
          title: 'Cayley-Hamilton',
        );
        final pdf = await store.importDocument(
          title: 'Cours.pdf',
          bytes: Uint8List.fromList([1]),
          contentHash: 'c',
          fingerprints: [Uint8List(4), Uint8List(4), Uint8List(4)],
        );
        final video = await store.addVideo(
          title: 'Cours filmé',
          url: 'https://youtu.be/abc',
          videoId: 'abc',
        );
        saved = [
          OpenPage.document(pdf.id, page: 3),
          OpenPage.item(item.id),
          OpenPage.video(video.id, positionMs: 42000),
        ];
        await store.setOpenPages(saved);
        await store.setHomeTab(2);
      },
    );

    expect(built, saved);
    expect(find.text('video 42000'), findsOneWidget);

    // Le retour redescend la pile jusqu'à l'accueil, sur l'onglet « Arbres ».
    await tester.pageBack();
    await settle(tester);
    expect(find.text('Cayley-Hamilton'), findsWidgets);
    expect(find.byType(ItemDetailPage), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    expect(find.text('document 3'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    expect(find.byType(ItemDetailPage), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, 2);

    // Les pages remplacées ne se déclarent pas : seule la fiche l'était, et
    // elle est quittée.
    expect(await tester.runAsync(store.openPages), isEmpty);
    await unmountTestApp(tester);
  });

  testWidgets('une page dont le contenu a disparu est oubliée', (tester) async {
    final built = captureBuiltPages();
    final store = await pumpTestApp(
      tester,
      seed: (store) async {
        final pdf = await store.importDocument(
          title: 'Cours.pdf',
          bytes: Uint8List.fromList([1]),
          contentHash: 'c',
          fingerprints: [Uint8List(4)],
        );
        await store.setOpenPages([
          const OpenPage.document('supprimé', page: 2),
          const OpenPage.item('supprimée'),
          // Un PDF n'est pas une vidéo.
          OpenPage.video(pdf.id, positionMs: 1000),
        ]);
      },
    );

    expect(built, isEmpty);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(await tester.runAsync(store.openPages), isEmpty);
    await unmountTestApp(tester);
  });

  testWidgets('fiche rouverte, position suivie, oubliée au retour', (
    tester,
  ) async {
    late KnowledgeItem item;
    final store = await pumpTestApp(
      tester,
      seed: (store) async {
        final tree = await store.createNode(title: 'Algèbre');
        item = await store.createItem(
          nodeId: tree.id,
          kind: ItemKind.theorem,
          title: 'Cayley-Hamilton',
        );
        await store.setOpenPages([OpenPage.item(item.id)]);
      },
    );
    expect(find.byType(ItemDetailPage), findsOneWidget);
    expect(find.text('Cayley-Hamilton'), findsWidgets);
    expect(await tester.runAsync(store.openPages), [OpenPage.item(item.id)]);

    // Une page qui suit sa position (PDF, vidéo) : enregistrée après un
    // court délai.
    final resume = AppScope.of(
      tester.element(find.byType(ItemDetailPage)),
    ).resume!;
    final token = resume.open(const OpenPage.document('d', page: 1));
    await settle(tester);
    resume.update(token, const OpenPage.document('d', page: 7));
    await tester.pump(ResumeTracker.delay);
    await settle(tester);
    expect(await tester.runAsync(store.openPages), [
      OpenPage.item(item.id),
      const OpenPage.document('d', page: 7),
    ]);
    resume.close(token);
    await settle(tester);

    await tester.pageBack();
    await settle(tester);
    expect(find.byType(ItemDetailPage), findsNothing);
    expect(await tester.runAsync(store.openPages), isEmpty);
    await unmountTestApp(tester);
  });
}
