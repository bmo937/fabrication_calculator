import 'package:fabrication_calculator/models/converter_formula.dart';
import 'package:flutter/material.dart';

class ConverterWidget extends StatelessWidget {
  const ConverterWidget({
    required this.formula,
    required this.controller,
    required this.onInputChanged,
    required this.onCalculate,
    required this.onClear,
    required this.resultText,
    required this.errorText,
    super.key,
  });

  final ConverterFormula formula;
  final TextEditingController controller;
  final ValueChanged<String> onInputChanged;
  final VoidCallback onCalculate;
  final VoidCallback onClear;
  final String resultText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(formula.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: onInputChanged,
              decoration: InputDecoration(labelText: formula.inputLabel, border: const OutlineInputBorder(), errorText: errorText),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                ElevatedButton(onPressed: onCalculate, child: const Text('Calculate')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ),
            const SizedBox(height: 12),
            Text('Result: $resultText', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('Output Unit: ${formula.outputLabel}'),
          ],
        ),
      ),
    );
  }
}
