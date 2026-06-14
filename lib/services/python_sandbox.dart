// Public entry point for the Python execution sandbox.
//
// Callers always import this file. The appropriate platform implementation
// is selected automatically via conditional imports:
//   - Desktop (dart:io available): python_sandbox_io.dart
//   - Web (dart:html): python_sandbox_unsupported.dart
//
// Usage:
// final result = await PythonSandbox.execute(
//   codeBody: 'result = thickness * 2',
//   inputs: [...],
//   outputs: [...],
//   inputValues: {'thickness': 3.0},
// );
import 'package:fabrication_calculator/models/calculator_field_definition.dart';
import 'package:fabrication_calculator/services/calculator_code_sandbox.dart';

// Conditional platform import:
//   - dart.library.html  → web  → unsupported stub
//   - dart.library.io    → desktop/mobile → full io implementation
import 'python_sandbox_io.dart' as impl
    if (dart.library.html) 'python_sandbox_unsupported.dart';

/// Sandboxed Python execution engine for Workshop Helper calculators.
///
/// ## Sandboxing
/// - Only `math` and `workshop_helpers` (and its sub-modules) may be imported.
/// - Dangerous built-ins (`open`, `eval`, `exec`, `compile`, `__import__`,
///   `os`, `sys`, `subprocess`, `socket`, etc.) are removed from the
///   execution namespace.
/// - Execution is terminated after [timeout] (default 5 s).
///
/// ## Input / Output contract
/// - Input variables are injected directly into the Python namespace so user
///   code can reference them by name:
///   ```python
///   # inputs: {thickness: 2.0, bend_radius: 4.0}
///   from workshop_helpers.geometry import bend_allowance
///   result = bend_allowance(thickness, 90, bend_radius)
///   ```
/// - Every output key defined in the calculator schema must be assigned a
///   numeric value before the script ends:
///   ```python
///   area   = math.pi * (diameter / 2) ** 2
///   volume = area * height
///   ```
///
/// ## Shared helpers
/// The `workshop_helpers` package is automatically available and contains:
/// - `geometry`      – circle/rectangle areas, bend allowance, flat-blank length
/// - `sheetmetal`    – material weight, press-brake tonnage, relief radii
/// - `lookup_tables` – linear interpolation, nearest-value lookup
class PythonSandbox {
  PythonSandbox._();

  /// Execute [codeBody] in an isolated Python 3 subprocess.
  ///
  /// Returns a [SandboxExecutionResult] whose [SandboxExecutionResult.success]
  /// flag indicates whether the run completed without error.
  ///
  /// On unsupported platforms (web, mobile without Python) the result will
  /// always be unsuccessful with an explanatory error message.
  static Future<SandboxExecutionResult> execute({
    required String codeBody,
    required List<CalculatorFieldDefinition> inputs,
    required List<CalculatorFieldDefinition> outputs,
    required Map<String, double> inputValues,
    Duration timeout = const Duration(seconds: 5),
  }) {
    return impl.executePython(
      codeBody: codeBody,
      inputs: inputs,
      outputs: outputs,
      inputValues: inputValues,
      timeout: timeout,
    );
  }

  /// Returns [true] if a Python 3 interpreter is accessible on the host.
  ///
  /// Always [false] on web and mobile (no subprocess support).
  static Future<bool> isPythonAvailable() => impl.isPythonAvailable();
}
