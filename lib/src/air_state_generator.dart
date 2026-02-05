import 'package:analyzer/dart/element/element.dart' hide Metadata;
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

/// Generator for @GenerateState annotation from air_framework
/// Uses name matching since annotations come from a different package
class AirStateGenerator extends Generator {
  @override
  String? generate(LibraryReader library, BuildStep buildStep) {
    final buffer = StringBuffer();

    for (final annotatedElement in library.classes) {
      // Check if class has @GenerateState annotation by name
      final annotation = _findGenerateStateAnnotation(annotatedElement);
      if (annotation != null) {
        buffer.writeln(_generateForClass(annotatedElement, annotation));
      }
    }

    final output = buffer.toString();
    return output.isEmpty ? null : output;
  }

  ConstantReader? _findGenerateStateAnnotation(ClassElement element) {
    for (final annotation in element.metadata.annotations) {
      final value = annotation.computeConstantValue();
      final typeName = value?.type?.getDisplayString() ?? '';
      if (typeName == 'GenerateState') {
        return ConstantReader(value);
      }
    }
    return null;
  }

  String _generateForClass(
    ClassElement classElement,
    ConstantReader annotation,
  ) {
    final className = classElement.name ?? '';
    final moduleId = annotation.read('moduleId').stringValue;

    // Convention: Public void methods (not lifecycle) → Pulses
    final pulseMethods = <_PulseInfo>[];
    final excludedMethods = {
      'onInit',
      'onPulses',
      'dispose',
      'toString',
      'noSuchMethod',
    };

    for (final method in classElement.methods) {
      // Skip private methods, lifecycle methods
      if (method.isPrivate) continue;
      if (method.isStatic) continue;
      if (excludedMethods.contains(method.name)) continue;

      // Support void and Future<void>
      final isVoid = method.returnType is VoidType;
      final isFutureVoid =
          method.returnType.isDartAsyncFuture &&
          method.returnType is ParameterizedType &&
          (method.returnType as ParameterizedType).typeArguments.isNotEmpty &&
          (method.returnType as ParameterizedType).typeArguments.first
              is VoidType;

      if (!isVoid && !isFutureVoid) continue;

      // Check for explicit @Pulse annotation OR use convention
      final pulseAnnotation = _getPulseAnnotation(method);
      pulseMethods.add(
        _PulseInfo(
          name: method.name ?? '',
          customName: pulseAnnotation?.read('name').isNull ?? true
              ? null
              : pulseAnnotation!.read('name').stringValue,
          parameters: method.formalParameters,
          isAsync: isFutureVoid,
        ),
      );
    }

    // Convention: Private fields → StateFlows
    final flowFields = <_FlowInfo>[];

    for (final field in classElement.fields) {
      // Only private fields become flows
      if (!field.isPrivate) continue;
      if (field.isStatic) continue;

      // Get the default value from the field initializer if possible
      String? defaultValue;

      // Try to get initializer from source if computeConstantValue fails
      // Note: In a generator, we can sometimes get the node
      final initializer = field.computeConstantValue();
      defaultValue ??= ConstantReader(initializer).literalValue?.toString();

      // Fallback to type defaults if we can't determine the value
      defaultValue ??= _getDefaultForType(field.type.getDisplayString());

      // Check for explicit @StateFlow annotation for custom options
      final flowAnnotation = _getFlowAnnotation(field);

      flowFields.add(
        _FlowInfo(
          name: field.name ?? '',
          customName: flowAnnotation?.read('name').isNull ?? true
              ? null
              : flowAnnotation!.read('name').stringValue,
          type: field.type.getDisplayString(),
          hasDefault: field.hasInitializer,
          defaultValue: defaultValue,
        ),
      );
    }

    // Generate code
    final buffer = StringBuffer();

    // Generate Pulses class
    buffer.writeln(_generatePulsesClass(className, moduleId, pulseMethods));
    buffer.writeln();

    // Generate Flows class
    buffer.writeln(_generateFlowsClass(className, moduleId, flowFields));
    buffer.writeln();

    // Generate base state class
    buffer.writeln(
      _generateBaseClass(className, moduleId, pulseMethods, flowFields),
    );

    return buffer.toString();
  }

  ConstantReader? _getPulseAnnotation(MethodElement method) {
    for (final annotation in (method.metadata.annotations)) {
      final value = annotation.computeConstantValue();
      final typeName = value?.type?.getDisplayString() ?? '';
      if (typeName == 'Pulse') {
        return ConstantReader(value);
      }
    }
    return null;
  }

  ConstantReader? _getFlowAnnotation(FieldElement field) {
    for (final annotation in field.metadata.annotations) {
      final value = annotation.computeConstantValue();
      final typeName = value?.type?.getDisplayString() ?? '';
      if (typeName == 'StateFlow') {
        return ConstantReader(value);
      }
    }
    return null;
  }

  String _generatePulsesClass(
    String className,
    String moduleId,
    List<_PulseInfo> pulses,
  ) {
    final baseName = className.replaceAll('State', '');
    final buffer = StringBuffer();

    buffer.writeln('/// Pulses for the $baseName module');
    buffer.writeln('class ${baseName}Pulses {');
    buffer.writeln('  ${baseName}Pulses._();');
    buffer.writeln();

    for (final pulse in pulses) {
      final pulseName = pulse.customName ?? pulse.name;
      final paramType = pulse.parameters.isEmpty
          ? 'void'
          : pulse.parameters.length == 1
          ? pulse.parameters.first.type.getDisplayString()
          : _buildRecordType(pulse.parameters);

      buffer.writeln('  /// Pulse: $pulseName');
      buffer.writeln(
        '  static const ${pulse.name} = AirPulse<$paramType>(\'$moduleId.${pulse.name}\');',
      );
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  String _generateFlowsClass(
    String className,
    String moduleId,
    List<_FlowInfo> flows,
  ) {
    final baseName = className.replaceAll('State', '');
    final buffer = StringBuffer();

    buffer.writeln('/// Flows for the $baseName module');
    buffer.writeln('class ${baseName}Flows {');
    buffer.writeln('  ${baseName}Flows._();');
    buffer.writeln();

    for (final flow in flows) {
      final flowName = flow.customName ?? flow.publicName;
      buffer.writeln('  /// Flow: $flowName');
      if (flow.defaultValue != null) {
        buffer.writeln(
          '  static const ${flow.publicName} = SimpleStateKey<${flow.type}>(\'$moduleId.${flow.publicName}\', defaultValue: ${flow.defaultValue});',
        );
      } else {
        buffer.writeln(
          '  static const ${flow.publicName} = SimpleStateKey<${flow.type}>(\'$moduleId.${flow.publicName}\');',
        );
      }
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  String _generateBaseClass(
    String className,
    String moduleId,
    List<_PulseInfo> pulses,
    List<_FlowInfo> flows,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('/// Base class for $className');
    buffer.writeln('abstract class _$className extends AirState {');
    buffer.writeln('  _$className() : super(moduleId: \'$moduleId\');');
    buffer.writeln();

    // Generate abstract methods for pulses
    for (final pulse in pulses) {
      final params = pulse.parameters
          .map((p) => '${p.type.getDisplayString()} ${p.name}')
          .join(', ');
      buffer.writeln('  /// Handle ${pulse.name} pulse');
      final returnType = pulse.isAsync ? 'Future<void>' : 'void';
      buffer.writeln('  $returnType ${pulse.name}($params);');
    }
    buffer.writeln();

    // Generate flow accessors
    for (final flow in flows) {
      buffer.writeln('  /// Get ${flow.publicName} value');
      buffer.writeln(
        '  ${flow.type} get ${flow.publicName} => Air().typedGet(${className.replaceAll('State', '')}Flows.${flow.publicName});',
      );
      buffer.writeln();
      buffer.writeln('  /// Set ${flow.publicName} value');
      buffer.writeln(
        '  set ${flow.publicName}(${flow.type} value) => Air().typedFlow(${className.replaceAll('State', '')}Flows.${flow.publicName}, value, sourceModuleId: moduleId);',
      );
    }
    buffer.writeln();

    // Generate onPulses
    buffer.writeln('  @override');
    buffer.writeln('  void onPulses() {');
    for (final pulse in pulses) {
      final hasParams = pulse.parameters.isNotEmpty;
      buffer.writeln(
        '    on(${className.replaceAll('State', '')}Pulses.${pulse.name}, (${hasParams ? 'value' : '_'}, {onSuccess, onError}) async {',
      );
      buffer.writeln('      try {');
      final awaitStr = pulse.isAsync ? 'await ' : '';
      if (hasParams) {
        buffer.writeln('        $awaitStr${pulse.name}(value);');
      } else {
        buffer.writeln('        $awaitStr${pulse.name}();');
      }
      buffer.writeln('        onSuccess?.call();');
      buffer.writeln('      } catch (e) {');
      buffer.writeln('        onError?.call(e.toString());');
      buffer.writeln('      }');
      buffer.writeln('    });');
    }
    buffer.writeln('  }');
    buffer.writeln('}');

    return buffer.toString();
  }

  String _buildRecordType(List<FormalParameterElement> params) {
    final fields = params.map((p) => '${p.type.getDisplayString()} ${p.name}');
    return '({${fields.join(', ')}})';
  }

  /// Generate a default value for common types
  String? _getDefaultForType(String typeName) {
    final baseType = typeName.replaceAll('?', '').trim();

    switch (baseType) {
      case 'int':
        return '0';
      case 'double':
        return '0.0';
      case 'num':
        return '0';
      case 'bool':
        return 'false';
      case 'String':
        return "''";
      default:
        if (baseType.startsWith('List<')) return 'const []';
        if (baseType.startsWith('Map<')) return 'const {}';
        if (baseType.startsWith('Set<')) return 'const {}';
        if (typeName.endsWith('?')) return 'null';
        return null;
    }
  }
}

class _PulseInfo {
  final String name;
  final String? customName;
  final List<FormalParameterElement> parameters;
  final bool isAsync;

  _PulseInfo({
    required this.name,
    this.customName,
    required this.parameters,
    this.isAsync = false,
  });
}

class _FlowInfo {
  final String name;
  final String? customName;
  final String type;
  final bool hasDefault;
  final String? defaultValue;

  _FlowInfo({
    required this.name,
    this.customName,
    required this.type,
    this.hasDefault = false,
    this.defaultValue,
  });

  String get publicName {
    if (name.startsWith('_')) {
      return name.substring(1);
    }
    return name;
  }
}
