import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:verger_core/verger_core.dart';

/// Résultat de l'analyse d'un PDF à l'import ou à la mise à jour.
typedef PdfAnalysis = ({
  int pageCount,
  String contentHash,
  List<Uint8List> fingerprints,
});

/// Ouvre un PDF depuis son contenu.
Future<PdfDocument> openPdf(Uint8List bytes, {String name = 'document.pdf'}) =>
    PdfDocument.openData(bytes, sourceName: '$name#${bytes.length}');

/// Calcule l'empreinte SHA-256 et l'empreinte visuelle de chaque page.
Future<PdfAnalysis> analyzePdf(
  Uint8List bytes, {
  void Function(int done, int total)? onProgress,
}) async {
  final document = await openPdf(bytes);
  try {
    final fingerprints = <Uint8List>[];
    final pages = document.pages;
    for (final (i, page) in pages.indexed) {
      fingerprints.add(await pageFingerprint(page));
      onProgress?.call(i + 1, pages.length);
    }
    return (
      pageCount: pages.length,
      contentHash: sha256.convert(bytes).toString(),
      fingerprints: fingerprints,
    );
  } finally {
    await document.dispose();
  }
}

/// Page réduite à [fingerprintSide]² niveaux de gris (fond blanc).
Future<Uint8List> pageFingerprint(PdfPage page) async {
  const side = fingerprintSide;
  final image = await page.render(
    width: side,
    height: side,
    fullWidth: side.toDouble(),
    fullHeight: side.toDouble(),
    backgroundColor: 0xffffffff,
    annotationRenderingMode: PdfAnnotationRenderingMode.annotation,
  );
  if (image == null) {
    return Uint8List(side * side)..fillRange(0, side * side, 255);
  }
  try {
    final bgra = image.pixels;
    final gray = Uint8List(side * side);
    for (var i = 0; i < gray.length; i++) {
      final b = bgra[i * 4];
      final g = bgra[i * 4 + 1];
      final r = bgra[i * 4 + 2];
      gray[i] = (0.299 * r + 0.587 * g + 0.114 * b).round();
    }
    return gray;
  } finally {
    image.dispose();
  }
}

/// Miniature PNG d'une zone de page (page entière si [region] est nul), de
/// largeur [targetWidth] pixels environ.
Future<Uint8List?> renderRegionPng(
  PdfPage page,
  NormalizedRect? region, {
  int targetWidth = 900,
}) async {
  final r = region ?? const NormalizedRect(0, 0, 1, 1);
  if (r.width <= 0 || r.height <= 0) return null;
  // Échelle : la zone fait [targetWidth] pixels de large, sans dépasser
  // 4000 pixels dans aucune dimension (zones hautes et étroites).
  var fullWidth = targetWidth / r.width;
  var fullHeight = fullWidth * page.height / page.width;
  final tallest = r.height * fullHeight;
  if (tallest > 4000) {
    fullWidth *= 4000 / tallest;
    fullHeight *= 4000 / tallest;
  }
  final width = (r.width * fullWidth).round().clamp(1, 4000);
  final height = (r.height * fullHeight).round().clamp(1, 4000);
  final image = await page.render(
    x: (r.left * fullWidth).round(),
    y: (r.top * fullHeight).round(),
    width: width,
    height: height,
    fullWidth: fullWidth,
    fullHeight: fullHeight,
    backgroundColor: 0xffffffff,
  );
  if (image == null) return null;
  try {
    final uiImage = await image.createImage();
    final data = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    uiImage.dispose();
    return data?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Texte de la page situé dans [region] (PDF de cours), ou `null`.
Future<String?> extractRegionText(PdfPage page, NormalizedRect region) async {
  final text = await page.loadText();
  if (text == null || text.fullText.isEmpty) return null;
  final buffer = StringBuffer();
  for (var i = 0; i < text.fullText.length && i < text.charRects.length; i++) {
    final rect = text.charRects[i];
    // Coordonnées PDF : origine en bas à gauche.
    final cx = (rect.left + rect.right) / 2 / page.width;
    final cy = 1 - (rect.top + rect.bottom) / 2 / page.height;
    final char = text.fullText[i];
    final inside =
        cx >= region.left &&
        cx <= region.right &&
        cy >= region.top &&
        cy <= region.bottom;
    if (inside || (char == '\n' || char == ' ') && buffer.isNotEmpty) {
      buffer.write(inside ? char : ' ');
    }
  }
  final result = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  return result.isEmpty ? null : result;
}
