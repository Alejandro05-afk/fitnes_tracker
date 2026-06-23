import '../entities/activity_record.dart';
import '../repositories/activity_history_repository.dart';

class CreateActivityRecord {
  final ActivityHistoryRepository repository;

  CreateActivityRecord(this.repository);

  Future<ActivityRecord> call(ActivityRecord record) {
    return repository.create(record);
  }
}
