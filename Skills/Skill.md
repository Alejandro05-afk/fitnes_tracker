---
name: fall-activity-voice-detector
description: >
  Implementa el "Mega Reto: Detector de actividad física con aviso por voz" sobre el proyecto
  Flutter fitness_tracker (Clean Architecture + Vertical Slicing). Cubre detección continua de
  caminar/correr/quieto y de caídas usando sensors_plus (acelerómetro crudo), avisos por voz con
  flutter_tts, debounce de estado estable, diálogo de confirmación de caída con reintento a los
  15s, permisos en runtime y AndroidManifest. Usa esta skill siempre que el usuario mencione
  "detector de actividad", "detección de caídas", "fall detection", "aviso por voz", "flutter_tts",
  "sensors_plus", "activity_recognition_flutter", "debounce de sensores", o pida ampliar
  fitness_tracker con reconocimiento de actividad/caídas. NO modifica la lógica de Platform
  Channels ya existente (biometría, contador de pasos, GPS) — se integra en paralelo como feature
  nueva.
---

# Mega Reto — Detector de actividad física con aviso por voz

Implementación completa para el proyecto `fitness_tracker` (Flutter, Clean Architecture +
Vertical Slicing, `flutter_bloc`, `get_it`, `permission_handler`). Esta skill asume el código
base ya documentado en memoria: Platform Channels para biometría (`auth`), pasos (`steps` /
`auth/accelerometer_datasource.dart`) y GPS (`tracking`), todos intactos.

**Regla de oro: no se toca nada de lo anterior.** Esta feature es 100% nueva, vive en su propio
slice y abre su propio stream de sensores independiente del `EventChannel` nativo que ya usa
`AccelerometerDataSourceImpl`. No hay colisión porque `sensors_plus` lee el sensor Android
directamente desde Flutter (plugin), sin pasar por `MainActivity.kt`.

---

## 0. Decisiones técnicas y su justificación (para la entrega académica)

Esto es lo que el estudiante debe poder explicar/defender. Inclúyelo en el README o informe.

### 0.1 — sensors_plus vs activity_recognition_flutter → se elige **sensors_plus** (único plugin)

| Criterio | `sensors_plus` | `activity_recognition_flutter` |
|---|---|---|
| Qué devuelve | Datos crudos del acelerómetro (x, y, z) en cada evento. Hay que procesar magnitud, suavizado y clasificación nosotros mismos. | Actividad ya clasificada (`WALKING`, `RUNNING`, `STILL`, etc.) vía la Activity Recognition Transition API de Android. |
| Soporte Android | Directo sobre `SensorManager`, estable, sin servicios nativos adicionales. | Requiere declarar `BroadcastReceiver` + 2 `Service` en el manifest, corre como tarea de Google Play Services, pensado para tracking en background. |
| Latencia | Inmediata (cada `SensorEvent`). | Asíncrona, de grano grueso — puede tardar varios segundos en confirmar un cambio de transición. |
| Permisos | Solo `ACTIVITY_RECOGNITION` en Android 10+ (ya declarado en el proyecto). | Mismo permiso + Google Play Services. |
| Detección de caídas | Es la **única** vía posible: una caída no es una "actividad" reconocida por la API, se detecta con la magnitud del vector crudo. | No la soporta en absoluto. |
| Encaje con el alcance del taller | Un solo stream, un solo plugin, control total del umbral/debounce que el reto exige justificar como propios. | Forzaría dos plugins corriendo en paralelo (uno para actividad, otro —sensors_plus— solo para caída), duplicando consumo de batería y permisos sin necesidad real. |

**Conclusión:** como la detección de caídas obliga a usar `sensors_plus` sí o sí, usar
`activity_recognition_flutter` además solo para caminar/correr añade un segundo plugin, un
segundo modelo de permisos y una API pensada para background tracking de larga duración —
sobredimensionada para una pantalla que muestra el estado mientras la app está abierta. Con
`sensors_plus` se obtiene un único stream de aceleración del que se derivan **ambas** señales
(actividad y caída) con el mismo umbral de magnitud, lo cual además es justo el ejercicio que
pide la sección 2.2 del enunciado.

### 0.2 — Umbral de detección de actividad (caminar/correr/quieto)

Se usa la magnitud del vector de aceleración **incluyendo gravedad** (`AccelerometerEvent`, no
`UserAccelerometerEvent`), porque así un dispositivo en reposo da una magnitud constante de
~9.8 m/s² (la gravedad) y cualquier desviación sobre ese valor base es movimiento real:

```
magnitude = sqrt(x² + y² + z²)
```

Sobre una ventana móvil de muestras (suavizado, ver 0.4) se clasifica:

| Rango de magnitud promedio | Estado |
|---|---|
| < 10.5 m/s² | Quieto (`stationary`) |
| 10.5 – 13.5 m/s² | Caminando (`walking`) |
| > 13.5 m/s² | Corriendo (`running`) |

Estos cortes replican los ya validados en `MainActivity.kt` del propio proyecto (líneas de
`setupAccelerometerChannel`), por lo que son consistentes con el comportamiento que el dispositivo
del estudiante ya demostró tener calibrado correctamente. Se documentan así porque: en reposo
total la gravedad sola mide ~9.8, el ruido normal de sostener el teléfono en la mano sube esa
lectura unos 0.7–3.7 m/s² adicionales (caminar), y una zancada de carrera produce picos que
superan los 13.5 m/s² de forma sostenida.

### 0.3 — Umbral de detección de caída

Una caída libre seguida de un impacto produce un patrón característico de dos fases:

1. **Caída libre**: la magnitud cae cerca de **0 m/s²** durante unos cientos de milisegundos
   (el sensor deja de "sentir" la gravedad porque todo el dispositivo está en caída libre).
2. **Impacto**: pico brusco de magnitud muy por encima de lo normal, típicamente **> 25 m/s²**
   en una caída real contra el suelo.

Se usa **25 m/s²** como umbral de impacto porque:
- Caminar/correr normal (incluso saltos al trotar) rara vez supera 20 m/s² de pico instantáneo.
- Literatura de fall-detection con acelerómetro de smartphone (ej. estudios de umbral SVM —
  Sum Vector Magnitude) sitúa el rango de impacto de caída real entre 2.5g y 3g (≈24.5–29.4 m/s²).
- Un umbral más bajo (ej. 15-18 m/s²) dispara falsos positivos con golpes del teléfono contra
  una mesa o un salto fuerte.

### 0.4 — Reducción de falsos positivos (caída)

Un solo pico de magnitud > 25 no es suficiente evidencia: dejar el teléfono caer sobre un sofá,
un golpe al meterlo en el bolsillo, etc. también generan picos puntuales. Se exige un **patrón
de 2 condiciones en secuencia, dentro de una ventana de 1.5 segundos**:

1. Fase de pre-impacto: magnitud cae por debajo de 3 m/s² (caída libre / momento sin apoyo).
2. Fase de impacto: dentro de los siguientes 1.5s, magnitud supera 25 m/s².

Solo si ambas fases ocurren en ese orden y ventana se considera "posible caída". Esto descarta
la mayoría de golpes secos aislados (que no tienen fase de caída libre previa) sin necesitar
machine learning, manteniendo el alcance apropiado para el taller.

### 0.5 — Síntesis de voz: flutter_tts

Se elige `flutter_tts` (no alternativas como `just_audio` con audios pregrabados) porque:
- Usa el motor TTS nativo del sistema (Android `TextToSpeech` / iOS `AVSpeechSynthesizer`), por
  lo que **respeta automáticamente el idioma configurado en el dispositivo** sin necesidad de
  grabar y empaquetar archivos de audio por idioma.
- Funciona offline una vez instalado el paquete de voz del sistema.
- Es el plugin estándar de facto en el ecosistema Flutter para este caso de uso (mantenido,
  >150 puntos de pub, soporte Android/iOS/macOS/Web/Windows).
- Permite forzar español como mínimo (`setLanguage("es-ES")`) si el idioma del sistema no tiene
  voz instalada, cumpliendo el requisito "en el idioma del sistema, o en español como mínimo".

### 0.6 — Debounce del stream de sensores

Conectar el aviso de voz directamente al stream de clasificación dispararía un anuncio cada vez
que la magnitud cruza un umbral por ruido normal (varias veces por segundo). Un **debounce en el
contexto de streams** significa: no reaccionar a cada evento, sino esperar a que el valor se
mantenga **estable durante una ventana de tiempo fija** antes de considerarlo un cambio real;
si llega un nuevo valor distinto antes de que termine la ventana, el temporizador se reinicia.

Se usa una ventana de **3 segundos** para anunciar cambio de actividad (caminar/correr/quieto):
- Es lo bastante corta para que el aviso se sienta "en tiempo real".
- Es lo bastante larga para filtrar transiciones momentáneas (ej. pisar mal un escalón, tropezar
  sin caer) que no representan un cambio sostenido de actividad.

El debounce se implementa **sin** el operador `debounce` de RxDart (el proyecto no usa RxDart),
con un `Timer` manual cancelable dentro del Bloc/Cubit — ver paso 3.

---

## 1. Dependencias nuevas (`pubspec.yaml`)

El proyecto actualmente **no tiene** `sensors_plus` ni `flutter_tts`. Agregar:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5
  get_it: ^7.6.4
  permission_handler: ^11.0.1

  # NUEVO — Mega Reto detección de actividad y caídas
  sensors_plus: ^7.0.0
  flutter_tts: ^4.2.5
```

Requisitos de entorno de `sensors_plus: ^7.0.0` (verificar que el proyecto cumpla):
- Flutter >=3.19.0, Dart >=3.3.0 — el proyecto declara `sdk: '>=3.0.0 <4.0.0'`, compatible.
- Java 17 — ya configurado en `android/app/build.gradle.kts` (`sourceCompatibility = VERSION_17`).
- Android Gradle Plugin >=8.12.1 y Kotlin reciente — revisar `android/settings.gradle.kts` si el
  build falla por versión de AGP/Kotlin; si es necesario, subir la versión del plugin
  `com.android.application` y `kotlin-android` ahí.

Instalar:

```powershell
flutter pub get
```

---

## 2. Permisos

### 2.1 AndroidManifest.xml

El manifest principal (`android/app/src/main/AndroidManifest.xml`) **ya tiene** declarados:

```xml
<uses-permission android:name="android.permission.BODY_SENSORS"/>
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
```

Para esta feature **no se necesita `BODY_SENSORS`** (ese permiso es para sensores biométricos
como ritmo cardíaco; el acelerómetro crudo no lo requiere). El permiso relevante para
`accelerometerEvents` de `sensors_plus` en Android 10+ es **`ACTIVITY_RECOGNITION`**, que el
proyecto ya declara — no hay que tocar el manifest para el permiso en sí.

Sí hay que agregar el `<queries>` requerido por `flutter_tts` en apps que apuntan a Android 11+
(`targetSdk` 30+), para que el sistema permita resolver el servicio de TTS instalado:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
    <uses-permission android:name="android.permission.BODY_SENSORS"/>
    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>

    <application
        android:label="Fitness Tracker"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <!-- ... activity existente sin cambios ... -->
    </application>

    <!-- NUEVO — requerido por flutter_tts en Android 11+ -->
    <queries>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE" />
        </intent>
    </queries>

</manifest>
```

`<queries>` va como hijo directo de `<manifest>`, al mismo nivel que `<application>` (no dentro
de ella). Si se omite, en Android 11+ el motor TTS puede no resolverse y `flutter_tts` falla
silenciosamente al hablar.

### 2.2 Solicitud en runtime

`permission_handler: ^11.0.1` ya está en el proyecto. La nueva feature solicita el permiso de
actividad física **antes** de suscribirse al stream del acelerómetro — si se omite este paso,
el stream de `sensors_plus` simplemente no emite eventos (no lanza excepción visible), exactamente
la advertencia del enunciado:

```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestActivityPermission() async {
  final status = await Permission.activityRecognition.request();
  return status.isGranted;
}
```

No se solicita `Permission.sensors` (mapea a `BODY_SENSORS`) porque no aplica al acelerómetro
crudo y pedirlo de más solo genera fricción innecesaria con el usuario.

---

## 3. Estructura del nuevo feature (Clean Architecture + Vertical Slicing)

Se crea un feature independiente, paralelo a `auth`, `steps` y `tracking`, sin tocar ninguno
de ellos:

```
lib/features/activity_detection/
├── data/
│   └── datasources/
│       ├── motion_sensor_datasource.dart      # Wrapper de sensors_plus (actividad + caída)
│       └── voice_announcer.dart               # Wrapper de flutter_tts
├── domain/
│   ├── entities/
│   │   ├── motion_state.dart                  # enum walking/running/stationary
│   │   └── fall_event.dart                    # evento de caída detectada
│   └── usecases/
│       └── classify_motion.dart               # magnitud -> MotionState (pura, testeable)
└── presentation/
    ├── cubit/
    │   └── activity_detection_cubit.dart       # orquesta stream + debounce + TTS + fall flag
    └── widgets/
        ├── activity_status_widget.dart         # tarjeta de estado (estilo StepCounterWidget)
        └── fall_confirmation_dialog.dart        # diálogo "¿Estás bien?" con reintento a 15s
```

Se usa **Cubit** en vez de Bloc completo porque no hay eventos complejos que justifiquen
`Event` classes — es el mismo criterio que ya usa el proyecto de mantener las cosas simples
(`AuthBloc` sí usa eventos porque tiene un flujo de autenticación más rico; aquí el "evento" es
literalmente "llegó una nueva lectura del sensor", que se modela mejor como llamada directa de
método). Si prefieres un `Bloc` con clases de evento explícitas para mantener el mismo patrón
que `AuthBloc` en toda la app, pide la variante y se reescribe la sección 7 con eventos
(`MotionDetected`, `FallDetected`, `FallSuspicionResolved`) sin cambiar el resto del diseño.

---

## 4. Domain layer

### 4.1 `lib/features/activity_detection/domain/entities/motion_state.dart`

```dart
import 'package:equatable/equatable.dart';

/// Estados de actividad física detectados a partir del acelerómetro.
enum MotionType { stationary, walking, running }

class MotionState extends Equatable {
  final MotionType type;
  final double magnitude;
  final DateTime timestamp;

  const MotionState({
    required this.type,
    required this.magnitude,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [type, magnitude, timestamp];
}
```

### 4.2 `lib/features/activity_detection/domain/entities/fall_event.dart`

```dart
import 'package:equatable/equatable.dart';

/// Representa una posible caída detectada por el patrón
/// caída-libre -> impacto en la ventana de tiempo definida.
class FallEvent extends Equatable {
  final double impactMagnitude;
  final DateTime timestamp;

  const FallEvent({
    required this.impactMagnitude,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [impactMagnitude, timestamp];
}
```

### 4.3 `lib/features/activity_detection/domain/usecases/classify_motion.dart`

Lógica pura (sin dependencias de Flutter ni de sensors_plus) para poder testearla con
`flutter test` sin mocks de sensores:

```dart
import '../entities/motion_state.dart';

/// Umbrales justificados en SKILL.md sección 0.2.
/// Se replican los mismos cortes ya validados en el Platform Channel
/// nativo de pasos (MainActivity.kt) para mantener consistencia de
/// comportamiento percibido por el usuario.
class ClassifyMotion {
  static const double stationaryUpperBound = 10.5;
  static const double walkingUpperBound = 13.5;

  MotionType call(double averageMagnitude) {
    if (averageMagnitude < stationaryUpperBound) return MotionType.stationary;
    if (averageMagnitude < walkingUpperBound) return MotionType.walking;
    return MotionType.running;
  }
}
```

---

## 5. Data layer — `motion_sensor_datasource.dart`

Encapsula `sensors_plus` (lectura cruda), el cálculo de magnitud, el suavizado por ventana móvil
y la detección del patrón de caída en dos fases. Expone dos streams separados: uno de
`MotionState` (ya clasificado, sin debounce — el debounce vive en el Cubit) y uno de `FallEvent`.

```dart
import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

import '../../domain/entities/fall_event.dart';
import '../../domain/entities/motion_state.dart';
import '../../domain/usecases/classify_motion.dart';

abstract class MotionSensorDataSource {
  Stream<MotionState> get motionStream;
  Stream<FallEvent> get fallStream;
  void start();
  void dispose();
}

class MotionSensorDataSourceImpl implements MotionSensorDataSource {
  MotionSensorDataSourceImpl({ClassifyMotion? classifier})
      : _classifier = classifier ?? ClassifyMotion();

  final ClassifyMotion _classifier;

  // Suavizado por promedio móvil (ver SKILL.md 0.2).
  static const int _windowSize = 10;
  final Queue<double> _magnitudeWindow = Queue<double>();

  // Umbrales de caída (ver SKILL.md 0.3 y 0.4).
  static const double _freeFallThreshold = 3.0;
  static const double _impactThreshold = 25.0;
  static const Duration _fallWindow = Duration(milliseconds: 1500);

  DateTime? _freeFallDetectedAt;
  StreamSubscription<AccelerometerEvent>? _subscription;

  final StreamController<MotionState> _motionController =
      StreamController<MotionState>.broadcast();
  final StreamController<FallEvent> _fallController =
      StreamController<FallEvent>.broadcast();

  @override
  Stream<MotionState> get motionStream => _motionController.stream;

  @override
  Stream<FallEvent> get fallStream => _fallController.stream;

  @override
  void start() {
    _subscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval, // ~20ms, igual a SENSOR_DELAY_GAME nativo
    ).listen(_onEvent, onError: (Object error) {
      // Sensor no disponible en el dispositivo: no se relanza, se ignora
      // para no tumbar la app (mismo criterio que el resto del proyecto).
    }, cancelOnError: false);
  }

  void _onEvent(AccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    _checkFallPattern(magnitude);
    _emitMotionState(magnitude);
  }

  void _emitMotionState(double magnitude) {
    _magnitudeWindow.addLast(magnitude);
    if (_magnitudeWindow.length > _windowSize) {
      _magnitudeWindow.removeFirst();
    }

    final avg = _magnitudeWindow.reduce((a, b) => a + b) / _magnitudeWindow.length;
    final type = _classifier(avg);

    _motionController.add(MotionState(
      type: type,
      magnitude: avg,
      timestamp: DateTime.now(),
    ));
  }

  void _checkFallPattern(double rawMagnitude) {
    final now = DateTime.now();

    // Fase 1: caída libre — magnitud cae casi a cero.
    if (rawMagnitude < _freeFallThreshold) {
      _freeFallDetectedAt = now;
      return;
    }

    // Fase 2: impacto dentro de la ventana posterior a la caída libre.
    if (_freeFallDetectedAt != null &&
        rawMagnitude > _impactThreshold &&
        now.difference(_freeFallDetectedAt!) <= _fallWindow) {
      _fallController.add(FallEvent(
        impactMagnitude: rawMagnitude,
        timestamp: now,
      ));
      _freeFallDetectedAt = null; // evita disparar múltiples veces por el mismo impacto
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _motionController.close();
    _fallController.close();
  }
}
```

**Por qué `accelerometerEventStream` (no `accelerometerEvents` plano):** desde `sensors_plus` 4.x
la API recomendada permite pasar `samplingPeriod`. Se usa `SensorInterval.gameInterval` para
replicar la frecuencia `SENSOR_DELAY_GAME` que ya usaba el Platform Channel nativo del proyecto,
manteniendo coherencia de comportamiento entre ambas features.

---

## 6. Voz — wrapper de `flutter_tts`

`lib/features/activity_detection/data/datasources/voice_announcer.dart`

```dart
import 'package:flutter_tts/flutter_tts.dart';

/// Encapsula flutter_tts. Habla en el idioma del sistema; si ese idioma
/// no tiene voz instalada, hace fallback a español (requisito mínimo
/// del enunciado, sección 2.3).
class VoiceAnnouncer {
  VoiceAnnouncer() : _tts = FlutterTts();

  final FlutterTts _tts;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // flutter_tts no expone "idioma del sistema" de forma directa y
    // confiable multiplataforma. Patrón usado aquí, cumpliendo el mínimo
    // del enunciado ("en español como mínimo"):
    // 1) Verificar si español está disponible como voz instalada.
    // 2) Fijarlo explícitamente como base garantizada.
    // Ver nota más abajo para la variante con detección de locale del
    // sistema vía Localizations.localeOf(context).
    final spanishAvailable = await _tts.isLanguageAvailable('es-ES');
    await _tts.setLanguage(spanishAvailable == true ? 'es-ES' : 'es');

    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _initialized = true;
  }

  Future<void> speak(String text) async {
    await init();
    await _tts.stop(); // evita encolar avisos atrasados sobre el estado actual
    await _tts.speak(text);
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
```

> Nota técnica honesta: `flutter_tts` no tiene un método único multiplataforma para "leer el
> locale del sistema y listo" — en Android el motor nativo `TextToSpeech` ya intenta usar el
> idioma del sistema si no llamas a `setLanguage`, así que una alternativa válida es **no llamar
> `setLanguage` en absoluto** y dejar que el motor nativo decida, solo cayendo a `'es-ES'` si
> `isLanguageAvailable` devuelve `false` para el locale reportado por `Localizations.localeOf
> (context)`. Si quieres ese comportamiento más fiel al "idioma del sistema, o español como
> mínimo" del enunciado, reemplaza `init()` por la variante con detección de locale (pídela y la
> agrego), documentando ese matiz en el informe del taller.

---

## 7. Cubit — orquestación, debounce y disparo de voz/caída

`lib/features/activity_detection/presentation/cubit/activity_detection_cubit.dart`

```dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/datasources/motion_sensor_datasource.dart';
import '../../data/datasources/voice_announcer.dart';
import '../../domain/entities/fall_event.dart';
import '../../domain/entities/motion_state.dart';

class ActivityDetectionState extends Equatable {
  final MotionType currentType;
  final bool isFallSuspected;

  const ActivityDetectionState({
    this.currentType = MotionType.stationary,
    this.isFallSuspected = false,
  });

  ActivityDetectionState copyWith({MotionType? currentType, bool? isFallSuspected}) {
    return ActivityDetectionState(
      currentType: currentType ?? this.currentType,
      isFallSuspected: isFallSuspected ?? this.isFallSuspected,
    );
  }

  @override
  List<Object?> get props => [currentType, isFallSuspected];
}

class ActivityDetectionCubit extends Cubit<ActivityDetectionState> {
  ActivityDetectionCubit({
    required MotionSensorDataSource dataSource,
    required VoiceAnnouncer announcer,
  })  : _dataSource = dataSource,
        _announcer = announcer,
        super(const ActivityDetectionState());

  final MotionSensorDataSource _dataSource;
  final VoiceAnnouncer _announcer;

  StreamSubscription<MotionState>? _motionSub;
  StreamSubscription<FallEvent>? _fallSub;

  // Debounce manual (ver SKILL.md 0.6): 3 segundos de estabilidad
  // antes de anunciar un cambio de estado.
  static const Duration _debounceWindow = Duration(seconds: 3);
  Timer? _debounceTimer;
  MotionType? _pendingType;
  MotionType _lastAnnouncedType = MotionType.stationary;

  void start() {
    _dataSource.start();

    _motionSub = _dataSource.motionStream.listen(_onMotion);
    _fallSub = _dataSource.fallStream.listen(_onFall);
  }

  void _onMotion(MotionState motion) {
    emit(state.copyWith(currentType: motion.type));

    if (motion.type == _pendingType) {
      // Mismo candidato que ya está esperando confirmación: no reiniciar timer.
      return;
    }

    // Llegó un tipo distinto al que se estaba esperando: reinicia el debounce.
    _pendingType = motion.type;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceWindow, () => _confirmStableState(motion.type));
  }

  void _confirmStableState(MotionType stableType) {
    if (stableType == _lastAnnouncedType) return; // evita avisos repetidos

    _lastAnnouncedType = stableType;
    _announcer.speak(_messageFor(stableType));
  }

  String _messageFor(MotionType type) {
    switch (type) {
      case MotionType.walking:
        return 'Estás caminando';
      case MotionType.running:
        return 'Estás corriendo';
      case MotionType.stationary:
        return 'Te has detenido';
    }
  }

  void _onFall(FallEvent event) {
    if (state.isFallSuspected) return; // ya hay un diálogo de caída activo
    emit(state.copyWith(isFallSuspected: true));
    _announcer.speak('Se ha detectado una posible caída');
  }

  /// Llamado por la UI cuando el usuario confirma o se cierra el diálogo.
  void resolveFallSuspicion() {
    emit(state.copyWith(isFallSuspected: false));
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    _motionSub?.cancel();
    _fallSub?.cancel();
    _dataSource.dispose();
    _announcer.dispose();
    return super.close();
  }
}
```

**Cómo funciona el debounce paso a paso:** cada lectura de `motionStream` (llega varias veces
por segundo) actualiza la UI inmediatamente (`emit` con el tipo crudo, para que la tarjeta de
estado se sienta responsiva), pero el **aviso de voz** solo se dispara si ese mismo tipo
permanece como "candidato" (`_pendingType`) durante 3 segundos seguidos sin que llegue un tipo
distinto que reinicie el `Timer`. Además, aunque se mantenga estable, si ya es el mismo estado
que se anunció la última vez (`_lastAnnouncedType`) no se repite el aviso — esto cumple
exactamente el punto 2.4 del enunciado ("solo si el nuevo estado se ha mantenido estable... y
siempre que sea diferente al último estado ya anunciado").

---

## 8. UI — diálogo de confirmación de caída (15s + refuerzo)

`lib/features/activity_detection/presentation/widgets/fall_confirmation_dialog.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';

class FallConfirmationDialog extends StatefulWidget {
  const FallConfirmationDialog({super.key, required this.onResolved});

  final VoidCallback onResolved;

  static Future<void> show(BuildContext context, VoidCallback onResolved) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => FallConfirmationDialog(onResolved: onResolved),
    );
  }

  @override
  State<FallConfirmationDialog> createState() => _FallConfirmationDialogState();
}

class _FallConfirmationDialogState extends State<FallConfirmationDialog> {
  Timer? _reinforceTimer;
  bool _showReinforcement = false;

  @override
  void initState() {
    super.initState();
    // Si no hay respuesta en 15s, refuerza el mensaje (enunciado punto 1.3).
    _reinforceTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() => _showReinforcement = true);
    });
  }

  void _resolve() {
    _reinforceTimer?.cancel();
    widget.onResolved();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _reinforceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
      title: const Text('¿Estás bien?'),
      content: Text(
        _showReinforcement
            ? 'Detectamos que no has respondido. Por favor confirma si estás bien o '
              'busca ayuda si la necesitas.'
            : 'Detectamos un posible impacto fuerte. Confirma que estás bien.',
      ),
      actions: [
        TextButton(
          onPressed: _resolve,
          child: const Text('Estoy bien'),
        ),
      ],
    );
  }
}
```

Conexión en la pantalla principal (`BlocListener` reaccionando a `isFallSuspected`):

```dart
BlocListener<ActivityDetectionCubit, ActivityDetectionState>(
  listenWhen: (prev, curr) => prev.isFallSuspected != curr.isFallSuspected,
  listener: (context, state) {
    if (state.isFallSuspected) {
      FallConfirmationDialog.show(
        context,
        () => context.read<ActivityDetectionCubit>().resolveFallSuspicion(),
      );
    }
  },
  child: const ActivityStatusWidget(),
)
```

---

## 9. UI — tarjeta de estado de actividad

`lib/features/activity_detection/presentation/widgets/activity_status_widget.dart`

Sigue el mismo estilo visual que `StepCounterWidget` ya existente, para consistencia:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/motion_state.dart';
import '../cubit/activity_detection_cubit.dart';

class ActivityStatusWidget extends StatelessWidget {
  const ActivityStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityDetectionCubit, ActivityDetectionState>(
      builder: (context, state) {
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Actividad detectada',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Icon(_iconFor(state.currentType), size: 56, color: const Color(0xFF6366F1)),
                const SizedBox(height: 8),
                Text(
                  _labelFor(state.currentType),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconFor(MotionType type) {
    switch (type) {
      case MotionType.walking:
        return Icons.directions_walk;
      case MotionType.running:
        return Icons.directions_run;
      case MotionType.stationary:
        return Icons.accessibility_new;
    }
  }

  String _labelFor(MotionType type) {
    switch (type) {
      case MotionType.walking:
        return 'Caminando';
      case MotionType.running:
        return 'Corriendo';
      case MotionType.stationary:
        return 'Quieto';
    }
  }
}
```

---

## 10. Cableado en `main.dart` (sin tocar el resto)

Se agrega el `BlocProvider` del nuevo Cubit **junto a** los existentes, sin modificar
`AuthBloc`, `BiometricDataSourceImpl`, ni los widgets de `steps`/`tracking`:

Agregar los imports nuevos al inicio del archivo (los existentes se mantienen tal cual):

```dart
// Imports existentes — NO TOCAR:
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'features/auth/data/datasources/biometric_datasource.dart';
// import 'features/auth/domain/usecases/authenticate_user.dart';
// import 'features/auth/presentation/bloc/auth_bloc.dart';
// import 'features/auth/presentation/pages/login_page.dart';
// import 'features/steps/presentation/widgets/step_counter_widget.dart';
// import 'features/tracking/presentation/widgets/route_map_widget.dart';

// Imports NUEVOS — agregar debajo de los anteriores:
import 'features/activity_detection/data/datasources/motion_sensor_datasource.dart';
import 'features/activity_detection/data/datasources/voice_announcer.dart';
import 'features/activity_detection/presentation/cubit/activity_detection_cubit.dart';
import 'features/activity_detection/presentation/widgets/activity_status_widget.dart';
import 'features/activity_detection/presentation/widgets/fall_confirmation_dialog.dart';
```

`main()`, `FitnessApp` y `AuthWrapper` se quedan **exactamente igual que hoy** — no se tocan.
La única clase que cambia es `HomePage`:

```dart
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ActivityDetectionCubit(
        dataSource: MotionSensorDataSourceImpl(),
        announcer: VoiceAnnouncer(),
      )..start(),
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
                ActivityStatusWidget(),     // NUEVO
                SizedBox(height: 16),
                StepCounterWidget(),         // sin cambios
                SizedBox(height: 16),
                RouteMapWidget(),            // sin cambios
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

**Permiso antes de iniciar:** si quieres bloquear el arranque del stream hasta que el permiso
esté concedido (en vez de que `sensors_plus` simplemente no emita nada), pide explícitamente que
amplíe esta skill con un `FutureBuilder` previo a `..start()` que llame a
`requestActivityPermission()` del paso 2.2 — no se incluye por defecto aquí para no acoplar el
Cubit a `permission_handler` directamente y mantenerlo testeable.

---

## 11. Resumen de archivos

| Archivo | Acción |
|---|---|
| `pubspec.yaml` | Modificar — agregar `sensors_plus: ^7.0.0`, `flutter_tts: ^4.2.5` |
| `android/app/src/main/AndroidManifest.xml` | Modificar — agregar `<queries>` para TTS (no tocar permisos existentes) |
| `lib/features/activity_detection/domain/entities/motion_state.dart` | **Nuevo** |
| `lib/features/activity_detection/domain/entities/fall_event.dart` | **Nuevo** |
| `lib/features/activity_detection/domain/usecases/classify_motion.dart` | **Nuevo** |
| `lib/features/activity_detection/data/datasources/motion_sensor_datasource.dart` | **Nuevo** |
| `lib/features/activity_detection/data/datasources/voice_announcer.dart` | **Nuevo** |
| `lib/features/activity_detection/presentation/cubit/activity_detection_cubit.dart` | **Nuevo** |
| `lib/features/activity_detection/presentation/widgets/activity_status_widget.dart` | **Nuevo** |
| `lib/features/activity_detection/presentation/widgets/fall_confirmation_dialog.dart` | **Nuevo** |
| `lib/main.dart` | Modificar — solo `HomePage`, agregar `BlocProvider` + dos widgets nuevos en el `Column` |
| `lib/features/auth/**`, `lib/features/steps/**`, `lib/features/tracking/**` | **Sin cambios** |
| `android/.../MainActivity.kt` | **Sin cambios** |

---

## 12. Checklist de verificación

- [ ] `flutter pub get` corre sin conflictos de versión (revisar `pubspec.lock` regenerado)
- [ ] App compila en Android sin tocar `MainActivity.kt`
- [ ] Al iniciar, se solicita el permiso de actividad física antes de que el stream emita datos
- [ ] Caminar sostenido 3+ segundos dispara "Estás caminando" una sola vez
- [ ] Pasar de caminar a correr y volver a caminar rápido (<3s en cada uno) **no** dispara avisos
      intermedios — solo el estado que se estabiliza
- [ ] Quedarse en el mismo estado no repite el aviso de voz
- [ ] Simular caída (dejar caer el dispositivo sobre superficie blanda, con cuidado) dispara el
      diálogo "¿Estás bien?"
- [ ] No tocar el diálogo 15 segundos → aparece el mensaje de refuerzo sin cerrar el diálogo
- [ ] Tocar "Estoy bien" cierra el diálogo y permite que se vuelva a disparar ante una nueva caída
- [ ] El contador de pasos (`StepCounterWidget`) sigue funcionando exactamente igual que antes
- [ ] El login biométrico y el mapa de ruta GPS siguen funcionando exactamente igual que antes
- [ ] La voz suena en español como mínimo (verificar en dispositivo con idioma del sistema distinto)