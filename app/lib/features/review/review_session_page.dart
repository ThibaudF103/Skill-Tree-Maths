import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

import '../../app/app_scope.dart';
import '../../ui/item_glyph.dart';
import '../../ui/labels.dart';
import '../../ui/math_text.dart';
import '../items/anchors_section.dart';

/// Session de révision façon cartes : on lit le titre, on tente de se
/// souvenir, on révèle le contenu, puis on s'évalue.
///
/// Raccourcis clavier : Espace / Entrée pour révéler, 1 à 4 pour noter.
class ReviewSessionPage extends StatefulWidget {
  const ReviewSessionPage({super.key, required this.itemIds});

  final List<String> itemIds;

  @override
  State<ReviewSessionPage> createState() => _ReviewSessionPageState();
}

class _ReviewSessionPageState extends State<ReviewSessionPage> {
  final _results = <Rating>[];
  final _session = Stopwatch()..start();
  final _card = Stopwatch();
  final _focus = FocusNode();

  Map<String, KnowledgeNode>? _nodes;
  KnowledgeItem? _item;
  List<ReviewRecord> _history = const [];
  List<Anchor> _anchors = const [];
  var _index = 0;
  var _revealed = false;
  var _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nodes == null) _load();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  VergerStore get _store => AppScope.of(context).store;

  Future<void> _load() async {
    final nodes = await _store.allNodes();
    _nodes = {for (final n in nodes) n.id: n};
    await _show(0);
  }

  /// Affiche la connaissance n° [index] (en sautant celles supprimées entre
  /// temps).
  Future<void> _show(int index) async {
    var i = index;
    KnowledgeItem? item;
    while (i < widget.itemIds.length) {
      item = await _store.item(widget.itemIds[i]);
      if (item != null && !item.suspended) break;
      i++;
    }
    final history = item == null
        ? const <ReviewRecord>[]
        : await _store.history(item.id);
    final anchors = item == null
        ? const <Anchor>[]
        : await _store.anchorsOf(item.id);
    if (!mounted) return;
    setState(() {
      _index = i;
      _item = i < widget.itemIds.length ? item : null;
      _history = history;
      _anchors = anchors;
      _revealed = false;
      _busy = false;
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
    } on StaleReviewException {
      // Révisée ailleurs entre-temps : on passe simplement à la suivante.
    }
    await _show(_index + 1);
  }

  void _reveal() {
    if (_item != null && !_revealed) setState(() => _revealed = true);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
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
    final total = widget.itemIds.length;
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
          child: SingleChildScrollView(
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
                          item.kind.label,
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
                      AnchorSnapshot(anchor: anchor, maxHeight: 360),
                    ],
                    const SizedBox(height: 32),
                    if (!_revealed)
                      Text(
                        item.kind.family == ItemFamily.exercise
                            ? 'Refaites l\'exercice, puis révélez.'
                            : 'Rappelez-vous l\'énoncé${item.kind.family == ItemFamily.statement ? ' et la démonstration' : ''}, puis révélez.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      )
                    else ...[
                      // Verso : la rédaction manuscrite.
                      for (final anchor in _anchors.where(
                        (a) => a.role == AnchorRole.work,
                      )) ...[
                        AnchorSnapshot(anchor: anchor, maxHeight: 640),
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
                          child: MathText(
                            item.body!,
                            style: theme.textTheme.bodyLarge,
                          ),
                        )
                      else if (!_anchors.any((a) => a.role == AnchorRole.work))
                        Text(
                          'Pas de contenu enregistré : comparez avec vos notes.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      const SizedBox(height: 24),
                      _StateLine(
                        state: s,
                        retrievability: scope.scheduler.retrievability(s, now),
                        history: _history,
                      ),
                    ],
                  ],
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
                              onPressed: _busy ? null : () => _rate(rating),
                            ),
                          ),
                        ],
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
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
  });

  final Rating rating;
  final Duration interval;
  final VoidCallback? onPressed;

  static const _colors = {
    Rating.again: Color(0xFFC8553D),
    Rating.hard: Color(0xFFE09A3E),
    Rating.good: Color(0xFF5B7F5E),
    Rating.easy: Color(0xFF3F7CAC),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[rating]!;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
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
