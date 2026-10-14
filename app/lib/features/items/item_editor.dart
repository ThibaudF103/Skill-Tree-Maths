import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../ui/item_glyph.dart';
import '../../ui/labels.dart';

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

/// Crée une connaissance dans [nodeId] ([item] nul) ou modifie [item].
Future<void> showItemEditor(
  BuildContext context, {
  required String nodeId,
  KnowledgeItem? item,
  ItemFamily? family,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ItemEditor(nodeId: nodeId, item: item, family: family),
  );
}

class ItemEditor extends StatefulWidget {
  const ItemEditor({super.key, required this.nodeId, this.item, this.family});

  final String nodeId;
  final KnowledgeItem? item;
  final ItemFamily? family;

  @override
  State<ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<ItemEditor> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late ItemKind _kind;
  var _level = _InitialLevel.none;
  var _saving = false;

  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item?.title ?? '');
    _body = TextEditingController(text: item?.body ?? '');
    _kind =
        item?.kind ??
        switch (widget.family) {
          ItemFamily.statement => ItemKind.theorem,
          ItemFamily.exercise => ItemKind.exercise,
          _ => ItemKind.definition,
        };
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    final scope = AppScope.of(context);
    final item = widget.item;
    if (item != null) {
      await scope.store.updateItem(
        item.id,
        title: title,
        body: () => _body.text,
        kind: _kind,
      );
    } else {
      final created = await scope.store.createItem(
        nodeId: widget.nodeId,
        kind: _kind,
        title: title,
        body: _body.text,
      );
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
    if (mounted) Navigator.pop(context);
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
                  hintText: 'Énoncé, hypothèses, remarques…',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
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
            onPressed: _title.text.trim().isEmpty || _saving ? null : _save,
            child: Text(_editing ? 'Enregistrer' : 'Ajouter'),
          ),
        ),
      ],
    );
  }
}
