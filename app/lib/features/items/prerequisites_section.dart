import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import '../../app/app_scope.dart';
import '../../ui/dialogs.dart';
import '../../ui/labels.dart';
import '../documents/pickers.dart';
import '../trees/node_picker.dart';
import 'item_detail_page.dart';

/// Prérequis d'une connaissance (ce sur quoi elle s'appuie) et connaissances
/// qui l'utilisent. Le graphe reste sans cycle : un lien qui en créerait un
/// est refusé.
class PrerequisitesSection extends StatefulWidget {
  const PrerequisitesSection({super.key, required this.item});

  final KnowledgeItem item;

  @override
  State<PrerequisitesSection> createState() => _PrerequisitesSectionState();
}

class _PrerequisitesSectionState extends State<PrerequisitesSection> {
  Stream<List<Prerequisite>>? _edges;
  Stream<List<KnowledgeItem>>? _items;
  Stream<List<KnowledgeNode>>? _nodes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context).store;
    _edges ??= store.watchPrerequisites();
    _items ??= store.watchItems();
    _nodes ??= store.watchNodes();
  }

  /// [requires] : ajouter un prérequis ; sinon une connaissance qui
  /// s'appuie sur celle-ci.
  Future<void> _add({
    required bool requires,
    required Set<String> linked,
  }) async {
    final store = AppScope.of(context).store;
    final picked = await pickItem(
      context,
      title: requires
          ? 'Prérequis de « ${widget.item.title} »'
          : 'Qui s\'appuie sur « ${widget.item.title} » ?',
      exclude: {widget.item.id, ...linked},
    );
    if (picked == null) return;
    try {
      requires
          ? await store.addPrerequisite(widget.item.id, picked.id)
          : await store.addPrerequisite(picked.id, widget.item.id);
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lien refusé : « ${picked.title} » '
            '${requires ? 's\'appuie déjà' : 'est déjà un prérequis'}, '
            'directement ou non, ${requires ? 'sur' : 'de'} cette connaissance.',
          ),
        ),
      );
    }
  }

  /// Lien vers [other] retiré : on propose de le remettre.
  Future<void> _undoable(KnowledgeItem other, Future<Deletion> removal) async {
    final store = AppScope.of(context).store;
    final messenger = ScaffoldMessenger.of(context);
    final deletion = await removal;
    showUndoSnackBar(
      messenger,
      message: 'Lien retiré : « ${other.title} »',
      onUndo: () => store.undoDeletion(deletion),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Prerequisite>>(
      stream: _edges,
      builder: (context, edges) => StreamBuilder<List<KnowledgeItem>>(
        stream: _items,
        builder: (context, items) => StreamBuilder<List<KnowledgeNode>>(
          stream: _nodes,
          builder: (context, nodes) {
            if (!edges.hasData || !items.hasData || !nodes.hasData) {
              return const SizedBox(height: 48);
            }
            final byId = {for (final i in items.data!) i.id: i};
            final nodeById = {for (final n in nodes.data!) n.id: n};
            final graph = PrerequisiteGraph(edges.data!);
            final id = widget.item.id;
            List<KnowledgeItem> resolve(Set<String> ids) =>
                [for (final i in ids) ?byId[i]]
                  ..sort((a, b) => a.title.compareTo(b.title));
            final requires = resolve(graph.requires(id));
            final usedBy = resolve(graph.usedBy(id));
            final store = AppScope.of(context).store;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LinkList(
                  label: 'S\'appuie sur',
                  empty: 'Aucun prérequis.',
                  items: requires,
                  path: (i) => nodePath(nodeById, i.nodeId),
                  onRemove: (other) =>
                      _undoable(other, store.removePrerequisite(id, other.id)),
                  addLabel: 'Prérequis',
                  onAdd: () => _add(
                    requires: true,
                    linked: {for (final i in requires) i.id},
                  ),
                ),
                const SizedBox(height: 16),
                _LinkList(
                  label: 'Utilisée par',
                  empty: 'Aucune connaissance ne s\'appuie sur celle-ci.',
                  items: usedBy,
                  path: (i) => nodePath(nodeById, i.nodeId),
                  onRemove: (other) =>
                      _undoable(other, store.removePrerequisite(other.id, id)),
                  addLabel: 'Utilisation',
                  onAdd: () => _add(
                    requires: false,
                    linked: {for (final i in usedBy) i.id},
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LinkList extends StatelessWidget {
  const _LinkList({
    required this.label,
    required this.empty,
    required this.items,
    required this.path,
    required this.onRemove,
    required this.addLabel,
    required this.onAdd,
  });

  final String label;
  final String empty;
  final List<KnowledgeItem> items;
  final String Function(KnowledgeItem) path;
  final void Function(KnowledgeItem) onRemove;
  final String addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.outline,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.labelLarge)),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(addLabel),
            ),
          ],
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(empty, style: muted),
          ),
        for (final other in items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${other.typeLabel} · ${other.title}'),
            subtitle: Text(path(other)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ItemDetailPage(itemId: other.id),
              ),
            ),
            trailing: IconButton(
              tooltip: 'Retirer le lien',
              icon: const Icon(Icons.link_off),
              onPressed: () => onRemove(other),
            ),
          ),
      ],
    );
  }
}
