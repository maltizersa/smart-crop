import 'package:flutter/material.dart';

import '../models/leaf_photo.dart';
import '../services/app_services.dart';
import '../services/guide_book.dart';
import 'result_screen.dart';

/// Shows the exact square the model will analyze before running it.
class PhotoReviewScreen extends StatefulWidget {
  const PhotoReviewScreen({super.key, required this.photo});

  final LeafPhoto photo;

  @override
  State<PhotoReviewScreen> createState() => _PhotoReviewScreenState();
}

class _PhotoReviewScreenState extends State<PhotoReviewScreen> {
  bool _analyzing = false;

  Future<void> _analyze() async {
    setState(() => _analyzing = true);
    final services = AppServices.of(context);
    try {
      final classifier = await services.classifier;
      final result = await classifier.classifyBytes(widget.photo.bytes);
      // The result is still useful without guidance, so a guide that failed
      // to load only hides that section.
      final guides =
          await services.guides.then<GuideBook?>((g) => g, onError: (_) => null);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          photo: widget.photo,
          result: result,
          guides: guides,
        ),
      ));
    } on FormatException {
      _fail('This file could not be read as an image. Try another photo.');
    } catch (e) {
      _fail('Analysis failed: $e');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _analyzing = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retakeLabel = switch (widget.photo.source) {
      PhotoSource.camera => 'Retake',
      PhotoSource.gallery || PhotoSource.sample => 'Choose another',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Check the photo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1,
                // BoxFit.cover in a square shows the same centered square
                // the preprocessor crops, so this is what the model sees.
                child: Image.memory(widget.photo.bytes, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SmartCrop analyzes only this square. Make sure one leaf '
                    'fills most of it and is sharp.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _analyzing ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.replay),
                  label: Text(retakeLabel),
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _analyzing ? null : _analyze,
                  icon: _analyzing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.biotech),
                  label: Text(_analyzing ? 'Analyzing…' : 'Analyze'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
