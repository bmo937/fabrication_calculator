import 'dart:convert';

import 'package:fabrication_calculator/models/formula_icon_option.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

const String _iconCatalogBoxName = 'icon_catalog';
const String _customIconsKey = 'custom_icons_v1';

final iconCatalogProvider = AsyncNotifierProvider<IconCatalogNotifier, List<FormulaIconOption>>(IconCatalogNotifier.new);

Future<Box<String>> _openIconCatalogBox() async {
  if (Hive.isBoxOpen(_iconCatalogBoxName)) {
    return Hive.box<String>(_iconCatalogBoxName);
  }
  return Hive.openBox<String>(_iconCatalogBoxName);
}

class IconCatalogNotifier extends AsyncNotifier<List<FormulaIconOption>> {
  @override
  Future<List<FormulaIconOption>> build() async {
    final Box<String> box = await _openIconCatalogBox();
    final String raw = box.get(_customIconsKey, defaultValue: '[]') ?? '[]';
    final List<FormulaIconOption> customIcons = _decodeCustomIcons(raw);
    return mergeFormulaIconOptions(customIcons);
  }

  Future<FormulaIconOption> addCustomIcon({required String glyph, required String label}) async {
    final String normalizedGlyph = glyph.trim();
    final String normalizedLabel = label.trim();
    if (normalizedGlyph.isEmpty || normalizedLabel.isEmpty) {
      throw ArgumentError('Icon glyph and label are required.');
    }

    final Box<String> box = await _openIconCatalogBox();
    final String raw = box.get(_customIconsKey, defaultValue: '[]') ?? '[]';
    final List<FormulaIconOption> customIcons = _decodeCustomIcons(raw);

    final String base = normalizedLabel.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    final String stem = base.isEmpty ? 'custom' : base;
    String key = 'custom_$stem';
    int suffix = 2;
    final Set<String> allKeys = <String>{for (final FormulaIconOption option in formulaIconOptions) option.key, for (final FormulaIconOption option in customIcons) option.key};
    while (allKeys.contains(key)) {
      key = 'custom_${stem}_$suffix';
      suffix += 1;
    }

    final FormulaIconOption icon = FormulaIconOption(key: key, label: normalizedLabel, glyph: normalizedGlyph);
    customIcons.add(icon);
    await box.put(_customIconsKey, jsonEncode(customIcons.map((FormulaIconOption option) => option.toJson()).toList()));

    state = AsyncData(mergeFormulaIconOptions(customIcons));
    return icon;
  }

  List<FormulaIconOption> _decodeCustomIcons(String raw) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return <FormulaIconOption>[];
      final List<FormulaIconOption> options = <FormulaIconOption>[];
      for (final dynamic item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final FormulaIconOption? option = FormulaIconOption.fromJson(item);
        if (option != null) {
          options.add(option);
        }
      }
      return options;
    } catch (_) {
      return <FormulaIconOption>[];
    }
  }
}
