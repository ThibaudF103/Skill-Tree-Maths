import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../ui/dialogs.dart';
import '../../ui/item_glyph.dart';
import '../data/pack_actions.dart';
import '../documents/content_import.dart';
import '../items/item_detail_page.dart';
import '../items/item_editor.dart';
import '../items/item_tile.dart';
import '../review/reviews_page.dart';
import '../skills/skill_graph_page.dart';
import '../worksheets/worksheet_dialog.dart';
import 'node_contents.dart';
import 'node_picker.dart';
import 'reorder.dart';
import 'tree_data.dart';

/// Contenu d'un nœud : chemin, sous-branches et connaissances.
class NodeDetail extends StatelessWidget {
  const NodeDetail({
    super.key,
    required this.data,
    required this.nodeId,
    required this.onSelect,
  });

  final TreeData data;
  final String nodeId;

  /// Navigation vers un autre nœud (`null` : retour à la liste des arbres).
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final node = data.byId[nodeId];
    if (node == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final path = data.pathTo(nodeId);
    final children = data.children(nodeId);
    final items = data.itemsIn(nodeId);
    final progress = data.progress[nodeId]!;
    final store = AppScope.of(context).store;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
      children: [
        _Breadcrumb(path: path, onSelect: onSelect),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(node.title, style: theme.textTheme.headlineMedium),
            ),
            IconButton(
              tooltip: 'Arbre de compétences',
              onPressed: () => openSkillGraph(context, node.id),
              icon: const Icon(Icons.account_tree_outlined),
            ),
            _NodeMenu(data: data, node: node, onSelect: onSelect),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _summary(progress),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 24),
        _SectionHeader(
          title: node.isTree ? 'Branches' : 'Sous-branches',
          action: TextButton.icon(
            onPressed: () => addChildNode(context, node),
            icon: const Icon(Icons.add),
            label: const Text('Branche'),
          ),
        ),
        if (children.isEmpty)
          _Hint(
            node.isTree
                ? 'Organisez ce domaine en branches (ex. « Réduction des endomorphismes »).'
                : 'Aucune sous-branche.',
          )
        else
          for (final child in children)
            TreeDropTarget(
              places: (drag) => nodeDropPlaces(data, child, drag),
              onDrop: (drag, place) =>
                  dropOnNode(store, data, child, drag, place),
              child: TreeDraggable(
                drag: NodeDrag(child),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Icon(
                    Icons.subdirectory_arrow_right,
                    color: theme.colorScheme.outline,
                  ),
                  title: Text(child.title),
                  subtitle: Text(_summary(data.progress[child.id]!)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TreeDragHandle(drag: NodeDrag(child)),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => onSelect(child.id),
                ),
              ),
            ),
        const SizedBox(height: 24),
        NodeContents(data: data, node: node),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Connaissances',
          action: MenuAnchor(
            builder: (context, controller, _) => FilledButton.tonalIcon(
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            ),
            menuChildren: [
              for (final family in ItemFamily.values)
                MenuItemButton(
                  leadingIcon: ItemGlyph(
                    family: family,
                    stage: GrowthStage.mature,
                    size: 22,
                  ),
                  onPressed: () =>
                      showItemEditor(context, nodeId: node.id, family: family),
                  child: Text(switch (family) {
                    ItemFamily.definition => 'Définition',
                    ItemFamily.statement => 'Propriété / théorème',
                    ItemFamily.exercise => 'Exercice',
                  }),
                ),
            ],
          ),
        ),
        if (items.isEmpty)
          const _Hint(
            'Aucune connaissance ici pour l\'instant : un rameau en hiver.',
          )
        else
          for (final item in items)
            TreeDropTarget(
              places: (drag) => itemDropPlaces(item, drag),
              onDrop: (drag, place) =>
                  dropOnItem(store, data, item, drag, place),
              child: TreeDraggable(
                drag: ItemDrag(item),
                child: ItemTile(
                  item: item,
                  now: data.now,
                  dragHandle: TreeDragHandle(drag: ItemDrag(item)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ItemDetailPage(itemId: item.id),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  static String _summary(NodeProgress p) {
    if (p.isEmpty) return 'Aucune connaissance';
    final parts = [
      p.itemCount == 1 ? '1 connaissance' : '${p.itemCount} connaissances',
      if (p.dueCount > 0) '${p.dueCount} à réviser',
      'maîtrise ${(p.meanMastery * 100).round()} %',
    ];
    return parts.join(' · ');
  }
}

/// Demande un nom puis crée un sous-nœud de [parent].
Future<void> addChildNode(BuildContext context, KnowledgeNode parent) async {
  final store = AppScope.of(context).store;
  final name = await askName(
    context,
    title: 'Nouvelle branche dans « ${parent.title} »',
    hint: 'Espaces vectoriels de dimension finie',
    confirm: 'Créer',
  );
  if (name != null) await store.createNode(title: name, parentId: parent.id);
}

class _NodeMenu extends StatelessWidget {
  const _NodeMenu({
    required this.data,
    required this.node,
    required this.onSelect,
  });

  final TreeData data;
  final KnowledgeNode node;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      onSelected: (action) async {
        switch (action) {
          case 'rename':
            final name = await askName(
              context,
              title: 'Renommer',
              initial: node.title,
            );
            if (name != null) await store.renameNode(node.id, name);
          case 'move':
            final target = await pickNode(
              context,
              title: 'Déplacer « ${node.title} » dans…',
              initialId: node.parentId,
            );
            if (target == null || target.id == node.parentId) return;
            if (data.pathTo(target.id).any((n) => n.id == node.id)) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Impossible de déplacer une branche dans elle-même.',
                    ),
                  ),
                );
              }
              return;
            }
            await store.moveNode(node.id, newParentId: target.id);
          case 'tree':
            await store.moveNode(node.id);
          case 'skills':
            openSkillGraph(context, node.id);
          case 'content':
            await importContent(context, nodeId: node.id);
          case 'share':
            await exportTreePack(context, node);
          case 'worksheets':
            await printWorksheets(
              context,
              title: node.title,
              items: data.subtreeItems(node.id),
            );
          case 'review':
            final ids = await loadReviewQueue(
              context,
              data.subtreeItems(node.id),
              data.items,
            );
            if (!context.mounted) return;
            if (ids.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Rien à réviser dans « ${node.title} » pour le moment.',
                  ),
                ),
              );
            } else {
              startReviewSession(context, ids);
            }
          case 'delete':
            final branches = _descendantCount(node.id);
            final items = data.subtreeItems(node.id).length;
            final empty = branches == 0 && items == 0;
            final ok = await confirmDestructive(
              context,
              title: 'Supprimer « ${node.title} » ?',
              message: empty
                  ? 'Cette branche est vide.'
                  : 'Seront aussi supprimés définitivement : '
                        '$branches sous-branche(s) et $items connaissance(s), '
                        'avec leur historique de révision.',
            );
            if (!ok) return;
            onSelect(node.parentId);
            await store.deleteNode(node.id, recursive: true);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'review',
          child: Text(
            node.isTree ? 'Réviser cet arbre' : 'Réviser cette branche',
          ),
        ),
        const PopupMenuItem(
          value: 'skills',
          child: Text('Arbre de compétences'),
        ),
        const PopupMenuItem(
          value: 'worksheets',
          child: Text('Fiches d\'exercices par élève (PDF)…'),
        ),
        const PopupMenuItem(
          value: 'content',
          child: Text('Importer un contenu (PDF, vidéo)…'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'share',
          child: Text('Partager (paquet avec contenus)…'),
        ),
        const PopupMenuItem(value: 'rename', child: Text('Renommer')),
        const PopupMenuItem(value: 'move', child: Text('Déplacer vers…')),
        if (!node.isTree)
          const PopupMenuItem(value: 'tree', child: Text('En faire un arbre')),
        const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
      ],
    );
  }

  int _descendantCount(String id) {
    var count = 0;
    for (final child in data.children(id)) {
      count += 1 + _descendantCount(child.id);
    }
    return count;
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.path, required this.onSelect});

  final List<KnowledgeNode> path;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.outline,
    );
    if (path.length < 2) return const SizedBox(height: 20);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (i, node) in path.take(path.length - 1).indexed) ...[
          if (i > 0) Text(' › ', style: style),
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => onSelect(node.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
              child: Text(node.title, style: style),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});
  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            action,
          ],
        ),
        const Divider(),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}
