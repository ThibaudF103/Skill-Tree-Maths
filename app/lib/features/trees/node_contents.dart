import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../documents/document_actions.dart';
import 'tree_data.dart';

/// Section « Contenus » d'un nœud : contenus rattachés au nœud, puis ceux
/// hérités de ses ancêtres (un poly rattaché à l'arbre sert à toutes ses
/// branches).
class NodeContents extends StatefulWidget {
  const NodeContents({super.key, required this.data, required this.node});

  final TreeData data;
  final KnowledgeNode node;

  @override
  State<NodeContents> createState() => _NodeContentsState();
}

class _NodeContentsState extends State<NodeContents> {
  Stream<List<SourceDocument>>? _documents;
  Stream<List<ResourceLink>>? _links;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context).store;
    _documents ??= store.watchDocuments();
    _links ??= store.watchResourceLinks();
  }

  Future<void> _linkExisting(Set<String> own) async {
    final store = AppScope.of(context).store;
    final document = await pickResource(
      context,
      title: 'Rattacher à « ${widget.node.title} »',
      exclude: own,
    );
    if (document != null) await store.linkResource(document.id, widget.node.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<SourceDocument>>(
      stream: _documents,
      builder: (context, docs) => StreamBuilder<List<ResourceLink>>(
        stream: _links,
        builder: (context, links) {
          final byId = {for (final d in docs.data ?? const []) d.id: d};
          final path = widget.data.pathTo(widget.node.id);
          // Contenu → nœud le plus proche (le nœud lui-même d'abord).
          final source = <String, KnowledgeNode>{};
          for (final node in path.reversed) {
            for (final l in links.data ?? const <ResourceLink>[]) {
              if (l.nodeId == node.id && byId.containsKey(l.documentId)) {
                source.putIfAbsent(l.documentId, () => node);
              }
            }
          }
          final own = {
            for (final e in source.entries)
              if (e.value.id == widget.node.id) e.key,
          };
          final entries = source.entries.toList()
            ..sort((a, b) {
              final ownA = a.value.id == widget.node.id ? 0 : 1;
              final ownB = b.value.id == widget.node.id ? 0 : 1;
              return ownA != ownB
                  ? ownA - ownB
                  : byId[a.key]!.title.compareTo(byId[b.key]!.title);
            });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Contenus', style: theme.textTheme.titleMedium),
                  ),
                  MenuAnchor(
                    builder: (context, controller, _) => TextButton.icon(
                      onPressed: () => controller.isOpen
                          ? controller.close()
                          : controller.open(),
                      icon: const Icon(Icons.add),
                      label: const Text('Contenu'),
                    ),
                    menuChildren: [
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.upload_file),
                        onPressed: () =>
                            importPdf(context, nodeId: widget.node.id),
                        child: const Text('Importer un PDF'),
                      ),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.link),
                        onPressed: () => _linkExisting(own),
                        child: const Text('Rattacher un contenu existant'),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  child: Text(
                    'Aucun contenu : rattachez le PDF du cours (ou une vidéo) '
                    'pour y encadrer énoncés et rédactions.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              for (final e in entries)
                _ContentTile(
                  document: byId[e.key]!,
                  inheritedFrom: e.value.id == widget.node.id ? null : e.value,
                  onUnlink: () => AppScope.of(
                    context,
                  ).store.unlinkResource(e.key, widget.node.id),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ContentTile extends StatelessWidget {
  const _ContentTile({
    required this.document,
    required this.inheritedFrom,
    required this.onUnlink,
  });

  final SourceDocument document;

  /// Ancêtre auquel le contenu est rattaché (`null` : ce nœud).
  final KnowledgeNode? inheritedFrom;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final from = inheritedFrom;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(resourceIcon(document), color: theme.colorScheme.primary),
      title: Text(document.title),
      subtitle: Text(
        [
          if (document.isPdf) '${document.pageCount} pages' else 'Vidéo',
          if (from != null) 'via « ${from.title} »',
        ].join(' · '),
      ),
      onTap: () => openResource(context, document),
      trailing: from != null
          ? null
          : IconButton(
              tooltip: 'Détacher de cette branche',
              icon: const Icon(Icons.link_off),
              onPressed: onUnlink,
            ),
    );
  }
}
