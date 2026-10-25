import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import '../../app/app_scope.dart';
import '../../ui/item_glyph.dart';
import '../../ui/labels.dart';
import '../../ui/math_text.dart';
import '../items/anchors_section.dart';
import '../notes/ink_editor.dart';
import '../notes/note_page.dart';
import '../notes/note_split.dart';
import '../notes/notes_panel.dart';

/// Session de révision façon cartes : on lit le titre, on tente de se
/// souvenir, on révèle le contenu, puis on s'évalue. Un exercice corrigé
/// automatiquement tire un énoncé, corrige les réponses et propose la note.
///
/// Prise de notes (bouton de la barre) : on rédige sa tentative sous la
/// carte, au clavier ou au stylet, on la compare au verso une fois révélé ;
/// à la notation, elle est enregistrée avec la connaissance (tentative de
/// révision, avec la note donnée).
///
/// Raccourcis clavier (hors saisie de texte) : Espace / Entrée pour
/// révéler, 1 à 4 pour noter ; après correction, Entrée applique la note
/// proposée.
class ReviewSessionPage extends StatefulWidget {
  const ReviewSessionPage({super.key, required this.itemIds});

  final List<String> itemIds;

  /// Referme la zone de notes des prochaines sessions (tests).
  @visibleForTesting
  static void closeNotes() => _ReviewSessionPageState._noting = false;

  @override
  State<ReviewSessionPage> createState() => _ReviewSessionPageState();
}

class _ReviewSessionPageState extends State<ReviewSessionPage> {
  final _results = <Rating>[];
  final _session = Stopwatch()..start();
  final _card = Stopwatch();
  final _focus = FocusNode();

  Map<String, KnowledgeNode>? _nodes;
  PrerequisiteGraph _graph = PrerequisiteGraph(const []);

  /// File de la session ; on peut y ajouter des prérequis en cours de route.
  late final List<String> _ids = [...widget.itemIds];

  /// Révisées implicitement pendant la session : on ne les repropose pas.
  final _implied = <String>{};
  KnowledgeItem? _item;
  List<ReviewRecord> _history = const [];
  List<Anchor> _anchors = const [];
  List<Note> _notes = const [];
  var _index = 0;
  var _revealed = false;
  var _busy = false;

  /// Exercice tiré pour la carte affichée (corrigé automatiquement).
  ExerciseInstance? _exercise;
  List<TextEditingController> _answers = const [];
  List<int?> _picked = const [];

  /// Correction : juste, faux, ou `null` (sans réponse lisible) ; `null`
  /// avant la vérification.
  List<bool?>? _checks;
  final _random = math.Random();

  /// Zone de notes ouverte ; reste ouverte d'une carte à l'autre et d'une
  /// session à l'autre.
  static var _noting = false;

  /// Brouillon de la tentative pour la carte affichée.
  var _draftText = TextEditingController();
  var _draftInk = InkEditorController(InkDrawing.empty);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nodes == null) _load();
  }

  @override
  void dispose() {
    _focus.dispose();
    _draftText.dispose();
    _draftInk.dispose();
    for (final c in _answers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Tire l'exercice de [item] s'il en a un valide (sinon carte classique).
  ExerciseInstance? _draw(KnowledgeItem? item) {
    final source = item?.autoExercise;
    if (source == null) return null;
    try {
      return ExerciseTemplate.parse(source).generate(_random.nextInt(1 << 30));
    } catch (_) {
      // Modèle devenu invalide : carte classique plutôt que session bloquée.
      return null;
    }
  }

  VergerStore get _store => AppScope.of(context).store;

  Future<void> _load() async {
    final nodes = await _store.allNodes();
    _graph = PrerequisiteGraph(await _store.prerequisites());
    _nodes = {for (final n in nodes) n.id: n};
    await _show(0);
  }

  /// Affiche la connaissance n° [index] (en sautant celles supprimées entre
  /// temps).
  Future<void> _show(int index) async {
    var i = index;
    KnowledgeItem? item;
    while (i < _ids.length) {
      item = _implied.contains(_ids[i]) ? null : await _store.item(_ids[i]);
      if (item != null && !item.suspended) break;
      i++;
    }
    final history = item == null
        ? const <ReviewRecord>[]
        : await _store.history(item.id);
    final anchors = item == null
        ? const <Anchor>[]
        : await _store.anchorsOf(item.id);
    // Le verso : sans les tentatives des révisions précédentes.
    final notes = item == null
        ? const <Note>[]
        : [
            for (final n in await _store.notes(itemId: item.id))
              if (!n.isReviewAttempt) n,
          ];
    if (!mounted) return;
    final exercise = _draw(i < _ids.length ? item : null);
    for (final c in _answers) {
      c.dispose();
    }
    final (oldText, oldInk) = (_draftText, _draftInk);
    setState(() {
      _draftText = TextEditingController();
      _draftInk = InkEditorController(InkDrawing.empty);
      _exercise = exercise;
      _answers = [
        for (final _ in exercise?.questions ?? const [])
          TextEditingController(),
      ];
      _picked = List.filled(exercise?.questions.length ?? 0, null);
      _checks = null;
      _index = i;
      _item = i < _ids.length ? item : null;
      _history = history;
      _anchors = anchors;
      _notes = notes;
      _revealed = false;
      _busy = false;
    });
    // Après la reconstruction : l'ancien brouillon n'est plus affiché.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldText.dispose();
      oldInk.dispose();
    });
    _card
      ..reset()
      ..start();
    _focus.requestFocus();
  }

  Future<void> _rate(Rating rating) async {
    final item = _item;
    if (item == null || !_revealed || _busy) return;
    setState(() => _busy = true);
    // Tentative lue tout de suite (la carte suivante remplace le brouillon).
    final text = _draftText.text, ink = _draftInk.ink;
    final scheduler = AppScope.of(context).scheduler;
    final record = scheduler.record(
      item.scheduling,
      rating,
      DateTime.now(),
      fuzzKey: item.id,
      duration: _card.elapsed,
    );
    try {
      await _store.applyReview(item.id, record);
      _results.add(rating);
      await _saveAttempt(item, rating, text, ink);
      await _afterReview(item, rating, record.reviewedAt);
    } on StaleReviewException {
      // Révisée ailleurs entre-temps : on passe à la suivante, sans perdre
      // la tentative.
      await _saveAttempt(item, rating, text, ink);
    } catch (e) {
      // Connaissance supprimée entre-temps, erreur de base… : on prévient
      // et on passe à la suivante plutôt que de bloquer la session.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Révision non enregistrée : $e')),
        );
      }
    }
    await _show(_index + 1);
  }

  /// Enregistre la tentative (si elle n'est pas vide) avec la connaissance.
  Future<void> _saveAttempt(
    KnowledgeItem item,
    Rating rating,
    String text,
    InkDrawing ink,
  ) async {
    if (text.trim().isEmpty && ink.isEmpty) return;
    await _store.createNote(
      body: text,
      ink: ink.isEmpty ? null : ink,
      itemId: item.id,
      reviewRating: rating,
    );
  }

  /// Prérequis directs de [item] encore existants et actifs.
  Future<List<KnowledgeItem>> _prerequisitesOf(KnowledgeItem item) async => [
    for (final id in _graph.requires(item.id))
      if (await _store.item(id) case final p? when !p.suspended) p,
  ];

  /// Réussir une connaissance revient à revoir ses prérequis à réviser ;
  /// l'oublier invite à consolider ceux qui sont fragiles.
  Future<void> _afterReview(
    KnowledgeItem item,
    Rating rating,
    DateTime now,
  ) async {
    final prerequisites = await _prerequisitesOf(item);
    if (prerequisites.isEmpty || !mounted) return;
    final scheduler = AppScope.of(context).scheduler;
    final byId = {for (final p in prerequisites) p.id: p};
    final implied = impliedReviews(rating, [
      for (final p in prerequisites) (id: p.id, state: p.scheduling),
    ], now);
    final revised = <String>[];
    for (final id in implied) {
      final p = byId[id]!;
      final r = scheduler.record(p.scheduling, Rating.good, now, fuzzKey: id);
      try {
        await _store.applyReview(
          id,
          ReviewRecord(
            rating: r.rating,
            reviewedAt: r.reviewedAt,
            before: r.before,
            after: r.after,
            schedulerId: r.schedulerId,
            impliedBy: item.id,
          ),
        );
        _implied.add(id);
        revised.add(p.title);
      } on StaleReviewException {
        // Révisée ailleurs entre-temps.
      }
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (revised.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Revu en même temps : ${revised.map((t) => '« $t »').join(', ')}.',
          ),
        ),
      );
    }
    if (rating != Rating.again) return;
    final ahead = _ids.skip(_index + 1).toSet();
    final weak = [
      for (final p in prerequisites)
        if (!ahead.contains(p.id) &&
            (p.scheduling.isNew ||
                scheduler.retrievability(p.scheduling, now) < 0.8))
          p,
    ];
    if (weak.isEmpty) return;
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 10),
        content: Text(
          '« ${item.title} » s\'appuie sur '
          '${[for (final p in weak.take(3)) '« ${p.title} »', if (weak.length > 3) '${weak.length - 3} autre(s)'].join(', ')}, '
          '${weak.length > 1 ? 'fragiles ou pas encore vus' : 'fragile ou pas encore vu'}.',
        ),
        action: SnackBarAction(
          label: 'Ajouter à la séance',
          onPressed: () => _insertNext([for (final p in weak) p.id]),
        ),
      ),
    );
  }

  /// Place [ids] juste après la carte affichée (ou à la suite, si la
  /// session était finie).
  void _insertNext(List<String> ids) {
    if (!mounted) return;
    final finished = _item == null;
    final at = finished ? _ids.length : _index + 1;
    setState(() {
      // Celles déjà plus loin dans la file n'ont pas été proposées.
      _ids.insertAll(at, ids);
      _implied.removeAll(ids);
    });
    if (finished) _show(at);
  }

  void _reveal() {
    if (_item != null && !_revealed) setState(() => _revealed = true);
  }

  /// Corrige l'exercice ; tout lu → correction affichée et note proposée.
  void _check() {
    final exercise = _exercise;
    if (exercise == null || _revealed) return;
    final checks = [
      for (final (i, q) in exercise.questions.indexed)
        switch (q) {
          NumberQuestion() => q.check(_answers[i].text),
          ChoiceQuestion() => _picked[i] == null ? null : q.check(_picked[i]!),
        },
    ];
    setState(() {
      _checks = checks;
      if (!checks.contains(null)) _revealed = true;
    });
    if (_revealed) _focus.requestFocus();
  }

  /// Note proposée par la correction (après vérification).
  Rating? get _suggested {
    final checks = _checks;
    if (_exercise == null || !_revealed || checks == null) return null;
    return ratingForResults(checks.cast<bool>());
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    // Saisie de texte en cours (tentative, réponse) : les touches lui vont.
    final editing = FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<EditableText>();
    if (editing != null) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final suggested = _suggested;
    if (suggested != null && key == LogicalKeyboardKey.enter) {
      _rate(suggested);
      return KeyEventResult.handled;
    }
    // Exercice à corriger : les touches vont aux réponses.
    if (_exercise != null && !_revealed) return KeyEventResult.ignored;
    if (!_revealed &&
        (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter)) {
      _reveal();
      return KeyEventResult.handled;
    }
    final keys = {
      LogicalKeyboardKey.digit1: Rating.again,
      LogicalKeyboardKey.digit2: Rating.hard,
      LogicalKeyboardKey.digit3: Rating.good,
      LogicalKeyboardKey.digit4: Rating.easy,
      LogicalKeyboardKey.numpad1: Rating.again,
      LogicalKeyboardKey.numpad2: Rating.hard,
      LogicalKeyboardKey.numpad3: Rating.good,
      LogicalKeyboardKey.numpad4: Rating.easy,
    };
    final rating = keys[key];
    if (rating != null && _revealed) {
      _rate(rating);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final total = _ids.length;
    final done = _nodes != null && _item == null;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Terminer',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: done
              ? const Text('Session terminée')
              : Text('${(_index + 1).clamp(1, total)} / $total'),
          actions: [
            if (!done && _nodes != null && _exercise == null)
              IconButton(
                tooltip: 'Prendre des notes',
                isSelected: _noting,
                icon: const Icon(Icons.edit_note),
                onPressed: () => setState(() => _noting = !_noting),
              ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: LinearProgressIndicator(
              value: total == 0 ? 1 : (done ? total : _index) / total,
              minHeight: 3,
            ),
          ),
        ),
        body: _nodes == null
            ? const Center(child: CircularProgressIndicator())
            : done
            ? _Summary(results: _results, elapsed: _session.elapsed)
            : _buildCard(context, _item!),
      ),
    );
  }

  Widget _buildCard(BuildContext context, KnowledgeItem item) {
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final now = DateTime.now();
    final s = item.scheduling;
    final path = <String>[];
    for (var n = _nodes![item.nodeId]; n != null; n = _nodes![n.parentId]) {
      path.insert(0, n.title);
      if (path.length > _nodes!.length) break;
    }
    final preview = scope.scheduler.preview(s, now, fuzzKey: item.id);

    return Column(
      children: [
        Expanded(
          child: NoteSplit(
            title: Text(
              _revealed
                  ? 'Votre tentative : comparez au verso'
                  : 'Votre tentative',
            ),
            onClose: () => setState(() => _noting = false),
            // Pas de prise de notes pour un exercice corrigé
            // automatiquement : les réponses se saisissent dans la carte.
            note: _noting && _exercise == null
                ? NoteDraftEditor(
                    key: ObjectKey(_draftText),
                    text: _draftText,
                    ink: _draftInk,
                    hint: 'Rédigez de mémoire, puis révélez pour comparer',
                  )
                : null,
            content: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        path.join(' → '),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ItemGlyph(
                            family: item.kind.family,
                            stage: GrowthStage.of(s),
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            item.typeLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(item.title, style: theme.textTheme.headlineMedium),
                      // Recto : l'énoncé encadré dans le cours.
                      for (final anchor in _anchors.where(
                        (a) => a.role == AnchorRole.source,
                      )) ...[
                        const SizedBox(height: 16),
                        AnchorSnapshot(
                          key: ValueKey(anchor.id),
                          anchor: anchor,
                          maxHeight: 360,
                        ),
                      ],
                      const SizedBox(height: 32),
                      if (_exercise case final exercise?) ...[
                        _ExerciseView(
                          exercise: exercise,
                          answers: _answers,
                          picked: _picked,
                          checks: _checks,
                          locked: _revealed,
                          onPick: (q, choice) =>
                              setState(() => _picked[q] = choice),
                          onSubmit: _check,
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (!_revealed && _exercise == null)
                        Text(
                          item.kind.family == ItemFamily.exercise
                              ? 'Refaites l\'exercice, puis révélez.'
                              : 'Rappelez-vous l\'énoncé${item.kind.family == ItemFamily.statement ? ' et la démonstration' : ''}, puis révélez.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        )
                      else if (_revealed) ...[
                        // Verso : la rédaction manuscrite.
                        for (final anchor in _anchors.where(
                          (a) => a.role == AnchorRole.work,
                        )) ...[
                          AnchorSnapshot(
                            key: ValueKey(anchor.id),
                            anchor: anchor,
                            maxHeight: 640,
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Verso : les notes rédigées dans l'application.
                        for (final note in _notes.where((n) => !n.isBlank)) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: NoteContent(note: note),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (item.body != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: SelectionArea(
                              child: MathText(
                                item.body!,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          )
                        else if (_exercise == null &&
                            !_anchors.any((a) => a.role == AnchorRole.work) &&
                            _notes.every((n) => n.isBlank))
                          Text(
                            'Pas de contenu enregistré : comparez avec vos notes.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        const SizedBox(height: 24),
                        _StateLine(
                          state: s,
                          retrievability: scope.scheduler.retrievability(
                            s,
                            now,
                          ),
                          history: _history,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _revealed
                  ? Row(
                      children: [
                        for (final rating in Rating.values) ...[
                          if (rating != Rating.again) const SizedBox(width: 8),
                          Expanded(
                            child: _RatingButton(
                              rating: rating,
                              interval: preview[rating]!.due!.difference(now),
                              suggested: rating == _suggested,
                              onPressed: _busy ? null : () => _rate(rating),
                            ),
                          ),
                        ],
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: _exercise != null
                          ? FilledButton(
                              onPressed: _check,
                              child: const Text('Vérifier'),
                            )
                          : FilledButton(
                              onPressed: _reveal,
                              child: const Text('Révéler'),
                            ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.rating,
    required this.interval,
    required this.onPressed,
    this.suggested = false,
  });

  final Rating rating;
  final Duration interval;
  final VoidCallback? onPressed;

  /// Note proposée par la correction automatique : mise en avant.
  final bool suggested;

  @override
  Widget build(BuildContext context) {
    final color = rating.color;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        foregroundColor: suggested ? Colors.white : color,
        backgroundColor: suggested ? color : null,
        side: BorderSide(color: color.withValues(alpha: suggested ? 1 : 0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rating.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(formatInterval(interval), style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _StateLine extends StatelessWidget {
  const _StateLine({
    required this.state,
    required this.retrievability,
    required this.history,
  });

  final SchedulingState state;
  final double retrievability;
  final List<ReviewRecord> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.outline,
    );
    final parts = [
      state.phase.label,
      if (state.stability != null)
        'stabilité ${state.stability!.toStringAsFixed(1)} j',
      if (state.difficulty != null)
        'difficulté ${state.difficulty!.toStringAsFixed(1)}',
      if (!state.isNew) 'rappel estimé ${(retrievability * 100).round()} %',
    ];
    final recent = history.reversed
        .take(4)
        .map((r) => '${r.rating.label} (${formatDate(r.reviewedAt)})');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(parts.join(' · '), style: style),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Dernières révisions : ${recent.join(', ')}', style: style),
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.results, required this.elapsed});

  final List<Rating> results;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = {
      for (final r in Rating.values) r: results.where((x) => x == r).length,
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.spa_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              results.isEmpty
                  ? 'Aucune révision effectuée'
                  : results.length == 1
                  ? '1 connaissance révisée'
                  : '${results.length} connaissances révisées',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'en ${formatElapsed(elapsed)}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            if (results.isNotEmpty) ...[
              const SizedBox(height: 24),
              Wrap(
                spacing: 24,
                children: [
                  for (final r in Rating.values)
                    Column(
                      children: [
                        Text('${counts[r]}', style: theme.textTheme.titleLarge),
                        Text(r.label, style: theme.textTheme.labelMedium),
                      ],
                    ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Énoncé tiré et questions d'un exercice corrigé automatiquement ; après
/// vérification, chaque réponse est marquée juste ou fausse.
class _ExerciseView extends StatelessWidget {
  const _ExerciseView({
    required this.exercise,
    required this.answers,
    required this.picked,
    required this.checks,
    required this.locked,
    required this.onPick,
    required this.onSubmit,
  });

  final ExerciseInstance exercise;
  final List<TextEditingController> answers;
  final List<int?> picked;
  final List<bool?>? checks;
  final bool locked;
  final void Function(int question, int choice) onPick;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const good = Color(0xFF5B7F5E), bad = Color(0xFFC8553D);
    Widget mark(bool? ok) => Icon(
      ok == true ? Icons.check_circle : Icons.cancel,
      color: ok == true ? good : bad,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exercise.statement.trim().isNotEmpty) ...[
            MathText(exercise.statement, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
          ],
          for (final (i, q) in exercise.questions.indexed) ...[
            if (i > 0) const SizedBox(height: 16),
            if (q.prompt.trim().isNotEmpty) ...[
              MathText(q.prompt, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
            ],
            switch (q) {
              NumberQuestion() => Row(
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: answers[i],
                      enabled: !locked,
                      textInputAction: i == exercise.questions.length - 1
                          ? TextInputAction.done
                          : TextInputAction.next,
                      onSubmitted: (_) {
                        if (i == exercise.questions.length - 1) onSubmit();
                      },
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        isDense: true,
                        hintText: 'ex. -3/4, 0,5, sqrt(2)',
                        errorText: checks != null && checks![i] == null
                            ? 'Réponse illisible ou manquante'
                            : null,
                      ),
                    ),
                  ),
                  if (locked) ...[
                    const SizedBox(width: 12),
                    mark(checks![i]),
                    if (checks![i] != true) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Réponse : ${q.expectedText}',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
              ChoiceQuestion() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (j, choice) in q.choices.indexed)
                        ChoiceChip(
                          label: MathText(choice),
                          selected: picked[i] == j,
                          side: locked && j == q.correct
                              ? const BorderSide(color: good, width: 2)
                              : null,
                          onSelected: locked ? null : (_) => onPick(i, j),
                        ),
                    ],
                  ),
                  if (locked) ...[
                    const SizedBox(height: 8),
                    mark(checks![i]),
                  ] else if (checks != null && checks![i] == null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Choisissez une réponse',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            },
          ],
        ],
      ),
    );
  }
}
