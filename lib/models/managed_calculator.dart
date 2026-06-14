import 'package:fabrication_calculator/models/calculator_field_definition.dart';
import 'package:hive/hive.dart';

part 'managed_calculator.g.dart';

@HiveType(typeId: 3)
class ManagedCalculator {
  const ManagedCalculator({
    required this.id,
    required this.groupId,
    required this.name,
    required this.calculatorType,
    required this.inputLabel,
    required this.outputLabel,
    this.formulaExpression,
    this.lookupEntriesJson,
    this.sortOrder = 0,
    this.description = '',
    this.isDraft = false,
    this.sandboxTestPassed = false,
    this.lastSandboxTestAt,
    this.publishedAt,
    this.codeBody = '',
    this.inputDefinitionsJson = '',
    this.outputDefinitionsJson = '',
    this.sandboxLastError = '',
    this.codeLanguage = 'math',
    this.iconKey = 'function',
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String groupId;

  @HiveField(2)
  final String name;

  /// 'formula' or 'lookup'
  @HiveField(3)
  final String calculatorType;

  @HiveField(4)
  final String inputLabel;

  @HiveField(5)
  final String outputLabel;

  /// Math expression using 'x' as the input variable, e.g. "x * 25.4"
  @HiveField(6)
  final String? formulaExpression;

  /// JSON-encoded list of LookupEntry objects
  @HiveField(7)
  final String? lookupEntriesJson;

  @HiveField(8)
  final int sortOrder;

  @HiveField(9)
  final String description;

  @HiveField(10)
  final bool isDraft;

  @HiveField(11)
  final bool sandboxTestPassed;

  @HiveField(12)
  final DateTime? lastSandboxTestAt;

  @HiveField(13)
  final DateTime? publishedAt;

  @HiveField(14)
  final String codeBody;

  @HiveField(15)
  final String inputDefinitionsJson;

  @HiveField(16)
  final String outputDefinitionsJson;

  @HiveField(17)
  final String sandboxLastError;

  @HiveField(18)
  final String codeLanguage;

  @HiveField(19)
  final String iconKey;

  static const String mathLanguage = 'math';
  static const String pythonLanguage = 'python';
  static const Set<String> supportedCodeLanguages = <String>{mathLanguage, pythonLanguage};

  static bool isSupportedCodeLanguage(String language) => supportedCodeLanguages.contains(language);

  static String normalizeCodeLanguage(String language) {
    return isSupportedCodeLanguage(language) ? language : mathLanguage;
  }

  String get normalizedCodeLanguage => normalizeCodeLanguage(codeLanguage);

  bool get isPublished => !isDraft;

  List<CalculatorFieldDefinition> get inputDefinitions {
    final List<CalculatorFieldDefinition> parsed = CalculatorFieldDefinition.listFromJson(inputDefinitionsJson);
    if (parsed.isNotEmpty) {
      return parsed;
    }
    return <CalculatorFieldDefinition>[CalculatorFieldDefinition(key: 'x', label: inputLabel)];
  }

  List<CalculatorFieldDefinition> get outputDefinitions {
    final List<CalculatorFieldDefinition> parsed = CalculatorFieldDefinition.listFromJson(outputDefinitionsJson);
    if (parsed.isNotEmpty) {
      return parsed;
    }
    return <CalculatorFieldDefinition>[CalculatorFieldDefinition(key: 'result', label: outputLabel)];
  }

  ManagedCalculator copyWith({
    String? id,
    String? groupId,
    String? name,
    String? calculatorType,
    String? inputLabel,
    String? outputLabel,
    String? formulaExpression,
    String? lookupEntriesJson,
    int? sortOrder,
    String? description,
    bool? isDraft,
    bool? sandboxTestPassed,
    DateTime? lastSandboxTestAt,
    DateTime? publishedAt,
    String? codeBody,
    String? inputDefinitionsJson,
    String? outputDefinitionsJson,
    String? sandboxLastError,
    String? codeLanguage,
    String? iconKey,
    bool clearLastSandboxTestAt = false,
    bool clearPublishedAt = false,
  }) {
    return ManagedCalculator(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      calculatorType: calculatorType ?? this.calculatorType,
      inputLabel: inputLabel ?? this.inputLabel,
      outputLabel: outputLabel ?? this.outputLabel,
      formulaExpression: formulaExpression ?? this.formulaExpression,
      lookupEntriesJson: lookupEntriesJson ?? this.lookupEntriesJson,
      sortOrder: sortOrder ?? this.sortOrder,
      description: description ?? this.description,
      isDraft: isDraft ?? this.isDraft,
      sandboxTestPassed: sandboxTestPassed ?? this.sandboxTestPassed,
      lastSandboxTestAt: clearLastSandboxTestAt ? null : (lastSandboxTestAt ?? this.lastSandboxTestAt),
      publishedAt: clearPublishedAt ? null : (publishedAt ?? this.publishedAt),
      codeBody: codeBody ?? this.codeBody,
      inputDefinitionsJson: inputDefinitionsJson ?? this.inputDefinitionsJson,
      outputDefinitionsJson: outputDefinitionsJson ?? this.outputDefinitionsJson,
      sandboxLastError: sandboxLastError ?? this.sandboxLastError,
      codeLanguage: codeLanguage ?? this.codeLanguage,
      iconKey: iconKey ?? this.iconKey,
    );
  }
}
