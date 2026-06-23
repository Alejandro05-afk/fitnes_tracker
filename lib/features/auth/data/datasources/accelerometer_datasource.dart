import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/step_data.dart';

abstract class AccelerometerDataSource {
  Stream<StepData> get stepStream;
  Future<void> startCounting();
  Future<void> stopCounting();
  Future<bool> requestPermissions();
}

class AccelerometerDataSourceImpl implements AccelerometerDataSource {
  StreamSubscription<AccelerometerEvent>? _sub;
  final StreamController<StepData> _controller =
      StreamController<StepData>.broadcast();

  int _stepCount = 0;
  double _lastMagnitude = 0;
  final List<double> _history = [];
  static const int _historySize = 10;

  @override
  Stream<StepData> get stepStream => _controller.stream;

  @override
  Future<void> startCounting() async {
    _stepCount = 0;
    _sub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onEvent, cancelOnError: false);
  }

  void _onEvent(AccelerometerEvent e) {
    final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);

    _history.add(mag);
    if (_history.length > _historySize) _history.removeAt(0);
    final avg = _history.reduce((a, b) => a + b) / _history.length;

    if (mag > 12 && _lastMagnitude <= 12) _stepCount++;
    _lastMagnitude = mag;

    final type = avg < 10.5
        ? ActivityType.stationary
        : avg < 13.5
            ? ActivityType.walking
            : ActivityType.running;

    _controller.add(StepData(
      stepCount: _stepCount,
      activityType: type,
      magnitude: avg,
    ));
  }

  @override
  Future<void> stopCounting() async {
    await _sub?.cancel();
    _sub = null;
  }

  @override
  Future<bool> requestPermissions() async {
    final status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
