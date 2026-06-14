// dart:io-based Python sandbox implementation for desktop platforms
// (Windows, macOS, Linux).
//
// Execution model:
//   1. A temporary directory is created for each run.
//   2. The workshop_helpers package is written to that directory as .py files.
//   3. A sandboxed Python wrapper script is written to the same directory.
//   4. Configuration (user code, inputs, expected output keys) is passed to
//      the wrapper via stdin as a JSON object.
//   5. The wrapper executes the user code in a restricted namespace and
//      returns a JSON object on stdout.
//   6. The temporary directory is deleted after the run.
//
// Security controls applied inside the Python wrapper:
//   - Restricted __builtins__ (open, exec, eval, compile, __import__ blocked)
//   - Custom import hook allowing only 'math' and 'workshop_helpers'
//   - Process-level timeout enforced by Dart (default 5 s)
//   - No explicit memory cap (platform resource limits apply)
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fabrication_calculator/models/calculator_field_definition.dart';
import 'package:fabrication_calculator/repositories/python_module_repository.dart';
import 'package:fabrication_calculator/services/calculator_code_sandbox.dart';
import 'package:fabrication_calculator/services/workshop_helpers_modules.dart';
import 'package:hive/hive.dart';

// ── Public API ────────────────────────────────────────────────────────────────

/// Execute [codeBody] in a sandboxed Python 3 process.
///
/// Inputs are injected as plain variables in the Python namespace so user
/// code can reference them directly (e.g. `result = thickness * 2`).
///
/// Expected output variables are collected from the namespace after execution.
/// All output values must be numeric (int or float); anything else is an error.
Future<SandboxExecutionResult> executePython({
  required String codeBody,
  required List<CalculatorFieldDefinition> inputs,
  required List<CalculatorFieldDefinition> outputs,
  required Map<String, double> inputValues,
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (!_isSupportedPlatform()) {
    return const SandboxExecutionResult(success: false, error: 'Python execution is only supported on Windows, macOS, and Linux.');
  }

  final String? pythonExe = await _findPythonExecutable();
  if (pythonExe == null) {
    return const SandboxExecutionResult(
      success: false,
      error:
          'Python 3 is not installed or not in PATH.\n'
          'Install Python 3.8 or later from https://python.org to use Python calculators.',
    );
  }

  Directory? tempDir;
  try {
    tempDir = await Directory.systemTemp.createTemp('wh_sandbox_');

    // Write workshop_helpers package to the temp dir
    await _extractWorkshopHelpers(tempDir.path);

    // Write the sandboxed wrapper script
    final String wrapperPath = '${tempDir.path}/sandbox_runner.py';
    await File(wrapperPath).writeAsString(_kSandboxWrapper, flush: true);

    // Build the JSON configuration to pass via stdin
    final String configJson = jsonEncode(<String, dynamic>{
      'code': codeBody,
      'inputs': inputValues,
      'output_keys': outputs.map((CalculatorFieldDefinition e) => e.key).toList(),
      'helpers_path': tempDir.path,
      'memory_limit_bytes': 256 * 1024 * 1024,
    });

    // Launch the Python process
    final Process process = await Process.start(pythonExe, <String>[wrapperPath], workingDirectory: tempDir.path);

    // Write config to stdin then close it so Python can read EOF
    process.stdin.write(configJson);
    await process.stdin.close();

    // Collect stdout and stderr concurrently
    final StringBuffer stdoutBuf = StringBuffer();
    final StringBuffer stderrBuf = StringBuffer();
    process.stdout.transform(const Utf8Decoder()).listen(stdoutBuf.write);
    process.stderr.transform(const Utf8Decoder()).listen(stderrBuf.write);

    // Wait for exit, enforcing a hard timeout
    late final int exitCode;
    try {
      exitCode = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill();
      return SandboxExecutionResult(
        success: false,
        error:
            'Python execution timed out (${timeout.inSeconds}s limit). '
            'Check for infinite loops or expensive computations.',
      );
    }

    final String stdoutStr = stdoutBuf.toString().trim();
    final String stderrStr = stderrBuf.toString().trim();

    if (exitCode != 0 && stdoutStr.isEmpty) {
      return SandboxExecutionResult(success: false, error: stderrStr.isNotEmpty ? stderrStr : 'Python process exited with code $exitCode.');
    }

    if (stdoutStr.isEmpty) {
      return SandboxExecutionResult(success: false, error: stderrStr.isNotEmpty ? stderrStr : 'No output from Python.');
    }

    // Parse the JSON response from the wrapper
    Map<String, dynamic> response;
    try {
      response = jsonDecode(stdoutStr) as Map<String, dynamic>;
    } catch (_) {
      return SandboxExecutionResult(success: false, error: 'Python returned unexpected output:\n$stdoutStr');
    }

    if (response.containsKey('error')) {
      return SandboxExecutionResult(success: false, error: response['error'] as String);
    }

    final dynamic rawOutputs = response['outputs'];
    if (rawOutputs is! Map) {
      return const SandboxExecutionResult(success: false, error: 'Python sandbox returned an unexpected response format.');
    }

    final Map<String, double> parsedOutputs = <String, double>{};
    for (final MapEntry<dynamic, dynamic> entry in rawOutputs.entries) {
      final dynamic value = entry.value;
      if (value is num) {
        parsedOutputs[entry.key as String] = value.toDouble();
      } else {
        return SandboxExecutionResult(success: false, error: "Output '${entry.key}' is not a number (got ${value.runtimeType}).");
      }
    }

    return SandboxExecutionResult(success: true, outputs: parsedOutputs);
  } catch (e) {
    return SandboxExecutionResult(success: false, error: 'Python sandbox error: $e');
  } finally {
    try {
      await tempDir?.delete(recursive: true);
    } catch (_) {
      // Temp cleanup failure is non-fatal
    }
  }
}

/// Returns [true] if Python 3 is accessible on the current machine.
Future<bool> isPythonAvailable() async {
  if (!_isSupportedPlatform()) return false;
  return await _findPythonExecutable() != null;
}

// ── Internal helpers ──────────────────────────────────────────────────────────

bool _isSupportedPlatform() {
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

/// Try common Python 3 executable names and return the first that succeeds,
/// or null if none are found.
Future<String?> _findPythonExecutable() async {
  final List<String> candidates = Platform.isWindows ? <String>['python', 'python3', 'py'] : <String>['python3', 'python'];

  for (final String candidate in candidates) {
    try {
      final ProcessResult result = await Process.run(candidate, <String>['--version'], runInShell: Platform.isWindows);
      final String versionOutput = '${result.stdout}${result.stderr}'.trim();
      if (result.exitCode == 0 && versionOutput.contains('Python 3')) {
        return candidate;
      }
    } catch (_) {
      // This candidate is not available; try the next one
    }
  }
  return null;
}

/// Write the workshop_helpers Python package to [destDir]/workshop_helpers/.
Future<void> _extractWorkshopHelpers(String destDir) async {
  final String pkgDir = '$destDir/workshop_helpers';
  await Directory(pkgDir).create(recursive: true);

  await File('$pkgDir/__init__.py').writeAsString(kWorkshopHelpersInit, flush: true);
  await File('$pkgDir/geometry.py').writeAsString(kGeometryPy, flush: true);
  await File('$pkgDir/sheetmetal.py').writeAsString(kSheetmetalPy, flush: true);
  await File('$pkgDir/lookup_tables.py').writeAsString(kLookupTablesPy, flush: true);

  // Scaffold support for user-defined modules:
  //   from workshop_helpers.user_modules import my_custom_helpers
  // Modules are loaded from Hive and materialized as .py files at runtime.
  final String userModulesDir = '$pkgDir/user_modules';
  await Directory(userModulesDir).create(recursive: true);
  await File('$userModulesDir/__init__.py').writeAsString('# User-defined helper modules (generated at runtime).\n', flush: true);

  if (!Hive.isAdapterRegistered(4)) {
    return;
  }

  try {
    final PythonModuleRepository repo = PythonModuleRepository();
    final Map<String, String> userModuleCode = await repo.getAllModuleCode();
    for (final MapEntry<String, String> entry in userModuleCode.entries) {
      final String moduleName = entry.key;
      final String code = entry.value;
      await File('$userModulesDir/$moduleName.py').writeAsString(code, flush: true);
    }
  } catch (_) {
    // If Hive is not initialized (for tests or constrained runtimes), proceed
    // without user modules. Built-in workshop_helpers modules remain available.
  }
}

// ── Sandboxed Python wrapper script ──────────────────────────────────────────
//
// This script is written to disk and executed by the Python subprocess.
// It reads configuration from stdin, sets up a restricted execution environment,
// runs the user's code, then writes results (or an error) to stdout as JSON.
const String _kSandboxWrapper = r"""
import sys
import json
import math
import traceback

# ── Read configuration from stdin ─────────────────────────────────────────────
try:
    _raw = sys.stdin.read()
    _cfg = json.loads(_raw)
except Exception as _e:
    print(json.dumps({"error": f"Failed to read sandbox config: {_e}"}))
    sys.exit(0)

_user_code    = _cfg.get("code", "")
_input_values = _cfg.get("inputs", {})
_output_keys  = _cfg.get("output_keys", [])
_helpers_path = _cfg.get("helpers_path", "")

# Optional hard memory ceiling (bytes). 256 MiB default.
_memory_limit_bytes = int(_cfg.get("memory_limit_bytes", 268435456))

# ── Set up helpers import path ────────────────────────────────────────────────
if _helpers_path and _helpers_path not in sys.path:
    sys.path.insert(0, _helpers_path)

# ── Memory limit (best effort) ───────────────────────────────────────────────
# On Unix (Linux/macOS), RLIMIT_AS constrains process virtual memory.
# On Windows this module is unavailable; we keep best-effort sandboxing.
try:
  import resource  # Unix only
  resource.setrlimit(resource.RLIMIT_AS, (_memory_limit_bytes, _memory_limit_bytes))
except Exception:
  pass

# ── Restricted import hook ────────────────────────────────────────────────────
import builtins as _builtins
_ALLOWED_MODULES = frozenset({
    "math",
    "workshop_helpers",
    "workshop_helpers.geometry",
    "workshop_helpers.sheetmetal",
    "workshop_helpers.lookup_tables",
})
_orig_import = _builtins.__import__

def _restricted_import(name, globals=None, locals=None, fromlist=(), level=0):
    top_level = name.split(".")[0]
    if top_level not in _ALLOWED_MODULES and name not in _ALLOWED_MODULES:
        raise ImportError(
            f"Import of '{name}' is not permitted in the calculator sandbox. "
            f"Allowed modules: math, workshop_helpers (and its sub-modules)."
        )
    return _orig_import(name, globals, locals, fromlist, level)

# ── Restricted built-ins (block filesystem, network, exec, eval, etc.) ────────
_safe_builtins = {
    "__name__":       "__sandbox__",
    "__import__":     _restricted_import,
    # Numeric / type operations
    "abs":            abs,
    "bool":           bool,
    "complex":        complex,
    "dict":           dict,
    "divmod":         divmod,
    "enumerate":      enumerate,
    "float":          float,
    "frozenset":      frozenset,
    "hash":           hash,
    "int":            int,
    "isinstance":     isinstance,
    "issubclass":     issubclass,
    "iter":           iter,
    "len":            len,
    "list":           list,
    "map":            map,
    "max":            max,
    "min":            min,
    "next":           next,
    "pow":            pow,
    "print":          print,
    "range":          range,
    "repr":           repr,
    "reversed":       reversed,
    "round":          round,
    "set":            set,
    "slice":          slice,
    "sorted":         sorted,
    "str":            str,
    "sum":            sum,
    "tuple":          tuple,
    "type":           type,
    "zip":            zip,
    # Constants
    "True":           True,
    "False":          False,
    "None":           None,
    # Safe exceptions
    "ArithmeticError":    ArithmeticError,
    "Exception":          Exception,
    "IndexError":         IndexError,
    "KeyError":           KeyError,
    "RuntimeError":       RuntimeError,
    "StopIteration":      StopIteration,
    "TypeError":          TypeError,
    "ValueError":         ValueError,
    "ZeroDivisionError":  ZeroDivisionError,
    "NotImplementedError":NotImplementedError,
}

# ── Build execution namespace ─────────────────────────────────────────────────
_namespace = {
    "__builtins__": _safe_builtins,
    "math":         math,
}
# Inject input values as plain variables
_namespace.update(_input_values)

# ── Execute user code ─────────────────────────────────────────────────────────
try:
    _compiled = compile(_user_code, "<calculator>", "exec")
    exec(_compiled, _namespace)
except SyntaxError as _e:
    print(json.dumps({"error": f"Syntax error on line {_e.lineno}: {_e.msg}"}))
    sys.exit(0)
except ImportError as _e:
    print(json.dumps({"error": str(_e)}))
    sys.exit(0)
except ZeroDivisionError:
    print(json.dumps({"error": "Division by zero in calculator code."}))
    sys.exit(0)
except Exception as _e:
    tb_lines = traceback.format_exception(type(_e), _e, _e.__traceback__)
    # Strip internal wrapper frames, keep only user-code lines
    user_lines = [l for l in tb_lines if "<calculator>" in l or str(_e) in l]
    detail = "".join(user_lines).strip() if user_lines else str(_e)
    print(json.dumps({"error": f"Runtime error: {detail}"}))
    sys.exit(0)

# ── Collect outputs ───────────────────────────────────────────────────────────
_result    = {}
_missing   = []
_type_errs = []

for _key in _output_keys:
    if _key not in _namespace:
        _missing.append(_key)
    else:
        _val = _namespace[_key]
        try:
            _result[_key] = float(_val)
        except (TypeError, ValueError):
            _type_errs.append(f"'{_key}' = {_val!r} (expected a number)")

if _missing:
    print(json.dumps({"error": f"Missing output variables: {', '.join(_missing)}. "
                                "Make sure every output key is assigned a value."}))
    sys.exit(0)

if _type_errs:
    print(json.dumps({"error": f"Output type error(s): {'; '.join(_type_errs)}"}))
    sys.exit(0)

print(json.dumps({"outputs": _result}))
""";
