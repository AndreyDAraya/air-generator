import 'package:air_generator/builder.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

void main() {
  group('AirStateGenerator', () {
    test('generates Pulses and Flows classes', () async {
      final assets = {
        'air_generator|lib/air_generator.dart': '''
          class GenerateState {
            final String moduleId;
            const GenerateState(this.moduleId);
          }
          class Pulse {
            const Pulse();
          }
          class StateFlow {
            const StateFlow();
          }
        ''',
        'a|lib/test_state.dart': '''
          import 'package:air_generator/air_generator.dart';

          part 'test_state.air.g.dart';

          @GenerateState('counter')
          class CounterState extends _CounterState {
            final int _amount = 0;
            
            void increment() {
              print('plus one');
            }
          }
        ''',
      };

      final expectedOutput = {
        'a|lib/test_state.air.g.dart': decodedMatches(
          allOf(
            contains('class CounterPulses'),
            contains('class CounterFlows'),
            contains(
              'static const amount = SimpleStateKey<int>(\'counter.amount\'',
            ),
            contains('defaultValue: 0'),
            contains('abstract class _CounterState extends AirState'),
            contains('void increment();'),
          ),
        ),
      };

      await testBuilder(
        airGenerator(BuilderOptions.empty),
        assets,
        outputs: expectedOutput,
      );
    });

    test('generates code for basic types', () async {
      final assets = {
        'air_generator|lib/air_generator.dart': '''
          class GenerateState {
            final String moduleId;
            const GenerateState(this.moduleId);
          }
        ''',
        'a|lib/auth_state.dart': '''
          import 'package:air_generator/air_generator.dart';

          part 'auth_state.air.g.dart';

          @GenerateState('auth')
          class AuthState extends _AuthState {
            final int _code = 123;
            
            void refresh() {
              print('refreshing');
            }
          }
        ''',
      };

      final expectedOutput = {
        'a|lib/auth_state.air.g.dart': decodedMatches(
          allOf([
            contains('static const refresh = AirPulse<void>(\'auth.refresh\')'),
            contains(
              'static const code = SimpleStateKey<int>(\'auth.code\', defaultValue: 0)',
            ),
          ]),
        ),
      };

      await testBuilder(
        airGenerator(BuilderOptions.empty),
        assets,
        outputs: expectedOutput,
      );
    });
  });
}
