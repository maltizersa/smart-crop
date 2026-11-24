/// How soon a farmer should act.
enum Urgency { none, low, medium, high }

/// Offline management guidance for one model class.
class DiseaseGuide {
  const DiseaseGuide({
    required this.label,
    required this.cause,
    required this.urgency,
    required this.summary,
    required this.symptoms,
    required this.actions,
    required this.prevention,
    this.pathogen,
    this.urgencyNote,
    this.note,
  });

  factory DiseaseGuide.fromJson(String label, Map<String, dynamic> json) {
    T field<T>(String key) {
      final value = json[key];
      if (value is! T) {
        throw FormatException('Guide "$label": "$key" is missing or invalid');
      }
      return value;
    }

    List<String> list(String key) => field<List<dynamic>>(key).cast<String>();

    final urgencyName = field<String>('urgency');
    final urgency = Urgency.values.asNameMap()[urgencyName] ??
        (throw FormatException('Guide "$label": unknown urgency "$urgencyName"'));

    return DiseaseGuide(
      label: label,
      cause: field<String>('cause'),
      pathogen: json['pathogen'] as String?,
      urgency: urgency,
      urgencyNote: json['urgencyNote'] as String?,
      summary: field<String>('summary'),
      symptoms: list('symptoms'),
      actions: list('actions'),
      prevention: list('prevention'),
      note: json['note'] as String?,
    );
  }

  /// Raw model label, e.g. `Tomato___Early_blight`.
  final String label;

  /// Kind of cause: "Fungus", "Bacterium", "Virus", "Pest (mite)", "Healthy"...
  final String cause;

  /// Scientific name of the organism, when there is one.
  final String? pathogen;

  final Urgency urgency;

  /// Why it is urgent; shown as a banner when [urgency] is high.
  final String? urgencyNote;

  final String summary;

  /// Signs to look for. Empty for healthy classes.
  final List<String> symptoms;

  /// What to do now (or, for healthy leaves, how to keep watching).
  final List<String> actions;

  /// How to avoid it next season (or general good habits).
  final List<String> prevention;

  /// Model limitation worth knowing for this class, if any.
  final String? note;

  bool get isHealthy => cause == 'Healthy';

  bool get isPest => cause.startsWith('Pest');
}
