---
name: fitness-tracker-plugin-crud
description: >
  Skill para el proyecto Flutter `fitness_tracker` con Clean Architecture + Vertical Slicing +
  flutter_bloc + get_it. Úsala SIEMPRE que el usuario pida:
  - Migrar Platform Channels a plugins (local_auth, geolocator, sensors_plus)
  - Eliminar código nativo de MainActivity.kt / AppDelegate.swift
  - Añadir o mejorar el CRUD del historial de actividad física
  - Registrar datasources, repositorios o BLoCs en get_it para las features auth, tracking,
    activity_detection o activity_history
  - Agregar persistencia local (sqlite, sqflite, hive, shared_preferences) al registro histórico
  - Cualquier modificación en biometric_datasource.dart, gps_datasource.dart,
    accelerometer_datasource.dart, motion_sensor_datasource.dart o injection_container.dart
---

# Fitness Tracker — Plugin Migration + Activity History CRUD

## 0. Arquitectura del proyecto

```
lib/
├── core/
│   ├── di/              ← injection_container.dart  (get_it)
│   └── platform/        ← platform_channels.dart  (ELIMINAR tras migración)
└── features/
    ├── auth/            ← Biometría
    ├── steps/           ← Contador de pasos (usa AccelerometerDataSource)
    ├── tracking/        ← GPS / ruta
    ├── activity_detection/ ← sensors_plus ya implementado
    └── activity_history/   ← NUEVO: CRUD historial  (ver §4)
```

**Regla de vertical slice**: cada feature es autónoma; sólo `core/di/` puede referenciar
múltiples features. Nunca importes entre features directamente.

---

## 1. Migración de Platform Channels → Plugins

### 1.1 Dependencias a añadir en `pubspec.yaml`

```yaml
dependencies:
  local_auth: ^2.3.0          # reemplaza canal biométrico
  geolocator: ^13.0.2         # reemplaza canal GPS
  sensors_plus: ^6.1.0        # ya presente — mantener
  sqflite: ^2.4.1             # para activity_history CRUD
  path: ^1.9.1                # helper de sqflite
  # Mantener:
  flutter_tts: ^4.2.5
  flutter_bloc: ^8.1.6
  equatable: ^2.0.8
  get_it: ^7.7.0
  permission_handler: ^11.4.0
```

**IMPORTANTE iOS — local_auth**: en `ios/Runner/Info.plist` añadir:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Autenticación biométrica para Fitness Tracker</string>
```

**IMPORTANTE Android — local_auth**: `MainActivity` debe heredar de
`FlutterFragmentActivity` (ya lo hace); verificar que el `build.gradle.kts` tenga:
```kotlin
implementation("androidx.biometric:biometric:1.1.0")
```

**IMPORTANTE Android — geolocator**: en `AndroidManifest.xml` (main) asegurarse de tener:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

---

### 1.2 Feature `auth` — Biometría con `local_auth`

**Archivo a reemplazar**: `lib/features/auth/data/datasources/biometric_datasource.dart`

```dart
import 'package:local_auth/local_auth.dart';
import '../../domain/entities/auth_result.dart';

abstract class BiometricDataSource {
  Future<bool> canAuthenticate();
  Future<AuthResult> authenticate();
}

class BiometricDataSourceImpl implements BiometricDataSource {
  BiometricDataSourceImpl() : _auth = LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> canAuthenticate() async {
    try {
      final isAvailable = await _auth.isDeviceSupported();
      if (!isAvailable) return false;
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AuthResult> authenticate() async {
    try {
      final didAuth = await _auth.authenticate(
        localizedReason: 'Usa tu huella o Face ID para acceder',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return AuthResult(
        success: didAuth,
        message: didAuth ? 'Autenticación exitosa' : 'Autenticación cancelada',
      );
    } catch (e) {
      return AuthResult(success: false, message: 'Error: $e');
    }
  }
}
```

**Archivo a eliminar** (ya no es necesario): `lib/core/platform/platform_channels.dart`  
**Limpiar en `auth/data/datasources/accelerometer_datasource.dart`**: quitar el
import de `platform_channels.dart` (ver §1.3).

---

### 1.3 Feature `auth` — Acelerómetro con `sensors_plus` (ya migrado en activity_detection)

`AccelerometerDataSourceImpl` en `lib/features/auth/data/datasources/accelerometer_datasource.dart`
todavía usa EventChannel. Reemplazarlo:

```dart
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/step_data.dart';

abstract class AccelerometerDataSource {
  Stream<StepData> get stepStream;
  Future<void> startCounting();
  Future<void> stopCounting();
  Future<bool> requestPermissions();
}

class AccelerometerDataSourceImpl implements AccelerometerDataSource {
  StreamSubscription<AccelerometerEvent>? _sub;
  final StreamController<StepData> _controller =
      StreamController<StepData>.broadcast();

  int _stepCount = 0;
  double _lastMagnitude = 0;
  final List<double> _history = [];
  static const int _historySize = 10;

  @override
  Stream<StepData> get stepStream => _controller.stream;

  @override
  Future<void> startCounting() async {
    _stepCount = 0;
    _sub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onEvent, cancelOnError: false);
  }

  void _onEvent(AccelerometerEvent e) {
    final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);

    _history.add(mag);
    if (_history.length > _historySize) _history.removeAt(0);
    final avg = _history.reduce((a, b) => a + b) / _history.length;

    if (mag > 12 && _lastMagnitude <= 12) _stepCount++;
    _lastMagnitude = mag;

    final type = avg < 10.5
        ? ActivityType.stationary
        : avg < 13.5
            ? ActivityType.walking
            : ActivityType.running;

    _controller.add(StepData(
      stepCount: _stepCount,
      activityType: type,
      magnitude: avg,
    ));
  }

  @override
  Future<void> stopCounting() async {
    await _sub?.cancel();
    _sub = null;
  }

  @override
  Future<bool> requestPermissions() async {
    final status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
```

---

### 1.4 Feature `tracking` — GPS con `geolocator`

**Archivo a reemplazar**: `lib/features/tracking/data/datasources/gps_datasource.dart`

```dart
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/location_point.dart';

abstract class GpsDataSource {
  Future<LocationPoint?> getCurrentLocation();
  Stream<LocationPoint> get locationStream;
  Future<bool> isGpsEnabled();
  Future<bool> requestPermissions();
}

class GpsDataSourceImpl implements GpsDataSource {
  static const _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 2, // metros — igual que el filtro ya existente en RouteMapWidget
  );

  @override
  Future<bool> requestPermissions() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Future<bool> isGpsEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPoint?> getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return _fromPosition(pos);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<LocationPoint> get locationStream =>
      Geolocator.getPositionStream(locationSettings: _locationSettings)
          .map(_fromPosition);

  LocationPoint _fromPosition(Position pos) => LocationPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
        altitude: pos.altitude,
        speed: pos.speed,
        accuracy: pos.accuracy,
        timestamp: pos.timestamp,
      );
}
```

**`LocationPoint.fromMap` ya no es necesario** para GPS (geolocator entrega objetos
`Position`, no Maps). Conservar `fromMap` si otros datasources aún lo usan; de lo
contrario se puede deprecar.

---

### 1.5 Limpiar `MainActivity.kt`

Tras la migración, `MainActivity.kt` sólo necesita:

```kotlin
package com.tuinstituto.fitness_tracker

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

Eliminar todos los bloques `MethodChannel`, `EventChannel`, `BiometricPrompt`,
`SensorManager`, `LocationManager` y sus imports.

---

### 1.6 Eliminar `core/platform/platform_channels.dart`

Una vez migrados los tres datasources, borrar el archivo y quitar cualquier import
residual de `platform_channels.dart` en el proyecto.

---

## 2. Inyección de dependencias (`core/di/injection_container.dart`)

Crear (o actualizar) el archivo de inyección centralizado:

```dart
import 'package:get_it/get_it.dart';
import '../features/auth/data/datasources/biometric_datasource.dart';
import '../features/auth/data/datasources/accelerometer_datasource.dart';
import '../features/auth/domain/usecases/authenticate_user.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/tracking/data/datasources/gps_datasource.dart';
import '../features/activity_detection/data/datasources/motion_sensor_datasource.dart';
import '../features/activity_detection/data/datasources/voice_announcer.dart';
import '../features/activity_history/data/datasources/activity_history_local_datasource.dart';
import '../features/activity_history/data/repositories/activity_history_repository_impl.dart';
import '../features/activity_history/domain/repositories/activity_history_repository.dart';
import '../features/activity_history/domain/usecases/create_activity_record.dart';
import '../features/activity_history/domain/usecases/get_activity_records.dart';
import '../features/activity_history/domain/usecases/update_activity_record.dart';
import '../features/activity_history/domain/usecases/delete_activity_record.dart';
import '../features/activity_history/presentation/bloc/activity_history_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ── Auth ──────────────────────────────────────────────────────────────
  sl.registerLazySingleton<BiometricDataSource>(() => BiometricDataSourceImpl());
  sl.registerLazySingleton<AccelerometerDataSource>(() => AccelerometerDataSourceImpl());
  sl.registerFactory(() => AuthenticateUser(sl()));
  sl.registerFactory(() => AuthBloc(sl()));

  // ── Tracking ──────────────────────────────────────────────────────────
  sl.registerLazySingleton<GpsDataSource>(() => GpsDataSourceImpl());

  // ── Activity Detection ────────────────────────────────────────────────
  sl.registerLazySingleton<MotionSensorDataSource>(() => MotionSensorDataSourceImpl());
  sl.registerLazySingleton<VoiceAnnouncer>(() => VoiceAnnouncerImpl());

  // ── Activity History (CRUD) ───────────────────────────────────────────
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
```

Llamar `await initDependencies()` en `main()` antes de `runApp(...)`.

---

## 3. Árbol de archivos completo post-migración

```
lib/
├── core/
│   └── di/
│       └── injection_container.dart          ← NUEVO
├── features/
│   ├── auth/
│   │   ├── data/datasources/
│   │   │   ├── biometric_datasource.dart     ← REEMPLAZAR (local_auth)
│   │   │   └── accelerometer_datasource.dart ← REEMPLAZAR (sensors_plus)
│   │   ├── domain/…                          ← sin cambios
│   │   └── presentation/…                   ← sin cambios
│   ├── steps/…                               ← sin cambios
│   ├── tracking/
│   │   ├── data/datasources/
│   │   │   └── gps_datasource.dart           ← REEMPLAZAR (geolocator)
│   │   ├── domain/…                          ← sin cambios
│   │   └── presentation/…                   ← sin cambios
│   ├── activity_detection/…                  ← sin cambios (ya usa sensors_plus)
│   └── activity_history/                     ← NUEVA feature (§4)
│       ├── data/
│       │   ├── datasources/
│       │   │   └── activity_history_local_datasource.dart
│       │   ├── models/
│       │   │   └── activity_record_model.dart
│       │   └── repositories/
│       │       └── activity_history_repository_impl.dart
│       ├── domain/
│       │   ├── entities/
│       │   │   └── activity_record.dart
│       │   ├── repositories/
│       │   │   └── activity_history_repository.dart
│       │   └── usecases/
│       │       ├── create_activity_record.dart
│       │       ├── get_activity_records.dart
│       │       ├── update_activity_record.dart
│       │       └── delete_activity_record.dart
│       └── presentation/
│           ├── bloc/
│           │   └── activity_history_bloc.dart
│           └── pages/
│               └── activity_history_page.dart
```

---

## 4. Feature `activity_history` — CRUD historial de actividad

> Leer `references/activity-history-crud.md` para todos los archivos de código de esta feature.

Resumen de responsabilidades por capa:

| Capa | Qué hace |
|------|----------|
| **Domain / entity** | `ActivityRecord` — inmutable, Equatable |
| **Domain / repository** | `ActivityHistoryRepository` — contrato CRUD |
| **Domain / usecases** | `CreateActivityRecord`, `GetActivityRecords`, `UpdateActivityRecord`, `DeleteActivityRecord` |
| **Data / model** | `ActivityRecordModel` — extiende `ActivityRecord`; `toMap/fromMap` para sqflite |
| **Data / datasource** | `ActivityHistoryLocalDatasource` — abre/migra la DB, ejecuta SQL |
| **Data / repository** | `ActivityHistoryRepositoryImpl` — delega al datasource |
| **Presentation / bloc** | `ActivityHistoryBloc` — eventos CRUD → estados |
| **Presentation / page** | `ActivityHistoryPage` — lista + FAB crear + swipe eliminar + edición |

---

## 5. Guía de errores frecuentes

| Error | Causa probable | Solución |
|-------|---------------|----------|
| `MissingPluginException` biometric | `MainActivity` no es `FlutterFragmentActivity` | Verificar herencia |
| `PermanentlyDeniedError` location | Permisos revocados por el usuario | Abrir `openAppSettings()` de `permission_handler` |
| `LocationServiceDisabledException` | GPS apagado | Llamar `Geolocator.openLocationSettings()` |
| Sensores dan cero en emulador | El emulador no tiene acelerómetro real | Probar en dispositivo físico o usar Extended Controls |
| `DatabaseException` al abrir sqflite | Migración de schema incompleta | Incrementar `version` y añadir `onUpgrade` en datasource |
| Bloc no se registra en get_it | `registerFactory` vs `registerLazySingleton` | Blocs → `registerFactory`; datasources → `registerLazySingleton` |

---

## 6. Checklist de implementación

- [ ] Añadir dependencias en `pubspec.yaml` y ejecutar `flutter pub get`
- [ ] Configurar permisos en `AndroidManifest.xml` e `Info.plist`
- [ ] Limpiar `MainActivity.kt` (quitar Platform Channels)
- [ ] Reemplazar `biometric_datasource.dart` → `local_auth`
- [ ] Reemplazar `accelerometer_datasource.dart` → `sensors_plus`
- [ ] Reemplazar `gps_datasource.dart` → `geolocator`
- [ ] Eliminar `lib/core/platform/platform_channels.dart`
- [ ] Crear `lib/core/di/injection_container.dart`
- [ ] Actualizar `main.dart` para llamar `initDependencies()`
- [ ] Crear la feature `activity_history` completa (ver `references/`)
- [ ] Añadir ruta/botón a `activity_history_page.dart` desde `HomePage`
- [ ] Verificar que `flutter analyze` no reporta errores
- [ ] Probar en dispositivo físico (biometría + GPS + sensores)