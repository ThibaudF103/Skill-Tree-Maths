import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/ui/math_text.dart';

void main() {
  group('parseMath', () {
    test('texte, formule en ligne et formule centrée', () {
      expect(parseMath(r'Soit $u \in L(E)$. Alors $$\chi_u(u) = 0.$$ Fin'), [
        const TextSegment('Soit '),
        const FormulaSegment(r'u \in L(E)', display: false),
        const TextSegment('. Alors '),
        const FormulaSegment(r'\chi_u(u) = 0.', display: true),
        const TextSegment(' Fin'),
      ]);
    });

    test('dollar littéral et dollar non refermé', () {
      expect(parseMath(r'Prix : 5 \$ et $x'), [
        const TextSegment(r'Prix : 5 $ et $x'),
      ]);
      expect(parseMath(r'$a \$ b$'), [
        const FormulaSegment(r'a \$ b', display: false),
      ]);
    });

    test('texte sans formule et formule vide', () {
      expect(parseMath('Rien'), [const TextSegment('Rien')]);
      expect(parseMath(r'a $$ $$ b'), [const TextSegment('a  b')]);
    });
  });

  testWidgets('MathText rend les formules, et montre une erreur telle quelle', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MathText(
            r'Théorème : $\sum_{k=1}^n k = \frac{n(n+1)}2$.'
            '\n'
            r'$$\int_0^1 x\,dx = \frac12$$'
            r'Erreur : $\frac{1$',
          ),
        ),
      ),
    );
    expect(find.byType(Math), findsNWidgets(3));
    expect(find.textContaining('Théorème'), findsOneWidget);
    // La formule invalide est affichée en clair.
    expect(find.text(r'$\frac{1$'), findsOneWidget);
  });
}
