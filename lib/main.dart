import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'features/auth/data/datasources/biometric_datasource.dart';
import 'features/auth/domain/usecases/authenticate_user.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/steps/presentation/widgets/step_counter_widget.dart';
import 'features/tracking/presentation/widgets/route_map_widget.dart';

// Imports para la detección de actividad y caídas
import 'features/activity_detection/data/datasources/motion_sensor_datasource.dart';
import 'features/activity_detection/data/datasources/voice_announcer.dart';
import 'features/activity_detection/presentation/cubit/activity_detection_cubit.dart';
import 'features/activity_detection/presentation/widgets/activity_status_widget.dart';
import 'features/activity_detection/presentation/widgets/fall_confirmation_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FitnessApp());
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    final biometricDataSource = BiometricDataSourceImpl();
    final authenticateUser = AuthenticateUser(biometricDataSource);

    return MaterialApp(
      title: 'Fitness Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (_) => AuthBloc(authenticateUser),
        child: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isAuthenticated = false;

  void _onAuthSuccess() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) {
      return const HomePage();
    }
    return LoginPage(onAuthSuccess: _onAuthSuccess);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ActivityDetectionCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = ActivityDetectionCubit(
      dataSource: MotionSensorDataSourceImpl(),
      announcer: VoiceAnnouncerImpl(),
    );
    _requestPermissionAndStart();
  }

  Future<void> _requestPermissionAndStart() async {
    final status = await Permission.activityRecognition.request();
    if (status.isGranted) {
      _cubit.start();
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fitness Tracker'),
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: BlocListener<ActivityDetectionCubit, ActivityDetectionState>(
          listenWhen: (prev, curr) => prev.isFallSuspected != curr.isFallSuspected,
          listener: (context, state) {
            if (state.isFallSuspected) {
              FallConfirmationDialog.show(
                context,
                () => context.read<ActivityDetectionCubit>().resolveFallSuspicion(),
              );
            }
          },
          child: const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                ActivityStatusWidget(),
                SizedBox(height: 16),
                StepCounterWidget(),
                SizedBox(height: 16),
                RouteMapWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
