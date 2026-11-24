import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/crop_guide_overlay.dart';

/// Full-screen camera with a square guide showing what the model will see.
/// Pops with the captured JPEG bytes, or null if the user backs out.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  static Future<Uint8List?> open(BuildContext context) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
  }

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _starting = false;
  bool _releasedForBackground = false;
  String? _error;
  bool _capturing = false;
  bool _torchOn = false;
  Offset? _focusRing;
  Timer? _focusRingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusRingTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the camera while the app is in the background so other apps
    // can use it, and reopen it on return. Lifecycle changes caused by the
    // permission dialog (while starting) are ignored.
    final controller = _controller;
    if (state == AppLifecycleState.inactive) {
      if (controller == null || !controller.value.isInitialized) return;
      _releasedForBackground = true;
      setState(() => _controller = null);
      controller.dispose();
    } else if (state == AppLifecycleState.resumed && _releasedForBackground) {
      _releasedForBackground = false;
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    if (_starting) return;
    _starting = true;
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _setError('No camera was found on this phone. '
            'You can choose a photo from the gallery instead.');
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        camera,
        // 720p is plenty: the model looks at a 224 x 224 square.
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller.setFlashMode(FlashMode.off);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _torchOn = false;
        _error = null;
      });
    } on CameraException catch (e) {
      await controller?.dispose();
      _setError(e.code.startsWith('CameraAccess')
          ? 'Camera permission is off. To take photos, allow Camera for '
              'SmartCrop in Settings > Apps > SmartCrop > Permissions. '
              'You can still choose a photo from the gallery.'
          : 'Could not start the camera: ${e.description ?? e.code}');
    } finally {
      _starting = false;
    }
  }

  void _setError(String message) {
    if (mounted) setState(() => _error = message);
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      // Keep photos in memory only; remove the camera's temporary file.
      File(file.path).delete().ignore();
      if (mounted) Navigator.of(context).pop(bytes);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not take the photo: ${e.description ?? e.code}'),
      ));
    }
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null) return;
    final on = !_torchOn;
    try {
      await controller.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torchOn = on);
    } on CameraException {
      // Some phones have no flash; leave the button as it was.
    }
  }

  void _focusAt(Offset position, Size previewSize) {
    final controller = _controller;
    if (controller == null) return;
    final point = Offset(
      (position.dx / previewSize.width).clamp(0.0, 1.0),
      (position.dy / previewSize.height).clamp(0.0, 1.0),
    );
    if (controller.value.focusPointSupported) {
      controller.setFocusPoint(point).ignore();
    }
    if (controller.value.exposurePointSupported) {
      controller.setExposurePoint(point).ignore();
    }
    setState(() => _focusRing = position);
    _focusRingTimer?.cancel();
    _focusRingTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _focusRing = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              torchOn: _torchOn,
              onToggleTorch: _controller == null ? null : _toggleTorch,
            ),
            Expanded(child: Center(child: _buildPreview())),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Text(
                'Fit one leaf inside the square. Tap the leaf to focus.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: _ShutterButton(
                busy: _capturing,
                onPressed: _controller == null ? null : _capture,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_error != null) {
      return _CameraMessage(
        message: _error!,
        onRetry: () {
          setState(() => _error = null);
          _startCamera();
        },
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    return CameraPreview(
      controller,
      child: LayoutBuilder(
        builder: (context, box) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _focusAt(d.localPosition, box.biggest),
          child: Stack(
            children: [
              const Positioned.fill(child: CropGuideOverlay()),
              if (_focusRing case final ring?)
                Positioned(
                  left: ring.dx - 32,
                  top: ring.dy - 32,
                  child: IgnorePointer(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.torchOn, required this.onToggleTorch});

  final bool torchOn;
  final VoidCallback? onToggleTorch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          const Spacer(),
          IconButton(
            tooltip: torchOn ? 'Turn light off' : 'Turn light on',
            onPressed: onToggleTorch,
            icon: Icon(
              torchOn ? Icons.flashlight_on : Icons.flashlight_off,
              color: torchOn ? Colors.amber : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Take photo',
      child: GestureDetector(
        onTap: busy ? null : onPressed,
        child: Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onPressed == null ? Colors.white24 : Colors.white,
            ),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _CameraMessage extends StatelessWidget {
  const _CameraMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined,
              color: Colors.white70, size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Back'),
              ),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ],
      ),
    );
  }
}
