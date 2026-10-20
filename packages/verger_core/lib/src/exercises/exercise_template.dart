import 'dart:convert';

import '../domain/rating.dart';
import 'expression.dart';
import 'math_value.dart';
import 'seeded_random.dart';

/// Modèle d'exercice paramétré, corrigé automatiquement. Chaque tirage
/// (une graine) donne un énoncé aux valeurs différentes, mais toujours le
/// même pour la même graine. Format JSON :
///
/// ```json
/// {
///   "v": 1,
///   "params": {"a": {"int": [2, 9]}, "b": {"int": [-9, 9], "not": [0]}},
///   "let": {"x": "-b/a"},
///   "when": ["a != b"],
///   "statement": "Résoudre $[[a]]x [[b|+]] = 0$.",
///   "questions": [
///     {"prompt": "$x =$", "answer": "x"},
///     {"prompt": "Signe de $x$ ?", "choices": ["positif", "négatif"],
///      "correct": "si(x > 0, 1, 2)"}
///   ]
/// }
/// ```
///
/// - `params` : `{"int": [min, max]}` (bornes comprises, `"not"` : valeurs
///   exclues) ou `{"pick": [valeurs]}`.
/// - `let` : valeurs calculées, dans l'ordre (chacune peut utiliser les
///   précédentes).
/// - `when` : conditions à respecter, sinon nouveau tirage.
/// - Dans les textes, `[[expression]]` affiche une valeur ;
///   `[[expression|options]]` : `+` (signe toujours écrit, « + 3 » ou
///   « - 3 »), `coef` (1 et -1 s'écrivent « » et « - »), `tex` (fraction
///   en `\frac{}{}`), un nombre (arrondi à ce nombre de décimales).
/// - Question à réponse numérique : `"answer"` (expression), `"tolerance"`
///   facultative (écart accepté ; sans elle, la réponse exacte est due).
/// - QCM : `"choices"` (mélangés à l'affichage) ; la bonne réponse est la
///   première, ou celle de rang `"correct"` (expression, 1 = le premier
///   choix écrit), par exemple `"si(x > 0, 1, 2)"`.
final class ExerciseTemplate {
  ExerciseTemplate._(
    this.source,
    this._params,
    this._lets,
    this._conditions,
    this._statement,
    this._questions,
  );

  /// Lit un modèle ; [FormatException] (message en français) s'il est mal
  /// formé ou s'il utilise une valeur non définie.
  factory ExerciseTemplate.parse(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('JSON invalide : ${e.message}');
    }
    if (json is! Map<String, Object?>) {
      throw const FormatException('Le modèle doit être un objet JSON');
    }
    if (json['v'] != 1) {
      throw const FormatException(
        'Version du modèle inconnue (attendu : "v": 1)',
      );
    }
    final defined = <String>{};
    void define(String name, String what) {
      if (!RegExp(r'^[A-Za-z_][A-Za-z_0-9]*$').hasMatch(name)) {
        throw FormatException('$what « $name » : nom invalide');
      }
      if (defined.contains(name)) {
        throw FormatException('$what « $name » : déjà défini');
      }
      defined.add(name);
    }

    MathExpression expr(Object? value, String where) {
      if (value is num) value = '$value';
      if (value is! String) {
        throw FormatException('$where : expression attendue');
      }
      final MathExpression e;
      try {
        e = MathExpression.parse(value);
      } on FormatException catch (err) {
        throw FormatException('$where : ${err.message}');
      }
      final unknown = e.variables.difference(defined);
      if (unknown.isNotEmpty) {
        throw FormatException('$where : « ${unknown.first} » non défini');
      }
      return e;
    }

    final params = <_Param>[];
    final rawParams = json['params'] ?? const <String, Object?>{};
    if (rawParams is! Map<String, Object?>) {
      throw const FormatException('« params » doit être un objet');
    }
    for (final MapEntry(:key, :value) in rawParams.entries) {
      final where = 'Paramètre « $key »';
      define(key, 'Paramètre');
      params.add(_Param.parse(key, value, where));
    }

    final lets = <(String, MathExpression)>[];
    final rawLets = json['let'] ?? const <String, Object?>{};
    if (rawLets is! Map<String, Object?>) {
      throw const FormatException('« let » doit être un objet');
    }
    for (final MapEntry(:key, :value) in rawLets.entries) {
      final e = expr(value, 'Valeur « $key »');
      define(key, 'Valeur');
      lets.add((key, e));
    }

    final rawWhen = json['when'] ?? const <Object?>[];
    if (rawWhen is! List) {
      throw const FormatException('« when » doit être une liste');
    }
    final conditions = [
      for (final (i, c) in rawWhen.indexed) expr(c, 'Condition ${i + 1}'),
    ];

    _Text text(Object? value, String where) {
      if (value is! String) throw FormatException('$where : texte attendu');
      return _Text.parse(value, where, (e, w) => expr(e, w));
    }

    final statement = text(json['statement'], 'Énoncé');
    final rawQuestions = json['questions'];
    if (rawQuestions is! List || rawQuestions.isEmpty) {
      throw const FormatException('« questions » : au moins une question');
    }
    final questions = <_Question>[];
    for (final (i, q) in rawQuestions.indexed) {
      final where = 'Question ${i + 1}';
      if (q is! Map<String, Object?>) {
        throw FormatException('$where : objet attendu');
      }
      final prompt = text(q['prompt'] ?? '', where);
      final choices = q['choices'];
      if (choices != null) {
        if (choices is! List || choices.length < 2) {
          throw FormatException('$where : au moins deux choix');
        }
        final correct = q['correct'];
        questions.add(
          _Question.choice(prompt, [
            for (final (j, c) in choices.indexed)
              text(c, '$where, choix ${j + 1}'),
          ], correct == null ? null : expr(correct, '$where, « correct »')),
        );
      } else {
        final tolerance = q['tolerance'];
        if (tolerance != null && (tolerance is! num || tolerance < 0)) {
          throw FormatException(
            '$where : « tolerance » doit être un nombre positif',
          );
        }
        questions.add(
          _Question.number(
            prompt,
            expr(q['answer'], '$where, réponse'),
            (tolerance as num?)?.toDouble(),
          ),
        );
      }
    }
    return ExerciseTemplate._(
      source,
      params,
      lets,
      conditions,
      statement,
      questions,
    );
  }

  final String source;
  final List<_Param> _params;
  final List<(String, MathExpression)> _lets;
  final List<MathExpression> _conditions;
  final _Text _statement;
  final List<_Question> _questions;

  /// Nombre de questions.
  int get questionCount => _questions.length;

  /// L'exercice tiré pour [seed]. [EvalError] si un calcul échoue (division
  /// par zéro…) ou si les conditions ne sont jamais remplies.
  ExerciseInstance generate(int seed) {
    final rng = SeededRandom(seed);
    EvalError? last;
    for (var attempt = 0; attempt < 200; attempt++) {
      final env = <String, MathValue>{};
      for (final p in _params) {
        env[p.name] = p.draw(rng);
      }
      // Un calcul impossible (division par zéro…) écarte le tirage, comme
      // une condition non remplie : « when » peut l'exclure après coup.
      try {
        for (final (name, e) in _lets) {
          env[name] = e.evaluate(env);
        }
        if (!_conditions.every((c) => c.evaluate(env).isTrue)) continue;
        return ExerciseInstance._(
          seed: seed,
          statement: _statement.render(env),
          questions: [for (final q in _questions) q.instantiate(env, rng)],
        );
      } on EvalError catch (e) {
        last = e;
      }
    }
    throw last ??
        const EvalError(
          'Conditions jamais remplies : élargir les paramètres ou les conditions',
        );
  }

  /// Vérifie le modèle sur plusieurs tirages : le premier problème trouvé,
  /// ou `null` si tout se calcule.
  String? check({int draws = 30}) {
    for (var seed = 0; seed < draws; seed++) {
      try {
        generate(seed);
      } on EvalError catch (e) {
        return 'Tirage $seed : ${e.message}';
      } catch (e) {
        return 'Tirage $seed : calcul impossible ($e)';
      }
    }
    return null;
  }
}

/// Un exercice tiré : énoncé et questions aux valeurs fixées.
final class ExerciseInstance {
  ExerciseInstance._({
    required this.seed,
    required this.statement,
    required this.questions,
  });

  final int seed;
  final String statement;
  final List<ExerciseQuestion> questions;
}

/// Question d'un exercice tiré.
sealed class ExerciseQuestion {
  const ExerciseQuestion(this.prompt);

  final String prompt;
}

/// Réponse numérique, lue comme une expression : `-3/4`, `-0,75`,
/// `sqrt(2)/2`…
final class NumberQuestion extends ExerciseQuestion {
  const NumberQuestion(super.prompt, this.expected, {this.tolerance});

  final MathValue expected;

  /// Écart accepté ; `null` : réponse exacte (pour une valeur approchée, à
  /// 5·10⁻⁵ près, comme la valeur affichée à 4 décimales).
  final double? tolerance;

  /// Réponse attendue, écrite simplement : exacte si elle l'est, sinon à
  /// 4 décimales.
  String get expectedText => formatValue(expected, expected.isExact ? '' : '4');

  /// Vrai si [input] est juste ; `null` s'il n'est pas lisible.
  bool? check(String input) {
    if (input.trim().isEmpty) return null;
    try {
      final e = MathExpression.parse(input, decimalComma: true);
      if (e.variables.isNotEmpty) return null;
      final tol = tolerance ?? (expected.isExact ? null : 5e-5);
      return e.evaluate().sameAs(expected, tolerance: tol);
    } catch (_) {
      // Saisie illisible ou incalculable, quelle qu'en soit la raison.
      return null;
    }
  }
}

/// QCM : [choices] dans l'ordre d'affichage, [correct] la bonne réponse.
final class ChoiceQuestion extends ExerciseQuestion {
  const ChoiceQuestion(super.prompt, this.choices, this.correct);

  final List<String> choices;
  final int correct;

  bool check(int index) => index == correct;
}

/// Note de révision tirée des résultats : tout juste → « bien », rien de
/// juste → « oublié », sinon « difficile ».
Rating ratingForResults(Iterable<bool> results) {
  final list = results.toList();
  final right = list.where((r) => r).length;
  if (right == list.length) return Rating.good;
  if (right == 0) return Rating.again;
  return Rating.hard;
}

/// Écrit [v] selon les options d'affichage (voir [ExerciseTemplate]).
String formatValue(MathValue v, String options) {
  final plus = options.contains('+');
  final coef = options.contains('coef');
  final tex = options.contains('tex');
  final digitsMatch = RegExp(r'\d+').firstMatch(options);
  final digits = digitsMatch == null ? null : int.parse(digitsMatch[0]!);
  final negative = v.toDouble() < 0;
  final magnitude = v.abs();
  final comma = tex ? '{,}' : ',';

  String body;
  final exact = magnitude.exact;
  if (coef && exact != null && exact == Rational.one) {
    body = '';
  } else if (digits != null) {
    body = magnitude.toDouble().toStringAsFixed(digits).replaceAll('.', comma);
  } else if (exact != null) {
    body = exact.isInteger
        ? '${exact.numerator}'
        : tex
        ? '\\frac{${exact.numerator}}{${exact.denominator}}'
        : '${exact.numerator}/${exact.denominator}';
  } else {
    body = magnitude
        .toDouble()
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'\.?0+$'), '')
        .replaceAll('.', comma);
  }
  if (plus) return '${negative ? '-' : '+'} $body';
  return negative ? '-$body' : body;
}

final class _Param {
  _Param.integer(this.name, int this._min, int this._max, this._excluded)
    : _choices = null;
  _Param.pick(this.name, List<MathValue> this._choices)
    : _min = null,
      _max = null,
      _excluded = const [];

  factory _Param.parse(String name, Object? value, String where) {
    if (value is! Map<String, Object?>) {
      throw FormatException(
        '$where : objet attendu ({"int": [min, max]} ou {"pick": […]})',
      );
    }
    final range = value['int'];
    if (range != null) {
      if (range is! List || range.length != 2 || range.any((x) => x is! int)) {
        throw FormatException('$where : « int » attend [min, max] (entiers)');
      }
      final lo = range[0] as int, hi = range[1] as int;
      if (hi < lo) throw FormatException('$where : min > max');
      final not = value['not'] ?? const <Object?>[];
      if (not is! List || not.any((x) => x is! int)) {
        throw FormatException('$where : « not » attend une liste d\'entiers');
      }
      final excluded = not.cast<int>();
      if (hi - lo + 1 <=
          excluded.where((x) => x >= lo && x <= hi).toSet().length) {
        throw FormatException('$where : toutes les valeurs sont exclues');
      }
      return _Param.integer(name, lo, hi, excluded);
    }
    final pick = value['pick'];
    if (pick is List && pick.isNotEmpty) {
      return _Param.pick(name, [
        for (final p in pick)
          if (p is num)
            MathValue.exact(Rational.parseDecimal(_plain(p)))
          else
            throw FormatException('$where : « pick » attend des nombres'),
      ]);
    }
    throw FormatException('$where : « int » ou « pick » attendu');
  }

  final String name;
  final int? _min;
  final int? _max;
  final List<int> _excluded;
  final List<MathValue>? _choices;

  MathValue draw(SeededRandom rng) {
    final choices = _choices;
    if (choices != null) return choices[rng.nextInt(0, choices.length - 1)];
    while (true) {
      final n = rng.nextInt(_min!, _max!);
      if (!_excluded.contains(n)) return MathValue.of(n);
    }
  }
}

/// Écriture décimale d'un nombre JSON, sans exposant.
String _plain(num n) {
  if (n is int) return '$n';
  final s = n.toString();
  if (!s.contains('e')) return s;
  return n.toStringAsFixed(12).replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Texte à trous : `[[expression]]` ou `[[expression|options]]`.
final class _Text {
  _Text._(this._parts);

  factory _Text.parse(
    String source,
    String where,
    MathExpression Function(String, String) expr,
  ) {
    final parts = <Object>[];
    var last = 0;
    // « [[[a]] ; 5] » : intervalle autour d'une valeur.
    for (final m in RegExp(r'\[\[(?!\[)(.+?)\]\]').allMatches(source)) {
      parts.add(source.substring(last, m.start));
      final inner = m[1]!;
      // Options après le dernier « | » qui n'appartient pas à un « || ».
      var bar = -1;
      for (var k = inner.length - 1; k >= 0; k--) {
        if (inner[k] == '|' && !_isOrOperator(inner, k)) {
          bar = k;
          break;
        }
      }
      final code = bar < 0 ? inner : inner.substring(0, bar);
      final options = bar < 0 ? '' : inner.substring(bar + 1);
      parts.add((expr(code, '$where, « [[$inner]] »'), options.trim()));
      last = m.end;
    }
    parts.add(source.substring(last));
    return _Text._(parts);
  }

  /// Le `|` trouvé appartient à un `||` (ou logique), pas aux options.
  static bool _isOrOperator(String s, int bar) =>
      (bar > 0 && s[bar - 1] == '|') ||
      (bar + 1 < s.length && s[bar + 1] == '|');

  final List<Object> _parts;

  String render(Map<String, MathValue> env) => _parts
      .map(
        (p) => p is String
            ? p
            : formatValue(
                (p as (MathExpression, String)).$1.evaluate(env),
                p.$2,
              ),
      )
      .join();
}

final class _Question {
  _Question.number(this._prompt, MathExpression this._answer, this._tolerance)
    : _choices = null;

  /// [correct] : rang de la bonne réponse (1 = premier choix), sinon 1.
  _Question.choice(
    this._prompt,
    List<_Text> this._choices,
    MathExpression? correct,
  ) : _answer = correct,
      _tolerance = null;

  final _Text _prompt;
  final MathExpression? _answer;
  final double? _tolerance;
  final List<_Text>? _choices;

  ExerciseQuestion instantiate(Map<String, MathValue> env, SeededRandom rng) {
    final prompt = _prompt.render(env);
    final choices = _choices;
    if (choices == null) {
      return NumberQuestion(
        prompt,
        _answer!.evaluate(env),
        tolerance: _tolerance,
      );
    }
    final correct = _answer;
    final rank = correct == null ? 1 : correct.evaluate(env).asInt;
    if (rank == null) {
      throw const EvalError('« correct » doit être un nombre entier');
    }
    if (rank < 1 || rank > choices.length) {
      throw EvalError(
        'Bonne réponse n° $rank : il n\'y a que ${choices.length} choix',
      );
    }
    final order = [for (var i = 0; i < choices.length; i++) i];
    rng.shuffle(order);
    return ChoiceQuestion(prompt, [
      for (final i in order) choices[i].render(env),
    ], order.indexOf(rank - 1));
  }
}
