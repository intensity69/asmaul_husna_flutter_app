import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      useMaterial3: true,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Asmaul Husna',
      theme: base.copyWith(
        textTheme: base.textTheme.copyWith(
          titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
          bodyMedium: GoogleFonts.inter(),
        ),
      ),
      home: const AsmaulListScreen(),
    );
  }
}

enum Lang { en, ms, ta }

class AsmaulListScreen extends StatefulWidget {
  const AsmaulListScreen({super.key});
  @override
  State<AsmaulListScreen> createState() => _AsmaulListScreenState();
}

class _AsmaulListScreenState extends State<AsmaulListScreen> {
  // -------- Data / Search --------
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _visible = [];
  Lang _lang = Lang.en;
  String _query = '';

  // -------- TTS --------
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  int? _speakingId;
  bool _isPlayingAll = false;
  Map<String, String>? _selectedVoice;

  // Remove most tashkīl & dagger-alif for smoother speech
  final _arabicDiacritics =
      RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]');
  String _cleanForTts(String s) => s.replaceAll(_arabicDiacritics, '');

  @override
  void initState() {
    super.initState();
    _loadJson();
    _initTts();
  }

  Future<void> _loadJson() async {
    final raw = await rootBundle.loadString('assets/json/asmaul_husna.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    final list = (data['asmaul_husna'] as List)
        .cast<Map<String, dynamic>>()
        .where((e) => (e['arabic'] ?? '').toString().trim().isNotEmpty)
        .toList();
    setState(() {
      _all = list;
      _visible = list;
    });
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('ar-SA');
    await _tts.setSpeechRate(0.33);
    await _tts.setPitch(1.08);
    await _tts.setVolume(1.0);

    // Prefer a high-quality Google Arabic voice when available
    final voices = (await _tts.getVoices) as List<dynamic>?;
    if (voices != null) {
      Map<String, dynamic>? best;
      for (final v in voices.cast<Map>()) {
        final name = (v['name'] ?? '').toString().toLowerCase();
        final locale = (v['locale'] ?? '').toString().toLowerCase();
        final isArabic = locale.startsWith('ar');
        final isGoogle = name.contains('google') || name.contains('gcloud');
        if (isArabic && (best == null || isGoogle)) {
          best = Map<String, dynamic>.from(v);
          if (isGoogle) break;
        }
      }
      if (best != null) {
        _selectedVoice = {
          'name': best['name']?.toString() ?? '',
          'locale': best['locale']?.toString() ?? '',
        };
        await _tts.setVoice(_selectedVoice!);
      }
    }

    _tts.setCompletionHandler(() {
      if (!_isPlayingAll && mounted) setState(() => _speakingId = null);
    });
    _tts.setCancelHandler(() {
      if (!_isPlayingAll && mounted) setState(() => _speakingId = null);
    });
    _tts.setErrorHandler((msg) {
      debugPrint('TTS error: $msg');
      if (mounted) {
        setState(() {
          _speakingId = null;
          _isPlayingAll = false;
        });
      }
    });

    if (mounted) setState(() => _ttsReady = true);
  }

  void _applyFilter() {
    setState(() {
      final key = switch (_lang) {
        Lang.en => 'meaning_en',
        Lang.ms => 'meaning_ms',
        Lang.ta => 'meaning_ta',
      };
      _visible = _all.where((e) {
        final hay = [
          e['transliteration'] ?? '',
          e[key] ?? '',
          e['arabic'] ?? '',
        ].join(' ').toLowerCase();
        return hay.contains(_query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _speak(int id, String arabic) async {
    if (!_ttsReady) return;
    await _tts.stop();
    setState(() => _speakingId = id);
    await _tts.speak(_cleanForTts(arabic));
  }

  Future<void> _stop() async {
    await _tts.stop();
    setState(() {
      _speakingId = null;
      _isPlayingAll = false;
    });
  }

  Future<void> _playAll() async {
    if (_isPlayingAll || !_ttsReady) return;
    setState(() => _isPlayingAll = true);

    for (final n in _visible) {
      if (!_isPlayingAll) break;
      final id = (n['id'] ?? 0) as int;
      await _tts.stop();
      setState(() => _speakingId = id);
      await _tts.speak(_cleanForTts((n['arabic'] ?? '').toString()));

      bool speaking = true;
      _tts.setCompletionHandler(() => speaking = false);
      _tts.setCancelHandler(() => speaking = false);
      while (speaking && _isPlayingAll) {
        await Future.delayed(const Duration(milliseconds: 120));
      }
      await Future.delayed(const Duration(milliseconds: 250));
    }

    if (mounted) {
      setState(() {
        _speakingId = null;
        _isPlayingAll = false;
      });
    }
  }

  Future<void> _chooseVoice() async {
    final voices = (await _tts.getVoices) as List<dynamic>?;
    if (!mounted || voices == null) return;

    final arVoices = voices
        .cast<Map>()
        .where((v) =>
            (v['locale'] ?? '').toString().toLowerCase().startsWith('ar'))
        .map((v) => Map<String, String>.from(v.cast<String, String>()))
        .toList();

    if (arVoices.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No Arabic voices found. Install a high-quality Arabic voice from system settings.')),
      );
      return;
    }

    final chosen = await showModalBottomSheet<Map<String, String>>(
      context: context,
      builder: (ctx) => ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (_, i) {
          final v = arVoices[i];
          final selected = _selectedVoice != null &&
              _selectedVoice!['name'] == v['name'] &&
              _selectedVoice!['locale'] == v['locale'];
          return ListTile(
            title: Text(v['name'] ?? ''),
            subtitle: Text(v['locale'] ?? ''),
            trailing: selected ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(ctx, v),
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: arVoices.length,
      ),
    );

    if (chosen != null) {
      await _tts.setVoice(chosen);
      setState(() => _selectedVoice = chosen);
      await _tts.speak(_cleanForTts('الرَّحْمَنُ'));
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arabicStyle = GoogleFonts.amiri(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('99 Names of Allah'),
        actions: [
          if (!_isPlayingAll)
            IconButton(
              tooltip: 'Play All',
              onPressed: _playAll,
              icon: const Icon(Icons.playlist_play),
            )
          else
            IconButton(
              tooltip: 'Stop',
              onPressed: _stop,
              icon: const Icon(Icons.stop),
            ),
          IconButton(
            tooltip: 'Choose Voice',
            onPressed: _chooseVoice,
            icon: const Icon(Icons.record_voice_over),
          ),
          PopupMenuButton<Lang>(
            initialValue: _lang,
            onSelected: (v) {
              _lang = v;
              _applyFilter();
            },
            itemBuilder: (c) => const [
              PopupMenuItem(value: Lang.en, child: Text('English')),
              PopupMenuItem(value: Lang.ms, child: Text('BM (Malay)')),
              PopupMenuItem(value: Lang.ta, child: Text('Tamil')),
            ],
            icon: const Icon(Icons.translate),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) {
                _query = v;
                _applyFilter();
              },
              decoration: InputDecoration(
                hintText: 'Search (name / meaning / Arabic)',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _visible.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, i) {
                final n = _visible[i];
                final id = (n['id'] ?? 0) as int;
                final meaning = switch (_lang) {
                  Lang.en => n['meaning_en'] ?? '',
                  Lang.ms => n['meaning_ms'] ?? '',
                  Lang.ta => n['meaning_ta'] ?? '',
                };
                final playing = _speakingId == id;

                return Card(
                  elevation: 0,
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.deepPurple.shade100,
                      child: Text('$id',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            (n['transliteration'] ?? '').toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          (n['arabic'] ?? '').toString(),
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: arabicStyle,
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(meaning.toString()),
                    ),
                    trailing: IconButton(
                      tooltip: playing ? 'Stop' : 'Listen',
                      icon:
                          Icon(playing ? Icons.stop : Icons.volume_up_outlined),
                      onPressed: playing
                          ? _stop
                          : () => _speak(id, (n['arabic'] ?? '').toString()),
                    ),
                    onTap: () => _speak(id, (n['arabic'] ?? '').toString()),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: _visible.length,
            ),
    );
  }
}
