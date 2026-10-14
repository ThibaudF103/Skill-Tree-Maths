import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import 'app_scope.dart';

/// Navigation principale : rail latéral sur grand écran (iPad, PC),
/// barre inférieure sur téléphone.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('Verger', Icons.park_outlined, Icons.park),
  _Destination('Révisions', Icons.event_repeat_outlined, Icons.event_repeat),
  _Destination('Arbres', Icons.account_tree_outlined, Icons.account_tree),
];

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final page = _index == 2
        ? const _TreesSummaryPage()
        : _PlaceholderPage(title: _destinations[_index].label);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: page),
          ],
        ),
      );
    }
    return Scaffold(
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'À venir',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Provisoire (étape 2) : vérifie que la base locale est accessible.
class _TreesSummaryPage extends StatelessWidget {
  const _TreesSummaryPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: StreamBuilder<List<KnowledgeNode>>(
          stream: AppScope.storeOf(context).watchNodes(),
          builder: (context, snapshot) {
            final trees = snapshot.data?.where((n) => n.isTree).length;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Arbres', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  switch (trees) {
                    null => 'Ouverture de la base…',
                    0 => 'Base locale prête — aucun arbre pour l\'instant',
                    1 => '1 arbre',
                    final n => '$n arbres',
                  },
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
