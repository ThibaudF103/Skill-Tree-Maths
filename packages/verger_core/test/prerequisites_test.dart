import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';

Prerequisite p(String item, String requires) =>
    (itemId: item, requiresId: requires);

void main() {
  // d1, d2 : définitions ; t : théorème (d1, d2) ; c : corollaire (t) ;
  // x : exercice (c, d2).
  final graph = PrerequisiteGraph([
    p('t', 'd1'),
    p('t', 'd2'),
    p('c', 't'),
    p('x', 'c'),
    p('x', 'd2'),
  ]);

  test('prérequis directs et utilisations', () {
    expect(graph.requires('t'), {'d1', 'd2'});
    expect(graph.usedBy('d2'), {'t', 'x'});
    expect(graph.requires('d1'), isEmpty);
  });

  test('dépendances indirectes et cycles', () {
    expect(graph.dependsOn('x', 'd1'), isTrue);
    expect(graph.dependsOn('d1', 'x'), isFalse);
    expect(graph.wouldCreateCycle('d1', 'x'), isTrue);
    expect(graph.wouldCreateCycle('t', 't'), isTrue);
    expect(graph.wouldCreateCycle('x', 'd1'), isFalse);
  });

  test('ordre : chaque connaissance après ses prérequis', () {
    // Ordre de départ volontairement inversé : le graphe le corrige, et
    // départage d1 / d2 selon l'ordre donné.
    expect(graph.order(['x', 'c', 't', 'd2', 'd1']), [
      'd2',
      'd1',
      't',
      'c',
      'x',
    ]);
    expect(
      PrerequisiteGraph([p('a', 'b'), p('b', 'a')]).order(['a', 'b']),
      isNull,
    );
  });

  test('niveaux, en ignorant les prérequis hors de la sélection', () {
    expect(graph.levels(['d1', 'd2', 't', 'c', 'x']), {
      'd1': 0,
      'd2': 0,
      't': 1,
      'c': 2,
      'x': 3,
    });
    expect(graph.levels(['c', 'x']), {'c': 0, 'x': 1});
  });

  test('déblocage : prérequis vus une fois ; chaînes complètes', () {
    expect(graph.isUnlocked('d1', {}), isTrue);
    expect(graph.isUnlocked('t', {'d1'}), isFalse);
    expect(graph.isUnlocked('t', {'d1', 'd2'}), isTrue);
    expect(graph.ancestors('x'), {'c', 't', 'd1', 'd2'});
    expect(graph.descendants('d1'), {'t', 'c', 'x'});
  });
}
