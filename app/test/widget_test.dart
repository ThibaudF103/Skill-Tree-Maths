import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  testWidgets('la navigation principale affiche les trois sections', (
    tester,
  ) async {
    await pumpTestApp(tester);
    expect(find.text('Verger'), findsWidgets);
    expect(find.text('Révisions'), findsOneWidget);
    expect(find.text('Arbres'), findsOneWidget);
    await unmountTestApp(tester);
  });
}
