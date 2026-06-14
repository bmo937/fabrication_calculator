import 'package:hive/hive.dart';

part 'user_python_module.g.dart';

/// A user-defined Python helper module stored in Hive.
///
/// Users can create reusable Python code snippets that can be imported
/// inside Python calculators via:
///   ```python
///   from workshop_helpers.user_modules import <module_name>
///   ```
///
/// This model is scaffolding only – the UI for managing modules is not
/// yet implemented.  Backend storage and import resolution are ready.
@HiveType(typeId: 4)
class UserPythonModule {
  const UserPythonModule({required this.id, required this.name, required this.code, this.description = '', required this.createdAt, required this.updatedAt});

  /// Unique identifier (UUID v4).
  @HiveField(0)
  final String id;

  /// Module name – must be a valid Python identifier (letters, digits, _).
  /// Used as the filename (e.g. "my_helpers" → my_helpers.py) and as the
  /// name other calculators import.
  @HiveField(1)
  final String name;

  /// Full Python source code of the module.
  @HiveField(2)
  final String code;

  /// Optional human-readable description shown in the module list.
  @HiveField(3)
  final String description;

  /// When the module was first created.
  @HiveField(4)
  final DateTime createdAt;

  /// When the module was last saved.
  @HiveField(5)
  final DateTime updatedAt;

  /// Returns [true] if [name] is a valid Python identifier.
  static bool isValidModuleName(String name) {
    return RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(name);
  }

  UserPythonModule copyWith({String? id, String? name, String? code, String? description, DateTime? createdAt, DateTime? updatedAt}) {
    return UserPythonModule(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
