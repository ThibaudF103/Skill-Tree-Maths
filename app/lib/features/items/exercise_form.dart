import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

/// Formulaire d'un modèle d'exercice corrigé automatiquement : paramètres,
/// valeurs calculées, conditions, énoncé, questions. Chaque saisie modifie
/// [draft] puis appelle [onChanged].
class ExerciseForm extends StatefulWidget {
  const ExerciseForm({super.key, required this.draft, required this.onChanged});

  final ExerciseDraft draft;
  final VoidCallback onChanged;

  @override
  State<ExerciseForm> createState() => _ExerciseFormState();
}

class _ExerciseFormState extends State<ExerciseForm> {
  ExerciseDraft get _d => widget.draft;

  /// Changement de structure (ligne ajoutée, ôtée, type changé).
  void _edit(VoidCallback change) {
    setState(change);
    widget.onChanged();
  }

  /// Champ de texte d'une ligne ; la clé [label] le distingue des autres
  /// champs de la même ligne quand le type de la ligne change.
  Widget _field(
    String label,
    String value,
    ValueChanged<String> set, {
    double? width,
    String? hint,
    int maxLines = 1,
  }) {
    final field = TextFormField(
      key: ValueKey(label),
      initialValue: value,
      minLines: 1,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        set(v);
        widget.onChanged();
      },
    );
    return width == null ? field : SizedBox(width: width, child: field);
  }

  Widget _remove(String tooltip, VoidCallback onPressed) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    icon: const Icon(Icons.close),
    onPressed: () => _edit(onPressed),
  );

  Widget _section(
    String title,
    String help,
    String addLabel,
    VoidCallback add,
    List<Widget> rows,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          Text(
            help,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final row in rows)
            Padding(
              key: row.key,
              padding: const EdgeInsets.only(top: 8),
              child: row,
            ),
          TextButton.icon(
            onPressed: () => _edit(add),
            icon: const Icon(Icons.add),
            label: Text(addLabel),
          ),
        ],
      ),
    );
  }

  Widget _row(Object key, List<Widget> children) => KeyedSubtree(
    key: ObjectKey(key),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(
          'Paramètres',
          'Valeurs tirées au hasard à chaque énoncé.',
          'Ajouter un paramètre',
          () => _d.params.add(DraftParam()),
          [for (final p in _d.params) _param(p)],
        ),
        _section(
          'Valeurs calculées',
          'À partir des paramètres et des valeurs précédentes : (c - b) / a.',
          'Ajouter une valeur',
          () => _d.lets.add(DraftLet()),
          [
            for (final l in _d.lets)
              _row(l, [
                _field('Nom', l.name, (v) => l.name = v, width: 80),
                _field(
                  'Expression',
                  l.expression,
                  (v) => l.expression = v,
                  width: 240,
                ),
                _remove('Retirer la valeur', () => _d.lets.remove(l)),
              ]),
          ],
        ),
        _section(
          'Conditions',
          'Un tirage qui ne les remplit pas est refait : x != 0, a < b.',
          'Ajouter une condition',
          () => _d.conditions.add(DraftCondition()),
          [
            for (final c in _d.conditions)
              _row(c, [
                _field(
                  'Condition',
                  c.expression,
                  (v) => c.expression = v,
                  width: 240,
                ),
                _remove('Retirer la condition', () => _d.conditions.remove(c)),
              ]),
          ],
        ),
        const SizedBox(height: 12),
        _field(
          'Énoncé',
          _d.statement,
          (v) => _d.statement = v,
          hint: r'Résoudre $[[a]]x [[b|+]] = [[c]]$.',
          maxLines: 6,
        ),
        Text(
          'Une valeur s\'écrit [[a]] ; [[b|+]] écrit toujours son signe, '
          '[[x|tex]] une fraction en LaTeX, [[v|2]] arrondit à 2 décimales.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        _section(
          'Questions',
          'Réponse numérique (expression) ou QCM.',
          'Ajouter une question',
          () => _d.questions.add(DraftQuestion()),
          [
            for (final (i, q) in _d.questions.indexed)
              KeyedSubtree(key: ObjectKey(q), child: _question(i, q)),
          ],
        ),
      ],
    );
  }

  Widget _param(DraftParam p) => _row(p, [
    _field('Nom', p.name, (v) => p.name = v, width: 80),
    DropdownButton<bool>(
      value: p.isList,
      items: const [
        DropdownMenuItem(value: false, child: Text('Entier')),
        DropdownMenuItem(value: true, child: Text('Liste')),
      ],
      onChanged: (v) => _edit(() => p.isList = v ?? false),
    ),
    if (p.isList)
      _field(
        'Valeurs',
        p.values,
        (v) => p.values = v,
        width: 200,
        hint: '2 ; 3 ; 0,5',
      )
    else ...[
      _field('Min', p.min, (v) => p.min = v, width: 70),
      _field('Max', p.max, (v) => p.max = v, width: 70),
      _field(
        'Sauf',
        p.excluded,
        (v) => p.excluded = v,
        width: 100,
        hint: '0 ; 1',
      ),
    ],
    _remove('Retirer le paramètre', () => _d.params.remove(p)),
  ]);

  Widget _question(int index, DraftQuestion q) {
    final theme = Theme.of(context);
    final written = q.correct.trim().isEmpty
        ? 1
        : int.tryParse(q.correct.trim());
    // Rang hors des choix : montré comme une expression, pour être vu.
    final rank = written != null && written >= 1 && written <= q.choices.length
        ? written
        : null;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Question ${index + 1}', style: theme.textTheme.labelLarge),
              const SizedBox(width: 12),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: false, label: Text('Nombre')),
                  ButtonSegment(value: true, label: Text('QCM')),
                ],
                selected: {q.isChoice},
                onSelectionChanged: (s) => _edit(() => q.isChoice = s.first),
              ),
              const Spacer(),
              if (_d.questions.length > 1)
                _remove('Retirer la question', () => _d.questions.remove(q)),
            ],
          ),
          const SizedBox(height: 8),
          _field(
            'Consigne (facultative)',
            q.prompt,
            (v) => q.prompt = v,
            hint: r'$x =$',
          ),
          const SizedBox(height: 8),
          if (!q.isChoice)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _field(
                  'Réponse (expression)',
                  q.answer,
                  (v) => q.answer = v,
                  width: 200,
                ),
                _field(
                  'Tolérance',
                  q.tolerance,
                  (v) => q.tolerance = v,
                  width: 110,
                  hint: 'exacte',
                ),
              ],
            )
          else
            RadioGroup<int>(
              groupValue: rank,
              onChanged: (v) => _edit(() => q.correct = '${v ?? 1}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (j, c) in q.choices.indexed)
                    KeyedSubtree(
                      key: ObjectKey(c),
                      child: Row(
                        children: [
                          Radio<int>(value: j + 1),
                          Expanded(
                            child: _field(
                              'Choix ${j + 1}',
                              c.text,
                              (v) => c.text = v,
                            ),
                          ),
                          if (q.choices.length > 2)
                            _remove(
                              'Retirer le choix',
                              () => _removeChoice(q, j),
                            ),
                        ],
                      ),
                    ),
                  if (rank == null)
                    Text(
                      written == null
                          ? 'Bonne réponse calculée : ${q.correct} '
                                '(cocher un choix la remplace)'
                          : written == 0
                          ? 'Cocher la bonne réponse'
                          : 'Bonne réponse : choix $written, qui n\'existe '
                                'pas (cocher un choix)',
                      style: TextStyle(
                        fontSize: theme.textTheme.bodySmall?.fontSize,
                        color: written == null ? null : theme.colorScheme.error,
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => _edit(() => q.choices.add(DraftChoice())),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un choix'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Retire le choix [j] ; la bonne réponse, si c'est un rang, suit.
  void _removeChoice(DraftQuestion q, int j) {
    q.choices.removeAt(j);
    final rank = q.correct.trim().isEmpty ? 1 : int.tryParse(q.correct.trim());
    if (rank == null) return;
    if (rank == j + 1) {
      // Bonne réponse retirée : à cocher de nouveau (le rang 0 bloque
      // l'enregistrement, le premier choix ne la remplace pas en silence).
      q.correct = '0';
    } else if (rank > j + 1) {
      q.correct = '${rank - 1}';
    }
  }
}
