import 'package:fabrication_calculator/models/calculator_group.dart';
import 'package:fabrication_calculator/models/formula_icon_option.dart';
import 'package:fabrication_calculator/models/managed_calculator.dart';
import 'package:fabrication_calculator/providers/calculator_registry_provider.dart';
import 'package:fabrication_calculator/screens/manage_calculator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ManageScreen extends ConsumerWidget {
  const ManageScreen({super.key});

  // ── Group dialogs ──────────────────────────────────────────────────────────

  static Future<void> _showAddGroupDialog(BuildContext context, WidgetRef ref) async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => const _GroupNameDialog(title: 'New Group', confirmLabel: 'Add'),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(calculatorGroupsProvider.notifier).add(name);
    }
  }

  static Future<void> _showEditGroupDialog(BuildContext context, WidgetRef ref, CalculatorGroup group) async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => _GroupNameDialog(title: 'Rename Group', confirmLabel: 'Save', initialValue: group.name),
    );
    if (name != null && name.isNotEmpty && name != group.name) {
      await ref.read(calculatorGroupsProvider.notifier).updateGroup(group.copyWith(name: name));
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CalculatorGroup>> groupsAsync = ref.watch(calculatorGroupsProvider);
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

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: <Widget>[
              if (allDrafts.isNotEmpty)
                Card(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text('Drafts', style: Theme.of(context).textTheme.titleSmall),
                        ),
                        for (final ManagedCalculator draft in allDrafts)
                          _DraftTile(
                            calculator: draft,
                            groupName: groups.where((CalculatorGroup g) => g.id == draft.groupId).map((CalculatorGroup g) => g.name).firstOrNull ?? 'Unknown Group',
                            onEdit: () => _openCalculatorEditor(context, calculator: draft),
                            onDuplicate: () => ref.read(managedCalculatorsProvider.notifier).duplicate(draft.id),
                            onDelete: () => _confirmDeleteCalculator(context, ref, draft),
                          ),
                      ],
                    ),
                  ),
                ),
              for (final CalculatorGroup group in groups)
                () {
                  final List<ManagedCalculator> groupCalcs = allCalcs.where((ManagedCalculator c) => c.groupId == group.id).toList()
                    ..sort((ManagedCalculator a, ManagedCalculator b) => a.sortOrder.compareTo(b.sortOrder));
                  final List<ManagedCalculator> publishedCalcs = groupCalcs.where((ManagedCalculator c) => !c.isDraft).toList();
                  final int publishedCount = publishedCalcs.length;
                  final int draftCount = groupCalcs.length - publishedCount;

                  return Card(
                    margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      title: Text(group.name, style: Theme.of(context).textTheme.titleMedium),
                      subtitle: Text('$publishedCount published • $draftCount draft'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(tooltip: 'Rename', icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showEditGroupDialog(context, ref, group)),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => _confirmDeleteGroup(context, ref, group, groupCalcs.length),
                          ),
                          const Icon(Icons.expand_more),
                        ],
                      ),
                      children: <Widget>[
                        if (publishedCalcs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Text('No published calculators in this group.', style: Theme.of(context).textTheme.bodySmall),
                          ),
                        for (final ManagedCalculator calc in publishedCalcs)
                          _CalculatorTile(
                            calculator: calc,
                            onEdit: () => _openCalculatorEditor(context, calculator: calc),
                            onDuplicate: () => ref.read(managedCalculatorsProvider.notifier).duplicate(calc.id),
                            onDelete: () => _confirmDeleteCalculator(context, ref, calc),
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
                }(),
            ],
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
  const _GroupNameDialog({required this.title, required this.confirmLabel, this.initialValue = ''});

  final String title;
  final String confirmLabel;
  final String initialValue;

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Group Name', border: OutlineInputBorder()),
        onSubmitted: (String value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(_controller.text.trim()), child: Text(widget.confirmLabel)),
      ],
    );
  }
}

// ── Calculator tile ────────────────────────────────────────────────────────────

class _CalculatorTile extends StatelessWidget {
  const _CalculatorTile({required this.calculator, required this.onEdit, required this.onDuplicate, required this.onDelete});

  final ManagedCalculator calculator;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final String status = calculator.isDraft ? 'Draft' : 'Published';
    final Color statusColor = calculator.isDraft ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.primary;
    final String? metadata = !calculator.isDraft ? _formatPublishedMetadata(calculator) : null;
    final FormulaIconOption iconOption = formulaIconByKey(calculator.iconKey);

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
  const _DraftTile({required this.calculator, required this.groupName, required this.onEdit, required this.onDuplicate, required this.onDelete});

  final ManagedCalculator calculator;
  final String groupName;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final String sandboxStatus = calculator.sandboxTestPassed ? 'Sandbox passed' : 'Sandbox not passed';
    final String? lastTest = calculator.lastSandboxTestAt == null ? null : _CalculatorTile._formatDate(calculator.lastSandboxTestAt!);
    final FormulaIconOption iconOption = formulaIconByKey(calculator.iconKey);

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
