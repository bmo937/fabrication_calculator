import 'package:fabrication_calculator/calculators/measurement_utils.dart';
import 'package:fabrication_calculator/models/converter_formula.dart';

final List<ConverterFormula> unitConverterFormulas = <ConverterFormula>[
  ConverterFormula(name: 'Millimeters to Inches', inputLabel: 'Millimeters (mm)', outputLabel: 'Inches (in)', formula: millimetersToInches),
  ConverterFormula(name: 'Inches to Millimeters', inputLabel: 'Inches (in)', outputLabel: 'Millimeters (mm)', formula: inchesToMillimeters),
  ConverterFormula(
    name: 'Decimal Inches to Nearest Fraction',
    inputLabel: 'Decimal Inches (in)',
    outputLabel: 'Nearest Fraction (decimal in)',
    formula: _decimalInchesToNearestFractionValue,
  ),
];

double _decimalInchesToNearestFractionValue(double value) {
  return decimalInchesToNearestFraction(value).value;
}
