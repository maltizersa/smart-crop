import 'package:flutter/material.dart';

import '../models/disease_guide.dart';

/// Icon for the kind of cause (fungus, virus, pest...).
IconData causeIcon(DiseaseGuide guide) {
  final cause = guide.cause.toLowerCase();
  if (guide.isHealthy) return Icons.eco_outlined;
  if (cause.startsWith('pest')) return Icons.bug_report_outlined;
  if (cause.startsWith('virus')) return Icons.coronavirus_outlined;
  if (cause.startsWith('bacter')) return Icons.bubble_chart_outlined;
  if (cause.startsWith('water mold')) return Icons.water_drop_outlined;
  return Icons.grass; // fungi
}

/// The offline guidance for one condition: urgency, cause, what to do and
/// how to prevent it. Used on the result screen and in the disease library.
class DiseaseGuideView extends StatelessWidget {
  const DiseaseGuideView({super.key, required this.guide});

  static const disclaimer =
      'General guidance, not a lab diagnosis. For sprays, follow the product '
      'label and local rules, and ask your Municipal Agriculture Office if '
      'you are unsure.';

  final DiseaseGuide guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final healthy = guide.isHealthy;
    final urgencyNote = guide.urgencyNote;
    final note = guide.note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (guide.urgency == Urgency.high && urgencyNote != null) ...[
          _Banner(
            icon: Icons.priority_high_rounded,
            text: urgencyNote,
            background: theme.colorScheme.error,
            foreground: theme.colorScheme.onError,
          ),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Icon(causeIcon(guide), size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: healthy ? 'Healthy leaf' : 'Cause: ${guide.cause}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (guide.pathogen case final pathogen?)
                      TextSpan(
                        text: '  ($pathogen)',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(guide.summary, style: theme.textTheme.bodyLarge),
        if (guide.symptoms.isNotEmpty)
          _Section(
            icon: Icons.search,
            title: 'Signs to look for',
            items: guide.symptoms,
          ),
        _Section(
          icon: healthy ? Icons.visibility_outlined : Icons.task_alt,
          title: healthy ? 'Keep watching' : 'What to do now',
          items: guide.actions,
          numbered: !healthy,
        ),
        _Section(
          icon: Icons.shield_outlined,
          title: healthy ? 'Good habits' : 'Prevent it next time',
          items: guide.prevention,
        ),
        if (note != null) ...[
          const SizedBox(height: 16),
          _Banner(
            icon: Icons.info_outline,
            text: note,
            background: theme.colorScheme.secondaryContainer,
            foreground: theme.colorScheme.onSecondaryContainer,
          ),
        ],
        if (!healthy) ...[
          const SizedBox(height: 16),
          Text(disclaimer, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.items,
    this.numbered = false,
  });

  final IconData icon;
  final String title;
  final List<String> items;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Flexible(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 8),
          for (final (i, item) in items.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: numbered
                        ? CircleAvatar(
                            radius: 11,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              '${i + 1}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text('•', style: theme.textTheme.bodyLarge),
                          ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(item, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
