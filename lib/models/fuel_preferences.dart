/// Suggestions only. Historical receipt values always live on FuelEntry.
class FuelPreferences {
  const FuelPreferences({this.usualGrade = 92, this.prices = const {}});
  final int usualGrade;
  final Map<int, double> prices;

  void validate() {
    if (![92, 95].contains(usualGrade) ||
        prices.entries.any(
          (e) => ![92, 95].contains(e.key) || !e.value.isFinite || e.value <= 0,
        )) {
      throw const FormatException('Invalid fuel preferences');
    }
  }

  Map<String, dynamic> toJson() => {
    'usualGrade': usualGrade,
    'prices': {for (final e in prices.entries) '${e.key}': e.value},
  };
  factory FuelPreferences.fromJson(Map<String, dynamic> json) {
    final raw = json['prices'] as Map? ?? {};
    final value = FuelPreferences(
      usualGrade: json['usualGrade'] as int? ?? 92,
      prices: Map.unmodifiable(
        raw.map(
          (k, v) => MapEntry(int.parse(k as String), (v as num).toDouble()),
        ),
      ),
    );
    value.validate();
    return value;
  }
}
