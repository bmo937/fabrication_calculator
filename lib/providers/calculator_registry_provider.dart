import 'package:fabrication_calculator/models/calculator_group.dart';
import 'package:fabrication_calculator/models/managed_calculator.dart';
import 'package:fabrication_calculator/repositories/calculator_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

final calculatorRepositoryProvider = Provider<CalculatorRepository>((Ref ref) => CalculatorRepository());

// ── Groups ───────────────────────────────────────────────────────────────────

final calculatorGroupsProvider = AsyncNotifierProvider<CalculatorGroupsNotifier, List<CalculatorGroup>>(CalculatorGroupsNotifier.new);

class CalculatorGroupsNotifier extends AsyncNotifier<List<CalculatorGroup>> {
  CalculatorRepository get _repo => ref.read(calculatorRepositoryProvider);

  @override
  Future<List<CalculatorGroup>> build() async => _repo.getGroups();

  Future<void> add(String name) async {
    final List<CalculatorGroup> current = state.valueOrNull ?? <CalculatorGroup>[];
    final CalculatorGroup group = CalculatorGroup(id: _uuid.v4(), name: name, sortOrder: current.length);
    await _repo.saveGroup(group);
    ref.invalidateSelf();
  }

  Future<void> updateGroup(CalculatorGroup group) async {
    await _repo.saveGroup(group);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await _repo.deleteGroup(id);
    // Cascade delete handled in repo; refresh calculators too
    ref.invalidate(managedCalculatorsProvider);
    ref.invalidateSelf();
  }
}

// ── Managed Calculators ──────────────────────────────────────────────────────

final managedCalculatorsProvider = AsyncNotifierProvider<ManagedCalculatorsNotifier, List<ManagedCalculator>>(ManagedCalculatorsNotifier.new);

class ManagedCalculatorsNotifier extends AsyncNotifier<List<ManagedCalculator>> {
  CalculatorRepository get _repo => ref.read(calculatorRepositoryProvider);

  @override
  Future<List<ManagedCalculator>> build() async => _repo.getCalculators();

  Future<void> add(ManagedCalculator calculator) async {
    await _repo.saveCalculator(calculator);
    ref.invalidateSelf();
  }

  Future<void> saveDraft(ManagedCalculator calculator) async {
    await _repo.saveDraft(calculator);
    ref.invalidateSelf();
  }

  Future<void> updateCalculator(ManagedCalculator calculator) async {
    await _repo.saveCalculator(calculator);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await _repo.deleteCalculator(id);
    ref.invalidateSelf();
  }

  Future<void> duplicate(String id) async {
    final List<ManagedCalculator> current = state.valueOrNull ?? <ManagedCalculator>[];
    final ManagedCalculator? original = current.where((ManagedCalculator c) => c.id == id).firstOrNull;
    if (original == null) return;
    final int count = current.where((ManagedCalculator c) => c.groupId == original.groupId).length;
    final ManagedCalculator copy = original.copyWith(
      id: _uuid.v4(),
      name: '${original.name} (Copy)',
      sortOrder: count,
      isDraft: true,
      sandboxTestPassed: false,
      clearPublishedAt: true,
    );
    await _repo.saveCalculator(copy);
    ref.invalidateSelf();
  }

  Future<void> updateSandboxTestResult(String id, {required bool passed}) async {
    await _repo.updateSandboxTestResult(id, passed: passed);
    ref.invalidateSelf();
  }

  Future<void> publish(String id) async {
    await _repo.publishCalculator(id);
    ref.invalidateSelf();
  }
}

// ── Derived ──────────────────────────────────────────────────────────────────

/// Returns calculators for [groupId], sorted by sortOrder.
final calculatorsByGroupProvider = Provider.family<List<ManagedCalculator>, String>((Ref ref, String groupId) {
  final List<ManagedCalculator> all = ref.watch(managedCalculatorsProvider).valueOrNull ?? <ManagedCalculator>[];
  return all.where((ManagedCalculator c) => c.groupId == groupId && !c.isDraft).toList()..sort((ManagedCalculator a, ManagedCalculator b) => a.sortOrder.compareTo(b.sortOrder));
});

final draftCalculatorsByGroupProvider = Provider.family<List<ManagedCalculator>, String>((Ref ref, String groupId) {
  final List<ManagedCalculator> all = ref.watch(managedCalculatorsProvider).valueOrNull ?? <ManagedCalculator>[];
  return all.where((ManagedCalculator c) => c.groupId == groupId && c.isDraft).toList()..sort((ManagedCalculator a, ManagedCalculator b) => a.sortOrder.compareTo(b.sortOrder));
});
