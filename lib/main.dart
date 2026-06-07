import 'package:fabrication_calculator/models/calculator_group.dart';
import 'package:fabrication_calculator/models/history_entry.dart';
import 'package:fabrication_calculator/models/managed_calculator.dart';
import 'package:fabrication_calculator/providers/calculator_registry_provider.dart';
import 'package:fabrication_calculator/providers/history_providers.dart';
import 'package:fabrication_calculator/providers/navigation_providers.dart';
import 'package:fabrication_calculator/screens/group_page.dart';
import 'package:fabrication_calculator/screens/manage_screen.dart';
import 'package:fabrication_calculator/screens/settings_screen.dart';
import 'package:fabrication_calculator/screens/traditional_calculator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(HistoryEntryAdapter());
  Hive.registerAdapter(CalculatorGroupAdapter());
  Hive.registerAdapter(ManagedCalculatorAdapter());
  await Hive.openBox<HistoryEntry>('history_entries');

  runApp(const ProviderScope(child: FabricationCalculatorApp()));
}

class FabricationCalculatorApp extends StatelessWidget {
  const FabricationCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AppRoot();
  }
}

class _AppRoot extends ConsumerWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(appThemeModeProvider).valueOrNull ?? ThemeMode.system;
    final double zoom = ref.watch(appZoomProvider).valueOrNull ?? 1.0;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Workshop Helper',
      theme: ThemeData(colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: Colors.blueGrey, useMaterial3: true, brightness: Brightness.dark),
      themeMode: themeMode,
      builder: (BuildContext context, Widget? child) {
        if (child == null) return const SizedBox.shrink();
        final MediaQueryData data = MediaQuery.of(context);
        return MediaQuery(
          data: data.copyWith(textScaler: TextScaler.linear(zoom)),
          child: child,
        );
      },
      home: const AppShell(),
    );
  }
}

// Route-id conventions:
//   'settings'                -> Settings screen
//   'manage'                  -> Manage screen
//   'group:<uuid>'            -> Group page for the given group

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static final Map<String, _BuiltInDef> _builtIns = <String, _BuiltInDef>{
    'calculator:traditional': const _BuiltInDef(id: 'calculator:traditional', title: 'Calculator', builder: TraditionalCalculatorScreen.new),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String> activeRouteAsync = ref.watch(activeCalculatorProvider);
    final List<CalculatorGroup> groups = ref.watch(calculatorGroupsProvider).valueOrNull ?? <CalculatorGroup>[];

    // Keep history in sync with built-in calculator routes
    ref.listen<AsyncValue<String>>(activeCalculatorProvider, (_, AsyncValue<String> next) {
      final String? routeId = next.valueOrNull;
      if (routeId == null) return;
      if (_builtIns.containsKey(routeId)) {
        ref.read(historyControllerProvider.notifier).loadForCalculator(_builtIns[routeId]!.title);
      }
    });

    return activeRouteAsync.when(
      data: (String routeId) {
        final String appBarTitle = _resolveTitle(routeId, groups);
        final Widget body = _resolveBody(routeId, groups);

        return Scaffold(
          appBar: AppBar(title: Text(appBarTitle)),
          drawer: _AppDrawer(activeRouteId: routeId, groups: groups, builtIns: _builtIns),
          body: body,
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, _) => Scaffold(body: Center(child: Text('Failed to load: $error'))),
    );
  }

  static String _resolveTitle(String routeId, List<CalculatorGroup> groups) {
    if (routeId == 'settings') return 'Settings';
    if (routeId == 'manage') return 'Manage Formulas';
    final _BuiltInDef? builtIn = _builtIns[routeId];
    if (builtIn != null) return builtIn.title;
    if (routeId.startsWith('group:')) {
      final String groupId = routeId.substring(6);
      return groups.where((CalculatorGroup g) => g.id == groupId).map((CalculatorGroup g) => g.name).firstOrNull ?? 'Group';
    }
    if (groups.isNotEmpty) return groups.first.name;
    return 'Manage Formulas';
  }

  static Widget _resolveBody(String routeId, List<CalculatorGroup> groups) {
    if (routeId == 'settings') return const SettingsScreen();
    if (routeId == 'manage') return const ManageScreen();
    final _BuiltInDef? builtIn = _builtIns[routeId];
    if (builtIn != null) return builtIn.builder();
    if (routeId.startsWith('group:')) {
      return GroupPage(groupId: routeId.substring(6));
    }
    if (groups.isNotEmpty) {
      return GroupPage(groupId: groups.first.id);
    }
    return const ManageScreen();
  }
}

// ── Drawer ────────────────────────────────────────────────────────────────────

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer({required this.activeRouteId, required this.groups, required this.builtIns});

  final String activeRouteId;
  final List<CalculatorGroup> groups;
  final Map<String, _BuiltInDef> builtIns;

  Future<void> _navigate(BuildContext context, WidgetRef ref, String routeId) async {
    await ref.read(activeCalculatorProvider.notifier).setActiveCalculator(routeId);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            // ── Header ─────────────────────────────────────────────────
            const DrawerHeader(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text('Workshop\nHelper', style: TextStyle(fontSize: 18)),
              ),
            ),
            // ── Built-in calculators ───────────────────────────────────
            if (builtIns.isNotEmpty) ...<Widget>[
              const Divider(),
              for (final _BuiltInDef item in builtIns.values)
                ListTile(leading: const Icon(Icons.calculate_outlined), title: Text(item.title), selected: activeRouteId == item.id, onTap: () => _navigate(context, ref, item.id)),
            ],
            // ── Groups ─────────────────────────────────────────────────
            if (groups.isNotEmpty) ...<Widget>[
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Formulas', style: Theme.of(context).textTheme.labelSmall),
              ),
              for (final CalculatorGroup group in groups)
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(group.name),
                  selected: activeRouteId == 'group:${group.id}',
                  onTap: () => _navigate(context, ref, 'group:${group.id}'),
                ),
            ],
            // ── System ─────────────────────────────────────────────────
            const Divider(),
            ListTile(
              leading: const Icon(Icons.tune_outlined),
              title: const Text('Manage Formulas'),
              selected: activeRouteId == 'manage',
              onTap: () => _navigate(context, ref, 'manage'),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              selected: activeRouteId == 'settings',
              onTap: () => _navigate(context, ref, 'settings'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Built-in definition ───────────────────────────────────────────────────────

class _BuiltInDef {
  const _BuiltInDef({required this.id, required this.title, required this.builder});

  final String id;
  final String title;
  final Widget Function() builder;
}
