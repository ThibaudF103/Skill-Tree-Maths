import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';

void main() {
  test('newId produit des UUID v4 distincts', () {
    final ids = {for (var i = 0; i < 1000; i++) newId()};
    expect(ids, hasLength(1000));
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(ids.every(pattern.hasMatch), isTrue);
  });
}
