// ignore_for_file: avoid_print

import 'package:fabrication_calculator/models/calculator_field_definition.dart';
import 'package:fabrication_calculator/models/user_python_module.dart';
import 'package:fabrication_calculator/services/calculator_code_sandbox.dart';
import 'package:fabrication_calculator/services/python_sandbox.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper to create a minimal field definition.
CalculatorFieldDefinition field(String key, {String? label}) =>
    CalculatorFieldDefinition(key: key, label: label ?? key);

void main() {
  // ── Math sandbox: confirm existing behaviour is unchanged ─────────────────

  group('Math sandbox (existing – must not regress)', () {
    test('basic arithmetic', () {
      final SandboxExecutionResult result = CalculatorCodeSandbox.execute(
        codeBody: 'area = length * width;',
        inputs: <CalculatorFieldDefinition>[field('length'), field('width')],
        outputs: <CalculatorFieldDefinition>[field('area')],
        inputValues: <String, double>{'length': 10, 'width': 5},
        codeLanguage: 'math',
      );
      expect(result.success, isTrue);
      expect(result.outputs['area'], closeTo(50.0, 1e-9));
    });

    test('rejects dart language', () {
      final SandboxExecutionResult result = CalculatorCodeSandbox.execute(
        codeBody: 'area = 0;',
        inputs: <CalculatorFieldDefinition>[],
        outputs: <CalculatorFieldDefinition>[field('area')],
        inputValues: <String, double>{},
        codeLanguage: 'dart',
      );
      expect(result.success, isFalse);
      expect(result.error, contains('math'));
    });

    test('rejects julia language', () {
      final SandboxExecutionResult result = CalculatorCodeSandbox.execute(
        codeBody: 'area = 0;',
        inputs: <CalculatorFieldDefinition>[],
        outputs: <CalculatorFieldDefinition>[field('area')],
        inputValues: <String, double>{},
        codeLanguage: 'julia',
      );
      expect(result.success, isFalse);
      expect(result.error, contains('math'));
    });
  });

  // ── supportsAutomaticSandbox ──────────────────────────────────────────────

  group('supportsAutomaticSandbox', () {
    test('math is supported', () {
      expect(CalculatorCodeSandbox.supportsAutomaticSandbox('math'), isTrue);
    });

    test('python is supported', () {
      expect(CalculatorCodeSandbox.supportsAutomaticSandbox('python'), isTrue);
    });

    test('dart is NOT supported', () {
      expect(CalculatorCodeSandbox.supportsAutomaticSandbox('dart'), isFalse);
    });

    test('julia is NOT supported', () {
      expect(CalculatorCodeSandbox.supportsAutomaticSandbox('julia'), isFalse);
    });

    test('empty string is NOT supported', () {
      expect(CalculatorCodeSandbox.supportsAutomaticSandbox(''), isFalse);
    });
  });

  // ── UserPythonModule model ────────────────────────────────────────────────

  group('UserPythonModule', () {
    test('isValidModuleName accepts valid identifiers', () {
      expect(UserPythonModule.isValidModuleName('my_helpers'), isTrue);
      expect(UserPythonModule.isValidModuleName('helpers123'), isTrue);
      expect(UserPythonModule.isValidModuleName('_private'), isTrue);
      expect(UserPythonModule.isValidModuleName('A'), isTrue);
    });

    test('isValidModuleName rejects invalid identifiers', () {
      expect(UserPythonModule.isValidModuleName(''), isFalse);
      expect(UserPythonModule.isValidModuleName('123abc'), isFalse);
      expect(UserPythonModule.isValidModuleName('my-module'), isFalse);
      expect(UserPythonModule.isValidModuleName('my module'), isFalse);
      expect(UserPythonModule.isValidModuleName('my.module'), isFalse);
    });

    test('copyWith preserves unspecified fields', () {
      final DateTime now = DateTime(2024, 1, 1);
      final UserPythonModule original = UserPythonModule(
        id: 'id-1',
        name: 'my_mod',
        code: 'x = 1',
        description: 'desc',
        createdAt: now,
        updatedAt: now,
      );
      final UserPythonModule updated = original.copyWith(name: 'new_name');
      expect(updated.id, 'id-1');
      expect(updated.name, 'new_name');
      expect(updated.code, 'x = 1');
      expect(updated.description, 'desc');
    });
  });

  // ── Python sandbox integration tests (require Python 3 on host) ───────────
  //
  // These tests are skipped automatically when Python is not available on the
  // host machine. Run them on a machine with Python 3 installed.

  group('Python sandbox (integration – requires Python 3)', () {
    late bool pythonAvailable;

    setUpAll(() async {
      pythonAvailable = await PythonSandbox.isPythonAvailable();
      if (!pythonAvailable) {
        print('[SKIP] Python 3 not found on this machine. Skipping integration tests.');
      }
    });

    test('basic variable assignment', () async {
      if (!pythonAvailable) return;

      final SandboxExecutionResult result = await PythonSandbox.execute(
        codeBody: 'area = length * width',
        inputs: <CalculatorFieldDefinition>[field('length'), field('width')],
        outputs: <CalculatorFieldDefinition>[field('area')],
        inputValues: <String, double>{'length': 10, 'width': 5},
      );

      expect(result.success, isTrue, reason: result.error);
      expect(result.outputs['area'], closeTo(50.0, 1e-9));
    });

    test('inputs are available as plain variables', () async {
      if (!pythonAvailable) return;

      final SandboxExecutionResult result = await PythonSandbox.execute(
        codeBody: 'result = x + y + z',
        inputs: <CalculatorFieldDefinition>[field('x'), field('y'), field('z')],
        outputs: <CalculatorFieldDefinition>[field('result')],
        inputValues: <String, double>{'x': 1, 'y': 2, 'z': 3},
      );

      expect(result.success, isTrue, reason: result.error);
      expect(result.outputs['result'], closeTo(6.0, 1e-9));
    });

    test('math module is available', () async {
      if (!pythonAvailable) return;

      final SandboxExecutionResult result = await PythonSandbox.execute(
        codeBody: 'circumference = math.pi * diameter',
        inputs: <CalculatorFieldDefinition>[field('diameter')],
        outputs: <CalculatorFieldDefinition>[field('circumference')],
        inputValues: <String, double>{'diameter': 2.0},
      );

      expect(result.success, isTrue, reason: result.error);
      expect(result.outputs['circumference'], closeTo(2 * 3.14159265358979, 1e-6));
    });

    test('workshop_helpers.geometry can be imported', () async {
      if (!pythonAvailable) return;

      const String code = '''
from workshop_helpers.geometry import circle_area
area = circle_area(diameter)
''';

      final SandboxExecutionResult result = await PythonSandbox.execute(
        codeBody: code,
        inputs: <CalculatorFieldDefinition>[field('diameter')],
        outputs: <CalculatorFieldDefinition>[field('area')],
        inputValues: <String, double>{'diameter': 10.0},
      );

      expect(result.success, isTrue, reason: result.error);
      expect(result.outputs['area'], closeTo(78.53981633974483, 1e-6));
    });

    test('workshop_helpers.sheetmetal can be imported', () async {
      if (!pythonAvailable) return;

      const String code = '''
from workshop_helpers.sheetmetal import material_weight
weight = material_weight(length_mm, width_mm, thickness_mm)
''';

      final SandboxExecutionResult result = await PythonSandbox.execute(
        codeBody: code,
        inputs: <CalculatorFieldDefinition>[
          field('length_mm'),
          field('width_mm'),
          field('thickness_mm'),
        ],
        outputs: <CalculatorFieldDefinition>[field('weight')],
        inputValues: <String, double>{'length_mm': 1000, 'width_mm': 500, 'thickness_mm': 3.0},
      );

      expect(result.success, isTrue, reason: result.error);
      // 1m × 0.5m × 0.003m × 7850 kg/m³ = 11.775 kg
      expect(result.outputs['weight'], closeTo(11.775, 0.001));
    });

    test('workshop_helpers.lookup_tables can be imported', () async {
      if (!pythonAvailable) return;

      const String code = '''
from workshop_helpers.lookup_tables import interpolate
table = [(0, 0), (10, 100), (20, 200)]
result = interpolate(table, 5)
''';

      final SandboxExecutionResult result = await PythonSandbox.execute(
        codeBody: code,
        inputs: <CalculatorFieldDefinition>[],
        outputs: <CalculatorFieldDefinition>[field('result')],
        inputValues: <String, double>{},
      );

      expect(result.success, isTrue, reason: result.error);
      expect(result.outputs['result'], closeTo(50.0, 1e-9));
    });

    test('missing output variable returns error', () async {
      if (!pythonAvailable) return;

      final SandboxExecutionResult result = await PythonSandbox.execute(
        codeBody: 'x = 1  # forgot to assign "result"',
        inputs: <CalculatorFieldDefinition>[],
        outputs: <CalculatorFieldDefinition>[field('result')],
        inputValues: <String, double>{},
      );

      expect(result.success, isFalse);
      expect(result.error, contains('result'));
    });

    test('syntax error returns clear message', () async {
      if (!pythonAvailable) return;

      final SandboxExecutionResult result = await PythonSandbox.execute(
        codeBody: 'result = (  # unclosed parenthesis',
        inputs: <CalculatorFieldDefinition>[],
        outputs: <CalculatorFieldDefinition>[field('result')],
        inputValues: <String, double>{},
      );

      expect(result.success, isFalse);
      expect(result.error, isNotEmpty);
    });

    test('division by zero returns error', () async {
      if (!pythonAvailable) return;

      final SandboxExecutionResult result = await PythonSandbox.execute(
        codeBody: 'result = 1 / 0',
        inputs: <CalculatorFieldDefinition>[],
        outputs: <CalculatorFieldDefinition>[field('result')],
        inputValues: <String, double>{},
      );

      expect(result.success, isFalse);
      expect(result.error, isNotEmpty);
    });

    test('disallowed import (os) is rejected', () async {
      if (!pythonAvailable) return;

      final SandboxExecutionResult result = await PythonSandbox.execute(
        codeBody: 'import os\nresult = float(os.getpid())',
        inputs: <CalculatorFieldDefinition>[],
        outputs: <CalculatorFieldDefinition>[field('result')],
        inputValues: <String, double>{},
      );

      expect(result.success, isFalse);
      expect(result.error, anyOf(contains('os'), contains('not allowed'), contains('not permitted')));
    });

    test('disallowed import (socket) is rejected', () async {
      if (!pythonAvailable) return;

      final SandboxExecutionResult result = await PythonSandbox.execute(
        codeBody: 'import socket\nresult = 0.0',
        inputs: <CalculatorFieldDefinition>[],
        outputs: <CalculatorFieldDefinition>[field('result')],
        inputValues: <String, double>{},
      );

      expect(result.success, isFalse);
      expect(result.error, anyOf(contains('socket'), contains('not allowed'), contains('not permitted')));
    });

    test('disallowed import (subprocess) is rejected', () async {
      if (!pythonAvailable) return;

      final SandboxExecutionResult result = await PythonSandbox.execute(
        codeBody: 'import subprocess\nresult = 0.0',
        inputs: <CalculatorFieldDefinition>[],
        outputs: <CalculatorFieldDefinition>[field('result')],
        inputValues: <String, double>{},
      );

      expect(result.success, isFalse);
    });

    test('execution timeout is enforced', () async {
      if (!pythonAvailable) return;

      final SandboxExecutionResult result = await PythonSandbox.execute(
        codeBody: 'result = 0\nwhile True: pass',
        inputs: <CalculatorFieldDefinition>[],
        outputs: <CalculatorFieldDefinition>[field('result')],
        inputValues: <String, double>{},
        timeout: const Duration(seconds: 2),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('timed out'));
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('multiple outputs are all returned', () async {
      if (!pythonAvailable) return;

      const String code = '''
area      = length * width
perimeter = 2 * (length + width)
diagonal  = (length ** 2 + width ** 2) ** 0.5
''';

      final SandboxExecutionResult result = await PythonSandbox.execute(
        codeBody: code,
        inputs: <CalculatorFieldDefinition>[field('length'), field('width')],
        outputs: <CalculatorFieldDefinition>[
          field('area'),
          field('perimeter'),
          field('diagonal'),
        ],
        inputValues: <String, double>{'length': 3.0, 'width': 4.0},
      );

      expect(result.success, isTrue, reason: result.error);
      expect(result.outputs['area'], closeTo(12.0, 1e-9));
      expect(result.outputs['perimeter'], closeTo(14.0, 1e-9));
      expect(result.outputs['diagonal'], closeTo(5.0, 1e-9));
    });
  });
}
