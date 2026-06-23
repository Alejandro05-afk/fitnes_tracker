import 'package:get_it/get_it.dart';
import '../../features/auth/data/datasources/biometric_datasource.dart';
import '../../features/auth/data/datasources/accelerometer_datasource.dart';
import '../../features/auth/domain/usecases/authenticate_user.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/tracking/data/datasources/gps_datasource.dart';
import '../../features/activity_detection/data/datasources/motion_sensor_datasource.dart';
import '../../features/activity_detection/data/datasources/voice_announcer.dart';
import '../../features/activity_history/data/datasources/activity_history_local_datasource.dart';
import '../../features/activity_history/data/repositories/activity_history_repository_impl.dart';
import '../../features/activity_history/domain/repositories/activity_history_repository.dart';
import '../../features/activity_history/domain/usecases/create_activity_record.dart';
import '../../features/activity_history/domain/usecases/get_activity_records.dart';
import '../../features/activity_history/domain/usecases/update_activity_record.dart';
import '../../features/activity_history/domain/usecases/delete_activity_record.dart';
import '../../features/activity_history/presentation/bloc/activity_history_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  sl.registerLazySingleton<BiometricDataSource>(() => BiometricDataSourceImpl());
  sl.registerLazySingleton<AccelerometerDataSource>(() => AccelerometerDataSourceImpl());
  sl.registerFactory(() => AuthenticateUser(sl()));
  sl.registerFactory(() => AuthBloc(sl()));

  sl.registerLazySingleton<GpsDataSource>(() => GpsDataSourceImpl());

  sl.registerLazySingleton<MotionSensorDataSource>(() => MotionSensorDataSourceImpl());
  sl.registerLazySingleton<VoiceAnnouncer>(() => VoiceAnnouncerImpl());

  final db = await ActivityHistoryLocalDatasource.create();
  sl.registerLazySingleton<ActivityHistoryLocalDatasource>(() => db);
  sl.registerLazySingleton<ActivityHistoryRepository>(
    () => ActivityHistoryRepositoryImpl(sl()),
  );
  sl.registerFactory(() => CreateActivityRecord(sl()));
  sl.registerFactory(() => GetActivityRecords(sl()));
  sl.registerFactory(() => UpdateActivityRecord(sl()));
  sl.registerFactory(() => DeleteActivityRecord(sl()));
  sl.registerFactory(
    () => ActivityHistoryBloc(
      create: sl(),
      getAll: sl(),
      update: sl(),
      delete: sl(),
    ),
  );
}
