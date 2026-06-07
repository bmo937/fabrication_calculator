import 'package:fabrication_calculator/calculators/converter_widget.dart';
import 'package:fabrication_calculator/calculators/measurement_utils.dart';
import 'package:fabrication_calculator/calculators/unit_converter_formulas.dart';
import 'package:fabrication_calculator/models/converter_formula.dart';
import 'package:fabrication_calculator/models/history_entry.dart';
import 'package:fabrication_calculator/providers/history_providers.dart';
import 'package:fabrication_calculator/providers/unit_converter_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UnitConverterCalculator extends ConsumerStatefulWidget {
  const UnitConverterCalculator({super.key});

  static const String calculatorId = 'unit_converter';
  static const String calculatorName = 'Unit Converter';

  @override
  ConsumerState<UnitConverterCalculator> createState() => _UnitConverterCalculatorState();
}

class _UnitConverterCalculatorState extends ConsumerState<UnitConverterCalculator> {
  late final TextEditingController _inputController;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UnitConverterState converterState = ref.watch(unitConverterProvider);
    final UnitConverterNotifier converterNotifier = ref.read(unitConverterProvider.notifier);
    final List<HistoryEntry> history = ref.watch(historyControllerProvider).valueOrNull ?? <HistoryEntry>[];

    if (_inputController.text != converterState.inputText) {
      _inputController.value = TextEditingValue(
        text: converterState.inputText,
        selection: TextSelection.fromPosition(TextPosition(offset: converterState.inputText.length)),
      );
    }

    final String resultText = _buildResultText(converterState);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: DropdownButtonFormField<ConverterFormula>(
            initialValue: converterState.selectedFormula,
            decoration: const InputDecoration(labelText: 'Conversion', border: OutlineInputBorder()),
            items: unitConverterFormulas.map((ConverterFormula formula) => DropdownMenuItem<ConverterFormula>(value: formula, child: Text(formula.name))).toList(),
            onChanged: (ConverterFormula? formula) {
              if (formula == null) {
                return;
              }
              converterNotifier.setFormula(formula);
            },
          ),
        ),
        ConverterWidget(
          formula: converterState.selectedFormula,
          controller: _inputController,
          onInputChanged: converterNotifier.setInputText,
          onCalculate: () async {
            converterNotifier.calculate();
            final UnitConverterState newState = ref.read(unitConverterProvider);
            if (newState.result == null) {
              return;
            }

            final Map<String, double>? inputs = converterNotifier.currentInputsForHistory();
            if (inputs == null) {
              return;
            }

            await ref
                .read(historyControllerProvider.notifier)
                .saveEntry(HistoryEntry(calculatorName: UnitConverterCalculator.calculatorName, inputs: inputs, result: newState.result!, timestamp: DateTime.now()));
          },
          onClear: () {
            converterNotifier.clear();
            _inputController.clear();
          },
          resultText: resultText,
          errorText: converterState.errorMessage,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Recent History', style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final HistoryEntry entry in history.take(5))
          ListTile(
            dense: true,
            title: Text(entry.inputs.entries.first.value.toStringAsFixed(2)),
            subtitle: Text(entry.timestamp.toLocal().toString()),
            trailing: Text(entry.result.toStringAsFixed(2)),
          ),
      ],
    );
  }

  String _buildResultText(UnitConverterState state) {
    if (state.result == null) {
      return '--';
    }

    final String value = state.result!.toStringAsFixed(2);
    if (state.selectedFormula.name == 'Decimal Inches to Nearest Fraction') {
      final FractionLookup nearest = decimalInchesToNearestFraction(state.result!);
      return '$value (${nearest.label})';
    }
    return value;
  }
}
