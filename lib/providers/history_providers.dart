import 'package:fabrication_calculator/models/history_entry.dart';
import 'package:fabrication_calculator/repositories/history_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const int historyLimitPerCalculator = 100;

final historyRepositoryProvider = Provider<HistoryRepository>((Ref ref) {
  return HistoryRepository();
});

final historyFilterCalculatorProvider = StateProvider<String?>((Ref ref) {
  return null;
});

final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, List<HistoryEntry>>(
  HistoryController.new,
);

class HistoryController extends AsyncNotifier<List<HistoryEntry>> {
  @override
  Future<List<HistoryEntry>> build() async {
    final String? calculator = ref.watch(historyFilterCalculatorProvider);
    return _repository.loadHistory(
      calculatorName: calculator,
      limit: historyLimitPerCalculator,
    );
  }

  HistoryRepository get _repository => ref.read(historyRepositoryProvider);

  Future<void> refresh() async {
    final String? calculator = ref.read(historyFilterCalculatorProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repository.loadHistory(
        calculatorName: calculator,
        limit: historyLimitPerCalculator,
      ),
    );
  }

  Future<void> loadForCalculator(String? calculatorName) async {
    ref.read(historyFilterCalculatorProvider.notifier).state = calculatorName;
  }

  Future<void> saveEntry(HistoryEntry entry) async {
    await _repository.saveEntry(
      entry,
      maxEntriesPerCalculator: historyLimitPerCalculator,
    );
    await refresh();
  }
}
