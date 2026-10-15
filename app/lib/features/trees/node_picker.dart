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
  final picked = await showDialog<Object>(
    context: context,
    builder: (_) => _NodePickerDialog(title: title, initialId: initial),
  );
  return picked is KnowledgeNode ? picked : null;
}

/// Coche plusieurs nœuds (cocher un nœud couvre toute sa descendance).
/// Renvoie l'ensemble choisi (vide : tout le verger), ou `null` si annulé.
Future<Set<String>?> pickNodes(
  BuildContext context, {
  required String title,
  Set<String> initial = const {},
}) async {
  final picked = await showDialog<Object>(
    context: context,
    builder: (_) =>
        _NodePickerDialog(title: title, initialId: null, checked: initial),
  );
  return picked is Set<String> ? picked : null;
}

class _NodePickerDialog extends StatefulWidget {
  const _NodePickerDialog({
    required this.title,
    required this.initialId,
    this.checked,
  });

  final String title;
  final String? initialId;

  /// Mode cases à cocher : nœuds cochés au départ.
  final Set<String>? checked;

  @override
  State<_NodePickerDialog> createState() => _NodePickerDialogState();
}

class _NodePickerDialogState extends State<_NodePickerDialog> {
  Stream<List<KnowledgeNode>>? _nodes;
  final _expanded = <String>{};
  late String? _selected = widget.initialId;
  late final Set<String>? _checked = widget.checked == null
      ? null
      : {...widget.checked!};
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
        if (_revealSelected && nodes != null) {
          for (final id in [?selected?.id, ...?_checked]) {
            _reveal(byId, id);
          }
          _revealSelected = false;
        }
        final checked = _checked;
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
          actions: checked != null
              ? [
                  TextButton(
                    onPressed: () => Navigator.pop(context, <String>{}),
                    child: const Text('Tout le verger'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, {
                      for (final id in checked)
                        if (byId.containsKey(id)) id,
                    }),
                    child: const Text('Valider'),
                  ),
                ]
              : [
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
        final checked = _checked;
        // Couvert par un ancêtre coché : coché d'office.
        var covered = false;
        for (var p = byId[node.parentId]; p != null; p = byId[p.parentId]) {
          if (checked?.contains(p.id) ?? false) covered = true;
        }
        void toggle() => setState(() {
          if (checked!.remove(node.id)) return;
          // Cocher un nœud rend inutiles les coches de sa descendance.
          checked.removeWhere((id) => _isDescendant(byId, id, node.id));
          checked.add(node.id);
        });
        return Material(
          color: isSelected
              ? theme.colorScheme.secondaryContainer
              : Colors.transparent,
          child: InkWell(
            // Un clic choisit la branche ; « Choisir » valide la sélection
            // courante (utile après une création).
            onTap: checked == null
                ? () => Navigator.pop(context, node)
                : covered
                ? null
                : toggle,
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
                    if (checked != null)
                      Checkbox(
                        value: covered || checked.contains(node.id),
                        onChanged: covered ? null : (_) => toggle(),
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
                    if (checked == null)
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

  static bool _isDescendant(
    Map<String, KnowledgeNode> byId,
    String id,
    String ancestorId,
  ) {
    for (var p = byId[byId[id]?.parentId]; p != null; p = byId[p.parentId]) {
      if (p.id == ancestorId) return true;
    }
    return false;
  }
}
