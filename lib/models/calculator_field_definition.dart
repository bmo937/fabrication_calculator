import 'dart:convert';

class CalculatorFieldDefinition {
  const CalculatorFieldDefinition({required this.key, required this.label});

  final String key;
  final String label;

  Map<String, dynamic> toJson() => <String, dynamic>{'key': key, 'label': label};

  factory CalculatorFieldDefinition.fromJson(Map<String, dynamic> json) {
    return CalculatorFieldDefinition(key: (json['key'] as String? ?? '').trim(), label: (json['label'] as String? ?? '').trim());
  }

  static String listToJson(List<CalculatorFieldDefinition> definitions) {
    return jsonEncode(definitions.map((CalculatorFieldDefinition e) => e.toJson()).toList());
  }

  static List<CalculatorFieldDefinition> listFromJson(String? jsonString) {
    if (jsonString == null || jsonString.trim().isEmpty) {
      return <CalculatorFieldDefinition>[];
    }
    final List<dynamic> list = jsonDecode(jsonString) as List<dynamic>;
    return list
        .map((dynamic e) => CalculatorFieldDefinition.fromJson(e as Map<String, dynamic>))
        .where((CalculatorFieldDefinition d) => d.key.isNotEmpty && d.label.isNotEmpty)
        .toList();
  }

  static String sanitizeKey(String raw) {
    final String normalized = raw.trim().replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    if (normalized.isEmpty) {
      return 'value';
    }
    if (RegExp(r'^[0-9]').hasMatch(normalized)) {
      return 'v_$normalized';
    }
    return normalized;
  }
}
