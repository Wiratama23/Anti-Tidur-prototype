import 'package:antitidur/screen/camera/controller_camera.dart';
import 'package:antitidur/screen/components/bnavbar.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Camera extends GetView<CamController> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Face Detection'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }
        if (!controller.cameraController.value.isInitialized) {
          return Center(child: Text('Camera not initialized'));
        }
        return Column(
          children: [
            Expanded(
              child: CameraPreview(controller.cameraController),
            ),
            Text('Left Eye Open Probability: ${controller.leftEyeOpenProb.value}'),
            Text('Right Eye Open Probability: ${controller.rightEyeOpenProb.value}'),
            Text('Smile Probability: ${controller.smileProb.value}'),
          ],
        );
      }),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: BottomNavbar(),
      ),
    );
  }
}
