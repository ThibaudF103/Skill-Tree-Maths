import 'package:flutter_test/flutter_test.dart';
import 'package:verger/app/verger_app.dart';

void main() {
  testWidgets('la navigation principale affiche les trois sections', (
    tester,
  ) async {
    await tester.pumpWidget(const VergerApp());

    expect(find.text('Verger'), findsWidgets);
    expect(find.text('Révisions'), findsOneWidget);
    expect(find.text('Arbres'), findsOneWidget);

    await tester.tap(find.text('Révisions'));
    await tester.pumpAndSettle();
    expect(find.text('Révisions'), findsNWidgets(2));
  });
}
