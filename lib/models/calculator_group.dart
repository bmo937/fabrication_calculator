import 'package:hive/hive.dart';

part 'calculator_group.g.dart';

@HiveType(typeId: 2)
class CalculatorGroup {
  const CalculatorGroup({required this.id, required this.name, this.sortOrder = 0});

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int sortOrder;

  CalculatorGroup copyWith({String? id, String? name, int? sortOrder}) {
    return CalculatorGroup(id: id ?? this.id, name: name ?? this.name, sortOrder: sortOrder ?? this.sortOrder);
  }
}
