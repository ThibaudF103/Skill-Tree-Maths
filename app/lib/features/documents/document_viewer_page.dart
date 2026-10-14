import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../pdf/pdf_tools.dart';
import '../items/item_detail_page.dart';
import '../items/item_editor.dart';
import 'pickers.dart';

/// Couleurs des ancres : recto (cours) et verso (notes).
const rectoColor = Color(0xFF3F7CAC);
const versoColor = Color(0xFFE09A3E);

/// Visionneuse d'un PDF de la bibliothèque.
///
/// Mode « Encadrer » : tracer un rectangle sur une page pour créer une
/// connaissance (recto) ou attacher la zone comme recto / verso.
class DocumentViewerPage extends StatefulWidget {
  const DocumentViewerPage({
    super.key,
    required this.documentId,
    this.initialPage = 1,
    this.highlight,
    this.selecting = false,
    this.attachToItem,
  });

  final String documentId;
  final int initialPage;

  /// Zone à mettre en évidence sur [initialPage].
  final NormalizedRect? highlight;

  /// Ouvrir directement en mode « Encadrer ».
  final bool selecting;

  /// Connaissance à laquelle attacher directement la zone encadrée (recto
  /// pour un cours, verso pour des notes), sans passer par le choix.
  final KnowledgeItem? attachToItem;

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  final _controller = PdfViewerController();
  Future<Uint8List?>? _bytes;
  Stream<List<SourceDocument>>? _documents;
  Stream<List<Anchor>>? _anchors;
  late bool _selecting = widget.selecting;
  late int? _page = widget.initialPage;

  // Rectangle en cours de tracé : page et coins normalisés.
  int? _dragPage;
  Offset? _dragStart;
  Offset? _dragEnd;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context).store;
    _bytes ??= store.documentBytes(widget.documentId);
    _documents ??= store.watchDocuments();
    _anchors ??= store.watchAnchors(documentId: widget.documentId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SourceDocument>>(
      stream: _documents,
      builder: (context, snapshot) {
        final document = snapshot.data
            ?.where((d) => d.id == widget.documentId)
            .firstOrNull;
        if (document == null) {
          return Scaffold(
            appBar: AppBar(),
            body: snapshot.hasData
                ? const Center(child: Text('Document supprimé'))
                : const Center(child: CircularProgressIndicator()),
          );
        }
        return _buildDocument(context, document);
      },
    );
  }

  Widget _buildDocument(BuildContext context, SourceDocument document) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(document.title),
        actions: [
          if (document.newPages.isNotEmpty)
            TextButton.icon(
              onPressed: () => _goToNextNewPage(document),
              icon: const Icon(Icons.fiber_new_outlined),
              label: Text(
                document.newPages.length == 1
                    ? '1 nouvelle page'
                    : '${document.newPages.length} nouvelles pages',
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: const Icon(Icons.crop_free, size: 18),
              label: const Text('Encadrer'),
              selected: _selecting,
              onSelected: (value) => setState(() {
                _selecting = value;
                _clearDrag();
              }),
            ),
          ),
        ],
      ),
      body: FutureBuilder<Uint8List?>(
        future: _bytes,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bytes = snapshot.data;
          if (bytes == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Le PDF n\'est pas présent sur cet appareil.\n'
                  'Utilisez « Mettre à jour » dans l\'onglet Documents '
                  'pour le réimporter : les liens seront conservés.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            );
          }
          return StreamBuilder<List<Anchor>>(
            stream: _anchors,
            builder: (context, anchors) => Stack(
              children: [
                PdfViewer.data(
                  bytes,
                  sourceName: 'verger-${document.id}-v${document.version}',
                  controller: _controller,
                  initialPageNumber: widget.initialPage.clamp(
                    1,
                    document.pageCount,
                  ),
                  params: PdfViewerParams(
                    panEnabled: !_selecting,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    onPageChanged: (page) => setState(() => _page = page),
                    pageOverlaysBuilder: (context, pageRect, page) => [
                      _overlay(page, document, anchors.data ?? const []),
                    ],
                  ),
                ),
                if (_selecting)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Center(
                      child: Material(
                        color: theme.colorScheme.inverseSurface,
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Text(
                            'Tracez un rectangle autour de l\'énoncé ou de la rédaction',
                            style: TextStyle(
                              color: theme.colorScheme.onInverseSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_page != null)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Chip(
                      label: Text('p. $_page / ${document.pageCount}'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Calque d'une page : ancres existantes, zone mise en évidence, page
  /// nouvelle, rectangle en cours de tracé.
  Widget _overlay(PdfPage page, SourceDocument document, List<Anchor> anchors) {
    final number = page.pageNumber;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        Rect toRect(NormalizedRect r) => Rect.fromLTRB(
          r.left * size.width,
          r.top * size.height,
          r.right * size.width,
          r.bottom * size.height,
        );
        Offset normalize(Offset p) => Offset(
          (p.dx / size.width).clamp(0.0, 1.0),
          (p.dy / size.height).clamp(0.0, 1.0),
        );

        final children = <Widget>[
          for (final anchor in anchors)
            if (anchor.page == number && anchor.region != null)
              Positioned.fromRect(
                rect: toRect(anchor.region!),
                child: Tooltip(
                  message: anchor.role == AnchorRole.source ? 'Recto' : 'Verso',
                  child: GestureDetector(
                    onTap: _selecting ? null : () => _openItem(anchor.itemId),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color:
                            (anchor.role == AnchorRole.source
                                    ? rectoColor
                                    : versoColor)
                                .withValues(alpha: 0.08),
                        border: Border.all(
                          color: anchor.role == AnchorRole.source
                              ? rectoColor
                              : versoColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          if (widget.highlight != null && number == widget.initialPage)
            Positioned.fromRect(
              rect: toRect(widget.highlight!).inflate(4),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.redAccent, width: 3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          if (document.newPages.contains(number))
            const Positioned(
              left: 8,
              top: 8,
              child: IgnorePointer(
                child: Chip(
                  label: Text('Nouvelle page'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          if (_selecting)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => setState(() {
                  _dragPage = number;
                  _dragStart = normalize(d.localPosition);
                  _dragEnd = _dragStart;
                }),
                onPanUpdate: (d) => setState(() {
                  if (_dragPage == number) {
                    _dragEnd = normalize(d.localPosition);
                  }
                }),
                onPanEnd: (_) => _finishDrag(page),
              ),
            ),
          if (_dragPage == number && _dragStart != null && _dragEnd != null)
            Positioned.fromRect(
              rect: Rect.fromPoints(
                Offset(
                  _dragStart!.dx * size.width,
                  _dragStart!.dy * size.height,
                ),
                Offset(_dragEnd!.dx * size.width, _dragEnd!.dy * size.height),
              ),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: rectoColor.withValues(alpha: 0.12),
                    border: Border.all(color: rectoColor, width: 2),
                  ),
                ),
              ),
            ),
        ];
        return Stack(children: children);
      },
    );
  }

  void _clearDrag() {
    _dragPage = null;
    _dragStart = null;
    _dragEnd = null;
  }

  Future<void> _finishDrag(PdfPage page) async {
    final start = _dragStart;
    final end = _dragEnd;
    if (start == null || end == null) return;
    final region = NormalizedRect.fromCorners(
      start.dx,
      start.dy,
      end.dx,
      end.dy,
    );
    if (region.width < 0.02 || region.height < 0.01) {
      setState(_clearDrag);
      return;
    }
    await _onRegionSelected(page, region);
    if (mounted) setState(_clearDrag);
  }

  Future<void> _onRegionSelected(PdfPage page, NormalizedRect region) async {
    final store = AppScope.of(context).store;
    final document = await store.document(widget.documentId);
    if (document == null || !mounted) return;
    final isCourse = document.role == DocumentRole.course;
    final target = widget.attachToItem;
    final action = target != null
        ? (isCourse ? 'source' : 'work')
        : await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCourse)
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: const Text(
                        'Créer une connaissance avec cet énoncé',
                      ),
                      subtitle: const Text('La zone devient son recto'),
                      onTap: () => Navigator.pop(context, 'create'),
                    ),
                  ListTile(
                    leading: const Icon(Icons.flip_to_front, color: rectoColor),
                    title: const Text('Attacher comme recto (énoncé)…'),
                    onTap: () => Navigator.pop(context, 'source'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.flip_to_back, color: versoColor),
                    title: const Text('Attacher comme verso (rédaction)…'),
                    onTap: () => Navigator.pop(context, 'work'),
                  ),
                ],
              ),
            ),
          );
    if (action == null || !mounted) return;

    final snapshot = await renderRegionPng(page, region);
    final text = isCourse ? await extractRegionText(page, region) : null;
    if (!mounted) return;

    KnowledgeItem? item = target;
    if (target != null) {
      // Connaissance déjà choisie.
    } else if (action == 'create') {
      final node = await pickNode(context, title: 'Dans quelle branche ?');
      if (node == null || !mounted) return;
      item = await showItemEditor(
        context,
        nodeId: node.id,
        family: ItemFamily.statement,
        initialTitle: _suggestTitle(text),
        initialBody: text,
      );
    } else {
      item = await pickItem(
        context,
        title: action == 'work'
            ? 'Verso de quelle connaissance ?'
            : 'Recto de quelle connaissance ?',
      );
    }
    if (item == null || !mounted) return;
    await store.addAnchor(
      itemId: item.id,
      documentId: widget.documentId,
      role: action == 'work' ? AnchorRole.work : AnchorRole.source,
      page: page.pageNumber,
      region: region,
      textSnippet: text,
      snapshot: snapshot,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${action == 'work' ? 'Verso' : 'Recto'} attaché à « ${item.title} ».',
        ),
      ),
    );
    if (target != null) Navigator.of(context).pop();
  }

  /// Première ligne du texte extrait, raccourcie : bon titre par défaut.
  static String? _suggestTitle(String? text) {
    if (text == null) return null;
    final sentence = text
        .split(RegExp(r'(?<=[.:])\s'))
        .first
        .trim()
        .replaceFirst(RegExp(r'[.:]$'), '');
    return sentence.length <= 80 ? sentence : '${sentence.substring(0, 77)}…';
  }

  void _goToNextNewPage(SourceDocument document) {
    final current = _page ?? 0;
    final next = document.newPages.firstWhere(
      (p) => p > current,
      orElse: () => document.newPages.first,
    );
    _controller.goToPage(pageNumber: next);
  }

  void _openItem(String itemId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ItemDetailPage(itemId: itemId)),
    );
  }
}
