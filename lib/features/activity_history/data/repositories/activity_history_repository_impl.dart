import '../../domain/entities/activity_record.dart';
import '../../domain/repositories/activity_history_repository.dart';
import '../datasources/activity_history_local_datasource.dart';
import '../models/activity_record_model.dart';

class ActivityHistoryRepositoryImpl implements ActivityHistoryRepository {
  final ActivityHistoryLocalDatasource datasource;

  ActivityHistoryRepositoryImpl(this.datasource);

  @override
  Future<ActivityRecord> create(ActivityRecord record) async {
    final model = ActivityRecordModel.fromEntity(record);
    final inserted = await datasource.insert(model);
    return inserted.toEntity();
  }

  @override
  Future<List<ActivityRecord>> getAll() async {
    final models = await datasource.getAll();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<ActivityRecord?> getById(int id) async {
    final model = await datasource.getById(id);
    return model?.toEntity();
  }

  @override
  Future<ActivityRecord> update(ActivityRecord record) async {
    final model = ActivityRecordModel.fromEntity(record);
    await datasource.update(model);
    return record;
  }

  @override
  Future<void> delete(int id) async {
    await datasource.delete(id);
  }
}
