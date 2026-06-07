typedef ConversionFormula = double Function(double input);

class ConverterFormula {
  const ConverterFormula({required this.name, required this.inputLabel, required this.outputLabel, required this.formula});

  final String name;
  final String inputLabel;
  final String outputLabel;
  final ConversionFormula formula;
}
