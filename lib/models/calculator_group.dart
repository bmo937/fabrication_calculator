import 'package:hive/hive.dart';

part 'calculator_group.g.dart';

@HiveType(typeId: 2)
class CalculatorGroup {
  const CalculatorGroup({required this.id, required this.name, this.sortOrder = 0, this.iconKey = 'folder'});

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int sortOrder;

  @HiveField(3)
  final String iconKey;

  CalculatorGroup copyWith({String? id, String? name, int? sortOrder, String? iconKey}) {
    return CalculatorGroup(id: id ?? this.id, name: name ?? this.name, sortOrder: sortOrder ?? this.sortOrder, iconKey: iconKey ?? this.iconKey);
  }
}
