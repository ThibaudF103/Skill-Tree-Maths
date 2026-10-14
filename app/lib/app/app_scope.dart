import 'package:flutter/widgets.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

/// Rend les services de l'application disponibles dans l'arbre de widgets.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.store,
    required this.scheduler,
    this.mastery = const MasteryModel(),
    required super.child,
  });

  final VergerStore store;
  final Scheduler scheduler;
  final MasteryModel mastery;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      store != oldWidget.store ||
      scheduler != oldWidget.scheduler ||
      mastery != oldWidget.mastery;
}
