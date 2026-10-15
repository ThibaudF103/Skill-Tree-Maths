import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import 'tree_data.dart';

/// Élément en cours de glisser-déposer dans l'onglet Arbres.
sealed class TreeDrag {
  const TreeDrag();
  String get label;
}

final class NodeDrag extends TreeDrag {
  const NodeDrag(this.node);
  final KnowledgeNode node;
  @override
  String get label => node.title;
}

final class ItemDrag extends TreeDrag {
  const ItemDrag(this.item);
  final KnowledgeItem item;
  @override
  String get label => item.title;
}

/// Où déposer par rapport à la ligne survolée.
enum DropPlace { before, inside, after }

/// Places acceptées quand [drag] survole le nœud [target].
Set<DropPlace> nodeDropPlaces(
  TreeData data,
  KnowledgeNode target,
  TreeDrag drag,
) {
  switch (drag) {
    case NodeDrag(:final node):
      // Ni sur lui-même, ni dans sa propre descendance.
      if (data.pathTo(target.id).any((n) => n.id == node.id)) return const {};
      return DropPlace.values.toSet();
    case ItemDrag(:final item):
      return item.nodeId == target.id ? const {} : const {DropPlace.inside};
  }
}

/// Places acceptées quand [drag] survole la connaissance [target].
Set<DropPlace> itemDropPlaces(KnowledgeItem target, TreeDrag drag) =>
    drag is ItemDrag && drag.item.id != target.id
    ? const {DropPlace.before, DropPlace.after}
    : const {};

/// Dépose [drag] sur le nœud [target].
Future<void> dropOnNode(
  VergerStore store,
  TreeData data,
  KnowledgeNode target,
  TreeDrag drag,
  DropPlace place,
) async {
  switch (drag) {
    case NodeDrag(:final node):
      if (place == DropPlace.inside) {
        await store.moveNode(node.id, newParentId: target.id);
        return;
      }
      final siblings = data
          .children(target.parentId)
          .where((n) => n.id != node.id)
          .toList();
      final index = siblings.indexWhere((n) => n.id == target.id);
      await store.moveNode(
        node.id,
        newParentId: target.parentId,
        index: place == DropPlace.after ? index + 1 : index,
      );
    case ItemDrag(:final item):
      await store.moveItem(item.id, nodeId: target.id);
  }
}

/// Dépose [drag] (une connaissance) avant ou après la connaissance [target].
Future<void> dropOnItem(
  VergerStore store,
  TreeData data,
  KnowledgeItem target,
  TreeDrag drag,
  DropPlace place,
) async {
  if (drag is! ItemDrag) return;
  final siblings = data
      .itemsIn(target.nodeId)
      .where((i) => i.id != drag.item.id)
      .toList();
  final index = siblings.indexWhere((i) => i.id == target.id);
  await store.moveItem(
    drag.item.id,
    nodeId: target.nodeId,
    index: place == DropPlace.after ? index + 1 : index,
  );
}

Widget _feedback(BuildContext context, TreeDrag drag) {
  final theme = Theme.of(context);
  return Material(
    elevation: 6,
    borderRadius: BorderRadius.circular(8),
    color: theme.colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Text(
          drag.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    ),
  );
}

/// Ligne déplaçable par appui long (tactile comme souris).
class TreeDraggable extends StatelessWidget {
  const TreeDraggable({super.key, required this.drag, required this.child});

  final TreeDrag drag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<TreeDrag>(
      data: drag,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _feedback(context, drag),
      childWhenDragging: Opacity(opacity: 0.4, child: child),
      child: child,
    );
  }
}

/// Poignée de déplacement immédiat (pratique à la souris).
class TreeDragHandle extends StatelessWidget {
  const TreeDragHandle({super.key, required this.drag});

  final TreeDrag drag;

  @override
  Widget build(BuildContext context) {
    return Draggable<TreeDrag>(
      data: drag,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _feedback(context, drag),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Tooltip(
          message: 'Glisser pour déplacer',
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              Icons.drag_indicator,
              size: 18,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      ),
    );
  }
}

/// Cible de dépôt : avant / dans / après selon la hauteur du pointeur, avec
/// un repère visuel.
class TreeDropTarget extends StatefulWidget {
  const TreeDropTarget({
    super.key,
    required this.places,
    required this.onDrop,
    required this.child,
  });

  final Set<DropPlace> Function(TreeDrag drag) places;
  final Future<void> Function(TreeDrag drag, DropPlace place) onDrop;
  final Widget child;

  @override
  State<TreeDropTarget> createState() => _TreeDropTargetState();
}

class _TreeDropTargetState extends State<TreeDropTarget> {
  DropPlace? _hover;

  DropPlace? _placeAt(Offset global, TreeDrag drag) {
    final allowed = widget.places(drag);
    if (allowed.isEmpty) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return allowed.first;
    final f = box.globalToLocal(global).dy / box.size.height;
    final edges = allowed.contains(DropPlace.before);
    if (!edges) return DropPlace.inside;
    if (!allowed.contains(DropPlace.inside)) {
      return f < 0.5 ? DropPlace.before : DropPlace.after;
    }
    return f < 0.25
        ? DropPlace.before
        : f > 0.75
        ? DropPlace.after
        : DropPlace.inside;
  }

  Future<void> _drop(TreeDrag drag, DropPlace place) async {
    try {
      await widget.onDrop(drag, place);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Déplacement impossible : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return DragTarget<TreeDrag>(
      onWillAcceptWithDetails: (d) => widget.places(d.data).isNotEmpty,
      onMove: (d) {
        final place = _placeAt(d.offset, d.data);
        if (place != _hover) setState(() => _hover = place);
      },
      onLeave: (_) => setState(() => _hover = null),
      onAcceptWithDetails: (d) {
        final place = _placeAt(d.offset, d.data) ?? _hover;
        setState(() => _hover = null);
        if (place != null) _drop(d.data, place);
      },
      builder: (context, _, _) => Stack(
        children: [
          widget.child,
          if (_hover != null)
            Positioned.fill(
              child: IgnorePointer(
                child: switch (_hover!) {
                  DropPlace.inside => DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      border: Border.all(color: color, width: 2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  DropPlace.before => Align(
                    alignment: Alignment.topCenter,
                    child: Container(height: 3, color: color),
                  ),
                  DropPlace.after => Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(height: 3, color: color),
                  ),
                },
              ),
            ),
        ],
      ),
    );
  }
}
