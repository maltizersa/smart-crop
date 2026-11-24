/// Leaf photos bundled in assets/samples/, taken from the PlantVillage
/// dataset (github.com/spMohanty/PlantVillage-Dataset). They let people try
/// the app without a sick plant at hand, and the on-device model check uses
/// them too.
class SampleLeaf {
  const SampleLeaf(this.fileName, this.label);

  final String fileName;

  /// The dataset's raw label for this photo, as written in labels.txt.
  final String label;

  String get assetPath => 'assets/samples/$fileName';
}

const sampleLeaves = <SampleLeaf>[
  SampleLeaf('apple_scab.jpg', 'Apple___Apple_scab'),
  SampleLeaf('bell_pepper_bacterial_spot.jpg', 'Pepper_bell___Bacterial_spot'),
  SampleLeaf('corn_common_rust.jpg', 'Corn_(maize)___Common_rust_'),
  SampleLeaf('grape_black_rot.jpg', 'Grape___Black_rot'),
  SampleLeaf('potato_late_blight.jpg', 'Potato___Late_blight'),
  SampleLeaf('tomato_early_blight.jpg', 'Tomato___Early_blight'),
  SampleLeaf('tomato_healthy.jpg', 'Tomato___healthy'),
  SampleLeaf(
    'tomato_yellow_leaf_curl_virus.jpg',
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
  ),
];
