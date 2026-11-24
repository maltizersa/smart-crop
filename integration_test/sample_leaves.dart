import 'package:smart_crop/data/sample_leaves.dart' as samples;

/// Bundled sample file name -> the label the model should predict.
final sampleLeaves = {
  for (final s in samples.sampleLeaves) s.fileName: s.label,
};
