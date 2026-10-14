import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../ui/item_glyph.dart';
import '../../ui/labels.dart';
import '../trees/tree_data.dart';
import 'review_session_page.dart';

/// Vue « Révisions » : connaissances à réviser, triées par priorité.
class ReviewsPage extends StatelessWidget {
  const ReviewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return TreeDataBuilder(
      builder: (context, data) {
        final scheduler = AppScope.of(context).scheduler;
        final active = [
          for (final item in data.items)
            if (!item.suspended) item,
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
        final queue = buildReviewQueue(
          candidates,
          now: data.now,
          scheduler: scheduler,
        );
        return _ReviewList(
          data: data,
          byId: byId,
          groups: groups,
          queue: [for (final e in queue) e.id],
        );
      },
    );
  }
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({
    required this.data,
    required this.byId,
    required this.groups,
    required this.queue,
  });

  final TreeData data;
  final Map<String, KnowledgeItem> byId;
  final Map<ReviewBucket, List<QueueEntry<String>>> groups;

  /// File d'une session lancée maintenant (connaissances dues et nouvelles).
  final List<String> queue;

  void _start(BuildContext context, List<String> ids) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ReviewSessionPage(itemIds: ids),
      ),
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
                                  ? 'Rien à réviser pour le moment.'
                                  : [
                                      if (dueNow > 0) '$dueNow à réviser',
                                      if (fresh > 0)
                                        '$fresh nouvelle${fresh > 1 ? 's' : ''}',
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
                  const SizedBox(height: 24),
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
    required this.onTap,
  });

  final KnowledgeItem item;
  final ReviewBucket bucket;
  final String path;
  final DateTime now;
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
      ReviewBucket.newItem => item.kind.label,
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
      trailing: Text(
        when,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}
