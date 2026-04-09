import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'face_recognition_service.dart';
import 'face_image_service.dart';

class CaregiverAddFaceScreen extends StatefulWidget {
  final String patientUid;
  final String patientName;

  const CaregiverAddFaceScreen({
    super.key,
    required this.patientUid,
    required this.patientName,
  });

  @override
  State<CaregiverAddFaceScreen> createState() => _CaregiverAddFaceScreenState();
}

class _CaregiverAddFaceScreenState extends State<CaregiverAddFaceScreen> {
  CameraController? _controller;
  late FaceDetector _faceDetector;

  bool _isDetecting = false;
  bool _faceDetected = false;
  bool _isProcessing = false;
  bool _isCaptured = false;

  Face? _detectedFace;
  CameraImage? _lastImage;
  List<double>? _capturedEmbedding;
  String? _capturedImagePath;

  @override
  void initState() {
    super.initState();
    _initializeFaceDetection();
    FaceRecognitionService.initialize();
    _initializeCamera();
  }

  void _initializeFaceDetection() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableContours: true,
        enableClassification: true,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Aucune camera trouvee"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      CameraDescription? frontCamera;
      try {
        frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        );
      } catch (e) {
        frontCamera = cameras.first;
      }

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      await Future.delayed(const Duration(milliseconds: 500));

      await _controller!.startImageStream((CameraImage image) async {
        if (_isDetecting || _isProcessing || _isCaptured) return;

        _isDetecting = true;

        try {
          _lastImage = image;

          final inputImage = _convertCameraImage(image);

          if (inputImage != null) {
            final faces = await _faceDetector.processImage(inputImage);

            if (mounted) {
              setState(() {
                _faceDetected = faces.isNotEmpty;
                _detectedFace = faces.isNotEmpty ? faces.first : null;
              });
            }
          }
        } catch (e) {
        } finally {
          _isDetecting = false;
        }
      });

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur camera: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }

      final bytes = allBytes.done().buffer.asUint8List();

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation270deg,
          format: InputImageFormat.yuv420,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  img.Image? _convertToImgImage(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;
      final imgImage = img.Image(width, height);

      final yPlane = image.planes[0].bytes;
      final uPlane = image.planes[1].bytes;
      final vPlane = image.planes[2].bytes;

      final uvRowStride = image.planes[1].bytesPerRow;
      final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yIndex = y * width + x;
          final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

          final yValue = yPlane[yIndex];
          final uValue = uPlane[uvIndex];
          final vValue = vPlane[uvIndex];

          final r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
          final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
              .round()
              .clamp(0, 255);
          final b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);

          imgImage.setPixelRgba(x, y, r, g, b, 255);
        }
      }

      return imgImage;
    } catch (e) {
      return null;
    }
  }

  Future<void> _captureFace() async {
    if (_isProcessing) return;

    if (_lastImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Aucune image capturee. Reessayez."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final fullImage = _convertToImgImage(_lastImage!);
      if (fullImage == null) {
        _showError("Erreur de conversion d'image");
        setState(() => _isProcessing = false);
        return;
      }

      img.Image faceImage;

      if (_detectedFace != null) {
        final box = _detectedFace!.boundingBox;
        final x = box.left.toInt().clamp(0, fullImage.width - 1);
        final y = box.top.toInt().clamp(0, fullImage.height - 1);
        final w = box.width.toInt().clamp(1, fullImage.width - x);
        final h = box.height.toInt().clamp(1, fullImage.height - y);

        faceImage = img.copyCrop(fullImage, x, y, w, h);
      } else {
        faceImage = fullImage;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Visage non detecte. Traitement en cours..."),
            backgroundColor: Colors.orange,
          ),
        );
      }

      final embedding = FaceRecognitionService.extractEmbedding(faceImage);

      if (embedding == null) {
        _showError("Impossible d'extraire les caracteristiques du visage");
        setState(() => _isProcessing = false);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final faceId = DateTime.now().millisecondsSinceEpoch.toString();
      final imagePath = '${tempDir.path}/face_$faceId.jpg';
      final file = File(imagePath);
      file.writeAsBytesSync(img.encodeJpg(faceImage, quality: 85));

      setState(() {
        _capturedEmbedding = embedding;
        _capturedImagePath = imagePath;
        _isCaptured = true;
        _isProcessing = false;
      });

      _showNameDialog(embedding, imagePath);
    } catch (e) {
      _showError("Erreur: $e");
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _showNameDialog(List<double> embedding, String imagePath) async {
    final nameController = TextEditingController();
    final relationController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_add, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Enregistrer ce proche',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Nom du proche",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person, color: Color(0xFF4A90E2)),
                  filled: true,
                  fillColor: const Color(0xFFF5F8FF),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: relationController,
                decoration: InputDecoration(
                  labelText: "Relation (ex: fils, fille, ami)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.family_restroom, color: Color(0xFF4A90E2)),
                  filled: true,
                  fillColor: const Color(0xFFF5F8FF),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: "Telephone",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.phone, color: Color(0xFF4A90E2)),
                  filled: true,
                  fillColor: const Color(0xFFF5F8FF),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Veuillez entrer un nom"),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final faceId = DateTime.now().millisecondsSinceEpoch.toString();
                final imageUrl = await FaceImageService.saveFaceImage(
                  imagePath: imagePath,
                  patientUid: widget.patientUid,
                  faceId: faceId,
                );

                final success = await FaceRecognitionService.saveFace(
                  name: nameController.text.trim(),
                  embedding: embedding,
                  relation: relationController.text.trim(),
                  phoneNumber: phoneController.text.trim(),
                  patientUid: widget.patientUid,
                  imageUrl: imageUrl,
                );

                Navigator.pop(ctx, success);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              child: const Text(
                "Enregistrer",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Text('${nameController.text.trim()} ajouté pour ${widget.patientName}'),
            ],
          ),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      Navigator.pop(context, true);
    } else if (result == false) {
      setState(() {
        _isCaptured = false;
        _capturedEmbedding = null;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E5AAC),
        foregroundColor: Colors.white,
        title: Text('Ajouter un proche pour ${widget.patientName}'),
        centerTitle: true,
      ),
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)))
          : Stack(
              children: [
                Positioned.fill(
                  child: CameraPreview(_controller!),
                ),

                Positioned(
                  top: 40,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: _faceDetected
                          ? Colors.green.withValues(alpha: 0.9)
                          : Colors.orange.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _faceDetected ? Icons.check_circle : Icons.warning,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _faceDetected
                              ? "Visage détecté - Appuyez pour capturer"
                              : "Positionnez le visage du proche",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Instructions",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Demandez au proche de se positionner devant la caméra\navec un bon éclairage",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: !_isProcessing && !_isCaptured ? _captureFace : null,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: !_isProcessing && !_isCaptured
                                ? const LinearGradient(
                                    colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                                  )
                                : const LinearGradient(
                                    colors: [Colors.grey, Colors.grey],
                                  ),
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: _isProcessing
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                )
                              : Icon(
                                  Icons.camera_alt,
                                  color: !_isProcessing && !_isCaptured
                                      ? Colors.white
                                      : Colors.grey,
                                  size: 40,
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
