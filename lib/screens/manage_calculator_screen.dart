import 'package:fabrication_calculator/models/calculator_field_definition.dart';
import 'package:fabrication_calculator/models/calculator_group.dart';
import 'package:fabrication_calculator/models/formula_icon_option.dart';
import 'package:fabrication_calculator/models/managed_calculator.dart';
import 'package:fabrication_calculator/providers/calculator_registry_provider.dart';
import 'package:fabrication_calculator/services/calculator_code_sandbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();
const String _dslCodeLanguage = 'math';

class ManageCalculatorScreen extends ConsumerStatefulWidget {
  const ManageCalculatorScreen({this.calculator, this.initialGroupId, super.key});

  final ManagedCalculator? calculator;
  final String? initialGroupId;

  @override
  ConsumerState<ManageCalculatorScreen> createState() => _ManageCalculatorScreenState();
}

class _ManageCalculatorScreenState extends ConsumerState<ManageCalculatorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _codeController;

  late String? _selectedGroupId;
  late String _selectedIconKey;
  late bool _sandboxTestPassed;
  Map<String, double> _sandboxOutputs = <String, double>{};
  String? _testError;
  bool _saving = false;

  final List<_FieldDefinitionRow> _inputRows = <_FieldDefinitionRow>[];
  final List<_FieldDefinitionRow> _outputRows = <_FieldDefinitionRow>[];

  @override
  void initState() {
    super.initState();
    final ManagedCalculator? calc = widget.calculator;
    _nameController = TextEditingController(text: calc?.name ?? '');
    _descriptionController = TextEditingController(text: calc?.description ?? '');
    _codeController = TextEditingController();

    _selectedGroupId = calc?.groupId ?? widget.initialGroupId;
    _selectedIconKey = calc?.iconKey ?? 'function';
    _sandboxTestPassed = calc?.sandboxTestPassed ?? false;
    _testError = (calc?.sandboxLastError ?? '').isEmpty ? null : calc!.sandboxLastError;

    final List<CalculatorFieldDefinition> inputDefs = calc?.inputDefinitions ?? <CalculatorFieldDefinition>[const CalculatorFieldDefinition(key: 'x', label: 'Input')];
    final List<CalculatorFieldDefinition> outputDefs = calc?.outputDefinitions ?? <CalculatorFieldDefinition>[const CalculatorFieldDefinition(key: 'result', label: 'Result')];

    for (final CalculatorFieldDefinition input in inputDefs) {
      _inputRows.add(
        _FieldDefinitionRow(
          keyController: TextEditingController(text: input.key),
          labelController: TextEditingController(text: input.label),
          testValueController: TextEditingController(text: '0'),
        ),
      );
    }

    for (final CalculatorFieldDefinition output in outputDefs) {
      _outputRows.add(
        _FieldDefinitionRow(
          keyController: TextEditingController(text: output.key),
          labelController: TextEditingController(text: output.label),
        ),
      );
    }

    _codeController.text = _initialCode(calc, outputDefs);
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    for (final _FieldDefinitionRow row in _inputRows) {
      row.dispose();
    }
    for (final _FieldDefinitionRow row in _outputRows) {
      row.dispose();
    }
    super.dispose();
  }

  String _initialCode(ManagedCalculator? calc, List<CalculatorFieldDefinition> outputs) {
    if (calc != null && calc.codeBody.trim().isNotEmpty) {
      return calc.codeBody;
    }
    if (calc != null && calc.calculatorType == 'formula' && (calc.formulaExpression ?? '').trim().isNotEmpty) {
      final String target = outputs.first.key;
      return '$target = ${calc.formulaExpression!.trim()};';
    }
    return _templateCodeFromOutputs(outputs);
  }

  String _templateCodeFromOutputs(List<CalculatorFieldDefinition> outputs) {
    if (outputs.isEmpty) {
      return '// Define output assignments, e.g.\n// result = x * 2;';
    }

    return outputs.map((CalculatorFieldDefinition o) => '${o.key} = 0;').join('\n');
  }

  void _onCodeChanged() {
    if (_sandboxTestPassed || _sandboxOutputs.isNotEmpty || _testError != null) {
      setState(() {
        _sandboxTestPassed = false;
        _sandboxOutputs = <String, double>{};
        _testError = null;
      });
    }
  }

  Future<void> _save({required bool asDraft}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a group')));
      return;
    }

    final _SchemaValidation validation = _validateSchema();
    if (!validation.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validation.message!)));
      return;
    }

    if (!asDraft && !_sandboxTestPassed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Run a successful sandbox test before publishing.')));
      return;
    }

    setState(() => _saving = true);

    final List<CalculatorFieldDefinition> inputs = _collectInputs();
    final List<CalculatorFieldDefinition> outputs = _collectOutputs();

    final bool isEditing = widget.calculator != null;
    final String id = widget.calculator?.id ?? _uuid.v4();

    final List<ManagedCalculator> existing = ref.read(managedCalculatorsProvider).valueOrNull ?? <ManagedCalculator>[];
    final int sortOrder = isEditing ? widget.calculator!.sortOrder : existing.where((ManagedCalculator c) => c.groupId == _selectedGroupId).length;

    final ManagedCalculator calculator = ManagedCalculator(
      id: id,
      groupId: _selectedGroupId!,
      name: _nameController.text.trim(),
      calculatorType: 'code',
      inputLabel: inputs.first.label,
      outputLabel: outputs.first.label,
      formulaExpression: null,
      lookupEntriesJson: null,
      sortOrder: sortOrder,
      description: _descriptionController.text.trim(),
      isDraft: asDraft,
      sandboxTestPassed: _sandboxTestPassed,
      lastSandboxTestAt: _sandboxTestPassed ? DateTime.now() : widget.calculator?.lastSandboxTestAt,
      publishedAt: asDraft ? null : (widget.calculator?.publishedAt ?? DateTime.now()),
      codeBody: _codeController.text,
      inputDefinitionsJson: CalculatorFieldDefinition.listToJson(inputs),
      outputDefinitionsJson: CalculatorFieldDefinition.listToJson(outputs),
      sandboxLastError: _testError ?? '',
      codeLanguage: _dslCodeLanguage,
      iconKey: _selectedIconKey,
    );

    try {
      if (asDraft) {
        await ref.read(managedCalculatorsProvider.notifier).saveDraft(calculator);
      } else if (isEditing) {
        await ref.read(managedCalculatorsProvider.notifier).updateCalculator(calculator);
      } else {
        await ref.read(managedCalculatorsProvider.notifier).add(calculator);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  _SchemaValidation _validateSchema() {
    if (_inputRows.isEmpty) {
      return const _SchemaValidation(false, 'Add at least one input field.');
    }

    if (_outputRows.isEmpty) {
      return const _SchemaValidation(false, 'Add at least one output field.');
    }

    final RegExp keyPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
    final Set<String> inputKeys = <String>{};
    final Set<String> outputKeys = <String>{};

    for (final _FieldDefinitionRow row in _inputRows) {
      final String key = row.keyController.text.trim();
      final String label = row.labelController.text.trim();
      if (key.isEmpty || label.isEmpty) {
        return const _SchemaValidation(false, 'Input key and label are required.');
      }
      if (!keyPattern.hasMatch(key)) {
        return _SchemaValidation(false, 'Invalid input key "$key". Use letters, numbers, and underscore.');
      }
      if (!inputKeys.add(key)) {
        return _SchemaValidation(false, 'Duplicate input key "$key".');
      }
    }

    for (final _FieldDefinitionRow row in _outputRows) {
      final String key = row.keyController.text.trim();
      final String label = row.labelController.text.trim();
      if (key.isEmpty || label.isEmpty) {
        return const _SchemaValidation(false, 'Output key and label are required.');
      }
      if (!keyPattern.hasMatch(key)) {
        return _SchemaValidation(false, 'Invalid output key "$key". Use letters, numbers, and underscore.');
      }
      if (!outputKeys.add(key)) {
        return _SchemaValidation(false, 'Duplicate output key "$key".');
      }
      if (inputKeys.contains(key)) {
        return _SchemaValidation(false, 'Output key "$key" conflicts with an input key.');
      }
    }

    if (_codeController.text.trim().isEmpty) {
      return const _SchemaValidation(false, 'Code body is required.');
    }

    return const _SchemaValidation(true, null);
  }

  List<CalculatorFieldDefinition> _collectInputs() {
    return _inputRows.map((_FieldDefinitionRow row) => CalculatorFieldDefinition(key: row.keyController.text.trim(), label: row.labelController.text.trim())).toList();
  }

  List<CalculatorFieldDefinition> _collectOutputs() {
    return _outputRows.map((_FieldDefinitionRow row) => CalculatorFieldDefinition(key: row.keyController.text.trim(), label: row.labelController.text.trim())).toList();
  }

  void _runSandbox() {
    final _SchemaValidation validation = _validateSchema();
    if (!validation.ok) {
      setState(() {
        _sandboxOutputs = <String, double>{};
        _sandboxTestPassed = false;
        _testError = validation.message;
      });
      return;
    }

    final List<CalculatorFieldDefinition> inputs = _collectInputs();
    final List<CalculatorFieldDefinition> outputs = _collectOutputs();
    final Map<String, double> testInputs = <String, double>{};

    for (final _FieldDefinitionRow row in _inputRows) {
      final String key = row.keyController.text.trim();
      final String rawValue = row.testValueController?.text.trim() ?? '';
      final double? value = double.tryParse(rawValue);
      if (value == null) {
        setState(() {
          _sandboxOutputs = <String, double>{};
          _sandboxTestPassed = false;
          _testError = 'Invalid test value for "$key".';
        });
        return;
      }
      testInputs[key] = value;
    }

    final SandboxExecutionResult result = CalculatorCodeSandbox.execute(
      codeBody: _codeController.text,
      inputs: inputs,
      outputs: outputs,
      inputValues: testInputs,
      codeLanguage: _dslCodeLanguage,
    );

    if (!result.success) {
      setState(() {
        _sandboxOutputs = <String, double>{};
        _sandboxTestPassed = false;
        _testError = result.error;
      });
      return;
    }

    final Map<String, double> labeledOutputs = <String, double>{};
    for (final CalculatorFieldDefinition output in outputs) {
      labeledOutputs[output.label] = result.outputs[output.key] ?? 0;
    }

    setState(() {
      _sandboxOutputs = labeledOutputs;
      _sandboxTestPassed = true;
      _testError = null;
    });
  }

  void _addInputRow() {
    setState(() {
      _inputRows.add(
        _FieldDefinitionRow(
          keyController: TextEditingController(text: CalculatorFieldDefinition.sanitizeKey('input_${_inputRows.length + 1}')),
          labelController: TextEditingController(text: 'Input ${_inputRows.length + 1}'),
          testValueController: TextEditingController(text: '0'),
        ),
      );
      _sandboxTestPassed = false;
      _sandboxOutputs = <String, double>{};
      _testError = null;
    });
  }

  void _addOutputRow() {
    setState(() {
      _outputRows.add(
        _FieldDefinitionRow(
          keyController: TextEditingController(text: CalculatorFieldDefinition.sanitizeKey('output_${_outputRows.length + 1}')),
          labelController: TextEditingController(text: 'Output ${_outputRows.length + 1}'),
        ),
      );
      _sandboxTestPassed = false;
      _sandboxOutputs = <String, double>{};
      _testError = null;
    });
  }

  void _insertAtCursor(String insertion) {
    final TextSelection selection = _codeController.selection;
    final String text = _codeController.text;

    if (!selection.isValid) {
      _codeController.text = text + insertion;
      return;
    }

    final int start = selection.start;
    final int end = selection.end;
    final String updated = text.replaceRange(start, end, insertion);
    _codeController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + insertion.length),
    );
  }

  List<Widget> _buildHelperButtons() {
    final List<CalculatorFieldDefinition> inputs = _collectInputs();
    final List<CalculatorFieldDefinition> outputs = _collectOutputs();
    final List<Widget> chips = <Widget>[];

    for (final CalculatorFieldDefinition input in inputs) {
      final String key = input.key.trim();
      if (key.isEmpty) continue;
      chips.add(ActionChip(label: Text('in:$key'), onPressed: () => _insertAtCursor(key)));
    }

    for (final CalculatorFieldDefinition output in outputs) {
      final String key = output.key.trim();
      if (key.isEmpty) continue;
      chips.add(ActionChip(label: Text('out:$key='), onPressed: () => _insertAtCursor('$key = ')));
    }

    const List<MapEntry<String, String>> syntaxChips = <MapEntry<String, String>>[
      MapEntry<String, String>('if()', 'if(condition, trueValue, falseValue)'),
      MapEntry<String, String>('lookup()', 'lookup(key, key1, value1, defaultValue)'),
      MapEntry<String, String>('lookup2d()', 'lookup2d(rowKey, colKey, row1, col1, value1, defaultValue)'),
      MapEntry<String, String>('&&', ' && '),
      MapEntry<String, String>('||', ' || '),
      MapEntry<String, String>('!', '!'),
      MapEntry<String, String>('==', ' == '),
      MapEntry<String, String>('!=', ' != '),
      MapEntry<String, String>('>=', ' >= '),
      MapEntry<String, String>('<=', ' <= '),
      MapEntry<String, String>('>', ' > '),
      MapEntry<String, String>('<', ' < '),
    ];

    for (final MapEntry<String, String> syntaxChip in syntaxChips) {
      chips.add(ActionChip(label: Text(syntaxChip.key), onPressed: () => _insertAtCursor(syntaxChip.value)));
    }

    chips.add(
      ActionChip(
        label: const Text('Template'),
        onPressed: () {
          _codeController.text = _templateCodeFromOutputs(_collectOutputs());
        },
      ),
    );

    return chips;
  }

  Widget _buildIconSection(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedIconKey,
      decoration: const InputDecoration(labelText: 'Formula Icon', border: OutlineInputBorder()),
      items: formulaIconOptions.map((FormulaIconOption option) => DropdownMenuItem<String>(value: option.key, child: Text('${option.glyph}  ${option.label}'))).toList(),
      onChanged: (String? value) {
        if (value == null) return;
        setState(() {
          _selectedIconKey = value;
        });
      },
    );
  }

  void _removeInputRow(int index) {
    if (_inputRows.length == 1) return;
    setState(() {
      _inputRows[index].dispose();
      _inputRows.removeAt(index);
      _sandboxTestPassed = false;
      _sandboxOutputs = <String, double>{};
      _testError = null;
    });
  }

  void _removeOutputRow(int index) {
    if (_outputRows.length == 1) return;
    setState(() {
      _outputRows[index].dispose();
      _outputRows.removeAt(index);
      _sandboxTestPassed = false;
      _sandboxOutputs = <String, double>{};
      _testError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<CalculatorGroup> groups = ref.watch(calculatorGroupsProvider).valueOrNull ?? <CalculatorGroup>[];

    if (_selectedGroupId == null && groups.isNotEmpty) {
      _selectedGroupId = groups.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.calculator == null ? 'New Calculator' : 'Edit Calculator'),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...<Widget>[
            TextButton(onPressed: () => _save(asDraft: true), child: const Text('Save Draft')),
            TextButton(onPressed: () => _save(asDraft: false), child: const Text('Publish')),
          ],
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              validator: (String? v) => v?.trim().isEmpty == true ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            _buildIconSection(context),
            const SizedBox(height: 12),
            if (groups.isEmpty)
              const Card(
                child: Padding(padding: EdgeInsets.all(12), child: Text('No groups available. Create a group first.')),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedGroupId,
                decoration: const InputDecoration(labelText: 'Group', border: OutlineInputBorder()),
                items: groups.map((CalculatorGroup g) => DropdownMenuItem<String>(value: g.id, child: Text(g.name))).toList(),
                onChanged: (String? v) => setState(() => _selectedGroupId = v),
                validator: (String? v) => v == null ? 'Select a group' : null,
              ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Formula DSL only. Use one assignment per line: target = expression;\n'
                  'Targets may be temp variables or output keys. Every output key must be assigned by the end.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildDefinitionsSection(context, title: 'Input Fields', rows: _inputRows, onAdd: _addInputRow, onRemove: _removeInputRow, includeTestValue: true),
            const SizedBox(height: 16),
            _buildDefinitionsSection(context, title: 'Output Fields', rows: _outputRows, onAdd: _addOutputRow, onRemove: _removeOutputRow, includeTestValue: false),
            const SizedBox(height: 16),
            _buildCodeEditor(context),
            const SizedBox(height: 16),
            _buildSandboxSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDefinitionsSection(
    BuildContext context, {
    required String title,
    required List<_FieldDefinitionRow> rows,
    required VoidCallback onAdd,
    required void Function(int) onRemove,
    required bool includeTestValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
          ],
        ),
        const SizedBox(height: 6),
        for (int i = 0; i < rows.length; i++) ...<Widget>[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 2,
                child: TextField(
                  controller: rows[i].keyController,
                  decoration: const InputDecoration(labelText: 'Key', border: OutlineInputBorder(), isDense: true),
                  onChanged: (_) => _onCodeChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: rows[i].labelController,
                  decoration: const InputDecoration(labelText: 'Label', border: OutlineInputBorder(), isDense: true),
                  onChanged: (_) => _onCodeChanged(),
                ),
              ),
              if (includeTestValue) ...<Widget>[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: rows[i].testValueController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Test', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
              ],
              IconButton(icon: const Icon(Icons.close), onPressed: () => onRemove(i)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCodeEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Code Body', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _buildHelperButtons()),
        const SizedBox(height: 6),
        TextFormField(
          controller: _codeController,
          minLines: 12,
          maxLines: 18,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Enter calculator code here'),
          validator: (String? value) {
            if (value == null || value.trim().isEmpty) {
              return 'Code body is required.';
            }
            return null;
          },
        ),
        const SizedBox(height: 6),
        Text('Supports + - * / ^, comparisons, && || !, if(), lookup(), lookup2d(). Booleans are numeric (true=1, false=0).', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              'Examples:\n'
              'spacing = length / (holes + 1);\n'
              'hole1 = round(spacing * 1);\n'
              'is_thick = thickness > 2;\n'
              'factor = if(is_thick, 1.25, 1.0);\n'
              'k = lookup(material_code, 1, 0.44, 2, 0.33, 0.40);',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSandboxSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('Sandbox Test', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            ElevatedButton(onPressed: _runSandbox, child: const Text('Run Test')),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _sandboxTestPassed ? 'Status: passed' : 'Status: not passed',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _sandboxTestPassed ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline),
        ),
        if (_testError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_testError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (_sandboxOutputs.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          for (final MapEntry<String, double> entry in _sandboxOutputs.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${entry.key}: ${entry.value.toStringAsPrecision(10)}', style: Theme.of(context).textTheme.bodyMedium),
            ),
        ],
      ],
    );
  }
}

class _FieldDefinitionRow {
  _FieldDefinitionRow({required this.keyController, required this.labelController, this.testValueController});

  final TextEditingController keyController;
  final TextEditingController labelController;
  final TextEditingController? testValueController;

  void dispose() {
    keyController.dispose();
    labelController.dispose();
    testValueController?.dispose();
  }
}

class _SchemaValidation {
  const _SchemaValidation(this.ok, this.message);

  final bool ok;
  final String? message;
}
