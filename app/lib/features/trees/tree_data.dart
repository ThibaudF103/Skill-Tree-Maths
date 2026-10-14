import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';

/// Instantané de la hiérarchie et des connaissances, avec la progression
/// calculée pour chaque nœud.
class TreeData {
  TreeData({
    required this.nodes,
    required this.items,
    required Scheduler scheduler,
    required MasteryModel mastery,
    required this.now,
  }) {
    for (final node in nodes) {
      byId[node.id] = node;
      (childrenOf[node.parentId] ??= []).add(node);
    }
    for (final item in items) {
      (itemsOf[item.nodeId] ??= []).add(item);
    }
    final window = DayWindow.around(now);
    progress = aggregateProgress(
      parentOf: {for (final n in nodes) n.id: n.parentId},
      items: [
        for (final item in items)
          if (!item.suspended)
            (
              nodeId: item.nodeId,
              stage: GrowthStage.of(item.scheduling),
              mastery: mastery.of(
                item.scheduling,
                scheduler.retrievability(item.scheduling, now),
              ),
              isDue: _isDue(item.scheduling, window),
            ),
      ],
    );
  }

  final List<KnowledgeNode> nodes;
  final List<KnowledgeItem> items;
  final DateTime now;
  final Map<String, KnowledgeNode> byId = {};
  final Map<String?, List<KnowledgeNode>> childrenOf = {};
  final Map<String, List<KnowledgeItem>> itemsOf = {};
  late final Map<String, NodeProgress> progress;

  List<KnowledgeNode> get trees => childrenOf[null] ?? const [];

  List<KnowledgeNode> children(String? id) => childrenOf[id] ?? const [];

  List<KnowledgeItem> itemsIn(String id) => itemsOf[id] ?? const [];

  /// Chemin depuis la racine jusqu'au nœud inclus.
  List<KnowledgeNode> pathTo(String id) {
    final path = <KnowledgeNode>[];
    for (var node = byId[id]; node != null; node = byId[node.parentId]) {
      path.insert(0, node);
      if (path.length > nodes.length) break; // garde-fou contre un cycle
    }
    return path;
  }

  static bool _isDue(SchedulingState s, DayWindow window) =>
      !s.isNew && s.due != null && s.due!.isBefore(window.startOfTomorrow);
}

/// Reconstruit [builder] à chaque modification des nœuds ou des connaissances.
class TreeDataBuilder extends StatefulWidget {
  const TreeDataBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, TreeData data) builder;

  @override
  State<TreeDataBuilder> createState() => _TreeDataBuilderState();
}

class _TreeDataBuilderState extends State<TreeDataBuilder> {
  AppScope? _scope;
  late Stream<List<KnowledgeNode>> _nodes;
  late Stream<List<KnowledgeItem>> _items;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    if (_scope?.store != scope.store) {
      _nodes = scope.store.watchNodes();
      _items = scope.store.watchItems();
    }
    _scope = scope;
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope!;
    return StreamBuilder<List<KnowledgeNode>>(
      stream: _nodes,
      builder: (context, nodes) => StreamBuilder<List<KnowledgeItem>>(
        stream: _items,
        builder: (context, items) {
          if (!nodes.hasData || !items.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return widget.builder(
            context,
            TreeData(
              nodes: nodes.data!,
              items: items.data!,
              scheduler: scope.scheduler,
              mastery: scope.mastery,
              now: DateTime.now(),
            ),
          );
        },
      ),
    );
  }
}
