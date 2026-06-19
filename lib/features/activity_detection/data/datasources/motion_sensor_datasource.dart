import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

import '../../domain/entities/fall_event.dart';
import '../../domain/entities/motion_state.dart';
import '../../domain/usecases/classify_motion.dart';

abstract class MotionSensorDataSource {
  Stream<MotionState> get motionStream;
  Stream<FallEvent> get fallStream;
  void start();
  void dispose();
}

class MotionSensorDataSourceImpl implements MotionSensorDataSource {
  MotionSensorDataSourceImpl({ClassifyMotion? classifier})
      : _classifier = classifier ?? ClassifyMotion();

  final ClassifyMotion _classifier;

  // Suavizado por promedio móvil (ver SKILL.md 0.2).
  static const int _windowSize = 12;
  final Queue<double> _magnitudeWindow = Queue<double>();

  // Umbrales de caída (ver SKILL.md 0.3 y 0.4).
  // Se usa un umbral de caída libre sobre la aceleración instantánea calibrado a 2.5.
  static const double _freeFallThreshold = 2.5;
  static const double _impactThreshold = 30.0;
  static const Duration _fallWindow = Duration(milliseconds: 1500);

  DateTime? _freeFallDetectedAt;
  StreamSubscription<AccelerometerEvent>? _subscription;

  final StreamController<MotionState> _motionController =
      StreamController<MotionState>.broadcast();
  final StreamController<FallEvent> _fallController =
      StreamController<FallEvent>.broadcast();

  // Historial de clasificaciones para el filtro de mayoría móvil
  final Queue<MotionType> _typeHistory = Queue<MotionType>();
  static const int _historySize = 50;

  @override
  Stream<MotionState> get motionStream => _motionController.stream;

  @override
  Stream<FallEvent> get fallStream => _fallController.stream;

  @override
  void start() {
    _subscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval, // ~20ms, igual a SENSOR_DELAY_GAME nativo
    ).listen(_onEvent, onError: (Object error) {
      // Sensor no disponible en el dispositivo: no se relanza, se ignora
      // para no tumbar la app (mismo criterio que el resto del proyecto).
    }, cancelOnError: false);
  }

  void _onEvent(AccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    _magnitudeWindow.addLast(magnitude);
    if (_magnitudeWindow.length > _windowSize) {
      _magnitudeWindow.removeFirst();
    }

    final avg = _magnitudeWindow.reduce((a, b) => a + b) / _magnitudeWindow.length;

    _checkFallPattern(magnitude);
    _emitMotionState(avg);
  }

  void _emitMotionState(double avg) {
    final rawType = _classifier(avg);

    // Guardar en el historial para filtro de estabilidad
    _typeHistory.addLast(rawType);
    if (_typeHistory.length > _historySize) {
      _typeHistory.removeFirst();
    }

    // Contar las ocurrencias de movimiento en el historial de 1 segundo (50 muestras)
    int walkingCount = 0;
    int runningCount = 0;
    for (final type in _typeHistory) {
      if (type == MotionType.walking) walkingCount++;
      if (type == MotionType.running) runningCount++;
    }

    // Filtro de retención de picos (Peak Hold / Envolvente)
    // Si hay suficiente actividad en el último segundo, cambiamos el estado.
    MotionType finalType;
    if (runningCount >= 6) {
      finalType = MotionType.running;
    } else if (walkingCount + runningCount >= 6) {
      finalType = MotionType.walking;
    } else {
      finalType = MotionType.stationary;
    }

    _motionController.add(MotionState(
      type: finalType,
      magnitude: avg,
      timestamp: DateTime.now(),
    ));
  }

  void _checkFallPattern(double rawMagnitude) {
    final now = DateTime.now();

    // Fase 1: caída libre — magnitud cae por debajo de 2.5 m/s².
    if (rawMagnitude < _freeFallThreshold) {
      _freeFallDetectedAt = now;
      return;
    }

    // Fase 2: impacto dentro de la ventana posterior a la caída libre.
    if (_freeFallDetectedAt != null &&
        rawMagnitude > _impactThreshold &&
        now.difference(_freeFallDetectedAt!) <= _fallWindow) {
      _fallController.add(FallEvent(
        impactMagnitude: rawMagnitude,
        timestamp: now,
      ));
      _freeFallDetectedAt = null; // evita disparar múltiples veces por el mismo impacto
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _motionController.close();
    _fallController.close();
  }
}
