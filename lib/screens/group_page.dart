import 'package:fabrication_calculator/models/formula_icon_option.dart';
import 'package:fabrication_calculator/models/managed_calculator.dart';
import 'package:fabrication_calculator/providers/calculator_registry_provider.dart';
import 'package:fabrication_calculator/screens/managed_calculator_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupPage extends ConsumerWidget {
  const GroupPage({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ManagedCalculator> calculators = ref.watch(calculatorsByGroupProvider(groupId));

    if (calculators.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.calculate_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('No formulas in this group', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text('Use Manage Formulas to add formulas.', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      itemCount: calculators.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final ManagedCalculator calc = calculators[index];
        final FormulaIconOption iconOption = formulaIconByKey(calc.iconKey);
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              child: Text(iconOption.glyph, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            title: Text(calc.name),
            subtitle: calc.description.isNotEmpty ? Text(calc.description, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ManagedCalculatorPage(calculator: calc)));
            },
          ),
        );
      },
    );
  }
}
