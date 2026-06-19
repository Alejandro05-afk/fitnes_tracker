import '../entities/motion_state.dart';

/// Umbrales justificados en SKILL.md sección 0.2.
/// Se replican los mismos cortes ya validados en el Platform Channel
/// nativo de pasos (MainActivity.kt) para mantener consistencia de
/// comportamiento percibido por el usuario.
class ClassifyMotion {
  static const double stationaryUpperBound = 10.5;
  static const double walkingUpperBound = 13.5;

  MotionType call(double averageMagnitude) {
    if (averageMagnitude < stationaryUpperBound) return MotionType.stationary;
    if (averageMagnitude < walkingUpperBound) return MotionType.walking;
    return MotionType.running;
  }
}
