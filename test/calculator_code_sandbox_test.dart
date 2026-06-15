import 'package:fabrication_calculator/models/calculator_field_definition.dart';
import 'package:fabrication_calculator/services/calculator_code_sandbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const List<CalculatorFieldDefinition> defaultInputs = <CalculatorFieldDefinition>[
    CalculatorFieldDefinition(key: 'length', label: 'Length'),
    CalculatorFieldDefinition(key: 'holes', label: 'Holes'),
    CalculatorFieldDefinition(key: 'value1', label: 'Value 1'),
    CalculatorFieldDefinition(key: 'value2', label: 'Value 2'),
    CalculatorFieldDefinition(key: 'value3', label: 'Value 3'),
    CalculatorFieldDefinition(key: 'value4', label: 'Value 4'),
    CalculatorFieldDefinition(key: 'width', label: 'Width'),
    CalculatorFieldDefinition(key: 'height', label: 'Height'),
    CalculatorFieldDefinition(key: 'thickness', label: 'Thickness'),
    CalculatorFieldDefinition(key: 'material_code', label: 'Material Code'),
  ];

  SandboxExecutionResult run({
    required String code,
    required List<CalculatorFieldDefinition> outputs,
    required Map<String, double> values,
    List<CalculatorFieldDefinition> inputs = defaultInputs,
  }) {
    return CalculatorCodeSandbox.execute(codeBody: code, inputs: inputs, outputs: outputs, inputValues: values, codeLanguage: 'math');
  }

  test('supports temp variables for repeated spacing calculations', () {
    final SandboxExecutionResult result = run(
      code: '''
spacing = length / (holes + 1);
hole1 = round(spacing * 1);
hole2 = round(spacing * 2);
hole3 = round(spacing * 3);
''',
      outputs: const <CalculatorFieldDefinition>[
        CalculatorFieldDefinition(key: 'hole1', label: 'Hole 1'),
        CalculatorFieldDefinition(key: 'hole2', label: 'Hole 2'),
        CalculatorFieldDefinition(key: 'hole3', label: 'Hole 3'),
      ],
      values: const <String, double>{'length': 100, 'holes': 3},
    );

    expect(result.success, isTrue);
    expect(result.outputs['hole1'], equals(25));
    expect(result.outputs['hole2'], equals(50));
    expect(result.outputs['hole3'], equals(75));
  });

  test('supports sequential running totals', () {
    final SandboxExecutionResult result = run(
      code: '''
t1 = value1;
t2 = t1 + value2;
t3 = t2 + value3;
t4 = t3 + value4;
''',
      outputs: const <CalculatorFieldDefinition>[
        CalculatorFieldDefinition(key: 't1', label: 'T1'),
        CalculatorFieldDefinition(key: 't2', label: 'T2'),
        CalculatorFieldDefinition(key: 't3', label: 'T3'),
        CalculatorFieldDefinition(key: 't4', label: 'T4'),
      ],
      values: const <String, double>{'value1': 1, 'value2': 2, 'value3': 3, 'value4': 4},
    );

    expect(result.success, isTrue);
    expect(result.outputs['t1'], equals(1));
    expect(result.outputs['t2'], equals(3));
    expect(result.outputs['t3'], equals(6));
    expect(result.outputs['t4'], equals(10));
  });

  test('supports comparisons, if(), and lookup()', () {
    final SandboxExecutionResult result = run(
      code: '''
area = width * height;
is_thick = thickness > 2;
factor = if(is_thick, 1.25, 1.0);
k = lookup(material_code, 1, 0.44, 2, 0.33, 0.40);
result = area * factor * k;
''',
      outputs: const <CalculatorFieldDefinition>[CalculatorFieldDefinition(key: 'result', label: 'Result')],
      values: const <String, double>{'width': 4, 'height': 5, 'thickness': 3, 'material_code': 2},
    );

    expect(result.success, isTrue);
    expect(result.outputs['result'], closeTo(8.25, 1e-9));
  });

  test('supports lookup2d exact matching with default fallback', () {
    final SandboxExecutionResult exactMatch = run(
      code: 'result = lookup2d(1, 2, 1, 2, 10, 2, 3, 20, 99);',
      outputs: const <CalculatorFieldDefinition>[CalculatorFieldDefinition(key: 'result', label: 'Result')],
      values: const <String, double>{},
      inputs: const <CalculatorFieldDefinition>[],
    );

    final SandboxExecutionResult fallback = run(
      code: 'result = lookup2d(9, 9, 1, 2, 10, 2, 3, 20, 99);',
      outputs: const <CalculatorFieldDefinition>[CalculatorFieldDefinition(key: 'result', label: 'Result')],
      values: const <String, double>{},
      inputs: const <CalculatorFieldDefinition>[],
    );

    expect(exactMatch.success, isTrue);
    expect(exactMatch.outputs['result'], equals(10));
    expect(fallback.success, isTrue);
    expect(fallback.outputs['result'], equals(99));
  });

  test('short-circuits if() to avoid evaluating unused branch', () {
    final SandboxExecutionResult result = run(
      code: 'result = if(1 == 1, 5, 1 / 0);',
      outputs: const <CalculatorFieldDefinition>[CalculatorFieldDefinition(key: 'result', label: 'Result')],
      values: const <String, double>{},
      inputs: const <CalculatorFieldDefinition>[],
    );

    expect(result.success, isTrue);
    expect(result.outputs['result'], equals(5));
  });

  test('short-circuits logical operators', () {
    final SandboxExecutionResult andResult = run(
      code: 'result = 0 && unknown_rhs;',
      outputs: const <CalculatorFieldDefinition>[CalculatorFieldDefinition(key: 'result', label: 'Result')],
      values: const <String, double>{},
      inputs: const <CalculatorFieldDefinition>[],
    );

    final SandboxExecutionResult orResult = run(
      code: 'result = 1 || unknown_rhs;',
      outputs: const <CalculatorFieldDefinition>[CalculatorFieldDefinition(key: 'result', label: 'Result')],
      values: const <String, double>{},
      inputs: const <CalculatorFieldDefinition>[],
    );

    expect(andResult.success, isTrue);
    expect(andResult.outputs['result'], equals(0));
    expect(orResult.success, isTrue);
    expect(orResult.outputs['result'], equals(1));
  });

  test('fails when trying to assign an input key', () {
    final SandboxExecutionResult result = run(
      code: 'length = 2;',
      outputs: const <CalculatorFieldDefinition>[CalculatorFieldDefinition(key: 'result', label: 'Result')],
      values: const <String, double>{'length': 10},
    );

    expect(result.success, isFalse);
    expect(result.error, contains('input key'));
  });

  test('fails when output assignment is missing', () {
    final SandboxExecutionResult result = run(
      code: 'temp = 12;',
      outputs: const <CalculatorFieldDefinition>[CalculatorFieldDefinition(key: 'result', label: 'Result')],
      values: const <String, double>{},
      inputs: const <CalculatorFieldDefinition>[],
    );

    expect(result.success, isFalse);
    expect(result.error, contains('Missing assignments'));
  });

  test('fails malformed lookup() argument structure', () {
    final SandboxExecutionResult result = run(
      code: 'result = lookup(1, 1, 10);',
      outputs: const <CalculatorFieldDefinition>[CalculatorFieldDefinition(key: 'result', label: 'Result')],
      values: const <String, double>{},
      inputs: const <CalculatorFieldDefinition>[],
    );

    expect(result.success, isFalse);
    expect(result.error, contains('lookup() requires key/value pairs'));
  });
}
