import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../ui/item_glyph.dart';
import '../../ui/labels.dart';
import '../trees/node_picker.dart';
import '../trees/tree_data.dart';
import 'review_session_page.dart';

/// File d'une session lancée maintenant parmi [items] (dues et nouvelles).
///
/// Avec [prerequisites] (déblocage progressif), une nouvelle connaissance
/// n'est proposée qu'après tous ses prérequis, vus dans [all] (tout le
/// verger : un prérequis peut être dans une autre branche) ou plus tôt dans
/// la session.
List<String> reviewQueueOf(
  Iterable<KnowledgeItem> items,
  Scheduler scheduler, {
  PrerequisiteGraph? prerequisites,
  Iterable<KnowledgeItem> all = const [],
}) {
  final queue = buildReviewQueue(
    [
      for (final item in items)
        if (!item.suspended)
          (id: item.id, state: item.scheduling, createdAt: item.createdAt),
    ],
    now: DateTime.now(),
    scheduler: scheduler,
    requires: prerequisites?.requires,
    seen: seenIds(all),
  );
  return [for (final e in queue) e.id];
}

/// Connaissances déjà vues au moins une fois.
Set<String> seenIds(Iterable<KnowledgeItem> items) => {
  for (final item in items)
    if (!item.scheduling.isNew) item.id,
};

/// File d'une session sur [items] selon les réglages enregistrés
/// (déblocage progressif ou non).
Future<List<String>> loadReviewQueue(
  BuildContext context,
  Iterable<KnowledgeItem> items,
  Iterable<KnowledgeItem> all,
) async {
  final scope = AppScope.of(context);
  final strict = await scope.store.strictPrerequisites();
  final graph = strict
      ? PrerequisiteGraph(await scope.store.prerequisites())
      : null;
  return reviewQueueOf(items, scope.scheduler, prerequisites: graph, all: all);
}

/// Ouvre une session de révision sur [ids], dans cet ordre.
void startReviewSession(BuildContext context, List<String> ids) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ReviewSessionPage(itemIds: ids),
    ),
  );
}

/// Vue « Révisions » : connaissances à réviser, triées par priorité, dans
/// tout le verger ou dans les arbres / branches ciblés.
class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  Stream<Set<String>>? _scope;
  Stream<bool>? _strict;
  Stream<List<Prerequisite>>? _edges;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context).store;
    _scope ??= store.watchReviewScope();
    _strict ??= store.watchStrictPrerequisites();
    _edges ??= store.watchPrerequisites();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: _scope,
      builder: (context, snapshot) => StreamBuilder<bool>(
        stream: _strict,
        builder: (context, strict) => StreamBuilder<List<Prerequisite>>(
          stream: _edges,
          builder: (context, edges) => TreeDataBuilder(
            builder: (context, data) => _build(
              context,
              data,
              snapshot.data ?? const {},
              strict: strict.data ?? true,
              graph: PrerequisiteGraph(edges.data ?? const []),
            ),
          ),
        ),
      ),
    );
  }

  Widget _build(
    BuildContext context,
    TreeData data,
    Set<String> savedScope, {
    required bool strict,
    required PrerequisiteGraph graph,
  }) {
    final scheduler = AppScope.of(context).scheduler;
    // Nœuds ciblés encore existants (vide : tout le verger).
    final scope = [
      for (final node in data.nodes)
        if (savedScope.contains(node.id)) node,
    ];
    final scopeIds = {for (final n in scope) n.id};
    bool inScope(KnowledgeItem item) =>
        scopeIds.isEmpty ||
        data.pathTo(item.nodeId).any((n) => scopeIds.contains(n.id));
    final active = [
      for (final item in data.items)
        if (!item.suspended && inScope(item)) item,
    ];
    final byId = {for (final item in active) item.id: item};
    final candidates = [
      for (final item in active)
        (id: item.id, state: item.scheduling, createdAt: item.createdAt),
    ];
    final groups = groupReviewList(
      candidates,
      now: data.now,
      scheduler: scheduler,
    );
    final seen = seenIds(data.items);
    final queue = buildReviewQueue(
      candidates,
      now: data.now,
      scheduler: scheduler,
      requires: strict ? graph.requires : null,
      seen: seen,
    );
    final queued = {for (final e in queue) e.id};
    return _ReviewList(
      data: data,
      byId: byId,
      groups: groups,
      queue: [for (final e in queue) e.id],
      locked: strict
          ? {
              for (final item in active)
                if (item.scheduling.isNew && !queued.contains(item.id)) item.id,
            }
          : const {},
      strict: strict,
      scope: scope,
      onScopeChanged: (ids) => AppScope.of(context).store.setReviewScope(ids),
      onStrictChanged: (v) =>
          AppScope.of(context).store.setStrictPrerequisites(v),
    );
  }
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({
    required this.data,
    required this.byId,
    required this.groups,
    required this.queue,
    required this.locked,
    required this.strict,
    required this.scope,
    required this.onScopeChanged,
    required this.onStrictChanged,
  });

  final TreeData data;
  final Map<String, KnowledgeItem> byId;
  final Map<ReviewBucket, List<QueueEntry<String>>> groups;

  /// File d'une session lancée maintenant (connaissances dues et nouvelles).
  final List<String> queue;

  /// Nouvelles connaissances en attente de leurs prérequis.
  final Set<String> locked;

  /// Déblocage progressif activé.
  final bool strict;
  final ValueChanged<bool> onStrictChanged;

  /// Nœuds ciblés (vide : tout le verger).
  final List<KnowledgeNode> scope;
  final ValueChanged<Set<String>> onScopeChanged;

  void _start(BuildContext context, List<String> ids) =>
      startReviewSession(context, ids);

  Future<void> _pickScope(BuildContext context) async {
    final ids = await pickNodes(
      context,
      title: 'Réviser seulement…',
      initial: {for (final n in scope) n.id},
    );
    if (ids != null) onScopeChanged(ids);
  }

  Widget _scopeBar(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () => _pickScope(context),
          icon: const Icon(Icons.filter_alt_outlined),
          label: Text(scope.isEmpty ? 'Tout le verger' : 'Cibler'),
        ),
        for (final node in scope)
          InputChip(
            label: Text(node.title),
            tooltip: data.pathTo(node.id).map((n) => n.title).join(' › '),
            deleteButtonTooltipMessage: 'Retirer de la sélection',
            onDeleted: () => onScopeChanged({
              for (final n in scope)
                if (n.id != node.id) n.id,
            }),
          ),
        Tooltip(
          message:
              'Une nouvelle connaissance n\'est proposée qu\'une fois tous '
              'ses prérequis vus au moins une fois.',
          child: FilterChip(
            avatar: Icon(strict ? Icons.lock_outline : Icons.lock_open),
            showCheckmark: false,
            label: const Text('Déblocage progressif'),
            selected: strict,
            onSelected: onStrictChanged,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dueNow = queue.where((id) => !byId[id]!.scheduling.isNew).length;
    final fresh = queue.length - dueNow;
    final later = groups[ReviewBucket.later]!.length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Révisions',
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              queue.isEmpty
                                  ? scope.isEmpty
                                        ? 'Rien à réviser pour le moment.'
                                        : 'Rien à réviser dans la sélection.'
                                  : [
                                      if (dueNow > 0) '$dueNow à réviser',
                                      if (fresh > 0)
                                        '$fresh nouvelle${fresh > 1 ? 's' : ''}',
                                      if (locked.isNotEmpty)
                                        '${locked.length} en attente de '
                                            'prérequis',
                                    ].join(' · '),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: queue.isEmpty
                            ? null
                            : () => _start(context, queue),
                        icon: const Icon(Icons.play_arrow),
                        label: Text('Commencer (${queue.length})'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (data.items.isNotEmpty) _scopeBar(context),
                  const SizedBox(height: 16),
                  for (final bucket in const [
                    ReviewBucket.overdue,
                    ReviewBucket.today,
                    ReviewBucket.tomorrow,
                    ReviewBucket.newItem,
                  ])
                    if (groups[bucket]!.isNotEmpty) ...[
                      _BucketHeader(
                        bucket: bucket,
                        count: groups[bucket]!.length,
                      ),
                      for (final entry in groups[bucket]!)
                        _ReviewRow(
                          item: byId[entry.id]!,
                          bucket: bucket,
                          path: data
                              .pathTo(byId[entry.id]!.nodeId)
                              .map((n) => n.title)
                              .join(' → '),
                          now: data.now,
                          locked: locked.contains(entry.id),
                          onTap: () => _start(context, [
                            entry.id,
                            ...queue.where((id) => id != entry.id),
                          ]),
                        ),
                      const SizedBox(height: 16),
                    ],
                  if (later > 0)
                    Text(
                      later == 1
                          ? '1 connaissance prévue plus tard.'
                          : '$later connaissances prévues plus tard.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  if (data.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Text(
                        'Ajoutez des connaissances dans l\'onglet Arbres : '
                        'elles apparaîtront ici.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Couleurs discrètes des groupes (pastilles).
Color bucketColor(ReviewBucket bucket) => switch (bucket) {
  ReviewBucket.overdue => const Color(0xFFC8553D),
  ReviewBucket.today => const Color(0xFFE09A3E),
  ReviewBucket.tomorrow => const Color(0xFFD8C25A),
  ReviewBucket.later => const Color(0xFF9DB58A),
  ReviewBucket.newItem => const Color(0xFF9DB58A),
};

class _BucketHeader extends StatelessWidget {
  const _BucketHeader({required this.bucket, required this.count});
  final ReviewBucket bucket;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = switch (bucket) {
      ReviewBucket.overdue => 'En retard',
      ReviewBucket.today => 'Aujourd\'hui',
      ReviewBucket.tomorrow => 'Demain',
      ReviewBucket.later => 'Plus tard',
      ReviewBucket.newItem => 'Nouvelles',
    };
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: bucketColor(bucket),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        const Divider(),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.item,
    required this.bucket,
    required this.path,
    required this.now,
    required this.locked,
    required this.onTap,
  });

  final KnowledgeItem item;
  final ReviewBucket bucket;
  final String path;
  final DateTime now;

  /// Nouvelle en attente de prérequis (on peut quand même la lancer).
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = item.scheduling.due;
    final when = switch (bucket) {
      ReviewBucket.overdue =>
        'retard : ${formatDue(due!, now).replaceFirst('en retard de ', '')}',
      ReviewBucket.today => 'prévu ${formatDue(due!, now)}',
      ReviewBucket.tomorrow => 'prévu demain',
      ReviewBucket.newItem =>
        locked ? '${item.typeLabel} · verrouillée' : item.typeLabel,
      ReviewBucket.later => formatDue(due!, now),
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      onTap: onTap,
      leading: ItemGlyph(
        family: item.kind.family,
        stage: GrowthStage.of(item.scheduling),
        size: 32,
      ),
      title: Text(item.title),
      subtitle: Text(path),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (locked) ...[
            Icon(
              Icons.lock_outline,
              size: 16,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            when,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
