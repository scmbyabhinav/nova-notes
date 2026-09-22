import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OrahOcrService {
  OrahOcrService._();
  static final instance = OrahOcrService._();
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> extractText(File image) async {
    final input = InputImage.fromFile(image);
    final result = await _recognizer.processImage(input);
    return result.text.trim();
  }

  Future<void> dispose() => _recognizer.close();
}
