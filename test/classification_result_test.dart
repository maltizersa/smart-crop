import 'package:flutter_test/flutter_test.dart';
import 'package:smart_crop/models/classification_result.dart';
import 'package:smart_crop/models/plant_label.dart';

void main() {
  final labels = PlantLabel.parseLabelsFile(
    'Tomato___healthy\nTomato___Early_blight\nPotato___Late_blight\nCorn_(maize)___Common_rust_',
  );

  test('topK sorts by confidence and keeps label alignment', () {
    final top = Prediction.topK([0.05, 0.7, 0.2, 0.05], labels, 3);
    expect(top.map((p) => p.label.raw), [
      'Tomato___Early_blight',
      'Potato___Late_blight',
      'Tomato___healthy',
    ]);
    expect(top.first.confidence, 0.7);
  });

  test('topK rejects a size mismatch', () {
    expect(() => Prediction.topK([1.0], labels, 1), throwsArgumentError);
  });

  ClassificationResult resultOf(List<double> scores) => ClassificationResult(
        predictions: Prediction.topK(scores, labels, 3),
        preprocessTime: Duration.zero,
        inferenceTime: Duration.zero,
      );

  test('verdict: healthy, diseased or uncertain', () {
    // labels: 0 Tomato healthy, 1 Tomato early blight, 2 Potato late blight, 3 Corn rust
    expect(resultOf([0.9, 0.05, 0.03, 0.02]).verdict, Verdict.healthy);
    expect(resultOf([0.05, 0.9, 0.03, 0.02]).verdict, Verdict.diseased);
    expect(resultOf([0.3, 0.45, 0.15, 0.1]).verdict, Verdict.uncertain);
  });

  test('high confidence starts at 85%', () {
    expect(resultOf([0.05, 0.86, 0.05, 0.04]).isHighConfidence, isTrue);
    expect(resultOf([0.2, 0.7, 0.05, 0.05]).isHighConfidence, isFalse);
  });

  test('strongAlternative when the runner-up is at least 25%', () {
    expect(
      resultOf([0.0, 0.52, 0.48, 0.0]).strongAlternative?.label.raw,
      'Potato___Late_blight',
    );
    expect(
      resultOf([0.3, 0.65, 0.05, 0.0]).strongAlternative?.label.raw,
      'Tomato___healthy',
    );
    expect(resultOf([0.06, 0.91, 0.03, 0.0]).strongAlternative, isNull);
    expect(resultOf([0.2, 0.7, 0.05, 0.05]).strongAlternative, isNull);
  });

  test('isConfident uses the threshold', () {
    ClassificationResult resultWith(double c) => ClassificationResult(
          predictions: [Prediction(labels[0], c)],
          preprocessTime: Duration.zero,
          inferenceTime: Duration.zero,
        );
    expect(resultWith(0.95).isConfident, isTrue);
    expect(resultWith(ClassificationResult.confidenceThreshold).isConfident, isTrue);
    expect(resultWith(0.4).isConfident, isFalse);
  });
}
