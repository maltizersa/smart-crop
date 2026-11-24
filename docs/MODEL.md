# Model notes

**Source:** Kaggle model `rishitdagli/plant-disease`, TFLite variation `default`, version 1
(Rishit Dagli, Apache 2.0). It was trained on the PlantVillage dataset.

**Files in the app**

| File | What it is |
|---|---|
| `assets/models/plant_disease.tflite` | `1.tflite` from the Kaggle archive, renamed. 12,950,792 bytes. SHA-256 `ef97f1c425b68c37ec676a5555a4d2da3c36895be86e166e4ab558c65169c04f` |
| `assets/labels/labels.txt` | 38 class names, one per line. Line *i* is output index *i*. Built from `class_indices.json` in the author's GitHub release (`Rishit-dagli/Greenathon-Plant-AI` v0.1.0). |

## Tensor details (checked by reading the file with `tool/inspect_tflite.js`)

| | Name | Shape | Type |
|---|---|---|---|
| Input | `serving_default_input_2:0` | `[1, 224, 224, 3]` | float32, not quantized |
| Output | `StatefulPartitionedCall:0` | `[1, 38]` | float32 |

- The last op is **SOFTMAX**, so the output is already a set of probabilities that add up to 1.
  Kaggle's description calls it a "logits-vector", but the file itself has the softmax.
  **Do not apply softmax again in the app.**
- The graph has 14 CONV_2D, 13 DEPTHWISE_CONV_2D, 4 PAD, MEAN, FULLY_CONNECTED and SOFTMAX ops.
  It has no ADD ops, so the backbone is a MobileNet **v1** layout, although the description says v2.
  This changes nothing in the app.

## Preprocessing (what the app must do)

1. Decode the photo and apply its EXIF rotation.
2. Center-crop to a square, then resize to 224 × 224.
3. Use RGB channel order and scale each value to `[0, 1]` (pixel / 255).

## On-device check (2026-11-24)

Setup: release build on the Android emulator (Pixel 8, API 31, x86_64), using the 8 PlantVillage
leaves in `assets/samples/`. To repeat it, follow the steps at the top of
`integration_test/model_check_main.dart`.

| Pixel range | Correct | Mean top-1 confidence | Avg preprocess | Avg inference |
|---|---|---|---|---|
| **`[0, 1]` (used by the app)** | **7 / 8** | 88.5% | 6.3 ms | 50.9 ms |
| `[-1, 1]` | 6 / 8 | 87.0% | 6.1 ms | 36.2 ms |

- `[0, 1]` scores better, which matches the Kaggle model card, so the app uses it.
- Both ranges miss `tomato_early_blight.jpg`. With `[0, 1]` it comes out as *Septoria leaf spot*
  at 90.8%, and *Early blight* is second. The two diseases look alike (brown fungal spots),
  so the app shows the top 3 instead of a single answer.
- `grape_black_rot.jpg` is close: Black rot 52.2% vs Esca 47.8%.
- Eight images show that the pipeline is wired correctly. They are not an accuracy measurement.
- Timings are from an emulator. Real phones differ, so measure on the target phone in Phase 6.
- When four calls overlap, the classifier queues them and all four return the right answer.
- Model load takes about 20 ms after the first app start.

## Limits to tell users

- The model knows 14 crops: apple, blueberry, cherry, corn, grape, orange, peach, bell pepper,
  potato, raspberry, soybean, squash, strawberry and tomato. It has no "not a leaf" class,
  so it always picks one of the 38 classes, even for photos of other things.
- PlantVillage photos show single leaves on plain backgrounds. Expect lower accuracy on field photos
  with busy backgrounds.

To re-inspect the model, run `node tool/inspect_tflite.js assets/models/plant_disease.tflite`.
