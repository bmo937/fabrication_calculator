import 'package:fabrication_calculator/models/calculator_group.dart';
import 'package:fabrication_calculator/models/formula_icon_option.dart';
import 'package:fabrication_calculator/models/managed_calculator.dart';
import 'package:fabrication_calculator/providers/calculator_registry_provider.dart';
import 'package:fabrication_calculator/providers/icon_catalog_provider.dart';
import 'package:fabrication_calculator/screens/manage_calculator_screen.dart';
import 'package:fabrication_calculator/widgets/icon_picker_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ManageScreen extends ConsumerWidget {
  const ManageScreen({super.key});

  // ── Group dialogs ──────────────────────────────────────────────────────────

  static Future<void> _showAddGroupDialog(BuildContext context, WidgetRef ref) async {
    final List<FormulaIconOption> iconOptions = ref.read(iconCatalogProvider).valueOrNull ?? formulaIconOptions;
    final _GroupDraft? draft = await showDialog<_GroupDraft>(
      context: context,
      builder: (BuildContext ctx) => _GroupNameDialog(
        title: 'New Group',
        confirmLabel: 'Add',
        initialIconKey: 'folder',
        iconOptions: iconOptions,
        onAddCustomIcon: ({required String glyph, required String label}) {
          return ref.read(iconCatalogProvider.notifier).addCustomIcon(glyph: glyph, label: label);
        },
      ),
    );
    if (draft != null && draft.name.isNotEmpty) {
      await ref.read(calculatorGroupsProvider.notifier).add(draft.name, iconKey: draft.iconKey);
    }
  }

  static Future<void> _showEditGroupDialog(BuildContext context, WidgetRef ref, CalculatorGroup group) async {
    final List<FormulaIconOption> iconOptions = ref.read(iconCatalogProvider).valueOrNull ?? formulaIconOptions;
    final _GroupDraft? draft = await showDialog<_GroupDraft>(
      context: context,
      builder: (BuildContext ctx) => _GroupNameDialog(
        title: 'Edit Group',
        confirmLabel: 'Save',
        initialValue: group.name,
        initialIconKey: group.iconKey,
        iconOptions: iconOptions,
        onAddCustomIcon: ({required String glyph, required String label}) {
          return ref.read(iconCatalogProvider.notifier).addCustomIcon(glyph: glyph, label: label);
        },
      ),
    );
    if (draft != null && draft.name.isNotEmpty && (draft.name != group.name || draft.iconKey != group.iconKey)) {
      await ref.read(calculatorGroupsProvider.notifier).updateGroup(group.copyWith(name: draft.name, iconKey: draft.iconKey));
    }
  }

  static Future<void> _confirmDeleteGroup(BuildContext context, WidgetRef ref, CalculatorGroup group, int calculatorCount) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Group?'),
        content: Text(
          calculatorCount > 0
              ? 'This will permanently delete "${group.name}" and its '
                    '$calculatorCount calculator${calculatorCount == 1 ? '' : 's'}.'
              : 'Delete group "${group.name}"?',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(calculatorGroupsProvider.notifier).delete(group.id);
    }
  }

  static Future<void> _confirmDeleteCalculator(BuildContext context, WidgetRef ref, ManagedCalculator calc) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Formula?'),
        content: Text('Permanently delete "${calc.name}"?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(managedCalculatorsProvider.notifier).delete(calc.id);
    }
  }

  static void _openCalculatorEditor(BuildContext context, {String? initialGroupId, ManagedCalculator? calculator}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ManageCalculatorScreen(calculator: calculator, initialGroupId: initialGroupId),
      ),
    );
  }

  static List<T> _moveItem<T>(List<T> items, int oldIndex, int newIndex) {
    final List<T> updated = List<T>.of(items);
    final T moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    return updated;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CalculatorGroup>> groupsAsync = ref.watch(calculatorGroupsProvider);
    final List<FormulaIconOption> iconOptions = ref.watch(iconCatalogProvider).valueOrNull ?? formulaIconOptions;
    final List<ManagedCalculator> allCalcs = ref.watch(managedCalculatorsProvider).valueOrNull ?? <ManagedCalculator>[];
    final List<ManagedCalculator> allDrafts = allCalcs.where((ManagedCalculator c) => c.isDraft).toList()
      ..sort((ManagedCalculator a, ManagedCalculator b) => b.sortOrder.compareTo(a.sortOrder));

    return Scaffold(
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('Error: $e')),
        data: (List<CalculatorGroup> groups) {
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.folder_open_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No formulas yet', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(onPressed: () => _showAddGroupDialog(context, ref), icon: const Icon(Icons.add), label: const Text('Add Formula Group')),
                ],
              ),
            );
          }

          final List<CalculatorGroup> orderedGroups = List<CalculatorGroup>.of(groups)..sort((CalculatorGroup a, CalculatorGroup b) => a.sortOrder.compareTo(b.sortOrder));

          final Widget header = Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Theme.of(context).colorScheme.primaryContainer, Theme.of(context).colorScheme.surface],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Organize Formulas', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text('Drag groups to reorder sections and drag formulas within a group to control calculator order.', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          );

          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            header: Column(
              children: <Widget>[
                header,
                if (allDrafts.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                            child: Text('Draft Queue', style: Theme.of(context).textTheme.titleSmall),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                            child: Text('Draft formulas stay here until published.', style: Theme.of(context).textTheme.bodySmall),
                          ),
                          for (final ManagedCalculator draft in allDrafts)
                            _DraftTile(
                              calculator: draft,
                              iconOptions: iconOptions,
                              groupName: groups.where((CalculatorGroup g) => g.id == draft.groupId).map((CalculatorGroup g) => g.name).firstOrNull ?? 'Unknown Group',
                              onEdit: () => _openCalculatorEditor(context, calculator: draft),
                              onDuplicate: () => ref.read(managedCalculatorsProvider.notifier).duplicate(draft.id),
                              onDelete: () => _confirmDeleteCalculator(context, ref, draft),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: orderedGroups.length,
            onReorderItem: (int oldIndex, int newIndex) {
              final List<CalculatorGroup> reordered = _moveItem<CalculatorGroup>(orderedGroups, oldIndex, newIndex);
              ref.read(calculatorGroupsProvider.notifier).reorderGroups(reordered);
            },
            itemBuilder: (BuildContext context, int index) {
              final CalculatorGroup group = orderedGroups[index];
              final List<ManagedCalculator> groupCalcs = allCalcs.where((ManagedCalculator c) => c.groupId == group.id).toList()
                ..sort((ManagedCalculator a, ManagedCalculator b) => a.sortOrder.compareTo(b.sortOrder));
              final List<ManagedCalculator> publishedCalcs = groupCalcs.where((ManagedCalculator c) => !c.isDraft).toList();
              final int publishedCount = publishedCalcs.length;
              final int draftCount = groupCalcs.length - publishedCount;
              final FormulaIconOption groupIcon = formulaIconByKey(group.iconKey, options: iconOptions);

              return Card(
                key: ValueKey<String>('group-${group.id}'),
                margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: ExpansionTile(
                  maintainState: true,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: CircleAvatar(radius: 16, child: Text(groupIcon.glyph, style: const TextStyle(fontSize: 14))),
                  title: Text(group.name, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text('$publishedCount published • $draftCount draft'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(tooltip: 'Rename', icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showEditGroupDialog(context, ref, group)),
                      IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _confirmDeleteGroup(context, ref, group, groupCalcs.length)),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.drag_indicator)),
                      ),
                    ],
                  ),
                  children: <Widget>[
                    if (publishedCalcs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Text('No published calculators in this group.', style: Theme.of(context).textTheme.bodySmall),
                      )
                    else
                      ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: publishedCalcs.length,
                        onReorderItem: (int oldIndex, int newIndex) {
                          final List<ManagedCalculator> reordered = _moveItem<ManagedCalculator>(publishedCalcs, oldIndex, newIndex);
                          ref.read(managedCalculatorsProvider.notifier).reorderPublishedInGroup(group.id, reordered);
                        },
                        itemBuilder: (BuildContext context, int calcIndex) {
                          final ManagedCalculator calc = publishedCalcs[calcIndex];
                          return _CalculatorTile(
                            key: ValueKey<String>('calc-${calc.id}'),
                            calculator: calc,
                            iconOptions: iconOptions,
                            dragHandle: ReorderableDragStartListener(
                              index: calcIndex,
                              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.drag_indicator)),
                            ),
                            onEdit: () => _openCalculatorEditor(context, calculator: calc),
                            onDuplicate: () => ref.read(managedCalculatorsProvider.notifier).duplicate(calc.id),
                            onDelete: () => _confirmDeleteCalculator(context, ref, calc),
                          );
                        },
                      ),
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                      title: Text('Add Formula', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                      onTap: () => _openCalculatorEditor(context, initialGroupId: group.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGroupDialog(context, ref),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('New Formula Group'),
      ),
    );
  }
}

class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialIconKey,
    required this.iconOptions,
    required this.onAddCustomIcon,
    this.initialValue = '',
  });

  final String title;
  final String confirmLabel;
  final String initialValue;
  final String initialIconKey;
  final List<FormulaIconOption> iconOptions;
  final Future<FormulaIconOption> Function({required String glyph, required String label}) onAddCustomIcon;

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  late final TextEditingController _controller;
  late String _selectedIconKey;
  late List<FormulaIconOption> _iconOptions;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _selectedIconKey = widget.initialIconKey;
    _iconOptions = widget.iconOptions;
  }

  Future<void> _pickIcon() async {
    final IconPickerSelection? selection = await showIconPickerBottomSheet(
      context,
      title: 'Group Icon',
      options: _iconOptions,
      selectedKey: _selectedIconKey,
      onAddCustomIcon: (String glyph, String label) => widget.onAddCustomIcon(glyph: glyph, label: label),
    );
    if (selection != null && mounted) {
      setState(() {
        _iconOptions = selection.options;
        _selectedIconKey = selection.selectedKey;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FormulaIconOption selectedIcon = formulaIconByKey(_selectedIconKey, options: _iconOptions);

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Group Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text(selectedIcon.glyph)),
            title: const Text('Group Icon'),
            subtitle: Text(selectedIcon.label),
            trailing: const Icon(Icons.keyboard_arrow_up),
            onTap: _pickIcon,
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_GroupDraft(name: _controller.text.trim(), iconKey: _selectedIconKey)),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _GroupDraft {
  const _GroupDraft({required this.name, required this.iconKey});

  final String name;
  final String iconKey;
}

// ── Calculator tile ────────────────────────────────────────────────────────────

class _CalculatorTile extends StatelessWidget {
  const _CalculatorTile({super.key, required this.calculator, required this.iconOptions, this.dragHandle, required this.onEdit, required this.onDuplicate, required this.onDelete});

  final ManagedCalculator calculator;
  final List<FormulaIconOption> iconOptions;
  final Widget? dragHandle;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final String status = calculator.isDraft ? 'Draft' : 'Published';
    final Color statusColor = calculator.isDraft ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.primary;
    final String? metadata = !calculator.isDraft ? _formatPublishedMetadata(calculator) : null;
    final FormulaIconOption iconOption = formulaIconByKey(calculator.iconKey, options: iconOptions);

    return ListTile(
      dense: true,
      leading: CircleAvatar(radius: 14, child: Text(iconOption.glyph, style: const TextStyle(fontSize: 14))),
      title: Text(calculator.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (calculator.description.isNotEmpty) Text(calculator.description, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (metadata != null) Text(metadata, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            calculator.isDraft && !calculator.sandboxTestPassed ? '$status • Sandbox not passed' : status,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: statusColor),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        itemBuilder: (_) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'edit',
            child: ListTile(dense: true, leading: Icon(Icons.edit_outlined), title: Text('Edit')),
          ),
          const PopupMenuItem<String>(
            value: 'duplicate',
            child: ListTile(dense: true, leading: Icon(Icons.copy_outlined), title: Text('Duplicate')),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'delete',
            child: ListTile(dense: true, leading: Icon(Icons.delete_outline), title: Text('Delete')),
          ),
        ],
        onSelected: (String value) {
          switch (value) {
            case 'edit':
              onEdit();
            case 'duplicate':
              onDuplicate();
            case 'delete':
              onDelete();
          }
        },
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[const Icon(Icons.more_vert), ?dragHandle]),
      ),
    );
  }

  String? _formatPublishedMetadata(ManagedCalculator calculator) {
    final String? publishedAt = calculator.publishedAt == null ? null : _formatDate(calculator.publishedAt!);
    final String? testedAt = calculator.lastSandboxTestAt == null ? null : _formatDate(calculator.lastSandboxTestAt!);
    if (publishedAt == null && testedAt == null) return null;
    if (publishedAt != null && testedAt != null) {
      return 'Published $publishedAt • Tested $testedAt';
    }
    return publishedAt != null ? 'Published $publishedAt' : 'Tested $testedAt';
  }

  static String _formatDate(DateTime value) {
    final DateTime local = value.toLocal();
    return '${local.month}/${local.day}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _DraftTile extends StatelessWidget {
  const _DraftTile({required this.calculator, required this.iconOptions, required this.groupName, required this.onEdit, required this.onDuplicate, required this.onDelete});

  final ManagedCalculator calculator;
  final List<FormulaIconOption> iconOptions;
  final String groupName;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final String sandboxStatus = calculator.sandboxTestPassed ? 'Sandbox passed' : 'Sandbox not passed';
    final String? lastTest = calculator.lastSandboxTestAt == null ? null : _CalculatorTile._formatDate(calculator.lastSandboxTestAt!);
    final FormulaIconOption iconOption = formulaIconByKey(calculator.iconKey, options: iconOptions);

    return ListTile(
      dense: true,
      leading: CircleAvatar(radius: 14, child: Text(iconOption.glyph, style: const TextStyle(fontSize: 14))),
      title: Text(calculator.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(groupName),
          Text(lastTest == null ? sandboxStatus : '$sandboxStatus • Last test $lastTest', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
      trailing: PopupMenuButton<String>(
        itemBuilder: (_) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'edit',
            child: ListTile(dense: true, leading: Icon(Icons.edit_outlined), title: Text('Edit')),
          ),
          const PopupMenuItem<String>(
            value: 'duplicate',
            child: ListTile(dense: true, leading: Icon(Icons.copy_outlined), title: Text('Duplicate')),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'delete',
            child: ListTile(dense: true, leading: Icon(Icons.delete_outline), title: Text('Delete')),
          ),
        ],
        onSelected: (String value) {
          switch (value) {
            case 'edit':
              onEdit();
            case 'duplicate':
              onDuplicate();
            case 'delete':
              onDelete();
          }
        },
      ),
    );
  }
}
