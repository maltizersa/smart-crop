// On-device check of the real model + preprocessing.
// Run with: flutter test integration_test/classifier_test.dart -d <device>
//
// Uses print (not debugPrint, which is rate-limited) so every line reaches
// the console even if the app is stopped right after.
// ignore_for_file: avoid_print
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smart_crop/models/classification_result.dart';
import 'package:smart_crop/services/image_preprocessor.dart';
import 'package:smart_crop/services/plant_classifier.dart';

import 'sample_leaves.dart';

final _samples = sampleLeaves;

Future<Uint8List> _asset(String path) async =>
    (await rootBundle.load(path)).buffer.asUint8List();

String _ms(Duration d) => (d.inMicroseconds / 1000).toStringAsFixed(1);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final range in PixelRange.values) {
    testWidgets('sample leaves, pixel range ${range.name}', (tester) async {
      await tester.runAsync(() async {
        final classifier = await PlantClassifier.load(
          preprocessor: ImagePreprocessor(pixelRange: range),
        );
        addTearDown(classifier.close);

        var correct = 0;
        var confidenceSum = 0.0;
        final results = <ClassificationResult>[];
        print('=== pixel range: ${range.name}');
        for (final MapEntry(key: file, value: expected) in _samples.entries) {
          print('${DateTime.now().toIso8601String()} classifying $file');
          final result = await classifier
              .classifyBytes(await _asset('assets/samples/$file'))
              .timeout(const Duration(seconds: 60));
          results.add(result);
          final ok = result.top.label.raw == expected;
          if (ok) correct++;
          confidenceSum += result.top.confidence;
          print(
            '${ok ? 'OK  ' : 'MISS'} $file -> ${result.predictions.join(' | ')}'
            '  (pre ${_ms(result.preprocessTime)} ms, infer ${_ms(result.inferenceTime)} ms)',
          );
        }
        // Skip the first call (warm-up) when averaging timings.
        final warm = results.skip(1);
        final avgPre = warm.map((r) => r.preprocessTime.inMicroseconds).reduce((a, b) => a + b) / warm.length / 1000;
        final avgInf = warm.map((r) => r.inferenceTime.inMicroseconds).reduce((a, b) => a + b) / warm.length / 1000;
        print(
          'SUMMARY ${range.name}: $correct/${_samples.length} correct, '
          'mean top-1 confidence ${(confidenceSum / _samples.length * 100).toStringAsFixed(1)}%, '
          'avg pre ${avgPre.toStringAsFixed(1)} ms, avg infer ${avgInf.toStringAsFixed(1)} ms',
        );

        if (range == PixelRange.zeroToOne) {
          // Measured 7/8 on 2026-11-24. The known miss is
          // tomato_early_blight.jpg, which comes out as Septoria leaf spot
          // (similar-looking fungal spots). Fewer than 7 means the
          // preprocessing or the model changed.
          expect(correct, greaterThanOrEqualTo(_samples.length - 1));
        }
      });
    });
  }

  testWidgets('overlapping calls are queued, not dropped', (tester) async {
    await tester.runAsync(() async {
      final classifier = await PlantClassifier.load();
      addTearDown(classifier.close);
      final files = _samples.keys.take(4).toList();
      final images = [for (final f in files) await _asset('assets/samples/$f')];

      final results = await Future.wait(images.map(classifier.classifyBytes))
          .timeout(const Duration(seconds: 120));

      for (var i = 0; i < files.length; i++) {
        expect(results[i].top.label.raw, _samples[files[i]], reason: files[i]);
      }
    });
  });
}
