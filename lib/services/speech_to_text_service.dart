import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef SpeechResultCallback = void Function(
  String transcript,
  bool isFinal,
);

typedef SpeechStatusCallback = void Function(String status);

typedef SpeechErrorCallback = void Function(String message);

abstract interface class VoiceSpeechService {
  bool get isListening;

  Future<bool> initialize({
    required SpeechStatusCallback onStatus,
    required SpeechErrorCallback onError,
  });

  Future<void> startListening({
    required SpeechResultCallback onResult,
  });

  Future<void> stopListening();

  Future<void> cancel();

  void dispose();
}

class SpeechToTextService implements VoiceSpeechService {
  SpeechToTextService({SpeechToText? speechToText})
      : _speechToText = speechToText ?? SpeechToText();

  final SpeechToText _speechToText;

  @override
  bool get isListening => _speechToText.isListening;

  @override
  Future<bool> initialize({
    required SpeechStatusCallback onStatus,
    required SpeechErrorCallback onError,
  }) {
    return _speechToText.initialize(
      onStatus: onStatus,
      onError: (error) => onError(error.errorMsg),
      debugLogging: false,
    );
  }

  @override
  Future<void> startListening({
    required SpeechResultCallback onResult,
  }) async {
    await _speechToText.listen(
      onDevice: true,
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
    );
  }

  @override
  Future<void> stopListening() => _speechToText.stop();

  @override
  Future<void> cancel() => _speechToText.cancel();

  @override
  void dispose() {
    _speechToText.cancel();
  }
}
