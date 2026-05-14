import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class NoteVoiceFeedbackService {
  final FlutterTts _tts = FlutterTts();
  final Random _random = Random();

  final List<String> _successPhrases = [
    'Awesome! Here it is.',
    'All set, there you go!',
    'That\'s cool, let me handle it.',
    'You have great artistic instincts! Done.',
    'Looking good! Formatting applied.',
    'Consider it done!',
    'Perfect, applying that right now.',
    'Got it! Your changes are live.',
  ];

  final List<String> _failurePhrases = [
    'Sorry, I couldn\'t find that word in the text.',
    'I don\'t support that specific feature just yet!',
    'Oops, I didn\'t quite catch that. Could you rephrase?',
    'Hmm, I couldn\'t find a match for that command.',
    'Sorry! I didn\'t understand. Let\'s try again.',
  ];

  Future<void> initializeSpeech(stt.SpeechToText speech) async {
    try {
      await speech.initialize(debugLogging: true);
      final voices = await _tts.getVoices;

      final preferredVoices = [
        'en-us-x-iom-network',
        'en-us-x-sfg-network',
        'en-gb-x-rjs-network',
        'en-in-x-ene-network',
      ];

      Map<String, String>? selectedVoice;

      for (final preferredName in preferredVoices) {
        for (final voice in voices) {
          final voiceName = voice['name'].toString().trim().toLowerCase();
          if (voiceName == preferredName) {
            selectedVoice = {
              'name': voice['name'].toString(),
              'locale': voice['locale'].toString(),
            };
            break;
          }
        }
        if (selectedVoice != null) break;
      }

      if (selectedVoice != null) {
        await _tts.setVoice(selectedVoice);
        debugPrint('SUCCESS: Forced Voice to -> ${selectedVoice['name']}');
      } else {
        debugPrint('FAILED: Network voices missing. Trying local default.');
        await _tts.setLanguage('en-US');
      }

      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(0.85);
      await _tts.setVolume(1.0);
    } catch (e) {
      debugPrint('Speech init error: $e');
    }
  }

  Future<void> speakSuccess() async {
    final phrase = _successPhrases[_random.nextInt(_successPhrases.length)];
    await _tts.speak(phrase);
  }

  Future<void> speakFailure() async {
    final phrase = _failurePhrases[_random.nextInt(_failurePhrases.length)];
    await _tts.speak(phrase);
  }
}
