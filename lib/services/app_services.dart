import 'package:flutter/widgets.dart';

import 'guide_book.dart';
import 'plant_classifier.dart';

/// App-wide services, started once in main() and available to every screen.
/// They load in the background, so screens get futures and await them when
/// they actually need them.
class AppServices extends InheritedWidget {
  const AppServices({
    super.key,
    required this.classifier,
    required this.guides,
    required super.child,
  });

  final Future<PlantClassifier> classifier;
  final Future<GuideBook> guides;

  static AppServices of(BuildContext context) {
    final services = context.getInheritedWidgetOfExactType<AppServices>();
    assert(services != null, 'No AppServices above this widget');
    return services!;
  }

  @override
  bool updateShouldNotify(AppServices oldWidget) =>
      classifier != oldWidget.classifier || guides != oldWidget.guides;
}
