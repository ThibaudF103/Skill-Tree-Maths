import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../app/app_scope.dart';
import '../../ui/dialogs.dart';
import '../../ui/item_glyph.dart';
import '../../ui/labels.dart';
import 'anchors_section.dart';
import 'item_editor.dart';

/// Fiche d'une connaissance : contenu, état de révision, historique.
class ItemDetailPage extends StatefulWidget {
  const ItemDetailPage({super.key, required this.itemId, this.path = ''});

  final String itemId;

  /// Chemin lisible dans l'arbre (« Algèbre › Réduction »).
  final String path;

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  Stream<List<KnowledgeItem>>? _items;
  Future<List<ReviewRecord>>? _history;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context).store;
    _items ??= store.watchItems();
    _history ??= store.history(widget.itemId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<KnowledgeItem>>(
      stream: _items,
      builder: (context, snapshot) {
        final item = snapshot.data
            ?.where((i) => i.id == widget.itemId)
            .firstOrNull;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: snapshot.hasData
                ? const Center(child: Text('Connaissance supprimée'))
                : const Center(child: CircularProgressIndicator()),
          );
        }
        return _buildItem(context, item);
      },
    );
  }

  Widget _buildItem(BuildContext context, KnowledgeItem item) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final s = item.scheduling;
    final stage = GrowthStage.of(s);
    final r = scope.scheduler.retrievability(s, now);
    final mastery = scope.mastery.of(s, r);

    return Scaffold(
      appBar: AppBar(
        title: Text(item.kind.label),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                showItemEditor(context, nodeId: item.nodeId, item: item),
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              switch (action) {
                case 'suspend':
                  await scope.store.updateItem(
                    item.id,
                    suspended: !item.suspended,
                  );
                case 'delete':
                  final ok = await confirmDestructive(
                    context,
                    title: 'Supprimer la connaissance ?',
                    message:
                        '« ${item.title} » et son historique de révision '
                        'seront définitivement supprimés.',
                  );
                  if (ok) {
                    await scope.store.deleteItem(item.id);
                    if (context.mounted) Navigator.pop(context);
                  }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'suspend',
                child: Text(
                  item.suspended ? 'Reprendre les révisions' : 'Suspendre',
                ),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.path.isNotEmpty)
                    Text(
                      widget.path,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ItemGlyph(
                        family: item.kind.family,
                        stage: stage,
                        size: 48,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          item.title,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  if (item.body != null) ...[
                    const SizedBox(height: 20),
                    SelectableText(
                      item.body!,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                  const SizedBox(height: 28),
                  _Section(
                    title: 'Recto / verso',
                    child: AnchorsSection(item: item),
                  ),
                  const SizedBox(height: 28),
                  _Section(
                    title: 'Progression',
                    child: Wrap(
                      spacing: 32,
                      runSpacing: 16,
                      children: [
                        _Fact('Stade', stage.label),
                        _Fact('Maîtrise', '${(mastery * 100).round()} %'),
                        _Fact('Phase', s.phase.label),
                        if (item.suspended)
                          const _Fact('Révisions', 'suspendues')
                        else if (s.due != null)
                          _Fact('Prochaine révision', formatDue(s.due!, now)),
                        if (s.lastReview != null)
                          _Fact(
                            'Dernière révision',
                            formatDate(s.lastReview!, now: now),
                          ),
                        if (s.stability != null)
                          _Fact(
                            'Stabilité',
                            '${s.stability!.toStringAsFixed(1)} j',
                          ),
                        if (s.difficulty != null)
                          _Fact(
                            'Difficulté',
                            '${s.difficulty!.toStringAsFixed(1)} / 10',
                          ),
                        if (!s.isNew)
                          _Fact('Rappel estimé', '${(r * 100).round()} %'),
                        _Fact('Révisions', '${s.reps}'),
                        if (s.lapses > 0) _Fact('Oublis', '${s.lapses}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _Section(
                    title: 'Historique',
                    child: FutureBuilder<List<ReviewRecord>>(
                      future: _history,
                      builder: (context, snapshot) {
                        final history = snapshot.data;
                        if (history == null) return const SizedBox.shrink();
                        if (history.isEmpty) {
                          return Text(
                            'Pas encore révisée.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final record in history.reversed)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(record.rating.label),
                                subtitle: Text(
                                  formatDate(record.reviewedAt, now: now),
                                ),
                                trailing: record.after.due == null
                                    ? null
                                    : Text(
                                        '→ ${formatDate(record.after.due!, now: now)}',
                                      ),
                              ),
                          ],
                        );
                      },
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const Divider(),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}
