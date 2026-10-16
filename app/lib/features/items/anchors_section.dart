import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../pdf/pdf_region_view.dart';
import '../../ui/labels.dart';
import '../documents/document_viewer_page.dart';

/// Zone de PDF (recto ou verso), en vectoriel avec texte sélectionnable si
/// le PDF est sur l'appareil, sinon sa miniature.
class AnchorSnapshot extends StatelessWidget {
  const AnchorSnapshot({super.key, required this.anchor, this.maxHeight = 320});

  final Anchor anchor;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final color = anchor.role == AnchorRole.source ? rectoColor : versoColor;
    final snapshot = anchor.snapshot;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: anchor.page == null
          ? SizedBox(
              height: 60,
              child: Center(
                child: Text('Extrait vidéo · ${anchorPlace(anchor)}'),
              ),
            )
          : PdfRegionView(
              store: AppScope.of(context).store,
              documentId: anchor.documentId,
              page: anchor.page!,
              region: anchor.region ?? const NormalizedRect(0, 0, 1, 1),
              snapshot: snapshot,
            ),
    );
  }
}

/// Section « Recto / verso » de la fiche d'une connaissance.
class AnchorsSection extends StatefulWidget {
  const AnchorsSection({super.key, required this.item});

  final KnowledgeItem item;

  @override
  State<AnchorsSection> createState() => _AnchorsSectionState();
}

class _AnchorsSectionState extends State<AnchorsSection> {
  Stream<List<Anchor>>? _anchors;
  Stream<List<SourceDocument>>? _documents;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context).store;
    _anchors ??= store.watchAnchors(itemId: widget.item.id);
    _documents ??= store.watchDocuments();
  }

  Future<void> _attach(
    BuildContext context,
    List<SourceDocument> documents,
  ) async {
    final pdfs = [
      for (final d in documents)
        if (d.isPdf) d,
    ];
    if (pdfs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Importez d\'abord un PDF (Bibliothèque, ou Contenus d\'une '
            'branche).',
          ),
        ),
      );
      return;
    }
    final document = await showDialog<SourceDocument>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Depuis quel PDF ?'),
        children: [
          for (final d in pdfs)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, d),
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(d.title),
                subtitle: Text('${d.pageCount} pages'),
              ),
            ),
        ],
      ),
    );
    if (document == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentViewerPage(
          documentId: document.id,
          // Nouvelles pages s'il y en a, sinon la dernière page lue ; on
          // navigue d'abord, puis on encadre.
          initialPage: document.newPages.isNotEmpty
              ? document.newPages.first
              : null,
          attachToItem: widget.item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<SourceDocument>>(
      stream: _documents,
      builder: (context, docs) => StreamBuilder<List<Anchor>>(
        stream: _anchors,
        builder: (context, snapshot) {
          final anchors = snapshot.data ?? const <Anchor>[];
          final documents = {
            for (final d in docs.data ?? const <SourceDocument>[]) d.id: d,
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (anchors.isEmpty)
                Text(
                  'Aucun lien : encadrez l\'énoncé dans un cours (recto) ou '
                  'votre rédaction dans vos notes (verso).',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              for (final anchor in anchors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _AnchorCard(
                    anchor: anchor,
                    document: documents[anchor.documentId],
                  ),
                ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => _attach(context, documents.values.toList()),
                icon: const Icon(Icons.crop_free),
                label: const Text('Attacher une zone d\'un PDF'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnchorCard extends StatelessWidget {
  const _AnchorCard({required this.anchor, required this.document});

  final Anchor anchor;
  final SourceDocument? document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRecto = anchor.role == AnchorRole.source;
    final color = isRecto ? rectoColor : versoColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isRecto ? 'Recto' : 'Verso',
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${document?.title ?? 'Contenu supprimé'} · '
                '${anchorPlace(anchor)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            if (anchor.needsReview)
              const Tooltip(
                message:
                    'La page n\'a pas été retrouvée dans la nouvelle version du '
                    'PDF. La miniature reste valable.',
                child: Chip(
                  avatar: Icon(Icons.warning_amber, size: 16),
                  label: Text('Page à vérifier'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (document != null && document!.isPdf)
              IconButton(
                tooltip: 'Ouvrir dans le PDF',
                icon: const Icon(Icons.open_in_new),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DocumentViewerPage(
                      documentId: anchor.documentId,
                      initialPage: anchor.page,
                      highlight: anchor.region,
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Retirer ce lien',
              icon: const Icon(Icons.link_off),
              onPressed: () =>
                  AppScope.of(context).store.deleteAnchor(anchor.id),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AnchorSnapshot(anchor: anchor),
      ],
    );
  }
}
