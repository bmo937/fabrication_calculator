import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';

class TraditionalCalculatorScreen extends StatefulWidget {
  const TraditionalCalculatorScreen({super.key});

  @override
  State<TraditionalCalculatorScreen> createState() => _TraditionalCalculatorScreenState();
}

class _TraditionalCalculatorScreenState extends State<TraditionalCalculatorScreen> {
  String _expression = '';
  String _display = '0';
  final List<_HistoryEntry> _history = <_HistoryEntry>[];

  static const List<String> _buttons = <String>['C', '⌫', '%', '/', '7', '8', '9', '*', '4', '5', '6', '-', '1', '2', '3', '+', '()', '0', '.', '='];

  static const Set<String> _operators = <String>{'+', '-', '*', '/', '%'};

  void _onButtonPressed(String token) {
    switch (token) {
      case 'C':
        setState(() {
          _expression = '';
          _display = '0';
        });
        return;
      case '⌫':
        if (_expression.isEmpty) return;
        setState(() {
          _expression = _expression.substring(0, _expression.length - 1);
          _display = _expression.isEmpty ? '0' : _expression;
        });
        return;
      case '()':
        _appendBracketFromSingleButton();
        return;
      case '=':
        _evaluateExpression();
        return;
      default:
        setState(() {
          _expression += token;
          _display = _expression;
        });
        return;
    }
  }

  void _appendBracketFromSingleButton() {
    final int openCount = '('.allMatches(_expression).length;
    final int closeCount = ')'.allMatches(_expression).length;
    final bool canClose = openCount > closeCount;
    final bool shouldOpen = _expression.isEmpty || _expression.endsWith('(') || _operators.contains(_expression[_expression.length - 1]);

    setState(() {
      if (shouldOpen || !canClose) {
        _expression += '(';
      } else {
        _expression += ')';
      }
      _display = _expression;
    });
  }

  void _evaluateExpression() {
    if (_expression.trim().isEmpty) return;

    try {
      final String inputExpression = _expression;
      final String normalized = _expression.replaceAll('×', '*').replaceAll('÷', '/').replaceAll('π', 'pi').replaceAll('−', '-').replaceAll(',', '.');

      final GrammarParser parser = GrammarParser();
      final Expression exp = parser.parse(normalized);
      final ContextModel contextModel = ContextModel();
      final double value = exp.evaluate(EvaluationType.REAL, contextModel);
      final String formattedValue = _formatValue(value);

      setState(() {
        _history.insert(0, _HistoryEntry(expression: inputExpression, result: formattedValue, timestamp: DateTime.now()));
        _display = formattedValue;
        _expression = _display;
      });
    } catch (_) {
      setState(() {
        _display = 'Error';
      });
    }
  }

  String _formatValue(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsPrecision(12).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  String _formatMinuteTimestamp(DateTime time) {
    final String year = time.year.toString().padLeft(4, '0');
    final String month = time.month.toString().padLeft(2, '0');
    final String day = time.day.toString().padLeft(2, '0');
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  void _showHistoryBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: _history.isEmpty
                ? Center(child: Text('No history yet', style: Theme.of(context).textTheme.titleMedium))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                    itemCount: _history.length,
                    itemBuilder: (BuildContext context, int index) {
                      final _HistoryEntry entry = _history[index];
                      return ListTile(
                        title: Text('${entry.expression} = ${entry.result}'),
                        subtitle: Text(_formatMinuteTimestamp(entry.timestamp)),
                        onTap: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _expression = entry.result;
                            _display = entry.result;
                          });
                        },
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(onPressed: _showHistoryBottomSheet, icon: const Icon(Icons.history), label: const Text('History')),
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            alignment: Alignment.bottomRight,
            child: Text(
              _display,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 62, fontWeight: FontWeight.w500),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              const int columns = 4;
              const int rows = 5;
              const double spacing = 8;
              final double gridWidth = constraints.maxWidth - 24;
              final double gridHeight = constraints.maxHeight - 12;
              final double tileWidth = (gridWidth - (columns - 1) * spacing) / columns;
              final double tileHeight = (gridHeight - (rows - 1) * spacing) / rows;

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: tileWidth / tileHeight,
                ),
                itemCount: _buttons.length,
                itemBuilder: (BuildContext context, int index) {
                  final String token = _buttons[index];
                  final bool isOperator = <String>{'/', '*', '-', '+', '=', '%'}.contains(token);

                  return FilledButton.tonal(
                    style: FilledButton.styleFrom(backgroundColor: isOperator ? Theme.of(context).colorScheme.primaryContainer : null),
                    onPressed: () => _onButtonPressed(token),
                    child: Text(token, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.w600)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryEntry {
  const _HistoryEntry({required this.expression, required this.result, required this.timestamp});

  final String expression;
  final String result;
  final DateTime timestamp;
}
