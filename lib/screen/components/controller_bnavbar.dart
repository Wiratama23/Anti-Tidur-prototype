import 'package:antitidur/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:water_drop_nav_bar/water_drop_nav_bar.dart';

class BottomNavController extends GetxController {
  RxInt selectedIndex = 0.obs;
  final barItems = [
    BarItem(
        filledIcon: Icons.dashboard,
        outlinedIcon: Icons.dashboard_outlined
    ),
    BarItem(
        filledIcon: Icons.camera,
        outlinedIcon: Icons.camera_alt_outlined
    ),
  ];

  void changeIndex(int index){
    selectedIndex.value = index;
    Get.toNamed(Routes.pages[selectedIndex.value].name);
    print(selectedIndex.value);
  }
}
