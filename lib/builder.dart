import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/air_state_generator.dart';

/// Builder for Air Framework code generation
/// Uses PartBuilder to generate proper part files
Builder airGenerator(BuilderOptions options) =>
    PartBuilder([AirStateGenerator()], '.air.g.dart');
