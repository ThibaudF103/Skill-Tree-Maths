import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../video/youtube.dart';
import '../trees/node_picker.dart';
import 'document_actions.dart';

/// Contenu à importer, tel que rempli dans [ContentImportDialog].
typedef ContentImport = ({
  ResourceKind kind,
  String title,

  /// Branche à laquelle rattacher le contenu (`null` : bibliothèque seule).
  String? nodeId,

  /// Fichier choisi (PDF).
  Uint8List? bytes,

  /// Identifiant YouTube (vidéo).
  String? videoId,
});

/// Point d'entrée unique pour ajouter un contenu (PDF, vidéo YouTube) à la
/// bibliothèque, rattaché au besoin à une branche ([nodeId] présélectionnée).
Future<SourceDocument?> importContent(
  BuildContext context, {
  String? nodeId,
}) async {
  final choice = await showDialog<ContentImport>(
    context: context,
    builder: (_) => ContentImportDialog(initialNodeId: nodeId),
  );
  if (choice == null || !context.mounted) return null;
  return switch (choice.kind) {
    ResourceKind.pdf => savePdf(
      context,
      bytes: choice.bytes!,
      title: choice.title,
      nodeId: choice.nodeId,
    ),
    ResourceKind.video => saveYoutubeVideo(
      context,
      videoId: choice.videoId!,
      title: choice.title,
      nodeId: choice.nodeId,
    ),
  };
}

/// Formulaire « Importer un contenu » : nature, ce qu'elle demande (fichier
/// ou adresse), titre et branche de rattachement.
class ContentImportDialog extends StatefulWidget {
  const ContentImportDialog({
    super.key,
    this.initialNodeId,
    this.pickPdf = pickPdfFile,
  });

  final String? initialNodeId;

  /// Choix du fichier PDF (remplaçable dans les tests).
  final Future<(String, Uint8List)?> Function() pickPdf;

  @override
  State<ContentImportDialog> createState() => _ContentImportDialogState();
}

class _ContentImportDialogState extends State<ContentImportDialog> {
  var _kind = ResourceKind.pdf;
  final _title = TextEditingController();
  final _url = TextEditingController();
  late String? _nodeId = widget.initialNodeId;
  String? _nodePath;

  /// PDF choisi : nom du fichier (sans extension) et contenu.
  (String, Uint8List)? _pdf;
  String? _videoId;
  var _fetching = false;

  /// Titre proposé automatiquement (nom du fichier, titre de la vidéo) :
  /// remplacé si l'on change de fichier tant qu'il n'a pas été retouché.
  String? _suggested;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nodeId != null && _nodePath == null) _loadPath();
  }

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _loadPath() async {
    final id = _nodeId;
    if (id == null) return;
    final nodes = await AppScope.of(context).store.allNodes();
    if (!mounted) return;
    setState(() => _nodePath = nodePath({for (final n in nodes) n.id: n}, id));
  }

  Future<void> _chooseNode() async {
    final node = await pickNode(
      context,
      title: 'Rattacher à…',
      initialId: _nodeId,
    );
    if (node == null || !mounted) return;
    _nodeId = node.id;
    await _loadPath();
  }

  void _suggest(String title) {
    if (_title.text.trim().isEmpty || _title.text == _suggested) {
      _title.text = title;
    }
    _suggested = title;
  }

  Future<void> _choosePdf() async {
    final picked = await widget.pickPdf();
    if (picked == null || !mounted) return;
    setState(() {
      _pdf = picked;
      _suggest(picked.$1);
    });
  }

  Future<void> _onUrl(String text) async {
    final id = youtubeId(text);
    setState(() => _videoId = id);
    if (id == null || _title.text.trim().isNotEmpty) return;
    setState(() => _fetching = true);
    final title = await youtubeTitle(id);
    if (!mounted || _videoId != id) return;
    setState(() {
      _fetching = false;
      if (title != null) _suggest(title);
    });
  }

  bool get _ready => switch (_kind) {
    ResourceKind.pdf => _pdf != null && _title.text.trim().isNotEmpty,
    ResourceKind.video => _videoId != null,
  };

  void _submit() {
    if (!_ready) return;
    final title = _title.text.trim();
    Navigator.pop<ContentImport>(context, (
      kind: _kind,
      title: title.isEmpty ? 'Vidéo $_videoId' : title,
      nodeId: _nodeId,
      bytes: _kind == ResourceKind.pdf ? _pdf!.$2 : null,
      videoId: _kind == ResourceKind.video ? _videoId : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Importer un contenu'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<ResourceKind>(
                segments: [
                  for (final kind in ResourceKind.values)
                    switch (kind) {
                      ResourceKind.pdf => const ButtonSegment(
                        value: ResourceKind.pdf,
                        icon: Icon(Icons.picture_as_pdf_outlined),
                        label: Text('Fichier PDF'),
                      ),
                      ResourceKind.video => const ButtonSegment(
                        value: ResourceKind.video,
                        icon: Icon(Icons.smart_display_outlined),
                        label: Text('Vidéo YouTube'),
                      ),
                    },
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.single),
              ),
              const SizedBox(height: 16),
              ...switch (_kind) {
                ResourceKind.pdf => [
                  OutlinedButton.icon(
                    onPressed: _choosePdf,
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      _pdf == null
                          ? 'Choisir un fichier PDF…'
                          : '${_pdf!.$1}.pdf (changer)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                ResourceKind.video => [
                  TextField(
                    controller: _url,
                    decoration: InputDecoration(
                      labelText: 'Adresse de la vidéo',
                      hintText: 'https://www.youtube.com/watch?v=…',
                      border: const OutlineInputBorder(),
                      errorText: _url.text.isNotEmpty && _videoId == null
                          ? 'Adresse YouTube non reconnue'
                          : null,
                    ),
                    onChanged: _onUrl,
                  ),
                ],
              },
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Titre',
                  border: const OutlineInputBorder(),
                  suffixIcon: _fetching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_tree_outlined),
                title: const Text('Rattaché à'),
                subtitle: Text(
                  _nodeId == null
                      ? 'Aucune branche (bibliothèque seulement)'
                      : _nodePath ?? '…',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_nodeId != null)
                      IconButton(
                        tooltip: 'Ne pas rattacher',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _nodeId = null;
                          _nodePath = null;
                        }),
                      ),
                    TextButton(
                      onPressed: _chooseNode,
                      child: Text(_nodeId == null ? 'Choisir' : 'Changer'),
                    ),
                  ],
                ),
              ),
              Text(
                'Un même contenu peut servir à plusieurs branches.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _ready ? _submit : null,
          child: const Text('Importer'),
        ),
      ],
    );
  }
}
