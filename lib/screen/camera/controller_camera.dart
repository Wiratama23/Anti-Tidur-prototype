import 'package:image/image.dart' as imglib;
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
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
  int frameCount = 0;

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
        ResolutionPreset.medium,
        enableAudio: true,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888
      );
      await cameraController.initialize();
      cameraController.startVideoRecording();
      await cameraController.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await cameraController.initialize().then((value) {
        cameraController.startImageStream((image) {
          print("1");
          frameCount++;
          print("print1 ${cameraController.imageFormatGroup}");
          if (frameCount % 5 == 0 ) {
            print("2");
            frameCount = 0;
            _detectFaces(image);
          }
          update();
          // isCameraInit(true);
        });
      });
      // cameraController.startImageStream((CameraImage image) {
      //   print("yes behrad");
      //   frameCount++;
      //   if (frameCount % 10 == 0) { // && !isDetecting
      //     print("yes behrad");
      //     frameCount = 0;
      //     _detectFaces(image);
      //   }
      //   update();
      // });
    } catch (e) {
      Get.snackbar('Camera Error', 'Failed to initialize camera: $e');
    } finally {
      isLoading.value = false;
    }
  }


  Uint8List _convertYUV420ToNV21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    // The Y (luminance) plane should have width * height pixels
    final int ySize = width * height;

    // The U and V (chrominance) planes are half the resolution of Y, so they should be width/2 * height/2 each
    final int uvSize = ((width / 2).floor()) * ((height / 2).floor()) * 2; // *2 because NV21 interleaves U and V

    // Create NV21 byte array
    final nv21 = Uint8List(ySize + uvSize);

    // Copy Y plane
    nv21.setRange(0, ySize, image.planes[0].bytes);

    // Copy UV planes: VU order (NV21 format)
    for (int i = 0; i < uvSize / 2; i++) {
      final int uIndex = image.planes[1].bytesPerRow * (i ~/ (width ~/ 2)) + (i % (width ~/ 2)) * image.planes[1].bytesPerPixel!;
      final int vIndex = image.planes[2].bytesPerRow * (i ~/ (width ~/ 2)) + (i % (width ~/ 2)) * image.planes[2].bytesPerPixel!;

      nv21[ySize + 2 * i] = image.planes[2].bytes[vIndex];     // V
      nv21[ySize + 2 * i + 1] = image.planes[1].bytes[uIndex]; // U
    }

    return nv21;
  }




  Uint8List _convertYUV420ToBGRA8888(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;

    final imglib.Image imgBuffer = imglib.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = (x / 2).floor() * uvPixelStride + (y / 2).floor() * uvRowStride;
        final int yIndex = x + y * width;

        final int yValue = image.planes[0].bytes[yIndex];
        final int uValue = image.planes[1].bytes[uvIndex];
        final int vValue = image.planes[2].bytes[uvIndex];

        final int r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        final int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).clamp(0, 255).toInt();
        final int b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        imgBuffer.setPixel(x, y, imglib.ColorFloat32.rgb(r / 255.0, g / 255.0, b / 255.0));
      }
    }

    // Convert to BGRA8888
    return imglib.encodePng(imgBuffer);
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = cameraController.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      final rotationCompensation = _orientations[cameraController.value.deviceOrientation] ?? 0;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotation = InputImageRotationValue.fromRawValue(
            (sensorOrientation + rotationCompensation) % 360);
      } else {
        rotation = InputImageRotationValue.fromRawValue(
            (sensorOrientation - rotationCompensation + 360) % 360);
      }
    }

    if (rotation == null) return null;

    Uint8List? convertedBytes;
    InputImageFormat? format;

    if (Platform.isAndroid) {
      convertedBytes = _convertYUV420ToNV21(image);
      format = InputImageFormat.nv21;
    } else if (Platform.isIOS) {
      convertedBytes = _convertYUV420ToBGRA8888(image);
      format = InputImageFormat.bgra8888;
    }

    if (convertedBytes == null || format == null) return null;

    return InputImage.fromBytes(
      bytes: convertedBytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }


  // InputImage? _inputImageFromCameraImage(CameraImage image) {
  //   final camera = cameraController.description;
  //   final sensorOrientation = camera.sensorOrientation;
  //   InputImageRotation? rotation;
  //
  //   if (Platform.isIOS) {
  //     rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
  //   } else if (Platform.isAndroid) {
  //     print("platform is android");
  //     final rotationCompensation =
  //         _orientations[cameraController.value.deviceOrientation] ?? 0;
  //     print("rotationcomp");
  //     if (camera.lensDirection == CameraLensDirection.front) {
  //       rotation = InputImageRotationValue.fromRawValue(
  //           ((sensorOrientation + rotationCompensation) % 360));
  //       print("rotation 1");
  //     } else {
  //       rotation = InputImageRotationValue.fromRawValue(
  //           ((sensorOrientation - rotationCompensation + 360) % 360));
  //       print("rotation 2");
  //     }
  //   }
  //
  //   print("rotation: $rotation");
  //   if (rotation == null) return null;
  //
  //   Uint8List? convertedBytes;
  //   InputImageFormat? format;
  //
  //   if (Platform.isAndroid) {
  //     convertedBytes = _convertYUV420ToNV21(image);
  //     format = InputImageFormat.nv21;
  //   } else if (Platform.isIOS) {
  //     convertedBytes = _convertYUV420ToBGRA8888(image);
  //     format = InputImageFormat.bgra8888;
  //   }
  //
  //   if (convertedBytes == null || format == null) return null;
  //   // final format = InputImageFormatValue.fromRawValue(image.format.raw);
  //   // print("image format ${image.format.raw}");
  //   // print("format $format");
  //   // if (format == null ||
  //   //     (Platform.isAndroid && format != InputImageFormat.nv21) ||
  //   //     (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;
  //   // Uint8List? convertedBytes;
  //   // if (Platform.isAndroid) {
  //   //   convertedBytes = _convertYUV420ToNV21(image);
  //   //   format! = InputImageFormat.nv21;
  //   // } else if (Platform.isIOS) {
  //   //   convertedBytes = _convertYUV420ToBGRA8888(image);
  //   //   format! = InputImageFormat.bgra8888;
  //   // }
  //   // final format = InputImageFormatValue.fromRawValue(image.format.raw);
  //   // print("image format ${image.format.raw}");
  //   // print("format $format");
  //   //
  //   // Uint8List? convertedBytes;
  //   // InputImageFormat? newFormat;
  //
  //   // if (Platform.isAndroid) {
  //   //   convertedBytes = _convertYUV420ToNV21(image);
  //   //   newFormat = InputImageFormat.nv21;
  //   // } else if (Platform.isIOS) {
  //   //   convertedBytes = _convertYUV420ToBGRA8888(image);
  //   //   newFormat = InputImageFormat.bgra8888;
  //   // }
  //
  //   // Now you can use `newFormat` and `convertedBytes`
  //   // if (convertedBytes != null && newFormat != null) {
  //   //   // Process the image with the convertedBytes and newFormat
  //   // } else {
  //   //   print("Failed to convert image format");
  //   // }
  //
  //   print("check 1");
  //
  //   final plane = image.planes.first;
  //   print("check 2 ${plane.bytes}");
  //   return InputImage.fromBytes(
  //     bytes: plane.bytes,
  //     metadata: InputImageMetadata(
  //       size: Size(image.width.toDouble(), image.height.toDouble()),
  //       rotation: rotation,
  //       format: format,
  //       bytesPerRow: plane.bytesPerRow,
  //     ),
  //   );
  // }

  void _detectFaces(CameraImage image) async {
    if (isDetecting) return;
    isDetecting = true;
    print("masuk");
    print(image.format.raw);
    print("image ${image.format}");
    final inputImage = _inputImageFromCameraImage(image);
    print(inputImage);
    if (inputImage == null) {
      isDetecting = false;
      return;
    }

    List<Face> faces = await _faceDetector.processImage(inputImage);
    print("faces $faces");

    if (faces.isNotEmpty) {
      print("face detected");
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
        print("face not detected");
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
      update();
    }
    print("not detected any");
    isDetecting = false;
  }

  @override void onClose() { cameraController.dispose(); _faceDetector.close(); player.dispose(); super.onClose(); }

}
