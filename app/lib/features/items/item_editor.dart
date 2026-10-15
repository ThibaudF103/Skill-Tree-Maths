import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../ui/item_glyph.dart';
import '../../ui/labels.dart';
import '../../ui/math_text.dart';
import '../trees/node_picker.dart';

/// Évaluation facultative à la création : compte comme première révision.
enum _InitialLevel {
  none('Jamais vue', null),
  fragile('Fragile', Rating.hard),
  known('Connue', Rating.good),
  mastered('Maîtrisée', Rating.easy);

  const _InitialLevel(this.label, this.rating);
  final String label;
  final Rating? rating;
}

const _statementKinds = [
  ItemKind.theorem,
  ItemKind.proposition,
  ItemKind.lemma,
  ItemKind.property,
  ItemKind.corollary,
];

/// Crée une connaissance ([item] nul) ou modifie [item].
///
/// La branche de création est [nodeId], ou à défaut la dernière utilisée ;
/// elle reste modifiable dans le formulaire. Renvoie la connaissance créée
/// (ou `null` en modification / annulation).
Future<KnowledgeItem?> showItemEditor(
  BuildContext context, {
  String? nodeId,
  KnowledgeItem? item,
  ItemFamily? family,
  String? initialTitle,
  String? initialBody,
}) {
  return showDialog<KnowledgeItem>(
    context: context,
    builder: (_) => ItemEditor(
      nodeId: nodeId,
      item: item,
      family: family,
      initialTitle: initialTitle,
      initialBody: initialBody,
    ),
  );
}

class ItemEditor extends StatefulWidget {
  const ItemEditor({
    super.key,
    this.nodeId,
    this.item,
    this.family,
    this.initialTitle,
    this.initialBody,
  });

  final String? nodeId;
  final KnowledgeItem? item;
  final ItemFamily? family;
  final String? initialTitle;
  final String? initialBody;

  @override
  State<ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<ItemEditor> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late ItemKind _kind;
  var _level = _InitialLevel.none;
  var _saving = false;
  KnowledgeNode? _node;
  var _nodePath = '';
  var _nodeLoaded = false;
  var _nodeResolved = false;

  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(
      text: item?.title ?? widget.initialTitle ?? '',
    );
    _body = TextEditingController(text: item?.body ?? widget.initialBody ?? '');
    _kind =
        item?.kind ??
        switch (widget.family) {
          ItemFamily.statement => ItemKind.theorem,
          ItemFamily.exercise => ItemKind.exercise,
          _ => ItemKind.definition,
        };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_nodeLoaded) {
      _nodeLoaded = true;
      _loadNode();
    }
  }

  Future<void> _loadNode() async {
    final store = AppScope.of(context).store;
    final id = widget.item?.nodeId ?? widget.nodeId;
    final node = id != null ? await store.node(id) : await store.lastNode();
    await _setNode(node);
  }

  Future<void> _setNode(KnowledgeNode? node) async {
    final store = AppScope.of(context).store;
    final byId = {for (final n in await store.allNodes()) n.id: n};
    if (!mounted) return;
    setState(() {
      _node = node;
      _nodeResolved = true;
      _nodePath = node == null ? '' : nodePath(byId, node.id);
    });
  }

  Future<void> _changeNode() async {
    final node = await pickNode(
      context,
      title: 'Dans quelle branche ?',
      initialId: _node?.id,
    );
    if (node != null && mounted) await _setNode(node);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final node = _node;
    if (title.isEmpty || node == null || _saving) return;
    setState(() => _saving = true);
    final scope = AppScope.of(context);
    final item = widget.item;
    KnowledgeItem? created;
    if (item != null) {
      await scope.store.updateItem(
        item.id,
        title: title,
        body: () => _body.text,
        kind: _kind,
        nodeId: node.id != item.nodeId ? node.id : null,
      );
    } else {
      created = await scope.store.createItem(
        nodeId: node.id,
        kind: _kind,
        title: title,
        body: _body.text,
      );
      await scope.store.setLastNode(node.id);
      final rating = _level.rating;
      if (rating != null) {
        await scope.store.applyReview(
          created.id,
          scope.scheduler.record(
            created.scheduling,
            rating,
            DateTime.now(),
            fuzzKey: created.id,
          ),
        );
      }
    }
    if (mounted) Navigator.pop(context, created);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final family = _kind.family;
    return AlertDialog(
      title: Text(
        _editing ? 'Modifier la connaissance' : 'Nouvelle connaissance',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _branchRow(theme),
              const SizedBox(height: 12),
              SegmentedButton<ItemFamily>(
                segments: [
                  for (final f in ItemFamily.values)
                    ButtonSegment(
                      value: f,
                      label: Text(f.label),
                      icon: ItemGlyph(
                        family: f,
                        stage: GrowthStage.mature,
                        size: 20,
                      ),
                    ),
                ],
                selected: {family},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => setState(() {
                  _kind = switch (selection.first) {
                    ItemFamily.definition => ItemKind.definition,
                    ItemFamily.statement => ItemKind.theorem,
                    ItemFamily.exercise => ItemKind.exercise,
                  };
                }),
              ),
              if (family == ItemFamily.statement) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final kind in _statementKinds)
                      ChoiceChip(
                        label: Text(kind.label),
                        selected: _kind == kind,
                        onSelected: (_) => setState(() => _kind = kind),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                autofocus: !_editing,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  hintText: 'Théorème de Cayley-Hamilton',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Contenu (facultatif)',
                  hintText:
                      r'Énoncé, remarques… Formules : $x^2$ ou $$\int_0^1 f$$',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              // Aperçu des formules pendant la saisie.
              ListenableBuilder(
                listenable: _body,
                builder: (context, _) => _body.text.contains(r'$')
                    ? Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: MathText(_body.text),
                      )
                    : const SizedBox.shrink(),
              ),
              if (!_editing) ...[
                const SizedBox(height: 16),
                Text('Je la connais déjà ?', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<_InitialLevel>(
                  segments: [
                    for (final level in _InitialLevel.values)
                      ButtonSegment(value: level, label: Text(level.label)),
                  ],
                  selected: {_level},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _level = s.first),
                ),
                const SizedBox(height: 4),
                Text(
                  _level == _InitialLevel.none
                      ? 'Elle apparaîtra comme un bourgeon, à réviser.'
                      : 'Compte comme une première révision « ${_level.rating!.label} ».',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ListenableBuilder(
          listenable: _title,
          builder: (context, _) => FilledButton(
            onPressed: _title.text.trim().isEmpty || _node == null || _saving
                ? null
                : _save,
            child: Text(_editing ? 'Enregistrer' : 'Ajouter'),
          ),
        ),
      ],
    );
  }

  Widget _branchRow(ThemeData theme) {
    final node = _node;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _changeNode,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          child: Row(
            children: [
              Icon(
                Icons.account_tree_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Branche', style: theme.textTheme.labelSmall),
                    Text(
                      node == null
                          ? (_nodeResolved ? 'Aucune branche choisie' : '…')
                          : _nodePath,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: node == null
                          ? TextStyle(color: theme.colorScheme.error)
                          : null,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _changeNode,
                child: Text(node == null ? 'Choisir' : 'Changer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
