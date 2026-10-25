import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Morceau d'un texte mathématique.
sealed class MathSegment {
  const MathSegment();
}

/// Texte ordinaire.
final class TextSegment extends MathSegment {
  const TextSegment(this.text);
  final String text;
  @override
  bool operator ==(Object other) => other is TextSegment && other.text == text;
  @override
  int get hashCode => text.hashCode;
  @override
  String toString() => 'Text($text)';
}

/// Formule : `$…$` (dans le texte) ou `$$…$$` (centrée, à part).
final class FormulaSegment extends MathSegment {
  const FormulaSegment(this.tex, {required this.display});
  final String tex;
  final bool display;
  @override
  bool operator ==(Object other) =>
      other is FormulaSegment && other.tex == tex && other.display == display;
  @override
  int get hashCode => Object.hash(tex, display);
  @override
  String toString() => '${display ? 'Display' : 'Inline'}($tex)';
}

/// Découpe un texte en morceaux : `$$…$$`, `$…$`, `\$` (dollar littéral).
/// Un `$` non refermé est gardé tel quel.
List<MathSegment> parseMath(String source) {
  final segments = <MathSegment>[];
  final text = StringBuffer();
  void flushText() {
    if (text.isNotEmpty) {
      segments.add(TextSegment(text.toString()));
      text.clear();
    }
  }

  var i = 0;
  while (i < source.length) {
    final c = source[i];
    if (c == r'\' && i + 1 < source.length && source[i + 1] == r'$') {
      text.write(r'$');
      i += 2;
      continue;
    }
    if (c == r'$') {
      final display = source.startsWith(r'$$', i);
      final open = display ? 2 : 1;
      final close = _findClosing(source, i + open, display);
      if (close != -1) {
        final tex = source.substring(i + open, close).trim();
        if (tex.isNotEmpty) {
          flushText();
          segments.add(FormulaSegment(tex, display: display));
        }
        i = close + open;
        continue;
      }
    }
    text.write(c);
    i++;
  }
  flushText();
  return segments;
}

int _findClosing(String s, int from, bool display) {
  for (var j = from; j < s.length; j++) {
    if (s[j] == r'\') {
      j++; // caractère échappé dans la formule (ex. \$)
      continue;
    }
    if (s[j] != r'$') continue;
    if (!display) return j;
    if (j + 1 < s.length && s[j + 1] == r'$') return j;
  }
  return -1;
}

/// Affiche un texte contenant des formules LaTeX.
class MathText extends StatelessWidget {
  const MathText(this.source, {super.key, this.style});

  final String source;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = this.style ?? theme.textTheme.bodyLarge!;
    final blocks = <Widget>[];
    var inline = <InlineSpan>[];

    void flushInline() {
      if (inline.isEmpty) return;
      blocks.add(Text.rich(TextSpan(children: inline), style: style));
      inline = [];
    }

    for (final segment in parseMath(source)) {
      switch (segment) {
        case TextSegment(:final text):
          var t = text;
          if (inline.isEmpty && blocks.isNotEmpty) {
            t = t.replaceFirst(RegExp(r'^[ \t]*\n'), '');
          }
          if (t.isNotEmpty) inline.add(TextSpan(text: t));
        case FormulaSegment(:final tex, display: false):
          // Sur la ligne de base du texte (flutter_math donne celle de la
          // formule) : centrée, une formule sans descendante paraissait
          // surélevée.
          inline.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: DryBaseline(
                child: _formula(tex, MathStyle.text, style, theme),
              ),
            ),
          );
        case FormulaSegment(:final tex, display: true):
          if (inline.isNotEmpty && inline.last is TextSpan) {
            final last = inline.removeLast() as TextSpan;
            final trimmed = last.text!.replaceFirst(RegExp(r'\n[ \t]*$'), '');
            if (trimmed.isNotEmpty) inline.add(TextSpan(text: trimmed));
          }
          flushInline();
          blocks.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _formula(tex, MathStyle.display, style, theme),
                ),
              ),
            ),
          );
      }
    }
    flushInline();
    if (blocks.length == 1) return blocks.single;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  static Widget _formula(
    String tex,
    MathStyle mathStyle,
    TextStyle style,
    ThemeData theme,
  ) {
    return Math.tex(
      tex,
      mathStyle: mathStyle,
      textStyle: style,
      onErrorFallback: (error) => Tooltip(
        message: error.message,
        child: Text(
          '\$$tex\$',
          style: style.copyWith(
            color: theme.colorScheme.error,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}

/// Donne une ligne de base « à sec » à une formule. Posée sur la ligne de
/// base du texte, elle est interrogée pendant les mesures intrinsèques
/// (puce, largeur intrinsèque, titre de dialogue) ; or flutter_math ne sait
/// pas la calculer sans mise en page (erreur en debug, ligne de base nulle
/// en release). On reprend celle de la dernière mise en page pour les mêmes
/// contraintes, sinon on l'estime au bas de la formule.
class DryBaseline extends SingleChildRenderObjectWidget {
  const DryBaseline({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderDryBaseline();
}

class _RenderDryBaseline extends RenderProxyBox {
  BoxConstraints? _laidOutWith;
  final _baselines = <TextBaseline, double?>{};

  @override
  void performLayout() {
    super.performLayout();
    _laidOutWith = constraints;
    _baselines.clear();
    final child = this.child;
    if (child == null) return;
    for (final baseline in TextBaseline.values) {
      _baselines[baseline] = child.getDistanceToBaseline(
        baseline,
        onlyReal: true,
      );
    }
  }

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    if (child == null) return null;
    if (constraints == _laidOutWith && _baselines[baseline] != null) {
      return _baselines[baseline];
    }
    return child.getDryLayout(constraints).height;
  }
}
