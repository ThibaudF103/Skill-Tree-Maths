import 'dart:convert';

import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';

const _full = r'''
{"v": 1,
 "params": {"a": {"int": [2, 9]}, "b": {"int": [-9, 9], "not": [0, 1]},
            "k": {"pick": [0.5, 2, 3]}},
 "let": {"x": "(k - b) / a"},
 "when": ["x != 0"],
 "statement": "Résoudre $[[a]]x [[b|+]] = [[k]]$.",
 "questions": [
   {"prompt": "$x =$", "answer": "x", "tolerance": 0.01},
   {"choices": ["positive", "négative"], "correct": "si(x > 0, 1, 2)"},
   {"prompt": "Combien ?", "choices": ["un", "deux"], "correct": 2}
 ]}''';

void main() {
  test('aller-retour : même modèle, mêmes tirages', () {
    final draft = ExerciseDraft.tryParse(_full)!;
    expect(draft.params.map((p) => p.name), ['a', 'b', 'k']);
    expect(draft.params[1].excluded, '0 ; 1');
    expect(draft.params[2].isList, isTrue);
    expect(draft.params[2].values, '0.5 ; 2 ; 3');
    expect(draft.questions[0].tolerance, '0.01');
    expect(draft.questions[1].isChoice, isTrue);
    expect(draft.questions[2].correct, '2');

    final encoded = draft.encode();
    expect(jsonDecode(encoded), jsonDecode(_full));
    final a = ExerciseTemplate.parse(_full),
        b = ExerciseTemplate.parse(encoded);
    for (var seed = 0; seed < 20; seed++) {
      expect(b.generate(seed).statement, a.generate(seed).statement);
    }
  });

  test('saisie : virgule décimale, « ; » ou espaces, vides omis', () {
    final draft = ExerciseDraft(
      params: [
        DraftParam(name: 'n', min: ' 1', max: '5 ', excluded: '2;3  4'),
        DraftParam(name: 'p', isList: true, values: '0,5 ; 1,25'),
      ],
      statement: '[[n]] et [[p]]',
      questions: [DraftQuestion(answer: 'n p', tolerance: '0,1')],
    );
    expect(draft.toJson(), {
      'v': 1,
      'params': {
        'n': {
          'int': [1, 5],
          'not': [2, 3, 4],
        },
        'p': {
          'pick': [0.5, 1.25],
        },
      },
      'statement': '[[n]] et [[p]]',
      'questions': [
        {'answer': 'n p', 'tolerance': 0.1},
      ],
    });
    expect(ExerciseTemplate.parse(draft.encode()).check(), isNull);
  });

  test('saisie non numérique gardée, puis refusée à la lecture', () {
    final draft = ExerciseDraft(
      params: [DraftParam(name: 'n', min: 'un', max: '5')],
      questions: [DraftQuestion(answer: 'n')],
    );
    expect(
      () => ExerciseTemplate.parse(draft.encode()),
      throwsA(isA<FormatException>()),
    );
    expect(ExerciseDraft.tryParse(draft.encode())!.params.single.min, 'un');
  });

  test('nom en double : signalé, modèle refusé', () {
    final draft = ExerciseDraft(
      params: [DraftParam(name: 'a', min: '1', max: '2')],
      lets: [DraftLet(name: 'a ', expression: '2')],
      questions: [DraftQuestion(answer: 'a')],
    );
    expect(draft.duplicateName, 'a');
    expect(
      () => ExerciseTemplate.parse(draft.encode()),
      throwsA(isA<FormatException>()),
    );
  });

  test('ce que le formulaire ne sait pas montrer : JSON seulement', () {
    for (final source in [
      'pas du json',
      '[]',
      '{"v": 2}',
      '{"v": 1, "inconnu": 1}',
      '{"v": 1, "params": {"a": {"int": [1, 2], "pick": [1]}}}',
      '{"v": 1, "params": {"a": {"not": [1]}}}',
      '{"v": 1, "questions": [{"answer": "1", "correct": 1}]}',
      '{"v": 1, "statement": 3}',
    ]) {
      expect(ExerciseDraft.tryParse(source), isNull, reason: source);
    }
    expect(ExerciseDraft.tryParse('{"v": 1}')!.questions, isEmpty);
  });
}
