import 'package:fabrication_calculator/models/formula_icon_option.dart';
import 'package:flutter/material.dart';

class IconPickerSelection {
  const IconPickerSelection({required this.selectedKey, required this.options});

  final String selectedKey;
  final List<FormulaIconOption> options;
}

Future<IconPickerSelection?> showIconPickerBottomSheet(
  BuildContext context, {
  required List<FormulaIconOption> options,
  required String selectedKey,
  required Future<FormulaIconOption> Function(String glyph, String label) onAddCustomIcon,
  String title = 'Choose Icon',
}) {
  return showModalBottomSheet<IconPickerSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) {
      return _IconPickerBottomSheet(title: title, options: options, selectedKey: selectedKey, onAddCustomIcon: onAddCustomIcon);
    },
  );
}

class _IconPickerBottomSheet extends StatefulWidget {
  const _IconPickerBottomSheet({required this.title, required this.options, required this.selectedKey, required this.onAddCustomIcon});

  final String title;
  final List<FormulaIconOption> options;
  final String selectedKey;
  final Future<FormulaIconOption> Function(String glyph, String label) onAddCustomIcon;

  @override
  State<_IconPickerBottomSheet> createState() => _IconPickerBottomSheetState();
}

class _IconPickerBottomSheetState extends State<_IconPickerBottomSheet> {
  late List<FormulaIconOption> _options;
  late String _selectedKey;
  final TextEditingController _customGlyphController = TextEditingController();
  final TextEditingController _customLabelController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _options = List<FormulaIconOption>.of(widget.options);
    _selectedKey = widget.selectedKey;
  }

  @override
  void dispose() {
    _customGlyphController.dispose();
    _customLabelController.dispose();
    super.dispose();
  }

  Future<void> _addCustomIcon() async {
    final String glyph = _customGlyphController.text.trim();
    final String label = _customLabelController.text.trim();
    if (glyph.isEmpty || label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter both icon character and label.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final FormulaIconOption icon = await widget.onAddCustomIcon(glyph, label);
      setState(() {
        _options = <FormulaIconOption>[..._options, icon];
        _selectedKey = icon.key;
      });
      _customGlyphController.clear();
      _customLabelController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added icon "${icon.label}"')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final FormulaIconOption selected = formulaIconByKey(_selectedKey, options: _options);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleMedium)),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(IconPickerSelection(selectedKey: _selectedKey, options: _options)),
                  child: const Text('Use Selected'),
                ),
              ],
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: CircleAvatar(child: Text(selected.glyph)),
            title: Text(selected.label),
            subtitle: const Text('Tap any icon below to preview/select.'),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: _options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.08),
              itemBuilder: (BuildContext context, int index) {
                final FormulaIconOption option = _options[index];
                final bool selected = option.key == _selectedKey;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() => _selectedKey = option.key);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline.withValues(alpha: 0.35)),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(option.glyph, style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(option.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Add Custom Icon', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      SizedBox(
                        width: 86,
                        child: TextField(
                          controller: _customGlyphController,
                          textAlign: TextAlign.center,
                          maxLength: 2,
                          decoration: const InputDecoration(counterText: '', labelText: 'Icon'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _customLabelController,
                          decoration: const InputDecoration(labelText: 'Label'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _saving
                          ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2))
                          : IconButton.filled(onPressed: _addCustomIcon, icon: const Icon(Icons.add)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
