import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/disease_guide.dart';

/// All offline guidance, bundled with the app (assets/guide/), keyed by the
/// model's raw labels.
class GuideBook {
  GuideBook(this._guides);

  static const asset = 'assets/guide/disease_guide.json';

  static Future<GuideBook> load() async =>
      GuideBook.parse(await rootBundle.loadString(asset));

  factory GuideBook.parse(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final guides = json['guides'] as Map<String, dynamic>;
    return GuideBook({
      for (final MapEntry(:key, :value) in guides.entries)
        key: DiseaseGuide.fromJson(key, value as Map<String, dynamic>),
    });
  }

  final Map<String, DiseaseGuide> _guides;

  /// Guidance for a raw model label, or null if there is none.
  DiseaseGuide? operator [](String rawLabel) => _guides[rawLabel];

  Iterable<DiseaseGuide> get all => _guides.values;

  int get length => _guides.length;
}
