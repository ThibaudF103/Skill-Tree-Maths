import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verger/ui/latex_input.dart';

/// Valeur décrite par un texte où `|` marque le curseur, ou `[…]` une
/// sélection.
TextEditingValue parse(String spec) {
  final open = spec.indexOf('[');
  if (open >= 0) {
    final close = spec.indexOf(']');
    return TextEditingValue(
      text: spec.replaceAll('[', '').replaceAll(']', ''),
      selection: TextSelection(baseOffset: open, extentOffset: close - 1),
    );
  }
  final caret = spec.indexOf('|');
  return TextEditingValue(
    text: spec.replaceAll('|', ''),
    selection: TextSelection.collapsed(offset: caret),
  );
}

String show(TextEditingValue v) =>
    v.text.replaceRange(v.selection.start, v.selection.start, '|');

/// Frappe de [char] (ou effacement si `null`) comme le ferait le champ.
String type(String spec, String? char) {
  final old = parse(spec);
  final s = old.selection;
  final TextEditingValue raw;
  if (char == null) {
    raw = TextEditingValue(
      text: old.text.replaceRange(s.start - 1, s.start, ''),
      selection: TextSelection.collapsed(offset: s.start - 1),
    );
  } else {
    raw = TextEditingValue(
      text: old.text.replaceRange(s.start, s.end, char),
      selection: TextSelection.collapsed(offset: s.start + 1),
    );
  }
  return show(const LatexAutoCloseFormatter().formatEditUpdate(old, raw));
}

void main() {
  test('accolades : fermeture, saut, échappement, sélection', () {
    expect(type(r'\frac|', '{'), r'\frac{|}');
    expect(type(r'\frac{a|}', '}'), r'\frac{a}|');
    expect(type(r'$\|$', '{'), r'$\{|\}$');
    expect(type(r'x^[ab]', '{'), r'x^{ab}|');
    expect(type('a|b', '}'), 'a}|b');
    // Accolades échappées : `\}` tapé saute le `\}` inséré.
    expect(type(r'\{x\|\}', '}'), r'\{x\}|');
    expect(type(r'{\|}', '}'), r'{\}|}');
  });

  test('dollars : formule en ligne, centrée, fermeture', () {
    expect(type('Soit |', r'$'), r'Soit $|$');
    expect(type(r'Soit $|$', r'$'), r'Soit $$|$$');
    expect(type(r'$x|$', r'$'), r'$x$|');
    expect(type(r'$$x|$$', r'$'), r'$$x$|$');
    expect(type(r'$$x$|$', r'$'), r'$$x$$|');
    expect(type(r'$x| et', r'$'), r'$x$| et');
    expect(type(r'prix 3\|', r'$'), r'prix 3\$|');
    expect(type('soit [u]', r'$'), r'soit $u$|');
    // Avant une formule existante : nouvelle paire, pas de saut.
    expect(type(r'|$y$', r'$'), r'$|$$y$');
  });

  test('effacement d\'une paire vide', () {
    expect(type('{|}', null), '|');
    expect(type(r'$|$', null), '|');
    expect(type(r'$$|$$', null), r'$|$');
    expect(type(r'\{|\}', null), '|');
    // Fermeture d'une formule suivie d'une autre : effacement simple.
    expect(type(r'$x$|$y$', null), r'$x|$y$');
    expect(type('{a|}', null), '{|}');
  });

  test('collage et saisie composée laissés intacts', () {
    final old = parse('a|');
    const pasted = TextEditingValue(
      text: r'a${',
      selection: TextSelection.collapsed(offset: 3),
    );
    expect(
      const LatexAutoCloseFormatter().formatEditUpdate(old, pasted),
      pasted,
    );
    const composing = TextEditingValue(
      text: r'a$',
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 1, end: 2),
    );
    expect(
      const LatexAutoCloseFormatter().formatEditUpdate(old, composing),
      composing,
    );
  });

  testWidgets('dans un champ : frappe caractère par caractère', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            controller: controller,
            inputFormatters: const [LatexAutoCloseFormatter()],
          ),
        ),
      ),
    );
    await tester.showKeyboard(find.byType(TextField));
    for (final char in r'Soit $\frac{1}{2}$ et $$x$$.'.split('')) {
      final v = controller.value;
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: v.text.replaceRange(v.selection.start, v.selection.end, char),
          selection: TextSelection.collapsed(offset: v.selection.start + 1),
        ),
      );
      await tester.pump();
    }
    // Les fermetures automatiques ont été sautées : aucun doublon.
    expect(controller.text, r'Soit $\frac{1}{2}$ et $$x$$.');
  });
}
