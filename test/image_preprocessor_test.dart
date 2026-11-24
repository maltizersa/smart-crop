import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:smart_crop/services/image_preprocessor.dart';

/// Landscape test image: red | green | blue thirds, so a center crop keeps
/// only the green middle.
img.Image _threeStripes({int width = 600, int height = 200}) {
  final image = img.Image(width: width, height: height);
  for (final p in image) {
    final third = p.x * 3 ~/ width;
    p
      ..r = third == 0 ? 255 : 0
      ..g = third == 1 ? 255 : 0
      ..b = third == 2 ? 255 : 0;
  }
  return image;
}

/// [r, g, b] of the tensor pixel at (x, y).
List<double> _pixel(Float32List tensor, int x, int y, {int size = 224}) {
  final i = (y * size + x) * 3;
  return [tensor[i], tensor[i + 1], tensor[i + 2]];
}

void main() {
  const pre = ImagePreprocessor();

  test('output has the model input size', () {
    final tensor = pre.toTensor(_threeStripes());
    expect(tensor, hasLength(224 * 224 * 3));
  });

  test('center-crops instead of squashing', () {
    // The centered 200x200 square of a 600x200 image is all green.
    final tensor = pre.toTensor(_threeStripes());
    for (final (x, y) in [(0, 0), (112, 112), (223, 223), (0, 223)]) {
      expect(_pixel(tensor, x, y), [0.0, 1.0, 0.0], reason: '($x, $y)');
    }
  });

  test('zeroToOne keeps values in [0, 1], RGB order', () {
    final image = img.Image(width: 224, height: 224)
      ..clear(img.ColorRgb8(255, 128, 0));
    final tensor = pre.toTensor(image);
    final px = _pixel(tensor, 10, 10);
    expect(px[0], closeTo(1.0, 1e-6));
    expect(px[1], closeTo(128 / 255, 1e-6));
    expect(px[2], closeTo(0.0, 1e-6));
  });

  test('minusOneToOne maps 0..255 to -1..1', () {
    const alt = ImagePreprocessor(pixelRange: PixelRange.minusOneToOne);
    final image = img.Image(width: 224, height: 224)
      ..clear(img.ColorRgb8(255, 0, 0));
    final px = _pixel(alt.toTensor(image), 5, 5);
    expect(px[0], closeTo(1.0, 1e-6));
    expect(px[1], closeTo(-1.0, 1e-6));
  });

  test('handles images with alpha and upscales small images', () {
    final small = img.Image(width: 50, height: 80, numChannels: 4)
      ..clear(img.ColorRgba8(0, 0, 255, 128));
    final tensor = pre.toTensor(small);
    expect(tensor, hasLength(224 * 224 * 3));
    expect(_pixel(tensor, 100, 100), [0.0, 0.0, 1.0]);
  });

  test('decodes JPEG and PNG bytes end to end', () {
    final source = _threeStripes(width: 900, height: 300);
    for (final bytes in [img.encodePng(source), img.encodeJpg(source, quality: 95)]) {
      final tensor = pre.preprocessBytes(bytes);
      final center = _pixel(tensor, 112, 112);
      expect(center[0], lessThan(0.1));
      expect(center[1], greaterThan(0.9));
      expect(center[2], lessThan(0.1));
    }
  });

  test('large JPEGs decode at reduced scale but stay correct', () {
    // 2400x1800: short side 1800 / 4 = 450 >= 448, so it decodes at 1/4.
    final big = _threeStripes(width: 2400, height: 1800);
    final decoded = pre.decode(img.encodeJpg(big, quality: 90));
    expect(decoded.width, 600);
    expect(decoded.height, 450);
  });

  test('applies EXIF orientation before cropping', () {
    // Stored as 600x200 landscape, EXIF says rotate 90 degrees: upright it is
    // 200x600 portrait, and the center crop is still the green middle third.
    final stored = _threeStripes();
    stored.exif.imageIfd.orientation = 6;
    final decoded = pre.decode(img.encodeJpg(stored, quality: 95));
    expect(decoded.width, 200);
    expect(decoded.height, 600);
  });

  test('rejects bytes that are not an image', () {
    expect(
      () => pre.preprocessBytes(Uint8List.fromList(List.filled(64, 7))),
      throwsFormatException,
    );
  });
}
