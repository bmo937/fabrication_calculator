class FractionLookup {
  const FractionLookup(this.label, this.value);

  final String label;
  final double value;
}

const List<FractionLookup> workshopFractions = <FractionLookup>[
  FractionLookup('1/16', 1 / 16),
  FractionLookup('1/8', 1 / 8),
  FractionLookup('3/16', 3 / 16),
  FractionLookup('1/4', 1 / 4),
  FractionLookup('5/16', 5 / 16),
  FractionLookup('3/8', 3 / 8),
  FractionLookup('7/16', 7 / 16),
  FractionLookup('1/2', 1 / 2),
  FractionLookup('9/16', 9 / 16),
  FractionLookup('5/8', 5 / 8),
  FractionLookup('11/16', 11 / 16),
  FractionLookup('3/4', 3 / 4),
  FractionLookup('13/16', 13 / 16),
  FractionLookup('7/8', 7 / 8),
  FractionLookup('15/16', 15 / 16),
  FractionLookup('1', 1),
];

double millimetersToInches(double millimeters) => millimeters / 25.4;

double inchesToMillimeters(double inches) => inches * 25.4;

double fractionToDecimalInches(String fraction) {
  final String clean = fraction.trim();
  final List<String> parts = clean.split('/');
  if (parts.length != 2) {
    throw const FormatException('Fraction must be in n/d format.');
  }

  final double? numerator = double.tryParse(parts[0]);
  final double? denominator = double.tryParse(parts[1]);
  if (numerator == null || denominator == null || denominator == 0) {
    throw const FormatException('Invalid fraction value.');
  }

  return numerator / denominator;
}

FractionLookup decimalInchesToNearestFraction(double decimalInches) {
  FractionLookup nearest = workshopFractions.first;
  double smallestDiff = (decimalInches - nearest.value).abs();

  for (final FractionLookup fraction in workshopFractions.skip(1)) {
    final double diff = (decimalInches - fraction.value).abs();
    if (diff < smallestDiff) {
      smallestDiff = diff;
      nearest = fraction;
    }
  }

  return nearest;
}
