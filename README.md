# Fabrication Calculator

Flutter app foundation for fabrication, construction, and machining calculators.

## Architecture Rules

- Riverpod is used for all state management.
- Each calculator has its own provider file in `lib/providers`.
- Calculator formulas are pure Dart functions and are kept separate from UI widgets.
- Hive is used for calculator history persistence.
- History loading and saving flows are handled through async Riverpod notifiers.

## Folder Structure

```text
lib/
	calculators/
		unit_converter.dart
		converter_widget.dart
		measurement_utils.dart
		unit_converter_formulas.dart
	models/
		converter_formula.dart
		history_entry.dart
	providers/
		unit_converter_providers.dart
		history_providers.dart
		navigation_providers.dart
	repositories/
		history_repository.dart
	main.dart
```

## History Model

`HistoryEntry` fields:

- `calculatorName` (`String`)
- `inputs` (`Map<String, double>`)
- `result` (`double`)
- `timestamp` (`DateTime`)

## Current Foundation

- Drawer navigation with last-used calculator restore.
- Unit converter calculator scaffold using reusable converter widget.
- Conversion utilities:
	- millimeters <-> inches
	- decimal inches <-> nearest workshop fraction lookup
	- fraction string to decimal inches parser
- History retention: latest 100 entries per calculator.

## Add a New Calculator

When adding a calculator, always do all of the following:

1. Create calculator widget file in `lib/calculators/<calculator_name>.dart`.
2. Create provider file or provider block in `lib/providers/<calculator_name>_providers.dart`.
3. Implement formula logic in pure Dart functions (not inside widget build methods).
4. Save history via `historyControllerProvider.notifier.saveEntry(...)`.
5. Register calculator in `AppShell._calculators` inside `lib/main.dart`.
6. Add any unit converter style formulas via `ConverterFormula` where applicable.

## Useful Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```
