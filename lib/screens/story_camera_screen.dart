import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:strik_app/controllers/story_controller.dart';
import 'package:strik_app/core/theme.dart';

class StoryCameraScreen extends StatefulWidget {
  const StoryCameraScreen({Key? key}) : super(key: key);

  @override
  State<StoryCameraScreen> createState() => _StoryCameraScreenState();
}

class _StoryCameraScreenState extends State<StoryCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  File? _capturedImage;
  final StoryController _storyController = Get.find<StoryController>();

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
      Get.snackbar(
        'Ijin Ditolak',
        'Ijin kamera diperlukan untuk mengambil story.',
      );
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
      setState(() {
        _capturedImage = File(file.path);
      });
    } catch (e) {
      print(e);
    }
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
      setState(() {
        _capturedImage = File(image.path);
      });
    }
  }

  void _uploadStory() {
    if (_capturedImage != null) {
      _storyController.uploadStoryFile(_capturedImage!);
      Get.back(); // Close camera screen
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedImage != null) {
      return _buildPreviewUI();
    }

    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview (Full Cover)
          _buildCameraPreview(),

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
                  mainAxisAlignment: MainAxisAlignment.center, // Center text
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () => Get.back(),
                        ),
                      ),
                    ),
                    const Text(
                      'Strik Stories',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                    const Spacer(), // Balance center
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery
                IconButton(
                  onPressed: _pickFromGallery,
                  icon: const Icon(
                    Icons.photo_library,
                    color: Colors.white,
                    size: 32,
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
                    Icons.cameraswitch,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;

    return Transform.scale(
      scale:
          1.0, // Standard scale, let CameraPreview handle aspect ratio letterboxing if needed or use Transform to cover
      // To strictly cover, we need complex math. Basic CameraPreview is usually fine or slightly letterboxed on long phones.
      // For a "Story" feel, usually we want to fill.
      // Simplified cover logic:
      child: Center(child: CameraPreview(_controller!)),
    );
  }

  Widget _buildPreviewUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(_capturedImage!, fit: BoxFit.cover),

          // Buttons
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Retake
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _capturedImage = null;
                    });
                  },
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text(
                    'Retake',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(backgroundColor: Colors.black54),
                ),

                // Post
                ElevatedButton.icon(
                  onPressed: _uploadStory,
                  icon: const Icon(Icons.send, color: Colors.black),
                  label: const Text(
                    'Post Story',
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
        ],
      ),
    );
  }
}
