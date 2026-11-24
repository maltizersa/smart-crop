import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// How pixel values are scaled before they go into the model.
enum PixelRange {
  /// value / 255. What the Kaggle model card specifies.
  zeroToOne,

  /// value / 127.5 - 1. Keras MobileNet style, kept for comparison.
  minusOneToOne,
}

/// Turns an encoded photo into the model's input: a float32 tensor of shape
/// [1, inputSize, inputSize, 3] in RGB order, flattened row by row.
///
/// Pure Dart and synchronous, so it can run inside a background isolate.
class ImagePreprocessor {
  const ImagePreprocessor({
    this.inputSize = 224,
    this.pixelRange = PixelRange.zeroToOne,
  });

  final int inputSize;
  final PixelRange pixelRange;

  /// Decode, fix rotation, center-crop, resize and normalize.
  Float32List preprocessBytes(Uint8List encoded) => toTensor(decode(encoded));

  /// Decodes JPEG/PNG/etc. and applies the EXIF orientation, so photos taken
  /// with the phone held sideways come out upright.
  img.Image decode(Uint8List encoded) {
    final decoded =
        _isJpeg(encoded) ? _decodeJpegScaled(encoded) : img.decodeImage(encoded);
    if (decoded == null) {
      throw const FormatException('Unsupported or corrupt image');
    }
    return img.bakeOrientation(decoded);
  }

  /// Largest centered square, resized to [inputSize] x [inputSize].
  /// Center-cropping (not squashing) keeps leaf lesions in proportion.
  img.Image cropAndResize(img.Image image) {
    final side = math.min(image.width, image.height);
    final square = img.copyCrop(
      image,
      x: (image.width - side) ~/ 2,
      y: (image.height - side) ~/ 2,
      width: side,
      height: side,
    );
    if (side == inputSize) return square;
    return img.copyResize(
      square,
      width: inputSize,
      height: inputSize,
      // Box-filter averaging when shrinking avoids aliasing on big photos.
      interpolation:
          side > inputSize ? img.Interpolation.average : img.Interpolation.linear,
    );
  }

  Float32List toTensor(img.Image image) {
    var resized = cropAndResize(image);
    if (resized.hasPalette ||
        resized.format != img.Format.uint8 ||
        resized.numChannels != 3) {
      resized = resized.convert(
        format: img.Format.uint8,
        numChannels: 3,
        noAnimation: true,
      );
    }
    final rgb = resized.getBytes(order: img.ChannelOrder.rgb);
    final tensor = Float32List(inputSize * inputSize * 3);
    switch (pixelRange) {
      case PixelRange.zeroToOne:
        for (var i = 0; i < tensor.length; i++) {
          tensor[i] = rgb[i] / 255.0;
        }
      case PixelRange.minusOneToOne:
        for (var i = 0; i < tensor.length; i++) {
          tensor[i] = rgb[i] / 127.5 - 1.0;
        }
    }
    return tensor;
  }

  static bool _isJpeg(Uint8List bytes) =>
      bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;

  /// Big camera JPEGs (12 MP+) are slow to decode in pure Dart. The JPEG
  /// decoder can skip detail while decoding (1/2, 1/4, 1/8 scale), so pick the
  /// largest reduction that still leaves at least 2x the model's input size.
  img.Image? _decodeJpegScaled(Uint8List bytes) {
    final info = img.JpegDecoder().startDecode(bytes);
    var scale = 1;
    if (info != null) {
      final shortSide = math.min(info.width, info.height);
      for (final s in const [8, 4, 2]) {
        if (shortSide / s >= inputSize * 2) {
          scale = s;
          break;
        }
      }
    }
    return img.decodeJpg(bytes, scale: scale);
  }
}
