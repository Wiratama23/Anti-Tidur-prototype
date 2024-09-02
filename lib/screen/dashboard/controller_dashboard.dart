import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DashboardController extends GetxController {
  RxDouble screenHeight = 0.0.obs;
  RxDouble screenWidth = 0.0.obs;
  RxBool isLoading = true.obs;


  @override
  void onInit() {
    super.onInit();
    // Delayed initialization to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.context != null) {
        screenHeight.value = MediaQuery.of(Get.context!).size.height;
        screenWidth.value = MediaQuery.of(Get.context!).size.width;
      }
      isLoading.value = false;
    });
  }

}
