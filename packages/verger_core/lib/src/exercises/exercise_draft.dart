import 'dart:convert';

/// Modèle d'exercice en cours d'écriture dans un formulaire : chaque champ
/// est un texte, tel que saisi. [encode] produit le JSON lu par
/// `ExerciseTemplate.parse`, qui signale les erreurs ; une saisie qui n'est
/// pas un nombre là où il en faut un est gardée telle quelle et refusée à la
/// lecture, rien n'est perdu en silence.
final class ExerciseDraft {
  ExerciseDraft({
    List<DraftParam>? params,
    List<DraftLet>? lets,
    List<DraftCondition>? conditions,
    this.statement = '',
    List<DraftQuestion>? questions,
  }) : params = params ?? [],
       lets = lets ?? [],
       conditions = conditions ?? [],
       questions = questions ?? [DraftQuestion()];

  final List<DraftParam> params;
  final List<DraftLet> lets;
  final List<DraftCondition> conditions;
  String statement;
  final List<DraftQuestion> questions;

  /// Brouillon d'un modèle JSON ; `null` si le texte n'est pas du JSON ou
  /// contient ce que le formulaire ne sait pas montrer (clé inconnue, type
  /// inattendu) : il ne s'édite alors qu'en JSON.
  static ExerciseDraft? tryParse(String source) {
    try {
      return _fromJson(jsonDecode(source));
    } on FormatException {
      return null;
    } on _Unsupported {
      return null;
    }
  }

  static ExerciseDraft _fromJson(Object? json) {
    final root = _map(json, const {
      'v',
      'params',
      'let',
      'when',
      'statement',
      'questions',
    });
    if (root['v'] != 1) throw const _Unsupported();
    return ExerciseDraft(
      params: [
        for (final MapEntry(:key, :value) in _map(
          root['params'] ?? const <String, Object?>{},
        ).entries)
          DraftParam._fromJson(key, value),
      ],
      lets: [
        for (final MapEntry(:key, :value) in _map(
          root['let'] ?? const <String, Object?>{},
        ).entries)
          DraftLet(name: key, expression: _text(value)),
      ],
      conditions: [
        for (final c in _list(root['when'] ?? const []))
          DraftCondition(_text(c)),
      ],
      statement: _string(root['statement'] ?? ''),
      questions: [
        for (final q in _list(root['questions'] ?? const []))
          DraftQuestion._fromJson(q),
      ],
    );
  }

  /// Nom donné deux fois (paramètre ou valeur calculée), `null` sinon. Le
  /// JSON ne peut pas porter deux clés égales : [toJson] rend alors la
  /// seconde invalide (« a#2 »), pour que le modèle soit refusé.
  String? get duplicateName {
    final seen = <String>{};
    for (final name in [
      ...params.map((p) => p.name),
      ...lets.map((l) => l.name),
    ]) {
      final n = name.trim();
      if (n.isNotEmpty && !seen.add(n)) return n;
    }
    return null;
  }

  Map<String, Object?> toJson() {
    final used = <String>{};
    String key(String name) {
      final n = name.trim();
      var k = n;
      for (var i = 2; !used.add(k); i++) {
        k = '$n#$i';
      }
      return k;
    }

    return {
      'v': 1,
      if (params.isNotEmpty)
        'params': {for (final p in params) key(p.name): p._toJson()},
      if (lets.isNotEmpty)
        'let': {for (final l in lets) key(l.name): l.expression.trim()},
      if (conditions.isNotEmpty)
        'when': [for (final c in conditions) c.expression.trim()],
      'statement': statement,
      'questions': [for (final q in questions) q._toJson()],
    };
  }

  /// JSON indenté, lisible dans le champ de saisie.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Valeur tirée au hasard : entier entre deux bornes, ou valeur d'une liste.
final class DraftParam {
  DraftParam({
    this.name = '',
    this.isList = false,
    this.min = '',
    this.max = '',
    this.excluded = '',
    this.values = '',
  });

  factory DraftParam._fromJson(String name, Object? json) {
    final m = _map(json, const {'int', 'not', 'pick'});
    final range = m['int'];
    if (range != null) {
      final r = _list(range);
      if (r.length != 2 || m.containsKey('pick')) throw const _Unsupported();
      return DraftParam(
        name: name,
        min: _text(r[0]),
        max: _text(r[1]),
        excluded: _joinNumbers(m['not'] ?? const []),
      );
    }
    if (m.containsKey('not') || !m.containsKey('pick')) {
      throw const _Unsupported();
    }
    return DraftParam(
      name: name,
      isList: true,
      values: _joinNumbers(m['pick']),
    );
  }

  String name;

  /// Valeur prise dans [values] plutôt qu'entre [min] et [max].
  bool isList;
  String min;
  String max;

  /// Valeurs exclues, séparées par « ; » ou des espaces.
  String excluded;

  /// Valeurs possibles, séparées par « ; » ou des espaces.
  String values;

  Map<String, Object?> _toJson() {
    if (isList) return {'pick': _splitNumbers(values)};
    final not = _splitNumbers(excluded);
    return {
      'int': [_number(min), _number(max)],
      if (not.isNotEmpty) 'not': not,
    };
  }
}

/// Valeur calculée à partir des précédentes.
final class DraftLet {
  DraftLet({this.name = '', this.expression = ''});

  String name;
  String expression;
}

/// Condition imposée au tirage.
final class DraftCondition {
  DraftCondition([this.expression = '']);

  String expression;
}

/// Question : réponse numérique, ou QCM.
final class DraftQuestion {
  DraftQuestion({
    this.prompt = '',
    this.isChoice = false,
    this.answer = '',
    this.tolerance = '',
    List<DraftChoice>? choices,
    this.correct = '',
  }) : choices = choices ?? [DraftChoice(), DraftChoice()];

  factory DraftQuestion._fromJson(Object? json) {
    final m = _map(json, const {
      'prompt',
      'answer',
      'tolerance',
      'choices',
      'correct',
    });
    final prompt = _string(m['prompt'] ?? '');
    final choices = m['choices'];
    if (choices != null) {
      if (m.containsKey('answer') || m.containsKey('tolerance')) {
        throw const _Unsupported();
      }
      return DraftQuestion(
        prompt: prompt,
        isChoice: true,
        choices: [for (final c in _list(choices)) DraftChoice(_string(c))],
        correct: m['correct'] == null ? '' : _text(m['correct']),
      );
    }
    if (m.containsKey('correct')) throw const _Unsupported();
    return DraftQuestion(
      prompt: prompt,
      answer: _text(m['answer'] ?? ''),
      tolerance: m['tolerance'] == null ? '' : _text(m['tolerance']),
    );
  }

  String prompt;
  bool isChoice;

  /// Expression de la réponse numérique.
  String answer;

  /// Écart accepté ; vide : réponse exacte.
  String tolerance;
  final List<DraftChoice> choices;

  /// Rang (1 = premier choix) ou expression ; vide : le premier choix.
  String correct;

  Map<String, Object?> _toJson() {
    if (isChoice) {
      final c = correct.trim();
      return {
        if (prompt.isNotEmpty) 'prompt': prompt,
        'choices': [for (final ch in choices) ch.text],
        if (c.isNotEmpty) 'correct': int.tryParse(c) ?? c,
      };
    }
    final t = tolerance.trim();
    return {
      if (prompt.isNotEmpty) 'prompt': prompt,
      'answer': answer.trim(),
      if (t.isNotEmpty) 'tolerance': _number(t),
    };
  }
}

/// Un choix de QCM.
final class DraftChoice {
  DraftChoice([this.text = '']);

  String text;
}

final class _Unsupported implements Exception {
  const _Unsupported();
}

Map<String, Object?> _map(Object? json, [Set<String>? allowed]) {
  if (json is! Map<String, Object?>) throw const _Unsupported();
  if (allowed != null && json.keys.any((k) => !allowed.contains(k))) {
    throw const _Unsupported();
  }
  return json;
}

List<Object?> _list(Object? json) =>
    json is List<Object?> ? json : throw const _Unsupported();

String _string(Object? json) =>
    json is String ? json : throw const _Unsupported();

/// Nombre ou expression, montré comme texte.
String _text(Object? json) => switch (json) {
  String() => json,
  int() => '$json',
  double() when json == json.roundToDouble() && json.abs() < 1e15 =>
    '${json.toInt()}',
  num() => '$json',
  _ => throw const _Unsupported(),
};

String _joinNumbers(Object? json) => _list(json).map(_text).join(' ; ');

/// Texte saisi en nombre (virgule décimale acceptée) ; gardé tel quel s'il
/// n'en est pas un, pour que la lecture du modèle le signale.
Object _number(String text) {
  final t = text.trim().replaceAll(',', '.');
  final d = double.tryParse(t);
  return int.tryParse(t) ?? (d != null && d.isFinite ? d : text.trim());
}

List<Object> _splitNumbers(String text) => [
  for (final part in text.split(RegExp(r'[;\s]+')))
    if (part.isNotEmpty) _number(part),
];
