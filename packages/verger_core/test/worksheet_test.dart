import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';

WorksheetSource source(String id) => WorksheetSource(
  itemId: id,
  title: 'Exercice $id',
  template: ExerciseTemplate.parse(
    '{"v": 1, "params": {"a": {"int": [1, 1000]}}, '
    '"statement": "[[a]]", "questions": [{"answer": "a"}]}',
  ),
);

void main() {
  final sources = [
    for (final id in ['e1', 'e2', 'e3', 'e4']) source(id),
  ];

  test('une fiche par élève, valeurs propres à chacun, reproductibles', () {
    List<Worksheet> plan() => planWorksheets(
      students: ['Alice', 'Bob'],
      sources: sources,
      perSheet: 10,
      session: 's1',
    );
    final sheets = plan();
    expect(sheets.map((s) => s.student), ['Alice', 'Bob']);
    expect(sheets.first.exercises.map((e) => e.itemId), [
      'e1',
      'e2',
      'e3',
      'e4',
    ]);
    final alice = sheets[0].exercises.map((e) => e.instance.statement);
    final bob = sheets[1].exercises.map((e) => e.instance.statement);
    expect(alice, isNot(bob));
    expect(
      plan()[0].exercises.map((e) => e.instance.statement),
      alice.toList(),
    );
  });

  test('moins d\'exercices que proposés : tirés par élève, dans l\'ordre', () {
    final sheets = planWorksheets(
      students: [for (var i = 0; i < 12; i++) 'Élève $i'],
      sources: sources,
      perSheet: 2,
      session: 's',
    );
    final picks = <String>{};
    for (final s in sheets) {
      final ids = s.exercises.map((e) => e.itemId).toList();
      expect(ids, hasLength(2));
      expect(ids, [...ids]..sort());
      picks.add(ids.join());
    }
    expect(picks.length, greaterThan(1));
  });

  test('le QR code suffit à retrouver les énoncés', () {
    final sheet = planWorksheets(
      students: ['Zoé « Z »'],
      sources: sources,
      perSheet: 3,
      session: 'x',
    ).single;
    final code = WorksheetCode.decode(sheet.code.encode())!;
    expect(code.student, 'Zoé « Z »');
    expect(code.itemIds, sheet.exercises.map((e) => e.itemId));
    for (final (i, id) in code.itemIds.indexed) {
      final again = sources
          .firstWhere((s) => s.itemId == id)
          .template
          .generate(worksheetExerciseSeed(code.seed, id));
      expect(again.statement, sheet.exercises[i].instance.statement);
    }
  });

  test('code étranger refusé', () {
    for (final text in [
      'https://exemple.fr',
      '{"v": 1, "t": "autre"}',
      '{"v": 1, "t": "verger-fiche", "n": "A", "g": "1", "i": []}',
      '[1]',
    ]) {
      expect(WorksheetCode.decode(text), isNull, reason: text);
    }
  });
}
