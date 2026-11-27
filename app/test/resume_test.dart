import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/app/app_scope.dart';
import 'package:verger/app/resume.dart';
import 'package:verger/features/documents/document_viewer_page.dart';
import 'package:verger/features/items/item_detail_page.dart';
import 'package:verger/features/video/video_page.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'test_app.dart';

/// Reprise au lancement : l'application rouvre la page où l'on était (#68).
void main() {
  tearDown(() => ResumeTracker.debugPageBuilder = null);

  /// Remplace les pages PDF et vidéo (pas de lecteur dans les tests) ; la
  /// fiche d'une connaissance reste la vraie.
  List<OpenPage> captureBuiltPages({List<String?>? attachedTo}) {
    final built = <OpenPage>[];
    ResumeTracker.debugPageBuilder = (page, {attachTo}) {
      built.add(page);
      attachedTo?.add(attachTo?.title);
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
    final attachedTo = <String?>[];
    final built = captureBuiltPages(attachedTo: attachedTo);
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
          // Extrait à attacher à une connaissance : portée conservée.
          OpenPage.video(
            video.id,
            positionMs: 42000,
            endMs: 60000,
            attachToItemId: item.id,
          ),
        ];
        await store.setOpenPages(saved);
        await store.setHomeTab(2);
      },
    );

    expect(built, saved);
    expect(attachedTo, [null, null, 'Cayley-Hamilton']);
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
    // « Arbres », après « Verger » et « Tableau ».
    expect(rail.selectedIndex, 3);

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

  test('pages construites avec la page, la position et la portée', () {
    final item = KnowledgeItem(
      id: 'i',
      nodeId: 'n',
      kind: ItemKind.theorem,
      title: 'Cayley-Hamilton',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final pdf =
        ResumeTracker.build(
              const OpenPage.document('d', page: 3, attachToItemId: 'i'),
              attachTo: item,
            )
            as DocumentViewerPage;
    expect(pdf.documentId, 'd');
    expect(pdf.initialPage, 3);
    expect(pdf.attachToItem, item);

    final video =
        ResumeTracker.build(
              const OpenPage.video('v', positionMs: 42000, endMs: 60000),
              attachTo: item,
            )
            as VideoPage;
    expect(video.documentId, 'v');
    expect(video.startMs, 42000);
    expect(video.endMs, 60000);
    expect(video.attachToItem, item);

    // Extrait dépassé : la lecture n'est plus arrêtée à sa fin.
    final past =
        ResumeTracker.build(
              const OpenPage.video('v', positionMs: 70000, endMs: 60000),
            )
            as VideoPage;
    expect(past.endMs, isNull);
  });

  testWidgets('pages ouvertes avant la fin de la reprise, échec retenté, '
      'relevé avant l\'arrière-plan', (tester) async {
    final store = await pumpTestApp(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final flaky = _FlakyStore(store);
    final tracker = ResumeTracker(flaky);

    // Ouverte pendant la reprise : rien n'est encore enregistré…
    final token = tracker.open(const OpenPage.document('d', page: 1));
    await settle(tester);
    expect(await tester.runAsync(store.openPages), isEmpty);
    // … mais la reprise terminée l'enregistre.
    await tester.runAsync(() => tracker.restore(navigator));
    expect(await tester.runAsync(store.openPages), const [
      OpenPage.document('d', page: 1),
    ]);

    // Un enregistrement qui échoue est retenté, même sans changement.
    flaky.failures = 1;
    tracker.update(token, const OpenPage.document('d', page: 2));
    await tester.runAsync(
      () => expectLater(tracker.flush(), throwsA(isA<StateError>())),
    );
    await tester.runAsync(tracker.flush);
    expect(await tester.runAsync(store.openPages), const [
      OpenPage.document('d', page: 2),
    ]);

    // Passage en arrière-plan : la position courante est relevée d'abord ;
    // un relevé qui ne répond pas ne bloque pas l'enregistrement.
    tracker.open(
      const OpenPage.video('v', positionMs: 1000),
      refresh: () async => const OpenPage.video('v', positionMs: 9000),
    );
    tracker.open(
      const OpenPage.video('w', positionMs: 5),
      refresh: () => Completer<OpenPage?>().future,
    );
    await tester.runAsync(() => tracker.flush(refresh: true));
    expect(await tester.runAsync(store.openPages), const [
      OpenPage.document('d', page: 2),
      OpenPage.video('v', positionMs: 9000),
      OpenPage.video('w', positionMs: 5),
    ]);
    tracker.dispose();
    await unmountTestApp(tester);
  });
}

/// Magasin dont les [failures] prochains enregistrements de la reprise
/// échouent.
class _FlakyStore implements VergerStore {
  _FlakyStore(this._store);

  final VergerStore _store;
  var failures = 0;

  @override
  Future<void> setOpenPages(List<OpenPage> pages) async {
    if (failures > 0) {
      failures--;
      throw StateError('écriture impossible');
    }
    await _store.setOpenPages(pages);
  }

  @override
  Future<List<OpenPage>> openPages() => _store.openPages();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
