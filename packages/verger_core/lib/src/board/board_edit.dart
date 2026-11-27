part of 'board_layout.dart';

/// Modification du tableau issue d'un geste (déplacer une carte ou une
/// région, redimensionner une région) : géométrie à enregistrer et
/// changement de hiérarchie éventuel, à appliquer en une transaction.
final class BoardEdit {
  const BoardEdit({
    this.regions = const {},
    this.cards = const {},
    this.clearedCards = const {},
    this.itemMove,
    this.nodeMove,
  });

  /// Régions déplacées, agrandies ou poussées.
  final Map<String, BoardRect> regions;

  /// Cartes déplacées ou poussées.
  final Map<String, BoardPoint> cards;

  /// Cartes sans place, que la mise en page automatique replacera (carte
  /// déposée hors de toute région, rangée dans « Non classées »).
  final Set<String> clearedCards;

  /// Connaissance changée de nœud ; [KnowledgeNode.unsortedId] : vers
  /// « Non classées » (nœud créé au besoin).
  final ({String itemId, String nodeId})? itemMove;

  /// Nœud changé de parent (`null` : il devient un arbre).
  final ({String nodeId, String? parentId})? nodeMove;

  bool get isEmpty =>
      regions.isEmpty &&
      cards.isEmpty &&
      clearedCards.isEmpty &&
      itemMove == null &&
      nodeMove == null;
}

/// Opérations d'édition du tableau, sur un instantané des nœuds et
/// connaissances (géométrie manquante complétée comme par [layoutBoard]).
/// Chaque opération part de l'instantané : elles sont indépendantes.
///
/// Mêmes règles que la mise en page : ce qui est déjà placé bouge le moins
/// possible ; une région qui grandit ou arrive pousse vers le bas les
/// voisines qu'elle recouvrirait, et son parent grandit au besoin.
final class BoardEditor {
  BoardEditor(
    this.nodes,
    this.items, {
    this.config = const BoardLayoutConfig(),
    this.snap = 8,
  });

  final List<KnowledgeNode> nodes;
  final List<KnowledgeItem> items;
  final BoardLayoutConfig config;

  /// Pas de la grille d'aimantation des positions déposées.
  final double snap;

  late final _Layout _base = _layout();

  _Layout _layout() => _Layout(nodes, items, config)..run();

  /// Région du nœud [id] dans l'instantané.
  BoardRect? region(String id) => _base._regions[id];

  /// Position de la carte [id] dans l'instantané.
  BoardPoint? card(String id) => _base._cards[id];

  /// Région la plus profonde contenant [p] (`null` : hors de toute région),
  /// en ignorant [excluding] et sa descendance. [forRegion] : cible d'une
  /// région déplacée (« Non classées » n'accueille que des cartes).
  String? regionAt(BoardPoint p, {String? excluding, bool forRegion = false}) =>
      _base._regionAt(p, excluding: excluding, forRegion: forRegion);

  /// Rectangle demandé pour la région [id], ramené au plus petit qui
  /// contient son contenu (avec les marges) et dans la zone utile de son
  /// parent.
  BoardRect clampResize(String id, BoardRect requested) =>
      _base._clampResize(id, requested);

  /// Carte [itemId] déposée avec son coin en [topLeft], le doigt en [at] :
  /// elle rejoint la région la plus profonde sous le doigt, à la place
  /// libre la plus proche ; hors de toute région, « Non classées ».
  BoardEdit moveCard(
    String itemId, {
    required BoardPoint topLeft,
    required BoardPoint at,
  }) => _layout()._moveCard(itemId, _snapped(topLeft), at);

  /// Région [nodeId] déposée avec son coin en [topLeft], le doigt en
  /// [at] : elle emporte son contenu et rejoint la région la plus profonde
  /// sous le doigt (hors d'elle-même), ou devient un arbre.
  BoardEdit moveRegion(
    String nodeId, {
    required BoardPoint topLeft,
    required BoardPoint at,
  }) => _layout()._moveRegion(nodeId, _snapped(topLeft), at);

  /// Région [nodeId] redimensionnée vers [requested] (voir [clampResize]).
  BoardEdit resizeRegion(String nodeId, BoardRect requested) =>
      _layout()._resizeRegion(nodeId, requested);

  BoardPoint _snapped(BoardPoint p) => BoardPoint(
    (p.x / snap).roundToDouble() * snap,
    (p.y / snap).roundToDouble() * snap,
  );
}

extension on _Layout {
  bool _isWithin(String id, String ancestor) {
    for (String? n = id; n != null; n = _parentOf[n]) {
      if (n == ancestor) return true;
    }
    return false;
  }

  String? _regionAt(BoardPoint p, {String? excluding, bool forRegion = false}) {
    String? best;
    for (final MapEntry(key: id, value: r) in _regions.entries) {
      if (!r.containsPoint(p)) continue;
      if (excluding != null && _isWithin(id, excluding)) continue;
      if (forRegion && _isWithin(id, KnowledgeNode.unsortedId)) continue;
      if (best == null) {
        best = id;
        continue;
      }
      final d = _depth[id]!.compareTo(_depth[best]!);
      final a = _regions[best]!.area.compareTo(r.area);
      if (d > 0 || (d == 0 && (a > 0 || (a == 0 && id.compareTo(best) < 0)))) {
        best = id;
      }
    }
    return best;
  }

  List<_Box> _rootBoxes() => [
    for (final r in _children[null] ?? const <KnowledgeNode>[])
      if (_regions.containsKey(r.id))
        _Box(r.id, _regions[r.id]!, isRegion: true),
  ];

  /// Remonte depuis [id] : chaque région agrandie pousse ses voisines puis
  /// fait grandir son parent.
  void _growUp(String id) {
    for (String? current = id; current != null;) {
      if (!_fit(current)) return;
      final parent = _parentOf[current];
      _resolve(parent == null ? _rootBoxes() : _boxesIn(parent), {
        current,
      }, parent == null ? c.rootGap : c.gap);
      current = parent;
    }
  }

  /// Place libre la plus proche de [desired] dans la zone utile de [id]
  /// (au-delà du bord droit ou bas, la région grandira).
  BoardPoint _nearestFree(String id, BoardPoint desired, double w, double h) {
    final area = _content(id);
    final d = BoardPoint(
      math.max(desired.x, area.x),
      math.max(desired.y, area.y),
    );
    final obstacles = [for (final b in _boxesIn(id)) b.rect];
    final g = c.gap;
    final candidates = <BoardPoint>[
      d,
      for (final o in obstacles) ...[
        BoardPoint(o.right + g, d.y),
        BoardPoint(o.x - g - w, d.y),
        BoardPoint(d.x, o.bottom + g),
        BoardPoint(d.x, o.y - g - h),
        BoardPoint(o.right + g, o.y),
        BoardPoint(o.x, o.bottom + g),
      ],
    ];
    BoardPoint? best;
    var bestDistance = double.infinity;
    for (final p in candidates) {
      if (p.x < area.x - _Layout._eps || p.y < area.y - _Layout._eps) {
        continue;
      }
      final halo = BoardRect.at(p, w, h).inflate(g - _Layout._eps);
      if (obstacles.any(halo.overlaps)) continue;
      final dx = p.x - d.x, dy = p.y - d.y;
      final distance = dx * dx + dy * dy;
      if (distance < bestDistance ||
          (distance == bestDistance &&
              (p.y < best!.y || (p.y == best.y && p.x < best.x)))) {
        best = p;
        bestDistance = distance;
      }
    }
    if (best != null) return best;
    final below = obstacles.map((o) => o.bottom + g).fold(area.y, math.max);
    return BoardPoint(area.x, below);
  }

  BoardEdit _result({
    Set<String> cleared = const {},
    ({String itemId, String nodeId})? itemMove,
    ({String nodeId, String? parentId})? nodeMove,
  }) => BoardEdit(
    regions: {for (final id in _changedRegions) id: _regions[id]!},
    cards: {for (final id in _changedCards) id: ?_cards[id]},
    clearedCards: cleared,
    itemMove: itemMove,
    nodeMove: nodeMove,
  );

  BoardEdit _moveCard(String itemId, BoardPoint topLeft, BoardPoint at) {
    final from = _itemNode[itemId];
    if (from == null) return const BoardEdit();
    final item = _items[from]!.firstWhere((i) => i.id == itemId);
    final target = _regionAt(at);
    if (target == null) {
      // Hors de toute région : rangée dans « Non classées », replacée
      // automatiquement.
      return _result(
        cleared: {itemId},
        itemMove: from == KnowledgeNode.unsortedId
            ? null
            : (itemId: itemId, nodeId: KnowledgeNode.unsortedId),
      );
    }
    _cards.remove(itemId);
    _changedCards.remove(itemId);
    if (target != from) {
      _items[from]!.remove(item);
      (_items[target] ??= []).add(item);
      _itemNode[itemId] = target;
    }
    _cards[itemId] = _nearestFree(target, topLeft, c.cardWidth, c.cardHeight);
    _changedCards.add(itemId);
    _growUp(target);
    return _result(
      itemMove: target == from ? null : (itemId: itemId, nodeId: target),
    );
  }

  void _setDepth(String id, int depth) {
    _depth[id] = depth;
    for (final k in _kids(id)) {
      _setDepth(k.id, depth + 1);
    }
  }

  BoardEdit _moveRegion(String id, BoardPoint topLeft, BoardPoint at) {
    final current = _regions[id];
    if (current == null) return const BoardEdit();
    final from = _parentOf[id];
    // « Non classées » reste un arbre.
    final target = id == KnowledgeNode.unsortedId
        ? null
        : _regionAt(at, excluding: id, forRegion: true);
    if (target != from) {
      final node = _children[from]!.firstWhere((n) => n.id == id);
      _children[from]!.remove(node);
      (_children[target] ??= []).add(node);
      _parentOf[id] = target;
      _setDepth(id, target == null ? 0 : _depth[target]! + 1);
      _fitBands(id);
    }
    final moved = _regions[id]!;
    var x = topLeft.x, y = topLeft.y;
    if (target != null) {
      // Dans la zone utile du parent (qui ne grandit que vers la droite et
      // le bas).
      final area = _content(target);
      x = math.max(x, area.x);
      y = math.max(y, area.y);
    }
    if (x != moved.x || y != moved.y) {
      _translate(id, x - moved.x, y - moved.y);
    }
    _resolve(target == null ? _rootBoxes() : _boxesIn(target), {
      id,
    }, target == null ? c.rootGap : c.gap);
    if (target != null) _growUp(target);
    return _result(
      nodeMove: target == from ? null : (nodeId: id, parentId: target),
    );
  }

  /// Après un changement de profondeur, le bandeau de titre a pu
  /// grandir : chaque région de la branche (des feuilles vers [id]) s'étend
  /// vers le haut pour que son contenu reste sous le bandeau.
  void _fitBands(String id) {
    for (final k in _kids(id)) {
      if (_regions.containsKey(k.id)) _fitBands(k.id);
    }
    final r = _regions[id]!;
    final boxes = _boxesIn(id);
    if (boxes.isEmpty) return;
    final top = boxes.map((b) => b.rect.y).reduce(math.min);
    final needed = top - c.titleBand(_depth[id]!);
    if (needed >= r.y - _Layout._eps) return;
    _regions[id] = BoardRect(r.x, needed, r.width, r.bottom - needed);
    _changedRegions.add(id);
  }

  BoardRect _clampResize(String id, BoardRect requested) {
    final current = _regions[id];
    if (current == null) return requested;
    final band = c.titleBand(_depth[id]!);
    final pad = c.padding;
    var left = requested.x, top = requested.y;
    var right = requested.right, bottom = requested.bottom;
    final boxes = _boxesIn(id);
    if (boxes.isNotEmpty) {
      final content = boxes.map((b) => b.rect).reduce((a, b) => a.union(b));
      left = math.min(left, content.x - pad);
      top = math.min(top, content.y - band);
      right = math.max(right, content.right + pad);
      bottom = math.max(bottom, content.bottom + pad);
    }
    final parent = _parentOf[id];
    if (parent != null) {
      final area = _content(parent);
      left = math.max(left, area.x);
      top = math.max(top, area.y);
    }
    // Au moins la place d'une carte ; le bord tiré cède.
    final minW = c.cardWidth + 2 * pad;
    final minH = band + c.cardHeight + pad;
    if (right - left < minW) {
      if (left != current.x) {
        left = right - minW;
      } else {
        right = left + minW;
      }
    }
    if (bottom - top < minH) {
      if (top != current.y) {
        top = bottom - minH;
      } else {
        bottom = top + minH;
      }
    }
    return BoardRect(left, top, right - left, bottom - top);
  }

  BoardEdit _resizeRegion(String id, BoardRect requested) {
    if (!_regions.containsKey(id)) return const BoardEdit();
    final rect = _clampResize(id, requested);
    if (rect != _regions[id]) {
      _regions[id] = rect;
      _changedRegions.add(id);
      final parent = _parentOf[id];
      _resolve(parent == null ? _rootBoxes() : _boxesIn(parent), {
        id,
      }, parent == null ? c.rootGap : c.gap);
      if (parent != null) _growUp(parent);
    }
    return _result();
  }
}
