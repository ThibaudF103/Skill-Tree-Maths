import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../ui/math_text.dart';

/// Image d'un texte, et sa taille en points (1 point = 1 pixel logique).
typedef RasterImage = ({Uint8List png, double width, double height});

/// Dessine un texte (LaTeX entre `$…$`) en image, sur [width] points de
/// large au plus.
typedef MathRasterizer =
    Future<RasterImage> Function(
      String source, {
      required double width,
      double fontSize,
      bool bold,
    });

/// Dessine le texte hors de l'écran, avec le rendu de [MathText] : les
/// formules d'une fiche imprimée sont celles de l'application.
Future<RasterImage> rasterizeMath(
  String source, {
  required double width,
  double fontSize = 11,
  bool bold = false,
  double pixelRatio = 2.5,
}) async {
  final boundary = RenderRepaintBoundary();
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final renderView = RenderView(
    view: view,
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints(maxWidth: width, maxHeight: 4000),
    ),
    child: RenderPositionedBox(alignment: Alignment.topLeft, child: boundary),
  );
  final pipeline = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final focusManager = FocusManager();
  final buildOwner = BuildOwner(focusManager: focusManager);
  final style = TextStyle(
    color: Colors.black,
    fontSize: fontSize,
    height: 1.3,
    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
  );
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData.light(),
          child: DefaultTextStyle(
            style: style,
            // Une formule fautive s'affiche avec une bulle d'aide, qui
            // demande un Overlay.
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (_) => Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: width),
                      child: MathText(source, style: style),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ).attachToRenderTree(buildOwner);
  try {
    buildOwner
      ..buildScope(root)
      ..finalizeTree();
    pipeline
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    final size = boundary.size;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return (
      png: data!.buffer.asUint8List(),
      width: size.width,
      height: size.height,
    );
  } finally {
    // Démonte l'arbre hors écran.
    RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
    ).attachToRenderTree(buildOwner, root);
    buildOwner.finalizeTree();
    pipeline
      ..rootNode = null
      ..dispose();
    focusManager.dispose();
  }
}
