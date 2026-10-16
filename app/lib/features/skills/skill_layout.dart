import 'package:verger_core/verger_core.dart';

/// Case d'une connaissance : colonne (niveau de prérequis), bande (groupe,
/// par exemple la sous-branche) et rang dans la bande.
typedef SkillCell = ({int column, int band, int row});

/// Bande horizontale du graphe : un groupe de connaissances (sous-branche)
/// et sa hauteur en rangs.
typedef SkillBand = ({String group, int rowCount});

/// Disposition en couches d'un graphe de prérequis : une colonne par niveau
/// (0 = aucun prérequis, à gauche) et une bande horizontale par groupe ;
/// dans chaque bande et chaque colonne, un ordre qui rapproche chaque
/// connaissance de ses voisines pour limiter les croisements (méthode des
/// barycentres, quelques allers-retours).
class SkillLayout {
  SkillLayout._(this.cells, this.columnCount, this.bands);

  final Map<String, SkillCell> cells;
  final int columnCount;

  /// Bandes, de haut en bas.
  final List<SkillBand> bands;

  /// Nombre total de rangs (toutes bandes).
  int get rowCount => bands.fold(0, (n, b) => n + b.rowCount);

  /// [ids] dans l'ordre de départ (ordre du cours), qui départage ; les
  /// bandes suivent l'ordre d'apparition des groupes ([groupOf], une seule
  /// bande s'il est omis).
  factory SkillLayout.of(
    List<String> ids,
    PrerequisiteGraph graph, {
    String Function(String id)? groupOf,
  }) {
    final levels = graph.levels(ids) ?? {for (final i in ids) i: 0};
    final columnCount = ids.isEmpty
        ? 0
        : levels.values.reduce((a, b) => a > b ? a : b) + 1;
    final groups = <String>[];
    final bandOf = <String, int>{};
    for (final i in ids) {
      final g = groupOf?.call(i) ?? '';
      var b = groups.indexOf(g);
      if (b < 0) {
        b = groups.length;
        groups.add(g);
      }
      bandOf[i] = b;
    }
    // columns[bande][colonne] : connaissances dans l'ordre courant.
    final columns = [
      for (var b = 0; b < groups.length; b++)
        [
          for (var c = 0; c < columnCount; c++)
            [
              for (final i in ids)
                if (bandOf[i] == b && levels[i] == c) i,
            ],
        ],
    ];
    final heights = [
      for (final band in columns)
        band.fold(0, (m, column) => column.length > m ? column.length : m),
    ];
    final firstRow = <int>[];
    var total = 0;
    for (final h in heights) {
      firstRow.add(total);
      total += h;
    }
    final start = {for (final (n, i) in ids.indexed) i: n};
    // Rang global (toutes bandes confondues) de chaque connaissance.
    final row = <String, double>{};
    void number(int b, int c) {
      for (final (r, i) in columns[b][c].indexed) {
        row[i] = (firstRow[b] + r).toDouble();
      }
    }

    for (var b = 0; b < groups.length; b++) {
      for (var c = 0; c < columnCount; c++) {
        number(b, c);
      }
    }
    // Barycentre des voisines placées dans d'autres colonnes ; à défaut,
    // place actuelle.
    void sweep(Iterable<int> order, Set<String> Function(String) neighbours) {
      for (final c in order) {
        for (var b = 0; b < groups.length; b++) {
          final key = <String, double>{};
          for (final i in columns[b][c]) {
            final placed = [
              for (final n in neighbours(i))
                if (row[n] != null && levels[n] != c) row[n]!,
            ];
            key[i] = placed.isEmpty
                ? row[i]!
                : placed.reduce((a, b) => a + b) / placed.length;
          }
          columns[b][c].sort((x, y) {
            final k = key[x]!.compareTo(key[y]!);
            return k != 0 ? k : start[x]!.compareTo(start[y]!);
          });
          number(b, c);
        }
      }
    }

    for (var pass = 0; pass < 3; pass++) {
      sweep([for (var c = 1; c < columnCount; c++) c], graph.requires);
      sweep([for (var c = columnCount - 2; c >= 0; c--) c], graph.usedBy);
    }
    return SkillLayout._(
      {
        for (final (b, band) in columns.indexed)
          for (final (c, column) in band.indexed)
            for (final (r, i) in column.indexed)
              i: (column: c, band: b, row: r),
      },
      columnCount,
      [for (final (b, g) in groups.indexed) (group: g, rowCount: heights[b])],
    );
  }
}
