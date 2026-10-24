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

  testWidgets('une formule en ligne est posée sur la ligne de base du texte', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: MathText(r'Soit $u \in L(E)$ et $x$ fixé.'),
          ),
        ),
      ),
    );
    final spans = <WidgetSpan>[];
    tester.widget<RichText>(find.byType(RichText).first).text.visitChildren((
      span,
    ) {
      if (span is WidgetSpan) spans.add(span);
      return true;
    });
    expect(spans, hasLength(2));
    for (final span in spans) {
      expect(span.alignment, PlaceholderAlignment.baseline);
      expect(span.baseline, TextBaseline.alphabetic);
    }

    // Même ligne de base, à l'écran, pour le texte et chaque formule (lue
    // hors mise en page : valeurs déjà calculées, en cache).
    RenderObject.debugCheckingIntrinsics = true;
    addTearDown(() => RenderObject.debugCheckingIntrinsics = false);
    final paragraph = tester.renderObject<RenderBox>(
      find.byType(RichText).first,
    );
    final textBaseline =
        paragraph.localToGlobal(Offset.zero).dy +
        paragraph.getDistanceToBaseline(TextBaseline.alphabetic)!;
    for (final formula in find.byType(Math).evaluate()) {
      final box = formula.renderObject! as RenderBox;
      final baseline =
          box.localToGlobal(Offset.zero).dy +
          box.getDistanceToBaseline(TextBaseline.alphabetic)!;
      expect(baseline, moreOrLessEquals(textBaseline, epsilon: 0.1));
    }
  });
}
