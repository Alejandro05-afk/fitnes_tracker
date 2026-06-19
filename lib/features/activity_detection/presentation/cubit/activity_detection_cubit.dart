import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/datasources/motion_sensor_datasource.dart';
import '../../data/datasources/voice_announcer.dart';
import '../../domain/entities/fall_event.dart';
import '../../domain/entities/motion_state.dart';

class ActivityDetectionState extends Equatable {
  final MotionType currentType;
  final bool isFallSuspected;

  const ActivityDetectionState({
    this.currentType = MotionType.stationary,
    this.isFallSuspected = false,
  });

  ActivityDetectionState copyWith({MotionType? currentType, bool? isFallSuspected}) {
    return ActivityDetectionState(
      currentType: currentType ?? this.currentType,
      isFallSuspected: isFallSuspected ?? this.isFallSuspected,
    );
  }

  @override
  List<Object?> get props => [currentType, isFallSuspected];
}

class ActivityDetectionCubit extends Cubit<ActivityDetectionState> {
  ActivityDetectionCubit({
    required MotionSensorDataSource dataSource,
    required VoiceAnnouncer announcer,
  })  : _dataSource = dataSource,
        _announcer = announcer,
        super(const ActivityDetectionState());

  final MotionSensorDataSource _dataSource;
  final VoiceAnnouncer _announcer;

  StreamSubscription<MotionState>? _motionSub;
  StreamSubscription<FallEvent>? _fallSub;

  // Debounce manual (ver SKILL.md 0.6): 3 segundos de estabilidad
  // antes de anunciar un cambio de estado.
  static const Duration _debounceWindow = Duration(seconds: 3);
  Timer? _debounceTimer;
  MotionType? _pendingType;
  MotionType _lastAnnouncedType = MotionType.stationary;

  void start() {
    _dataSource.start();

    _motionSub = _dataSource.motionStream.listen(_onMotion);
    _fallSub = _dataSource.fallStream.listen(_onFall);
  }

  void _onMotion(MotionState motion) {
    emit(state.copyWith(currentType: motion.type));

    if (motion.type == _pendingType) {
      // Mismo candidato que ya está esperando confirmación: no reiniciar timer.
      return;
    }

    // Llegó un tipo distinto al que se estaba esperando: reinicia el debounce.
    _pendingType = motion.type;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceWindow, () => _confirmStableState(motion.type));
  }

  void _confirmStableState(MotionType stableType) {
    if (stableType == _lastAnnouncedType) return; // evita avisos repetidos

    _lastAnnouncedType = stableType;
    _announcer.speak(_messageFor(stableType));
  }

  String _messageFor(MotionType type) {
    switch (type) {
      case MotionType.walking:
        return 'Estás caminando';
      case MotionType.running:
        return 'Estás corriendo';
      case MotionType.stationary:
        return 'Te has detenido';
    }
  }

  void _onFall(FallEvent event) {
    if (state.isFallSuspected) return; // ya hay un diálogo de caída activo
    emit(state.copyWith(isFallSuspected: true));
    _announcer.speak('Se ha detectado una posible caída. Por favor confirme si se encuentra bien.');
  }

  /// Llamado por la UI cuando el usuario confirma o se cierra el diálogo.
  void resolveFallSuspicion() {
    emit(state.copyWith(isFallSuspected: false));
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    _motionSub?.cancel();
    _fallSub?.cancel();
    _dataSource.dispose();
    _announcer.dispose();
    return super.close();
  }
}
