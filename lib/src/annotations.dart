/// Pure Dart annotations for Air Framework code generation
/// These are duplicated from air_framework to avoid Flutter dependencies
library;

/// Annotation to mark a class as an Air state.
/// By convention, private fields become StateFlows and public void methods become Pulses.
class GenerateState {
  final String moduleId;
  final bool generateAccessors;
  final bool includeDocs;

  const GenerateState(
    this.moduleId, {
    this.generateAccessors = true,
    this.includeDocs = true,
  });
}

/// Annotation to mark a method as a pulse
class Pulse {
  final String? name;
  final String? description;

  const Pulse({this.name, this.description});
}

/// Annotation to mark a field as a state flow
class StateFlow {
  final String? name;
  final bool persist;
  final String? description;

  const StateFlow({this.name, this.persist = false, this.description});
}
