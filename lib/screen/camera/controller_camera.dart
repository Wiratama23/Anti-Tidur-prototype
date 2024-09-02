import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:math';

import 'package:vibration/vibration.dart';

class CamController extends GetxController {
  late CameraController cameraController;
  late FaceDetector _faceDetector;
  bool isDetecting = false;
  double currentProgress = 0.0;
  final double activThreshold = 0.3;
  final int threshold = 5;
  bool isPlaying = false;
  final player = AudioPlayer();

  var isLoading = true.obs;
  var leftEyeHistory = <double>[].obs;
  var rightEyeHistory = <double>[].obs;
  var leftEyeOpenProb = 1.0.obs;
  var rightEyeOpenProb = 1.0.obs;
  var smileProb = 1.0.obs;
  var trackingId = 0.obs;
  var landmarks = <Point>[].obs;

  final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void onInit() {
    super.onInit();
    _initializeFaceDetector();
    _requestPermissions();
  }

  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: true,
      enableClassification: true,
    );
    _faceDetector = FaceDetector(options: options);
  }

  Future<void> _requestPermissions() async {
    if (await Permission.camera.request().isGranted) {
      _initializeCamera();
    } else {
      Get.snackbar('Permission Denied', 'Camera permission is required to proceed.');
    }
  }

  void _initializeCamera() async {
    isLoading.value = true;

    try {
      final cameras = await availableCameras();
      final firstCamera = cameras.first;
      cameraController = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: true,
      );
      await cameraController.initialize();
      cameraController.startVideoRecording();

      cameraController.startImageStream((CameraImage image) {
        _detectFaces(image);
      });
    } catch (e) {
      Get.snackbar('Camera Error', 'Failed to initialize camera: $e');
    } finally {
      isLoading.value = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = cameraController.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      final rotationCompensation =
          _orientations[cameraController.value.deviceOrientation] ?? 0;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotation = InputImageRotationValue.fromRawValue(
            ((sensorOrientation + rotationCompensation) % 360) as int);
      } else {
        rotation = InputImageRotationValue.fromRawValue(
            ((sensorOrientation - rotationCompensation + 360) % 360) as int);
      }
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _detectFaces(CameraImage image) async {
    if (isDetecting) return;
    isDetecting = true;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      isDetecting = false;
      return;
    }

    final List<Face> faces = await _faceDetector.processImage(inputImage);

    if (faces.isNotEmpty) {
      final face = faces.first;

      double leftEyeOpenProbNorm =
          face.leftEyeOpenProbability ?? 1.0;
      double rightEyeOpenProbNorm =
          face.rightEyeOpenProbability ?? 1.0;

      leftEyeHistory.add(leftEyeOpenProbNorm);
      rightEyeHistory.add(rightEyeOpenProbNorm);
      if (leftEyeHistory.length > 50) leftEyeHistory.removeAt(0);
      if (rightEyeHistory.length > 50) rightEyeHistory.removeAt(0);

      if (leftEyeOpenProbNorm < activThreshold ||
          rightEyeOpenProbNorm < activThreshold) {
        if (currentProgress < threshold) {
          currentProgress++;
        }
      } else {
        if (currentProgress >= 0) {
          currentProgress -= 2;
        } else {
          currentProgress = 0;
        }
      }

      if (currentProgress == threshold) {
        Vibration.vibrate(duration: 1000);
        if (!isPlaying) {
          await player
              .setLoopMode(LoopMode.one);
          await player.setAsset('assets/warn.mp3');
          player.play();
          isPlaying = true;

          SharedPreferences prefs = await SharedPreferences.getInstance();
          int sleepCount = (prefs.getInt('sleepCount') ?? 0) + 1;
          await prefs.setInt('sleepCount', sleepCount);
        }
      } else {
        player.stop();
        isPlaying = false;
      }

      leftEyeOpenProb.value = face.leftEyeOpenProbability ?? 1.0;
      rightEyeOpenProb.value = face.rightEyeOpenProbability ?? 1.0;
      smileProb.value = face.smilingProbability ?? 1.0;
      trackingId.value = face.trackingId ?? 0;
      landmarks.value = [    face.landmarks[FaceLandmarkType.bottomMouth]?.position ??
          const Point(0, 0),
        face.landmarks[FaceLandmarkType.leftMouth]?.position ??
            const Point(0, 0),
        face.landmarks[FaceLandmarkType.rightMouth]?.position ??
            const Point(0, 0),
        face.landmarks[FaceLandmarkType.leftEye]?.position ??
            const Point(0, 0),
        face.landmarks[FaceLandmarkType.rightEye]?.position ??
            const Point(0, 0),
        face.landmarks[FaceLandmarkType.noseBase]?.position ??
            const Point(0, 0),
        face.landmarks[FaceLandmarkType.rightCheek]?.position ??
            const Point(0, 0),
        face.landmarks[FaceLandmarkType.leftCheek]?.position ??
            const Point(0, 0),
      ];
    }

    isDetecting = false;
  }

  @override void onClose() { cameraController.dispose(); _faceDetector.close(); player.dispose(); super.onClose(); } }
