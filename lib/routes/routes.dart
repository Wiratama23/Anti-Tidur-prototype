import 'package:antitidur/screen/camera/camera.dart';
import 'package:antitidur/screen/camera/controller_camera.dart';
import 'package:antitidur/screen/components/controller_bnavbar.dart';
import 'package:antitidur/screen/dashboard/controller_dashboard.dart';
import 'package:get/get.dart';

import '../screen/dashboard/dashboard.dart';
import 'routes_name.dart';

class Routes{
  static final pages = [
    GetPage(
        name: Names.dashboard,
        page: () => const Dashboard(),
        transition: Transition.fadeIn,
        transitionDuration: const Duration(seconds: 1),
        binding : BindingsBuilder((){
          Get.put(DashboardController());
          Get.put(BottomNavController());
        })
    ),
    GetPage(
        name: Names.camera,
        page: () => Camera(),
        transition: Transition.fadeIn,
        transitionDuration: const Duration(seconds: 1),
        binding : BindingsBuilder((){
          Get.put(CamController());
          Get.put(BottomNavController());
        })
    ),
  ];
}