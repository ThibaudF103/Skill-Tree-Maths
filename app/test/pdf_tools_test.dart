import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:verger/pdf/pdf_tools.dart';
import 'package:verger_core/verger_core.dart';

/// Vrais PDF générés (Chromium) : v1 = pages A, B, C ;
/// v2 = A, X (insérée), B, C, D (ajoutée).
void main() {
  if (Platform.environment['PDFIUM_PATH'] == null) {
    test('outils PDF', () {}, skip: 'PDFIUM_PATH non défini (PDFium absent)');
    return;
  }
  final v1 = File('test/fixtures/cours_v1.pdf').readAsBytesSync();
  final v2 = File('test/fixtures/cours_v2.pdf').readAsBytesSync();

  setUpAll(() async {
    // Initialisation « Dart pur » : PDFium natif de la machine de test.
    await pdfrxInitialize(tmpPath: Directory.systemTemp.createTempSync().path);
  });

  test('analyse : pages, empreintes, SHA-256', () async {
    final a = await analyzePdf(v1);
    expect(a.pageCount, 3);
    expect(a.fingerprints, hasLength(3));
    expect(a.fingerprints.first, hasLength(fingerprintSide * fingerprintSide));
    expect(a.contentHash, hasLength(64));
    // Analyse reproductible.
    final again = await analyzePdf(Uint8List.fromList(v1));
    expect(again.fingerprints[1], a.fingerprints[1]);
  });

  test('recalage réel entre deux versions du PDF', () async {
    final a = await analyzePdf(v1);
    final b = await analyzePdf(v2);
    final remap = remapPages(a.fingerprints, b.fingerprints);
    expect(remap.matches[1]!.page, 1);
    expect(remap.matches[2]!.page, 3);
    expect(remap.matches[3]!.page, 4);
    expect(remap.newPages, [2, 5]);
  });

  test('texte et miniature d\'une zone', () async {
    final doc = await openPdf(v1);
    final page = doc.pages.first;
    final text = await extractRegionText(
      page,
      const NormalizedRect(0, 0, 1, 0.3),
    );
    expect(text, contains('Cayley-Hamilton'));
    final png = await renderRegionPng(
      page,
      const NormalizedRect(0, 0, 1, 0.3),
      targetWidth: 400,
    );
    expect(png, isNotNull);
    expect(png!.sublist(1, 4), 'PNG'.codeUnits);
    await doc.dispose();
  });

  test('zone coupant une ligne : ligne entière ou rien (ticket #4)', () async {
    final doc = await openPdf(v1);
    final page = doc.pages.first;
    // La ligne du théorème occupe environ 0,117 à 0,127 de la hauteur.
    const line =
        'Théorème (Cayley-Hamilton). Le polynôme caractéristique annule u.';
    Future<String?> from(double top) =>
        extractRegionText(page, NormalizedRect(0, top, 1, 0.3));
    expect(await from(0.12), line);
    // Bord au milieu de la ligne : autrefois « orme (ayey-amton)… ».
    expect(await from(0.123), isNull);
    expect(await from(0.124), isNull);
    await doc.dispose();
  });

  test('filigrane en travers de la page ignoré (ticket #9)', () async {
    final doc = await openPdf(
      File('test/fixtures/filigrane.pdf').readAsBytesSync(),
    );
    final text = await doc.pages.first.loadStructuredText();
    expect(text.fullText, startsWith('Auteur : Filigrane'));
    // Un caractère du texte courant recouvert par une lettre du filigrane.
    int? body, mark;
    for (var i = 20; i < text.charRects.length && body == null; i++) {
      final r = text.charRects[i];
      if (text.fullText[i].trim().isEmpty) continue;
      final c = PdfPoint((r.left + r.right) / 2, (r.top + r.bottom) / 2);
      for (var j = 0; j < 18; j++) {
        if (text.charRects[j].containsPoint(c)) {
          (body, mark) = (i, j);
          break;
        }
      }
    }
    expect(body, isNotNull, reason: 'la fixture doit superposer les deux');
    final r = text.charRects[body!];
    final x = (r.left + r.right) / 2;
    final y = (r.top + r.bottom) / 2;
    // pdfrx aurait pris la lettre du filigrane (premier contenant)…
    expect(mark, lessThan(body));
    // … la recherche filtrée trouve le caractère visé.
    expect(charIndexAt(text, x, y), body);
    await doc.dispose();
  });

  test('les grandes lettres d\'un titre restent sélectionnables', () async {
    final doc = await openPdf(
      File('test/fixtures/filigrane.pdf').readAsBytesSync(),
    );
    final text = await doc.pages.first.loadStructuredText();
    final c = text.fullText.indexOf('Chapitre');
    expect(c, greaterThan(0));
    final r = text.charRects[c];
    final body = text.charRects[text.fullText.indexOf('Rolle')];
    expect(r.height, greaterThan(3 * body.height), reason: 'titre démesuré');
    expect(
      charIndexAt(text, (r.left + r.right) / 2, (r.top + r.bottom) / 2),
      c,
    );
    await doc.dispose();
  });
}
