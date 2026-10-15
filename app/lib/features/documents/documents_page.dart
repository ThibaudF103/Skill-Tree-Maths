import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../ui/dialogs.dart';
import '../../ui/labels.dart';
import '../trees/node_picker.dart';
import 'document_actions.dart';

/// Vue « Bibliothèque » : tous les contenus (PDF, vidéos), filtrables par
/// arbre. On y gère les fichiers ; on travaille surtout depuis les arbres.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

/// Filtre : un arbre, ou les contenus rattachés à aucun nœud.
const _unlinked = '';

class _LibraryPageState extends State<LibraryPage> {
  Stream<List<SourceDocument>>? _documents;
  Stream<List<Anchor>>? _anchors;
  Stream<List<ResourceLink>>? _links;
  Stream<List<KnowledgeNode>>? _nodes;
  String? _filter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context).store;
    _documents ??= store.watchDocuments();
    _anchors ??= store.watchAnchors();
    _links ??= store.watchResourceLinks();
    _nodes ??= store.watchNodes();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<SourceDocument>>(
        stream: _documents,
        builder: (context, docs) => StreamBuilder<List<Anchor>>(
          stream: _anchors,
          builder: (context, anchors) => StreamBuilder<List<ResourceLink>>(
            stream: _links,
            builder: (context, links) => StreamBuilder<List<KnowledgeNode>>(
              stream: _nodes,
              builder: (context, nodes) {
                if (!docs.hasData || !links.hasData || !nodes.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _build(
                  context,
                  docs.data!,
                  anchors.data ?? const [],
                  links.data!,
                  nodes.data!,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _build(
    BuildContext context,
    List<SourceDocument> documents,
    List<Anchor> anchors,
    List<ResourceLink> links,
    List<KnowledgeNode> nodes,
  ) {
    final theme = Theme.of(context);
    final byId = {for (final n in nodes) n.id: n};
    String? rootOf(String id) {
      var node = byId[id];
      for (var i = 0; node?.parentId != null && i < nodes.length; i++) {
        node = byId[node!.parentId];
      }
      return node?.id;
    }

    final linksOf = <String, List<String>>{};
    for (final l in links) {
      if (byId.containsKey(l.nodeId)) {
        (linksOf[l.documentId] ??= []).add(l.nodeId);
      }
    }
    final treesOf = {
      for (final d in documents)
        d.id: {for (final n in linksOf[d.id] ?? const <String>[]) ?rootOf(n)},
    };
    final trees = [
      for (final n in nodes)
        if (n.isTree && treesOf.values.any((t) => t.contains(n.id))) n,
    ];
    final filter = _filter;
    final shown = [
      for (final d in documents)
        if (filter == null ||
            (filter == _unlinked
                ? treesOf[d.id]!.isEmpty
                : treesOf[d.id]!.contains(filter)))
          d,
    ];
    final counts = <String, ({int recto, int verso, int review})>{};
    // Couverture : pages d'où au moins un recto ou un verso a été tiré.
    final pages = <String, Set<int>>{};
    for (final a in anchors) {
      if (a.page != null) (pages[a.documentId] ??= {}).add(a.page!);
    }
    for (final a in anchors) {
      final c = counts[a.documentId] ?? (recto: 0, verso: 0, review: 0);
      counts[a.documentId] = (
        recto: c.recto + (a.role == AnchorRole.source ? 1 : 0),
        verso: c.verso + (a.role == AnchorRole.work ? 1 : 0),
        review: c.review + (a.needsReview ? 1 : 0),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Bibliothèque',
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => addYoutubeVideo(context),
                      icon: const Icon(Icons.smart_display_outlined),
                      label: const Text('Vidéo'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => importPdf(context),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Importer un PDF'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Les contenus (PDF, vidéos) se rattachent aux branches de '
                  'vos arbres. Encadrez un énoncé ou une rédaction pour en '
                  'faire le recto ou le verso d\'une connaissance.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 16),
                if (documents.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        label: const Text('Tout'),
                        selected: filter == null,
                        onSelected: (_) => setState(() => _filter = null),
                      ),
                      for (final tree in trees)
                        ChoiceChip(
                          label: Text(tree.title),
                          selected: filter == tree.id,
                          onSelected: (_) => setState(() => _filter = tree.id),
                        ),
                      if (treesOf.values.any((t) => t.isEmpty))
                        ChoiceChip(
                          label: const Text('Non rattachés'),
                          selected: filter == _unlinked,
                          onSelected: (_) =>
                              setState(() => _filter = _unlinked),
                        ),
                    ],
                  ),
                const Divider(height: 24),
                if (documents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Aucun contenu pour l\'instant : importez un PDF, ici '
                      'ou depuis une branche de l\'onglet Arbres.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                for (final d in shown)
                  _ResourceTile(
                    document: d,
                    counts: counts[d.id],
                    coveredPages: pages[d.id]?.length ?? 0,
                    paths: [
                      for (final n in linksOf[d.id] ?? const <String>[])
                        nodePath(byId, n),
                    ]..sort(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.document,
    required this.counts,
    required this.coveredPages,
    required this.paths,
  });

  final SourceDocument document;
  final ({int recto, int verso, int review})? counts;

  /// Pages d'où au moins un recto ou un verso a été tiré.
  final int coveredPages;

  /// Branches auxquelles le contenu est rattaché.
  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = counts;
    final parts = [
      if (document.isPdf)
        coveredPages > 0
            ? '$coveredPages / ${document.pageCount} pages travaillées'
            : '${document.pageCount} pages'
      else
        'Vidéo',
      if (document.version > 1) 'version ${document.version}',
      'ajouté le ${formatDate(document.importedAt)}',
      if (c != null && c.recto > 0) '${c.recto} recto',
      if (c != null && c.verso > 0) '${c.verso} verso',
    ];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(resourceIcon(document), color: theme.colorScheme.primary),
      title: Text(document.title),
      subtitle: Text(
        [
          parts.join(' · '),
          if (paths.isEmpty) 'Rattaché à aucune branche' else paths.join(' ; '),
          if (c != null && c.review > 0) '${c.review} lien(s) à vérifier',
        ].join('\n'),
      ),
      isThreeLine: true,
      onTap: () => openResource(context, document),
      trailing: PopupMenuButton<String>(
        tooltip: 'Actions',
        onSelected: (action) async {
          final store = AppScope.of(context).store;
          switch (action) {
            case 'link':
              await linkResourceToNode(context, document);
            case 'update':
              await updatePdf(context, document);
            case 'url':
              final url = await askName(
                context,
                title: 'Adresse de téléchargement',
                initial: document.url ?? '',
                hint: 'https://…/cours.pdf',
              );
              if (url != null) await store.setDocumentUrl(document.id, url);
            case 'rename':
              final name = await askName(
                context,
                title: 'Renommer',
                initial: document.title,
              );
              if (name != null) await store.renameDocument(document.id, name);
            case 'delete':
              final links = (c?.recto ?? 0) + (c?.verso ?? 0);
              final ok = await confirmDestructive(
                context,
                title: 'Supprimer « ${document.title} » ?',
                message: links == 0
                    ? 'Le contenu sera retiré de la bibliothèque.'
                    : 'Le contenu et ses $links lien(s) recto/verso seront '
                          'supprimés. Les connaissances restent.',
              );
              if (ok) await store.deleteDocument(document.id);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'link',
            child: ListTile(
              leading: Icon(Icons.account_tree_outlined),
              title: Text('Rattacher à une branche…'),
            ),
          ),
          if (document.isPdf)
            const PopupMenuItem(
              value: 'url',
              child: ListTile(
                leading: Icon(Icons.public),
                title: Text('Adresse de téléchargement…'),
                subtitle: Text('Pour partager un paquet sans le PDF'),
              ),
            ),
          if (document.isPdf)
            const PopupMenuItem(
              value: 'update',
              child: ListTile(
                leading: Icon(Icons.sync),
                title: Text('Mettre à jour (nouvelle version)'),
              ),
            ),
          const PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Renommer'),
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('Supprimer'),
            ),
          ),
        ],
      ),
    );
  }
}
