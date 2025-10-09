class AsmaulHusna {
  final int id;
  final String arabic;
  final String transliteration;
  final String meaningEn;
  final String meaningMs;
  final String meaningTa;
  final String descriptionEn;
  final String descriptionMs;
  final String descriptionTa;

  AsmaulHusna({
    required this.id,
    required this.arabic,
    required this.transliteration,
    required this.meaningEn,
    required this.meaningMs,
    required this.meaningTa,
    required this.descriptionEn,
    required this.descriptionMs,
    required this.descriptionTa,
  });

  factory AsmaulHusna.fromJson(Map<String, dynamic> json) {
    return AsmaulHusna(
      id: json['id'] ?? 0,
      arabic: json['arabic'] ?? '',
      transliteration: json['transliteration'] ?? '',
      meaningEn: json['meaning_en'] ?? '',
      meaningMs: json['meaning_ms'] ?? '',
      meaningTa: json['meaning_ta'] ?? '',
      descriptionEn: json['description_en'] ?? '',
      descriptionMs: json['description_ms'] ?? '',
      descriptionTa: json['description_ta'] ?? '',
    );
  }
}
