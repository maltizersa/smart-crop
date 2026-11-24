import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:smart_crop/data/sample_leaves.dart';
import 'package:smart_crop/models/classification_result.dart';
import 'package:smart_crop/models/leaf_photo.dart';
import 'package:smart_crop/models/plant_label.dart';
import 'package:smart_crop/screens/guide_library_screen.dart';
import 'package:smart_crop/screens/home_screen.dart';
import 'package:smart_crop/screens/photo_review_screen.dart';
import 'package:smart_crop/screens/result_screen.dart';
import 'package:smart_crop/services/app_services.dart';
import 'package:smart_crop/services/guide_book.dart';
import 'package:smart_crop/services/plant_classifier.dart';
import 'package:smart_crop/widgets/disease_guide_view.dart';

// The real classifier needs the native TFLite library, which only exists on
// a device. These tests cover the screens with a classifier that never loads
// (or fails); the model itself is checked on-device (integration_test/).
Future<T> _pending<T>() => Completer<T>().future;

final Uint8List _png = img.encodePng(img.Image(width: 8, height: 8));

final GuideBook _guides =
    GuideBook.parse(File(GuideBook.asset).readAsStringSync());

Widget _app(
  Widget home, {
  Future<PlantClassifier>? classifier,
  Future<GuideBook>? guides,
}) {
  return AppServices(
    classifier: classifier ?? _pending(),
    guides: guides ?? _pending(),
    child: MaterialApp(home: home),
  );
}

/// testWidgets on a phone-sized screen (1080 x 2400 px at 2.625x, about
/// 411 x 914 dp) so lists build their lower items like on a real phone.
void phoneTest(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await body(tester);
  });
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 300,
        scrollable: find.byType(Scrollable).first);

ClassificationResult _result(List<(String, double)> scores) {
  return ClassificationResult(
    predictions: [
      for (final (i, (raw, p)) in scores.indexed)
        Prediction(PlantLabel.parse(i, raw), p),
    ],
    preprocessTime: const Duration(milliseconds: 6),
    inferenceTime: const Duration(milliseconds: 40),
  );
}

void main() {
  group('HomeScreen', () {
    phoneTest('offers camera, gallery, samples and the guide', (tester) async {
      await tester.pumpWidget(_app(const HomeScreen()));

      expect(find.text('SmartCrop'), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(find.text('Try a sample leaf'), findsOneWidget);
      expect(find.text('Disease guide'), findsOneWidget);
      expect(find.text('Tips for a good photo'), findsOneWidget);
      await _scrollTo(tester, find.text('Loading the offline model…'));
    });

    phoneTest('shows a model load failure', (tester) async {
      // Same as main(): ignore() keeps the failure from counting as uncaught
      // before the model card subscribes; the card still receives it.
      final failing = Future<PlantClassifier>.error(StateError('bad model'))
        ..ignore();
      await tester.pumpWidget(_app(const HomeScreen(), classifier: failing));
      await tester.pump();

      await _scrollTo(tester, find.textContaining('failed to load'));
      expect(find.textContaining('bad model'), findsOneWidget);
    });

    phoneTest('sample sheet lists the bundled samples', (tester) async {
      await tester.pumpWidget(_app(const HomeScreen()));
      await tester.tap(find.text('Try a sample leaf'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Sample leaves'), findsOneWidget);
      expect(find.text('Apple scab'), findsOneWidget);
      expect(sampleLeaves, hasLength(8));
    });
  });

  group('PhotoReviewScreen', () {
    phoneTest('camera photo offers retake and analyze', (tester) async {
      await tester.pumpWidget(_app(PhotoReviewScreen(
        photo: LeafPhoto(bytes: _png, source: PhotoSource.camera),
      )));

      expect(find.text('Retake'), findsOneWidget);
      expect(find.text('Analyze'), findsOneWidget);
    });

    phoneTest('analyze shows progress while the model works', (tester) async {
      await tester.pumpWidget(_app(PhotoReviewScreen(
        photo: LeafPhoto(bytes: _png, source: PhotoSource.gallery),
      )));
      expect(find.text('Choose another'), findsOneWidget);

      await tester.tap(find.text('Analyze'));
      await tester.pump();

      expect(find.text('Analyzing…'), findsOneWidget);
    });
  });

  group('ResultScreen', () {
    Future<void> showResult(
      WidgetTester tester,
      List<(String, double)> scores, {
      String? sampleLabel,
      GuideBook? guides,
    }) {
      return tester.pumpWidget(_app(ResultScreen(
        photo: LeafPhoto(
          bytes: _png,
          source: sampleLabel == null ? PhotoSource.camera : PhotoSource.sample,
          sampleLabel: sampleLabel,
        ),
        result: _result(scores),
        guides: guides,
      )));
    }

    phoneTest('clear disease result', (tester) async {
      await showResult(tester, [
        ('Tomato___Early_blight', 0.91),
        ('Tomato___Septoria_leaf_spot', 0.06),
        ('Tomato___healthy', 0.03),
      ]);

      expect(find.text('DISEASE DETECTED'), findsOneWidget);
      expect(find.text('Early blight'), findsOneWidget);
      expect(find.text('Tomato leaf'), findsOneWidget);
      expect(find.text('91.0% confidence · High'), findsOneWidget);
      expect(find.text('Also possible'), findsNothing);
      expect(find.text('Other possibilities'), findsOneWidget);
      expect(find.text('Tomato: Septoria leaf spot'), findsOneWidget);
      expect(find.textContaining('46 ms'), findsOneWidget);
      expect(find.text('Scan another leaf'), findsOneWidget);
    });

    phoneTest('healthy result', (tester) async {
      await showResult(tester, [
        ('Potato___healthy', 0.7),
        ('Potato___Early_blight', 0.27),
        ('Potato___Late_blight', 0.03),
      ]);

      expect(find.text('HEALTHY'), findsOneWidget);
      expect(find.text('Looks healthy'), findsOneWidget);
      expect(find.text('Potato leaf'), findsOneWidget);
      expect(find.text('70.0% confidence · Medium'), findsOneWidget);
      // 27% runner-up is worth a mention.
      expect(find.text('Also possible'), findsOneWidget);
      expect(find.textContaining('Potato: Early blight, at 27.0%'),
          findsOneWidget);
    });

    phoneTest('uncertain result with sample check', (tester) async {
      await showResult(
        tester,
        [
          ('Grape___Black_rot', 0.52),
          ('Grape___Esca_(Black_Measles)', 0.47),
          ('Tomato___Septoria_leaf_spot', 0.01),
        ],
        sampleLabel: 'Grape___Black_rot',
      );

      expect(find.text('NOT SURE'), findsOneWidget);
      expect(find.text("Can't tell for sure"), findsOneWidget);
      expect(find.text('Best guess: Grape: Black rot'), findsOneWidget);
      expect(find.text('Only 52.0% likely'), findsOneWidget);
      expect(find.textContaining('14 supported crops'), findsOneWidget);
      expect(find.text('Also possible'), findsOneWidget);
      expect(find.text('Try another photo'), findsOneWidget);

      await _scrollTo(tester, find.text('Matches the expert label'));
      expect(find.textContaining('Expert label for this sample: Grape: Black rot'),
          findsOneWidget);
    });

    test('percent never shows a misleading 0.0%', () {
      expect(ResultScreen.percent(0.9081), '90.8%');
      expect(ResultScreen.percent(0.001), '0.1%');
      expect(ResultScreen.percent(0.00004), '<0.1%');
    });

    phoneTest('sample that the model gets wrong says so', (tester) async {
      await showResult(
        tester,
        [
          ('Tomato___Septoria_leaf_spot', 0.908),
          ('Tomato___Early_blight', 0.046),
          ('Tomato___Leaf_Mold', 0.042),
        ],
        sampleLabel: 'Tomato___Early_blight',
      );

      await _scrollTo(tester, find.text('Differs from the expert label'));
      expect(find.textContaining('not always right'), findsOneWidget);
    });
  });

  group('ResultScreen guidance', () {
    Future<void> showResult(
      WidgetTester tester,
      List<(String, double)> scores,
    ) {
      return tester.pumpWidget(_app(ResultScreen(
        photo: LeafPhoto(bytes: _png, source: PhotoSource.camera),
        result: _result(scores),
        guides: _guides,
      )));
    }

    phoneTest('disease result shows what to do and prevention',
        (tester) async {
      await showResult(tester, [
        ('Tomato___Septoria_leaf_spot', 0.9),
        ('Tomato___Early_blight', 0.05),
        ('Tomato___Leaf_Mold', 0.05),
      ]);

      expect(find.text('What to do'), findsOneWidget);
      await _scrollTo(tester, find.text('What to do now'));
      expect(find.text('Remove infected lower leaves'), findsOneWidget);
      await _scrollTo(tester, find.text('Prevent it next time'));
      await _scrollTo(tester, find.text(DiseaseGuideView.disclaimer));
    });

    phoneTest('urgent disease shows an act-now banner', (tester) async {
      await showResult(tester, [
        ('Potato___Late_blight', 0.95),
        ('Potato___Early_blight', 0.04),
        ('Potato___healthy', 0.01),
      ]);

      await _scrollTo(tester, find.textContaining('Act today'));
    });

    phoneTest('healthy result shows good habits', (tester) async {
      await showResult(tester, [
        ('Corn_(maize)___healthy', 0.97),
        ('Corn_(maize)___Common_rust_', 0.02),
        ('Corn_(maize)___Northern_Leaf_Blight', 0.01),
      ]);

      expect(find.text('Keep it healthy'), findsOneWidget);
      await _scrollTo(tester, find.text('Good habits'));
      expect(find.text('Rotate corn with other crops'), findsOneWidget);
      expect(find.text('What to do now'), findsNothing);
    });

    phoneTest('pest result is labeled as a pest', (tester) async {
      await showResult(tester, [
        ('Tomato___Spider_mites Two-spotted_spider_mite', 0.88),
        ('Tomato___Target_Spot', 0.1),
        ('Tomato___healthy', 0.02),
      ]);

      expect(find.text('PEST DETECTED'), findsOneWidget);
      expect(find.text('DISEASE DETECTED'), findsNothing);
    });

    phoneTest('uncertain result folds the best-guess guide away',
        (tester) async {
      await showResult(tester, [
        ('Grape___Black_rot', 0.52),
        ('Grape___Esca_(Black_Measles)', 0.47),
        ('Tomato___Septoria_leaf_spot', 0.01),
      ]);

      await _scrollTo(tester, find.text('Guide for the best guess'));
      expect(find.text('What to do now'), findsNothing);

      await tester.tap(find.text('Guide for the best guess'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Only follow this'), findsOneWidget);
    });
  });

  group('GuideLibraryScreen', () {
    phoneTest('lists crops and opens a condition', (tester) async {
      await tester.pumpWidget(_app(
        const GuideLibraryScreen(),
        guides: Future.value(_guides),
      ));
      await tester.pump();

      expect(find.textContaining('38 conditions across 14 crops'),
          findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);

      final potatoLateBlight = find.byKey(const ValueKey('Potato___Late_blight'));
      await _scrollTo(tester, potatoLateBlight);
      await tester.tap(potatoLateBlight);
      await tester.pumpAndSettle();

      expect(find.text('Potato'), findsOneWidget); // detail app bar
      expect(find.textContaining('Act today'), findsOneWidget);
    });
  });
}
