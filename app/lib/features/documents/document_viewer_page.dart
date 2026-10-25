import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import '../../app/app_scope.dart';
import '../../pdf/pdf_tools.dart';
import '../../ui/coverage.dart';
import '../../ui/labels.dart';
import '../items/item_detail_page.dart';
import '../items/item_editor.dart';
import '../notes/note_split.dart';
import '../notes/notes_panel.dart';
import 'pickers.dart';
import 'viewer_gestures.dart';

/// Couleurs des ancres : recto (cours) et verso (notes).
const rectoColor = Color(0xFF3F7CAC);
const versoColor = Color(0xFFE09A3E);
const noteColor = Color(0xFF5B7F5E);

enum _SidePanel { none, pages, outline }

/// Visionneuse d'un PDF de la bibliothèque.
///
/// - Panneau latéral : miniatures des pages, sommaire du PDF.
/// - Recherche dans le texte.
/// - Reprise de lecture à la dernière page consultée.
/// - Mode « Encadrer » : tracer un rectangle pour prendre une note sur la
///   zone, créer une connaissance (recto) ou attacher la zone ; tirer les
///   bords d'un cadre existant pour le redimensionner.
/// - Sur ordinateur : barre de défilement, défilement au bouton du milieu.
/// - Panneau de notes sous le PDF, à hauteur réglable (bouton, balayage
///   depuis le bord droit, ou marqueur sur la page).
class DocumentViewerPage extends StatefulWidget {
  const DocumentViewerPage({
    super.key,
    required this.documentId,
    this.initialPage,
    this.highlight,
    this.selecting = false,
    this.attachToItem,
    this.openNoteId,
  });

  final String documentId;

  /// Page d'ouverture ; par défaut, la dernière page consultée.
  final int? initialPage;

  /// Zone à mettre en évidence sur [initialPage].
  final NormalizedRect? highlight;

  /// Ouvrir directement en mode « Encadrer ».
  final bool selecting;

  /// Connaissance à laquelle attacher directement la zone encadrée (recto
  /// pour un cours, verso pour des notes), sans passer par le choix.
  final KnowledgeItem? attachToItem;

  /// Note à ouvrir dans le panneau de notes.
  final String? openNoteId;

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  final _controller = PdfViewerController();
  final _viewerKey = GlobalKey();
  final _notesKey = GlobalKey();

  /// Créé une fois la visionneuse prête (il s'appuie sur le document).
  PdfTextSearcher? _searcher;
  final _query = TextEditingController();
  late VergerStore _store;
  Future<Uint8List?>? _bytes;
  Stream<List<SourceDocument>>? _documents;
  Stream<List<Anchor>>? _anchors;

  /// Ancres du document pour la couverture des miniatures.
  Stream<List<Anchor>>? _coverage;
  StreamSubscription<List<Note>>? _notesSubscription;
  List<Note> _notes = const [];
  PdfDocument? _pdf;
  Future<List<PdfOutlineNode>>? _outline;
  Timer? _saveLastPage;

  late bool _selecting = widget.selecting;
  int? _startPage;
  int? _page;
  var _side = _SidePanel.none;
  var _searching = false;
  late bool _notesOpen = widget.openNoteId != null;
  late String? _activeNote = widget.openNoteId;

  // Rectangle en cours de tracé : page et coins normalisés.
  int? _dragPage;
  Offset? _dragStart;
  Offset? _dragEnd;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = AppScope.of(context).store;
    _bytes ??= _store.documentBytes(widget.documentId);
    _documents ??= _store.watchDocuments();
    _anchors ??= _store.watchAnchors(documentId: widget.documentId);
    _coverage ??= _store.watchAnchors(documentId: widget.documentId);
    _notesSubscription ??= _store
        .watchNotes(documentId: widget.documentId)
        .listen((notes) => setState(() => _notes = notes));
  }

  @override
  void dispose() {
    _notesSubscription?.cancel();
    _saveLastPage?.cancel();
    final page = _page;
    if (page != null) _store.setLastPage(widget.documentId, page);
    _searcher
      ?..removeListener(_onSearchChanged)
      ..dispose();
    _query.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _onPageChanged(int? page) {
    if (page == null) return;
    setState(() => _page = page);
    _saveLastPage?.cancel();
    _saveLastPage = Timer(
      const Duration(seconds: 1),
      () => _store.setLastPage(widget.documentId, page),
    );
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
        _startPage ??= (widget.initialPage ?? document.lastPage).clamp(
          1,
          document.pageCount,
        );
        _page ??= _startPage;
        return _buildDocument(context, document);
      },
    );
  }

  Widget _buildDocument(BuildContext context, SourceDocument document) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: Text(document.title),
        actions: [
          IconButton(
            tooltip: 'Pages et sommaire',
            isSelected: _side != _SidePanel.none,
            icon: const Icon(Icons.view_sidebar_outlined),
            onPressed: () => setState(
              () => _side = _side == _SidePanel.none
                  ? _SidePanel.pages
                  : _SidePanel.none,
            ),
          ),
          IconButton(
            tooltip: 'Rechercher dans le PDF',
            isSelected: _searching,
            icon: const Icon(Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _query.clear();
                _searcher?.resetTextSearch();
              }
            }),
          ),
          if (document.newPages.isNotEmpty)
            IconButton(
              tooltip: 'Nouvelle page suivante',
              icon: Badge(
                label: Text('${document.newPages.length}'),
                child: const Icon(Icons.fiber_new_outlined),
              ),
              onPressed: () => _goToNextNewPage(document),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              avatar: const Icon(Icons.crop_free, size: 18),
              label: const Text('Encadrer'),
              selected: _selecting,
              onSelected: (value) async {
                // Texte surligné : on encadre directement ce texte.
                if (value && await _frameSelectedText()) return;
                if (!mounted) return;
                setState(() {
                  _selecting = value;
                  _clearDrag();
                });
              },
            ),
          ),
          IconButton(
            tooltip: 'Notes',
            isSelected: _notesOpen,
            icon: Badge(
              isLabelVisible: _notes.isNotEmpty,
              label: Text('${_notes.length}'),
              child: const Icon(Icons.edit_note),
            ),
            onPressed: () => setState(() => _notesOpen = !_notesOpen),
          ),
          const SizedBox(width: 4),
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
                  'Utilisez « Mettre à jour » dans l\'onglet Bibliothèque '
                  'pour le réimporter : les liens seront conservés.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            );
          }
          final notes = _notes;
          // Clé globale : la visionneuse garde son état (page, zoom) quand la
          // mise en page change (rotation, redimensionnement).
          final viewer = KeyedSubtree(
            key: _viewerKey,
            child: _buildViewer(context, document, bytes, notes),
          );
          // Pas de balayage pour fermer : un trait du stylet dans la note ne
          // doit jamais la refermer.
          final notesPanel = KeyedSubtree(
            // Clé globale : l'éditeur de note survit au changement de mise en
            // page (rotation), sans perdre la saisie en cours.
            key: _notesKey,
            child: NotesPanel(
              document: document,
              notes: notes,
              activeNoteId: _activeNote,
              currentPage: _page ?? 1,
              onSelect: (id) => setState(() => _activeNote = id),
              onGoTo: (page, _) => _controller.goToPage(pageNumber: page),
            ),
          );
          final side = _side == _SidePanel.none
              ? null
              : _buildSidePanel(context, document);
          // Les notes s'ouvrent sous le PDF (écran partagé), qui reste
          // visible pendant la prise de note.
          return Column(
            children: [
              if (_searching) _buildSearchBar(context),
              Expanded(
                child: NoteSplit(
                  onClose: () => setState(() => _notesOpen = false),
                  note: _notesOpen ? notesPanel : null,
                  content: wide
                      ? Row(
                          children: [
                            if (side != null) ...[
                              SizedBox(width: 200, child: side),
                              const VerticalDivider(width: 1),
                            ],
                            Expanded(child: viewer),
                          ],
                        )
                      : Stack(
                          children: [
                            viewer,
                            if (side != null)
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                width: 200,
                                child: Material(elevation: 4, child: side),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildViewer(
    BuildContext context,
    SourceDocument document,
    Uint8List bytes,
    List<Note> notes,
  ) {
    final theme = Theme.of(context);
    return StreamBuilder<List<Anchor>>(
      stream: _anchors,
      builder: (context, anchors) => Stack(
        children: [
          // Clic molette : défilement automatique (aussi en mode
          // « Encadrer »).
          MiddleClickAutoscroll(
            onScroll: (delta) => _panBy(-delta),
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: (_) => _dragFrom = _dragTo = null,
              // Pavé tactile (deux doigts) : on fait défiler la page même en
              // mode « Encadrer », au lieu de tracer une zone.
              onPointerPanZoomUpdate: (event) {
                if (_selecting) _panBy(event.panDelta);
              },
              child: PdfViewer.data(
                bytes,
                // Par empreinte : partagé avec les zones du même fichier.
                sourceName: 'verger-${document.contentHash}',
                controller: _controller,
                initialPageNumber: _startPage ?? 1,
                params: PdfViewerParams(
                  panEnabled: !_selecting,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  onViewerReady: (pdf, controller) {
                    setState(() {
                      _pdf = pdf;
                      _outline = pdf.loadOutline();
                      _searcher ??= PdfTextSearcher(controller)
                        ..addListener(_onSearchChanged);
                    });
                  },
                  onPageChanged: _onPageChanged,
                  onViewSizeChanged: _onViewSizeChanged,
                  onGeneralTap: _onGeneralTap,
                  textSelectionParams: PdfTextSelectionParams(
                    onTextSelectionChange: _onTextSelectionChange,
                  ),
                  // Liens du PDF : sommaire, renvois, notes de bas de page, web.
                  linkHandlerParams: _selecting
                      ? null
                      : PdfLinkHandlerParams(onLinkTap: _onLinkTap),
                  pagePaintCallbacks: [
                    if (_searcher != null)
                      _searcher!.pageTextMatchPaintCallback,
                  ],
                  pageOverlaysBuilder: (context, pageRect, page) => [
                    _overlay(page, document, anchors.data ?? const [], notes),
                  ],
                  // Barre de défilement (ordinateur) : pdfrx reconstruit ce
                  // calque à chaque déplacement de la vue.
                  viewerOverlayBuilder: (context, size, handleLinkTap) => [
                    if (isDesktopPlatform && _controller.isReady)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: ScrollPassThrough(
                          onScroll: _controller.handlePointerSignalEvent,
                          // Reçu avant le Listener de la visionneuse : un
                          // glissé sur la barre n'est pas une sélection.
                          child: Listener(
                            onPointerDown: (e) => _scrollbarPointer = e.pointer,
                            child: ViewerScrollbar(
                              extent: _controller.documentSize.height,
                              viewport: _controller.visibleRect.height,
                              offset: _controller.visibleRect.top,
                              onScrollTo: _scrollTo,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_selecting || widget.attachToItem != null)
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
                      _selecting
                          ? 'Tracez un rectangle autour d\'un élément du PDF, '
                                'ou tirez les bords d\'un cadre'
                          : 'Allez à la bonne page, puis « Encadrer » '
                                '(ou surlignez le texte d\'abord)',
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
              // À gauche de la barre de défilement sur ordinateur.
              right: isDesktopPlatform ? 26 : 12,
              top: 12,
              child: Chip(label: Text('p. $_page / ${document.pageCount}')),
            ),
          // Balayer depuis le bord droit ouvre les notes.
          if (!_notesOpen && !_selecting)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 16,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) < -300) {
                    setState(() => _notesOpen = true);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final searcher = _searcher;
    final count = searcher?.matches.length ?? 0;
    final index = searcher?.currentIndex;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _query,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Rechercher dans le PDF',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (q) => searcher?.startTextSearch(q.trim()),
                onSubmitted: (_) => searcher?.goToNextMatch(),
              ),
            ),
            if (searcher?.isSearching ?? false)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (_query.text.trim().isNotEmpty)
              Text(
                count == 0 ? 'Aucun résultat' : '${(index ?? 0) + 1} / $count',
                style: theme.textTheme.labelLarge,
              ),
            IconButton(
              tooltip: 'Précédent',
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: count == 0 ? null : searcher!.goToPrevMatch,
            ),
            IconButton(
              tooltip: 'Suivant',
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: count == 0 ? null : searcher!.goToNextMatch,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidePanel(BuildContext context, SourceDocument document) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SegmentedButton<_SidePanel>(
            segments: const [
              ButtonSegment(value: _SidePanel.pages, label: Text('Pages')),
              ButtonSegment(value: _SidePanel.outline, label: Text('Sommaire')),
            ],
            selected: {_side},
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            onSelectionChanged: (s) => setState(() => _side = s.first),
          ),
        ),
        Expanded(
          child: _side == _SidePanel.pages
              ? _buildThumbnails(context, document)
              : FutureBuilder<List<PdfOutlineNode>>(
                  future: _outline,
                  builder: (context, snapshot) {
                    final rows = <(PdfOutlineNode, int)>[];
                    void visit(List<PdfOutlineNode> nodes, int depth) {
                      for (final n in nodes) {
                        rows.add((n, depth));
                        visit(n.children, depth + 1);
                      }
                    }

                    visit(snapshot.data ?? const [], 0);
                    if (rows.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          snapshot.connectionState == ConnectionState.done
                              ? 'Ce PDF n\'a pas de sommaire.'
                              : '…',
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final (node, depth) = rows[i];
                        final page = node.dest?.pageNumber;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.only(
                            left: 12.0 + depth * 12,
                            right: 8,
                          ),
                          title: Text(node.title, maxLines: 2),
                          trailing: page == null ? null : Text('$page'),
                          onTap: page == null
                              ? null
                              : () => _controller.goToPage(pageNumber: page),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildThumbnails(BuildContext context, SourceDocument document) {
    final theme = Theme.of(context);
    final pdf = _pdf;
    if (pdf == null) return const Center(child: CircularProgressIndicator());
    return StreamBuilder<List<Anchor>>(
      stream: _coverage,
      builder: (context, anchors) {
        final coverage = pageCoverage(anchors.data ?? const [], _notes);
        return _thumbnailList(theme, pdf, document, coverage);
      },
    );
  }

  Widget _thumbnailList(
    ThemeData theme,
    PdfDocument pdf,
    SourceDocument document,
    Map<int, PageCoverage> coverage,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: pdf.pages.length,
      itemBuilder: (context, i) {
        final number = i + 1;
        final current = number == _page;
        final covered = coverage[number];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _controller.goToPage(pageNumber: number),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: current
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      width: current ? 3 : 1,
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: pdf.pages[i].width / pdf.pages[i].height,
                    child: PdfPageView(
                      document: pdf,
                      pageNumber: number,
                      maximumDpi: 40,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      document.newPages.contains(number)
                          ? '$number · nouvelle'
                          : '$number',
                      style: theme.textTheme.labelSmall,
                    ),
                    // Couverture : ce qui a déjà été tiré de la page.
                    if (covered != null) ...[
                      if (covered.recto > 0)
                        _CoverageDot(rectoColor, covered.recto, 'recto'),
                      if (covered.verso > 0)
                        _CoverageDot(versoColor, covered.verso, 'verso'),
                      if (covered.notes > 0)
                        _CoverageDot(noteColor, covered.notes, 'note(s)'),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Calque d'une page : ancres, notes, zone mise en évidence, page
  /// nouvelle, rectangle en cours de tracé.
  Widget _overlay(
    PdfPage page,
    SourceDocument document,
    List<Anchor> anchors,
    List<Note> notes,
  ) {
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

        NormalizedRect toRegion(Rect r) => NormalizedRect.fromCorners(
          r.left / size.width,
          r.top / size.height,
          r.right / size.width,
          r.bottom / size.height,
        );
        // Au moins la taille minimale d'un tracé (voir _finishDrag).
        final minFrame = Size(
          math.max(0.02 * size.width, 12),
          math.max(0.01 * size.height, 12),
        );

        final pageNotes = notes.where((n) => n.page == number).toList();
        final pageAnchors = [
          for (final anchor in anchors)
            if (anchor.page == number && anchor.region != null) anchor,
        ];
        void sendBack(String key) => setState(
          () => _framesBack
            ..remove(key)
            ..insert(0, key),
        );
        final frames = <String, Widget>{
          if (_selecting) ...{
            for (final note in pageNotes)
              if (note.region != null)
                'note-${note.id}': FrameResizer(
                  key: ValueKey('note-${note.id}'),
                  rect: toRect(note.region!),
                  bounds: size,
                  minSize: minFrame,
                  color: noteColor,
                  onResized: (r) => _resizeFrame(page, toRegion(r), note: note),
                  onHandleTap: () => sendBack('note-${note.id}'),
                  child: _noteFrame(note),
                ),
            for (final anchor in pageAnchors)
              'anchor-${anchor.id}': FrameResizer(
                key: ValueKey('anchor-${anchor.id}'),
                rect: toRect(anchor.region!),
                bounds: size,
                minSize: minFrame,
                color: _anchorColor(anchor),
                onResized: (r) =>
                    _resizeFrame(page, toRegion(r), anchor: anchor),
                onHandleTap: () => sendBack('anchor-${anchor.id}'),
                child: _anchorFrame(anchor),
              ),
          },
        };
        final children = <Widget>[
          // En mode « Encadrer », les cadres sont dessinés avec leurs
          // poignées, au-dessus de la zone de tracé (plus bas).
          if (!_selecting)
            for (final anchor in pageAnchors)
              Positioned.fromRect(
                rect: toRect(anchor.region!),
                child: Tooltip(
                  message: anchor.role == AnchorRole.source ? 'Recto' : 'Verso',
                  child: GestureDetector(
                    onTap: () => _openItem(anchor.itemId),
                    child: _anchorFrame(anchor),
                  ),
                ),
              ),
          // Zones des notes (pointillé discret) et marqueurs.
          if (!_selecting)
            for (final note in pageNotes)
              if (note.region != null)
                Positioned.fromRect(
                  rect: toRect(note.region!),
                  child: IgnorePointer(child: _noteFrame(note)),
                ),
          for (final (i, note) in pageNotes.indexed)
            Positioned(
              left: note.region == null
                  ? size.width - 40
                  : (note.region!.right * size.width - 14).clamp(
                      0,
                      size.width - 28,
                    ),
              top: note.region == null
                  ? 8.0 + i * 32
                  : (note.region!.top * size.height - 14).clamp(
                      0,
                      size.height - 28,
                    ),
              child: _NoteMarker(
                active: note.id == _activeNote,
                onTap: _selecting
                    ? null
                    : () => setState(() {
                        _notesOpen = true;
                        _activeNote = note.id;
                      }),
              ),
            ),
          if (widget.highlight != null && number == _startPage)
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
                // Le pavé tactile fait défiler (voir Listener) au lieu de
                // tracer.
                supportedDevices: frameDevices,
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
          // Cadres existants : poignées pour les redimensionner. Cadres
          // superposés : la note active d'abord ; toucher une poignée sans
          // glisser passe au cadre de dessous.
          if (_selecting) ...[
            for (final key in stackFrames(
              [
                for (final note in pageNotes)
                  if (note.region != null) 'note-${note.id}',
                for (final anchor in pageAnchors) 'anchor-${anchor.id}',
              ],
              sentBack: _framesBack,
              front: _activeNote == null ? null : 'note-$_activeNote',
            ))
              ?frames[key],
          ],
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
        // La molette et le pavé tactile font défiler la page même sur un
        // cadre ou une poignée (sinon le calque les absorbe). En mode
        // « Encadrer », le pavé tactile passe déjà par le Listener de la
        // visionneuse.
        return ScrollPassThrough(
          onScroll: _controller.handlePointerSignalEvent,
          onPan: _selecting ? null : _panBy,
          child: Stack(children: children),
        );
      },
    );
  }

  static Color _anchorColor(Anchor anchor) =>
      anchor.role == AnchorRole.source ? rectoColor : versoColor;

  Widget _anchorFrame(Anchor anchor) => DecoratedBox(
    decoration: BoxDecoration(
      color: _anchorColor(anchor).withValues(alpha: 0.08),
      border: Border.all(color: _anchorColor(anchor), width: 1.5),
    ),
  );

  Widget _noteFrame(Note note) => DecoratedBox(
    decoration: BoxDecoration(
      color: noteColor.withValues(alpha: note.id == _activeNote ? 0.14 : 0.05),
      border: Border.all(color: noteColor.withValues(alpha: 0.6)),
    ),
  );

  /// Fait glisser le contenu de [delta] (pixels de la vue).
  void _panBy(Offset delta) {
    if (!_controller.isReady || delta == Offset.zero) return;
    _controller.value =
        Matrix4.translationValues(delta.dx, delta.dy, 0) * _controller.value;
  }

  /// Barre de défilement : place le haut de la vue à [top] (coordonnées du
  /// document).
  void _scrollTo(double top) {
    if (!_controller.isReady) return;
    final m = _controller.value.clone();
    final t = m.getTranslation();
    m.setTranslationRaw(t.x, -top * _controller.currentZoom, t.z);
    _controller.value = m;
  }

  /// Redimensionnements en cours, par cadre : seul le dernier enregistre
  /// son aperçu.
  final _resizes = <String, int>{};

  /// Cadres touchés sans glisser, passés dessous (le plus récent d'abord).
  final _framesBack = <String>[];

  /// Cadre redimensionné : la zone est enregistrée tout de suite (dans
  /// l'ordre des gestes), puis l'aperçu, s'il n'y a pas eu d'autre geste
  /// entre-temps.
  Future<void> _resizeFrame(
    PdfPage page,
    NormalizedRect region, {
    Anchor? anchor,
    Note? note,
  }) async {
    final key = anchor != null ? 'anchor-${anchor.id}' : 'note-${note!.id}';
    final gesture = (_resizes[key] ?? 0) + 1;
    _resizes[key] = gesture;
    Future<void> save(Uint8List? snapshot) => anchor != null
        ? _store.relocateAnchor(
            anchor.id,
            page: page.pageNumber,
            region: region,
            snapshot: snapshot,
          )
        : _store.relocateNote(note!.id, region: region, snapshot: snapshot);
    try {
      await save(null);
      final snapshot = await renderRegionPng(page, region);
      if (snapshot == null || _resizes[key] != gesture) return;
      await save(snapshot);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cadre non enregistré : $e')));
    }
  }

  /// Ouverture / fermeture d'un panneau : la page garde la même part de la
  /// largeur (une page ajustée à la largeur le reste) autour du même point.
  void _onViewSizeChanged(
    Size viewSize,
    Size? oldViewSize,
    PdfViewerController controller,
  ) {
    if (oldViewSize == null ||
        oldViewSize.width <= 0 ||
        (viewSize.width - oldViewSize.width).abs() < 1) {
      return;
    }
    // Au zoom minimal, pdfrx a déjà réajusté la page : ne pas zoomer deux
    // fois.
    if ((controller.currentZoom - controller.minScale).abs() < 1e-3) return;
    final center = controller.value.calcPosition(oldViewSize);
    final zoom = controller.currentZoom * viewSize.width / oldViewSize.width;
    // Pas pendant la construction : le rappel peut survenir en plein build.
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      if (!mounted || !controller.isReady) return;
      controller.goTo(
        controller.calcMatrixFor(center, zoom: zoom),
        duration: Duration.zero,
      );
    });
  }

  /// Appui long sur du texte : sélection du mot seul (pdfrx sélectionne un
  /// « fragment », parfois une ligne entière dans les PDF sans espaces).
  bool _onGeneralTap(
    BuildContext context,
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    if (_selecting ||
        details.type != PdfViewerGeneralTapType.longPress ||
        details.tapOn != PdfViewerPart.nonSelectedText) {
      return false;
    }
    _selectWordAt(controller, details.documentPosition);
    return true;
  }

  /// Page contenant la position [doc] (coordonnées du document), ou `null`.
  int? _pageAt(PdfViewerController controller, Offset doc) {
    final layouts = controller.layout.pageLayouts;
    for (var i = 0; i < layouts.length; i++) {
      if (layouts[i].contains(doc)) return i + 1;
    }
    return null;
  }

  /// Caractère de [text] sous la position [doc], filigranes ignorés.
  PdfTextSelectionPoint? _charAt(
    PdfViewerController controller,
    PdfPageText text,
    Offset doc,
  ) {
    final pageIndex = text.pageNumber - 1;
    final pageRect = controller.layout.pageLayouts[pageIndex];
    final point = doc
        .translate(-pageRect.left, -pageRect.top)
        .toPdfPoint(
          page: controller.pages[pageIndex],
          scaledPageSize: pageRect.size,
        );
    final index = charIndexAt(text, point.x, point.y);
    return index == null ? null : PdfTextSelectionPoint(text, index);
  }

  Future<void> _selectWordAt(
    PdfViewerController controller,
    Offset position,
  ) async {
    final delegate = controller.textSelectionDelegate;
    await delegate.selectWord(position);
    final range = delegate.textSelectionPointRange;
    if (range == null) return;
    final text = range.start.text;
    final char = _charAt(controller, text, position);
    if (char == null) {
      // Seul un filigrane était sous le doigt.
      await delegate.clearTextSelection();
      return;
    }
    final (start, stop) = wordBounds(text.fullText, [
      for (final r in text.charRects)
        (left: r.left, right: r.right, height: r.top - r.bottom),
    ], char.index);
    final word = PdfTextSelectionRange.fromPoints(
      PdfTextSelectionPoint(text, start),
      PdfTextSelectionPoint(text, stop - 1),
    );
    if (word.start == range.start && word.end == range.end) return;
    await delegate.setTextSelectionPointRange(word);
  }

  /// Dernier pointeur posé sur la barre de défilement.
  int? _scrollbarPointer;

  /// Clic glissé (souris, stylet) en cours, en coordonnées globales.
  Offset? _dragFrom;
  Offset? _dragTo;
  PdfTextSelectionPoint? _dragAnchor;
  PdfTextSelectionPoint? _lastDragEnd;

  /// Textes des pages vues pendant le clic glissé : pdfrx ne garde que les
  /// pages des bornes de la sélection en cours.
  final _dragTexts = <int, PdfPageText>{};

  /// Recalcule les bornes de la sélection en cours de clic glissé en
  /// ignorant les filigranes : pdfrx prend le premier caractère dont la
  /// boîte contient le pointeur, souvent une lettre géante du filigrane
  /// placée en tête du texte, et sélectionnait alors des pages entières.
  void _fixDragSelection() {
    final from = _dragFrom;
    final to = _dragTo;
    if (from == null || to == null || !_controller.isReady) return;
    final delegate = _controller.textSelectionDelegate;
    final range = delegate.textSelectionPointRange;
    if (range == null) return;
    _dragTexts[range.start.text.pageNumber] = range.start.text;
    _dragTexts[range.end.text.pageNumber] = range.end.text;
    PdfTextSelectionPoint? at(Offset global) {
      final doc = _controller.globalToDocument(global);
      if (doc == null) return null;
      final text = _dragTexts[_pageAt(_controller, doc)];
      return text == null ? null : _charAt(_controller, text, doc);
    }

    // Le point de départ est fixé au premier passage : en glissant vers le
    // haut, pdfrx remplace ensuite la borne de départ par le pointeur.
    final a = _dragAnchor ??= at(from);
    if (a == null) {
      // Départ hors du texte : seul un filigrane avait été touché.
      delegate.clearTextSelection();
      return;
    }
    final b = at(to) ?? _lastDragEnd ?? a;
    _lastDragEnd = b;
    final fixed = PdfTextSelectionRange.fromPoints(a, b);
    if (fixed.start == range.start && fixed.end == range.end) return;
    delegate.setTextSelectionPointRange(fixed);
  }

  void _onTextSelectionChange(PdfTextSelection _) => _fixDragSelection();

  void _onPointerDown(PointerDownEvent event) {
    // Barre de défilement : la sélection de texte en cours reste intacte.
    if (event.pointer == _scrollbarPointer) {
      _dragFrom = _dragTo = null;
      return;
    }
    final mouseLike =
        event.kind == PointerDeviceKind.mouse ||
        event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;
    final drag = !_selecting && mouseLike && event.buttons == kPrimaryButton;
    _dragFrom = drag ? event.position : null;
    _dragTo = null;
    _dragAnchor = _lastDragEnd = null;
    _dragTexts.clear();
  }

  // pdfrx traite le même événement après ce Listener (reconnaisseurs de
  // gestes) : la correction passe en micro-tâche, donc en dernier.
  void _onPointerMove(PointerMoveEvent event) {
    if (_dragFrom == null) return;
    _dragTo = event.position;
    scheduleMicrotask(_fixDragSelection);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_dragFrom == null) return;
    if (_dragTo != null) _dragTo = event.position;
    scheduleMicrotask(() {
      _fixDragSelection();
      _dragFrom = _dragTo = null;
    });
  }

  Future<void> _onLinkTap(PdfLink link) async {
    final dest = link.dest;
    if (dest != null) {
      await _controller.goToDest(dest);
      return;
    }
    final url = link.url;
    if (url == null) return;
    final ok = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir $url')));
    }
  }

  /// Encadre le texte surligné (sur sa première page) ; `false` s'il n'y en
  /// a pas.
  Future<bool> _frameSelectedText() async {
    if (!_controller.isReady) return false;
    final delegate = _controller.textSelectionDelegate;
    if (!delegate.hasSelectedText) return false;
    final ranges = await delegate.getSelectedTextRanges();
    if (ranges.isEmpty || !mounted) return false;
    final first = ranges.first;
    final page = _controller.pages[first.pageNumber - 1];
    final region = regionOfPdfRect(first.bounds, page.width, page.height);
    await delegate.clearTextSelection();
    if (!mounted) return true;
    await _onRegionSelected(page, region);
    return true;
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
    final store = _store;
    final document = await store.document(widget.documentId);
    if (document == null || !mounted) return;
    final target = widget.attachToItem;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: target != null
              ? [
                  ListTile(
                    leading: const Icon(Icons.flip_to_front, color: rectoColor),
                    title: Text('Recto de « ${target.title} »'),
                    subtitle: const Text('L\'énoncé à se rappeler'),
                    onTap: () => Navigator.pop(context, 'source'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.flip_to_back, color: versoColor),
                    title: Text('Verso de « ${target.title} »'),
                    subtitle: const Text('La rédaction, révélée en révision'),
                    onTap: () => Navigator.pop(context, 'work'),
                  ),
                ]
              : [
                  ListTile(
                    leading: const Icon(Icons.edit_note, color: noteColor),
                    title: const Text('Prendre une note sur cette zone'),
                    subtitle: const Text('Rédaction liée à cet élément du PDF'),
                    onTap: () => Navigator.pop(context, 'note'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('Créer une connaissance avec cet énoncé'),
                    subtitle: const Text('La zone devient son recto'),
                    onTap: () => Navigator.pop(context, 'create'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text(
                      'Créer une connaissance avec cette rédaction',
                    ),
                    subtitle: const Text('La zone devient son verso'),
                    onTap: () => Navigator.pop(context, 'createWork'),
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
    if (!mounted) return;

    if (action == 'note') {
      final note = await store.createNote(
        documentId: document.id,
        page: page.pageNumber,
        region: region,
        snapshot: snapshot,
      );
      if (!mounted) return;
      setState(() {
        _selecting = false;
        _notesOpen = true;
        _activeNote = note.id;
      });
      return;
    }

    final text = await extractRegionText(page, region);
    if (!mounted) return;
    final work = action == 'work' || action == 'createWork';
    KnowledgeItem? item = target;
    if (target != null) {
      // Connaissance déjà choisie.
    } else if (action == 'create' || action == 'createWork') {
      // Énoncé : le texte extrait sert de titre et de contenu ; une
      // rédaction (souvent manuscrite) n'en a pas d'exploitable.
      item = await showItemEditor(
        context,
        family: ItemFamily.statement,
        initialTitle: work ? null : suggestTitle(text),
        initialBody: work ? null : text,
      );
    } else {
      item = await pickItem(
        context,
        title: work
            ? 'Verso de quelle connaissance ?'
            : 'Recto de quelle connaissance ?',
      );
    }
    if (item == null || !mounted) return;
    final role = work ? AnchorRole.work : AnchorRole.source;
    await store.addAnchor(
      itemId: item.id,
      documentId: widget.documentId,
      role: role,
      page: page.pageNumber,
      region: region,
      textSnippet: text,
      snapshot: snapshot,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${role == AnchorRole.work ? 'Verso' : 'Recto'} attaché à « ${item.title} ».',
        ),
      ),
    );
    if (target != null) Navigator.of(context).pop();
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

class _NoteMarker extends StatelessWidget {
  const _NoteMarker({required this.active, required this.onTap});

  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Note',
      child: Material(
        color: active ? noteColor : Colors.white,
        shape: const CircleBorder(side: BorderSide(color: noteColor)),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 28,
            child: Icon(
              Icons.edit_note,
              size: 18,
              color: active ? Colors.white : noteColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille de couverture d'une miniature : nombre de recto, verso ou notes.
class _CoverageDot extends StatelessWidget {
  const _CoverageDot(this.color, this.count, this.what);

  final Color color;
  final int count;
  final String what;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$count $what',
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$count',
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ),
    );
  }
}
