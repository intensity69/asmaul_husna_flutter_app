import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _visible = [];
  Lang _lang = Lang.en;
  String _query = '';

  Future<void> _loadJson() async {
    final raw = await rootBundle.loadString('assets/json/asmaul_husna.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    final list = (data['asmaul_husna'] as List)
        .cast<Map<String, dynamic>>()
        .where((e) => (e['arabic'] ?? '').toString().trim().isNotEmpty)
        .toList(); // file currently has only first 3 filled; we’ll complete it below :contentReference[oaicite:0]{index=0}
    setState(() {
      _all = list;
      _visible = list;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadJson();
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
                final meaning = switch (_lang) {
                  Lang.en => n['meaning_en'] ?? '',
                  Lang.ms => n['meaning_ms'] ?? '',
                  Lang.ta => n['meaning_ta'] ?? '',
                };
                return Card(
                  elevation: 0,
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.deepPurple.shade100,
                      child: Text(
                        '${n['id']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            n['transliteration'] ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          n['arabic'] ?? '',
                          textAlign: TextAlign.right,
                          style: arabicStyle,
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(meaning),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: _visible.length,
            ),
    );
  }
}
