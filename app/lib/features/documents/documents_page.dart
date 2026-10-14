import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../ui/dialogs.dart';
import '../../ui/labels.dart';
import 'document_actions.dart';
import 'document_viewer_page.dart';

/// Vue « Documents » : PDF de cours et notes manuscrites exportées.
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  Stream<List<SourceDocument>>? _documents;
  Stream<List<Anchor>>? _anchors;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context).store;
    _documents ??= store.watchDocuments();
    _anchors ??= store.watchAnchors();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: StreamBuilder<List<SourceDocument>>(
        stream: _documents,
        builder: (context, docs) => StreamBuilder<List<Anchor>>(
          stream: _anchors,
          builder: (context, anchors) {
            final documents = docs.data;
            if (documents == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final counts = <String, ({int recto, int verso, int review})>{};
            for (final a in anchors.data ?? const <Anchor>[]) {
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
                                'Documents',
                                style: theme.textTheme.headlineMedium,
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => importPdf(context),
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Importer un PDF'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Encadrez un énoncé dans un cours (recto) ou votre '
                          'rédaction dans vos notes (verso) : en révision, '
                          'le verso apparaît quand vous révélez.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 24),
                        for (final role in DocumentRole.values) ...[
                          Text(role.label, style: theme.textTheme.titleMedium),
                          const Divider(),
                          if (!documents.any((d) => d.role == role))
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                role.hint,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ),
                          for (final d in documents.where(
                            (d) => d.role == role,
                          ))
                            _DocumentTile(document: d, counts: counts[d.id]),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
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

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document, required this.counts});

  final SourceDocument document;
  final ({int recto, int verso, int review})? counts;

  @override
  Widget build(BuildContext context) {
    final c = counts;
    final parts = [
      '${document.pageCount} pages',
      if (document.version > 1) 'version ${document.version}',
      'importé le ${formatDate(document.importedAt)}',
      if (c != null && c.recto > 0) '${c.recto} recto',
      if (c != null && c.verso > 0) '${c.verso} verso',
    ];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(
        document.role == DocumentRole.course
            ? Icons.menu_book_outlined
            : Icons.draw_outlined,
        color: document.role == DocumentRole.course ? rectoColor : versoColor,
      ),
      title: Text(document.title),
      subtitle: Text(
        [
          parts.join(' · '),
          if (c != null && c.review > 0) '${c.review} lien(s) à vérifier',
        ].join('\n'),
      ),
      isThreeLine: c != null && c.review > 0,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DocumentViewerPage(documentId: document.id),
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Actions',
        onSelected: (action) async {
          final store = AppScope.of(context).store;
          switch (action) {
            case 'update':
              await updatePdf(context, document);
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
                    ? 'Le PDF sera retiré de la bibliothèque.'
                    : 'Le PDF et ses $links lien(s) recto/verso seront '
                          'supprimés. Les connaissances restent.',
              );
              if (ok) await store.deleteDocument(document.id);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'update',
            child: ListTile(
              leading: Icon(Icons.sync),
              title: Text('Mettre à jour (nouvelle version)'),
            ),
          ),
          PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Renommer'),
            ),
          ),
          PopupMenuItem(
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
