import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../ui/dialogs.dart';
import '../documents/pickers.dart' show normalizeForSearch;

/// Chemin « Arbre › Branche › … » de [id].
String nodePath(Map<String, KnowledgeNode> byId, String id) {
  final parts = <String>[];
  for (var n = byId[id]; n != null; n = byId[n.parentId]) {
    parts.insert(0, n.title);
    if (parts.length > byId.length) break;
  }
  return parts.join(' › ');
}

/// Choisit un nœud (arbre ou branche) dans l'arborescence repliable, avec
/// création d'arbres et de branches sur place. [initialId] est présélectionné
/// (par défaut : la dernière branche utilisée).
Future<KnowledgeNode?> pickNode(
  BuildContext context, {
  required String title,
  String? initialId,
}) async {
  final store = AppScope.of(context).store;
  final initial = initialId ?? (await store.lastNode())?.id;
  if (!context.mounted) return null;
  return showDialog<KnowledgeNode>(
    context: context,
    builder: (_) => _NodePickerDialog(title: title, initialId: initial),
  );
}

class _NodePickerDialog extends StatefulWidget {
  const _NodePickerDialog({required this.title, required this.initialId});

  final String title;
  final String? initialId;

  @override
  State<_NodePickerDialog> createState() => _NodePickerDialogState();
}

class _NodePickerDialogState extends State<_NodePickerDialog> {
  Stream<List<KnowledgeNode>>? _nodes;
  final _expanded = <String>{};
  late String? _selected = widget.initialId;
  var _revealSelected = true;
  var _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _nodes ??= AppScope.of(context).store.watchNodes();
  }

  void _reveal(Map<String, KnowledgeNode> byId, String id) {
    for (var n = byId[byId[id]?.parentId]; n != null; n = byId[n.parentId]) {
      if (!_expanded.add(n.id)) break;
    }
  }

  Future<void> _create({KnowledgeNode? parent}) async {
    final name = await askName(
      context,
      title: parent == null ? 'Nouvel arbre' : 'Nouvelle branche',
      hint: parent == null ? 'Algèbre' : 'Sous-branche de ${parent.title}',
      confirm: 'Créer',
    );
    if (name == null || !mounted) return;
    final node = await AppScope.of(
      context,
    ).store.createNode(title: name, parentId: parent?.id);
    if (!mounted) return;
    setState(() {
      if (parent != null) _expanded.add(parent.id);
      _selected = node.id;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<KnowledgeNode>>(
      stream: _nodes,
      builder: (context, snapshot) {
        final nodes = snapshot.data;
        final byId = {
          for (final n in nodes ?? const <KnowledgeNode>[]) n.id: n,
        };
        final selected = byId[_selected];
        if (_revealSelected && selected != null) {
          _reveal(byId, selected.id);
          _revealSelected = false;
        }
        return AlertDialog(
          title: Text(widget.title),
          content: SizedBox(
            width: 520,
            height: 460,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Rechercher une branche',
                  ),
                  onChanged: (v) =>
                      setState(() => _query = normalizeForSearch(v)),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: nodes == null
                      ? const Center(child: CircularProgressIndicator())
                      : _list(theme, nodes, byId),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => _create(),
              icon: const Icon(Icons.add),
              label: const Text('Nouvel arbre'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(context, selected),
              child: const Text('Choisir'),
            ),
          ],
        );
      },
    );
  }

  Widget _list(
    ThemeData theme,
    List<KnowledgeNode> nodes,
    Map<String, KnowledgeNode> byId,
  ) {
    final children = <String?, List<KnowledgeNode>>{};
    for (final n in nodes) {
      (children[n.parentId] ??= []).add(n);
    }
    final rows = <(KnowledgeNode, int)>[];
    if (_query.isEmpty) {
      void visit(String? parent, int depth) {
        for (final n in children[parent] ?? const <KnowledgeNode>[]) {
          rows.add((n, depth));
          if (_expanded.contains(n.id)) visit(n.id, depth + 1);
        }
      }

      visit(null, 0);
    } else {
      for (final n in nodes) {
        if (normalizeForSearch(nodePath(byId, n.id)).contains(_query)) {
          rows.add((n, 0));
        }
      }
    }
    if (rows.isEmpty) {
      return Center(
        child: Text(
          nodes.isEmpty ? 'Aucun arbre : créez-en un.' : 'Aucun résultat',
          style: TextStyle(color: theme.colorScheme.outline),
        ),
      );
    }
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final (node, depth) = rows[i];
        final hasChildren = children[node.id]?.isNotEmpty ?? false;
        final isSelected = node.id == _selected;
        final expanded = _expanded.contains(node.id);
        return Material(
          color: isSelected
              ? theme.colorScheme.secondaryContainer
              : Colors.transparent,
          child: InkWell(
            // Un clic choisit la branche ; « Choisir » valide la sélection
            // courante (utile après une création).
            onTap: () => Navigator.pop(context, node),
            child: Padding(
              padding: EdgeInsets.only(left: 4.0 + depth * 18),
              child: SizedBox(
                height: _query.isEmpty ? 44 : 56,
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: hasChildren && _query.isEmpty
                          ? IconButton(
                              tooltip: expanded ? 'Replier' : 'Déplier',
                              iconSize: 20,
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                expanded
                                    ? Icons.expand_more
                                    : Icons.chevron_right,
                              ),
                              onPressed: () => setState(
                                () => expanded
                                    ? _expanded.remove(node.id)
                                    : _expanded.add(node.id),
                              ),
                            )
                          : null,
                    ),
                    Expanded(
                      child: _query.isEmpty
                          ? Text(
                              node.title,
                              overflow: TextOverflow.ellipsis,
                              style: node.isTree
                                  ? theme.textTheme.titleSmall
                                  : theme.textTheme.bodyMedium,
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(node.title),
                                Text(
                                  nodePath(byId, node.id),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    IconButton(
                      tooltip: 'Nouvelle branche dans « ${node.title} »',
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add),
                      onPressed: () => _create(parent: node),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
