import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

/// Contenu des PDF récemment affichés en zones, pour ne pas relire la base
/// à chaque carte (quelques documents au plus).
class _PdfBytesCache {
  static final _entries = <String, Future<(SourceDocument, Uint8List)?>>{};

  static Future<(SourceDocument, Uint8List)?> load(
    VergerStore store,
    String documentId,
  ) {
    final cached = _entries.remove(documentId);
    final future = cached ?? _read(store, documentId);
    _entries[documentId] = future; // le plus récent en dernier
    while (_entries.length > 3) {
      _entries.remove(_entries.keys.first);
    }
    return future;
  }

  static Future<(SourceDocument, Uint8List)?> _read(
    VergerStore store,
    String documentId,
  ) async {
    final document = await store.document(documentId);
    final bytes = await store.documentBytes(documentId);
    if (document == null || bytes == null) {
      _entries.remove(documentId); // réessayer après un réimport
      return null;
    }
    return (document, bytes);
  }
}

/// Rapport largeur / hauteur d'une image PNG (en-tête IHDR), ou `null`.
double? pngAspectRatio(Uint8List? png) {
  if (png == null || png.length < 24) return null;
  final data = ByteData.sublistView(png);
  final width = data.getUint32(16);
  final height = data.getUint32(20);
  return width > 0 && height > 0 ? width / height : null;
}

/// Zone d'un PDF affichée en vectoriel, texte sélectionnable (copier-coller),
/// figée sur la zone. L'image [snapshot] s'affiche pendant le chargement et
/// sert de secours si le PDF n'est plus sur l'appareil.
class PdfRegionView extends StatefulWidget {
  const PdfRegionView({
    super.key,
    required this.store,
    required this.documentId,
    required this.page,
    required this.region,
    required this.snapshot,
  });

  final VergerStore store;
  final String documentId;
  final int page;
  final NormalizedRect region;
  final Uint8List? snapshot;

  /// Rendu vectoriel actif (désactivé dans les tests de widgets, sans
  /// PDFium) ; sinon, seule la miniature est affichée.
  static var vectorEnabled = true;

  @override
  State<PdfRegionView> createState() => _PdfRegionViewState();
}

class _PdfRegionViewState extends State<PdfRegionView> {
  late Future<(SourceDocument, Uint8List)?> _pdf = _PdfBytesCache.load(
    widget.store,
    widget.documentId,
  );
  final _controller = PdfViewerController();
  var _ready = false;
  double? _aspect;

  @override
  void didUpdateWidget(PdfRegionView old) {
    super.didUpdateWidget(old);
    if (old.documentId != widget.documentId) {
      _pdf = _PdfBytesCache.load(widget.store, widget.documentId);
      _ready = false;
    } else if (old.page != widget.page || old.region != widget.region) {
      _frame();
    }
  }

  /// Cadre la vue exactement sur la zone.
  void _frame() {
    if (!_controller.isReady) return;
    final page = _controller.pages[widget.page - 1];
    final r = widget.region;
    final rect = _controller.calcRectForRectInsidePage(
      pageNumber: widget.page,
      rect: PdfRect(
        r.left * page.width,
        (1 - r.top) * page.height,
        r.right * page.width,
        (1 - r.bottom) * page.height,
      ),
    );
    _controller.goTo(
      _controller.calcMatrixForRect(rect, zoomMax: 50, margin: 0),
      duration: Duration.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.snapshot == null
        ? const SizedBox(
            height: 60,
            child: Center(child: Icon(Icons.image_not_supported_outlined)),
          )
        : Image.memory(
            widget.snapshot!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          );
    return FutureBuilder<(SourceDocument, Uint8List)?>(
      future: _pdf,
      builder: (context, snapshot) {
        final pdf = snapshot.data;
        // Sans miniature (zone importée d'un paquet), proportions estimées
        // pour une page A4 portrait, corrigées dès que la page est chargée.
        final r = widget.region;
        final aspect =
            _aspect ??
            pngAspectRatio(widget.snapshot) ??
            (r.height > 0 ? r.width / r.height / math.sqrt2 : null);
        if (!PdfRegionView.vectorEnabled || pdf == null || aspect == null) {
          return fallback;
        }
        final (document, bytes) = pdf;
        return AspectRatio(
          aspectRatio: aspect,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!_ready) fallback,
              Opacity(
                opacity: _ready ? 1 : 0,
                child: PdfViewer.data(
                  bytes,
                  // Même nom que la visionneuse : document partagé.
                  sourceName: 'verger-${document.id}-v${document.version}',
                  controller: _controller,
                  initialPageNumber: widget.page,
                  params: PdfViewerParams(
                    margin: 0,
                    panEnabled: false,
                    scaleEnabled: false,
                    sizeDelegateProvider:
                        const PdfViewerSizeDelegateProviderLegacy(
                          maxScale: 50,
                          useAlternativeFitScaleAsMinScale: false,
                        ),
                    scrollByMouseWheel: null,
                    enableKeyboardNavigation: false,
                    backgroundColor: Colors.white,
                    onViewerReady: (_, controller) {
                      if (widget.page > controller.pageCount) return;
                      final page = controller.pages[widget.page - 1];
                      final r = widget.region;
                      // Proportions exactes de la zone (sans arrondi PNG),
                      // puis cadrage, puis affichage : pas d'éclair de la
                      // page entière.
                      setState(
                        () => _aspect =
                            r.width * page.width / (r.height * page.height),
                      );
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _frame();
                        Future<void>.delayed(
                          const Duration(milliseconds: 50),
                          () {
                            if (mounted) setState(() => _ready = true);
                          },
                        );
                      });
                    },
                    onViewSizeChanged: (_, _, _) =>
                        Future<void>.delayed(Duration.zero, _frame),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
