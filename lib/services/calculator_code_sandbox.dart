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
  static final RegExp _identifierPattern = RegExp(r'\b[A-Za-z_][A-Za-z0-9_]*\b');
  static final RegExp _customFunctionPattern = RegExp(r'\b(if|lookup2d|lookup|round)\s*\(');
  static const Set<String> _reservedConstants = <String>{'pi', 'e'};
  static const Set<String> _mathFunctions = <String>{
    'sqrt',
    'sin',
    'cos',
    'tan',
    'asin',
    'acos',
    'atan',
    'exp',
    'ln',
    'log',
    'abs',
    'ceil',
    'floor',
    'round',
    'sign',
    'pow',
    'min',
    'max',
  };

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
    final Set<String> unknownInputs = inputValues.keys.toSet().difference(inputKeys);
    if (unknownInputs.isNotEmpty) {
      return SandboxExecutionResult(success: false, error: 'Unknown input keys: ${unknownInputs.join(', ')}.');
    }

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

      if (_reservedConstants.contains(target)) {
        return SandboxExecutionResult(success: false, error: 'Line ${i + 1}: "$target" is reserved and cannot be assigned.');
      }

      if (inputKeys.contains(target)) {
        return SandboxExecutionResult(success: false, error: 'Line ${i + 1}: "$target" is an input key and cannot be assigned.');
      }

      if (outputKeys.contains(target) && assignedOutputs.contains(target)) {
        return SandboxExecutionResult(success: false, error: 'Line ${i + 1}: "$target" output is already assigned.');
      }

      final _EvaluationResult result = _evaluateExpression(expression, runtime);
      if (!result.ok) {
        return SandboxExecutionResult(success: false, error: 'Line ${i + 1}: ${result.error ?? 'Failed to evaluate "$expression".'}');
      }

      runtime[target] = result.value!;
      if (outputKeys.contains(target)) {
        assignedOutputs.add(target);
      }
    }

    if (assignedOutputs.length != outputKeys.length) {
      final Set<String> missing = outputKeys.difference(assignedOutputs);
      return SandboxExecutionResult(success: false, error: 'Missing assignments for: ${missing.join(', ')}.');
    }

    final Map<String, double> evaluated = <String, double>{for (final CalculatorFieldDefinition output in outputs) output.key: runtime[output.key]!};

    return SandboxExecutionResult(success: true, outputs: evaluated);
  }

  static _EvaluationResult _evaluateExpression(String expression, Map<String, double> runtime) {
    final String source = _stripWrappingParentheses(expression.trim());
    if (source.isEmpty) {
      return const _EvaluationResult.error('Expression is empty.');
    }

    final _EvaluationResult orResult = _evaluateLogicalOr(source, runtime);
    if (orResult.ok) {
      return orResult;
    }

    final _EvaluationResult andResult = _evaluateLogicalAnd(source, runtime);
    if (andResult.ok) {
      return andResult;
    }

    final _EvaluationResult comparisonResult = _evaluateComparison(source, runtime);
    if (comparisonResult.ok) {
      return comparisonResult;
    }

    final _EvaluationResult unaryResult = _evaluateUnaryNot(source, runtime);
    if (unaryResult.ok) {
      return unaryResult;
    }

    final _EvaluationResult functionResult = _evaluateDirectCustomFunction(source, runtime);
    if (functionResult.ok) {
      return functionResult;
    }

    final _StringResult expanded = _replaceCustomFunctions(source, runtime);
    if (!expanded.ok) {
      return _EvaluationResult.error(expanded.error ?? 'Failed to evaluate expression.');
    }

    return _evaluateArithmetic(expanded.text!, runtime);
  }

  static _EvaluationResult _evaluateLogicalOr(String expression, Map<String, double> runtime) {
    final List<_OperatorMatch> matches = _findTopLevelOperators(expression, <String>['||']);
    if (matches.isEmpty) {
      return const _EvaluationResult.notApplicable();
    }

    final List<String> parts = _splitByMatches(expression, matches);
    for (final String part in parts) {
      final _EvaluationResult partResult = _evaluateExpression(part, runtime);
      if (!partResult.ok) {
        return partResult;
      }
      if (_isTruthy(partResult.value!)) {
        return const _EvaluationResult.value(1.0);
      }
    }
    return const _EvaluationResult.value(0.0);
  }

  static _EvaluationResult _evaluateLogicalAnd(String expression, Map<String, double> runtime) {
    final List<_OperatorMatch> matches = _findTopLevelOperators(expression, <String>['&&']);
    if (matches.isEmpty) {
      return const _EvaluationResult.notApplicable();
    }

    final List<String> parts = _splitByMatches(expression, matches);
    for (final String part in parts) {
      final _EvaluationResult partResult = _evaluateExpression(part, runtime);
      if (!partResult.ok) {
        return partResult;
      }
      if (!_isTruthy(partResult.value!)) {
        return const _EvaluationResult.value(0.0);
      }
    }
    return const _EvaluationResult.value(1.0);
  }

  static _EvaluationResult _evaluateComparison(String expression, Map<String, double> runtime) {
    final List<_OperatorMatch> matches = _findTopLevelOperators(expression, <String>['>=', '<=', '==', '!=', '>', '<']);
    if (matches.length != 1) {
      return const _EvaluationResult.notApplicable();
    }

    final _OperatorMatch operator = matches.first;
    final String leftExpression = expression.substring(0, operator.start);
    final String rightExpression = expression.substring(operator.start + operator.operator.length);

    final _EvaluationResult leftResult = _evaluateExpression(leftExpression, runtime);
    if (!leftResult.ok) {
      return leftResult;
    }
    final _EvaluationResult rightResult = _evaluateExpression(rightExpression, runtime);
    if (!rightResult.ok) {
      return rightResult;
    }

    final double left = leftResult.value!;
    final double right = rightResult.value!;

    bool output;
    switch (operator.operator) {
      case '>':
        output = left > right;
        break;
      case '<':
        output = left < right;
        break;
      case '>=':
        output = left >= right;
        break;
      case '<=':
        output = left <= right;
        break;
      case '==':
        output = _areNearlyEqual(left, right);
        break;
      case '!=':
        output = !_areNearlyEqual(left, right);
        break;
      default:
        return const _EvaluationResult.error('Unsupported comparison operator.');
    }

    return _EvaluationResult.value(output ? 1.0 : 0.0);
  }

  static _EvaluationResult _evaluateUnaryNot(String expression, Map<String, double> runtime) {
    final String trimmed = expression.trim();
    if (!trimmed.startsWith('!')) {
      return const _EvaluationResult.notApplicable();
    }

    int index = 0;
    while (index < trimmed.length && trimmed[index] == '!') {
      index++;
    }

    final _EvaluationResult operandResult = _evaluateExpression(trimmed.substring(index), runtime);
    if (!operandResult.ok) {
      return operandResult;
    }

    bool value = _isTruthy(operandResult.value!);
    for (int i = 0; i < index; i++) {
      value = !value;
    }
    return _EvaluationResult.value(value ? 1.0 : 0.0);
  }

  static _EvaluationResult _evaluateDirectCustomFunction(String expression, Map<String, double> runtime) {
    final _FunctionCall? call = _parseDirectFunction(expression);
    if (call == null || !_isCustomFunction(call.name)) {
      return const _EvaluationResult.notApplicable();
    }
    return _evaluateCustomFunction(call, runtime);
  }

  static _StringResult _replaceCustomFunctions(String expression, Map<String, double> runtime) {
    String current = expression;

    while (true) {
      final Match? match = _lastMatch(_customFunctionPattern.allMatches(current));
      if (match == null) {
        return _StringResult.text(current);
      }

      final String functionName = match.group(1)!;
      final int callStart = match.start;
      final int openParenIndex = current.indexOf('(', callStart);
      if (openParenIndex < 0) {
        return const _StringResult.error('Malformed function call.');
      }
      final int closeParenIndex = _findMatchingParen(current, openParenIndex);
      if (closeParenIndex < 0) {
        return const _StringResult.error('Unbalanced parentheses in function call.');
      }

      final String argsSource = current.substring(openParenIndex + 1, closeParenIndex);
      final List<String> args = _splitTopLevelArgs(argsSource);
      final _EvaluationResult functionResult = _evaluateCustomFunction(_FunctionCall(functionName, args), runtime);
      if (!functionResult.ok) {
        return _StringResult.error(functionResult.error ?? 'Function evaluation failed.');
      }

      final String replacement = functionResult.value!.toString();
      current = '${current.substring(0, callStart)}$replacement${current.substring(closeParenIndex + 1)}';
    }
  }

  static _EvaluationResult _evaluateCustomFunction(_FunctionCall call, Map<String, double> runtime) {
    switch (call.name) {
      case 'if':
        return _evaluateIf(call.args, runtime);
      case 'lookup':
        return _evaluateLookup(call.args, runtime);
      case 'lookup2d':
        return _evaluateLookup2d(call.args, runtime);
      case 'round':
        return _evaluateRound(call.args, runtime);
      default:
        return _EvaluationResult.error('Unsupported function "${call.name}".');
    }
  }

  static _EvaluationResult _evaluateRound(List<String> args, Map<String, double> runtime) {
    if (args.length != 1) {
      return const _EvaluationResult.error('round() requires exactly 1 argument.');
    }

    final _EvaluationResult valueResult = _evaluateExpression(args.first, runtime);
    if (!valueResult.ok) {
      return valueResult;
    }

    return _EvaluationResult.value(valueResult.value!.roundToDouble());
  }

  static _EvaluationResult _evaluateIf(List<String> args, Map<String, double> runtime) {
    if (args.length != 3) {
      return const _EvaluationResult.error('if() requires exactly 3 arguments.');
    }

    final _EvaluationResult conditionResult = _evaluateExpression(args[0], runtime);
    if (!conditionResult.ok) {
      return conditionResult;
    }

    final String branch = _isTruthy(conditionResult.value!) ? args[1] : args[2];
    return _evaluateExpression(branch, runtime);
  }

  static _EvaluationResult _evaluateLookup(List<String> args, Map<String, double> runtime) {
    if (args.length < 4 || args.length.isOdd) {
      return const _EvaluationResult.error('lookup() requires key/value pairs and a final default value.');
    }

    final _EvaluationResult keyResult = _evaluateExpression(args[0], runtime);
    if (!keyResult.ok) {
      return keyResult;
    }
    final double key = keyResult.value!;

    for (int i = 1; i < args.length - 1; i += 2) {
      final _EvaluationResult candidateKey = _evaluateExpression(args[i], runtime);
      if (!candidateKey.ok) {
        return candidateKey;
      }
      if (_areNearlyEqual(candidateKey.value!, key)) {
        return _evaluateExpression(args[i + 1], runtime);
      }
    }

    return _evaluateExpression(args.last, runtime);
  }

  static _EvaluationResult _evaluateLookup2d(List<String> args, Map<String, double> runtime) {
    if (args.length < 6 || args.length % 3 != 0) {
      return const _EvaluationResult.error('lookup2d() requires row/col/value tuples and a final default value.');
    }

    final _EvaluationResult rowKeyResult = _evaluateExpression(args[0], runtime);
    if (!rowKeyResult.ok) {
      return rowKeyResult;
    }
    final _EvaluationResult colKeyResult = _evaluateExpression(args[1], runtime);
    if (!colKeyResult.ok) {
      return colKeyResult;
    }

    final double rowKey = rowKeyResult.value!;
    final double colKey = colKeyResult.value!;

    for (int i = 2; i < args.length - 1; i += 3) {
      final _EvaluationResult candidateRow = _evaluateExpression(args[i], runtime);
      if (!candidateRow.ok) {
        return candidateRow;
      }
      final _EvaluationResult candidateCol = _evaluateExpression(args[i + 1], runtime);
      if (!candidateCol.ok) {
        return candidateCol;
      }

      if (_areNearlyEqual(candidateRow.value!, rowKey) && _areNearlyEqual(candidateCol.value!, colKey)) {
        return _evaluateExpression(args[i + 2], runtime);
      }
    }

    return _evaluateExpression(args.last, runtime);
  }

  static _EvaluationResult _evaluateArithmetic(String expression, Map<String, double> runtime) {
    final String normalized = _stripWrappingParentheses(expression.trim());
    final String? unknownIdentifier = _findUnknownIdentifier(normalized, runtime.keys.toSet());
    if (unknownIdentifier != null) {
      return _EvaluationResult.error('Unknown identifier "$unknownIdentifier".');
    }

    try {
      final Expression exp = _parser.parse(normalized);
      final ContextModel cm = ContextModel();
      runtime.forEach((String key, double value) {
        cm.bindVariable(Variable(key), Number(value));
      });
      final dynamic result = exp.evaluate(EvaluationType.REAL, cm);
      final double value = result is double ? result : (result as num).toDouble();
      if (!value.isFinite) {
        return const _EvaluationResult.error('Expression result is not finite.');
      }
      return _EvaluationResult.value(value);
    } catch (error) {
      return _EvaluationResult.error(error.toString());
    }
  }

  static List<_OperatorMatch> _findTopLevelOperators(String source, List<String> operators) {
    final List<_OperatorMatch> matches = <_OperatorMatch>[];
    int depth = 0;
    for (int index = 0; index < source.length; index++) {
      final String char = source[index];
      if (char == '(') {
        depth++;
        continue;
      }
      if (char == ')') {
        depth--;
        continue;
      }
      if (depth != 0) {
        continue;
      }
      for (final String operator in operators) {
        if (source.startsWith(operator, index)) {
          matches.add(_OperatorMatch(index, operator));
          index += operator.length - 1;
          break;
        }
      }
    }
    return matches;
  }

  static List<String> _splitByMatches(String source, List<_OperatorMatch> matches) {
    final List<String> result = <String>[];
    int start = 0;
    for (final _OperatorMatch match in matches) {
      result.add(source.substring(start, match.start));
      start = match.start + match.operator.length;
    }
    result.add(source.substring(start));
    return result;
  }

  static List<String> _splitTopLevelArgs(String source) {
    final List<String> args = <String>[];
    int depth = 0;
    int start = 0;
    for (int i = 0; i < source.length; i++) {
      final String char = source[i];
      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
      } else if (char == ',' && depth == 0) {
        args.add(source.substring(start, i).trim());
        start = i + 1;
      }
    }
    args.add(source.substring(start).trim());
    return args;
  }

  static _FunctionCall? _parseDirectFunction(String source) {
    final String trimmed = source.trim();
    final Match? nameMatch = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*)\s*\(').firstMatch(trimmed);
    if (nameMatch == null) {
      return null;
    }
    final String name = nameMatch.group(1)!;
    final int openParenIndex = trimmed.indexOf('(');
    final int closeParenIndex = _findMatchingParen(trimmed, openParenIndex);
    if (closeParenIndex < 0 || closeParenIndex != trimmed.length - 1) {
      return null;
    }
    final String argsSource = trimmed.substring(openParenIndex + 1, closeParenIndex);
    return _FunctionCall(name, _splitTopLevelArgs(argsSource));
  }

  static int _findMatchingParen(String source, int openIndex) {
    int depth = 0;
    for (int i = openIndex; i < source.length; i++) {
      if (source[i] == '(') {
        depth++;
      } else if (source[i] == ')') {
        depth--;
        if (depth == 0) {
          return i;
        }
      }
    }
    return -1;
  }

  static Match? _lastMatch(Iterable<Match> matches) {
    Match? last;
    for (final Match match in matches) {
      last = match;
    }
    return last;
  }

  static String _stripWrappingParentheses(String source) {
    String current = source;
    while (current.startsWith('(') && current.endsWith(')')) {
      final int closeIndex = _findMatchingParen(current, 0);
      if (closeIndex != current.length - 1) {
        break;
      }
      current = current.substring(1, current.length - 1).trim();
    }
    return current;
  }

  static bool _isCustomFunction(String name) {
    return name == 'if' || name == 'lookup' || name == 'lookup2d' || name == 'round';
  }

  static String? _findUnknownIdentifier(String expression, Set<String> runtimeKeys) {
    for (final Match match in _identifierPattern.allMatches(expression)) {
      final String token = match.group(0)!;
      if (runtimeKeys.contains(token) || _mathFunctions.contains(token)) {
        continue;
      }
      final int lookaheadIndex = match.end;
      if (lookaheadIndex < expression.length && expression[lookaheadIndex] == '(') {
        continue;
      }
      return token;
    }
    return null;
  }

  static bool _isTruthy(double value) {
    return value != 0.0;
  }

  static bool _areNearlyEqual(double a, double b) {
    return (a - b).abs() <= 1e-9;
  }
}

class _OperatorMatch {
  const _OperatorMatch(this.start, this.operator);

  final int start;
  final String operator;
}

class _FunctionCall {
  const _FunctionCall(this.name, this.args);

  final String name;
  final List<String> args;
}

class _EvaluationResult {
  const _EvaluationResult._({required this.ok, this.value, this.error});

  const _EvaluationResult.value(double value) : this._(ok: true, value: value);

  const _EvaluationResult.error(String message) : this._(ok: false, error: message);

  const _EvaluationResult.notApplicable() : this._(ok: false);

  final bool ok;
  final double? value;
  final String? error;
}

class _StringResult {
  const _StringResult._({required this.ok, this.text, this.error});

  const _StringResult.text(String text) : this._(ok: true, text: text);

  const _StringResult.error(String message) : this._(ok: false, error: message);

  final bool ok;
  final String? text;
  final String? error;
}
