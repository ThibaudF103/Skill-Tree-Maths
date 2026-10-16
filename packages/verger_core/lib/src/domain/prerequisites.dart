/// Prérequis : la connaissance [itemId] s'appuie sur [requiresId] (une
/// définition pour un théorème, un théorème pour un exercice…).
typedef Prerequisite = ({String itemId, String requiresId});

/// Graphe des prérequis entre connaissances. Il doit rester sans cycle :
/// on ne peut pas avoir besoin, même indirectement, de ce qu'on démontre.
final class PrerequisiteGraph {
  PrerequisiteGraph(Iterable<Prerequisite> edges) {
    for (final e in edges) {
      (_requires[e.itemId] ??= {}).add(e.requiresId);
      (_usedBy[e.requiresId] ??= {}).add(e.itemId);
    }
  }

  final _requires = <String, Set<String>>{};
  final _usedBy = <String, Set<String>>{};

  /// Prérequis directs de [itemId].
  Set<String> requires(String itemId) => _requires[itemId] ?? const {};

  /// Connaissances qui s'appuient directement sur [itemId].
  Set<String> usedBy(String itemId) => _usedBy[itemId] ?? const {};

  /// Vrai si tous les prérequis directs de [itemId] ont été vus (sont dans
  /// [seen]) : la connaissance est alors débloquée. Il suffit d'avoir vu une
  /// fois une définition pour aborder les énoncés qui l'utilisent, qui
  /// aident à la comprendre.
  bool isUnlocked(String itemId, Set<String> seen) =>
      requires(itemId).every(seen.contains);

  /// Prérequis directs et indirects de [itemId].
  Set<String> ancestors(String itemId) => _reach(itemId, requires);

  /// Connaissances qui s'appuient, directement ou non, sur [itemId].
  Set<String> descendants(String itemId) => _reach(itemId, usedBy);

  Set<String> _reach(String from, Set<String> Function(String) next) {
    final seen = <String>{};
    final stack = [from];
    while (stack.isNotEmpty) {
      for (final n in next(stack.removeLast())) {
        if (seen.add(n)) stack.add(n);
      }
    }
    return seen;
  }

  /// Vrai si [itemId] s'appuie, directement ou non, sur [requiresId].
  bool dependsOn(String itemId, String requiresId) {
    final seen = <String>{};
    final stack = [itemId];
    while (stack.isNotEmpty) {
      for (final r in requires(stack.removeLast())) {
        if (r == requiresId) return true;
        if (seen.add(r)) stack.add(r);
      }
    }
    return false;
  }

  /// Vrai si ajouter « [itemId] s'appuie sur [requiresId] » créerait un
  /// cycle (ou une connaissance prérequise d'elle-même).
  bool wouldCreateCycle(String itemId, String requiresId) =>
      itemId == requiresId || dependsOn(requiresId, itemId);

  /// Ordre où chaque connaissance vient après ses prérequis ; à égalité,
  /// l'ordre de [items] est conservé. `null` si le graphe a un cycle.
  /// Les prérequis absents de [items] sont ignorés.
  List<String>? order(List<String> items) {
    final present = items.toSet();
    final pending = {
      for (final i in items) i: requires(i).where(present.contains).length,
    };
    final out = <String>[];
    final ready = [
      for (final i in items)
        if (pending[i] == 0) i,
    ];
    final rank = {for (final (n, i) in items.indexed) i: n};
    while (ready.isNotEmpty) {
      ready.sort((a, b) => rank[a]!.compareTo(rank[b]!));
      final next = ready.removeAt(0);
      out.add(next);
      for (final u in usedBy(next)) {
        if (!present.contains(u)) continue;
        pending[u] = pending[u]! - 1;
        if (pending[u] == 0) ready.add(u);
      }
    }
    return out.length == items.length ? out : null;
  }

  /// Niveau de chaque connaissance : 0 sans prérequis, sinon un de plus que
  /// le plus haut de ses prérequis (parmi [items]). `null` si cycle.
  Map<String, int>? levels(List<String> items) {
    final sorted = order(items);
    if (sorted == null) return null;
    final level = <String, int>{};
    for (final i in sorted) {
      var l = 0;
      for (final r in requires(i)) {
        final lr = level[r];
        if (lr != null && lr + 1 > l) l = lr + 1;
      }
      level[i] = l;
    }
    return level;
  }
}
