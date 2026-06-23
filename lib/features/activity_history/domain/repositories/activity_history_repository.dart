import '../entities/activity_record.dart';

abstract class ActivityHistoryRepository {
  Future<ActivityRecord> create(ActivityRecord record);
  Future<List<ActivityRecord>> getAll();
  Future<ActivityRecord?> getById(int id);
  Future<ActivityRecord> update(ActivityRecord record);
  Future<void> delete(int id);
}
