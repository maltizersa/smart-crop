import 'package:flutter/material.dart';

import '../models/disease_guide.dart';
import '../models/plant_label.dart';
import '../services/app_services.dart';
import '../services/guide_book.dart';
import '../widgets/disease_guide_view.dart';

/// Every condition the model knows, grouped by crop, readable offline
/// without scanning anything.
class GuideLibraryScreen extends StatelessWidget {
  const GuideLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Disease guide')),
      body: FutureBuilder<GuideBook>(
        future: AppServices.of(context).guides,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('The guide failed to load: ${snapshot.error}'),
              ),
            );
          }
          final book = snapshot.data;
          if (book == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _GuideList(book: book);
        },
      ),
    );
  }
}

class _GuideList extends StatelessWidget {
  const _GuideList({required this.book});

  final GuideBook book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // -1: these labels describe guide entries, not model outputs.
    final entries = [
      for (final guide in book.all) (PlantLabel.parse(-1, guide.label), guide),
    ];
    final byCrop = <String, List<(PlantLabel, DiseaseGuide)>>{};
    for (final entry in entries) {
      byCrop.putIfAbsent(entry.$1.crop, () => []).add(entry);
    }
    final crops = byCrop.keys.toList()..sort();
    for (final list in byCrop.values) {
      // Diseases alphabetically, healthy last.
      list.sort((a, b) {
        if (a.$2.isHealthy != b.$2.isHealthy) return a.$2.isHealthy ? 1 : -1;
        return a.$1.condition.compareTo(b.$1.condition);
      });
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            '${book.length} conditions across ${crops.length} crops. '
            'Tap one to read how to spot, treat and prevent it.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        for (final crop in crops) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              crop,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          for (final (label, guide) in byCrop[crop]!)
            ListTile(
              key: ValueKey(guide.label),
              leading: Icon(
                causeIcon(guide),
                color: guide.isHealthy
                    ? theme.colorScheme.primary
                    : guide.urgency == Urgency.high
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(label.condition),
              subtitle: Text(switch (guide) {
                DiseaseGuide(isHealthy: true) => 'Care tips',
                DiseaseGuide(urgency: Urgency.high) => '${guide.cause} · act fast',
                _ => guide.cause,
              }),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => GuideDetailScreen(label: label, guide: guide),
              )),
            ),
        ],
      ],
    );
  }
}

class GuideDetailScreen extends StatelessWidget {
  const GuideDetailScreen({super.key, required this.label, required this.guide});

  final PlantLabel label;
  final DiseaseGuide guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(label.crop)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              guide.isHealthy ? 'Healthy leaf' : label.condition,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DiseaseGuideView(guide: guide),
          ],
        ),
      ),
    );
  }
}
