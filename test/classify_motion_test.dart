import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/activity_detection/domain/entities/motion_state.dart';
import 'package:fitness_tracker/features/activity_detection/domain/usecases/classify_motion.dart';

void main() {
  group('ClassifyMotion Usecase Tests', () {
    final classifier = ClassifyMotion();

    test('should classify magnitude < 10.5 as stationary', () {
      expect(classifier(9.8), MotionType.stationary);
      expect(classifier(10.49), MotionType.stationary);
    });

    test('should classify magnitude between 10.5 and 13.5 as walking', () {
      expect(classifier(10.5), MotionType.walking);
      expect(classifier(12.0), MotionType.walking);
      expect(classifier(13.49), MotionType.walking);
    });

    test('should classify magnitude >= 13.5 as running', () {
      expect(classifier(13.5), MotionType.running);
      expect(classifier(15.0), MotionType.running);
      expect(classifier(25.0), MotionType.running);
    });
  });
}
