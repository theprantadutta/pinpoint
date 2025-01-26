import 'package:flutter/material.dart';
import 'package:pinpoint/components/home_screen/home_screen_my_folders.dart';
import 'package:pinpoint/components/home_screen/home_screen_top_bar.dart';

class HomeScreen extends StatelessWidget {
  static const String kRouteName = '/home';
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        spacing: 10,
        children: [
          HomeScreenTopBar(),
          HomeScreenMyFolders(),
        ],
      ),
    );
  }
}
