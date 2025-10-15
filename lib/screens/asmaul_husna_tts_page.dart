import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Adjust this import to match your file path:
// if your list file is at lib/asmaul_husna_tts.dart, use:
import '../asmaul_husna_tts.dart'; // provides `asmaulHusna` (id, arabic, transliteration)

class AsmaulHusnaTtsPage extends StatefulWidget {
  const AsmaulHusnaTtsPage({super.key});

  @override
  State<AsmaulHusnaTtsPage> createState() => _AsmaulHusnaTtsPageState();
}

class _AsmaulHusnaTtsPageState extends State<AsmaulHusnaTtsPage> {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  int? _speakingId; // which row is currently playing
  bool _isPlayingAll = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    // baseline clear Arabic voice
    await _tts.setLanguage('ar-SA');
    await _tts.setSpeechRate(0.40);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    // fallbacks if ar-SA unavailable
    final langs = (await _tts.getLanguages) as List?;
    if (langs != null && !langs.contains('ar-SA')) {
      if (langs.contains('ar')) {
        await _tts.setLanguage('ar');
      } else if (langs.contains('ar-XA')) {
        await _tts.setLanguage('ar-XA');
      }
    }

    _tts.setCompletionHandler(() {
      if (!_isPlayingAll) {
        setState(() => _speakingId = null);
      }
    });
    _tts.setCancelHandler(() {
      if (!_isPlayingAll) {
        setState(() => _speakingId = null);
      }
    });
    _tts.setErrorHandler((msg) {
      debugPrint('TTS error: $msg');
      setState(() {
        _speakingId = null;
        _isPlayingAll = false;
      });
    });

    setState(() => _ready = true);
  }

  Future<void> _speak(int id, String text) async {
    if (!_ready) return;
    await _tts.stop();
    setState(() => _speakingId = id);
    await _tts.speak(text);
  }

  Future<void> _stop() async {
    await _tts.stop();
    setState(() {
      _speakingId = null;
      _isPlayingAll = false;
    });
  }

  Future<void> _playAll() async {
    if (_isPlayingAll) return;
    setState(() => _isPlayingAll = true);

    for (final n in asmaulHusna) {
      if (!_isPlayingAll) break; // user stopped
      await _tts.stop();
      setState(() => _speakingId = n.id);
      await _tts.speak(n.arabic);

      // wait until current item finishes
      bool speaking = true;
      _tts.setCompletionHandler(() => speaking = false);
      _tts.setCancelHandler(() => speaking = false);
      while (speaking && _isPlayingAll) {
        await Future.delayed(const Duration(milliseconds: 120));
      }

      // small gap
      await Future.delayed(const Duration(milliseconds: 250));
    }

    if (mounted) {
      setState(() {
        _speakingId = null;
        _isPlayingAll = false;
      });
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أسماء الله الحسنى'),
        actions: [
          if (!_isPlayingAll)
            IconButton(
              tooltip: 'تشغيل الكل',
              onPressed: _playAll,
              icon: const Icon(Icons.playlist_play),
            )
          else
            IconButton(
              tooltip: 'إيقاف',
              onPressed: _stop,
              icon: const Icon(Icons.stop),
            ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: asmaulHusna.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final n = asmaulHusna[i];
          final playing = _speakingId == n.id;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              n.arabic,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 22, height: 1.25),
            ),
            subtitle: Text(
              n.transliteration,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13),
            ),
            trailing: IconButton(
              tooltip: playing ? 'إيقاف' : 'استماع',
              icon: Icon(playing ? Icons.stop : Icons.volume_up),
              onPressed: playing ? _stop : () => _speak(n.id, n.arabic),
            ),
            onTap: () => _speak(n.id, n.arabic),
          );
        },
      ),
      floatingActionButton: (_speakingId != null || _isPlayingAll)
          ? FloatingActionButton.extended(
              onPressed: _stop,
              icon: const Icon(Icons.stop),
              label: const Text('إيقاف'),
            )
          : null,
    );
  }
}
