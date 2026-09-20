final class SeededRandom {
  SeededRandom(int seed) : _state = _normalize(seed);

  SeededRandom.fromState(int state) : _state = _normalize(state);

  int _state;

  int get state => _state;

  int nextUint32() {
    var value = _state;
    value ^= (value << 13) & 0xffffffff;
    value ^= value >>> 17;
    value ^= (value << 5) & 0xffffffff;
    return _state = value & 0xffffffff;
  }

  int nextInt(int max) {
    if (max <= 0) {
      throw RangeError.range(max, 1, null, 'max');
    }
    return nextUint32() % max;
  }

  static int _normalize(int seed) {
    final normalized = seed & 0xffffffff;
    return normalized == 0 ? 0x6d2b79f5 : normalized;
  }
}
