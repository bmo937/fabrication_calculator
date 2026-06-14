// Stub implementation of the Python sandbox for platforms where
// dart:io is unavailable (e.g. Flutter Web).
import 'package:fabrication_calculator/models/calculator_field_definition.dart';
import 'package:fabrication_calculator/services/calculator_code_sandbox.dart';

Future<SandboxExecutionResult> executePython({
  required String codeBody,
  required List<CalculatorFieldDefinition> inputs,
  required List<CalculatorFieldDefinition> outputs,
  required Map<String, double> inputValues,
  Duration timeout = const Duration(seconds: 5),
}) async {
  return const SandboxExecutionResult(
    success: false,
    error:
        'Python execution is not supported on this platform. '
        'Use a desktop build (Windows, macOS, or Linux) to run Python calculators.',
  );
}

Future<bool> isPythonAvailable() async => false;
