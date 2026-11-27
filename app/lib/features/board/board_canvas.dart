import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../ui/item_glyph.dart';
import '../../ui/labels.dart';
import '../../ui/math_text.dart';

/// Niveau de détail du tableau selon le zoom (zoom sémantique).
enum BoardDetail {
  /// De loin : titres des régions en grand, cartes en blocs colorés.
  far,

  /// À mi-distance : titres des cartes en texte simple.
  mid,

  /// De près : titres des cartes avec leurs formules.
  near;

  /// En dessous : vue de loin.
  static const farBelow = 0.35;

  /// À partir de : rendu LaTeX des cartes.
  static const latexFrom = 0.7;

  static BoardDetail of(double scale) => scale < farBelow
      ? far
      : scale < latexFrom
      ? mid
      : near;
}

/// Région prête à dessiner.
class SceneRegion {
  const SceneRegion({
    required this.node,
    required this.rect,
    required this.depth,
    required this.color,
  });

  final KnowledgeNode node;

  /// Rectangle dans le repère du dessin (voir [BoardScene.origin]).
  final Rect rect;
  final int depth;

  /// Couleur de l'arbre auquel appartient la région.
  final Color color;
}

/// Carte prête à dessiner.
class SceneCard {
  const SceneCard({
    required this.item,
    required this.rect,
    required this.mastery,
    required this.color,
  });

  final KnowledgeItem item;
  final Rect rect;

  /// Maîtrise entre 0 et 1 (0 pour une connaissance nouvelle).
  final double mastery;
  final Color color;
}

/// Contenu du tableau, dans le repère du dessin : le coin supérieur gauche
/// du dessin est le point [origin] du tableau.
class BoardScene {
  BoardScene._({
    required this.regions,
    required this.cards,
    required this.origin,
    required this.size,
    required this.config,
  });

  /// Couleurs des arbres, dans l'ordre des arbres.
  static const palette = [
    Color(0xFF3F7CAC), // bleu
    Color(0xFF5B7F5E), // vert
    Color(0xFFC8553D), // brique
    Color(0xFF8E6BB0), // violet
    Color(0xFFD08C2E), // ocre
    Color(0xFF2E8C8C), // sarcelle
    Color(0xFFB0507A), // framboise
    Color(0xFF7A6248), // écorce
  ];

  /// Marge autour du contenu.
  static const margin = 400.0;

  /// [mastery] : maîtrise d'une connaissance (0 si nouvelle).
  factory BoardScene.build({
    required List<KnowledgeNode> nodes,
    required List<KnowledgeItem> items,
    required BoardLayout layout,
    BoardLayoutConfig config = const BoardLayoutConfig(),
    double Function(KnowledgeItem item)? mastery,
  }) {
    final byId = {for (final n in nodes) n.id: n};
    final roots =
        nodes
            .where((n) => n.parentId == null || !byId.containsKey(n.parentId))
            .toList()
          ..sort((a, b) {
            final s = a.sortIndex.compareTo(b.sortIndex);
            return s != 0 ? s : a.createdAt.compareTo(b.createdAt);
          });
    final rootIndex = {for (final (i, r) in roots.indexed) r.id: i};
    final depth = <String, int>{};
    final colorOf = <String, Color>{};
    int depthOf(KnowledgeNode n) {
      final known = depth[n.id];
      if (known != null) return known;
      final parent = byId[n.parentId];
      final d = parent == null ? 0 : depthOf(parent) + 1;
      colorOf[n.id] = parent == null
          ? palette[rootIndex[n.id]! % palette.length]
          : colorOf[parent.id]!;
      return depth[n.id] = d;
    }

    final bounds = layout.bounds ?? const BoardRect(0, 0, 0, 0);
    final origin = Offset(
      math.min(0, bounds.x) - margin,
      math.min(0, bounds.y) - margin,
    );
    Rect local(BoardRect r) =>
        Rect.fromLTWH(r.x - origin.dx, r.y - origin.dy, r.width, r.height);

    final regions = [
      for (final n in nodes)
        if (layout.regions[n.id] case final r?)
          SceneRegion(
            node: n,
            rect: local(r),
            depth: depthOf(n),
            color: colorOf[n.id]!,
          ),
    ]..sort((a, b) => a.depth.compareTo(b.depth));
    final cards = [
      for (final i in items)
        if (layout.cards[i.id] case final p? when colorOf.containsKey(i.nodeId))
          SceneCard(
            item: i,
            rect: local(BoardRect.at(p, config.cardWidth, config.cardHeight)),
            mastery: mastery?.call(i) ?? 0,
            color: colorOf[i.nodeId]!,
          ),
    ];
    return BoardScene._(
      regions: regions,
      cards: cards,
      origin: origin,
      size: Size(
        bounds.right - origin.dx + margin,
        bounds.bottom - origin.dy + margin,
      ),
      config: config,
    );
  }

  /// Des plus grandes (arbres) aux plus petites : les sous-régions sont
  /// dessinées par-dessus.
  final List<SceneRegion> regions;
  final List<SceneCard> cards;
  final Offset origin;
  final Size size;
  final BoardLayoutConfig config;

  /// Rectangle englobant le contenu (sans la marge), repère du dessin.
  Rect get contentRect => Rect.fromLTWH(
    margin,
    margin,
    math.max(0, size.width - 2 * margin),
    math.max(0, size.height - 2 * margin),
  );
}

/// Ce qui est construit : zone visible élargie et arrondie, niveau de
/// détail, palier de zoom. Ne change qu'en sortant d'une case de la grille
/// ou en changeant de palier : le reste du temps, rien n'est reconstruit.
@immutable
class _View {
  const _View(this.area, this.detail, this.step);

  final Rect area;
  final BoardDetail detail;
  final int step;

  /// Paliers de zoom : facteur 1,25.
  static const _ratio = 1.25;

  double get scale => math.pow(_ratio, step).toDouble();

  static _View of(Matrix4 matrix, Size viewport) {
    final scale = matrix.getMaxScaleOnAxis();
    final step = (math.log(scale) / math.log(_ratio)).floor();
    final inverse = Matrix4.inverted(matrix);
    final visible = Rect.fromPoints(
      MatrixUtils.transformPoint(inverse, Offset.zero),
      MatrixUtils.transformPoint(inverse, viewport.bottomRight(Offset.zero)),
    );
    // Case de la grille : la moitié de la plus grande dimension visible au
    // palier courant ; au moins une case de marge de chaque côté.
    final cell =
        math.max(viewport.width, viewport.height) / math.pow(_ratio, step) / 2;
    double down(double v) => (v / cell).floorToDouble() * cell;
    double up(double v) => (v / cell).ceilToDouble() * cell;
    return _View(
      Rect.fromLTRB(
        down(visible.left - cell),
        down(visible.top - cell),
        up(visible.right + cell),
        up(visible.bottom + cell),
      ),
      BoardDetail.of(scale),
      step,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _View &&
      other.area == area &&
      other.detail == detail &&
      other.step == step;

  @override
  int get hashCode => Object.hash(area, detail, step);
}

/// Dessin du tableau, à placer dans un `InteractiveViewer` (non contraint)
/// piloté par [controller]. Seuls les régions et cartes qui touchent la
/// zone visible sont construites.
class BoardCanvas extends StatefulWidget {
  const BoardCanvas({
    super.key,
    required this.scene,
    required this.controller,
    required this.viewport,
    this.onOpenItem,
    this.onOpenNode,
  });

  final BoardScene scene;
  final TransformationController controller;

  /// Taille de la vue (écran) ; vide : tout est construit.
  final Size viewport;
  final ValueChanged<KnowledgeItem>? onOpenItem;
  final ValueChanged<KnowledgeNode>? onOpenNode;

  @override
  State<BoardCanvas> createState() => _BoardCanvasState();
}

class _BoardCanvasState extends State<BoardCanvas> {
  late _View _view;

  @override
  void initState() {
    super.initState();
    _view = _compute();
    widget.controller.addListener(_onTransform);
  }

  @override
  void didUpdateWidget(BoardCanvas old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onTransform);
      widget.controller.addListener(_onTransform);
    }
    _view = _compute();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTransform);
    super.dispose();
  }

  _View _compute() {
    final matrix = widget.controller.value;
    if (widget.viewport.isEmpty) {
      return _View(
        Offset.zero & widget.scene.size,
        BoardDetail.of(matrix.getMaxScaleOnAxis()),
        0,
      );
    }
    return _View.of(matrix, widget.viewport);
  }

  void _onTransform() {
    final next = _compute();
    if (next != _view) setState(() => _view = next);
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    final view = _view;
    final far = view.detail == BoardDetail.far;
    final regions = [
      for (final r in scene.regions)
        if (r.rect.overlaps(view.area)) r,
    ];
    final cards = [
      for (final c in scene.cards)
        if (c.rect.overlaps(view.area)) c,
    ];
    return SizedBox.fromSize(
      size: scene.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final r in regions)
            Positioned.fromRect(
              key: ValueKey('region ${r.node.id}'),
              rect: r.rect,
              child: _RegionBox(
                region: r,
                band: scene.config.titleBand(r.depth),
                showTitle: !far,
                onTap: widget.onOpenNode == null
                    ? null
                    : () => widget.onOpenNode!(r.node),
              ),
            ),
          if (far)
            Positioned.fill(
              key: const ValueKey('blocks'),
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BlocksPainter(cards, Theme.of(context).colorScheme),
                ),
              ),
            )
          else
            for (final c in cards)
              Positioned.fromRect(
                key: ValueKey('card ${c.item.id}'),
                rect: c.rect,
                child: BoardCard(
                  card: c,
                  latex: view.detail == BoardDetail.near,
                  onTap: widget.onOpenItem == null
                      ? null
                      : () => widget.onOpenItem!(c.item),
                ),
              ),
          if (far)
            for (final r in regions)
              if (_FarLabel.fits(r, view.scale))
                Positioned(
                  key: ValueKey('label ${r.node.id}'),
                  left: r.rect.left + scene.config.padding / 2,
                  top: r.rect.top + scene.config.padding / 2,
                  width: r.rect.width - scene.config.padding,
                  child: _FarLabel(
                    region: r,
                    scale: view.scale,
                    onTap: widget.onOpenNode == null
                        ? null
                        : () => widget.onOpenNode!(r.node),
                  ),
                ),
        ],
      ),
    );
  }
}

/// Fond, bord et titre d'une région : plus marqués pour un arbre.
class _RegionBox extends StatelessWidget {
  const _RegionBox({
    required this.region,
    required this.band,
    required this.showTitle,
    this.onTap,
  });

  final SceneRegion region;
  final double band;
  final bool showTitle;
  final VoidCallback? onTap;

  static double radius(int depth) => switch (depth) {
    0 => 28,
    1 => 18,
    _ => 12,
  };

  static double fontSize(int depth) => switch (depth) {
    0 => 40,
    1 => 28,
    _ => 20,
  };

  @override
  Widget build(BuildContext context) {
    final color = region.color;
    final depth = region.depth;
    return DecoratedBox(
      decoration: BoxDecoration(
        // Fonds translucides : une région imbriquée paraît plus foncée.
        color: color.withValues(alpha: depth == 0 ? 0.05 : 0.07),
        borderRadius: BorderRadius.circular(radius(depth)),
        border: Border.all(
          color: color.withValues(alpha: depth == 0 ? 0.8 : 0.55),
          width: switch (depth) {
            0 => 4,
            1 => 2.5,
            _ => 1.5,
          },
        ),
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: band,
          child: !showTitle
              ? null
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: band * 0.4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        region.node.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fontSize(depth),
                          fontWeight: depth == 0
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: Color.lerp(color, Colors.black, 0.25),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Titre d'une région vu de loin : taille constante à l'écran (au palier
/// de zoom près).
class _FarLabel extends StatelessWidget {
  const _FarLabel({required this.region, required this.scale, this.onTap});

  final SceneRegion region;
  final double scale;
  final VoidCallback? onTap;

  /// Taille à l'écran, selon la profondeur.
  static double screenSize(int depth) => switch (depth) {
    0 => 26,
    1 => 18,
    _ => 14,
  };

  /// Assez de place à l'écran pour un titre lisible.
  static bool fits(SceneRegion r, double scale) =>
      r.rect.width * scale >= 90 &&
      r.rect.height * scale >= screenSize(r.depth) * 2;

  @override
  Widget build(BuildContext context) {
    final size = screenSize(region.depth) / scale;
    final color = region.color;
    return Align(
      alignment: Alignment.topLeft,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(size / 3),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: size / 3,
              vertical: size / 8,
            ),
            child: Text(
              region.node.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: size,
                height: 1.15,
                fontWeight: region.depth == 0
                    ? FontWeight.w700
                    : FontWeight.w600,
                color: Color.lerp(color, Colors.black, 0.25),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Couleur de fond d'une carte selon sa maîtrise (comme l'arbre de
/// compétences) : neutre si nouvelle, de plus en plus soutenue ensuite.
Color cardColor(SceneCard card, ColorScheme scheme) =>
    card.item.scheduling.isNew
    ? scheme.surface
    : Color.lerp(
        scheme.surface,
        scheme.primaryContainer,
        0.35 + 0.65 * card.mastery,
      )!;

/// Carte d'une connaissance : glyphe (type et stade) et titre / recto.
class BoardCard extends StatelessWidget {
  const BoardCard({
    super.key,
    required this.card,
    required this.latex,
    this.onTap,
  });

  final SceneCard card;

  /// Titre avec ses formules (sinon texte simple, plus léger).
  final bool latex;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = card.item;
    final style = theme.textTheme.bodyMedium!.copyWith(height: 1.25);
    return Material(
      color: cardColor(card, scheme),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: card.color.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 10, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ItemGlyph(
                family: item.kind.family,
                stage: GrowthStage.of(item.scheduling),
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topLeft,
                          maxHeight: double.infinity,
                          child: latex
                              ? MathText(item.title, style: style)
                              : Text(
                                  item.title.replaceAll(r'$', ''),
                                  style: style,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ),
                    ),
                    Text(
                      item.typeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cartes vues de loin : de simples blocs colorés, en un seul dessin.
class _BlocksPainter extends CustomPainter {
  _BlocksPainter(this.cards, this.scheme);

  final List<SceneCard> cards;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint();
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final c in cards) {
      final shape = RRect.fromRectAndRadius(c.rect, const Radius.circular(12));
      canvas.drawRRect(shape, fill..color = cardColor(c, scheme));
      canvas.drawRRect(shape, edge..color = c.color.withValues(alpha: 0.6));
    }
  }

  @override
  bool shouldRepaint(_BlocksPainter old) =>
      old.cards != cards || old.scheme != scheme;
}
