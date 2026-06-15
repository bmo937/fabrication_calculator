class FormulaIconOption {
  const FormulaIconOption({required this.key, required this.label, required this.glyph});

  final String key;
  final String label;
  final String glyph;

  Map<String, String> toJson() {
    return <String, String>{'key': key, 'label': label, 'glyph': glyph};
  }

  static FormulaIconOption? fromJson(Map<String, dynamic> json) {
    final String? key = json['key'] as String?;
    final String? label = json['label'] as String?;
    final String? glyph = json['glyph'] as String?;
    if (key == null || label == null || glyph == null) {
      return null;
    }
    if (key.trim().isEmpty || label.trim().isEmpty || glyph.trim().isEmpty) {
      return null;
    }
    return FormulaIconOption(key: key.trim(), label: label.trim(), glyph: glyph.trim());
  }
}

const List<FormulaIconOption> formulaIconOptions = <FormulaIconOption>[
  FormulaIconOption(key: 'folder', label: 'Folder', glyph: '⌂'),
  FormulaIconOption(key: 'function', label: 'Function', glyph: '\u0192'),
  FormulaIconOption(key: 'notch', label: 'Notch', glyph: '⌴'),
  FormulaIconOption(key: 'coil', label: 'Coil', glyph: '⑁'),
  FormulaIconOption(key: 'square', label: 'Square', glyph: '□'),
  FormulaIconOption(key: 'rectangle', label: 'Rectangle', glyph: '▭'),
  FormulaIconOption(key: 'triangle', label: 'Triangle', glyph: '△'),
  FormulaIconOption(key: 'hexagon', label: 'Hexagon', glyph: '⬡'),
  FormulaIconOption(key: 'circle', label: 'Circle', glyph: '○'),
  FormulaIconOption(key: 'diamond', label: 'Diamond', glyph: '◇'),
  FormulaIconOption(key: 'star', label: 'Star', glyph: '★'),
  FormulaIconOption(key: 'gear', label: 'Gear', glyph: '⚙'),
  FormulaIconOption(key: 'bolt', label: 'Bolt', glyph: '⚡'),
  FormulaIconOption(key: 'hammer', label: 'Hammer', glyph: '⚒'),
  FormulaIconOption(key: 'wrench', label: 'Wrench', glyph: '🔧'),
  FormulaIconOption(key: 'ruler', label: 'Ruler', glyph: '📏'),
  FormulaIconOption(key: 'caliper', label: 'Caliper', glyph: '⟂'),
  FormulaIconOption(key: 'cube', label: 'Cube', glyph: '◫'),
  FormulaIconOption(key: 'pipe', label: 'Pipe', glyph: '⊙'),
  FormulaIconOption(key: 'angle', label: 'Angle', glyph: '∠'),
  FormulaIconOption(key: 'sum', label: 'Sigma', glyph: '∑'),
  FormulaIconOption(key: 'delta', label: 'Delta', glyph: 'Δ'),
  FormulaIconOption(key: 'ratio', label: 'Ratio', glyph: '÷'),
  FormulaIconOption(key: 'target', label: 'Target', glyph: '◎'),
];

List<FormulaIconOption> mergeFormulaIconOptions(List<FormulaIconOption> customIcons) {
  final Map<String, FormulaIconOption> merged = <String, FormulaIconOption>{for (final FormulaIconOption option in formulaIconOptions) option.key: option};
  for (final FormulaIconOption option in customIcons) {
    merged[option.key] = option;
  }
  return merged.values.toList();
}

FormulaIconOption formulaIconByKey(String key, {List<FormulaIconOption>? options}) {
  final List<FormulaIconOption> source = options ?? formulaIconOptions;
  return source.where((FormulaIconOption option) => option.key == key).firstOrNull ?? source.first;
}
