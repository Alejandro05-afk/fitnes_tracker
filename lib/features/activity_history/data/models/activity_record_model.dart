import '../../domain/entities/activity_record.dart';

class ActivityRecordModel extends ActivityRecord {
  const ActivityRecordModel({
    super.id,
    required super.activityType,
    super.stepCount,
    super.distanceKm,
    super.durationSeconds,
    super.calories,
    required super.startTime,
    super.endTime,
    required super.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activityType': activityType,
      'stepCount': stepCount,
      'distanceKm': distanceKm,
      'durationSeconds': durationSeconds,
      'calories': calories,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ActivityRecordModel.fromMap(Map<String, dynamic> map) {
    return ActivityRecordModel(
      id: map['id'] as int?,
      activityType: map['activityType'] as String,
      stepCount: map['stepCount'] as int? ?? 0,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0,
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      calories: (map['calories'] as num?)?.toDouble() ?? 0,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: map['endTime'] != null
          ? DateTime.parse(map['endTime'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  factory ActivityRecordModel.fromEntity(ActivityRecord entity) {
    return ActivityRecordModel(
      id: entity.id,
      activityType: entity.activityType,
      stepCount: entity.stepCount,
      distanceKm: entity.distanceKm,
      durationSeconds: entity.durationSeconds,
      calories: entity.calories,
      startTime: entity.startTime,
      endTime: entity.endTime,
      createdAt: entity.createdAt,
    );
  }

  @override
  ActivityRecordModel copyWith({
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
    return ActivityRecordModel(
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

  ActivityRecord toEntity() {
    return ActivityRecord(
      id: id,
      activityType: activityType,
      stepCount: stepCount,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      calories: calories,
      startTime: startTime,
      endTime: endTime,
      createdAt: createdAt,
    );
  }
}
