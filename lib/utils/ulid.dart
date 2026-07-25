import 'dart:math';

class Ulid {
  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static final Random _rng = Random.secure();

  static String generate({DateTime? at}) {
    final ms = (at ?? DateTime.now()).millisecondsSinceEpoch;
    final bytes = List<int>.filled(16, 0);

    var time = ms;
    for (var i = 5; i >= 0; i--) {
      bytes[i] = time & 0xff;
      time >>= 8;
    }

    for (var i = 6; i < 16; i++) {
      bytes[i] = _rng.nextInt(256);
    }

    return _encode(bytes);
  }

  static String _encode(List<int> bytes) {
    var value = BigInt.zero;
    for (final b in bytes) {
      value = (value << 8) | BigInt.from(b);
    }

    final out = List<String>.filled(26, '0');
    for (var i = 25; i >= 0; i--) {
      final idx = (value & BigInt.from(31)).toInt();
      out[i] = _alphabet[idx];
      value = value >> 5;
    }
    return out.join();
  }
}
