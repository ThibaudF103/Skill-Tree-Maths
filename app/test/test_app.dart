import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/app/verger_app.dart';
import 'package:verger_core/verger_core.dart';
import 'package:verger_data/verger_data.dart';

/// Lance l'application sur une base en mémoire, à la taille d'un iPad en
/// paysage par défaut.
Future<VergerStore> pumpTestApp(
  WidgetTester tester, {
  Size size = const Size(1180, 820),
  Future<void> Function(VergerStore store)? seed,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final store = VergerStore(VergerDatabase(NativeDatabase.memory()));
  if (seed != null) await tester.runAsync(() => seed(store));
  addTearDown(() => tester.runAsync(store.close));

  await tester.pumpWidget(
    VergerApp(store: store, scheduler: const SchedulerSettings().build()),
  );
  await settle(tester);
  return store;
}

/// Laisse la base répondre (vraies attentes) puis redessine.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Démonte l'application puis laisse drift fermer ses requêtes observées
/// (sinon un minuteur reste en attente à la fin du test).
Future<void> unmountTestApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await settle(tester);
}
