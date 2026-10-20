import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:verger_core/verger_core.dart';

import 'math_raster.dart';

const _margin = 36.0;
const _contentWidth = 595.28 - 2 * _margin; // A4

/// Lettre d'un choix de QCM sur la fiche : A, B, C…
String choiceLetter(int index) => String.fromCharCode(0x41 + index);

/// Fiches imprimables : une par élève (nom, date, QR code, exercices avec
/// cases de réponse), puis, si [answerKey], le corrigé de chacune.
///
/// Les textes saisis (noms, énoncés, formules) sont dessinés en images par
/// [raster], avec le rendu de l'application ; seuls les libellés fixes sont
/// du texte PDF.
Future<Uint8List> buildWorksheetPdf(
  List<Worksheet> sheets, {
  required String title,
  required String date,
  required bool answerKey,
  required MathRasterizer raster,
}) async {
  final cache = <String, RasterImage>{};
  Future<pw.Widget> text(
    String source, {
    double width = _contentWidth,
    double fontSize = 11,
    bool bold = false,
  }) async {
    if (source.trim().isEmpty) return pw.SizedBox();
    final key = '$width|$fontSize|$bold|$source';
    final image = cache[key] ??= await raster(
      source,
      width: width,
      fontSize: fontSize,
      bold: bold,
    );
    if (image.width <= 0 || image.height <= 0) return pw.SizedBox();
    return pw.Image(
      pw.MemoryImage(image.png),
      width: image.width,
      height: image.height,
    );
  }

  final doc = pw.Document(title: title, creator: 'Verger');
  final theme = pw.ThemeData.withFont(base: pw.Font.helvetica());
  for (final sheet in sheets) {
    final body = <pw.Widget>[
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                await text(sheet.student, fontSize: 16, bold: true),
                pw.SizedBox(height: 4),
                await text('$title — $date', width: _contentWidth - 90),
              ],
            ),
          ),
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: sheet.code.encode(),
            width: 72,
            height: 72,
          ),
        ],
      ),
      pw.Divider(),
    ];
    for (final (i, e) in sheet.exercises.indexed) {
      body.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: await text(
            'Exercice ${i + 1} — ${e.title}',
            fontSize: 12,
            bold: true,
          ),
        ),
      );
      body.add(await text(e.instance.statement));
      for (final (j, q) in e.instance.questions.indexed) {
        final number = e.instance.questions.length > 1 ? '${j + 1}. ' : '';
        switch (q) {
          case NumberQuestion():
            body.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Expanded(
                      child: await text(
                        '$number${q.prompt.trim().isEmpty ? 'Réponse :' : q.prompt}',
                        width: _contentWidth - 170,
                      ),
                    ),
                    pw.Container(
                      width: 160,
                      height: 26,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(width: 0.8),
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            );
          case ChoiceQuestion():
            body.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
                child: await text('$number${q.prompt}'),
              ),
            );
            for (final (k, choice) in q.choices.indexed) {
              body.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 12, top: 3),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 10,
                        height: 10,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 0.8),
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text('${choiceLetter(k)}. '),
                      pw.Expanded(
                        child: await text(choice, width: _contentWidth - 50),
                      ),
                    ],
                  ),
                ),
              );
            }
        }
      }
    }
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(_margin),
        build: (_) => body,
      ),
    );
  }

  if (answerKey) {
    final body = <pw.Widget>[
      pw.Text(
        'Corrigé',
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
    ];
    for (final sheet in sheets) {
      body.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, bottom: 2),
          child: await text(sheet.student, bold: true),
        ),
      );
      for (final (i, e) in sheet.exercises.indexed) {
        final answers = [
          for (final (j, q) in e.instance.questions.indexed)
            '${e.instance.questions.length > 1 ? '${j + 1}) ' : ''}'
                '${switch (q) {
                  NumberQuestion() => q.expectedText,
                  ChoiceQuestion() => choiceLetter(q.correct),
                }}',
        ];
        body.add(await text('Exercice ${i + 1} : ${answers.join(' ; ')}'));
      }
    }
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(_margin),
        build: (_) => body,
      ),
    );
  }
  return doc.save();
}
