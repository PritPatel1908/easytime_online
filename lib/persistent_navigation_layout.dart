import 'package:flutter/material.dart';
import 'package:easytime_online/animated_bottom_navigation.dart';

class PersistentNavigationLayout extends StatefulWidget {
  final List<Widget> screens;
  final List<BottomNavigationItem> navigationItems;
  final int initialIndex;

  const PersistentNavigationLayout({
    Key? key,
    required this.screens,
    required this.navigationItems,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<PersistentNavigationLayout> createState() => _PersistentNavigationLayoutState();
}

class _PersistentNavigationLayoutState extends State<PersistentNavigationLayout> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
      // Animate to the selected page without animation to prevent the bottom navigation from moving
      _pageController.jumpToPage(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swiping between pages
        children: widget.screens,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      bottomNavigationBar: AnimatedBottomNavigation(
        items: widget.navigationItems,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

// Extension to make it easier to navigate to a specific page
extension PersistentNavigationLayoutExtension on BuildContext {
  void navigateToPage(int index) {
    final state = findAncestorStateOfType<_PersistentNavigationLayoutState>();
    if (state != null) {
      state._onTabTapped(index);
    }
  }
}