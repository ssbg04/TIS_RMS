import 'package:flutter/material.dart';

/// Centralized navigation service to access the root navigator from
/// background services, HTTP interceptors, and non-widget contexts.
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static BuildContext? get currentContext => navigatorKey.currentContext;
  static NavigatorState? get currentState => navigatorKey.currentState;
}

