import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';

const _n = fingerprintSide * fingerprintSide;

/// Page de notes : fond blanc avec un quadrillage léger (identique sur toutes
/// les pages) et quelques traits d'encre aléatoires mais reproductibles.
Uint8List page(int seed, {int strokes = 60}) {
  final random = Random(seed);
  final pixels = Uint8List(_n);
  for (var i = 0; i < _n; i++) {
    pixels[i] = (i ~/ fingerprintSide) % 4 == 0 ? 238 : 250;
  }
  for (var s = 0; s < strokes; s++) {
    pixels[random.nextInt(_n)] = 60 + random.nextInt(80);
  }
  return pixels;
}

/// La même page, complétée : l'encre existante reste, de l'encre s'ajoute.
Uint8List completed(Uint8List original, {int seed = 7}) {
  final copy = Uint8List.fromList(original);
  final random = Random(seed);
  for (var s = 0; s < 40; s++) {
    copy[random.nextInt(_n)] = 70;
  }
  return copy;
}

void main() {
  final p = [for (var i = 0; i < 6; i++) page(i)];

  test('pages de notes distinctes : faible distance mais encre différente', () {
    expect(fingerprintDistance(p[0], Uint8List.fromList(p[0])), 0);
    // Pages surtout blanches : la distance moyenne seule serait trompeuse.
    expect(fingerprintDistance(p[0], p[1]), lessThan(30));
    expect(fingerprintDistance(p[0], p[1]), greaterThan(1));
    expect(inkContainment(p[0], p[1]), lessThan(0.5));
    expect(inkContainment(p[0], completed(p[0])), 1);
    expect(inkContainment(page(1, strokes: 0), p[0]), 1); // page vierge
  });

  test('carnet complété à la fin : anciennes pages inchangées', () {
    final r = remapPages(p.sublist(0, 4), p);
    for (var i = 1; i <= 4; i++) {
      expect(r.matches[i], (page: i, exact: true));
    }
    expect(r.newPages, [5, 6]);
  });

  test('page insérée au milieu : les suivantes sont décalées', () {
    final inserted = [p[0], p[1], page(99), p[2], p[3]];
    final r = remapPages(p.sublist(0, 4), inserted);
    expect(r.matches[2], (page: 2, exact: true));
    expect(r.matches[3], (page: 4, exact: true));
    expect(r.matches[4], (page: 5, exact: true));
    expect(r.newPages, [3]);
  });

  test('page supprimée : pas de correspondance pour elle seule', () {
    final r = remapPages(p.sublist(0, 4), [p[0], p[2], p[3]]);
    expect(r.matches[1]!.page, 1);
    expect(r.matches[2]!.page, isNull);
    expect(r.matches[3]!.page, 2);
    expect(r.matches[4]!.page, 3);
    expect(r.newPages, isEmpty);
  });

  test('dernière page complétée puis nouvelles pages', () {
    final r = remapPages(p.sublist(0, 3), [p[0], p[1], completed(p[2]), p[3]]);
    expect(r.matches[3], (page: 3, exact: false));
    expect(r.newPages, [4]);
  });

  test('page remplacée par un tout autre contenu : à vérifier', () {
    final r = remapPages(p.sublist(0, 3), [p[0], page(42), p[2]]);
    expect(r.matches[2], (page: null, exact: false));
    expect(r.newPages, [2]);
  });

  test('pages réordonnées : appariement le plus long conservé', () {
    final r = remapPages(p.sublist(0, 3), [p[2], p[0], p[1]]);
    expect(r.matches[1], (page: 2, exact: true));
    expect(r.matches[2], (page: 3, exact: true));
    expect(r.matches[3]!.page, isNull);
  });
}
