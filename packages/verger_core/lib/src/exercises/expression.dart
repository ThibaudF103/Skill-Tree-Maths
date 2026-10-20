import 'math_value.dart';

/// Expression compilée : se calcule pour des valeurs de variables données.
typedef Evaluator = MathValue Function(Map<String, MathValue> env);

/// Expression mathématique d'un exercice : nombres, variables, `+ - * / ^`,
/// parenthèses, fonctions (`abs`, `sqrt`, `min`, `max`,
/// `si(condition, alors, sinon)`), comparaisons
/// (`== != < <= > >=`, valant 1 ou 0) et `&&`, `||`. La multiplication peut
/// être sous-entendue (`2x`, `3(a+1)`, `2sqrt(3)`). Les signes usuels
/// (`×`, `÷`, `−`, `·`) sont acceptés.
final class MathExpression {
  MathExpression._(this.source, this._eval, this.variables);

  /// Lit [source] ; [FormatException] (en français) si elle est mal formée.
  /// [decimalComma] : la virgule est un séparateur décimal (réponse d'un
  /// élève), et non un séparateur d'arguments.
  factory MathExpression.parse(String source, {bool decimalComma = false}) {
    final parser = _Parser(_tokenize(source, decimalComma: decimalComma));
    final variables = <String>{};
    final eval = parser.parse(variables);
    return MathExpression._(source, eval, variables);
  }

  final String source;
  final Evaluator _eval;

  /// Variables utilisées.
  final Set<String> variables;

  MathValue evaluate([Map<String, MathValue> env = const {}]) => _eval(env);
}

enum _Kind { number, name, op, open, close, comma, end }

typedef _Token = ({_Kind kind, String text, int at});

List<_Token> _tokenize(String source, {required bool decimalComma}) {
  final tokens = <_Token>[];
  final s = source
      .replaceAll('×', '*')
      .replaceAll('·', '*')
      .replaceAll('÷', '/')
      .replaceAll('−', '-')
      .replaceAll('–', '-');
  var i = 0;
  bool isDigit(String c) {
    final u = c.codeUnitAt(0);
    return u >= 0x30 && u <= 0x39;
  }

  bool isLetter(String c) => RegExp(r'[A-Za-z_À-ɏ]').hasMatch(c);
  while (i < s.length) {
    final c = s[i];
    if (c.trim().isEmpty) {
      i++;
      continue;
    }
    final start = i;
    if (isDigit(c) ||
        ((c == '.' || (decimalComma && c == ',')) &&
            i + 1 < s.length &&
            isDigit(s[i + 1]))) {
      var seenDot = false;
      final buf = StringBuffer();
      while (i < s.length) {
        final d = s[i];
        if (isDigit(d)) {
          buf.write(d);
        } else if ((d == '.' || (decimalComma && d == ',')) && !seenDot) {
          seenDot = true;
          buf.write('.');
        } else {
          break;
        }
        i++;
      }
      tokens.add((kind: _Kind.number, text: buf.toString(), at: start));
      continue;
    }
    if (isLetter(c)) {
      while (i < s.length && (isLetter(s[i]) || isDigit(s[i]))) {
        i++;
      }
      tokens.add((kind: _Kind.name, text: s.substring(start, i), at: start));
      continue;
    }
    const twoChars = ['==', '!=', '<=', '>=', '&&', '||'];
    if (i + 1 < s.length && twoChars.contains(s.substring(i, i + 2))) {
      tokens.add((kind: _Kind.op, text: s.substring(i, i + 2), at: start));
      i += 2;
      continue;
    }
    final kind = switch (c) {
      '+' || '-' || '*' || '/' || '^' || '<' || '>' => _Kind.op,
      '(' => _Kind.open,
      ')' => _Kind.close,
      ',' => _Kind.comma,
      _ => throw FormatException('Caractère inattendu « $c »', source, i),
    };
    tokens.add((kind: kind, text: c, at: start));
    i++;
  }
  tokens.add((kind: _Kind.end, text: '', at: s.length));
  return tokens;
}

const _functions = {
  'abs': 1,
  'sqrt': 1,
  'racine': 1,
  'min': 2,
  'max': 2,
  'si': 3,
};

final class _Parser {
  _Parser(this.tokens);

  final List<_Token> tokens;
  var _i = 0;
  late Set<String> _vars;

  _Token get _peek => tokens[_i];
  _Token _next() => tokens[_i++];

  bool _isOp(String text) => _peek.kind == _Kind.op && _peek.text == text;

  Never _fail(String message) => throw FormatException(message, null, _peek.at);

  Evaluator parse(Set<String> vars) {
    _vars = vars;
    final e = _or();
    if (_peek.kind != _Kind.end) _fail('« ${_peek.text} » inattendu');
    return e;
  }

  Evaluator _binary(
    Evaluator Function() operand,
    Map<String, MathValue Function(MathValue, MathValue)> ops,
  ) {
    var left = operand();
    while (_peek.kind == _Kind.op && ops.containsKey(_peek.text)) {
      final op = ops[_next().text]!;
      final l = left, r = operand();
      left = (env) => op(l(env), r(env));
    }
    return left;
  }

  static MathValue _bool(bool b) => MathValue.of(b ? 1 : 0);

  Evaluator _or() =>
      _binary(_and, {'||': (a, b) => _bool(a.isTrue || b.isTrue)});

  Evaluator _and() =>
      _binary(_comparison, {'&&': (a, b) => _bool(a.isTrue && b.isTrue)});

  Evaluator _comparison() => _binary(_sum, {
    '==': (a, b) => _bool(a.sameAs(b)),
    '!=': (a, b) => _bool(!a.sameAs(b)),
    '<': (a, b) => _bool(a.compareTo(b) < 0),
    '<=': (a, b) => _bool(a.compareTo(b) <= 0),
    '>': (a, b) => _bool(a.compareTo(b) > 0),
    '>=': (a, b) => _bool(a.compareTo(b) >= 0),
  });

  Evaluator _sum() =>
      _binary(_product, {'+': (a, b) => a + b, '-': (a, b) => a - b});

  /// Produit, y compris sous-entendu : `2x`, `3(a+1)`, `(a)(b)`.
  Evaluator _product() {
    var left = _unary();
    while (true) {
      if (_isOp('*') || _isOp('/')) {
        final div = _next().text == '/';
        final l = left, r = _unary();
        left = div ? (env) => l(env) / r(env) : (env) => l(env) * r(env);
      } else if (_peek.kind == _Kind.name ||
          _peek.kind == _Kind.open ||
          _peek.kind == _Kind.number) {
        final l = left, r = _power();
        left = (env) => l(env) * r(env);
      } else {
        return left;
      }
    }
  }

  Evaluator _unary() {
    if (_isOp('-')) {
      _next();
      final e = _unary();
      return (env) => -e(env);
    }
    if (_isOp('+')) {
      _next();
      return _unary();
    }
    return _power();
  }

  /// Puissance, associative à droite ; `-2^2` vaut -4.
  Evaluator _power() {
    final base = _atom();
    if (!_isOp('^')) return base;
    _next();
    final exponent = _unary();
    return (env) => base(env).pow(exponent(env));
  }

  Evaluator _atom() {
    final t = _next();
    switch (t.kind) {
      case _Kind.number:
        final v = MathValue.exact(Rational.parseDecimal(t.text));
        return (_) => v;
      case _Kind.open:
        final e = _or();
        _close();
        return e;
      case _Kind.name:
        final arity = _functions[t.text];
        if (arity != null && _peek.kind == _Kind.open) {
          _next();
          final args = <Evaluator>[_or()];
          while (_peek.kind == _Kind.comma) {
            _next();
            args.add(_or());
          }
          _close();
          if (args.length != arity) {
            throw FormatException(
              '« ${t.text} » attend $arity argument${arity > 1 ? 's' : ''}',
              null,
              t.at,
            );
          }
          return _call(t.text, args);
        }
        final name = t.text;
        _vars.add(name);
        return (env) =>
            env[name] ?? (throw EvalError('Variable inconnue « $name »'));
      default:
        _i--;
        _fail(
          t.kind == _Kind.end
              ? 'MathExpression incomplète'
              : '« ${t.text} » inattendu',
        );
    }
  }

  void _close() {
    if (_peek.kind != _Kind.close) _fail('Parenthèse non fermée');
    _next();
  }

  Evaluator _call(String name, List<Evaluator> args) {
    final a = args.first;
    return switch (name) {
      'abs' => (env) => a(env).abs(),
      'sqrt' || 'racine' => (env) => a(env).sqrt(),
      'si' => (env) => a(env).isTrue ? args[1](env) : args[2](env),
      'min' => (env) {
        final x = a(env), y = args[1](env);
        return x.compareTo(y) <= 0 ? x : y;
      },
      _ => (env) {
        final x = a(env), y = args[1](env);
        return x.compareTo(y) >= 0 ? x : y;
      },
    };
  }
}
