import 'package:flutter/material.dart';

class AppPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final RouteSettings? routeSettings;

  AppPageRoute({
    required this.page,
    this.routeSettings,
  }) : super(
    settings: routeSettings,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
    transitionDuration: const Duration(milliseconds: 300),
  );
}

class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final RouteSettings? routeSettings;

  FadePageRoute({
    required this.page,
    this.routeSettings,
  }) : super(
    settings: routeSettings,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 250),
  );
}

class ScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final RouteSettings? routeSettings;

  ScalePageRoute({
    required this.page,
    this.routeSettings,
  }) : super(
    settings: routeSettings,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        ),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final RouteSettings? routeSettings;

  SlideUpPageRoute({
    required this.page,
    this.routeSettings,
  }) : super(
    settings: routeSettings,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.easeInOutCubic;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 350),
  );
}

extension NavigatorExtensions on BuildContext {
  Future<T?> pushWithSlide<T>(Widget page, {String? routeName}) {
    return Navigator.push<T>(
      this,
      AppPageRoute(
        page: page,
        routeSettings: routeName != null ? RouteSettings(name: routeName) : null,
      ),
    );
  }

  Future<T?> pushWithFade<T>(Widget page, {String? routeName}) {
    return Navigator.push<T>(
      this,
      FadePageRoute(
        page: page,
        routeSettings: routeName != null ? RouteSettings(name: routeName) : null,
      ),
    );
  }

  Future<T?> pushWithScale<T>(Widget page, {String? routeName}) {
    return Navigator.push<T>(
      this,
      ScalePageRoute(
        page: page,
        routeSettings: routeName != null ? RouteSettings(name: routeName) : null,
      ),
    );
  }

  Future<T?> pushWithSlideUp<T>(Widget page, {String? routeName}) {
    return Navigator.push<T>(
      this,
      SlideUpPageRoute(
        page: page,
        routeSettings: routeName != null ? RouteSettings(name: routeName) : null,
      ),
    );
  }
}
