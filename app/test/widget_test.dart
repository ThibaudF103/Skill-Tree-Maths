import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/app/verger_app.dart';
import 'package:verger_data/verger_data.dart';

void main() {
  testWidgets('navigation principale et lecture de la base locale', (
    tester,
  ) async {
    final store = VergerStore(VergerDatabase(NativeDatabase.memory()));
    await tester.runAsync(() => store.createNode(title: 'Algèbre'));

    await tester.pumpWidget(VergerApp(store: store));
    expect(find.text('Verger'), findsWidgets);
    expect(find.text('Révisions'), findsOneWidget);

    await tester.tap(find.text('Arbres'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('1 arbre'), findsOneWidget);

    await tester.runAsync(store.close);
  });
}
