import 'package:flutter_tts/flutter_tts.dart';

/// Interfaz para el sintetizador de voz.
abstract class VoiceAnnouncer {
  Future<void> init();
  Future<void> speak(String text);
  Future<void> dispose();
}

/// Implementación concreta de VoiceAnnouncer utilizando flutter_tts.
class VoiceAnnouncerImpl implements VoiceAnnouncer {
  VoiceAnnouncerImpl() : _tts = FlutterTts();

  final FlutterTts _tts;
  bool _initialized = false;

  @override
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

  @override
  Future<void> speak(String text) async {
    await init();
    await _tts.stop(); // evita encolar avisos atrasados sobre el estado actual
    await _tts.speak(text);
  }

  @override
  Future<void> dispose() async {
    await _tts.stop();
  }
}
