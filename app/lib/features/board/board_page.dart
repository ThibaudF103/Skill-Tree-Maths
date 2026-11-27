import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../ui/graph_viewer.dart';
import '../items/item_detail_page.dart';
import '../trees/trees_page.dart';
import 'board_canvas.dart';

/// Vue « Tableau » : toute la hiérarchie sur une toile infinie, les nœuds en
/// régions imbriquées et les connaissances en cartes (voir docs/TABLEAU.md).
///
/// En mode « Édition », un doigt sur une carte la déplace (vers une autre
/// région : elle change de nœud ; hors de toute région : « Non classées »),
/// sur un bandeau de titre déplace la région avec son contenu, sur une
/// poignée la redimensionne ; ailleurs il déplace la vue, et deux doigts
/// zooment toujours.
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

  /// Mode édition (désactivé par défaut : lire et se déplacer sans risque).
  var _editing = false;
  _EditGesture? _gesture;
  BoardDrag? _drag;

  /// Doigts (ou pointeurs) posés sur le tableau.
  final _pointers = <int>{};
  final _canvasKey = GlobalKey();

  /// Une modification vient d'être enregistrée : l'aperçu reste affiché
  /// jusqu'à l'instantané suivant.
  var _awaitingSnapshot = false;

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
    setState(() {
      _scene = scene;
      if (_awaitingSnapshot) {
        _awaitingSnapshot = false;
        _drag = null;
      }
    });
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

  // --- Édition -------------------------------------------------------------

  void _setEditing(bool editing) {
    _cancelGesture();
    setState(() => _editing = editing);
  }

  /// Point du tableau sous un point de l'écran.
  BoardPoint? _boardPoint(Offset global) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final scene = _scene;
    if (box == null || scene == null) return null;
    final local = box.globalToLocal(global);
    return BoardPoint(local.dx + scene.origin.dx, local.dy + scene.origin.dy);
  }

  /// Appui sur une carte, un bandeau de titre ou une poignée (mode
  /// édition) : à un seul doigt, le geste déplacera l'élément, pas la vue.
  void _onEditDown(PointerDownEvent event, BoardTarget target) {
    final nodes = _nodes, items = _items;
    if (!_editing ||
        _gesture != null ||
        _pointers.isNotEmpty ||
        nodes == null ||
        items == null ||
        (event.kind == PointerDeviceKind.mouse &&
            event.buttons != kPrimaryMouseButton)) {
      return;
    }
    setState(() {
      _gesture = _EditGesture(
        pointer: event.pointer,
        start: event.position,
        target: target,
        editor: BoardEditor(nodes, items),
        matrix: _controller.value.clone(),
      );
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    // Deuxième doigt : pincer et déplacer la vue l'emportent.
    if (_pointers.length > 1) _cancelGesture();
  }

  void _onPointerMove(PointerMoveEvent event) {
    final g = _gesture;
    if (g == null || event.pointer != g.pointer) return;
    // La vue reste immobile pendant le geste.
    if (_controller.value != g.matrix) _setView(g.matrix.clone());
    final delta = event.position - g.start;
    if (!g.active && delta.distance < kTouchSlop / 2) return;
    final at = _boardPoint(event.position);
    if (at == null) return;
    g
      ..active = true
      ..delta = delta / g.matrix.getMaxScaleOnAxis()
      ..at = at;
    setState(() => _drag = _preview(g));
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    final g = _gesture;
    if (g == null || event.pointer != g.pointer) return;
    if (!g.active) {
      // Simple toucher : la carte ou le nœud s'ouvre.
      setState(() => _gesture = null);
      return;
    }
    _commit(g);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    if (_gesture?.pointer == event.pointer) _cancelGesture();
  }

  void _cancelGesture() {
    if (_gesture == null && _drag == null) return;
    setState(() {
      _gesture = null;
      _drag = null;
    });
  }

  /// Rectangle demandé par une poignée tirée de [delta].
  static BoardRect _resized(BoardRect r, ResizeTarget t, Offset delta) {
    var left = r.x, top = r.y, right = r.right, bottom = r.bottom;
    if (t.hx < 0) left += delta.dx;
    if (t.hx > 0) right += delta.dx;
    if (t.hy < 0) top += delta.dy;
    if (t.hy > 0) bottom += delta.dy;
    return BoardRect(left, top, right - left, bottom - top);
  }

  BoardDrag _preview(_EditGesture g) {
    final editor = g.editor;
    final origin = _scene!.origin;
    return switch (g.target) {
      CardTarget() => BoardDrag(
        target: g.target,
        delta: g.delta,
        highlight: editor.regionAt(g.at),
      ),
      RegionTarget(:final nodeId) => BoardDrag(
        target: g.target,
        delta: g.delta,
        highlight: nodeId == KnowledgeNode.unsortedId
            ? null
            : editor.regionAt(g.at, excluding: nodeId, forRegion: true),
      ),
      final ResizeTarget t => () {
        final r = editor.clampResize(
          t.nodeId,
          _resized(editor.region(t.nodeId)!, t, g.delta),
        );
        return BoardDrag(
          target: t,
          resized: Rect.fromLTWH(
            r.x - origin.dx,
            r.y - origin.dy,
            r.width,
            r.height,
          ),
        );
      }(),
    };
  }

  /// Fin du geste : la modification est enregistrée en une transaction,
  /// avec « Annuler ».
  Future<void> _commit(_EditGesture g) async {
    final editor = g.editor;
    final d = g.delta;
    final edit = switch (g.target) {
      CardTarget(:final itemId) => editor.moveCard(
        itemId,
        topLeft: editor.card(itemId)!.translate(d.dx, d.dy),
        at: g.at,
      ),
      RegionTarget(:final nodeId) => editor.moveRegion(
        nodeId,
        topLeft: editor.region(nodeId)!.topLeft.translate(d.dx, d.dy),
        at: g.at,
      ),
      final ResizeTarget t => editor.resizeRegion(
        t.nodeId,
        _resized(editor.region(t.nodeId)!, t, d),
      ),
    };
    _gesture = null;
    if (edit.isEmpty) {
      setState(() => _drag = null);
      return;
    }
    // L'aperçu reste jusqu'au prochain instantané (pas de saut en arrière).
    _awaitingSnapshot = true;
    final store = AppScope.of(context).store;
    final messenger = ScaffoldMessenger.of(context);
    final message = _describe(g.target, edit);
    try {
      final undo = await store.applyBoardEdit(edit);
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Annuler',
            onPressed: () => store.undoBoardEdit(undo),
          ),
        ),
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() {
        _awaitingSnapshot = false;
        _drag = null;
      });
      messenger.showSnackBar(SnackBar(content: Text('${e.message}')));
    }
  }

  String _describe(BoardTarget target, BoardEdit edit) {
    String title(String? id) =>
        _nodes?.where((n) => n.id == id).firstOrNull?.title ??
        KnowledgeNode.unsortedTitle;
    return switch (target) {
      CardTarget() => switch (edit.itemMove) {
        null => 'Carte déplacée',
        (nodeId: final n, itemId: _) => 'Carte rangée dans « ${title(n)} »',
      },
      RegionTarget(:final nodeId) => switch (edit.nodeMove) {
        null => 'Région déplacée',
        (parentId: null, nodeId: _) => '« ${title(nodeId)} » devient un arbre',
        (parentId: final p?, nodeId: _) =>
          '« ${title(nodeId)} » rattachée à « ${title(p)} »',
      },
      ResizeTarget() => 'Région redimensionnée',
    };
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
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  onPointerCancel: _onPointerCancel,
                  child: GraphViewer(
                    transformationController: _controller,
                    constrained: false,
                    minScale: BoardPage.minScale,
                    maxScale: BoardPage.maxScale,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    panEnabled: _gesture == null,
                    child: BoardCanvas(
                      key: _canvasKey,
                      scene: scene,
                      controller: _controller,
                      viewport: viewport,
                      onOpenItem: _openItem,
                      onOpenNode: _openNode,
                      editing: _editing,
                      drag: _drag,
                      onEditDown: _onEditDown,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 16,
              child: SafeArea(
                child: FilterChip(
                  avatar: const Icon(Icons.edit_outlined),
                  label: const Text('Édition'),
                  tooltip: 'Déplacer et redimensionner cartes et régions',
                  selected: _editing,
                  showCheckmark: false,
                  elevation: 2,
                  onSelected: _setEditing,
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

/// Geste d'édition en cours (un seul doigt).
class _EditGesture {
  _EditGesture({
    required this.pointer,
    required this.start,
    required this.target,
    required this.editor,
    required this.matrix,
  });

  final int pointer;

  /// Point de départ, à l'écran.
  final Offset start;
  final BoardTarget target;

  /// Opérations sur l'instantané du début du geste.
  final BoardEditor editor;

  /// Vue au début du geste, maintenue pendant le geste.
  final Matrix4 matrix;

  /// Au-delà du seuil de glissé (sinon : simple toucher).
  var active = false;

  /// Déplacement, en unités du tableau.
  var delta = Offset.zero;

  /// Point du tableau sous le doigt.
  var at = const BoardPoint(0, 0);
}
