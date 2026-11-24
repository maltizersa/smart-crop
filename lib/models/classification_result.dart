import 'plant_label.dart';

class Prediction {
  const Prediction(this.label, this.confidence);

  final PlantLabel label;

  /// Probability from the model's softmax output, 0.0 to 1.0.
  final double confidence;

  /// The [k] most likely labels, highest confidence first.
  static List<Prediction> topK(
    List<double> probabilities,
    List<PlantLabel> labels,
    int k,
  ) {
    if (probabilities.length != labels.length) {
      throw ArgumentError(
        'Got ${probabilities.length} probabilities for ${labels.length} labels',
      );
    }
    final indices = List<int>.generate(labels.length, (i) => i)
      ..sort((a, b) => probabilities[b].compareTo(probabilities[a]));
    return [
      for (final i in indices.take(k)) Prediction(labels[i], probabilities[i]),
    ];
  }

  @override
  String toString() =>
      '${label.raw} ${(confidence * 100).toStringAsFixed(1)}%';
}

/// What the result screen tells the user, in one word.
enum Verdict { healthy, diseased, uncertain }

class ClassificationResult {
  const ClassificationResult({
    required this.predictions,
    required this.preprocessTime,
    required this.inferenceTime,
  });

  /// Below this, the app should ask for a clearer photo instead of
  /// presenting the top label as a diagnosis.
  static const double confidenceThreshold = 0.6;

  /// At or above this, the result is labeled "high confidence".
  static const double highConfidence = 0.85;

  /// A runner-up at or above this is worth pointing out to the user.
  static const double alternativeThreshold = 0.25;

  /// Top predictions, highest confidence first. Never empty.
  final List<Prediction> predictions;

  /// Decode + crop + resize + normalize.
  final Duration preprocessTime;

  /// Model invocation only.
  final Duration inferenceTime;

  Prediction get top => predictions.first;

  bool get isConfident => top.confidence >= confidenceThreshold;

  bool get isHighConfidence => top.confidence >= highConfidence;

  Verdict get verdict {
    if (!isConfident) return Verdict.uncertain;
    return top.label.isHealthy ? Verdict.healthy : Verdict.diseased;
  }

  /// The runner-up when it is a real possibility too, e.g. Grape black rot
  /// 52% vs Esca 48%. Null when the top match clearly dominates.
  Prediction? get strongAlternative {
    if (predictions.length < 2) return null;
    final second = predictions[1];
    return second.confidence >= alternativeThreshold ? second : null;
  }
}
