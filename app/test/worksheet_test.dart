import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/features/worksheets/math_raster.dart';
import 'package:verger/features/worksheets/worksheet_dialog.dart';
import 'package:verger/features/worksheets/worksheet_pdf.dart';
import 'package:verger_core/verger_core.dart';

/// Image PNG de 1×1 pixel.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

/// Rasterizer factice : note les textes dessinés.
MathRasterizer recorder(List<String> drawn) =>
    (source, {required width, fontSize = 11, bold = false}) async {
      drawn.add(source);
      return (png: _png, width: 100.0, height: 12.0);
    };

KnowledgeItem item(String id, String? model) => KnowledgeItem(
  id: id,
  nodeId: 'n',
  kind: ItemKind.exercise,
  title: 'Exercice $id',
  autoExercise: model,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const _model = r'''
{"v": 1, "params": {"a": {"int": [2, 9]}},
 "statement": "Calculer $[[a]] \\times 2$.",
 "questions": [{"prompt": "Résultat :", "answer": "2a"},
               {"prompt": "Pair ?", "choices": ["oui", "non"]}]}''';

void main() {
  test('sources : seuls les modèles valides', () {
    final sources = worksheetSources([
      item('a', _model),
      item('b', null),
      item('c', '{"v": 1}'),
      item('d', '  '),
    ]);
    expect(sources.map((s) => s.itemId), ['a']);
  });

  test('PDF : une fiche par élève, énoncés propres, corrigé', () async {
    final sheets = planWorksheets(
      students: ['Alice', 'Bob'],
      sources: worksheetSources([item('a', _model)]),
      perSheet: 1,
      session: 's',
    );
    final drawn = <String>[];
    final bytes = await buildWorksheetPdf(
      sheets,
      title: 'Calcul',
      date: '20/10/2026',
      answerKey: true,
      raster: recorder(drawn),
    );
    expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(drawn, containsAll(['Alice', 'Bob', 'Calcul — 20/10/2026']));
    for (final s in sheets) {
      final e = s.exercises.single.instance;
      expect(drawn, contains(e.statement));
      final q = e.questions;
      final number = q[0] as NumberQuestion, choice = q[1] as ChoiceQuestion;
      expect(
        drawn,
        contains(
          'Exercice 1 : 1) ${number.expectedText} ; '
          '2) ${choiceLetter(choice.correct)}',
        ),
      );
    }
    // Textes identiques dessinés une seule fois.
    expect(drawn.where((t) => t == '1. Résultat :'), hasLength(1));
  });

  testWidgets('rendu hors écran d\'une formule', (tester) async {
    final image = (await tester.runAsync(
      () => rasterizeMath(r'Calculer $\frac{1}{2}$', width: 300),
    ))!;
    expect(image.width, greaterThan(0));
    expect(image.width, lessThanOrEqualTo(300));
    expect(image.height, greaterThan(0));
    expect(image.png.sublist(1, 4), utf8.encode('PNG'));
  });

  testWidgets('dialogue : élèves, exercices par fiche, enregistrement', (
    tester,
  ) async {
    final drawn = <String>[];
    String? savedName;
    Uint8List? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => printWorksheets(
                context,
                title: 'Calcul',
                items: [item('a', _model), item('b', _model)],
                raster: recorder(drawn),
                save: (name, bytes) async {
                  savedName = name;
                  saved = bytes;
                  return name;
                },
              ),
              child: const Text('Fiches'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Fiches'));
    await tester.pumpAndSettle();
    final create = find.widgetWithText(FilledButton, 'Créer les fiches');
    expect(tester.widget<FilledButton>(create).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Élèves'),
      'Alice\n\n  Bob  \n',
    );
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 exercice tirés parmi 2'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Créer 2 fiches'));
      for (var i = 0; i < 20 && saved == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(savedName, 'Calcul.pdf');
    expect(saved, isNotNull);
    expect(drawn, containsAll(['Alice', 'Bob']));
    expect(find.text('2 fiches enregistrées.'), findsOneWidget);
  });
}
