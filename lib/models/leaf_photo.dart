import 'dart:typed_data';

enum PhotoSource { camera, gallery, sample }

/// A photo the user wants analyzed, kept in memory only.
class LeafPhoto {
  const LeafPhoto({
    required this.bytes,
    required this.source,
    this.sampleLabel,
  });

  /// Encoded image (JPEG/PNG) exactly as captured or picked.
  final Uint8List bytes;

  final PhotoSource source;

  /// For bundled samples: the dataset's raw label for this image, so the
  /// result screen can show what the photo actually is.
  final String? sampleLabel;
}
