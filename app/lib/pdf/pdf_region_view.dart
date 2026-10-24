import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

/// Contenu (fiche) et fichier d'un PDF ; l'un ou l'autre peut manquer.
typedef PdfFile = ({SourceDocument? document, Uint8List? bytes});

/// Contenu des PDF récemment affichés en zones, pour ne pas relire la base
/// à chaque carte (quelques documents au plus). Clé : document et version,
/// pour ne pas afficher l'ancienne version après une mise à jour.
class _PdfBytesCache {
  static final _entries = <String, Future<Uint8List?>>{};

  static Future<PdfFile> load(VergerStore store, String documentId) async {
    final document = await store.document(documentId);
    if (document == null) return (document: null, bytes: null);
    final key = '${document.id}-v${document.version}';
    final future = _entries.remove(key) ?? store.documentBytes(documentId);
    _entries[key] = future; // le plus récent en dernier
    while (_entries.length > 3) {
      _entries.remove(_entries.keys.first);
    }
    final bytes = await future;
    // Pas de fichier : réessayer après un import (même version).
    if (bytes == null) _entries.remove(key);
    return (document: document, bytes: bytes);
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
/// sert de secours si le PDF n'est plus sur l'appareil. Sans elle, une zone
/// qui ne peut pas s'afficher dit pourquoi (PDF absent, page introuvable…).
class PdfRegionView extends StatefulWidget {
  const PdfRegionView({
    super.key,
    required this.store,
    required this.documentId,
    required this.page,
    required this.region,
    required this.snapshot,
    this.onMissingFile,
  });

  final VergerStore store;
  final String documentId;
  final int page;
  final NormalizedRect region;
  final Uint8List? snapshot;

  /// Proposé quand le fichier du PDF manque (paquet dont le PDF n'a pas pu
  /// être téléchargé) : l'importer. La zone est rechargée ensuite.
  final Future<void> Function(SourceDocument document)? onMissingFile;

  /// Rendu vectoriel actif (désactivé dans les tests de widgets, sans
  /// PDFium) ; sinon, seule la miniature est affichée.
  static var vectorEnabled = true;

  @override
  State<PdfRegionView> createState() => _PdfRegionViewState();
}

class _PdfRegionViewState extends State<PdfRegionView> {
  late Future<PdfFile> _pdf = _PdfBytesCache.load(
    widget.store,
    widget.documentId,
  );
  final _controller = PdfViewerController();
  var _ready = false;
  double? _aspect;

  /// Échec du rendu vectoriel (PDF illisible, page absente).
  String? _error;

  @override
  void didUpdateWidget(PdfRegionView old) {
    super.didUpdateWidget(old);
    if (old.documentId != widget.documentId) {
      _reload();
    } else if (old.page != widget.page || old.region != widget.region) {
      // Autre zone : proportions à recalculer, puis cadrage.
      _error = null;
      _aspect = _measure();
      _frame();
    }
  }

  void _reload() {
    _pdf = _PdfBytesCache.load(widget.store, widget.documentId);
    _ready = false;
    _aspect = null;
    _error = null;
  }

  /// Proportions exactes de la zone (sans arrondi PNG), une fois le PDF
  /// chargé ; `null` si la page n'existe pas.
  double? _measure() {
    if (!_controller.isReady || widget.page > _controller.pageCount) {
      return null;
    }
    final page = _controller.pages[widget.page - 1];
    final r = widget.region;
    if (r.height <= 0) return null;
    return r.width * page.width / (r.height * page.height);
  }

  /// Cadre la vue exactement sur la zone.
  void _frame() {
    if (!_controller.isReady || widget.page > _controller.pageCount) return;
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

  Future<void> _importMissing(SourceDocument document) async {
    await widget.onMissingFile!(document);
    if (mounted) setState(_reload);
  }

  /// Pourquoi la zone ne peut pas s'afficher en vectoriel, ou `null`.
  _Problem? _problem(AsyncSnapshot<PdfFile> snapshot) {
    if (snapshot.hasError) {
      return const _Problem('Lecture du PDF impossible');
    }
    final file = snapshot.data;
    if (file == null) return null; // chargement
    final document = file.document;
    if (document == null) return const _Problem('Contenu supprimé');
    if (file.bytes == null) {
      return _Problem(
        'PDF absent de cet appareil',
        detail:
            'Importez « ${document.title} » (Bibliothèque › Mettre à jour) : '
            'ses recto et verso s\'afficheront.',
        document: document,
      );
    }
    if (document.pageCount > 0 && widget.page > document.pageCount) {
      return _Problem(
        'Page ${widget.page} introuvable',
        detail: document.pageCount == 1
            ? 'Le PDF n\'a qu\'une page.'
            : 'Le PDF n\'a que ${document.pageCount} pages.',
      );
    }
    if (widget.region.width <= 0 || widget.region.height <= 0) {
      return const _Problem('Zone vide');
    }
    if (_error != null) return _Problem(_error!);
    if (!PdfRegionView.vectorEnabled) {
      return const _Problem('Aperçu indisponible');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.snapshot == null
        ? null
        : Image.memory(
            widget.snapshot!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          );
    return FutureBuilder<PdfFile>(
      future: _pdf,
      builder: (context, snapshot) {
        final problem = _problem(snapshot);
        // La miniature, quand il y en a une, reste le meilleur secours.
        final fallback =
            image ??
            (problem == null
                ? const _Loading()
                : _Unavailable(
                    problem: problem,
                    onImport:
                        problem.document == null || widget.onMissingFile == null
                        ? null
                        : () => _importMissing(problem.document!),
                  ));
        final file = snapshot.data;
        final bytes = file?.bytes;
        if (problem != null || file == null || bytes == null) return fallback;
        // Sans miniature (zone importée d'un paquet), proportions estimées
        // pour une page A4 portrait, corrigées dès que la page est chargée.
        final r = widget.region;
        final aspect =
            _aspect ??
            pngAspectRatio(widget.snapshot) ??
            r.width / r.height / math.sqrt2;
        final document = file.document!;
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
                    // Échec silencieux auparavant : la zone restait vide
                    // ou sur l'icône de chargement.
                    onDocumentLoadFinished: (_, succeeded) {
                      if (!succeeded && mounted) {
                        setState(() => _error = 'PDF illisible');
                      }
                    },
                    onViewerReady: (_, controller) {
                      if (widget.page > controller.pageCount) {
                        setState(
                          () => _error = 'Page ${widget.page} introuvable',
                        );
                        return;
                      }
                      // Proportions exactes, puis cadrage, puis affichage :
                      // pas d'éclair de la page entière.
                      setState(() => _aspect = _measure());
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

/// Raison pour laquelle une zone ne s'affiche pas. [document] : PDF dont le
/// fichier manque, à importer.
class _Problem {
  const _Problem(this.message, {this.detail, this.document});
  final String message;
  final String? detail;
  final SourceDocument? document;
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 60,
    child: Center(
      child: SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

/// Zone indisponible : la raison plutôt qu'un cadre vide. Sur fond blanc
/// (celui des pages), quel que soit le thème.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.problem, this.onImport});

  final _Problem problem;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, color: Colors.black45),
          const SizedBox(height: 6),
          Text(
            problem.message,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(color: Colors.black87),
          ),
          if (problem.detail != null) ...[
            const SizedBox(height: 4),
            Text(
              problem.detail!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ],
          if (onImport != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file),
              label: const Text('Importer le PDF…'),
            ),
          ],
        ],
      ),
    );
  }
}
