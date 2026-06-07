import 'package:fabrication_calculator/calculators/unit_converter_formulas.dart';
import 'package:fabrication_calculator/models/converter_formula.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UnitConverterState {
  const UnitConverterState({required this.selectedFormula, required this.inputText, required this.result, required this.resultLabel, required this.errorMessage});

  factory UnitConverterState.initial() {
    return UnitConverterState(selectedFormula: unitConverterFormulas.first, inputText: '', result: null, resultLabel: null, errorMessage: null);
  }

  final ConverterFormula selectedFormula;
  final String inputText;
  final double? result;
  final String? resultLabel;
  final String? errorMessage;

  UnitConverterState copyWith({
    ConverterFormula? selectedFormula,
    String? inputText,
    double? result,
    bool clearResult = false,
    String? resultLabel,
    bool clearResultLabel = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UnitConverterState(
      selectedFormula: selectedFormula ?? this.selectedFormula,
      inputText: inputText ?? this.inputText,
      result: clearResult ? null : (result ?? this.result),
      resultLabel: clearResultLabel ? null : (resultLabel ?? this.resultLabel),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final unitConverterProvider = NotifierProvider<UnitConverterNotifier, UnitConverterState>(UnitConverterNotifier.new);

class UnitConverterNotifier extends Notifier<UnitConverterState> {
  @override
  UnitConverterState build() => UnitConverterState.initial();

  void setFormula(ConverterFormula formula) {
    state = state.copyWith(selectedFormula: formula, clearResult: true, clearResultLabel: true, clearError: true);
  }

  void setInputText(String text) {
    state = state.copyWith(inputText: text, clearError: true);
  }

  void calculate() {
    final double? input = double.tryParse(state.inputText);
    if (input == null) {
      state = state.copyWith(errorMessage: 'Enter a valid number.', clearResult: true, clearResultLabel: true);
      return;
    }

    final double output = state.selectedFormula.formula(input);
    state = state.copyWith(result: output, resultLabel: null, clearError: true);
  }

  void clear() {
    state = UnitConverterState.initial();
  }

  Map<String, double>? currentInputsForHistory() {
    final double? input = double.tryParse(state.inputText);
    if (input == null || state.result == null) {
      return null;
    }

    return <String, double>{state.selectedFormula.inputLabel: input};
  }
}
