# Air Generator

A robust code generator for the Air Framework that automates state management and module registration.

## Features

- **Simplified State Generation**: Annotate your class with `@GenerateState` and let the generator do the rest.
- **Convention over Configuration**:
  - Private fields (e.g., `_count`) automatically become **StateFlows**.
  - Public `void` or `Future<void>` methods automatically become **Pulses**.
- **Type Safety**: Generates typed keys and classes to avoid magic strings.
- **Async Support**: Automatically handles asynchronous pulses.

## Installation

Add `air_generator` and `build_runner` to your `dev_dependencies`:

```yaml
dev_dependencies:
  air_generator: ^1.0.0
  build_runner: ^2.4.0
```

## Usage

### Simple State Generation

Define your state class by extending the generated base class:

```dart
import 'package:air_generator/air_generator.dart';

part 'notifications_state.air.g.dart';

@GenerateState('notifications')
class NotificationsState extends _NotificationsState {
  NotificationsState();

  // Private fields → automatically become StateFlows
  final int _count = 0;
  final bool _isLoading = false;

  // Public void methods → automatically become Pulses
  @override
  void increment() async {
    isLoading = true;
    await Future.delayed(Duration(seconds: 1));
    isLoading = false;
    count = count + 1;
  }

  @override
  void decrement() {
    count = count - 1;
  }
}
```

Run the generator:

```bash
dart run build_runner build
```

The generator will create `notifications_state.air.g.dart` containing the `_NotificationsState` base class with all the reactive logic.

## Initial Values

The generator attempts to extract initial values from field initializers. For best results, use constant or literal values.

## License

MIT
