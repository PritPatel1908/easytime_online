import 'package:flutter/material.dart';

/// Enum to define different transition types
enum PageTransitionType {
  fade,
  rightToLeft,
  leftToRight,
  upToDown,
  downToUp,
  scale,
  rotate,
  size,
  rightToLeftWithFade,
  leftToRightWithFade,
}

/// Custom page route that provides smooth transitions between pages
class CustomPageRoute<T> extends PageRoute<T> {
  final Widget page;
  final PageTransitionType transitionType;
  final Curve curve;
  final Alignment alignment;
  final Duration duration;
  
  CustomPageRoute({
    required this.page,
    this.transitionType = PageTransitionType.rightToLeft,
    this.curve = Curves.easeInOut,
    this.alignment = Alignment.center,
    this.duration = const Duration(milliseconds: 300),
    RouteSettings? settings,
  }) : super(settings: settings);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);
  
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return page;
  }
  
  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    // Use a cached animation curve for better performance
    final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn);
    
    switch (transitionType) {
      case PageTransitionType.fade:
        return FadeTransition(opacity: animation, child: child);
        
      case PageTransitionType.rightToLeft:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
        
      case PageTransitionType.leftToRight:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
        
      case PageTransitionType.upToDown:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
        
      case PageTransitionType.downToUp:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
        
      case PageTransitionType.scale:
        return ScaleTransition(
          alignment: alignment,
          scale: curvedAnimation,
          child: child,
        );
        
      case PageTransitionType.rotate:
        return RotationTransition(
          turns: animation,
          child: ScaleTransition(
            scale: animation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
        );
        
      case PageTransitionType.size:
        return Align(
          alignment: alignment,
          child: SizeTransition(
            sizeFactor: CurvedAnimation(
              parent: animation,
              curve: curve,
            ),
            child: child,
          ),
        );
        
      case PageTransitionType.rightToLeftWithFade:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: curve)),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
        
      case PageTransitionType.leftToRightWithFade:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: curve)),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
        
      default:
        return FadeTransition(opacity: animation, child: child);
    }
  }
}

/// Helper class to handle navigation with custom transitions
class NavigationHelper {
  /// Navigate to a new page with custom transition
  static Future<T?> navigateTo<T>(
    BuildContext context, 
    Widget page, {
    PageTransitionType transitionType = PageTransitionType.rightToLeft,
    Curve curve = Curves.easeInOut,
    Alignment alignment = Alignment.center,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.push<T>(
      context,
      CustomPageRoute<T>(
        page: page,
        transitionType: transitionType,
        curve: curve,
        alignment: alignment,
        duration: duration,
      ),
    );
  }

  /// Replace the current page with a new page using custom transition
  static Future<T?> navigateReplacementTo<T>(
    BuildContext context, 
    Widget page, {
    PageTransitionType transitionType = PageTransitionType.rightToLeft,
    Curve curve = Curves.easeInOut,
    Alignment alignment = Alignment.center,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return Navigator.pushReplacement<T, dynamic>(
      context,
      CustomPageRoute<T>(
        page: page,
        transitionType: transitionType,
        curve: curve,
        alignment: alignment,
        duration: duration,
      ),
    );
  }

  /// Navigate to a named route with custom transition
  static Future<T?> navigateToNamed<T>(
    BuildContext context, 
    String routeName, {
    Object? arguments,
    PageTransitionType transitionType = PageTransitionType.rightToLeft,
    Curve curve = Curves.easeInOut,
    Alignment alignment = Alignment.center,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    final route = CustomPageRoute<T>(
      page: _buildPageFromRoute(context, routeName, arguments),
      settings: RouteSettings(name: routeName, arguments: arguments),
      transitionType: transitionType,
      curve: curve,
      alignment: alignment,
      duration: duration,
    );
    return Navigator.push<T>(context, route);
  }

  /// Replace the current page with a named route using custom transition
  static Future<T?> navigateReplacementToNamed<T>(
    BuildContext context, 
    String routeName, {
    Object? arguments,
    PageTransitionType transitionType = PageTransitionType.rightToLeft,
    Curve curve = Curves.easeInOut,
    Alignment alignment = Alignment.center,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    final route = CustomPageRoute<T>(
      page: _buildPageFromRoute(context, routeName, arguments),
      settings: RouteSettings(name: routeName, arguments: arguments),
      transitionType: transitionType,
      curve: curve,
      alignment: alignment,
      duration: duration,
    );
    return Navigator.pushReplacement<T, dynamic>(context, route);
  }

  // Helper method to build a page from a route name
  static Widget _buildPageFromRoute(BuildContext context, String routeName, Object? arguments) {
    final routes = {
      '/dashboard': (context) => const SizedBox(), // Placeholder, will be replaced in implementation
      '/attendance': (context) => const SizedBox(), // Placeholder, will be replaced in implementation
      '/hours': (context) => const SizedBox(), // Placeholder, will be replaced in implementation
      '/profile': (context) => const SizedBox(), // Placeholder, will be replaced in implementation
    };

    final builder = routes[routeName];
    if (builder == null) {
      throw Exception('Route not found: $routeName');
    }
    
    return builder(context);
  }
}