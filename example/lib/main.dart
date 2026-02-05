// ignore_for_file: unused_field

import 'package:air_generator/air_generator.dart';

// part 'main.air.g.dart'; // This would be generated

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
    await Future.delayed(const Duration(seconds: 1));
    isLoading = false;
    count = count + 1;
  }

  @override
  void decrement() {
    count = count - 1;
  }
}

// Mock base class for example purposes (normally generated) into *.air.g.dart
abstract class _NotificationsState {
  set isLoading(bool value) {}
  bool get isLoading => false;
  set count(int value) {}
  int get count => 0;
  void increment();
  void decrement();
}

void main() {
  print('Run build_runner to generate code for NotificationsState.');
}
