import 'package:antitidur/screen/components/controller_bnavbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:water_drop_nav_bar/water_drop_nav_bar.dart';

class BottomNavbar extends GetView<BottomNavController> {
  const BottomNavbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() =>
        WaterDropNavBar(
            backgroundColor: Colors.white,
            barItems: controller.barItems,
            selectedIndex: controller.selectedIndex.value,
            onItemSelected: (index) => controller.changeIndex(index)
        ),
    );
  }
}
