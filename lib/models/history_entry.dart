import 'package:hive/hive.dart';

part 'history_entry.g.dart';

@HiveType(typeId: 1)
class HistoryEntry {
  const HistoryEntry({required this.calculatorName, required this.inputs, required this.result, required this.timestamp});

  @HiveField(0)
  final String calculatorName;

  @HiveField(1)
  final Map<String, double> inputs;

  @HiveField(2)
  final double result;

  @HiveField(3)
  final DateTime timestamp;
}
