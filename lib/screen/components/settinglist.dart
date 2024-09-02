import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Settinglist extends StatelessWidget {
  const Settinglist({
    required this.title,
    super.key
  });

  final String title;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SizedBox(
          child: Text(title, style: const TextStyle(fontSize: 15)),
        ),
        const SizedBox(width: 50),
        Switch(value: false, onChanged: (bool value) {})
      ],
    );
  }
}