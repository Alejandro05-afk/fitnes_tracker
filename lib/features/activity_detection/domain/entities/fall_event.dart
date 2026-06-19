import 'package:equatable/equatable.dart';

/// Representa una posible caída detectada por el patrón
/// caída-libre -> impacto en la ventana de tiempo definida.
class FallEvent extends Equatable {
  final double impactMagnitude;
  final DateTime timestamp;

  const FallEvent({
    required this.impactMagnitude,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [impactMagnitude, timestamp];
}
