import 'package:verger_core/verger_core.dart';

/// Disposition en couches d'un graphe de prérequis : une colonne par niveau
/// (0 = aucun prérequis, à gauche), et dans chaque colonne un ordre qui
/// rapproche chaque connaissance de ses voisines pour limiter les
/// croisements (méthode des barycentres, quelques allers-retours).
class SkillLayout {
  SkillLayout._(this.cells, this.columnCount, this.rowCount);

  /// Colonne et rang de chaque connaissance.
  final Map<String, ({int column, int row})> cells;
  final int columnCount;

  /// Nombre de rangs de la plus haute colonne.
  final int rowCount;

  /// [ids] dans l'ordre de départ (ordre du cours), qui départage.
  factory SkillLayout.of(List<String> ids, PrerequisiteGraph graph) {
    final levels = graph.levels(ids) ?? {for (final i in ids) i: 0};
    final columnCount = ids.isEmpty
        ? 0
        : levels.values.reduce((a, b) => a > b ? a : b) + 1;
    final columns = [
      for (var c = 0; c < columnCount; c++)
        [
          for (final i in ids)
            if (levels[i] == c) i,
        ],
    ];
    final start = {for (final (n, i) in ids.indexed) i: n};
    final row = <String, double>{};
    void number() {
      for (final column in columns) {
        for (final (r, i) in column.indexed) {
          row[i] = r.toDouble();
        }
      }
    }

    number();
    // Barycentre des voisines déjà placées ; à défaut, place actuelle.
    void sweep(Iterable<int> order, Set<String> Function(String) neighbours) {
      for (final c in order) {
        final key = <String, double>{};
        for (final i in columns[c]) {
          final placed = [
            for (final n in neighbours(i))
              if (row[n] != null && levels[n] != c) row[n]!,
          ];
          key[i] = placed.isEmpty
              ? row[i]!
              : placed.reduce((a, b) => a + b) / placed.length;
        }
        columns[c].sort((a, b) {
          final k = key[a]!.compareTo(key[b]!);
          return k != 0 ? k : start[a]!.compareTo(start[b]!);
        });
        for (final (r, i) in columns[c].indexed) {
          row[i] = r.toDouble();
        }
      }
    }

    for (var pass = 0; pass < 3; pass++) {
      sweep([for (var c = 1; c < columnCount; c++) c], graph.requires);
      sweep([for (var c = columnCount - 2; c >= 0; c--) c], graph.usedBy);
    }
    return SkillLayout._(
      {
        for (final (c, column) in columns.indexed)
          for (final (r, i) in column.indexed) i: (column: c, row: r),
      },
      columnCount,
      columns.fold(0, (m, column) => column.length > m ? column.length : m),
    );
  }
}
