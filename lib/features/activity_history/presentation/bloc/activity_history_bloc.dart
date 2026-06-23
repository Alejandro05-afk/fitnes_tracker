import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/activity_record.dart';
import '../../domain/usecases/create_activity_record.dart';
import '../../domain/usecases/get_activity_records.dart';
import '../../domain/usecases/update_activity_record.dart';
import '../../domain/usecases/delete_activity_record.dart';

abstract class ActivityHistoryEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadActivityHistory extends ActivityHistoryEvent {}

class CreateActivityHistory extends ActivityHistoryEvent {
  final ActivityRecord record;
  CreateActivityHistory(this.record);
  @override
  List<Object?> get props => [record];
}

class UpdateActivityHistory extends ActivityHistoryEvent {
  final ActivityRecord record;
  UpdateActivityHistory(this.record);
  @override
  List<Object?> get props => [record];
}

class DeleteActivityHistory extends ActivityHistoryEvent {
  final int id;
  DeleteActivityHistory(this.id);
  @override
  List<Object?> get props => [id];
}

abstract class ActivityHistoryState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ActivityHistoryInitial extends ActivityHistoryState {}

class ActivityHistoryLoading extends ActivityHistoryState {}

class ActivityHistoryLoaded extends ActivityHistoryState {
  final List<ActivityRecord> records;
  ActivityHistoryLoaded(this.records);
  @override
  List<Object?> get props => [records];
}

class ActivityHistoryError extends ActivityHistoryState {
  final String message;
  ActivityHistoryError(this.message);
  @override
  List<Object?> get props => [message];
}

class ActivityHistoryBloc
    extends Bloc<ActivityHistoryEvent, ActivityHistoryState> {
  final CreateActivityRecord create;
  final GetActivityRecords getAll;
  final UpdateActivityRecord update;
  final DeleteActivityRecord delete;

  ActivityHistoryBloc({
    required this.create,
    required this.getAll,
    required this.update,
    required this.delete,
  }) : super(ActivityHistoryInitial()) {
    on<LoadActivityHistory>(_onLoad);
    on<CreateActivityHistory>(_onCreate);
    on<UpdateActivityHistory>(_onUpdate);
    on<DeleteActivityHistory>(_onDelete);
  }

  Future<void> _onLoad(
    LoadActivityHistory event,
    Emitter<ActivityHistoryState> emit,
  ) async {
    emit(ActivityHistoryLoading());
    try {
      final records = await getAll();
      emit(ActivityHistoryLoaded(records));
    } catch (e) {
      emit(ActivityHistoryError(e.toString()));
    }
  }

  Future<void> _onCreate(
    CreateActivityHistory event,
    Emitter<ActivityHistoryState> emit,
  ) async {
    try {
      await create(event.record);
      final records = await getAll();
      emit(ActivityHistoryLoaded(records));
    } catch (e) {
      emit(ActivityHistoryError(e.toString()));
    }
  }

  Future<void> _onUpdate(
    UpdateActivityHistory event,
    Emitter<ActivityHistoryState> emit,
  ) async {
    try {
      await update(event.record);
      final records = await getAll();
      emit(ActivityHistoryLoaded(records));
    } catch (e) {
      emit(ActivityHistoryError(e.toString()));
    }
  }

  Future<void> _onDelete(
    DeleteActivityHistory event,
    Emitter<ActivityHistoryState> emit,
  ) async {
    try {
      await delete(event.id);
      final records = await getAll();
      emit(ActivityHistoryLoaded(records));
    } catch (e) {
      emit(ActivityHistoryError(e.toString()));
    }
  }
}
