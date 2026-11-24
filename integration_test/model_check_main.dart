// Standalone model check that needs no debugger connection, so it also works
// in release (AOT) mode and gives real-world timings:
//
//   flutter build apk --release -t integration_test/model_check_main.dart
//   adb install -r build/app/outputs/flutter-apk/app-release.apk
//   adb shell am start -n com.example.smart_crop/.MainActivity
//   adb logcat -s flutter        (lines start with MODELCHECK)
//
// Results also appear on screen.
// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:smart_crop/models/classification_result.dart';
import 'package:smart_crop/services/image_preprocessor.dart';
import 'package:smart_crop/services/plant_classifier.dart';

import 'sample_leaves.dart';

final _lines = ValueNotifier<List<String>>([]);

void _log(String line) {
  print('MODELCHECK $line');
  _lines.value = [..._lines.value, line];
}

String _ms(num micros) => (micros / 1000).toStringAsFixed(1);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _CheckApp());
  try {
    for (final range in PixelRange.values) {
      await _checkRange(range);
    }
    await _checkQueue();
    await _checkPhotoSizes();
    _log('DONE');
  } catch (e, st) {
    _log('ERROR $e\n$st');
  }
}

Future<void> _checkRange(PixelRange range) async {
  final loadWatch = Stopwatch()..start();
  final classifier = await PlantClassifier.load(
    preprocessor: ImagePreprocessor(pixelRange: range),
  );
  _log('[${range.name}] model loaded in ${loadWatch.elapsedMilliseconds} ms');

  var correct = 0;
  var confidenceSum = 0.0;
  final results = <ClassificationResult>[];
  for (final MapEntry(key: file, value: expected) in sampleLeaves.entries) {
    final bytes = (await rootBundle.load('assets/samples/$file')).buffer.asUint8List();
    final result = await classifier
        .classifyBytes(bytes)
        .timeout(const Duration(seconds: 60));
    results.add(result);
    final ok = result.top.label.raw == expected;
    if (ok) correct++;
    confidenceSum += result.top.confidence;
    _log('${ok ? 'OK  ' : 'MISS'} $file -> ${result.predictions.join(' | ')} '
        '(pre ${_ms(result.preprocessTime.inMicroseconds)} ms, '
        'infer ${_ms(result.inferenceTime.inMicroseconds)} ms)');
  }
  await classifier.close();

  final warm = results.skip(1).toList(); // first call includes warm-up
  num avg(int Function(ClassificationResult) f) =>
      warm.map(f).reduce((a, b) => a + b) / warm.length;
  _log('SUMMARY [${range.name}] $correct/${sampleLeaves.length} correct, '
      'mean top-1 ${(confidenceSum / sampleLeaves.length * 100).toStringAsFixed(1)}%, '
      'avg pre ${_ms(avg((r) => r.preprocessTime.inMicroseconds))} ms, '
      'avg infer ${_ms(avg((r) => r.inferenceTime.inMicroseconds))} ms');
}

Future<void> _checkQueue() async {
  final classifier = await PlantClassifier.load();
  final files = sampleLeaves.keys.take(4).toList();
  final images = [
    for (final f in files)
      (await rootBundle.load('assets/samples/$f')).buffer.asUint8List(),
  ];
  final results = await Future.wait(images.map(classifier.classifyBytes))
      .timeout(const Duration(seconds: 120));
  await classifier.close();
  final allRight = [
    for (var i = 0; i < files.length; i++)
      results[i].top.label.raw == sampleLeaves[files[i]],
  ].every((ok) => ok);
  _log('QUEUE ${allRight ? 'OK' : 'MISMATCH'}: 4 overlapping calls all returned');
}

/// Timing only: how long a full analysis takes for photos the size a phone
/// camera or gallery produces. (The upscaled sample is stretched, so its
/// prediction is not meaningful here.)
Future<void> _checkPhotoSizes() async {
  final classifier = await PlantClassifier.load();
  final source = img.decodeJpg(
    (await rootBundle.load('assets/samples/corn_common_rust.jpg'))
        .buffer
        .asUint8List(),
  )!;
  for (final (name, w, h) in const [
    ('camera 1280x720', 1280, 720),
    ('gallery 1600x1200', 1600, 1200),
    ('12 MP 4000x3000', 4000, 3000),
  ]) {
    final jpeg = img.encodeJpg(
      img.copyResize(source, width: w, height: h),
      quality: 90,
    );
    final pre = <int>[];
    final infer = <int>[];
    for (var i = 0; i < 3; i++) {
      final r = await classifier.classifyBytes(jpeg);
      pre.add(r.preprocessTime.inMicroseconds);
      infer.add(r.inferenceTime.inMicroseconds);
    }
    num avg(List<int> v) => v.reduce((a, b) => a + b) / v.length;
    _log('SIZE $name (${(jpeg.length / 1024).round()} KB JPEG): '
        'avg pre ${_ms(avg(pre))} ms, avg infer ${_ms(avg(infer))} ms');
  }
  await classifier.close();
}

class _CheckApp extends StatelessWidget {
  const _CheckApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('SmartCrop model check')),
        body: ValueListenableBuilder(
          valueListenable: _lines,
          builder: (context, lines, _) => ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: line.startsWith('MISS') || line.startsWith('ERROR')
                          ? Colors.red
                          : null,
                    ),
                  ),
                ),
              if (lines.isEmpty || lines.last != 'DONE')
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
