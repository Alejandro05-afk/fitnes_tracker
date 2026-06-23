import 'package:equatable/equatable.dart';

class ActivityRecord extends Equatable {
  final int? id;
  final String activityType;
  final int stepCount;
  final double distanceKm;
  final int durationSeconds;
  final double calories;
  final DateTime startTime;
  final DateTime? endTime;
  final DateTime createdAt;

  const ActivityRecord({
    this.id,
    required this.activityType,
    this.stepCount = 0,
    this.distanceKm = 0,
    this.durationSeconds = 0,
    this.calories = 0,
    required this.startTime,
    this.endTime,
    required this.createdAt,
  });

  ActivityRecord copyWith({
    int? id,
    String? activityType,
    int? stepCount,
    double? distanceKm,
    int? durationSeconds,
    double? calories,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? createdAt,
  }) {
    return ActivityRecord(
      id: id ?? this.id,
      activityType: activityType ?? this.activityType,
      stepCount: stepCount ?? this.stepCount,
      distanceKm: distanceKm ?? this.distanceKm,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      calories: calories ?? this.calories,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        activityType,
        stepCount,
        distanceKm,
        durationSeconds,
        calories,
        startTime,
        endTime,
        createdAt,
      ];
}
