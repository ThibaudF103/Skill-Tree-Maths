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
}
