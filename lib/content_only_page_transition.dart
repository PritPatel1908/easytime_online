import 'package:flutter/material.dart';

/// A page transition that only animates the content area, keeping the bottom navigation fixed
class ContentOnlyPageTransition<T> extends PageRouteBuilder<T> {
  final Widget page;
  final RouteSettings settings;

  ContentOnlyPageTransition({
    required this.page,
    required this.settings,
  }) : super(
          settings: settings,
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
        );
}

/// Navigation helper to push a new page with content-only transition
class ContentOnlyNavigation {
  static Future<T?> push<T>(BuildContext context, Widget page, {String? routeName}) {
    return Navigator.of(context).push<T>(
      ContentOnlyPageTransition<T>(
        page: page,
        settings: RouteSettings(name: routeName),
      ),
    );
  }

  static Future<T?> pushReplacement<T>(BuildContext context, Widget page, {String? routeName}) {
    return Navigator.of(context).pushReplacement<T, dynamic>(
      ContentOnlyPageTransition<T>(
        page: page,
        settings: RouteSettings(name: routeName),
      ),
    );
  }
}