import 'package:flutter/material.dart';

import '../data/sample_leaves.dart';
import '../models/plant_label.dart';

/// Bottom sheet listing the bundled sample leaves; pops the chosen one.
class SamplePickerSheet extends StatelessWidget {
  const SamplePickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sample leaves', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Photos from the PlantVillage dataset, labeled by experts. '
                    'Try one to see how SmartCrop works.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: sampleLeaves.length,
                itemBuilder: (context, i) => _SampleTile(sampleLeaves[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SampleTile extends StatelessWidget {
  const _SampleTile(this.sample);

  final SampleLeaf sample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // -1: this label only describes the photo, it is not a model output.
    final label = PlantLabel.parse(-1, sample.label);
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(sample),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.asset(sample.assetPath, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.crop, style: theme.textTheme.titleSmall),
                  Text(
                    label.condition,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
