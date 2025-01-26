import 'package:flutter/material.dart';

const kBottomDestinations = <Widget>[
  NavigationDestination(
    selectedIcon: Icon(Icons.home),
    icon: Icon(Icons.home_outlined),
    label: 'Home',
  ),
  NavigationDestination(
    icon: Icon(Icons.folder_copy_outlined),
    label: 'Folder',
  ),
  NavigationDestination(
    icon: Icon(Icons.check_box_outlined),
    label: 'Todo',
  ),
  NavigationDestination(
    icon: Icon(Icons.person_2_outlined),
    label: 'Account',
  ),
];
