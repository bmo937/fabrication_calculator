import 'package:fabrication_calculator/models/calculator_field_definition.dart';
import 'package:fabrication_calculator/models/formula_icon_option.dart';
import 'package:fabrication_calculator/models/history_entry.dart';
import 'package:fabrication_calculator/models/lookup_entry.dart';
import 'package:fabrication_calculator/models/managed_calculator.dart';
import 'package:fabrication_calculator/providers/history_providers.dart';
import 'package:fabrication_calculator/services/calculator_code_sandbox.dart';
import 'package:fabrication_calculator/services/formula_evaluator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ManagedCalculatorPage extends ConsumerStatefulWidget {
  const ManagedCalculatorPage({required this.calculator, super.key});

  final ManagedCalculator calculator;

  @override
  ConsumerState<ManagedCalculatorPage> createState() => _ManagedCalculatorPageState();
}

class _ManagedCalculatorPageState extends ConsumerState<ManagedCalculatorPage> {
  late final Map<String, TextEditingController> _inputControllers;
  final Map<String, double> _codeOutputs = <String, double>{};
  double? _legacyResult;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _inputControllers = <String, TextEditingController>{for (final CalculatorFieldDefinition input in widget.calculator.inputDefinitions) input.key: TextEditingController()};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(historyControllerProvider.notifier).loadForCalculator(widget.calculator.name);
      }
    });
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _inputControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _calculate() {
    if (widget.calculator.calculatorType == 'code') {
      _calculateCode();
      return;
    }
    _calculateLegacy();
  }

  void _clear() {
    setState(() {
      _legacyResult = null;
      _codeOutputs.clear();
      _errorText = null;
    });
    for (final TextEditingController controller in _inputControllers.values) {
      controller.clear();
    }
  }

  void _calculateLegacy() {
    final TextEditingController? firstController = _inputControllers.values.firstOrNull;
    final double? inputValue = double.tryParse(firstController?.text.trim() ?? '');

    if (inputValue == null) {
      setState(() {
        _legacyResult = null;
        _errorText = 'Enter a valid number';
      });
      return;
    }

    double? result;

    if (widget.calculator.calculatorType == 'formula') {
      final String? expr = widget.calculator.formulaExpression;
      if (expr == null || expr.isEmpty) {
        setState(() {
          _legacyResult = null;
          _errorText = 'No formula configured';
        });
        return;
      }
      result = FormulaEvaluator.evaluate(expr, x: inputValue);
      if (result == null) {
        setState(() {
          _legacyResult = null;
          _errorText = 'Could not evaluate formula';
        });
        return;
      }
    } else {
      final String? json = widget.calculator.lookupEntriesJson;
      if (json == null || json.isEmpty) {
        setState(() {
          _legacyResult = null;
          _errorText = 'No lookup table configured';
        });
        return;
      }
      final List<LookupEntry> entries = LookupEntry.listFromJson(json);
      result = LookupEntry.interpolate(entries, inputValue);
      if (result == null) {
        setState(() {
          _legacyResult = null;
          _errorText = 'Value not found in table';
        });
        return;
      }
    }

    setState(() {
      _legacyResult = result;
      _errorText = null;
      _codeOutputs.clear();
    });

    ref
        .read(historyControllerProvider.notifier)
        .saveEntry(
          HistoryEntry(calculatorName: widget.calculator.name, inputs: <String, double>{widget.calculator.inputLabel: inputValue}, result: result, timestamp: DateTime.now()),
        );
  }

  void _calculateCode() {
    if (!CalculatorCodeSandbox.supportsAutomaticSandbox(widget.calculator.codeLanguage)) {
      setState(() {
        _errorText = 'Runtime execution is not available yet for ${widget.calculator.codeLanguage}. This calculator is currently authoring-only.';
        _codeOutputs.clear();
        _legacyResult = null;
      });
      return;
    }

    final List<CalculatorFieldDefinition> inputs = widget.calculator.inputDefinitions;
    final List<CalculatorFieldDefinition> outputs = widget.calculator.outputDefinitions;

    final Map<String, double> inputValues = <String, double>{};
    for (final CalculatorFieldDefinition input in inputs) {
      final TextEditingController? controller = _inputControllers[input.key];
      final double? value = double.tryParse(controller?.text.trim() ?? '');
      if (value == null) {
        setState(() {
          _errorText = 'Enter a valid number for ${input.label}';
          _codeOutputs.clear();
          _legacyResult = null;
        });
        return;
      }
      inputValues[input.key] = value;
    }

    final SandboxExecutionResult execution = CalculatorCodeSandbox.execute(
      codeBody: widget.calculator.codeBody,
      inputs: inputs,
      outputs: outputs,
      inputValues: inputValues,
      codeLanguage: widget.calculator.codeLanguage,
    );

    if (!execution.success) {
      setState(() {
        _errorText = execution.error ?? 'Execution failed.';
        _codeOutputs.clear();
        _legacyResult = null;
      });
      return;
    }

    setState(() {
      _errorText = null;
      _legacyResult = null;
      _codeOutputs
        ..clear()
        ..addAll(execution.outputs);
    });

    final double primaryResult = execution.outputs[outputs.first.key] ?? 0;
    ref
        .read(historyControllerProvider.notifier)
        .saveEntry(HistoryEntry(calculatorName: widget.calculator.name, inputs: inputValues, result: primaryResult, timestamp: DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final List<HistoryEntry> history = ref.watch(historyControllerProvider).valueOrNull ?? <HistoryEntry>[];
    final FormulaIconOption iconOption = formulaIconByKey(widget.calculator.iconKey);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Text(iconOption.glyph, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.calculator.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (widget.calculator.description.isNotEmpty) ...<Widget>[
                    Text(widget.calculator.description, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                  ],
                  for (final CalculatorFieldDefinition input in widget.calculator.inputDefinitions) ...<Widget>[
                    TextField(
                      controller: _inputControllers[input.key],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: InputDecoration(labelText: input.label, border: const OutlineInputBorder(), errorText: _errorText),
                      onSubmitted: (_) => _calculate(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (widget.calculator.calculatorType == 'code' && !CalculatorCodeSandbox.supportsAutomaticSandbox(widget.calculator.codeLanguage)) ...<Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Runtime execution unavailable for ${widget.calculator.codeLanguage}', style: Theme.of(context).textTheme.labelLarge),
                            const SizedBox(height: 8),
                            SelectableText(widget.calculator.codeBody, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      ElevatedButton(onPressed: _calculate, child: const Text('Calculate')),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: _clear, child: const Text('Clear')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (widget.calculator.calculatorType == 'code')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final CalculatorFieldDefinition output in widget.calculator.outputDefinitions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: <Widget>[
                                Text('${output.label}:  ', style: Theme.of(context).textTheme.titleSmall),
                                Text(
                                  _codeOutputs.containsKey(output.key) ? (_codeOutputs[output.key]!.toStringAsPrecision(10)) : '--',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    )
                  else
                    Row(
                      children: <Widget>[
                        Text('${widget.calculator.outputLabel}:  ', style: Theme.of(context).textTheme.titleSmall),
                        Text(
                          _legacyResult != null ? _legacyResult!.toStringAsFixed(4) : '--',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  if (widget.calculator.calculatorType == 'lookup')
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Values between table entries are linearly interpolated.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('Recent History', style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final HistoryEntry entry in history.take(5))
            ListTile(
              dense: true,
              title: Text(entry.inputs.values.first.toStringAsFixed(2)),
              subtitle: Text(_formatTimestamp(entry.timestamp)),
              trailing: Text(entry.result.toStringAsFixed(4), style: Theme.of(context).textTheme.bodyMedium),
            ),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('No history yet.', style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime ts) {
    final DateTime local = ts.toLocal();
    return '${local.day}/${local.month}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
