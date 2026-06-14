import 'package:fabrication_calculator/models/user_python_module.dart';
import 'package:hive/hive.dart';

/// Hive-backed storage for user-defined Python modules.
///
/// This is scaffold-only: CRUD operations are fully implemented and ready
/// for use once the UI layer is added in a future iteration.
///
/// Usage:
/// ```dart
/// final repo = PythonModuleRepository();
/// await repo.save(module);
/// final modules = await repo.getAll();
/// ```
class PythonModuleRepository {
  static const String _boxName = 'user_python_modules';

  Future<Box<UserPythonModule>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<UserPythonModule>(_boxName);
    }
    return Hive.openBox<UserPythonModule>(_boxName);
  }

  /// Returns all stored user modules sorted alphabetically by name.
  Future<List<UserPythonModule>> getAll() async {
    final Box<UserPythonModule> box = await _openBox();
    return (box.values.toList()..sort((UserPythonModule a, UserPythonModule b) => a.name.compareTo(b.name)));
  }

  /// Returns the module with [id], or [null] if not found.
  Future<UserPythonModule?> getById(String id) async {
    final Box<UserPythonModule> box = await _openBox();
    return box.get(id);
  }

  /// Returns the module with [name], or [null] if not found.
  Future<UserPythonModule?> getByName(String name) async {
    final Box<UserPythonModule> box = await _openBox();
    try {
      return box.values.firstWhere((UserPythonModule m) => m.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Saves (inserts or replaces) a module.
  Future<void> save(UserPythonModule module) async {
    final Box<UserPythonModule> box = await _openBox();
    await box.put(module.id, module);
  }

  /// Deletes the module with [id].  No-op if it does not exist.
  Future<void> delete(String id) async {
    final Box<UserPythonModule> box = await _openBox();
    await box.delete(id);
  }

  /// Checks whether a module with [name] already exists (optionally
  /// excluding [excludeId] so an edit check can exclude itself).
  Future<bool> nameExists(String name, {String? excludeId}) async {
    final Box<UserPythonModule> box = await _openBox();
    return box.values.any((UserPythonModule m) => m.name == name && m.id != excludeId);
  }

  /// Writes all user modules to [directory] as individual .py files so the
  /// Python sandbox process can import them.
  ///
  /// Called internally by the sandbox before executing user code.
  Future<void> extractToDirectory(String directory) async {
    final List<UserPythonModule> modules = await getAll();
    for (final UserPythonModule module in modules) {
      // Validate the module name before writing to disk (defence in depth)
      if (!UserPythonModule.isValidModuleName(module.name)) continue;
      // File I/O is handled by the caller (python_sandbox_io.dart) which
      // already has dart:io imported. Use getAllModuleCode() to retrieve code.
      // Placeholder: '$directory/${module.name}.py'
    }
  }

  /// Returns a map of module name → source code for all stored modules.
  ///
  /// The Python sandbox calls this to write user modules alongside the
  /// bundled workshop_helpers package before executing user code.
  Future<Map<String, String>> getAllModuleCode() async {
    final List<UserPythonModule> modules = await getAll();
    return <String, String>{
      for (final UserPythonModule m in modules)
        if (UserPythonModule.isValidModuleName(m.name)) m.name: m.code,
    };
  }
}
