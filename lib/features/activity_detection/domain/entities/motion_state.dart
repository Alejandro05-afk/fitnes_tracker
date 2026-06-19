import 'package:equatable/equatable.dart';

/// Estados de actividad física detectados a partir del acelerómetro.
enum MotionType { stationary, walking, running }

class MotionState extends Equatable {
  final MotionType type;
  final double magnitude;
  final DateTime timestamp;

  const MotionState({
    required this.type,
    required this.magnitude,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [type, magnitude, timestamp];
}
