import 'dart:math';

/// Cryptographically-random password generator.
class PasswordGenerator {
  static const _lower = 'abcdefghijkmnopqrstuvwxyz';
  static const _lowerAll = 'abcdefghijklmnopqrstuvwxyz';
  static const _upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const _upperAll = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _digits = '23456789';
  static const _digitsAll = '0123456789';
  static const _symbols = '!@#\$%^&*()-_=+[]{};:,.?/';

  static String generate({
    int length = 16,
    bool upper = true,
    bool lower = true,
    bool digits = true,
    bool symbols = true,
    bool avoidAmbiguous = true,
  }) {
    final rng = Random.secure();
    final pools = <String>[
      if (lower) avoidAmbiguous ? _lower : _lowerAll,
      if (upper) avoidAmbiguous ? _upper : _upperAll,
      if (digits) avoidAmbiguous ? _digits : _digitsAll,
      if (symbols) _symbols,
    ];
    if (pools.isEmpty) pools.add(_lowerAll);

    final len = max(length, pools.length);
    final chars = <String>[];
    for (final pool in pools) {
      chars.add(pool[rng.nextInt(pool.length)]);
    }
    final combined = pools.join();
    while (chars.length < len) {
      chars.add(combined[rng.nextInt(combined.length)]);
    }
    chars.shuffle(rng);
    return chars.join();
  }
}
