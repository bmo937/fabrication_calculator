import 'package:math_expressions/math_expressions.dart';

/// Safely evaluates mathematical expressions with a single variable [x].
///
/// Supported syntax follows standard math_expressions notation:
///   x * 25.4    x / 2.54    (x - 32) * 5/9    sqrt(x)    x^2
class FormulaEvaluator {
  static final GrammarParser _parser = GrammarParser();

  /// Evaluates [expression] substituting [x] for the variable named 'x'.
  /// Returns null if the expression is syntactically invalid or produces a
  /// non-finite result (±infinity, NaN).
  static double? evaluate(String expression, {required double x}) {
    try {
      final Expression exp = _parser.parse(expression);
      final ContextModel cm = ContextModel()..bindVariable(Variable('x'), Number(x));
      final dynamic result = exp.evaluate(EvaluationType.REAL, cm);
      final double value = result is double ? result : (result as num).toDouble();
      return value.isFinite ? value : null;
    } catch (_) {
      return null;
    }
  }

  /// Returns a human-readable error message if [expression] cannot be parsed,
  /// or null when the expression is valid.
  static String? validate(String expression) {
    if (expression.trim().isEmpty) return 'Expression cannot be empty';
    try {
      _parser.parse(expression);
      return null;
    } catch (e) {
      return 'Invalid expression';
    }
  }
}
