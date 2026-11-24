import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_crop/models/disease_guide.dart';
import 'package:smart_crop/models/plant_label.dart';
import 'package:smart_crop/services/guide_book.dart';

void main() {
  late GuideBook book;
  late List<PlantLabel> labels;

  setUpAll(() {
    book = GuideBook.parse(File(GuideBook.asset).readAsStringSync());
    labels = PlantLabel.parseLabelsFile(
      File('assets/labels/labels.txt').readAsStringSync(),
    );
  });

  test('every model label has a guide, and nothing else does', () {
    expect(book.length, labels.length);
    for (final label in labels) {
      expect(book[label.raw], isNotNull, reason: label.raw);
    }
  });

  test('disease guides are complete', () {
    for (final guide in book.all.where((g) => !g.isHealthy)) {
      expect(guide.symptoms.length, greaterThanOrEqualTo(2), reason: guide.label);
      expect(guide.actions.length, greaterThanOrEqualTo(2), reason: guide.label);
      expect(guide.prevention, isNotEmpty, reason: guide.label);
      expect(guide.pathogen, isNotNull, reason: guide.label);
      expect(guide.urgency, isNot(Urgency.none), reason: guide.label);
    }
  });

  test('healthy guides give habits, not symptoms', () {
    final healthy = book.all.where((g) => g.isHealthy).toList();
    expect(healthy, hasLength(labels.where((l) => l.isHealthy).length));
    for (final guide in healthy) {
      expect(guide.symptoms, isEmpty, reason: guide.label);
      expect(guide.prevention, isNotEmpty, reason: guide.label);
      expect(guide.urgency, Urgency.none, reason: guide.label);
    }
  });

  test('high urgency always explains why', () {
    final urgent = book.all.where((g) => g.urgency == Urgency.high).toList();
    expect(urgent, isNotEmpty);
    for (final guide in urgent) {
      expect(guide.urgencyNote, isNotNull, reason: guide.label);
    }
  });

  test('crops the model knows only one class for carry a warning note', () {
    final classesPerCrop = <String, int>{};
    for (final label in labels) {
      classesPerCrop.update(label.crop, (n) => n + 1, ifAbsent: () => 1);
    }
    final singleClassCrops =
        classesPerCrop.entries.where((e) => e.value == 1).map((e) => e.key);
    expect(singleClassCrops.toSet(),
        {'Blueberry', 'Orange', 'Raspberry', 'Soybean', 'Squash'});
    for (final label in labels.where((l) => singleClassCrops.contains(l.crop))) {
      expect(book[label.raw]!.note, isNotNull, reason: label.raw);
    }
  });

  test('spider mites are flagged as a pest, not a disease', () {
    expect(book['Tomato___Spider_mites Two-spotted_spider_mite']!.isPest, isTrue);
    expect(book['Tomato___Early_blight']!.isPest, isFalse);
  });

  test('invalid guide data fails loudly', () {
    expect(
      () => GuideBook.parse('{"guides": {"X___y": {"cause": "Fungus"}}}'),
      throwsFormatException,
    );
    expect(
      () => GuideBook.parse('{"guides": {"X___y": {"cause": "Fungus", '
          '"urgency": "extreme", "summary": "s", "symptoms": [], '
          '"actions": [], "prevention": []}}}'),
      throwsFormatException,
    );
  });
}
