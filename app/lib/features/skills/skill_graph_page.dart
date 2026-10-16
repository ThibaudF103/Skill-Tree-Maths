import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../ui/labels.dart';
import '../items/item_detail_page.dart';
import '../trees/tree_data.dart';
import 'skill_layout.dart';

/// Ouvre l'arbre de compétences de la branche [nodeId].
void openSkillGraph(BuildContext context, String nodeId) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => SkillGraphPage(nodeId: nodeId)));

/// Arbre de compétences d'une branche : ses connaissances placées de gauche
/// à droite selon leurs prérequis, reliées par des flèches. Une connaissance
/// est verrouillée tant que ses prérequis n'ont pas tous été vus une fois.
class SkillGraphPage extends StatefulWidget {
  const SkillGraphPage({super.key, required this.nodeId});

  final String nodeId;

  @override
  State<SkillGraphPage> createState() => _SkillGraphPageState();
}

class _SkillGraphPageState extends State<SkillGraphPage> {
  Stream<List<Prerequisite>>? _edges;
  bool _showUnlinked = false;
  String? _selected;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _edges ??= AppScope.of(context).store.watchPrerequisites();
  }

  @override
  Widget build(BuildContext context) {
    return TreeDataBuilder(
      builder: (context, data) => StreamBuilder<List<Prerequisite>>(
        stream: _edges,
        builder: (context, edges) {
          final node = data.byId[widget.nodeId];
          final title = node == null ? 'Compétences' : node.title;
          if (!edges.hasData || node == null) {
            return Scaffold(
              appBar: AppBar(title: Text(title)),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          final model = SkillGraphModel.of(
            data: data,
            nodeId: widget.nodeId,
            edges: edges.data!,
            showUnlinked: _showUnlinked,
            scheduler: AppScope.of(context).scheduler,
            mastery: AppScope.of(context).mastery,
          );
          final selected = model.cells.containsKey(_selected)
              ? _selected
              : null;
          return Scaffold(
            appBar: AppBar(
              title: Text('Compétences · $title'),
              actions: [
                if (model.unlinkedCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: FilterChip(
                      label: Text('Sans lien (${model.unlinkedCount})'),
                      selected: _showUnlinked,
                      onSelected: (v) => setState(() => _showUnlinked = v),
                    ),
                  ),
              ],
            ),
            body: model.cells.isEmpty
                ? const _Empty()
                : Column(
                    children: [
                      const _Legend(),
                      Expanded(
                        child: _GraphView(
                          model: model,
                          selected: selected,
                          onTap: (id) => setState(
                            () => _selected = id == _selected ? null : id,
                          ),
                        ),
                      ),
                      if (selected != null)
                        _SelectionBar(
                          card: model.cards[selected]!,
                          onClose: () => setState(() => _selected = null),
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// État d'une connaissance dans l'arbre de compétences.
enum SkillState {
  /// Prérequis pas encore tous vus.
  locked,

  /// Jamais vue, mais prête à être apprise.
  ready,

  /// Déjà vue au moins une fois.
  seen,
}

/// Une case du graphe.
class SkillCard {
  const SkillCard({
    required this.item,
    required this.state,
    required this.mastery,
    required this.external,
  });

  final KnowledgeItem item;
  final SkillState state;

  /// Maîtrise entre 0 et 1 (0 si jamais vue).
  final double mastery;

  /// Prérequis venu d'une autre branche, affiché pour mémoire.
  final bool external;
}

/// Ce que montre le graphe d'une branche, calculé hors de l'affichage.
class SkillGraphModel {
  SkillGraphModel._({
    required this.graph,
    required this.cards,
    required this.layout,
    required this.edges,
    required this.unlinkedCount,
  });

  final PrerequisiteGraph graph;
  final Map<String, SkillCard> cards;
  final SkillLayout layout;

  /// Flèches affichées (les deux bouts sont dans le graphe).
  final List<Prerequisite> edges;

  /// Connaissances de la branche sans aucun lien, masquées par défaut.
  final int unlinkedCount;

  Map<String, ({int column, int row})> get cells => layout.cells;

  factory SkillGraphModel.of({
    required TreeData data,
    required String nodeId,
    required List<Prerequisite> edges,
    required bool showUnlinked,
    Scheduler? scheduler,
    MasteryModel mastery = const MasteryModel(),
  }) {
    final graph = PrerequisiteGraph(edges);
    final scope = data.subtreeItems(nodeId);
    final inScope = {for (final i in scope) i.id};
    final byId = {for (final i in data.items) i.id: i};
    bool linked(String id) =>
        graph.requires(id).isNotEmpty || graph.usedBy(id).isNotEmpty;
    final shown = [
      for (final i in scope)
        if (showUnlinked || linked(i.id)) i,
    ];
    final external = <String>{
      for (final i in shown)
        for (final r in graph.requires(i.id))
          if (!inScope.contains(r) && byId.containsKey(r)) r,
    };
    final ids = [
      for (final i in data.items)
        if (external.contains(i.id)) i.id,
      for (final i in shown) i.id,
    ];
    final seen = {
      for (final i in data.items)
        if (!i.scheduling.isNew) i.id,
    };
    final now = data.now;
    final cards = <String, SkillCard>{
      for (final id in ids)
        id: () {
          final item = byId[id]!;
          final s = item.scheduling;
          return SkillCard(
            item: item,
            state: !s.isNew
                ? SkillState.seen
                : graph.isUnlocked(id, seen)
                ? SkillState.ready
                : SkillState.locked,
            mastery: scheduler == null
                ? 0
                : mastery.of(s, scheduler.retrievability(s, now)),
            external: external.contains(id),
          );
        }(),
    };
    final present = cards.keys.toSet();
    return SkillGraphModel._(
      graph: graph,
      cards: cards,
      layout: SkillLayout.of(ids, graph),
      edges: [
        for (final e in edges)
          if (present.contains(e.itemId) && present.contains(e.requiresId)) e,
      ],
      unlinkedCount: scope.where((i) => !linked(i.id)).length,
    );
  }
}

const _cardWidth = 220.0;
const _cardHeight = 64.0;
const _columnGap = 80.0;
const _rowGap = 16.0;
const _margin = 32.0;

Offset _origin(({int column, int row}) cell) => Offset(
  _margin + cell.column * (_cardWidth + _columnGap),
  _margin + cell.row * (_cardHeight + _rowGap),
);

class _GraphView extends StatelessWidget {
  const _GraphView({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  final SkillGraphModel model;
  final String? selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final layout = model.layout;
    final size = Size(
      2 * _margin +
          layout.columnCount * _cardWidth +
          math.max(0, layout.columnCount - 1) * _columnGap,
      2 * _margin +
          layout.rowCount * _cardHeight +
          math.max(0, layout.rowCount - 1) * _rowGap,
    );
    final selected = this.selected;
    final chain = selected == null
        ? null
        : {
            selected,
            ...model.graph.ancestors(selected),
            ...model.graph.descendants(selected),
          };
    final scheme = Theme.of(context).colorScheme;
    return InteractiveViewer(
      constrained: false,
      minScale: 0.2,
      maxScale: 2,
      boundaryMargin: const EdgeInsets.all(200),
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _EdgePainter(
                  edges: model.edges,
                  cells: model.cells,
                  chain: chain,
                  color: scheme.outline,
                  highlight: scheme.primary,
                ),
              ),
            ),
            for (final MapEntry(key: id, value: cell) in model.cells.entries)
              Positioned(
                left: _origin(cell).dx,
                top: _origin(cell).dy,
                width: _cardWidth,
                height: _cardHeight,
                child: Opacity(
                  opacity: chain == null || chain.contains(id) ? 1 : 0.25,
                  child: _SkillTile(
                    card: model.cards[id]!,
                    selected: id == selected,
                    onTap: () => onTap(id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.edges,
    required this.cells,
    required this.chain,
    required this.color,
    required this.highlight,
  });

  final List<Prerequisite> edges;
  final Map<String, ({int column, int row})> cells;
  final Set<String>? chain;
  final Color color;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      final from = cells[e.requiresId]!;
      final to = cells[e.itemId]!;
      final a = _origin(from) + const Offset(_cardWidth, _cardHeight / 2);
      final b = _origin(to) + const Offset(0, _cardHeight / 2);
      final lit =
          chain != null &&
          chain!.contains(e.itemId) &&
          chain!.contains(e.requiresId);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lit ? 2 : 1.2
        ..color = lit
            ? highlight
            : color.withValues(alpha: chain == null ? 0.6 : 0.15);
      final bend = math.max(40.0, (b.dx - a.dx) / 2);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx + bend, a.dy, b.dx - bend, b.dy, b.dx, b.dy);
      canvas.drawPath(path, paint);
      // Pointe de flèche à l'arrivée.
      final head = Path()
        ..moveTo(b.dx, b.dy)
        ..lineTo(b.dx - 7, b.dy - 4)
        ..lineTo(b.dx - 7, b.dy + 4)
        ..close();
      canvas.drawPath(head, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.edges != edges ||
      old.cells != cells ||
      old.chain != chain ||
      old.color != color ||
      old.highlight != highlight;
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({
    required this.card,
    required this.selected,
    required this.onTap,
  });

  final SkillCard card;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locked = card.state == SkillState.locked;
    final background = switch (card.state) {
      SkillState.locked => scheme.surfaceContainerHighest,
      SkillState.ready => scheme.surface,
      SkillState.seen => Color.lerp(
        scheme.surface,
        scheme.primaryContainer,
        0.35 + 0.65 * card.mastery,
      )!,
    };
    final foreground = locked ? scheme.outline : scheme.onSurface;
    final border = selected
        ? BorderSide(color: scheme.primary, width: 2.5)
        : card.state == SkillState.ready
        ? BorderSide(color: scheme.primary, width: 1.5)
        : BorderSide(color: scheme.outlineVariant);
    return Material(
      color: card.external ? Colors.transparent : background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: card.external ? border.copyWith(color: scheme.outline) : border,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      card.external
                          ? '${card.item.typeLabel} · autre branche'
                          : card.item.typeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                    Text(
                      card.item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (locked)
                Icon(Icons.lock_outline, size: 16, color: scheme.outline),
              if (card.state == SkillState.seen)
                Icon(Icons.check, size: 16, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.card, required this.onClose});

  final SkillCard card;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = switch (card.state) {
      SkillState.locked => 'Verrouillée : des prérequis restent à voir.',
      SkillState.ready => 'Prête : tous ses prérequis ont été vus.',
      SkillState.seen => 'Vue · maîtrise ${(card.mastery * 100).round()} %',
    };
    return Material(
      elevation: 6,
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      card.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(state, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ItemDetailPage(itemId: card.item.id),
                  ),
                ),
                child: const Text('Ouvrir la fiche'),
              ),
              IconButton(
                tooltip: 'Fermer',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget entry(Widget mark, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 6),
        Text(text, style: theme.textTheme.bodySmall),
      ],
    );
    Widget box(Color fill, BorderSide side) => Container(
      width: 18,
      height: 12,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(3),
        border: Border.fromBorderSide(side),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          entry(
            box(
              scheme.surfaceContainerHighest,
              BorderSide(color: scheme.outlineVariant),
            ),
            'Verrouillée',
          ),
          entry(
            box(scheme.surface, BorderSide(color: scheme.primary, width: 1.5)),
            'Prête',
          ),
          entry(
            box(
              scheme.primaryContainer,
              BorderSide(color: scheme.outlineVariant),
            ),
            'Vue (plus foncée = mieux maîtrisée)',
          ),
          entry(
            box(Colors.transparent, BorderSide(color: scheme.outline)),
            'Autre branche',
          ),
          Text(
            'Une flèche va d\'un prérequis vers ce qui s\'appuie dessus. '
            'Touchez une carte pour suivre sa chaîne.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Aucun prérequis dans cette branche.\n'
          'Ajoutez-en depuis la fiche d\'une connaissance (section '
          '« Prérequis »), ou affichez les connaissances sans lien.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
