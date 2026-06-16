# Fabrication Calculator (Workshop Helper)

A Flutter app for workshop and fabrication workflows that combines:

- A built-in traditional calculator with expression history
- User-managed formula groups and calculators
- Draft and publish flow for custom calculators
- Persistent local storage for formulas, history, and app settings

The app title shown in UI is **Workshop Helper**.

## Features

- Calculator
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

Sandbox flow in the editor:

1. Define input/output fields (each input has a required numeric test value).
2. Write formula code in line-based assignments.
3. Click **Run Test**.
4. Fix any reported line-level error until status is **passed**.
5. Publish only after a successful sandbox run.

If inputs/outputs/code are changed, sandbox status is reset and must be re-run before publishing.

Math formula format is line-based assignment:

```txt
target = expression;
```

Example:

```txt
spacing = length / (holes + 1);
hole1 = round(spacing * 1);
is_thick = thickness > 2;
factor = if(is_thick, 1.25, 1.0);
k = lookup(material_code, 1, 0.44, 2, 0.33, 0.40);
result = hole1 * factor * k;
```

Supported expression features:

- Arithmetic: `+`, `-`, `*`, `/`, `^`, parentheses
- Comparisons: `>`, `<`, `>=`, `<=`, `==`, `!=`
- Logic: `&&`, `||`, `!`
- Built-in constants: `pi`, `e`
- Built-in math functions from parser (for example `sqrt`, `sin`, `cos`, `pow`, `min`, `max`)
- Sandbox custom functions:
  - `if(condition, trueValue, falseValue)`
  - `lookup(key, key1, value1, key2, value2, ..., defaultValue)`
  - `lookup2d(rowKey, colKey, row1, col1, value1, row2, col2, value2, ..., defaultValue)`
  - `round(value)`

Behavior details:

- Temporary variables are supported and can be reused across later lines.
- Outputs can be assigned in any order, but each declared output key must be assigned by the end.
- Booleans are numeric (`true = 1`, `false = 0`).
- `if()`, `&&`, and `||` short-circuit (unused branches/operands are not evaluated).

Validation and error rules:

- Every output key must be assigned exactly once.
- Input keys cannot be assigned.
- Reserved constants (`pi`, `e`) cannot be assigned.
- Unknown identifiers fail with an explicit error.
- Unknown input keys in the test payload fail sandbox execution.
- Non-finite results (for example divide-by-zero paths that evaluate) fail execution.
- Syntax/format errors are reported with line numbers in the form `Line N: ...`.

Publishing rule:

- Drafts can be saved anytime.
- Publishing a calculator requires sandbox status = passed.

Current language support:

- Automatic runtime sandbox is available only for `math` code language.
- Other languages are currently authoring-only and require manual verification.

Simple area/perimeter example:

```txt
area = width * height;
perimeter = 2 * (width + height);
```

### Formula Patterns (Recipes)

Use these as starting templates when building custom calculators.

Running totals:

```txt
t1 = value1;
t2 = t1 + value2;
t3 = t2 + value3;
t4 = t3 + value4;
```

Even spacing / repeated offsets:

```txt
spacing = length / (holes + 1);
hole1 = round(spacing * 1);
hole2 = round(spacing * 2);
hole3 = round(spacing * 3);
```

Threshold-based factor with `if()`:

```txt
area = width * height;
is_thick = thickness > 2;
factor = if(is_thick, 1.25, 1.0);
result = area * factor;
```

Single-key lookup table (`lookup`):

```txt
k = lookup(material_code, 1, 0.44, 2, 0.33, 3, 0.28, 0.40);
result = base * k;
```

Two-key lookup table (`lookup2d`):

```txt
rate = lookup2d(size_code, grade_code,
  1, 1, 10,
  1, 2, 12,
  2, 1, 14,
  2, 2, 16,
  9);
result = qty * rate;
```

### Sandbox Troubleshooting

| Error (example) | Likely cause | Fix |
|---|---|---|
| `Line 3: Use "outputKey = expression;" format.` | Line is not a valid assignment. | Use exactly one assignment per non-comment line, like `target = expression;`. |
| `Line N: "length" is an input key and cannot be assigned.` | Formula tries to overwrite an input field key. | Write to a temp variable or output key instead. |
| `Line N: "result" output is already assigned.` | Same output key assigned more than once. | Keep one final assignment per output key. |
| `Missing assignments for: result.` | At least one declared output key was never assigned. | Add assignment lines for every output key. |
| `Unknown identifier "foo".` | Typo or missing input/temp/output variable. | Correct spelling or define it on an earlier line. |
| `Invalid test value for "width".` | Test input is blank or non-numeric. | Enter a numeric value for every input test field. |
| `Expression result is not finite.` | Runtime path produced `NaN`/infinity (for example divide-by-zero). | Add guards with `if()` and safe defaults. |
| `lookup() requires key/value pairs and a final default value.` | Wrong argument count/order for `lookup`. | Use `lookup(key, key1, value1, key2, value2, ..., defaultValue)`. |
| `lookup2d() requires row/col/value tuples and a final default value.` | Wrong argument structure for `lookup2d`. | Use `lookup2d(rowKey, colKey, row1, col1, value1, ..., defaultValue)`. |
| `Automatic sandbox is unavailable for <language>. Use manual verification.` | Code language is not `math`. | Keep calculator in `math` for auto sandbox, or verify manually. |

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
