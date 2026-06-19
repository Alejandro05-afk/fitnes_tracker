import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/activity_detection/domain/entities/motion_state.dart';
import 'package:fitness_tracker/features/activity_detection/domain/entities/fall_event.dart';
import 'package:fitness_tracker/features/activity_detection/data/datasources/motion_sensor_datasource.dart';
import 'package:fitness_tracker/features/activity_detection/data/datasources/voice_announcer.dart';
import 'package:fitness_tracker/features/activity_detection/presentation/cubit/activity_detection_cubit.dart';

class FakeMotionSensorDataSource implements MotionSensorDataSource {
  final _motionController = StreamController<MotionState>.broadcast();
  final _fallController = StreamController<FallEvent>.broadcast();

  @override
  Stream<MotionState> get motionStream => _motionController.stream;

  @override
  Stream<FallEvent> get fallStream => _fallController.stream;

  bool isStarted = false;

  @override
  void start() {
    isStarted = true;
  }

  void emitMotion(MotionType type) {
    _motionController.add(MotionState(
      type: type,
      magnitude: 1.0,
      timestamp: DateTime.now(),
    ));
  }

  void emitFall() {
    _fallController.add(FallEvent(
      impactMagnitude: 30.0,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _motionController.close();
    _fallController.close();
  }
}

class FakeVoiceAnnouncer implements VoiceAnnouncer {
  final List<String> spokenTexts = [];

  @override
  Future<void> speak(String text) async {
    spokenTexts.add(text);
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  late FakeMotionSensorDataSource dataSource;
  late FakeVoiceAnnouncer announcer;
  late ActivityDetectionCubit cubit;

  setUp(() {
    dataSource = FakeMotionSensorDataSource();
    announcer = FakeVoiceAnnouncer();
    cubit = ActivityDetectionCubit(dataSource: dataSource, announcer: announcer);
  });

  tearDown(() {
    cubit.close();
  });

  test('should start datasource and listen to streams', () {
    expect(dataSource.isStarted, isFalse);
    cubit.start();
    expect(dataSource.isStarted, isTrue);
  });

  test('should emit state immediately when motion changes', () async {
    cubit.start();

    // Verify initial state
    expect(cubit.state.currentType, MotionType.stationary);

    // Emit walking
    dataSource.emitMotion(MotionType.walking);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.currentType, MotionType.walking);
  });

  test('should announce stable state after 3 seconds', () async {
    cubit.start();

    // Emit walking
    dataSource.emitMotion(MotionType.walking);
    await Future<void>.delayed(Duration.zero);

    // Should not have spoken yet (debounce is 3 seconds)
    expect(announcer.spokenTexts, isEmpty);

    // Wait 3.1 seconds
    await Future<void>.delayed(const Duration(milliseconds: 3100));

    expect(announcer.spokenTexts, contains('Estás caminando'));
  });

  test('should not announce intermediate states if changed within 3 seconds', () async {
    cubit.start();

    // Emit walking, then running 1 second later
    dataSource.emitMotion(MotionType.walking);
    await Future<void>.delayed(const Duration(seconds: 1));
    dataSource.emitMotion(MotionType.running);
    await Future<void>.delayed(const Duration(seconds: 1));

    // At 2 seconds, no announcement should be made
    expect(announcer.spokenTexts, isEmpty);

    // Wait another 2.1 seconds (running has now been stable for 3.1s)
    await Future<void>.delayed(const Duration(milliseconds: 2100));

    // Only 'Estás corriendo' should be announced
    expect(announcer.spokenTexts, contains('Estás corriendo'));
    expect(announcer.spokenTexts, isNot(contains('Estás caminando')));
  });

  test('should suspect fall and speak warning when fall occurs', () async {
    cubit.start();

    expect(cubit.state.isFallSuspected, isFalse);

    dataSource.emitFall();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.isFallSuspected, isTrue);
    expect(announcer.spokenTexts, contains('Se ha detectado una posible caída. Por favor confirme si se encuentra bien.'));
  });
}
