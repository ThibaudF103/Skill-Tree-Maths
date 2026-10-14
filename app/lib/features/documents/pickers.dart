import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import '../../app/app_scope.dart';
import '../../ui/item_glyph.dart';
import '../../ui/labels.dart';

/// Minuscules sans accents, pour une recherche tolérante.
String normalizeForSearch(String text) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    final i = from.indexOf(char);
    buffer.write(i < 0 ? char : to[i]);
  }
  return buffer.toString();
}

Map<String, String> _paths(List<KnowledgeNode> nodes) {
  final byId = {for (final n in nodes) n.id: n};
  String path(String id) {
    final parts = <String>[];
    for (var n = byId[id]; n != null; n = byId[n.parentId]) {
      parts.insert(0, n.title);
      if (parts.length > nodes.length) break;
    }
    return parts.join(' › ');
  }

  return {for (final n in nodes) n.id: path(n.id)};
}

/// Choisit une connaissance existante (recherche par titre ou chemin).
Future<KnowledgeItem?> pickItem(BuildContext context, {required String title}) {
  return showDialog<KnowledgeItem>(
    context: context,
    builder: (_) => _PickerDialog<KnowledgeItem>(
      title: title,
      hint: 'Rechercher une connaissance',
      load: (store) async {
        final paths = _paths(await store.allNodes());
        return [
          for (final item in await store.allItems())
            (
              value: item,
              title: item.title,
              subtitle: '${item.kind.label} · ${paths[item.nodeId] ?? ''}',
              leading: ItemGlyph(
                family: item.kind.family,
                stage: GrowthStage.of(item.scheduling),
                size: 28,
              ),
              indent: 0,
            ),
        ];
      },
    ),
  );
}

/// Choisit un nœud (arbre ou branche).
Future<KnowledgeNode?> pickNode(BuildContext context, {required String title}) {
  return showDialog<KnowledgeNode>(
    context: context,
    builder: (_) => _PickerDialog<KnowledgeNode>(
      title: title,
      hint: 'Rechercher une branche',
      load: (store) async {
        final nodes = await store.allNodes();
        final paths = _paths(nodes);
        final children = <String?, List<KnowledgeNode>>{};
        for (final n in nodes) {
          (children[n.parentId] ??= []).add(n);
        }
        final rows = <_Row<KnowledgeNode>>[];
        void visit(String? parent, int depth) {
          for (final n in children[parent] ?? const <KnowledgeNode>[]) {
            rows.add((
              value: n,
              title: n.title,
              subtitle: paths[n.id]!,
              leading: null,
              indent: depth,
            ));
            visit(n.id, depth + 1);
          }
        }

        visit(null, 0);
        return rows;
      },
    ),
  );
}

typedef _Row<T> = ({
  T value,
  String title,
  String subtitle,
  Widget? leading,
  int indent,
});

class _PickerDialog<T> extends StatefulWidget {
  const _PickerDialog({
    required this.title,
    required this.hint,
    required this.load,
  });

  final String title;
  final String hint;
  final Future<List<_Row<T>>> Function(VergerStore store) load;

  @override
  State<_PickerDialog<T>> createState() => _PickerDialogState<T>();
}

class _PickerDialogState<T> extends State<_PickerDialog<T>> {
  Future<List<_Row<T>>>? _rows;
  var _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rows ??= widget.load(AppScope.of(context).store);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        height: 460,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: widget.hint,
              ),
              onChanged: (v) => setState(() => _query = normalizeForSearch(v)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<_Row<T>>>(
                future: _rows,
                builder: (context, snapshot) {
                  final rows = snapshot.data;
                  if (rows == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final filtered = _query.isEmpty
                      ? rows
                      : rows
                            .where(
                              (r) => normalizeForSearch(
                                '${r.title} ${r.subtitle}',
                              ).contains(_query),
                            )
                            .toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'Aucun résultat',
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final row = filtered[i];
                      return ListTile(
                        contentPadding: EdgeInsets.only(
                          left: 8.0 + (_query.isEmpty ? row.indent * 18 : 0),
                          right: 8,
                        ),
                        leading: row.leading,
                        title: Text(row.title),
                        subtitle: Text(
                          row.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, row.value),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}
