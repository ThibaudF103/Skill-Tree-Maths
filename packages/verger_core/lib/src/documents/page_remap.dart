import 'dart:math' as math;
import 'dart:typed_data';

/// Côté (en pixels) des empreintes de page : image en niveaux de gris de
/// [fingerprintSide] × [fingerprintSide] (0 = noir, 255 = blanc).
const fingerprintSide = 32;

/// Cases « encrées » d'une empreinte : nettement plus sombres que le fond de
/// la page (médiane), ce qui ignore le blanc et les quadrillages légers.
List<bool> inkCells(Uint8List fingerprint) {
  if (fingerprint.isEmpty) return const [];
  final sorted = [...fingerprint]..sort();
  final background = sorted[sorted.length ~/ 2];
  final limit = background - 30;
  return [for (final v in fingerprint) v < limit];
}

/// Part de l'encre de [before] encore présente dans [after] (1 si [before]
/// est vierge). Une page complétée garde son encre et en ajoute.
double inkContainment(Uint8List before, Uint8List after) {
  if (before.length != after.length) return 0;
  final a = inkCells(before);
  final b = inkCells(after);
  var ink = 0;
  var kept = 0;
  for (var i = 0; i < a.length; i++) {
    if (!a[i]) continue;
    ink++;
    // Tolérance d'une case (léger décalage de rendu).
    final x = i % fingerprintSide;
    final y = i ~/ fingerprintSide;
    var found = false;
    for (var dy = -1; dy <= 1 && !found; dy++) {
      for (var dx = -1; dx <= 1 && !found; dx++) {
        final nx = x + dx;
        final ny = y + dy;
        if (nx < 0 ||
            ny < 0 ||
            nx >= fingerprintSide ||
            ny >= fingerprintSide) {
          continue;
        }
        found = b[ny * fingerprintSide + nx];
      }
    }
    if (found) kept++;
  }
  return ink == 0 ? 1 : kept / ink;
}

/// Différence moyenne entre deux empreintes, de 0 (identiques) à 255.
double fingerprintDistance(Uint8List a, Uint8List b) {
  if (a.length != b.length || a.isEmpty) return 255;
  var sum = 0;
  for (var i = 0; i < a.length; i++) {
    sum += (a[i] - b[i]).abs();
  }
  return sum / a.length;
}

/// Correspondance d'une page de l'ancienne version.
typedef PageMatch = ({
  /// Page correspondante dans la nouvelle version (à partir de 1), ou `null`.
  int? page,

  /// `true` : page retrouvée à l'identique (ou presque).
  bool exact,
});

/// Résultat du recalage entre deux versions d'un PDF.
typedef PageRemap = ({
  /// Pour chaque page de l'ancienne version (à partir de 1).
  Map<int, PageMatch> matches,

  /// Pages de la nouvelle version sans équivalent dans l'ancienne.
  List<int> newPages,
});

/// Recale les pages d'un PDF mis à jour (typiquement un carnet de notes
/// réexporté) à partir des empreintes visuelles.
///
/// 1. Les pages au rendu identique (différence moyenne ≤ [exactThreshold])
///    sont appariées dans l'ordre (plus longue sous-suite commune) : une
///    insertion ou une suppression décale les pages suivantes sans les perdre.
/// 2. Entre deux appariements, une ancienne page encrée dont l'encre se
///    retrouve dans une page nouvelle (≥ [containmentThreshold]) lui est
///    appariée, dans l'ordre : page complétée ou annotée.
/// 3. Les autres pages anciennes n'ont pas de correspondance ; les pages
///    nouvelles restantes sont signalées comme nouvelles.
PageRemap remapPages(
  List<Uint8List> oldPages,
  List<Uint8List> newPages, {
  double exactThreshold = 1,
  double containmentThreshold = 0.8,
}) {
  final n = oldPages.length;
  final m = newPages.length;
  bool same(int i, int j) =>
      fingerprintDistance(oldPages[i], newPages[j]) <= exactThreshold;

  // Plus longue sous-suite commune.
  final lcs = List.generate(n + 1, (_) => Uint32List(m + 1));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      lcs[i][j] = same(i, j)
          ? lcs[i + 1][j + 1] + 1
          : math.max(lcs[i + 1][j], lcs[i][j + 1]);
    }
  }
  final pairs = <(int, int)>[];
  for (var i = 0, j = 0; i < n && j < m;) {
    if (same(i, j) && lcs[i][j] == lcs[i + 1][j + 1] + 1) {
      pairs.add((i, j));
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }

  final matches = <int, PageMatch>{};
  final usedNew = <int>{};
  for (final (i, j) in pairs) {
    matches[i + 1] = (page: j + 1, exact: true);
    usedNew.add(j);
  }

  // Pages modifiées entre deux appariements.
  final bounds = [(-1, -1), ...pairs, (n, m)];
  for (var k = 0; k + 1 < bounds.length; k++) {
    final (i0, j0) = bounds[k];
    final (i1, j1) = bounds[k + 1];
    // Dans l'ordre : chaque ancienne page prend la première page nouvelle
    // encore ressemblante qui suit la précédente correspondance.
    var next = j0 + 1;
    for (var i = i0 + 1; i < i1; i++) {
      for (var j = next; j < j1; j++) {
        if (inkCells(oldPages[i]).contains(true) &&
            inkContainment(oldPages[i], newPages[j]) >= containmentThreshold) {
          matches[i + 1] = (page: j + 1, exact: false);
          usedNew.add(j);
          next = j + 1;
          break;
        }
      }
    }
  }
  for (var i = 1; i <= n; i++) {
    matches.putIfAbsent(i, () => (page: null, exact: false));
  }

  return (
    matches: matches,
    newPages: [
      for (var j = 0; j < m; j++)
        if (!usedNew.contains(j)) j + 1,
    ],
  );
}
