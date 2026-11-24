/// One of the classes the model can predict, parsed from a raw label such as
/// `Tomato___Early_blight` (crop and condition separated by three underscores).
class PlantLabel {
  const PlantLabel({
    required this.index,
    required this.raw,
    required this.crop,
    required this.condition,
  });

  factory PlantLabel.parse(int index, String raw) {
    final parts = raw.split('___');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      throw FormatException('Expected "<crop>___<condition>"', raw);
    }
    return PlantLabel(
      index: index,
      raw: raw,
      crop: _cropNames[parts[0]] ?? _sentenceCase(parts[0]),
      condition: _conditionNames[raw] ?? _sentenceCase(parts[1]),
    );
  }

  /// Parses `labels.txt`: one label per line, line i = model output index i.
  static List<PlantLabel> parseLabelsFile(String contents) {
    final lines = contents
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return [for (var i = 0; i < lines.length; i++) PlantLabel.parse(i, lines[i])];
  }

  /// Index in the model's output vector.
  final int index;

  /// The label exactly as written in labels.txt. Use it as the lookup key
  /// for per-disease data (e.g. guidance), since display names may change.
  final String raw;

  /// Human-readable crop name, e.g. "Tomato".
  final String crop;

  /// Human-readable condition, e.g. "Early blight" or "Healthy".
  final String condition;

  bool get isHealthy => condition == 'Healthy';

  String get displayName => '$crop: $condition';

  @override
  String toString() => 'PlantLabel($index, $raw)';

  /// Crop names that read badly after the generic cleanup.
  static const _cropNames = {
    'Cherry_(including_sour)': 'Cherry',
    'Corn_(maize)': 'Corn',
    'Pepper_bell': 'Bell pepper',
  };

  /// Conditions whose raw names are awkward, misspelled or repeat the crop.
  static const _conditionNames = {
    'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot':
        'Gray leaf spot (Cercospora)',
    'Grape___Esca_(Black_Measles)': 'Esca (black measles)',
    'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)':
        'Leaf blight (Isariopsis leaf spot)',
    'Orange___Haunglongbing_(Citrus_greening)':
        'Huanglongbing (citrus greening)',
    'Tomato___Spider_mites Two-spotted_spider_mite':
        'Spider mites (two-spotted spider mite)',
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus': 'Yellow leaf curl virus',
    'Tomato___Tomato_mosaic_virus': 'Mosaic virus',
  };

  /// "Northern_Leaf_Blight" -> "Northern leaf blight", "Common_rust_" -> "Common rust".
  static String _sentenceCase(String text) {
    final words = text.replaceAll('_', ' ').trim().split(RegExp(r'\s+'));
    final joined = words.join(' ').toLowerCase();
    return joined[0].toUpperCase() + joined.substring(1);
  }
}
