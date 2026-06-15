import 'package:fabrication_calculator/models/calculator_group.dart';
import 'package:fabrication_calculator/models/managed_calculator.dart';
import 'package:hive/hive.dart';

class CalculatorRepository {
  static const String _groupsBoxName = 'calculator_groups';
  static const String _calculatorsBoxName = 'managed_calculators';

  Future<Box<CalculatorGroup>> _openGroupsBox() async {
    if (Hive.isBoxOpen(_groupsBoxName)) {
      return Hive.box<CalculatorGroup>(_groupsBoxName);
    }
    return Hive.openBox<CalculatorGroup>(_groupsBoxName);
  }

  Future<Box<ManagedCalculator>> _openCalculatorsBox() async {
    if (Hive.isBoxOpen(_calculatorsBoxName)) {
      return Hive.box<ManagedCalculator>(_calculatorsBoxName);
    }
    return Hive.openBox<ManagedCalculator>(_calculatorsBoxName);
  }

  Future<List<CalculatorGroup>> getGroups() async {
    final Box<CalculatorGroup> box = await _openGroupsBox();
    return box.values.toList()..sort((CalculatorGroup a, CalculatorGroup b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<void> saveGroup(CalculatorGroup group) async {
    final Box<CalculatorGroup> box = await _openGroupsBox();
    await box.put(group.id, group);
  }

  Future<void> updateGroupSortOrders(List<CalculatorGroup> groups) async {
    final Box<CalculatorGroup> box = await _openGroupsBox();
    final Map<String, CalculatorGroup> updates = <String, CalculatorGroup>{for (final CalculatorGroup group in groups) group.id: group};
    await box.putAll(updates);
  }

  Future<void> deleteGroup(String groupId) async {
    final Box<CalculatorGroup> groupBox = await _openGroupsBox();
    await groupBox.delete(groupId);

    // Cascade-delete all calculators belonging to this group
    final Box<ManagedCalculator> calcBox = await _openCalculatorsBox();
    final List<String> keysToDelete = calcBox.values.where((ManagedCalculator c) => c.groupId == groupId).map((ManagedCalculator c) => c.id).toList();
    await calcBox.deleteAll(keysToDelete);
  }

  Future<List<ManagedCalculator>> getCalculators({String? groupId, bool includeDrafts = true}) async {
    final Box<ManagedCalculator> box = await _openCalculatorsBox();
    final Iterable<ManagedCalculator> scoped = groupId == null ? box.values : box.values.where((ManagedCalculator c) => c.groupId == groupId);
    final Iterable<ManagedCalculator> all = includeDrafts ? scoped : scoped.where((ManagedCalculator c) => !c.isDraft);
    return all.toList()..sort((ManagedCalculator a, ManagedCalculator b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<List<ManagedCalculator>> getDraftCalculators({String? groupId}) async {
    final Box<ManagedCalculator> box = await _openCalculatorsBox();
    final Iterable<ManagedCalculator> scoped = groupId == null ? box.values : box.values.where((ManagedCalculator c) => c.groupId == groupId);
    final Iterable<ManagedCalculator> drafts = scoped.where((ManagedCalculator c) => c.isDraft);
    return drafts.toList()..sort((ManagedCalculator a, ManagedCalculator b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<void> saveCalculator(ManagedCalculator calculator) async {
    final Box<ManagedCalculator> box = await _openCalculatorsBox();
    await box.put(calculator.id, calculator);
  }

  Future<void> updateCalculatorSortOrders(List<ManagedCalculator> calculators) async {
    final Box<ManagedCalculator> box = await _openCalculatorsBox();
    final Map<String, ManagedCalculator> updates = <String, ManagedCalculator>{for (final ManagedCalculator calculator in calculators) calculator.id: calculator};
    await box.putAll(updates);
  }

  Future<void> saveDraft(ManagedCalculator calculator) async {
    final Box<ManagedCalculator> box = await _openCalculatorsBox();
    await box.put(calculator.id, calculator.copyWith(isDraft: true, clearPublishedAt: true));
  }

  Future<void> updateSandboxTestResult(String calculatorId, {required bool passed}) async {
    final Box<ManagedCalculator> box = await _openCalculatorsBox();
    final ManagedCalculator? calculator = box.get(calculatorId);
    if (calculator == null) return;

    await box.put(calculator.id, calculator.copyWith(sandboxTestPassed: passed, lastSandboxTestAt: DateTime.now()));
  }

  Future<void> publishCalculator(String calculatorId) async {
    final Box<ManagedCalculator> box = await _openCalculatorsBox();
    final ManagedCalculator? calculator = box.get(calculatorId);
    if (calculator == null) return;
    if (!calculator.sandboxTestPassed) {
      throw StateError('Calculator must pass sandbox test before publishing.');
    }

    await box.put(calculator.id, calculator.copyWith(isDraft: false, publishedAt: DateTime.now()));
  }

  Future<void> deleteCalculator(String calculatorId) async {
    final Box<ManagedCalculator> box = await _openCalculatorsBox();
    await box.delete(calculatorId);
  }
}
