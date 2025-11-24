import 'package:flutter/material.dart';
import 'package:easytime_online/animated_bottom_navigation.dart';
import 'package:easytime_online/persistent_navigation_layout.dart';
import 'package:easytime_online/dashboard_screen.dart';
import 'package:easytime_online/attendance_history_screen.dart';

class MainNavigation extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final String? userName;
  final String empKey;

  const MainNavigation({
    Key? key,
    this.userData,
    this.userName,
    required this.empKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Define the navigation items
    final List<BottomNavigationItem> navigationItems = [
      BottomNavigationItem(
        icon: Icons.dashboard,
        label: 'Dashboard',
      ),
      BottomNavigationItem(
        icon: Icons.history,
        label: 'Attendance',
      ),
      BottomNavigationItem(
        icon: Icons.person,
        label: 'Profile',
      ),
    ];

    // Define the screens for each navigation item
    final List<Widget> screens = [
      DashboardScreen(userData: userData, userName: userName, empKey: empKey),
      AttendanceHistoryScreen(empKey: empKey),
      Center(child: Text('Profile Screen')), // Placeholder for profile screen
    ];

    // Return the persistent navigation layout
    return PersistentNavigationLayout(
      screens: screens,
      navigationItems: navigationItems,
      initialIndex: 0,
    );
  }
}

// Using BottomNavigationItem from animated_bottom_navigation.dart