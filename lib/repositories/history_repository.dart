import 'package:fabrication_calculator/models/history_entry.dart';
import 'package:hive/hive.dart';

class HistoryRepository {
  static const String historyBoxName = 'history_entries';

  Future<Box<HistoryEntry>> openBox() async {
    if (Hive.isBoxOpen(historyBoxName)) {
      return Hive.box<HistoryEntry>(historyBoxName);
    }
    return Hive.openBox<HistoryEntry>(historyBoxName);
  }

  Future<void> saveEntry(
    HistoryEntry entry, {
    int maxEntriesPerCalculator = 100,
  }) async {
    final Box<HistoryEntry> box = await openBox();
    await box.add(entry);
    await _trimCalculatorHistory(
      box,
      calculatorName: entry.calculatorName,
      maxEntriesPerCalculator: maxEntriesPerCalculator,
    );
  }

  Future<List<HistoryEntry>> loadHistory({
    String? calculatorName,
    int limit = 100,
  }) async {
    final Box<HistoryEntry> box = await openBox();

    final List<HistoryEntry> entries = box.values
        .where(
          (HistoryEntry entry) =>
              calculatorName == null || entry.calculatorName == calculatorName,
        )
        .toList()
      ..sort((HistoryEntry a, HistoryEntry b) => b.timestamp.compareTo(a.timestamp));

    if (entries.length <= limit) {
      return entries;
    }
    return entries.sublist(0, limit);
  }

  Future<void> _trimCalculatorHistory(
    Box<HistoryEntry> box, {
    required String calculatorName,
    required int maxEntriesPerCalculator,
  }) async {
    final List<MapEntry<dynamic, HistoryEntry>> calculatorEntries = box.toMap().entries
        .where((MapEntry<dynamic, HistoryEntry> e) => e.value.calculatorName == calculatorName)
        .toList()
      ..sort(
        (MapEntry<dynamic, HistoryEntry> a, MapEntry<dynamic, HistoryEntry> b) =>
            b.value.timestamp.compareTo(a.value.timestamp),
      );

    if (calculatorEntries.length <= maxEntriesPerCalculator) {
      return;
    }

    final Iterable<dynamic> keysToDelete = calculatorEntries
        .skip(maxEntriesPerCalculator)
        .map((MapEntry<dynamic, HistoryEntry> e) => e.key);
    await box.deleteAll(keysToDelete);
  }
}
