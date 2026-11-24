import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/classification_result.dart';
import '../models/plant_label.dart';
import 'image_preprocessor.dart';

/// Runs the bundled plant disease model entirely on the device.
///
/// Create once with [load] and reuse: loading the 13 MB model takes a moment,
/// classifying is fast. Each [classifyBytes] call does decoding,
/// preprocessing and inference in a background isolate so the UI stays smooth.
class PlantClassifier {
  PlantClassifier._(this._interpreter, this.labels, this.preprocessor);

  static const modelAsset = 'assets/models/plant_disease.tflite';
  static const labelsAsset = 'assets/labels/labels.txt';

  final Interpreter _interpreter;
  final List<PlantLabel> labels;
  final ImagePreprocessor preprocessor;

  /// Calls run one at a time on the single native interpreter.
  Future<void> _queue = Future.value();
  bool _closed = false;

  static Future<PlantClassifier> load({
    ImagePreprocessor preprocessor = const ImagePreprocessor(),
    int threads = 4,
  }) async {
    final labels = PlantLabel.parseLabelsFile(
      await rootBundle.loadString(labelsAsset),
    );
    final interpreter = await Interpreter.fromAsset(
      modelAsset,
      options: InterpreterOptions()..threads = threads,
    );
    try {
      _checkTensors(interpreter, labels.length, preprocessor.inputSize);
    } catch (_) {
      interpreter.close();
      rethrow;
    }
    return PlantClassifier._(interpreter, labels, preprocessor);
  }

  /// Classifies an encoded image (JPEG, PNG, ...) and returns the [topK]
  /// most likely labels.
  Future<ClassificationResult> classifyBytes(
    Uint8List encodedImage, {
    int topK = 3,
  }) {
    return _serialized(() async {
      final raw = await _inferInBackground(
        _interpreter.address,
        encodedImage,
        preprocessor,
        labels.length,
      );
      return ClassificationResult(
        predictions: Prediction.topK(raw.probabilities, labels, topK),
        preprocessTime: raw.preprocessTime,
        inferenceTime: raw.inferenceTime,
      );
    });
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _queue;
    _interpreter.close();
  }

  Future<T> _serialized<T>(Future<T> Function() task) {
    if (_closed) {
      return Future.error(StateError('PlantClassifier is closed'));
    }
    final result = _queue.then((_) => task());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  /// Static and synchronous on purpose: the closure passed to Isolate.run
  /// must not capture `this` (the native interpreter can't be sent between
  /// isolates; only its address can).
  static Future<_RawOutput> _inferInBackground(
    int interpreterAddress,
    Uint8List encodedImage,
    ImagePreprocessor preprocessor,
    int numClasses,
  ) {
    return Isolate.run(
      () => _infer(interpreterAddress, encodedImage, preprocessor, numClasses),
      debugName: 'PlantClassifier',
    );
  }

  static _RawOutput _infer(
    int interpreterAddress,
    Uint8List encodedImage,
    ImagePreprocessor preprocessor,
    int numClasses,
  ) {
    final stopwatch = Stopwatch()..start();
    final input = preprocessor.preprocessBytes(encodedImage);
    final preprocessTime = stopwatch.elapsed;

    stopwatch.reset();
    final output = Float32List(numClasses);
    Interpreter.fromAddress(interpreterAddress, allocated: true)
        .run(input.buffer, output.buffer);
    final inferenceTime = stopwatch.elapsed;

    return _RawOutput(output, preprocessTime, inferenceTime);
  }

  static void _checkTensors(
    Interpreter interpreter,
    int numLabels,
    int inputSize,
  ) {
    final input = interpreter.getInputTensor(0);
    final output = interpreter.getOutputTensor(0);
    final expectedInput = [1, inputSize, inputSize, 3];
    final expectedOutput = [1, numLabels];
    if (input.type != TensorType.float32 ||
        !_sameShape(input.shape, expectedInput)) {
      throw StateError(
        'Model input is ${input.type} ${input.shape}, '
        'expected float32 $expectedInput',
      );
    }
    if (!_sameShape(output.shape, expectedOutput)) {
      throw StateError(
        'Model output is ${output.shape}, expected $expectedOutput '
        '(labels.txt has $numLabels labels)',
      );
    }
  }

  static bool _sameShape(List<int> a, List<int> b) =>
      a.length == b.length &&
      Iterable.generate(a.length).every((i) => a[i] == b[i]);
}

class _RawOutput {
  const _RawOutput(this.probabilities, this.preprocessTime, this.inferenceTime);

  final Float32List probabilities;
  final Duration preprocessTime;
  final Duration inferenceTime;
}
