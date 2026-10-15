import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../../ui/item_glyph.dart';
import '../../ui/labels.dart';

/// Ligne d'une connaissance : glyphe, titre, type, stade et échéance.
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.item,
    required this.now,
    this.onTap,
    this.dragHandle,
  });

  final KnowledgeItem item;
  final DateTime now;
  final VoidCallback? onTap;

  /// Poignée de déplacement affichée en fin de ligne.
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = item.scheduling;
    final stage = GrowthStage.of(s);
    final due = s.due;
    final isDue =
        !s.isNew &&
        due != null &&
        due.isBefore(DayWindow.around(now).startOfTomorrow);
    final parts = [
      item.typeLabel,
      stage.label,
      if (item.suspended) 'suspendue' else if (due != null) formatDue(due, now),
    ];
    return ListTile(
      onTap: onTap,
      leading: ItemGlyph(family: item.kind.family, stage: stage, size: 32),
      title: Text(item.title),
      subtitle: Text(parts.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDue && !item.suspended)
            Icon(Icons.water_drop, size: 18, color: theme.colorScheme.primary),
          ?dragHandle,
        ],
      ),
    );
  }
}
