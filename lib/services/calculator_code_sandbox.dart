import 'dart:math' as math;

import 'package:fabrication_calculator/models/calculator_field_definition.dart';
import 'package:math_expressions/math_expressions.dart';

class SandboxExecutionResult {
  const SandboxExecutionResult({required this.success, this.outputs = const <String, double>{}, this.error});

  final bool success;
  final Map<String, double> outputs;
  final String? error;
}

class CalculatorCodeSandbox {
  static final GrammarParser _parser = GrammarParser();
  static final RegExp _linePattern = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*;?$');

  static bool supportsAutomaticSandbox(String codeLanguage) => codeLanguage == 'math';

  static SandboxExecutionResult execute({
    required String codeBody,
    required List<CalculatorFieldDefinition> inputs,
    required List<CalculatorFieldDefinition> outputs,
    required Map<String, double> inputValues,
    required String codeLanguage,
  }) {
    if (!supportsAutomaticSandbox(codeLanguage)) {
      return SandboxExecutionResult(success: false, error: 'Automatic sandbox is unavailable for $codeLanguage. Use manual verification.');
    }

    if (outputs.isEmpty) {
      return const SandboxExecutionResult(success: false, error: 'Define at least one output field.');
    }

    if (codeBody.trim().isEmpty) {
      return const SandboxExecutionResult(success: false, error: 'Code body is required.');
    }

    final Set<String> outputKeys = outputs.map((CalculatorFieldDefinition e) => e.key).toSet();
    final Set<String> inputKeys = inputs.map((CalculatorFieldDefinition e) => e.key).toSet();

    final Map<String, double> runtime = <String, double>{...inputValues, 'pi': math.pi, 'e': math.e};

    final Set<String> assignedOutputs = <String>{};
    final List<String> lines = codeBody.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final String rawLine = lines[i].trim();
      if (rawLine.isEmpty || rawLine.startsWith('//')) {
        continue;
      }

      final Match? match = _linePattern.firstMatch(rawLine);
      if (match == null) {
        return SandboxExecutionResult(success: false, error: 'Line ${i + 1}: Use "outputKey = expression;" format.');
      }

      final String target = match.group(1)!;
      final String expression = match.group(2)!;

      if (!outputKeys.contains(target)) {
        return SandboxExecutionResult(success: false, error: 'Line ${i + 1}: "$target" is not a defined output key.');
      }

      final double? value = _evaluateExpression(expression, runtime);
      if (value == null) {
        return SandboxExecutionResult(success: false, error: 'Line ${i + 1}: Failed to evaluate "$expression".');
      }

      runtime[target] = value;
      assignedOutputs.add(target);
    }

    if (assignedOutputs.length != outputKeys.length) {
      final Set<String> missing = outputKeys.difference(assignedOutputs);
      return SandboxExecutionResult(success: false, error: 'Missing assignments for: ${missing.join(', ')}.');
    }

    final Map<String, double> evaluated = <String, double>{for (final CalculatorFieldDefinition output in outputs) output.key: runtime[output.key]!};

    final Set<String> unknownInputs = inputValues.keys.toSet().difference(inputKeys);
    if (unknownInputs.isNotEmpty) {
      return SandboxExecutionResult(success: false, error: 'Unknown input keys: ${unknownInputs.join(', ')}.');
    }

    return SandboxExecutionResult(success: true, outputs: evaluated);
  }

  static double? _evaluateExpression(String expression, Map<String, double> runtime) {
    try {
      final Expression exp = _parser.parse(expression);
      final ContextModel cm = ContextModel();
      runtime.forEach((String key, double value) {
        cm.bindVariable(Variable(key), Number(value));
      });
      final dynamic result = exp.evaluate(EvaluationType.REAL, cm);
      final double value = result is double ? result : (result as num).toDouble();
      if (!value.isFinite) {
        return null;
      }
      return value;
    } catch (_) {
      return null;
    }
  }
}
