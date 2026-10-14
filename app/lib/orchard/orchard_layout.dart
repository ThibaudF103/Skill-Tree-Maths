import 'dart:math' as math;
import 'dart:ui';

import 'package:verger_core/verger_core.dart';

/// Connaissance telle que la voit le verger.
typedef SceneItem = ({
  String id,
  ItemFamily family,
  GrowthStage stage,
  bool isDue,
});

/// Branche partant du nœud affiché.
typedef SceneBranch = ({
  String id,
  String title,
  int twigs,
  List<SceneItem> items,
});

/// Ce que le verger doit représenter pour un nœud : ses branches (avec les
/// connaissances de leur descendance) et ses connaissances directes.
///
/// C'est la seule entrée de la mise en page : la visualisation ne dépend ni
/// du stockage ni de FSRS, seulement des stades de croissance.
typedef OrchardScene = ({
  String id,
  List<SceneBranch> branches,
  List<SceneItem> items,
});

/// Segment de bois (tronc, branche, rameau).
typedef WoodSegment = ({Offset from, Offset to, double width, bool bare});

/// Glyphe placé dans la scène.
typedef GlyphPlacement = ({SceneItem item, Offset center, double size});

/// Étiquette d'une branche, à son extrémité.
typedef BranchLabel = ({
  String branchId,
  String text,
  Offset anchor,
  bool alignRight,
  int hidden,
  bool isDue,
});

/// Zone sensible au toucher.
typedef HitTarget = ({Rect rect, String? branchId, String? itemId});

/// Résultat de la mise en page, prêt à dessiner.
class OrchardLayout {
  OrchardLayout({
    required this.size,
    required this.wood,
    required this.glyphs,
    required this.labels,
    required this.targets,
  });

  final Size size;
  final List<WoodSegment> wood;
  final List<GlyphPlacement> glyphs;
  final List<BranchLabel> labels;
  final List<HitTarget> targets;

  /// Cible touchée en [point] : connaissance en priorité, sinon branche.
  HitTarget? hitTest(Offset point) {
    HitTarget? branch;
    for (final target in targets.reversed) {
      if (!target.rect.contains(point)) continue;
      if (target.itemId != null) return target;
      branch ??= target;
    }
    return branch;
  }
}

/// Dispose un nœud du verger dans un rectangle de taille [size].
///
/// Tronc vertical ; branches en éventail, d'autant plus longues qu'elles
/// portent de connaissances ; connaissances le long des branches et de leurs
/// rameaux. Une même scène donne toujours la même image (aléa initialisé par
/// les identifiants).
OrchardLayout layoutOrchard(
  OrchardScene scene,
  Size size, {
  bool labels = true,
  int maxGlyphsPerBranch = 18,
}) {
  final w = size.width;
  final h = size.height;
  final unit = math.min(w, h);
  final glyph = (unit / 18).clamp(14.0, 30.0);
  final wood = <WoodSegment>[];
  final glyphs = <GlyphPlacement>[];
  final labelList = <BranchLabel>[];
  final targets = <HitTarget>[];

  final base = Offset(w / 2, h * 0.94);
  final branches = scene.branches;
  final hasBranches = branches.isNotEmpty;
  final top = Offset(w / 2, hasBranches ? h * 0.58 : h * 0.18);
  final totalItems =
      scene.items.length +
      branches.fold<int>(0, (sum, b) => sum + b.items.length);
  wood.add((
    from: base,
    to: top,
    width: unit * (hasBranches ? 0.045 : 0.025),
    bare: totalItems == 0,
  ));

  void place(SceneItem item, Offset center) {
    glyphs.add((item: item, center: center, size: glyph));
    targets.add((
      rect: Rect.fromCenter(
        center: center,
        width: glyph * 1.3,
        height: glyph * 1.3,
      ),
      branchId: null,
      itemId: item.id,
    ));
  }

  // Connaissances directes : le long du tronc (rameau) ou en couronne.
  if (!hasBranches) {
    final slots = _alongSegment(base, top, glyph, startT: 0.15);
    for (final (i, item) in scene.items.indexed) {
      if (i >= slots.length) break;
      place(item, slots[i]);
    }
  } else {
    for (final (i, item) in scene.items.indexed) {
      final angle = -math.pi / 2 + (i - (scene.items.length - 1) / 2) * 0.45;
      final radius = glyph * (1.2 + (i ~/ 7) * 1.1);
      place(item, top + Offset(math.cos(angle), math.sin(angle)) * radius);
    }
  }

  // Branches en éventail.
  final k = branches.length;
  final maxItems = branches.fold<int>(1, (m, b) => math.max(m, b.items.length));
  final spread = math.min(150.0, 40.0 * k) * math.pi / 180;
  for (final (i, branch) in branches.indexed) {
    final random = math.Random(_stableHash(branch.id));
    final angle =
        (k == 1 ? 0.0 : -spread / 2 + spread * i / (k - 1)) +
        (random.nextDouble() - 0.5) * 0.08;
    final weight = math.sqrt(branch.items.length / maxItems);
    final length = h * (0.22 + 0.14 * weight);
    final start = Offset.lerp(
      base,
      top,
      k <= 2 ? 1.0 : 0.88 + 0.12 * ((i % 2 == 0) ? 1 : 0),
    )!;
    var end = start + Offset(math.sin(angle), -math.cos(angle)) * length;
    end = Offset(
      end.dx.clamp(glyph * 2, w - glyph * 2),
      end.dy.clamp(glyph * 2, h - glyph * 2),
    );
    final bare = branch.items.isEmpty;
    wood.add((
      from: start,
      to: end,
      width: unit * (0.012 + 0.02 * weight),
      bare: bare,
    ));

    // Rameaux : un par sous-branche (au plus 4), vers l'extrémité.
    final twigEnds = <(Offset, Offset)>[];
    final twigCount = math.min(branch.twigs, 4);
    for (var t = 0; t < twigCount; t++) {
      final from = Offset.lerp(
        start,
        end,
        0.55 + 0.4 * t / math.max(1, twigCount),
      )!;
      final side = t.isEven ? 1 : -1;
      final twigAngle = angle + side * (0.5 + random.nextDouble() * 0.2);
      final to =
          from +
          Offset(math.sin(twigAngle), -math.cos(twigAngle)) * length * 0.32;
      wood.add((from: from, to: to, width: unit * 0.008, bare: bare));
      twigEnds.add((from, to));
    }

    // Emplacements des connaissances : branche, puis rameaux.
    final slots = [
      ..._alongSegment(start, end, glyph, startT: 0.3),
      for (final (from, to) in twigEnds)
        ..._alongSegment(from, to, glyph, startT: 0.4),
    ];
    final shown = math.min(
      math.min(slots.length, maxGlyphsPerBranch),
      branch.items.length,
    );
    for (var j = 0; j < shown; j++) {
      place(branch.items[j], slots[j]);
    }

    targets.insert(0, (
      rect: Rect.fromPoints(start, end).inflate(glyph * 1.2),
      branchId: branch.id,
      itemId: null,
    ));
    if (labels) {
      labelList.add((
        branchId: branch.id,
        text: branch.title,
        anchor: end + Offset(math.sin(angle), -math.cos(angle)) * glyph,
        alignRight: angle < -0.05,
        hidden: branch.items.length - shown,
        isDue: branch.items.any((item) => item.isDue),
      ));
    }
  }

  return OrchardLayout(
    size: size,
    wood: wood,
    glyphs: glyphs,
    labels: labelList,
    targets: targets,
  );
}

/// Emplacements alternés de part et d'autre d'un segment.
List<Offset> _alongSegment(
  Offset from,
  Offset to,
  double glyph, {
  double startT = 0.3,
}) {
  final vector = to - from;
  final length = vector.distance;
  if (length == 0) return const [];
  final normal = Offset(-vector.dy, vector.dx) / length;
  final step = glyph * 0.75;
  final count = ((length * (1 - startT)) / step).floor();
  return [
    for (var i = 0; i <= count; i++)
      from +
          vector * (startT + (1 - startT) * (count == 0 ? 1 : i / count)) +
          normal * glyph * 0.6 * (i.isEven ? 1 : -1),
  ];
}

/// FNV-1a 32 bits, stable d'une exécution à l'autre.
int _stableHash(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash;
}
