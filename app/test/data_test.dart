import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:verger_core/verger_core.dart';

import 'test_app.dart';

void main() {
  test("l'exemple « Algèbre » est une archive valide", () {
    final archive = VergerArchive.fromJson(
      (jsonDecode(
                File('assets/samples/algebre_exemple.json').readAsStringSync(),
              )
              as Map)
          .cast(),
    );
    expect(archive.nodes.where((n) => n.parentId == null), hasLength(1));
    expect(archive.items.length, greaterThan(20));
    expect(archive.reviews, isEmpty);
    expect(
      archive.items.map((i) => i.kind.family).toSet(),
      ItemFamily.values.toSet(),
    );
  });

  testWidgets("charger l'exemple depuis le verger vide", (tester) async {
    final store = await pumpTestApp(tester);
    await tester.tap(find.text('Arbres'));
    await settle(tester);
    await tester.tap(find.textContaining('Essayer avec l\'exemple'));
    await settle(tester);

    expect(find.text('Algèbre (exemple)'), findsWidgets);
    expect(find.textContaining('ajouté (26 connaissances)'), findsOneWidget);
    final items = (await tester.runAsync(store.allItems))!;
    expect(items, hasLength(26));
    expect(items.every((i) => i.scheduling.isNew), isTrue);

    // Le verger montre l'arbre.
    await tester.tap(find.text('Verger'));
    await settle(tester);
    expect(find.text('Algèbre (exemple)'), findsOneWidget);
    expect(find.text('26 connaissances · maîtrise 0 %'), findsOneWidget);
    await unmountTestApp(tester);
  });
}
