import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../ui/graph_viewer.dart';
import '../items/item_detail_page.dart';
import '../trees/trees_page.dart';
import 'board_canvas.dart';

/// Vue « Tableau » : toute la hiérarchie sur une toile infinie, les nœuds en
/// régions imbriquées et les connaissances en cartes (lecture seule pour
/// l'instant, voir docs/TABLEAU.md).
///
/// À l'ouverture puis à chaque changement des nœuds ou connaissances, ce
/// qui n'est pas encore placé l'est automatiquement, et enregistré.
class BoardPage extends StatefulWidget {
  const BoardPage({super.key});

  /// Zoom permis.
  static const minScale = 0.02;
  static const maxScale = 2.5;

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  final _controller = TransformationController();
  StreamSubscription<({List<KnowledgeNode> nodes, List<KnowledgeItem> items})>?
  _sub;
  List<KnowledgeNode>? _nodes;
  List<KnowledgeItem>? _items;
  BoardScene? _scene;
  Size _viewport = Size.zero;
  var _saving = false;

  /// Vue retenue, lue au démarrage ; appliquée (ou tout cadré) une fois.
  ({double scale, double dx, double dy})? _savedView;
  var _savedViewLoaded = false;
  var _viewApplied = false;

  /// Vrai pendant un changement de vue par programme (pas à retenir).
  var _programmatic = false;
  Timer? _saveView;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sub != null) return;
    final store = AppScope.of(context).store;
    // Nœuds et connaissances lus ensemble : la mise en page part toujours
    // d'un état cohérent (jamais des régions placées sans leurs cartes, ou
    // l'inverse, entre deux émissions).
    _sub = store.watchBoard().listen((board) {
      _nodes = board.nodes;
      _items = board.items;
      _rebuild();
    });
    store.boardViewport().then((view) {
      if (!mounted) return;
      _savedView = view;
      _savedViewLoaded = true;
      _applyInitialView();
    });
    _controller.addListener(_onTransform);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _saveView?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Recalcule la mise en page ; enregistre ce qui vient d'être placé.
  void _rebuild() {
    final nodes = _nodes, items = _items;
    if (nodes == null || items == null || !mounted) return;
    final scope = AppScope.of(context);
    final layout = layoutBoard(nodes, items);
    final now = DateTime.now();
    final scene = BoardScene.build(
      nodes: nodes,
      items: items,
      layout: layout,
      mastery: (item) => item.scheduling.isNew
          ? 0
          : scope.mastery.of(
              item.scheduling,
              scope.scheduler.retrievability(item.scheduling, now),
            ),
    );
    final previous = _scene;
    setState(() => _scene = scene);
    // Le repère du dessin a bougé (contenu étendu vers le haut ou la
    // gauche) : la vue suit, rien ne saute à l'écran.
    if (previous != null && previous.origin != scene.origin) {
      final shift = previous.origin - scene.origin;
      final m = _controller.value;
      final scale = m.getMaxScaleOnAxis();
      final t = m.getTranslation();
      _setView(
        m.clone()..setTranslationRaw(
          t.x - shift.dx * scale,
          t.y - shift.dy * scale,
          t.z,
        ),
      );
    }
    _applyInitialView();
    if (layout.hasChanges && !_saving) _persist(layout);
  }

  /// Enregistre la géométrie calculée ; la base renvoie alors les nœuds et
  /// connaissances placés (et ce qui serait arrivé entre-temps).
  Future<void> _persist(BoardLayout layout) async {
    _saving = true;
    try {
      await AppScope.of(context).store.saveBoardGeometry(
        regions: {
          for (final id in layout.changedRegions) id: layout.regions[id]!,
        },
        cards: {for (final id in layout.changedCards) id: layout.cards[id]!},
      );
    } finally {
      _saving = false;
    }
  }

  void _setView(Matrix4 matrix) {
    _programmatic = true;
    _controller.value = matrix;
    _programmatic = false;
  }

  /// Première vue : celle retenue, sinon tout le tableau.
  void _applyInitialView() {
    final scene = _scene;
    if (_viewApplied ||
        !_savedViewLoaded ||
        scene == null ||
        _viewport.isEmpty) {
      return;
    }
    _viewApplied = true;
    final saved = _savedView;
    if (saved == null) {
      _fit();
      return;
    }
    // Retenue dans le repère du tableau : écran = tableau × zoom + décalage.
    _setView(
      Matrix4.identity()
        ..translateByDouble(
          saved.dx + scene.origin.dx * saved.scale,
          saved.dy + scene.origin.dy * saved.scale,
          0,
          1,
        )
        ..scaleByDouble(saved.scale, saved.scale, saved.scale, 1),
    );
  }

  /// Cadre tout le tableau (« Recentrer »).
  void _fit() {
    final scene = _scene;
    if (scene == null || _viewport.isEmpty) return;
    final content = scene.contentRect;
    if (content.isEmpty) {
      _setView(Matrix4.identity());
      return;
    }
    const inset = 24.0;
    final scale = math
        .min(
          (_viewport.width - 2 * inset) / content.width,
          (_viewport.height - 2 * inset) / content.height,
        )
        .clamp(BoardPage.minScale, 1.0);
    final dx = (_viewport.width - content.width * scale) / 2;
    final dy = (_viewport.height - content.height * scale) / 2;
    _setView(
      Matrix4.identity()
        ..translateByDouble(
          dx - content.left * scale,
          dy - content.top * scale,
          0,
          1,
        )
        ..scaleByDouble(scale, scale, scale, 1),
    );
  }

  /// Vue changée par l'utilisateur : retenue après un court délai.
  void _onTransform() {
    if (_programmatic) return;
    _saveView?.cancel();
    _saveView = Timer(const Duration(milliseconds: 800), () {
      final scene = _scene;
      if (scene == null || !mounted) return;
      final m = _controller.value;
      final scale = m.getMaxScaleOnAxis();
      final t = m.getTranslation();
      AppScope.of(context).store.setBoardViewport((
        scale: scale,
        dx: t.x - scene.origin.dx * scale,
        dy: t.y - scene.origin.dy * scale,
      ));
    });
  }

  void _openItem(KnowledgeItem item) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ItemDetailPage(itemId: item.id)),
  );

  void _openNode(KnowledgeNode node) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => NodePage(nodeId: node.id)));

  @override
  Widget build(BuildContext context) {
    final scene = _scene;
    if (scene == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (scene.regions.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Le tableau est vide : créez un arbre dans l\'onglet « Arbres ».',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        if (viewport != _viewport) {
          _viewport = viewport;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(_applyInitialView);
          });
        }
        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                child: GraphViewer(
                  transformationController: _controller,
                  constrained: false,
                  minScale: BoardPage.minScale,
                  maxScale: BoardPage.maxScale,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  child: BoardCanvas(
                    scene: scene,
                    controller: _controller,
                    viewport: viewport,
                    onOpenItem: _openItem,
                    onOpenNode: _openNode,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: FloatingActionButton.extended(
                  heroTag: null,
                  onPressed: _fit,
                  icon: const Icon(Icons.fit_screen),
                  label: const Text('Recentrer'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
