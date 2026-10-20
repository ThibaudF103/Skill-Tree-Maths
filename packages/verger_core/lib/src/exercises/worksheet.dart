import 'dart:convert';

import 'exercise_template.dart';
import 'seeded_random.dart';

/// Exercice corrigé automatiquement, proposé pour les fiches.
final class WorksheetSource {
  const WorksheetSource({
    required this.itemId,
    required this.title,
    required this.template,
  });

  final String itemId;
  final String title;
  final ExerciseTemplate template;
}

/// Exercice tiré pour une fiche.
final class WorksheetExercise {
  const WorksheetExercise({
    required this.itemId,
    required this.title,
    required this.instance,
    required this.templateSource,
  });

  final String itemId;
  final String title;
  final ExerciseInstance instance;

  /// Modèle d'où l'exercice est tiré.
  final String templateSource;
}

/// Fiche d'un élève : ses exercices, et le code qui permet de la corriger
/// (graine et exercices, sans rien demander à la base).
final class Worksheet {
  const Worksheet({
    required this.student,
    required this.seed,
    required this.exercises,
  });

  final String student;
  final int seed;
  final List<WorksheetExercise> exercises;

  WorksheetCode get code => WorksheetCode(
    student: student,
    seed: seed,
    itemIds: [for (final e in exercises) e.itemId],
    templatesHash: worksheetTemplatesHash([
      for (final e in exercises) e.templateSource,
    ]),
  );
}

/// Contenu du QR code d'une fiche.
final class WorksheetCode {
  const WorksheetCode({
    required this.student,
    required this.seed,
    required this.itemIds,
    required this.templatesHash,
  });

  final String student;
  final int seed;
  final List<String> itemIds;

  /// Empreinte des modèles à l'impression : un modèle modifié depuis ne
  /// redonne plus les mêmes énoncés (voir [worksheetTemplatesHash]).
  final int templatesHash;

  static const _type = 'verger-fiche';

  String encode() => jsonEncode({
    'v': 1,
    't': _type,
    'n': student,
    'g': seed,
    'i': itemIds,
    'h': templatesHash,
  });

  /// Code lu sur une fiche ; `null` s'il n'en vient pas.
  static WorksheetCode? decode(String text) {
    try {
      final json = jsonDecode(text);
      if (json is! Map<String, Object?> ||
          json['v'] != 1 ||
          json['t'] != _type) {
        return null;
      }
      final (n, g, i, h) = (json['n'], json['g'], json['i'], json['h']);
      if (n is! String ||
          g is! int ||
          h is! int ||
          i is! List ||
          i.any((x) => x is! String)) {
        return null;
      }
      return WorksheetCode(
        student: n,
        seed: g,
        itemIds: i.cast<String>(),
        templatesHash: h,
      );
    } on FormatException {
      return null;
    }
  }
}

/// Empreinte des modèles d'une fiche, dans l'ordre de ses exercices.
int worksheetTemplatesHash(List<String> sources) =>
    SeededRandom.hashString(sources.join('\u0000'));

/// Graine de l'exercice [itemId] sur la fiche de graine [sheetSeed] : la
/// correction retrouve ainsi l'énoncé de l'élève.
int worksheetExerciseSeed(int sheetSeed, String itemId) =>
    SeededRandom.hashString('$sheetSeed:$itemId');

/// Une fiche par élève, [perSheet] exercices chacune (tous s'il y en a
/// moins), dans l'ordre de [sources]. Chaque élève a ses exercices et ses
/// valeurs, tirés de [session] (une même session redonne les mêmes fiches).
List<Worksheet> planWorksheets({
  required List<String> students,
  required List<WorksheetSource> sources,
  required int perSheet,
  required String session,
}) => [
  for (final (i, student) in students.indexed)
    _sheet(
      student,
      SeededRandom.hashString('$session:$i:$student'),
      sources,
      perSheet,
    ),
];

Worksheet _sheet(
  String student,
  int seed,
  List<WorksheetSource> sources,
  int perSheet,
) {
  var chosen = sources;
  if (perSheet < sources.length) {
    final order = [for (var i = 0; i < sources.length; i++) i];
    SeededRandom(seed).shuffle(order);
    final picked = order.take(perSheet).toList()..sort();
    chosen = [for (final i in picked) sources[i]];
  }
  return Worksheet(
    student: student,
    seed: seed,
    exercises: [
      for (final s in chosen)
        WorksheetExercise(
          itemId: s.itemId,
          title: s.title,
          instance: s.template.generate(worksheetExerciseSeed(seed, s.itemId)),
          templateSource: s.template.source,
        ),
    ],
  );
}
