import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_crop/models/plant_label.dart';

void main() {
  late List<PlantLabel> labels;

  setUpAll(() {
    labels = PlantLabel.parseLabelsFile(
      File('assets/labels/labels.txt').readAsStringSync(),
    );
  });

  test('labels.txt has the 38 classes in model output order', () {
    expect(labels, hasLength(38));
    for (var i = 0; i < labels.length; i++) {
      expect(labels[i].index, i);
    }
    expect(labels.first.raw, 'Apple___Apple_scab');
    expect(labels.last.raw, 'Tomato___healthy');
  });

  test('covers 14 crops, 12 of them with a healthy class', () {
    expect(labels.map((l) => l.crop).toSet(), hasLength(14));
    expect(labels.where((l) => l.isHealthy), hasLength(12));
  });

  test('every display name is clean', () {
    for (final label in labels) {
      expect(label.crop, isNot(contains('_')), reason: label.raw);
      expect(label.condition, isNot(contains('_')), reason: label.raw);
      expect(label.condition.trim(), label.condition, reason: label.raw);
      expect(label.condition[0], label.condition[0].toUpperCase());
    }
  });

  test('parses generic and overridden names', () {
    final byRaw = {for (final l in labels) l.raw: l};
    expect(byRaw['Tomato___Early_blight']!.crop, 'Tomato');
    expect(byRaw['Tomato___Early_blight']!.condition, 'Early blight');
    expect(byRaw['Corn_(maize)___Common_rust_']!.condition, 'Common rust');
    expect(byRaw['Corn_(maize)___Northern_Leaf_Blight']!.crop, 'Corn');
    expect(
      byRaw['Corn_(maize)___Northern_Leaf_Blight']!.condition,
      'Northern leaf blight',
    );
    expect(byRaw['Pepper_bell___Bacterial_spot']!.crop, 'Bell pepper');
    expect(
      byRaw['Orange___Haunglongbing_(Citrus_greening)']!.condition,
      'Huanglongbing (citrus greening)',
    );
    expect(byRaw['Potato___healthy']!.isHealthy, isTrue);
    expect(byRaw['Potato___Late_blight']!.isHealthy, isFalse);
  });

  test('rejects malformed labels', () {
    expect(() => PlantLabel.parse(0, 'Tomato_Early_blight'), throwsFormatException);
    expect(() => PlantLabel.parse(0, '___healthy'), throwsFormatException);
  });

  test('ignores blank lines and Windows line endings', () {
    final parsed = PlantLabel.parseLabelsFile('A___healthy\r\n\r\nB___Rust\r\n');
    expect(parsed.map((l) => l.raw), ['A___healthy', 'B___Rust']);
    expect(parsed[1].index, 1);
  });
}
