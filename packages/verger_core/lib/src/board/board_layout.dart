import 'dart:math' as math;

import '../domain/knowledge_item.dart';
import '../domain/knowledge_node.dart';
import 'board_geometry.dart';

/// Dimensions de la mise en page automatique du tableau (unités du
/// tableau).
final class BoardLayoutConfig {
  const BoardLayoutConfig({
    this.cardWidth = 220,
    this.cardHeight = 96,
    this.gap = 16,
    this.padding = 24,
    this.rootGap = 96,
  });

  /// Taille d'une carte (fixe pour l'instant).
  final double cardWidth;
  final double cardHeight;

  /// Écart entre cartes et régions voisines.
  final double gap;

  /// Marge intérieure d'une région (côtés et bas).
  final double padding;

  /// Écart entre deux arbres.
  final double rootGap;

  /// Bandeau du titre en haut d'une région : plus haut pour un arbre.
  double titleBand(int depth) => switch (depth) {
    0 => 88,
    1 => 64,
    _ => 48,
  };
}

/// Géométrie complète du tableau, et ce qui a changé par rapport à celle
/// enregistrée (à persister).
final class BoardLayout {
  const BoardLayout({
    required this.regions,
    required this.cards,
    required this.changedRegions,
    required this.changedCards,
  });

  /// Région de chaque nœud.
  final Map<String, BoardRect> regions;

  /// Coin supérieur gauche de chaque carte.
  final Map<String, BoardPoint> cards;

  /// Nœuds placés, agrandis ou décalés par ce calcul.
  final Set<String> changedRegions;

  /// Connaissances placées ou décalées par ce calcul.
  final Set<String> changedCards;

  bool get hasChanges => changedRegions.isNotEmpty || changedCards.isNotEmpty;

  /// Rectangle englobant tout le tableau (`null` s'il est vide).
  BoardRect? get bounds {
    BoardRect? all;
    for (final r in regions.values) {
      all = all == null ? r : all.union(r);
    }
    return all;
  }
}

/// Met en page le tableau : complète la géométrie de ce qui n'est pas encore
/// placé, sans bouger ce qui l'est.
///
/// - Un nœud non placé reçoit, avec toute sa descendance, une mise en page
///   neuve : ses cartes en grille sous le bandeau de titre, puis ses
///   sous-régions rangées par étagères (de gauche à droite, retour à la
///   ligne au-delà d'une largeur visée).
/// - Dans une région déjà placée, les nouvelles cartes et sous-régions vont
///   dans le premier espace libre (de haut en bas, puis de gauche à droite),
///   sinon en dessous du contenu ; la région s'agrandit alors (vers le bas,
///   et vers la droite si besoin), et les voisines qu'elle recouvrirait sont
///   poussées vers le bas avec leur contenu.
/// - Les arbres sont rangés par étagères au premier lancement ; un nouvel
///   arbre se place à droite des autres.
///
/// Déterministe : même entrée, même résultat (ordre des frères, puis date
/// de création, puis identifiant). Une connaissance dont le nœud est
/// inconnu est ignorée.
BoardLayout layoutBoard(
  List<KnowledgeNode> nodes,
  List<KnowledgeItem> items, {
  BoardLayoutConfig config = const BoardLayoutConfig(),
}) => _Layout(nodes, items, config).run();

/// Mise en page neuve d'un sous-arbre, relative à son coin supérieur
/// gauche.
class _Fresh {
  _Fresh(this.width, this.height);
  final double width;
  final double height;
  final regions = <String, BoardRect>{};
  final cards = <String, BoardPoint>{};
}

/// Boîte à ranger dans une région : sous-région ou carte.
class _Box {
  _Box(this.id, this.rect, {required this.isRegion});
  final String id;
  BoardRect rect;
  final bool isRegion;
}

class _Layout {
  _Layout(List<KnowledgeNode> nodes, List<KnowledgeItem> items, this.c) {
    final ids = {for (final n in nodes) n.id};
    int byOrder(
      ({int sortIndex, DateTime createdAt, String id}) a,
      ({int sortIndex, DateTime createdAt, String id}) b,
    ) {
      final s = a.sortIndex.compareTo(b.sortIndex);
      if (s != 0) return s;
      final d = a.createdAt.compareTo(b.createdAt);
      return d != 0 ? d : a.id.compareTo(b.id);
    }

    for (final n in nodes) {
      // Parent inconnu : traité comme un arbre.
      final parent = ids.contains(n.parentId) ? n.parentId : null;
      (_children[parent] ??= []).add(n);
    }
    for (final list in _children.values) {
      list.sort(
        (a, b) => byOrder(
          (sortIndex: a.sortIndex, createdAt: a.createdAt, id: a.id),
          (sortIndex: b.sortIndex, createdAt: b.createdAt, id: b.id),
        ),
      );
    }
    for (final i in items) {
      if (ids.contains(i.nodeId)) (_items[i.nodeId] ??= []).add(i);
    }
    for (final list in _items.values) {
      list.sort(
        (a, b) => byOrder(
          (sortIndex: a.sortIndex, createdAt: a.createdAt, id: a.id),
          (sortIndex: b.sortIndex, createdAt: b.createdAt, id: b.id),
        ),
      );
    }
    // Placé : a une région, et son parent aussi (sinon tout le sous-arbre
    // est refait). Profondeurs au passage.
    void visit(String? parent, int depth) {
      for (final n in _children[parent] ?? const <KnowledgeNode>[]) {
        _depth[n.id] = depth;
        final board = n.board;
        if (board != null && (parent == null || _regions.containsKey(parent))) {
          _regions[n.id] = board;
          for (final i in _items[n.id] ?? const <KnowledgeItem>[]) {
            final p = i.boardPosition;
            if (p != null) _cards[i.id] = p;
          }
        }
        visit(n.id, depth + 1);
      }
    }

    visit(null, 0);
  }

  final BoardLayoutConfig c;
  final _children = <String?, List<KnowledgeNode>>{};
  final _items = <String, List<KnowledgeItem>>{};
  final _depth = <String, int>{};
  final _regions = <String, BoardRect>{};
  final _cards = <String, BoardPoint>{};
  final _changedRegions = <String>{};
  final _changedCards = <String>{};

  /// Tolérance des comparaisons (sommes de flottants).
  static const _eps = 1e-6;

  BoardLayout run() {
    final roots = _children[null] ?? const <KnowledgeNode>[];
    final grown = <String>{
      for (final r in roots)
        if (_regions.containsKey(r.id) && _settle(r.id)) r.id,
    };
    if (grown.isNotEmpty) {
      _resolve(
        [
          for (final r in roots)
            if (_regions.containsKey(r.id))
              _Box(r.id, _regions[r.id]!, isRegion: true),
        ],
        grown,
        c.rootGap,
      );
    }
    final fresh = [
      for (final r in roots)
        if (!_regions.containsKey(r.id)) r.id,
    ];
    if (fresh.isNotEmpty) {
      final placed = [
        for (final r in roots)
          if (_regions.containsKey(r.id)) _regions[r.id]!,
      ];
      if (placed.isEmpty) {
        // Premier lancement : arbres rangés par étagères.
        final layouts = [for (final id in fresh) _fresh(id)];
        final shelf = _shelf(
          [for (final f in layouts) (f.width, f.height)],
          0,
          c.rootGap,
        );
        for (final (i, f) in layouts.indexed) {
          _apply(f, shelf.positions[i].x, shelf.positions[i].y);
        }
      } else {
        // Nouvel arbre : à droite de tout le reste, en haut.
        var right = placed.map((r) => r.right).reduce(math.max);
        final top = placed.map((r) => r.y).reduce(math.min);
        for (final id in fresh) {
          final f = _fresh(id);
          _apply(f, right + c.rootGap, top);
          right += c.rootGap + f.width;
        }
      }
    }
    return BoardLayout(
      regions: Map.unmodifiable(_regions),
      cards: Map.unmodifiable(_cards),
      changedRegions: Set.unmodifiable(_changedRegions),
      changedCards: Set.unmodifiable(_changedCards),
    );
  }

  List<KnowledgeNode> _kids(String id) =>
      _children[id] ?? const <KnowledgeNode>[];
  List<KnowledgeItem> _cardsOf(String id) =>
      _items[id] ?? const <KnowledgeItem>[];

  BoardRect _cardRect(BoardPoint p) =>
      BoardRect(p.x, p.y, c.cardWidth, c.cardHeight);

  /// Complète une région déjà placée : d'abord ses sous-régions placées,
  /// puis ses nouvelles cartes et sous-régions. Vrai si elle a grandi.
  bool _settle(String id) {
    final grown = <String>{
      for (final k in _kids(id))
        if (_regions.containsKey(k.id) && _settle(k.id)) k.id,
    };
    if (grown.isNotEmpty) _resolve(_boxesIn(id), grown, c.gap);
    for (final item in _cardsOf(id)) {
      if (_cards.containsKey(item.id)) continue;
      _cards[item.id] = _freeSpot(id, c.cardWidth, c.cardHeight);
      _changedCards.add(item.id);
    }
    for (final k in _kids(id)) {
      if (_regions.containsKey(k.id)) continue;
      final f = _fresh(k.id);
      final p = _freeSpot(id, f.width, f.height);
      _apply(f, p.x, p.y);
    }
    return _fit(id);
  }

  /// Sous-régions placées et cartes d'une région.
  List<_Box> _boxesIn(String id) => [
    for (final k in _kids(id))
      if (_regions.containsKey(k.id))
        _Box(k.id, _regions[k.id]!, isRegion: true),
    for (final i in _cardsOf(id))
      if (_cards.containsKey(i.id))
        _Box(i.id, _cardRect(_cards[i.id]!), isRegion: false),
  ];

  /// Zone utile d'une région : sous le bandeau de titre, dans les marges.
  BoardRect _content(String id) {
    final r = _regions[id]!;
    final top = c.titleBand(_depth[id]!);
    return BoardRect(
      r.x + c.padding,
      r.y + top,
      r.width - 2 * c.padding,
      r.height - top - c.padding,
    );
  }

  /// Premier emplacement libre de taille [w] × [h] dans la région [id] (de
  /// haut en bas, puis de gauche à droite), sinon sous son contenu.
  BoardPoint _freeSpot(String id, double w, double h) {
    final area = _content(id);
    final obstacles = [for (final b in _boxesIn(id)) b.rect];
    final candidates = <BoardPoint>[
      area.topLeft,
      for (final o in obstacles) ...[
        BoardPoint(o.right + c.gap, o.y),
        BoardPoint(o.x, o.bottom + c.gap),
        BoardPoint(area.x, o.bottom + c.gap),
      ],
    ];
    candidates.sort((a, b) {
      final dy = a.y.compareTo(b.y);
      return dy != 0 ? dy : a.x.compareTo(b.x);
    });
    for (final p in candidates) {
      final rect = BoardRect.at(p, w, h);
      if (!area.inflate(_eps).contains(rect)) continue;
      final halo = rect.inflate(c.gap - _eps);
      if (obstacles.every((o) => !halo.overlaps(o))) return p;
    }
    final below = obstacles.isEmpty
        ? area.y
        : obstacles.map((o) => o.bottom + c.gap).reduce(math.max);
    return BoardPoint(area.x, math.max(area.y, below));
  }

  /// Agrandit la région pour contenir ses cartes et sous-régions (jamais
  /// ne la rétrécit). Vrai si elle a grandi.
  bool _fit(String id) {
    final r = _regions[id]!;
    var right = r.right;
    var bottom = r.bottom;
    for (final b in _boxesIn(id)) {
      right = math.max(right, b.rect.right + c.padding);
      bottom = math.max(bottom, b.rect.bottom + c.padding);
    }
    if (right <= r.right + _eps && bottom <= r.bottom + _eps) return false;
    _regions[id] = BoardRect(r.x, r.y, right - r.x, bottom - r.y);
    _changedRegions.add(id);
    return true;
  }

  /// Supprime les chevauchements dus aux boîtes [dirty] (agrandies) : dans
  /// l'ordre de lecture, une boîte qui en recouvre une précédente, l'une
  /// des deux étant concernée, descend juste en dessous (avec son
  /// contenu). Les boîtes qui ne touchent à rien ne bougent pas.
  void _resolve(List<_Box> boxes, Set<String> dirty, double gap) {
    boxes.sort((a, b) {
      final dy = a.rect.y.compareTo(b.rect.y);
      if (dy != 0) return dy;
      final dx = a.rect.x.compareTo(b.rect.x);
      return dx != 0 ? dx : a.id.compareTo(b.id);
    });
    final done = <_Box>[];
    for (final box in boxes) {
      for (var moved = true; moved;) {
        moved = false;
        for (final other in done) {
          if (!dirty.contains(box.id) && !dirty.contains(other.id)) continue;
          if (!box.rect.inflate(gap - _eps).overlaps(other.rect)) continue;
          final dy = other.rect.bottom + gap - box.rect.y;
          _shift(box, dy);
          dirty.add(box.id);
          moved = true;
        }
      }
      done.add(box);
    }
  }

  /// Décale une boîte vers le bas, avec tout le contenu d'une région.
  void _shift(_Box box, double dy) {
    box.rect = box.rect.translate(0, dy);
    if (!box.isRegion) {
      _cards[box.id] = _cards[box.id]!.translate(0, dy);
      _changedCards.add(box.id);
      return;
    }
    void move(String id) {
      _regions[id] = _regions[id]!.translate(0, dy);
      _changedRegions.add(id);
      for (final i in _cardsOf(id)) {
        final p = _cards[i.id];
        if (p == null) continue;
        _cards[i.id] = p.translate(0, dy);
        _changedCards.add(i.id);
      }
      for (final k in _kids(id)) {
        if (_regions.containsKey(k.id)) move(k.id);
      }
    }

    move(box.id);
  }

  /// Mise en page neuve du sous-arbre [id] (ignore toute géométrie
  /// enregistrée dedans).
  _Fresh _fresh(String id) {
    final depth = _depth[id]!;
    final cards = _cardsOf(id);
    final band = c.titleBand(depth);

    // Cartes en grille presque carrée.
    final n = cards.length;
    final cols = n == 0 ? 0 : math.sqrt(n).ceil();
    final rows = n == 0 ? 0 : (n / cols).ceil();
    final gridW = cols == 0 ? 0.0 : cols * c.cardWidth + (cols - 1) * c.gap;
    final gridH = rows == 0 ? 0.0 : rows * c.cardHeight + (rows - 1) * c.gap;

    final subs = [for (final k in _kids(id)) _fresh(k.id)];
    final shelf = _shelf([for (final s in subs) (s.width, s.height)], gridW);
    final between = gridH > 0 && subs.isNotEmpty ? c.gap : 0.0;

    final contentW = [gridW, shelf.width, c.cardWidth].reduce(math.max);
    var contentH = gridH + between + shelf.height;
    // Une région vide garde la place d'une carte.
    if (contentH == 0) contentH = c.cardHeight;

    final result = _Fresh(
      contentW + 2 * c.padding,
      band + contentH + c.padding,
    );
    result.regions[id] = BoardRect(0, 0, result.width, result.height);
    for (final (i, item) in cards.indexed) {
      result.cards[item.id] = BoardPoint(
        c.padding + (i % cols) * (c.cardWidth + c.gap),
        band + (i ~/ cols) * (c.cardHeight + c.gap),
      );
    }
    final top = band + gridH + between;
    for (final (i, s) in subs.indexed) {
      final dx = c.padding + shelf.positions[i].x;
      final dy = top + shelf.positions[i].y;
      s.regions.forEach((k, r) => result.regions[k] = r.translate(dx, dy));
      s.cards.forEach((k, p) => result.cards[k] = p.translate(dx, dy));
    }
    return result;
  }

  /// Range des boîtes par étagères, dans l'ordre : de gauche à droite, à la
  /// ligne au-delà d'une largeur visée (au moins [minWidth] et la plus
  /// large des boîtes ; environ 1,4 fois la racine de l'aire totale, pour
  /// un ensemble plus large que haut).
  ({List<BoardPoint> positions, double width, double height}) _shelf(
    List<(double, double)> sizes,
    double minWidth, [
    double? gap,
  ]) {
    final g = gap ?? c.gap;
    if (sizes.isEmpty) {
      return (positions: const [], width: 0, height: 0);
    }
    final area = sizes.fold(0.0, (sum, s) => sum + s.$1 * s.$2);
    final target = [
      minWidth,
      math.sqrt(area) * 1.4,
      ...sizes.map((s) => s.$1),
    ].reduce(math.max);
    final positions = <BoardPoint>[];
    var x = 0.0, y = 0.0, rowH = 0.0, width = 0.0;
    for (final (w, h) in sizes) {
      if (x > 0 && x + w > target + _eps) {
        x = 0;
        y += rowH + g;
        rowH = 0;
      }
      positions.add(BoardPoint(x, y));
      width = math.max(width, x + w);
      rowH = math.max(rowH, h);
      x += w + g;
    }
    return (positions: positions, width: width, height: y + rowH);
  }

  /// Applique une mise en page neuve à la position ([dx], [dy]).
  void _apply(_Fresh f, double dx, double dy) {
    f.regions.forEach((id, r) {
      _regions[id] = r.translate(dx, dy);
      _changedRegions.add(id);
    });
    f.cards.forEach((id, p) {
      _cards[id] = p.translate(dx, dy);
      _changedCards.add(id);
    });
  }
}
