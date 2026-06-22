import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../screens/login/login_screen.dart';

class InactivityWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  
  const InactivityWrapper({
    super.key, 
    required this.child,
    required this.navigatorKey,
  });

  @override
  ConsumerState<InactivityWrapper> createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends ConsumerState<InactivityWrapper> {
  Timer? _inactivityTimer;
  // 5 minutes = 300 seconds
  static const int _inactivityTimeoutSeconds = 300; 

  @override
  void initState() {
    super.initState();
  }

  void _resetTimer() {
    // Only run the timer if the user is logged in
    final authState = ref.read(authProvider);
    if (authState.value == null) {
      _inactivityTimer?.cancel();
      return;
    }

    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: _inactivityTimeoutSeconds), _handleInactivity);
  }

  Future<void> _handleInactivity() async {
    // Guard: only act if user is still logged in
    final authState = ref.read(authProvider);
    if (authState.value == null) return;

    // 1. Log out first (clears stored token)
    await ref.read(authProvider.notifier).logout();

    // 2. Navigate to login screen with sessionExpired flag using the root navigator
    final navState = widget.navigatorKey.currentState;
    if (navState != null && navState.mounted) {
      navState.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen(sessionExpired: true)),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes to start/stop the timer
    ref.listen(authProvider, (previous, next) {
      if (next.value != null) {
        // User logged in, start timer
        _resetTimer();
      } else {
        // User logged out, cancel timer
        _inactivityTimer?.cancel();
      }
    });

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerUp: (_) => _resetTimer(),
      // Track keyboard activity as well
      child: Focus(
        onKeyEvent: (node, event) {
          _resetTimer();
          return KeyEventResult.ignored;
        },
        child: widget.child,
      ),
    );
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }
}
