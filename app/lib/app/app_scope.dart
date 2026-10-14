import 'package:flutter/widgets.dart';
import 'package:verger_data/verger_data.dart';

/// Rend les services de l'application (accès aux données) disponibles dans
/// l'arbre de widgets.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.store, required super.child});

  final VergerStore store;

  static VergerStore storeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.store;

  @override
  bool updateShouldNotify(AppScope oldWidget) => store != oldWidget.store;
}
