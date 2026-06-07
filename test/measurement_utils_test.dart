import 'package:fabrication_calculator/calculators/measurement_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('measurement conversions', () {
    test('millimeters to inches', () {
      expect(millimetersToInches(25.4), closeTo(1.0, 0.000001));
    });

    test('inches to millimeters', () {
      expect(inchesToMillimeters(1.0), closeTo(25.4, 0.000001));
    });
  });

  group('fraction conversions', () {
    test('fraction string to decimal inches', () {
      expect(fractionToDecimalInches('3/8'), closeTo(0.375, 0.000001));
    });

    test('nearest fraction lookup', () {
      final FractionLookup nearest = decimalInchesToNearestFraction(0.37);
      expect(nearest.label, '3/8');
    });
  });
}
