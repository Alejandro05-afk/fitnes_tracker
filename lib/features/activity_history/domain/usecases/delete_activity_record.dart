import '../repositories/activity_history_repository.dart';

class DeleteActivityRecord {
  final ActivityHistoryRepository repository;

  DeleteActivityRecord(this.repository);

  Future<void> call(int id) {
    return repository.delete(id);
  }
}
