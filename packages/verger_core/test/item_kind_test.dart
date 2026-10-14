import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';

void main() {
  test('chaque type appartient à la bonne famille', () {
    expect(ItemKind.definition.family, ItemFamily.definition);
    expect(ItemKind.exercise.family, ItemFamily.exercise);
    for (final kind in [
      ItemKind.theorem,
      ItemKind.proposition,
      ItemKind.lemma,
      ItemKind.property,
      ItemKind.corollary,
    ]) {
      expect(kind.family, ItemFamily.statement, reason: kind.name);
    }
  });
}
