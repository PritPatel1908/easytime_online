import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An animated bottom navigation bar with smooth transitions and effects
class AnimatedBottomNavigation extends StatefulWidget {
  final List<BottomNavigationItem> items;
  final int currentIndex;
  final Function(int) onTap;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final double iconSize;
  final double height;
  final Curve animationCurve;
  final Duration animationDuration;
  final bool showLabels;
  final bool enableFeedback;

  const AnimatedBottomNavigation({
    Key? key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.iconSize = 24.0,
    this.height = 60.0,
    this.animationCurve = Curves.easeInOut,
    this.animationDuration = const Duration(milliseconds: 300),
    this.showLabels = true,
    this.enableFeedback = true,
  }) : super(key: key);

  @override
  State<AnimatedBottomNavigation> createState() => _AnimatedBottomNavigationState();
}

class _AnimatedBottomNavigationState extends State<AnimatedBottomNavigation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<double> _itemPositions;
  late double _itemWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = widget.backgroundColor ?? theme.bottomNavigationBarTheme.backgroundColor ?? theme.colorScheme.surface;
    final selectedItemColor = widget.selectedItemColor ?? theme.bottomNavigationBarTheme.selectedItemColor ?? theme.colorScheme.primary;
    final unselectedItemColor = widget.unselectedItemColor ?? theme.bottomNavigationBarTheme.unselectedItemColor ?? theme.colorScheme.onSurface.withOpacity(0.6);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _itemWidth = constraints.maxWidth / widget.items.length;
          _itemPositions = List.generate(
            widget.items.length,
            (index) => index * _itemWidth,
          );

          return Stack(
            children: [
              // Fixed navigation bar layout (non-animated)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  widget.items.length,
                  (index) => SizedBox(
                    width: _itemWidth,
                    height: widget.height,
                  ),
                ),
              ),
              // Animated indicator
              AnimatedPositioned(
                duration: widget.animationDuration,
                curve: widget.animationCurve,
                left: _itemPositions[widget.currentIndex],
                width: _itemWidth,
                top: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: selectedItemColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Navigation items with only icon animations
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  widget.items.length,
                  (index) => _buildNavItem(
                    item: widget.items[index],
                    index: index,
                    isSelected: index == widget.currentIndex,
                    selectedColor: selectedItemColor,
                    unselectedColor: unselectedItemColor,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavItem({
    required BottomNavigationItem item,
    required int index,
    required bool isSelected,
    required Color selectedColor,
    required Color unselectedColor,
  }) {
    return InkWell(
      onTap: () {
        widget.onTap(index);
        if (widget.enableFeedback) {
          HapticFeedback.lightImpact();
        }
      },
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: _itemWidth,
        height: widget.height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Only animate the icon, not the entire item
            AnimatedSwitcher(
              duration: widget.animationDuration,
              switchInCurve: widget.animationCurve,
              switchOutCurve: widget.animationCurve,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                );
              },
              child: Icon(
                isSelected ? item.icon : item.icon,
                key: ValueKey<bool>(isSelected),
                color: isSelected ? selectedColor : unselectedColor,
                size: widget.iconSize,
              ),
            ),
            if (widget.showLabels) ...[
              const SizedBox(height: 4),
              // Text with no animation for position
              AnimatedDefaultTextStyle(
                duration: widget.animationDuration,
                curve: widget.animationCurve,
                style: TextStyle(
                  color: isSelected ? selectedColor : unselectedColor,
                  fontSize: isSelected ? 12 : 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                child: Text(
                  item.label,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Model class for bottom navigation items
class BottomNavigationItem {
  final IconData icon;
  final String label;

  const BottomNavigationItem({
    required this.icon,
    required this.label,
  });
}