class OdometerValue {
  const OdometerValue._();

  static String adjustDigit({
    required String value,
    required int digitIndex,
    required int delta,
  }) {
    if (value.isEmpty || digitIndex < 0 || digitIndex >= value.length) {
      throw ArgumentError('Digit index must be within the odometer value.');
    }

    final placeValue = _powerOfTen(value.length - digitIndex - 1);
    final maximum = int.parse('9' * value.length);
    final nextValue = (int.parse(value) + delta * placeValue).clamp(0, maximum);
    return nextValue.toString().padLeft(value.length, '0');
  }

  static int _powerOfTen(int exponent) {
    var result = 1;
    for (var index = 0; index < exponent; index++) {
      result *= 10;
    }
    return result;
  }
}
