import 'package:flutter_test/flutter_test.dart';
import 'package:verger/pdf/pdf_tools.dart';

/// Boîtes de largeur 1, séparées de [gaps] (écart après chaque caractère).
List<({double left, double right, double height})> boxes(
  String text, {
  Map<int, double> gaps = const {},
}) {
  final result = <({double left, double right, double height})>[];
  var x = 0.0;
  for (var i = 0; i < text.length; i++) {
    result.add((left: x, right: x + 1, height: 2));
    x += 1 + (gaps[i] ?? 0);
  }
  return result;
}

void main() {
  test('mot délimité par espaces et ponctuation', () {
    const text = 'Soit E, un espace.';
    expect(wordBounds(text, boxes(text), 12), (11, 17)); // espace
    expect(wordBounds(text, boxes(text), 5), (5, 6)); // E
    expect(wordBounds(text, boxes(text), 6), (6, 7)); // la virgule seule
  });

  test('PDF sans espaces : coupure aux écarts visuels', () {
    const text = 'Soitunespace';
    // Écarts d'un caractère après « Soit » et « un ».
    final b = boxes(text, gaps: {3: 1, 5: 1});
    expect(wordBounds(text, b, 1), (0, 4));
    expect(wordBounds(text, b, 4), (4, 6));
    expect(wordBounds(text, b, 9), (6, 12));
  });

  test('ne sort pas du fragment', () {
    const text = 'abcdef';
    expect(wordBounds(text, boxes(text), 3, from: 2, to: 5), (2, 5));
  });
}
