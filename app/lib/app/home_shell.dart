import 'package:flutter/material.dart';
import 'package:verger_core/verger_core.dart';

import '../features/documents/documents_page.dart';
import '../features/orchard/orchard_page.dart';
import '../features/review/reviews_page.dart';
import '../features/trees/trees_page.dart';
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
  _Destination(
    'Bibliothèque',
    Icons.local_library_outlined,
    Icons.local_library,
  ),
];

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  Stream<List<KnowledgeItem>>? _items;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _items ??= AppScope.of(context).store.watchItems();
  }

  /// Icône avec, pour « Révisions », le nombre de connaissances dues.
  Widget _icon(int index, IconData icon) {
    if (index != 1) return Icon(icon);
    return StreamBuilder<List<KnowledgeItem>>(
      stream: _items,
      builder: (context, snapshot) {
        final tomorrow = DayWindow.around(DateTime.now()).startOfTomorrow;
        final due =
            snapshot.data
                ?.where(
                  (i) =>
                      !i.suspended &&
                      !i.scheduling.isNew &&
                      i.scheduling.due!.isBefore(tomorrow),
                )
                .length ??
            0;
        return Badge(
          isLabelVisible: due > 0,
          label: Text('$due'),
          child: Icon(icon),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final page = switch (_index) {
      1 => const ReviewsPage(),
      2 => const TreesPage(),
      3 => const LibraryPage(),
      _ => const OrchardPage(),
    };

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (i, d) in _destinations.indexed)
                  NavigationRailDestination(
                    icon: _icon(i, d.icon),
                    selectedIcon: _icon(i, d.selectedIcon),
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
          for (final (i, d) in _destinations.indexed)
            NavigationDestination(
              icon: _icon(i, d.icon),
              selectedIcon: _icon(i, d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
