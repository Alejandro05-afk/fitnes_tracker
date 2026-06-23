import '../entities/activity_record.dart';
import '../repositories/activity_history_repository.dart';

class GetActivityRecords {
  final ActivityHistoryRepository repository;

  GetActivityRecords(this.repository);

  Future<List<ActivityRecord>> call() {
    return repository.getAll();
  }
}
