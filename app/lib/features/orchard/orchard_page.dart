import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../orchard/orchard_layout.dart';
import '../../orchard/orchard_painter.dart';
import '../../ui/item_glyph.dart';
import '../items/item_detail_page.dart';
import '../trees/tree_data.dart';

/// Construit la scène d'un nœud à partir des données.
OrchardScene buildScene(TreeData data, String nodeId) {
  final tomorrow = DayWindow.around(data.now).startOfTomorrow;
  SceneItem toScene(KnowledgeItem item) => (
    id: item.id,
    family: item.kind.family,
    stage: GrowthStage.of(item.scheduling),
    isDue:
        !item.suspended &&
        !item.scheduling.isNew &&
        item.scheduling.due!.isBefore(tomorrow),
  );
  bool active(KnowledgeItem item) => !item.suspended;
  return (
    id: nodeId,
    branches: [
      for (final child in data.children(nodeId))
        (
          id: child.id,
          title: child.title,
          twigs: data.children(child.id).length,
          items: [
            for (final item in data.subtreeItems(child.id))
              if (active(item)) toScene(item),
          ],
        ),
    ],
    items: [
      for (final item in data.itemsIn(nodeId))
        if (active(item)) toScene(item),
    ],
  );
}

String progressSummary(NodeProgress p) {
  if (p.isEmpty) return 'Hiver : aucune connaissance';
  return [
    p.itemCount == 1 ? '1 connaissance' : '${p.itemCount} connaissances',
    'maîtrise ${(p.meanMastery * 100).round()} %',
    if (p.dueCount > 0) '${p.dueCount} à réviser',
  ].join(' · ');
}

/// Vue « Verger » : un arbre par domaine.
class OrchardPage extends StatelessWidget {
  const OrchardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: TreeDataBuilder(
        builder: (context, data) {
          if (data.trees.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Le verger est encore en friche.\n'
                  'Plantez un premier arbre dans l\'onglet Arbres.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            );
          }
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                sliver: SliverToBoxAdapter(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text('Verger', style: theme.textTheme.headlineMedium),
                      const OrchardLegend(),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 380,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: data.trees.length,
                  itemBuilder: (context, i) =>
                      _TreeCard(data: data, tree: data.trees[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TreeCard extends StatelessWidget {
  const _TreeCard({required this.data, required this.tree});

  final TreeData data;
  final KnowledgeNode tree;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scene = buildScene(data, tree.id);
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OrchardFocusPage(nodeId: tree.id),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final layout = layoutOrchard(
                    scene,
                    constraints.biggest,
                    labels: false,
                    maxGlyphsPerBranch: 10,
                  );
                  return CustomPaint(
                    painter: OrchardPainter(
                      layout: layout,
                      labelStyle: theme.textTheme.labelSmall!,
                      accent: theme.colorScheme.primary,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tree.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    progressSummary(data.progress[tree.id]!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un arbre, une branche ou un rameau en grand : toucher une branche pour
/// s'en approcher, une connaissance pour l'ouvrir. Pincer pour zoomer.
class OrchardFocusPage extends StatelessWidget {
  const OrchardFocusPage({super.key, required this.nodeId});

  final String nodeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TreeDataBuilder(
      builder: (context, data) {
        final node = data.byId[nodeId];
        if (node == null) {
          return Scaffold(appBar: AppBar());
        }
        final path = data.pathTo(nodeId);
        final scene = buildScene(data, nodeId);
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(node.title),
                if (path.length > 1)
                  Text(
                    path.take(path.length - 1).map((n) => n.title).join(' › '),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final layout = layoutOrchard(scene, constraints.biggest);
                    return InteractiveViewer(
                      maxScale: 4,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          final hit = layout.hitTest(details.localPosition);
                          if (hit == null) return;
                          if (hit.itemId != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    ItemDetailPage(itemId: hit.itemId!),
                              ),
                            );
                          } else if (hit.branchId != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    OrchardFocusPage(nodeId: hit.branchId!),
                              ),
                            );
                          }
                        },
                        child: CustomPaint(
                          size: constraints.biggest,
                          painter: OrchardPainter(
                            layout: layout,
                            labelStyle: theme.textTheme.labelLarge!.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            accent: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text(
                        progressSummary(data.progress[nodeId]!),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const OrchardLegend(),
                    ],
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

/// Légende : feuille, fleur, fruit.
class OrchardLegend extends StatelessWidget {
  const OrchardLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.outline,
    );
    return Wrap(
      spacing: 14,
      children: [
        for (final (family, label) in const [
          (ItemFamily.definition, 'définition'),
          (ItemFamily.statement, 'énoncé'),
          (ItemFamily.exercise, 'exercice'),
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ItemGlyph(family: family, stage: GrowthStage.mature, size: 18),
              const SizedBox(width: 4),
              Text(label, style: style),
            ],
          ),
      ],
    );
  }
}
