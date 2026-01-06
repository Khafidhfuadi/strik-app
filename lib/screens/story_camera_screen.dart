import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart' show Lottie;
import 'package:permission_handler/permission_handler.dart';
import 'package:strik_app/controllers/story_controller.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/screens/story_archive_screen.dart';
import 'package:image/image.dart' as img; // Added for silent cropping
import 'package:flutter/foundation.dart'; // for compute // Added

class CropRequest {
  final File file;
  final bool mirror;

  CropRequest(this.file, {this.mirror = false});
}

class StoryCameraScreen extends StatefulWidget {
  const StoryCameraScreen({super.key});

  @override
  State<StoryCameraScreen> createState() => _StoryCameraScreenState();
}

class _StoryCameraScreenState extends State<StoryCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  bool _isPermissionDenied = false; // Added
  FlashMode _flashMode = FlashMode.off; // Added
  File? _capturedImage;
  final StoryController _storyController = Get.find<StoryController>();
  final TextEditingController _captionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _onNewCameraSelected(cameraController.description);
    }
  }

  Future<void> _initCamera() async {
    // Request permission
    var status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          _isPermissionDenied = true;
          // We can add a state variable for 'denied' if we want a custom UI,
          // but seeing the build method, let's just use `_isInitialized = false`
          // and handle it in build() by checking permission status or adding a flag.
          // For now, let's add `_isPermissionDenied` flag.
          // We need to declare it first.
        });
      }
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Find back camera first, or default
        _selectedCameraIndex = _cameras!.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
        );
        if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

        await _onNewCameraSelected(_cameras![_selectedCameraIndex]);
      }
    } catch (e) {
      print('Camera Error: $e');
    }
  }

  Future<void> _onNewCameraSelected(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high, // Good balance for stories
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.jpeg
          : ImageFormatGroup.bgra8888,
    );

    _controller = cameraController;

    try {
      await cameraController.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } on CameraException catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;

    try {
      final XFile file = await _controller!.takePicture();

      // Auto-Crop to Square 1:1
      final File rawImage = File(file.path);

      final isFront =
          _cameras![_selectedCameraIndex].lensDirection ==
          CameraLensDirection.front;
      final request = CropRequest(rawImage, mirror: isFront);

      // Run heavy image processing in a separate isolate
      final File croppedImage = await compute(_cropSquareImage, request);

      setState(() {
        _capturedImage = croppedImage;
      });
    } catch (e) {
      print(e);
    }
  }

  // Static function for isolate
  static Future<File> _cropSquareImage(CropRequest request) async {
    final imageFile = request.file;
    final bytes = await imageFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);

    if (originalImage == null) return imageFile;

    // Mirror if requested (Front Camera)
    if (request.mirror) {
      originalImage = img.flip(
        originalImage,
        direction: img.FlipDirection.horizontal,
      );
    }

    // Determine crop area (Center Square)
    final size = originalImage.width < originalImage.height
        ? originalImage.width
        : originalImage.height;

    final x = (originalImage.width - size) ~/ 2;
    final y = (originalImage.height - size) ~/ 2;

    // Crop
    final img.Image cropped = img.copyCrop(
      originalImage,
      x: x,
      y: y,
      width: size,
      height: size,
    );

    // Save back to file (overwrite or new temp?)
    // Overwriting is fine for temp capture
    final jpg = img.encodeJpg(cropped, quality: 90); // Use high quality
    await imageFile.writeAsBytes(jpg);

    return imageFile;
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.isEmpty) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    await _onNewCameraSelected(_cameras![_selectedCameraIndex]);
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (image != null) {
      final File rawImage = File(image.path);
      // Run heavy image processing in a separate isolate
      // Mirror is false for gallery
      final request = CropRequest(rawImage, mirror: false);
      final File croppedImage = await compute(_cropSquareImage, request);

      setState(() {
        _capturedImage = croppedImage;
      });
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;

    FlashMode nextMode;
    if (_flashMode == FlashMode.off) {
      nextMode = FlashMode
          .torch; // Use torch for constant light in preview, or auto/always for capture?
      // User usually expects simple On/Off or Auto.
      // Let's toggle Off -> Torch (On) -> Off for simplicity in stories?
      // Or Off -> Auto -> On -> Off.
      // Let's stick to Off -> On (Torch) -> Off for now as it's cleaner for preview.
      // Actually, camera package has setFlashMode.
    } else {
      nextMode = FlashMode.off;
    }

    try {
      await _controller!.setFlashMode(nextMode);
      setState(() {
        _flashMode = nextMode;
      });
    } catch (e) {
      print('Error toggling flash: $e');
    }
  }

  void _onSwipeUp() {
    Get.to(() => StoryArchiveScreen());
  }

  void _uploadStory() {
    if (_capturedImage != null) {
      final caption = _captionController.text.trim().isEmpty
          ? null
          : _captionController.text.trim();
      _storyController.createStory(_capturedImage!, caption: caption);
      Get.back(); // Close camera screen
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedImage != null) {
      return _buildPreviewUI();
    }

    if (_isPermissionDenied) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, color: Colors.grey, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Akses Kamera Ditolak',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aktifin dulu izin kamera di settings ya!',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => openAppSettings(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
                child: const Text(
                  'Buka Settings',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              TextButton(
                onPressed: _initCamera,
                child: const Text(
                  'Coba Lagi',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! < -500) {
            // Threshold for swipe up
            _onSwipeUp();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Camera Preview (Centered 1:1)
            Center(child: _buildCameraPreview()),

            // 2. Top Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Row(
                        children: [
                          Text(
                            'Strik Momentz',
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Lottie.asset(
                            'assets/src/strik-logo.json',
                            width: 35,
                            height: 35,
                            repeat: false,
                          ),
                        ],
                      ),

                      const Spacer(),

                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Get.back(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Bottom Controls
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Gallery
                      IconButton(
                        onPressed: _pickFromGallery,
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),

                      // Shutter Button
                      GestureDetector(
                        onTap: _takePicture,
                        child: Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),

                      // Switch Camera
                      IconButton(
                        onPressed: _switchCamera,
                        icon: const Icon(
                          Icons.flip_camera_ios_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Column(
                    children: [
                      Text(
                        'Throwback',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final size = MediaQuery.of(context).size;
    final double side = size.width - 32; // Padding 16 each side

    // Aspect Ratio 1:1
    return Container(
      width: side,
      height: side, // Square
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera Stream
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width:
                    _controller!.value.previewSize!.height, // Swap for portrait
                height: _controller!.value.previewSize!.width,
                child: Transform(
                  alignment: Alignment.center,
                  transform:
                      _cameras![_selectedCameraIndex].lensDirection ==
                          CameraLensDirection.front
                      ? Matrix4.rotationY(math.pi)
                      : Matrix4.identity(),
                  child: CameraPreview(_controller!),
                ),
              ),
            ),

            // Flash Button (Top Left)
            Positioned(
              top: 16,
              left: 16,
              child: GestureDetector(
                onTap: _toggleFlash,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _flashMode == FlashMode.off
                        ? Icons.flash_off
                        : Icons.flash_on,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

            // Zoom/Settings? (Top Right usually, or just keep it simple)

            // Simple camera shutter at bottom
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFC107), // Amber
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.black,
                      size: 16,
                    ),
                  ),
                  // Removed video icon as requested
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewUI() {
    final size = MediaQuery.of(context).size;
    final double side = size.width - 32; // Padding 16 each side

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // 1:1 Image Preview
            Container(
              width: side,
              height: side,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.file(_capturedImage!, fit: BoxFit.cover),
              ),
            ),
            // Caption Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: TextField(
                controller: _captionController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'isi dulu captionnya...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: 3,
                minLines: 1,
              ),
            ),
            const Spacer(),
            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Retake
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _capturedImage = null;
                        _captionController.clear(); // Clear caption on retake
                      });
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Retake',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),

                  // Post
                  ElevatedButton.icon(
                    onPressed: _uploadStory,
                    icon: const Icon(Icons.send, color: Colors.black),
                    label: const Text(
                      'Post Strike Momentz',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
