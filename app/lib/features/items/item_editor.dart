import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../ui/item_glyph.dart';
import '../../ui/labels.dart';
import '../../ui/latex_input.dart';
import '../../ui/math_text.dart';
import '../trees/node_picker.dart';
import 'exercise_form.dart';

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

/// Précisions facultatives d'un énoncé (aucune : « Énoncé »).
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

  /// Modèle d'exercice corrigé automatiquement (JSON), facultatif.
  late final TextEditingController _auto;
  late ItemKind _kind;
  var _initial = _InitialLevel.none;
  ExerciseLevel? _exerciseLevel;
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
    _auto = TextEditingController(text: item?.autoExercise ?? '');
    _kind =
        item?.kind ??
        switch (widget.family) {
          ItemFamily.statement => ItemKind.statement,
          ItemFamily.exercise => ItemKind.exercise,
          _ => ItemKind.definition,
        };
    _exerciseLevel = item?.level;
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
    _auto.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final node = _node;
    if (title.isEmpty || node == null || _saving || _autoProblem != null) {
      return;
    }
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
        level: () => _exerciseLevel,
        autoExercise: () => _auto.text,
        nodeId: node.id != item.nodeId ? node.id : null,
      );
    } else {
      created = await scope.store.createItem(
        nodeId: node.id,
        kind: _kind,
        title: title,
        body: _body.text,
        level: _exerciseLevel,
        autoExercise: _auto.text,
      );
      await scope.store.setLastNode(node.id);
      final rating = _initial.rating;
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
                    ItemFamily.statement => ItemKind.statement,
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
                        // Un second appui retire la précision.
                        onSelected: (selected) => setState(
                          () => _kind = selected ? kind : ItemKind.statement,
                        ),
                      ),
                  ],
                ),
                _hint(theme, 'Précision facultative'),
              ],
              if (family == ItemFamily.exercise) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final level in ExerciseLevel.values)
                      ChoiceChip(
                        label: Text(level.label),
                        selected: _exerciseLevel == level,
                        onSelected: (selected) => setState(
                          () => _exerciseLevel = selected ? level : null,
                        ),
                      ),
                  ],
                ),
                _hint(theme, 'Difficulté facultative'),
                const SizedBox(height: 8),
                _AutoExerciseField(controller: _auto),
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
                inputFormatters: const [LatexAutoCloseFormatter()],
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
                  selected: {_initial},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _initial = s.first),
                ),
                const SizedBox(height: 4),
                Text(
                  _initial == _InitialLevel.none
                      ? 'Elle apparaîtra comme un bourgeon, à réviser.'
                      : 'Compte comme une première révision « ${_initial.rating!.label} ».',
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
          listenable: Listenable.merge([_title, _auto]),
          builder: (context, _) => FilledButton(
            onPressed:
                _title.text.trim().isEmpty ||
                    _node == null ||
                    _saving ||
                    _autoProblem != null
                ? null
                : _save,
            child: Text(_editing ? 'Enregistrer' : 'Ajouter'),
          ),
        ),
      ],
    );
  }

  /// Modèle d'exercice invalide (un exercice seulement) : on ne peut pas
  /// enregistrer.
  String? get _autoProblem => _kind.family == ItemFamily.exercise
      ? autoExerciseProblem(_auto.text)
      : null;

  Widget _hint(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.outline,
      ),
    ),
  );

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

/// Problème d'un modèle d'exercice (lecture ou calcul), `null` s'il est
/// vide ou valide.
String? autoExerciseProblem(String source) {
  if (source.trim().isEmpty) return null;
  try {
    return ExerciseTemplate.parse(source).check();
  } on FormatException catch (e) {
    return e.message;
  } catch (e) {
    return 'Modèle incalculable ($e)';
  }
}

/// Exemple de modèle, proposé à l'écriture d'un premier exercice.
const _autoExample = r"""{
  "v": 1,
  "params": {
    "a": {"int": [2, 9]},
    "b": {"int": [-9, 9], "not": [0]},
    "c": {"int": [-9, 9]}
  },
  "let": {"x": "(c - b) / a"},
  "statement": "Résoudre l'équation $[[a]]x [[b|+]] = [[c]]$.",
  "questions": [
    {"prompt": "$x =$", "answer": "x"},
    {"prompt": "Signe de la solution :",
     "choices": ["positive", "négative", "nulle"],
     "correct": "si(x > 0, 1, si(x < 0, 2, 3))"}
  ]
}""";

/// Modèle d'exercice corrigé automatiquement : saisie JSON, contrôle et
/// aperçu d'un tirage.
class _AutoExerciseField extends StatefulWidget {
  const _AutoExerciseField({required this.controller});

  final TextEditingController controller;

  @override
  State<_AutoExerciseField> createState() => _AutoExerciseFieldState();
}

class _AutoExerciseFieldState extends State<_AutoExerciseField> {
  var _seed = 0;

  /// Brouillon montré par le formulaire ; `null` : saisie en JSON.
  ExerciseDraft? _draft;

  /// Le modèle ne se montre pas dans le formulaire.
  var _jsonOnly = false;

  @override
  void initState() {
    super.initState();
    _showForm();
  }

  void _showForm() {
    final text = widget.controller.text;
    _draft = text.trim().isEmpty
        ? ExerciseDraft()
        : ExerciseDraft.tryParse(text);
    _jsonOnly = _draft == null;
  }

  void _useExample() {
    widget.controller.text = _autoExample;
    if (_draft != null) setState(_showForm);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.controller;
    final draft = _draft;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      initiallyExpanded: c.text.trim().isNotEmpty,
      title: const Text('Corrigé automatiquement (facultatif)'),
      subtitle: const Text('Énoncé tiré au hasard, réponses vérifiées'),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: true, label: Text('Formulaire')),
              ButtonSegment(value: false, label: Text('JSON')),
            ],
            selected: {draft != null},
            onSelectionChanged: (s) => setState(() {
              if (s.first) {
                _showForm();
              } else {
                _draft = null;
                _jsonOnly = false;
              }
            }),
          ),
        ),
        const SizedBox(height: 8),
        if (draft != null)
          ExerciseForm(
            key: ObjectKey(draft),
            draft: draft,
            onChanged: () => c.text = draft.encode(),
          )
        else ...[
          if (_jsonOnly)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Ce modèle ne se lit pas dans le formulaire : '
                'il s\'édite en JSON.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          TextField(
            controller: c,
            minLines: 6,
            maxLines: 16,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Modèle (JSON)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            if (c.text.trim().isEmpty) {
              return Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _useExample,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Partir d\'un exemple'),
                ),
              );
            }
            final duplicate = draft?.duplicateName;
            final problem = duplicate != null
                ? '« $duplicate » est défini deux fois'
                : autoExerciseProblem(c.text);
            if (problem != null) {
              return Text(
                problem,
                style: TextStyle(color: theme.colorScheme.error),
              );
            }
            final ExerciseInstance instance;
            try {
              instance = ExerciseTemplate.parse(c.text).generate(_seed);
            } catch (e) {
              return Text(
                'Tirage $_seed : ${e is EvalError ? e.message : e}',
                style: TextStyle(color: theme.colorScheme.error),
              );
            }
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Aperçu d\'un tirage',
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _seed++),
                        child: const Text('Autre tirage'),
                      ),
                    ],
                  ),
                  if (instance.statement.trim().isNotEmpty)
                    MathText(instance.statement),
                  for (final q in instance.questions)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: MathText(switch (q) {
                        NumberQuestion() => '${q.prompt} → ${q.expectedText}',
                        ChoiceQuestion() =>
                          '${q.prompt} → ${q.choices[q.correct]} '
                              '(parmi ${q.choices.join(', ')})',
                      }),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
