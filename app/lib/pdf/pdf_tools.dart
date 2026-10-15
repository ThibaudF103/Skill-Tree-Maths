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
///
/// Décision par ligne : une ligne est retenue si au moins la moitié de sa
/// hauteur est dans la zone (sinon, un bord passant au milieu d'une ligne
/// laisserait passer ses seules lettres basses : « e », « a »…), puis ses
/// caractères dont le centre est dans la largeur de la zone.
Future<String?> extractRegionText(PdfPage page, NormalizedRect region) async {
  final text = await page.loadText();
  if (text == null || text.fullText.isEmpty) return null;
  final chars = text.fullText;
  final count = chars.length < text.charRects.length
      ? chars.length
      : text.charRects.length;
  final buffer = StringBuffer();
  var start = 0;
  while (start < count) {
    var end = start;
    while (end < count && chars[end] != '\n') {
      end++;
    }
    // Étendue verticale de la ligne (coordonnées PDF : origine en bas).
    double? top, bottom;
    for (var i = start; i < end; i++) {
      final r = text.charRects[i];
      if (r.top == r.bottom || chars[i].trim().isEmpty) continue;
      final t = 1 - r.top / page.height;
      final b = 1 - r.bottom / page.height;
      top = top == null || t < top ? t : top;
      bottom = bottom == null || b > bottom ? b : bottom;
    }
    if (top != null && bottom != null) {
      final overlap =
          (bottom < region.bottom ? bottom : region.bottom) -
          (top > region.top ? top : region.top);
      if (overlap >= (bottom - top) / 2) {
        for (var i = start; i < end; i++) {
          final r = text.charRects[i];
          final cx = (r.left + r.right) / 2 / page.width;
          final inside = cx >= region.left && cx <= region.right;
          buffer.write(inside ? chars[i] : ' ');
        }
        buffer.write(' ');
      }
    }
    start = end + 1;
  }
  final result = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  return result.isEmpty ? null : result;
}

/// Bornes `[début, fin[` du mot contenant le caractère [index], sans sortir
/// de `[from, to[`. Un mot s'arrête aux espaces, à la ponctuation, ou à un
/// écart visuel entre deux caractères (PDF sans caractères d'espace, où un
/// « fragment » couvre parfois une ligne entière).
(int, int) wordBounds(
  String chars,
  List<({double left, double right, double height})> boxes,
  int index, {
  int from = 0,
  int? to,
}) {
  final end = to ?? chars.length;
  bool separator(int i) => _wordSeparators.contains(chars[i]);
  bool gap(int i) {
    // Écart entre les caractères i et i + 1.
    final a = boxes[i];
    final b = boxes[i + 1];
    final h = a.height > b.height ? a.height : b.height;
    return b.left - a.right > 0.25 * h;
  }

  if (separator(index)) return (index, index + 1);
  var start = index;
  while (start > from && !separator(start - 1) && !gap(start - 1)) {
    start--;
  }
  var stop = index + 1;
  while (stop < end && !separator(stop) && !gap(stop - 1)) {
    stop++;
  }
  return (start, stop);
}

const _wordSeparators = ' \t\r\n.,;:!?()[]{}«»"\'’';
