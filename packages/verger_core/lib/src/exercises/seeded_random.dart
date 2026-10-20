/// Générateur pseudo-aléatoire déterministe (mulberry32), identique sur
/// toutes les plateformes, web compris : une même graine redonne le même
/// exercice (fiche réimprimée, correction).
final class SeededRandom {
  SeededRandom(int seed) : _state = seed & 0xFFFFFFFF;

  /// Graine tirée d'un texte (identifiant d'élève, de séance…).
  SeededRandom.fromString(String text) : this(hashString(text));

  int _state;

  /// Entier sur 32 bits, non signé.
  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t ^= (t + _imul(t ^ (t >>> 7), t | 61)) & 0xFFFFFFFF;
    return (t ^ (t >>> 14)) & 0xFFFFFFFF;
  }

  /// Entier dans [min, max], bornes comprises.
  int nextInt(int min, int max) {
    if (max < min) throw ArgumentError('max < min');
    final span = max - min + 1;
    return min + nextUint32() % span;
  }

  /// Mélange [list] sur place (Fisher-Yates).
  void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(0, i);
      final t = list[i];
      list[i] = list[j];
      list[j] = t;
    }
  }

  /// FNV-1a sur 32 bits.
  static int hashString(String text) {
    var h = 0x811C9DC5;
    for (final unit in text.codeUnits) {
      h = _imul(h ^ unit, 0x01000193);
    }
    return h;
  }

  /// Produit de deux entiers sur 32 bits, modulo 2^32, sans dépasser la
  /// précision des nombres du web (53 bits).
  static int _imul(int a, int b) {
    a &= 0xFFFFFFFF;
    b &= 0xFFFFFFFF;
    final aHi = a >>> 16, aLo = a & 0xFFFF;
    final lo = aLo * b;
    final hi = (aHi * b) & 0xFFFF;
    return (lo + (hi << 16)) & 0xFFFFFFFF;
  }
}
