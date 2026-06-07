class FormulaIconOption {
  const FormulaIconOption({required this.key, required this.label, required this.glyph});

  final String key;
  final String label;
  final String glyph;
}

const List<FormulaIconOption> formulaIconOptions = <FormulaIconOption>[
  FormulaIconOption(key: 'function', label: 'Function', glyph: '\u0192'),
  FormulaIconOption(key: 'notch', label: 'Notch', glyph: '⌴'),
  FormulaIconOption(key: 'coil', label: 'Coil', glyph: '⑁'),
  FormulaIconOption(key: 'square', label: 'Square', glyph: '□'),
  FormulaIconOption(key: 'rectangle', label: 'Rectangle', glyph: '▭'),
  FormulaIconOption(key: 'triangle', label: 'Triangle', glyph: '△'),
  FormulaIconOption(key: 'hexagon', label: 'Hexagon', glyph: '⬡'),
];

FormulaIconOption formulaIconByKey(String key) {
  return formulaIconOptions.where((FormulaIconOption option) => option.key == key).firstOrNull ?? formulaIconOptions.first;
}
