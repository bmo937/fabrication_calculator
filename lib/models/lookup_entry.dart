import 'dart:convert';

/// A single input→output mapping entry used in lookup-table calculators.
/// Lists are JSON-serialized inside [ManagedCalculator.lookupEntriesJson].
class LookupEntry {
  const LookupEntry({required this.inputValue, required this.outputValue, this.label = ''});

  final double inputValue;
  final double outputValue;
  final String label;

  factory LookupEntry.fromJson(Map<String, dynamic> json) {
    return LookupEntry(inputValue: (json['input'] as num).toDouble(), outputValue: (json['output'] as num).toDouble(), label: (json['label'] as String?) ?? '');
  }

  Map<String, dynamic> toJson() => <String, dynamic>{'input': inputValue, 'output': outputValue, 'label': label};

  static List<LookupEntry> listFromJson(String jsonString) {
    final List<dynamic> list = jsonDecode(jsonString) as List<dynamic>;
    return list.map((dynamic e) => LookupEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<LookupEntry> entries) {
    return jsonEncode(entries.map((LookupEntry e) => e.toJson()).toList());
  }

  /// Looks up [input] in [entries] using linear interpolation between adjacent
  /// entries. Clamps to the nearest boundary when out of range.
  /// Returns null only when [entries] is empty.
  static double? interpolate(List<LookupEntry> entries, double input) {
    if (entries.isEmpty) return null;
    if (entries.length == 1) return entries.first.outputValue;

    final List<LookupEntry> sorted = List<LookupEntry>.from(entries)..sort((LookupEntry a, LookupEntry b) => a.inputValue.compareTo(b.inputValue));

    // Exact match
    for (final LookupEntry e in sorted) {
      if (e.inputValue == input) return e.outputValue;
    }

    // Clamp below range
    if (input < sorted.first.inputValue) return sorted.first.outputValue;

    // Clamp above range
    if (input > sorted.last.inputValue) return sorted.last.outputValue;

    // Linear interpolation between adjacent entries
    for (int i = 0; i < sorted.length - 1; i++) {
      if (input >= sorted[i].inputValue && input <= sorted[i + 1].inputValue) {
        final double t = (input - sorted[i].inputValue) / (sorted[i + 1].inputValue - sorted[i].inputValue);
        return sorted[i].outputValue + t * (sorted[i + 1].outputValue - sorted[i].outputValue);
      }
    }

    return null;
  }
}
