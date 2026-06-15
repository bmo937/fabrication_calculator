import 'package:fabrication_calculator/providers/navigation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(appThemeModeProvider).valueOrNull ?? ThemeMode.system;
    final double zoom = ref.watch(appZoomProvider).valueOrNull ?? 1.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: const Text('Theme'),
                  subtitle: SegmentedButton<ThemeMode>(
                    segments: const <ButtonSegment<ThemeMode>>[
                      ButtonSegment<ThemeMode>(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment<ThemeMode>(value: ThemeMode.dark, label: Text('Dark')),
                      ButtonSegment<ThemeMode>(value: ThemeMode.system, label: Text('System')),
                    ],
                    selected: <ThemeMode>{themeMode},
                    onSelectionChanged: (Set<ThemeMode> selected) {
                      ref.read(appThemeModeProvider.notifier).setThemeMode(selected.first);
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.zoom_in_outlined),
                  title: Text('App Zoom (${zoom.toStringAsFixed(2)}x)'),
                  subtitle: Slider(
                    min: 0.8,
                    max: 1.4,
                    divisions: 6,
                    value: zoom.clamp(0.8, 1.4),
                    onChanged: (double value) {
                      ref.read(appZoomProvider.notifier).setZoom(value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('About', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Version'),
                  trailing: Text('1.0.0', style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Data', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ListTile(leading: const Icon(Icons.upload_outlined), title: const Text('Export Formulas'), subtitle: const Text('Coming soon'), enabled: false, onTap: null),
                ListTile(leading: const Icon(Icons.download_outlined), title: const Text('Import Formulas'), subtitle: const Text('Coming soon'), enabled: false, onTap: null),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
