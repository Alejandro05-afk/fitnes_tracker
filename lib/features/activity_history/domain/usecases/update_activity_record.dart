import '../entities/activity_record.dart';
import '../repositories/activity_history_repository.dart';

class UpdateActivityRecord {
  final ActivityHistoryRepository repository;

  UpdateActivityRecord(this.repository);

  Future<ActivityRecord> call(ActivityRecord record) {
    return repository.update(record);
  }
}
