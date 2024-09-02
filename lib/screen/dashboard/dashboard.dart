import 'package:antitidur/screen/components/settinglist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../components/bnavbar.dart';
import 'controller_dashboard.dart';

class Dashboard extends GetView<DashboardController> {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          body: Obx(
            () => controller.isLoading.value
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: SizedBox(
                            height: controller.screenHeight.value * 0.6,
                            width: controller.screenHeight.value * 0.8,
                            child: const Card(
                              color: Colors.white70,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(15))),
                              elevation: 8,
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      child: Text("SETTINGS",
                                          style: TextStyle(fontSize: 35)),
                                    ),
                                    Divider(
                                      thickness: 3,
                                      color: Colors.blue,
                                    ),
                                    Settinglist(title: 'Enable Alarm'),
                                    Settinglist(title: 'Enable Alarm'),
                                    Settinglist(title: 'Enable Alarm'),
                                    Settinglist(title: 'Enable Alarm'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: SizedBox(
                            height: controller.screenHeight.value * 0.6,
                            width: controller.screenHeight.value * 0.8,
                            child: const Card(
                              color: Colors.white70,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.all(Radius.circular(15))),
                              elevation: 8,
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      child: Text("REPORTS",
                                          style: TextStyle(fontSize: 35)),
                                    ),
                                    Divider(
                                      thickness: 3,
                                      color: Colors.blue,
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Text("Tanggal"),
                                        Divider(),
                                        Text("Jumlah kejadian")
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Text("1/9/2024"),
                                        Divider(),
                                        Text("10")
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Text("10/9/2024"),
                                        Divider(),
                                        Text("12")
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          bottomNavigationBar: const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: BottomNavbar(),
          ),
        ));
  }
}
