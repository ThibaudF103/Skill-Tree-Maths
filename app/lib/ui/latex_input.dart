import 'package:flutter/services.dart';

/// Saisie LaTeX : referme automatiquement `$` et `{`, comme un éditeur de
/// code.
///
/// - `{` insère `{}` (et `\{` insère `\{\}`), `$` insère `$$`, le curseur
///   au milieu ; avec une sélection, celle-ci est entourée.
/// - Dans `$|$`, un second `$` ouvre une formule centrée : `$$|$$`.
/// - Dans une formule, taper le `$` ou la `}` déjà présent après le curseur
///   le saute ; un `$` tapé dans une formule non refermée la referme.
/// - Effacer l'ouverture d'une paire vide efface aussi la fermeture.
///
/// Seule la frappe d'un caractère est concernée : un collage reste intact.
class LatexAutoCloseFormatter extends TextInputFormatter {
  const LatexAutoCloseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final old = oldValue.text;
    final sel = oldValue.selection;
    if (!sel.isValid || newValue.composing.isValid) return newValue;
    final start = sel.start;
    final end = sel.end;
    final typed = newValue.text;

    // Effacement du caractère situé juste avant le curseur.
    if (sel.isCollapsed &&
        start > 0 &&
        newValue.selection.isCollapsed &&
        newValue.selection.start == start - 1 &&
        typed == old.replaceRange(start - 1, start, '')) {
      final removed = _pairAt(old, start - 1);
      if (removed == null) return newValue;
      final (from, to) = removed;
      return _value(old.replaceRange(from, to, ''), from);
    }

    // Frappe d'un seul caractère (remplaçant éventuellement la sélection).
    if (!newValue.selection.isCollapsed ||
        newValue.selection.start != start + 1 ||
        typed.length != old.length - (end - start) + 1) {
      return newValue;
    }
    final char = typed[start];
    if (!r'${}'.contains(char) || typed != old.replaceRange(start, end, char)) {
      return newValue;
    }
    final selected = old.substring(start, end);
    final prev = start > 0 ? old[start - 1] : '';
    final next = end < old.length ? old[end] : '';
    final escaped = prev == r'\' && !_isEscaped(old, start - 1);

    if (char == '}') {
      if (selected.isNotEmpty) return newValue;
      // `\}` tapé devant un `\}` déjà inséré : on le saute.
      if (escaped && old.startsWith(r'\}', end)) {
        return _value(old.replaceRange(start - 1, start, ''), start + 1);
      }
      return !escaped && next == '}' ? _value(old, start + 1) : newValue;
    }
    if (char == '{') {
      final close = escaped ? r'\}' : '}';
      return _value(
        old.replaceRange(start, end, '{$selected$close'),
        selected.isEmpty
            ? start + 1
            : start + 1 + selected.length + close.length,
      );
    }

    // `$`
    if (escaped) return newValue;
    if (selected.isNotEmpty) {
      return _value(
        old.replaceRange(start, end, '\$$selected\$'),
        start + 2 + selected.length,
      );
    }
    if (next == r'$') {
      // `$|$` isolé : formule centrée.
      if (prev == r'$' &&
          !_insideMath(old, start - 1) &&
          (start + 1 >= old.length || old[start + 1] != r'$')) {
        return _value(old.replaceRange(start, start, r'$$'), start + 1);
      }
      if (_insideMath(old, start)) return _value(old, start + 1);
    }
    // Dans une formule non refermée, le `$` la referme.
    if (_insideMath(old, start) && next != r'$') return newValue;
    return _value(old.replaceRange(start, start, r'$$'), start + 1);
  }

  /// Paire vide à effacer quand on efface l'ouverture située en [i] :
  /// bornes (début, fin) dans [text], ou `null`.
  static (int, int)? _pairAt(String text, int i) {
    final char = text[i];
    final after = i + 1;
    if (char == '{') {
      final escaped = i > 0 && text[i - 1] == r'\' && !_isEscaped(text, i - 1);
      if (!text.startsWith(escaped ? r'\}' : '}', after)) return null;
      // `\{|\}` : le `\` ouvrant part aussi.
      return escaped ? (i - 1, after + 2) : (i, after + 1);
    }
    if (char != r'$' || !text.startsWith(r'$', after) || _isEscaped(text, i)) {
      return null;
    }
    // `$$|$$` : on revient à `$|$`.
    if (i > 0 &&
        text[i - 1] == r'$' &&
        text.startsWith(r'$$', after) &&
        !_insideMath(text, i - 1)) {
      return (i, after + 1);
    }
    return _insideMath(text, i) ? null : (i, after + 1);
  }

  /// La position [i] est-elle à l'intérieur d'une formule `$…$` ou `$$…$$` ?
  static bool _insideMath(String text, int i) {
    var display = false;
    var inline = false;
    var j = 0;
    while (j < i) {
      if (text[j] == r'\') {
        j += 2;
        continue;
      }
      if (text[j] != r'$') {
        j++;
        continue;
      }
      final double = j + 1 < i && text[j + 1] == r'$';
      if (inline) {
        inline = false;
        j++;
      } else if (display) {
        // Un `$` isolé dans une formule centrée (fermeture en cours) ne
        // change rien.
        if (double) display = false;
        j += double ? 2 : 1;
      } else if (double) {
        display = true;
        j += 2;
      } else {
        inline = true;
        j++;
      }
    }
    return inline || display;
  }

  /// Le caractère en [i] est-il précédé d'un nombre impair de `\` ?
  static bool _isEscaped(String text, int i) {
    var count = 0;
    for (var j = i - 1; j >= 0 && text[j] == r'\'; j--) {
      count++;
    }
    return count.isOdd;
  }

  static TextEditingValue _value(String text, int caret) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret),
  );
}
