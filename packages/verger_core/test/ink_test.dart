import 'package:test/test.dart';
import 'package:verger_core/verger_core.dart';

InkStroke stroke(List<(double, double)> xy, {InkTool tool = InkTool.pen}) =>
    InkStroke(
      points: [for (final (x, y) in xy) (x: x, y: y, pressure: 0.5)],
      color: 0xFF1A237E,
      width: 3,
      tool: tool,
    );

void main() {
  test('format compact : aller-retour', () {
    final ink = InkDrawing([
      stroke([(10.04, 20), (30, 40.26)]),
      stroke([(5, 5)], tool: InkTool.highlighter),
    ]);
    final json = ink.toJson();
    expect((json['strokes'] as List).first, {
      'c': 0xFF1A237E,
      'w': 3,
      'p': [10, 20, 0.5, 30, 40.3, 0.5],
    });
    final back = InkDrawing.decode(ink.encode());
    expect(back.strokes, hasLength(2));
    expect(back.strokes[1].tool, InkTool.highlighter);
    expect(back.strokes[0].points[1], (x: 30.0, y: 40.3, pressure: 0.5));
    expect(InkDrawing.decode(back.encode()).strokes, back.strokes);
  });

  test('trait mal formé refusé', () {
    expect(
      () => InkDrawing.fromJson({
        'strokes': [
          {
            'c': 0,
            'w': 1,
            'p': [1, 2],
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test('gomme : retire les traits touchés', () {
    final ink = InkDrawing([
      stroke([(0, 0), (100, 0)]),
      stroke([(0, 50), (100, 50)]),
    ]);
    expect(ink.erase(50, 1, 2).strokes, [ink.strokes[1]]);
    expect(ink.erase(50, 25, 2).strokes, ink.strokes);
  });

  test('bas de l\'écriture', () {
    expect(InkDrawing.empty.bottom, 0);
    expect(
      InkDrawing([
        stroke([(0, 10), (0, 90)]),
      ]).bottom,
      93,
    );
  });
}
