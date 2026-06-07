# Fabrication Calculator (Workshop Helper)

A Flutter app for workshop and fabrication workflows that combines:

- A built-in traditional calculator with expression history
- User-managed formula groups and calculators
- Draft and publish flow for custom calculators
- Persistent local storage for formulas, history, and app settings

The app title shown in UI is **Workshop Helper**.

## Features

- Traditional calculator
  - Supports standard operators and expression parsing
  - In-app history sheet for quick reuse of past results
- Formula management
  - Create, rename, and delete formula groups
  - Add, edit, duplicate, and delete calculators inside each group
  - Draft vs published status for safer iteration
- Custom calculator schema
  - Define multiple input fields and output fields
  - Assign icon, description, and ordering metadata
- Sandbox validation
  - Run test inputs against formula code before publishing
  - Publishing requires a successful sandbox run
- App settings
  - Theme mode: Light / Dark / System
  - Adjustable text zoom
- Local persistence
  - Data stored with Hive (no backend required)

## Tech Stack

- Flutter (Material 3)
- Dart SDK ^3.12.1
- State management: flutter_riverpod
- Local storage: hive + hive_flutter
- Formula parsing/evaluation: math_expressions
- IDs: uuid

## Project Structure

```text
lib/
  main.dart                         App bootstrap, Hive init, app shell
  calculators/                      Converter and measurement helpers
  models/                           Hive-backed data models
  providers/                        Riverpod providers and controllers
  repositories/                     Data access layer (Hive boxes)
  screens/                          UI pages (calculator, manage, settings)
  services/                         Sandbox execution and related logic
test/
  measurement_utils_test.dart
```

## Getting Started

### Prerequisites

- Flutter SDK installed
- A configured device/emulator (Android, iOS, web, or desktop target)

Check your environment:

```bash
flutter doctor
```

### Install Dependencies

```bash
flutter pub get
```

### Run the App

```bash
flutter run
```

## Development Commands

Run tests:

```bash
flutter test
```

Regenerate Hive model adapters (when model fields/annotations change):

```bash
dart run build_runner build --delete-conflicting-outputs
```

Optional continuous generation while editing models:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## How to Use

1. Launch the app and open the drawer.
2. Use **Calculator** for quick calculations.
3. Open **Manage Formulas** to create a formula group.
4. Add a formula and define input/output keys and labels.
5. Enter formula code and run the sandbox test.
6. Save as draft while iterating, then publish when validated.
7. Open the formula group from the drawer to use published calculators.

## Formula Authoring Notes

The automatic sandbox currently validates the **math** code language.

Math formula format is line-based assignment:

```txt
outputKey = expression;
```

Example:

```txt
area = width * height;
perimeter = 2 * (width + height);
```

Rules:

- Every output key must be assigned exactly once
- Input and output keys must be valid identifiers (letters, numbers, underscore)
- Use defined input/output keys only
- Constants like `pi` and `e` are available in math expressions

## Data Storage

The app stores data locally using Hive boxes, including:

- Formula groups
- Managed calculators (draft/published)
- Calculator history entries
- App settings (theme, zoom, last selected calculator)

## Roadmap

Potential next enhancements based on current UI placeholders:

- Formula export
- Formula import

## License

No license file is currently included in this repository. Add a `LICENSE` file if you plan to distribute the project.
