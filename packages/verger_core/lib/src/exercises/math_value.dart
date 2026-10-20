import 'dart:math' as math;

/// Fraction exacte, toujours réduite, dénominateur strictement positif.
final class Rational implements Comparable<Rational> {
  factory Rational(BigInt numerator, [BigInt? denominator]) {
    var n = numerator, d = denominator ?? BigInt.one;
    if (d == BigInt.zero) throw const EvalError('Division par zéro');
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    final g = n.gcd(d);
    return Rational._(g > BigInt.one ? n ~/ g : n, g > BigInt.one ? d ~/ g : d);
  }

  const Rational._(this.numerator, this.denominator);

  Rational.fromInt(int n) : this._(BigInt.from(n), BigInt.one);

  /// Écriture décimale finie (« 3.25 ») : valeur exacte.
  factory Rational.parseDecimal(String text) {
    final dot = text.indexOf('.');
    if (dot < 0) return Rational(BigInt.parse(text));
    final digits = text.length - dot - 1;
    return Rational(
      BigInt.parse(text.replaceFirst('.', '')),
      BigInt.from(10).pow(digits),
    );
  }

  static final zero = Rational.fromInt(0);
  static final one = Rational.fromInt(1);

  final BigInt numerator;
  final BigInt denominator;

  bool get isInteger => denominator == BigInt.one;
  bool get isNegative => numerator.isNegative;
  bool get isZero => numerator == BigInt.zero;

  Rational operator +(Rational o) => Rational(
    numerator * o.denominator + o.numerator * denominator,
    denominator * o.denominator,
  );
  Rational operator -(Rational o) => Rational(
    numerator * o.denominator - o.numerator * denominator,
    denominator * o.denominator,
  );
  Rational operator *(Rational o) =>
      Rational(numerator * o.numerator, denominator * o.denominator);
  Rational operator /(Rational o) {
    if (o.isZero) throw const EvalError('Division par zéro');
    return Rational(numerator * o.denominator, denominator * o.numerator);
  }

  Rational operator -() => Rational._(-numerator, denominator);
  Rational abs() => isNegative ? -this : this;

  /// Puissance entière (négative : inverse).
  Rational pow(int e) {
    if (e < 0) return one / pow(-e);
    return Rational._(numerator.pow(e), denominator.pow(e));
  }

  double toDouble() => numerator / denominator;

  @override
  int compareTo(Rational o) =>
      (numerator * o.denominator).compareTo(o.numerator * denominator);

  @override
  bool operator ==(Object other) =>
      other is Rational &&
      other.numerator == numerator &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => isInteger ? '$numerator' : '$numerator/$denominator';
}

/// Erreur de calcul (division par zéro, fonction inconnue…), en français.
final class EvalError implements Exception {
  const EvalError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Nombre manipulé par les exercices : exact (fraction) tant que possible,
/// approché (flottant) sinon, par exemple pour une racine non entière.
final class MathValue {
  const MathValue.exact(Rational this.exact) : approx = null;
  const MathValue.approx(double this.approx) : exact = null;

  MathValue.of(int n) : this.exact(Rational.fromInt(n));

  final Rational? exact;
  final double? approx;

  bool get isExact => exact != null;
  double toDouble() => exact?.toDouble() ?? approx!;

  /// Entier exact, sinon `null`.
  int? get asInt {
    final e = exact;
    if (e == null || !e.isInteger) return null;
    return e.numerator.isValidInt ? e.numerator.toInt() : null;
  }

  bool get isTrue => toDouble() != 0;

  static MathValue _fromDouble(double v) {
    if (v.isNaN || v.isInfinite) throw const EvalError('Calcul impossible');
    return MathValue.approx(v);
  }

  MathValue _op(
    MathValue o,
    Rational Function(Rational, Rational) exactOp,
    double Function(double, double) approxOp,
  ) {
    final a = exact, b = o.exact;
    if (a != null && b != null) return MathValue.exact(exactOp(a, b));
    return _fromDouble(approxOp(toDouble(), o.toDouble()));
  }

  MathValue operator +(MathValue o) => _op(o, (a, b) => a + b, (a, b) => a + b);
  MathValue operator -(MathValue o) => _op(o, (a, b) => a - b, (a, b) => a - b);
  MathValue operator *(MathValue o) => _op(o, (a, b) => a * b, (a, b) => a * b);
  MathValue operator /(MathValue o) {
    if (o.toDouble() == 0) throw const EvalError('Division par zéro');
    return _op(o, (a, b) => a / b, (a, b) => a / b);
  }

  MathValue operator -() {
    final e = exact;
    return e != null ? MathValue.exact(-e) : MathValue.approx(-approx!);
  }

  MathValue abs() => toDouble() < 0 ? -this : this;

  MathValue pow(MathValue e) {
    final base = exact, n = e.asInt;
    if (base != null && n != null && n.abs() <= 64) {
      if (base.isZero && n < 0) throw const EvalError('Division par zéro');
      return MathValue.exact(base.pow(n));
    }
    return _fromDouble(_pow(toDouble(), e.toDouble()));
  }

  /// Racine carrée, exacte si la fraction est un carré parfait.
  MathValue sqrt() {
    if (toDouble() < 0) throw const EvalError('Racine d\'un nombre négatif');
    final e = exact;
    if (e != null) {
      final n = _isqrt(e.numerator), d = _isqrt(e.denominator);
      if (n * n == e.numerator && d * d == e.denominator) {
        return MathValue.exact(Rational(n, d));
      }
    }
    return _fromDouble(_sqrt(toDouble()));
  }

  int compareTo(MathValue o) {
    final a = exact, b = o.exact;
    if (a != null && b != null) return a.compareTo(b);
    return toDouble().compareTo(o.toDouble());
  }

  /// Égalité : exacte entre deux valeurs exactes, sinon à [tolerance] près
  /// (par défaut, l'erreur d'arrondi d'un flottant).
  bool sameAs(MathValue o, {double? tolerance}) {
    final a = exact, b = o.exact;
    if (tolerance == null && a != null && b != null) return a == b;
    final x = toDouble(), y = o.toDouble();
    final tol = tolerance ?? 1e-9 * [1.0, x.abs(), y.abs()].reduce(_max);
    return (x - y).abs() <= tol;
  }

  @override
  String toString() => exact?.toString() ?? '$approx';
}

double _max(double a, double b) => a > b ? a : b;

BigInt _isqrt(BigInt n) {
  if (n < BigInt.two) return n;
  var x = BigInt.from(_sqrt(n.toDouble()));
  // Ajustement : la racine flottante peut être décalée d'une unité.
  while (x * x > n) {
    x -= BigInt.one;
  }
  while ((x + BigInt.one) * (x + BigInt.one) <= n) {
    x += BigInt.one;
  }
  return x;
}

double _sqrt(double x) => x <= 0 ? 0 : math.sqrt(x);

double _pow(double base, double exponent) {
  final r = math.pow(base, exponent).toDouble();
  if (r.isNaN) throw const EvalError('Puissance impossible');
  return r;
}
