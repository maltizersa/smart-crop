import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'services/app_services.dart';
import 'services/guide_book.dart';
import 'services/plant_classifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The camera guide frame and photo layouts are designed for portrait.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Start loading right away so everything is ready by the first scan.
  // ignore() only stops a load failure from being reported as uncaught
  // before a screen listens; screens awaiting it still receive the error.
  runApp(SmartCropApp(
    classifier: PlantClassifier.load()..ignore(),
    guides: GuideBook.load()..ignore(),
  ));
}

class SmartCropApp extends StatelessWidget {
  const SmartCropApp({
    super.key,
    required this.classifier,
    required this.guides,
  });

  final Future<PlantClassifier> classifier;
  final Future<GuideBook> guides;

  static const _seed = Color(0xFF2E7D32); // leaf green

  @override
  Widget build(BuildContext context) {
    return AppServices(
      classifier: classifier,
      guides: guides,
      child: MaterialApp(
        title: 'SmartCrop',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _seed,
            brightness: Brightness.dark,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
