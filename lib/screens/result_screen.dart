import 'package:flutter/material.dart';

import '../models/classification_result.dart';
import '../models/disease_guide.dart';
import '../models/leaf_photo.dart';
import '../models/plant_label.dart';
import '../services/guide_book.dart';
import '../widgets/disease_guide_view.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.photo,
    required this.result,
    this.guides,
  });

  final LeafPhoto photo;
  final ClassificationResult result;

  /// Offline guidance; null hides the guidance section.
  final GuideBook? guides;

  /// "84.3%", or "<0.1%" for tiny values that would otherwise read as zero.
  static String percent(double v) =>
      v < 0.001 ? '<0.1%' : '${(v * 100).toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alternative = result.strongAlternative;
    final others = result.predictions.skip(1).toList();
    final totalMs =
        (result.preprocessTime + result.inferenceTime).inMilliseconds;
    final sampleLabel = photo.sampleLabel;
    final guide = guides?[result.top.label.raw];

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _VerdictCard(photo: photo, result: result, guide: guide),
            if (alternative != null) ...[
              const SizedBox(height: 12),
              _NoteCard(
                icon: Icons.compare_arrows,
                title: 'Also possible',
                text: 'It could also be ${alternative.label.displayName}, '
                    'at ${percent(alternative.confidence)}. Compare the leaf '
                    'with both before acting.',
              ),
            ],
            if (guide != null) ...[
              const SizedBox(height: 24),
              if (result.verdict == Verdict.uncertain)
                _BestGuessGuide(guide: guide, label: result.top.label)
              else ...[
                Text(
                  result.verdict == Verdict.healthy
                      ? 'Keep it healthy'
                      : 'What to do',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                DiseaseGuideView(guide: guide),
              ],
            ],
            if (others.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Other possibilities', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final p in others) _PredictionRow(p),
            ],
            if (sampleLabel != null) ...[
              const SizedBox(height: 16),
              _SampleCheck(sampleLabel: sampleLabel, top: result.top),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.offline_bolt_outlined,
                    size: 18, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Analyzed on this phone in $totalMs ms. '
                    'No internet needed.',
                    style: theme.textTheme.bodySmall,
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
          child: FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.photo_camera),
            label: Text(result.verdict == Verdict.uncertain
                ? 'Try another photo'
                : 'Scan another leaf'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          ),
        ),
      ),
    );
  }
}

/// Colors and wording for each verdict.
class _VerdictStyle {
  const _VerdictStyle({
    required this.icon,
    required this.tag,
    required this.background,
    required this.foreground,
    required this.accent,
  });

  factory _VerdictStyle.of(Verdict verdict, ThemeData theme) {
    final scheme = theme.colorScheme;
    switch (verdict) {
      case Verdict.healthy:
        return _VerdictStyle(
          icon: Icons.check_circle,
          tag: 'HEALTHY',
          background: scheme.primaryContainer,
          foreground: scheme.onPrimaryContainer,
          accent: scheme.primary,
        );
      case Verdict.diseased:
        return _VerdictStyle(
          icon: Icons.warning_rounded,
          tag: 'DISEASE DETECTED',
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
          accent: scheme.error,
        );
      case Verdict.uncertain:
        final amber = ColorScheme.fromSeed(
          seedColor: const Color(0xFFF9A825),
          brightness: theme.brightness,
        );
        return _VerdictStyle(
          icon: Icons.help_rounded,
          tag: 'NOT SURE',
          background: amber.primaryContainer,
          foreground: amber.onPrimaryContainer,
          accent: amber.primary,
        );
    }
  }

  final IconData icon;
  final String tag;
  final Color background;
  final Color foreground;
  final Color accent;

  _VerdictStyle withTag(String newTag) => _VerdictStyle(
        icon: icon,
        tag: newTag,
        background: background,
        foreground: foreground,
        accent: accent,
      );
}

/// For uncertain results: the best guess's guide, folded away behind a
/// warning so nobody sprays for a disease the leaf may not have.
class _BestGuessGuide extends StatelessWidget {
  const _BestGuessGuide({required this.guide, required this.label});

  final DiseaseGuide guide;
  final PlantLabel label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(Icons.menu_book_outlined, color: theme.colorScheme.primary),
        title: const Text('Guide for the best guess'),
        subtitle: Text(label.displayName),
        shape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            'Only follow this if the leaf clearly matches the signs below.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          DiseaseGuideView(guide: guide),
        ],
      ),
    );
  }
}

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.photo, required this.result, this.guide});

  final LeafPhoto photo;
  final ClassificationResult result;
  final DiseaseGuide? guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verdict = result.verdict;
    var style = _VerdictStyle.of(verdict, theme);
    if (verdict == Verdict.diseased && (guide?.isPest ?? false)) {
      style = style.withTag('PEST DETECTED');
    }
    final top = result.top;
    final fg = style.foreground;

    final (title, subtitle) = switch (verdict) {
      Verdict.healthy => ('Looks healthy', '${top.label.crop} leaf'),
      Verdict.diseased => (top.label.condition, '${top.label.crop} leaf'),
      Verdict.uncertain => (
          'Can\'t tell for sure',
          'Best guess: ${top.label.displayName}',
        ),
    };
    final confidenceText = switch (verdict) {
      Verdict.uncertain => 'Only ${ResultScreen.percent(top.confidence)} likely',
      _ => '${ResultScreen.percent(top.confidence)} confidence · '
          '${result.isHighConfidence ? 'High' : 'Medium'}',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox.square(
                  dimension: 104,
                  child: Image.memory(photo.bytes, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(style.icon, size: 18, color: style.accent),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            style.tag,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: fg,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(color: fg),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: top.confidence,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
            color: style.accent,
            backgroundColor: fg.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 6),
          Text(confidenceText,
              style: theme.textTheme.labelLarge?.copyWith(color: fg)),
          if (verdict == Verdict.uncertain) ...[
            const SizedBox(height: 14),
            Text(
              'This leaf may not be one of the 14 supported crops, or the '
              'photo may be unclear. Try again with:',
              style: theme.textTheme.bodyMedium?.copyWith(color: fg),
            ),
            const SizedBox(height: 6),
            for (final tip in const [
              'one leaf filling the square',
              'daylight, without strong shadows',
              'a plain background, like paper',
            ])
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('•  $tip',
                    style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
              ),
          ],
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.icon,
    required this.title,
    required this.text,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor ?? theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(text, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PredictionRow extends StatelessWidget {
  const _PredictionRow(this.prediction);

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prediction.label.displayName,
                    style: theme.textTheme.bodyLarge),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: prediction.confidence,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                  color: theme.colorScheme.secondary,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 56,
            child: Text(
              ResultScreen.percent(prediction.confidence),
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// For bundled samples: compares the expert label with the top result.
class _SampleCheck extends StatelessWidget {
  const _SampleCheck({required this.sampleLabel, required this.top});

  final String sampleLabel;
  final Prediction top;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = sampleLabel == top.label.raw;
    final expert = PlantLabel.parse(-1, sampleLabel).displayName;
    return _NoteCard(
      icon: matches ? Icons.verified_outlined : Icons.report_outlined,
      iconColor: matches ? theme.colorScheme.primary : theme.colorScheme.error,
      title: matches
          ? 'Matches the expert label'
          : 'Differs from the expert label',
      text: 'Expert label for this sample: $expert.'
          '${matches ? '' : ' The model is not always right, which is why '
              'it shows other possibilities.'}',
    );
  }
}
