import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/sample_leaves.dart';
import '../models/leaf_photo.dart';
import '../services/app_services.dart';
import '../widgets/sample_picker_sheet.dart';
import 'camera_screen.dart';
import 'guide_library_screen.dart';
import 'photo_review_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _takePhoto() async {
    final bytes = await CameraScreen.open(context);
    if (bytes == null || !mounted) return;
    _review(LeafPhoto(bytes: bytes, source: PhotoSource.camera));
  }

  Future<void> _pickFromGallery() async {
    try {
      // Let the platform shrink big photos before they reach Dart; the model
      // only needs 224 x 224, and smaller files decode much faster.
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      _review(LeafPhoto(bytes: bytes, source: PhotoSource.gallery));
    } on PlatformException catch (e) {
      _showMessage('Could not open the gallery: ${e.message ?? e.code}');
    }
  }

  Future<void> _trySample() async {
    final sample = await showModalBottomSheet<SampleLeaf>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const SamplePickerSheet(),
    );
    if (sample == null) return;
    final data = await rootBundle.load(sample.assetPath);
    if (!mounted) return;
    _review(LeafPhoto(
      bytes: data.buffer.asUint8List(),
      source: PhotoSource.sample,
      sampleLabel: sample.label,
    ));
  }

  void _review(LeafPhoto photo) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PhotoReviewScreen(photo: photo),
    ));
  }

  void _openGuide() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const GuideLibraryScreen(),
    ));
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const buttonSize = Size.fromHeight(56);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.eco,
                    size: 30,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'SmartCrop',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Take a photo of a plant leaf to check it for diseases. '
              'Everything runs on this phone, so it works without internet.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Take a photo'),
              style: FilledButton.styleFrom(minimumSize: buttonSize),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from gallery'),
              style: OutlinedButton.styleFrom(minimumSize: buttonSize),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _trySample,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Try a sample leaf'),
            ),
            const SizedBox(height: 20),
            Card.outlined(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: _openGuide,
                leading: Icon(Icons.menu_book_outlined,
                    color: theme.colorScheme.primary),
                title: const Text('Disease guide'),
                subtitle: const Text(
                    'Signs, treatment and prevention for every condition. '
                    'Works offline.'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 12),
            const _TipsCard(),
            const SizedBox(height: 12),
            const _ModelCard(),
          ],
        ),
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  static const _tips = [
    (Icons.crop_free, 'Fill the square with one leaf, close up.'),
    (Icons.wb_sunny_outlined, 'Use daylight. Avoid strong shadows.'),
    (Icons.center_focus_strong, 'Hold steady and tap the leaf to focus.'),
    (Icons.flip_to_back, 'A plain background helps.'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tips for a good photo', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final (icon, text) in _tips)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Model status plus the crops it knows, read from the loaded labels.
class _ModelCard extends StatelessWidget {
  const _ModelCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder(
          future: AppServices.of(context).classifier,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                'The offline model failed to load: ${snapshot.error}',
                style: TextStyle(color: theme.colorScheme.error),
              );
            }
            final model = snapshot.data;
            if (model == null) {
              return const Row(
                children: [
                  Icon(Icons.hourglass_top, size: 20),
                  SizedBox(width: 12),
                  Expanded(child: Text('Loading the offline model…')),
                ],
              );
            }
            final crops = model.labels.map((l) => l.crop).toSet().toList()
              ..sort();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.offline_pin,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Offline model ready: ${model.labels.length} '
                        'conditions across ${crops.length} crops',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final crop in crops)
                      Chip(
                        label: Text(crop),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Other crops (like rice or banana) are not supported yet.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
