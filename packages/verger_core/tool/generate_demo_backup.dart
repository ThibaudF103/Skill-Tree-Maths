// Génère une sauvegarde de démonstration : un modèle d'arbre et environ deux
// mois de révisions simulées (pour essayer le verger avec des données
// réalistes).
//
//   dart run tool/generate_demo_backup.dart modele.json sortie.json
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:verger_core/verger_core.dart';

void main(List<String> args) {
  final template = VergerArchive.fromJson(
    (jsonDecode(File(args[0]).readAsStringSync()) as Map).cast(),
  );
  final random = Random(42);
  final scheduler = const SchedulerSettings().build();
  final now = DateTime.now().toUtc();
  final start = now.subtract(const Duration(days: 60));

  final items = <KnowledgeItem>[];
  final reviews = <ArchivedReview>[];
  for (final (i, item) in template.items.indexed) {
    final created = start.add(Duration(days: i * 2, hours: 18));
    var state = SchedulingState.initial;
    // Les dernières connaissances créées n'ont pas encore été révisées.
    if (i < template.items.length - 4) {
      var at = created;
      while (at.isBefore(now)) {
        final p = random.nextDouble();
        final rating = p < 0.1
            ? Rating.again
            : p < 0.2
            ? Rating.hard
            : p < 0.9
            ? Rating.good
            : Rating.easy;
        final record = scheduler.record(state, rating, at, fuzzKey: item.id);
        reviews.add((itemId: item.id, record: record));
        state = record.after;
        // On révise parfois en retard.
        at = state.due!.add(Duration(hours: random.nextInt(40)));
      }
    }
    items.add(
      KnowledgeItem(
        id: item.id,
        nodeId: item.nodeId,
        kind: item.kind,
        title: item.title,
        body: item.body,
        createdAt: created,
        updatedAt: created,
        scheduling: state,
      ),
    );
  }
  final archive = VergerArchive(
    title: 'Démonstration',
    nodes: [
      for (final n in template.nodes)
        KnowledgeNode(
          id: n.id,
          parentId: n.parentId,
          title: n.title.replaceAll(' (exemple)', ''),
          sortIndex: n.sortIndex,
          curriculumKey: n.curriculumKey,
          origin: n.origin,
          createdAt: start,
        ),
    ],
    items: items,
    reviews: reviews,
    settings: const SchedulerSettings(),
  );
  File(args[1]).writeAsStringSync(jsonEncode(archive.toJson()));
  stdout.writeln('${items.length} connaissances, ${reviews.length} révisions');
}
