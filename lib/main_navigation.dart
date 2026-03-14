import 'package:flutter/material.dart';
import 'package:easytime_online/animated_bottom_navigation.dart';
import 'package:easytime_online/persistent_navigation_layout.dart';
import 'package:easytime_online/ui/dashboard_screen.dart';
import 'package:easytime_online/ui/attendance_history_screen.dart';

class MainNavigation extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final String? userName;
  final String empKey;
  final int initialIndex;

  const MainNavigation({
    Key? key,
    this.userData,
    this.userName,
    required this.empKey,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Define the navigation items
    final List<BottomNavigationItem> navigationItems = [
      const BottomNavigationItem(
        icon: Icons.dashboard,
        label: 'Dashboard',
      ),
      const BottomNavigationItem(
        icon: Icons.history,
        label: 'Attendance',
      ),
      const BottomNavigationItem(
        icon: Icons.person,
        label: 'Profile',
      ),
    ];

    // Define the screens for each navigation item
    final List<Widget> screens = [
      DashboardScreen(userData: userData, userName: userName, empKey: empKey),
      AttendanceHistoryScreen(
          empKey: empKey, userData: userData, userName: userName),
      const Center(
          child: Text('Profile Screen')), // Placeholder for profile screen
    ];

    // Return the persistent navigation layout
    return PersistentNavigationLayout(
      screens: screens,
      navigationItems: navigationItems,
      initialIndex: initialIndex,
    );
  }
}

// Using BottomNavigationItem from animated_bottom_navigation.dart
