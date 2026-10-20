import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';

MathValue ev(String s, [Map<String, MathValue> env = const {}]) =>
    MathExpression.parse(s).evaluate(env);

void main() {
  group('expressions', () {
    test('calcul exact sur les fractions', () {
      expect(ev('1/3 + 1/6').exact, Rational(BigInt.one, BigInt.two));
      expect(ev('2^-2').exact, Rational(BigInt.one, BigInt.from(4)));
      expect(ev('-2^2').asInt, -4);
      expect(ev('2^3^2').asInt, 512);
      expect(ev('0.25 * 4').asInt, 1);
      expect(ev('sqrt(9/4)').exact, Rational(BigInt.from(3), BigInt.two));
      expect(ev('sqrt(2)').isExact, isFalse);
      expect(ev('sqrt(2)^2').sameAs(MathValue.of(2)), isTrue);
    });

    test('multiplication sous-entendue, variables, fonctions', () {
      final env = {'a': MathValue.of(3), 'x': MathValue.of(-2)};
      expect(ev('2a', env).asInt, 6);
      expect(ev('3(a + 1)', env).asInt, 12);
      expect(ev('2sqrt(4)').asInt, 4);
      expect(ev('-2x^2', env).asInt, -8);
      expect(ev('abs(x) + min(a, x) + max(a, x)', env).asInt, 3);
      expect(ev('si(x > 0, 1, 2)', env).asInt, 2);
      expect(ev('a == 3 && x != 0 || 0', env).asInt, 1);
      expect(ev('5 × 2 − 3 ÷ 3').asInt, 9);
    });

    test('erreurs en français', () {
      expect(() => MathExpression.parse('2 +'), throwsFormatException);
      expect(() => MathExpression.parse('(1 + 2'), throwsFormatException);
      expect(() => MathExpression.parse('2 # 3'), throwsFormatException);
      expect(() => MathExpression.parse('min(1)'), throwsFormatException);
      expect(() => ev('1/0'), throwsA(isA<EvalError>()));
      expect(() => ev('y'), throwsA(isA<EvalError>()));
      expect(MathExpression.parse('a + 2b').variables, {'a', 'b'});
    });

    test('virgule décimale dans une réponse', () {
      final e = MathExpression.parse('-0,75', decimalComma: true);
      expect(e.evaluate().exact, Rational(BigInt.from(-3), BigInt.from(4)));
    });
  });

  group('affichage', () {
    MathValue r(int p, int q) =>
        MathValue.exact(Rational(BigInt.from(p), BigInt.from(q)));
    test('options', () {
      expect(formatValue(MathValue.of(3), ''), '3');
      expect(formatValue(MathValue.of(-3), '+'), '- 3');
      expect(formatValue(MathValue.of(3), '+'), '+ 3');
      expect(formatValue(MathValue.of(1), 'coef'), '');
      expect(formatValue(MathValue.of(-1), 'coef'), '-');
      expect(formatValue(MathValue.of(-1), '+coef'), '- ');
      expect(formatValue(r(-3, 4), ''), '-3/4');
      expect(formatValue(r(-3, 4), 'tex'), r'-\frac{3}{4}');
      expect(formatValue(r(1, 3), '2'), '0,33');
      expect(formatValue(MathValue.approx(1.5), ''), '1,5');
    });
  });

  group('tirage', () {
    test('déterministe et réparti', () {
      final a = SeededRandom(42), b = SeededRandom(42);
      final xs = [for (var i = 0; i < 50; i++) a.nextInt(1, 6)];
      expect([for (var i = 0; i < 50; i++) b.nextInt(1, 6)], xs);
      expect(xs.toSet(), {1, 2, 3, 4, 5, 6});
      expect(
        SeededRandom.hashString('Alice'),
        isNot(SeededRandom.hashString('Bob')),
      );
      // Valeur de référence de mulberry32 (0,6270739… × 2^32) : le même
      // tirage sur toutes les plateformes.
      expect(SeededRandom(1).nextUint32(), 2693262067);
    });
  });

  group('modèle d\'exercice', () {
    const affine = r'''
{
  "v": 1,
  "params": {"a": {"int": [2, 9]}, "b": {"int": [-9, 9], "not": [0]}},
  "let": {"x": "-b/a"},
  "statement": "Résoudre $[[a|coef]]x [[b|+]] = 0$.",
  "questions": [
    {"prompt": "$x =$", "answer": "x"},
    {"prompt": "Signe de $x$ ?", "choices": ["positif", "négatif"],
     "correct": "si(x > 0, 1, 2)"}
  ]
}''';

    test('tirage, énoncé et correction', () {
      final t = ExerciseTemplate.parse(affine);
      expect(t.check(), isNull);
      final i = t.generate(7);
      expect(t.generate(7).statement, i.statement);
      final m = RegExp(r'\$(\d)x ([+-]) (\d) = 0\$').firstMatch(i.statement);
      expect(m, isNotNull, reason: i.statement);
      final a = int.parse(m![1]!),
          b = int.parse(m[3]!) * (m[2] == '-' ? -1 : 1);
      final q = i.questions.first as NumberQuestion;
      final x = Rational(BigInt.from(-b), BigInt.from(a));
      expect(q.check('${x.numerator}/${x.denominator}'), isTrue);
      expect(q.check(' ${x.numerator} / ${x.denominator} '), isTrue);
      expect(q.check('${x.numerator + BigInt.one}/${x.denominator}'), isFalse);
      expect(q.check('n importe quoi'), isNull);
      expect(q.check(''), isNull);
      final c = i.questions[1] as ChoiceQuestion;
      expect(c.choices, unorderedEquals(['positif', 'négatif']));
      expect(c.choices[c.correct], x.isNegative ? 'négatif' : 'positif');
    });

    test('réponse approchée avec tolérance', () {
      final t = ExerciseTemplate.parse(r'''
{"v": 1, "params": {"n": {"pick": [2, 3, 5]}},
 "statement": "Valeur approchée de $\\sqrt{[[n]]}$",
 "questions": [{"answer": "sqrt(n)", "tolerance": 0.01}]}''');
      final q = t.generate(1).questions.single as NumberQuestion;
      final v = q.expected.toDouble();
      expect(q.check(v.toStringAsFixed(2).replaceAll('.', ',')), isTrue);
      expect(q.check((v + 0.1).toStringAsFixed(2)), isFalse);
      expect(q.check('sqrt(${(v * v).round()})'), isTrue);
    });

    test('décimal exact : 0,5 vaut 1/2, mais 0,33 ne vaut pas 1/3', () {
      final t = ExerciseTemplate.parse(
        r'''
{"v": 1, "statement": "", "questions": [{"answer": "1/2"}, {"answer": "1/3"}]}''',
      );
      final qs = t.generate(0).questions.cast<NumberQuestion>();
      expect(qs[0].check('0,5'), isTrue);
      expect(qs[1].check('0,33'), isFalse);
      expect(qs[1].check('1/3'), isTrue);
    });

    test('conditions et erreurs de modèle', () {
      final t = ExerciseTemplate.parse(r'''
{"v": 1, "params": {"a": {"int": [1, 3]}, "b": {"int": [1, 3]}},
 "when": ["a != b"], "statement": "[[a]] [[b]]",
 "questions": [{"answer": "a - b"}]}''');
      for (var s = 0; s < 20; s++) {
        final parts = t.generate(s).statement.split(' ');
        expect(parts[0], isNot(parts[1]));
      }
      void bad(String json, String fragment) => expect(
        () => ExerciseTemplate.parse(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(fragment),
          ),
        ),
      );
      bad('{', 'JSON invalide');
      bad('{"v": 2}', 'Version');
      bad(
        '{"v": 1, "statement": "", "questions": []}',
        'au moins une question',
      );
      bad(
        '{"v": 1, "statement": "[[z]]", "questions": [{"answer": "1"}]}',
        '« z » non défini',
      );
      bad(
        '{"v": 1, "params": {"a": {"int": [3, 1]}}, "statement": "", "questions": [{"answer": "a"}]}',
        'min > max',
      );
      bad(
        '{"v": 1, "statement": "", "questions": [{"choices": ["x"]}]}',
        'au moins deux choix',
      );
      final never = ExerciseTemplate.parse(r'''
{"v": 1, "params": {"a": {"int": [1, 1]}}, "when": ["a > 1"], "statement": "",
 "questions": [{"answer": "a"}]}''');
      expect(never.check(), contains('Conditions jamais remplies'));
      final zero = ExerciseTemplate.parse(
        r'''
{"v": 1, "params": {"a": {"int": [0, 0]}}, "statement": "", "questions": [{"answer": "1/a"}]}''',
      );
      expect(zero.check(), contains('Division par zéro'));
    });

    test('retours de relecture', () {
      // Calcul impossible dans « let » : tirage écarté, pas d'échec.
      final guarded = ExerciseTemplate.parse(r'''
{"v": 1, "params": {"b": {"int": [-2, 2]}}, "let": {"x": "1/b"},
 "when": ["b != 0"], "statement": "", "questions": [{"answer": "x"}]}''');
      expect(guarded.check(), isNull);
      // Rang « correct » non entier : refusé.
      final rank = ExerciseTemplate.parse(r'''
{"v": 1, "statement": "", "questions": [
  {"choices": ["A", "B"], "correct": "3/2"}]}''');
      expect(rank.check(), contains('entier'));
      // Intervalle autour d'une valeur.
      final interval = ExerciseTemplate.parse(r'''
{"v": 1, "params": {"a": {"int": [1, 1]}},
 "statement": "x ∈ [[[a]] ; 5]", "questions": [{"answer": "a"}]}''');
      expect(interval.generate(0).statement, 'x ∈ [1 ; 5]');
      // Valeur approchée sans tolérance : la réponse affichée est acceptée.
      final approx = ExerciseTemplate.parse(r'''
{"v": 1, "statement": "", "questions": [{"answer": "sqrt(2)"}]}''');
      final q = approx.generate(0).questions.single as NumberQuestion;
      expect(q.expectedText, '1,4142');
      expect(q.check(q.expectedText), isTrue);
      expect(q.check('1,41'), isFalse);
      // Avec tolérance, une valeur exacte s'affiche telle quelle.
      final exactTol = ExerciseTemplate.parse(r'''
{"v": 1, "statement": "", "questions": [{"answer": "5", "tolerance": 0.1}]}''');
      expect(
        (exactTol.generate(0).questions.single as NumberQuestion).expectedText,
        '5',
      );
      // Saisies absurdes : illisibles, sans plantage ni blocage.
      final one = ExerciseTemplate.parse(r'''
{"v": 1, "statement": "", "questions": [{"answer": "1"}]}''');
      final q1 = one.generate(0).questions.single as NumberQuestion;
      expect(q1.check('sqrt((10^64)^7)'), isFalse);
      expect(q1.check('(((9^64)^64)^64)^64'), isNull);
      expect(q1.check('${'(' * 20000}1${')' * 20000}'), isNull);
      expect(q1.check('1.2.3'), isNull);
      expect(q1.check('1,2,3'), isNull);
    });

    test('calculs limites', () {
      expect(
        ev('1/(1/(10^64)^6)').exact!.numerator.bitLength,
        greaterThan(1000),
      );
      expect(ev('sqrt((10^64)^7)').isExact, isTrue); // carré parfait
      // Trop grand pour une valeur approchée : erreur de calcul, sans plantage.
      expect(() => ev('sqrt(2(10^64)^7)'), throwsA(isA<EvalError>()));
      expect(ev('sqrt(2(10^64))').isExact, isFalse);
      expect(ev('sqrt(10^128)').exact, Rational(BigInt.from(10).pow(64)));
      expect(ev('3/2sqrt(4)').exact, Rational(BigInt.from(3), BigInt.from(4)));
      expect(ev('6/2(1+2)').asInt, 1);
    });

    test('note tirée des résultats', () {
      expect(ratingForResults([true, true]), Rating.good);
      expect(ratingForResults([true, false]), Rating.hard);
      expect(ratingForResults([false, false]), Rating.again);
    });
  });
}
