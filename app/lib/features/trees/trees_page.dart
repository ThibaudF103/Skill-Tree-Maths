import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../ui/dialogs.dart';
import '../data/data_actions.dart';
import '../data/pack_actions.dart';
import 'node_detail.dart';
import 'reorder.dart';
import 'tree_data.dart';

/// Vue « Arbres » : plan hiérarchique à gauche, contenu du nœud à droite sur
/// grand écran ; navigation par pages sur téléphone.
class TreesPage extends StatefulWidget {
  const TreesPage({super.key});

  @override
  State<TreesPage> createState() => _TreesPageState();
}

class _TreesPageState extends State<TreesPage> {
  String? _selected;
  final _expanded = <String>{};

  void _select(TreeData data, String? id) {
    setState(() {
      _selected = id;
      if (id != null) _expanded.addAll(data.pathTo(id).map((n) => n.id));
    });
  }

  Future<void> _createTree(TreeData data) async {
    final store = AppScope.of(context).store;
    final name = await askName(
      context,
      title: 'Nouvel arbre',
      hint: 'Algèbre',
      confirm: 'Créer',
    );
    if (name == null) return;
    final tree = await store.createNode(title: name);
    if (mounted && MediaQuery.sizeOf(context).width >= 900) {
      setState(() => _selected = tree.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TreeDataBuilder(
      builder: (context, data) {
        if (data.trees.isEmpty) {
          return _EmptyOrchard(onCreate: () => _createTree(data));
        }
        final wide = MediaQuery.sizeOf(context).width >= 900;
        if (!wide) {
          return _Outline(
            data: data,
            expanded: _expanded,
            selected: null,
            onToggle: (id) => setState(
              () => _expanded.contains(id)
                  ? _expanded.remove(id)
                  : _expanded.add(id),
            ),
            onSelect: (id) => _openPage(context, id),
            onCreateTree: () => _createTree(data),
            onExpand: (id) => setState(() => _expanded.add(id)),
          );
        }
        final selected = data.byId.containsKey(_selected)
            ? _selected!
            : data.trees.first.id;
        // Le chemin du nœud affiché reste déplié dans le plan.
        _expanded.addAll(data.pathTo(selected).map((n) => n.id));
        return Row(
          children: [
            SizedBox(
              width: 320,
              child: _Outline(
                data: data,
                expanded: _expanded,
                selected: selected,
                onToggle: (id) => setState(
                  () => _expanded.contains(id)
                      ? _expanded.remove(id)
                      : _expanded.add(id),
                ),
                onSelect: (id) => _select(data, id),
                onCreateTree: () => _createTree(data),
                onExpand: (id) => setState(() => _expanded.add(id)),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: NodeDetail(
                key: ValueKey(selected),
                data: data,
                nodeId: selected,
                onSelect: (id) => _select(data, id),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openPage(BuildContext context, String id) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => NodePage(nodeId: id)));
  }
}

/// Page d'un nœud (téléphone).
class NodePage extends StatelessWidget {
  const NodePage({super.key, required this.nodeId});

  final String nodeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: TreeDataBuilder(
        builder: (context, data) => NodeDetail(
          data: data,
          nodeId: nodeId,
          onSelect: (id) {
            if (id == null || data.byId[nodeId]?.parentId == id) {
              Navigator.of(context).maybePop();
            } else {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => NodePage(nodeId: id)),
              );
            }
          },
        ),
      ),
    );
  }
}

class _Outline extends StatelessWidget {
  const _Outline({
    required this.data,
    required this.expanded,
    required this.selected,
    required this.onToggle,
    required this.onSelect,
    required this.onCreateTree,
    required this.onExpand,
  });

  final TreeData data;
  final Set<String> expanded;
  final String? selected;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onSelect;
  final VoidCallback onCreateTree;

  /// Déplie un nœud (après y avoir déposé un élément).
  final ValueChanged<String> onExpand;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    final rows = <(KnowledgeNode, int)>[];
    void visit(String? parentId, int depth) {
      for (final node in data.children(parentId)) {
        rows.add((node, depth));
        if (expanded.contains(node.id)) visit(node.id, depth + 1);
      }
    }

    visit(null, 0);
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Arbres', style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: 'Nouvel arbre',
                  icon: const Icon(Icons.add),
                  onPressed: onCreateTree,
                ),
                const DataMenuButton(),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final (node, depth) = rows[i];
                final hasChildren = data.children(node.id).isNotEmpty;
                final progress = data.progress[node.id]!;
                final isSelected = node.id == selected;
                final row = Material(
                  color: isSelected
                      ? theme.colorScheme.secondaryContainer
                      : Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelect(node.id),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 8.0 + depth * 18,
                        right: 4,
                      ),
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: hasChildren
                                  ? IconButton(
                                      iconSize: 20,
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(
                                        expanded.contains(node.id)
                                            ? Icons.expand_more
                                            : Icons.chevron_right,
                                      ),
                                      onPressed: () => onToggle(node.id),
                                    )
                                  : null,
                            ),
                            Expanded(
                              child: Text(
                                node.title,
                                overflow: TextOverflow.ellipsis,
                                style: node.isTree
                                    ? theme.textTheme.titleSmall
                                    : theme.textTheme.bodyMedium,
                              ),
                            ),
                            if (progress.dueCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.water_drop,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            if (!progress.isEmpty)
                              Text(
                                '${progress.itemCount}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            TreeDragHandle(drag: NodeDrag(node)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
                return TreeDropTarget(
                  places: (drag) => nodeDropPlaces(data, node, drag),
                  onDrop: (drag, place) async {
                    await dropOnNode(store, data, node, drag, place);
                    if (place == DropPlace.inside) onExpand(node.id);
                  },
                  child: TreeDraggable(drag: NodeDrag(node), child: row),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrchard extends StatelessWidget {
  const _EmptyOrchard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.park_outlined,
                size: 56,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text('Le verger est vide', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Commencez par planter un arbre pour un domaine du programme, '
                'par exemple « Algèbre ».',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Planter un arbre'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => loadSample(context),
                child: const Text('Essayer avec l\'exemple « Algèbre »'),
              ),
              TextButton(
                onPressed: () => importPackFile(context),
                child: const Text('Importer un paquet (arbre + contenus)'),
              ),
              TextButton(
                onPressed: () => restoreBackup(context),
                child: const Text('Restaurer une sauvegarde'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
