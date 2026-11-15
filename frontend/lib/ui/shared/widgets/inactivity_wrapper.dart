import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../screens/login/login_screen.dart';

/// Wraps the root MaterialApp and logs the user out after [inactivityTimeout]
/// of no pointer or keyboard activity (including backgrounded time).
class InactivityWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final Duration inactivityTimeout;

  const InactivityWrapper({
    super.key,
    required this.child,
    required this.navigatorKey,
    this.inactivityTimeout = const Duration(minutes: 10),
  });

  @override
  ConsumerState<InactivityWrapper> createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends ConsumerState<InactivityWrapper>
    with WidgetsBindingObserver {
  Timer? _inactivityTimer;
  DateTime _lastActivityAt = DateTime.now();
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      _recordActivity();
    }
    return false; // Never consume key events
  }

  bool get _isLoggedIn => ref.read(authProvider).value != null;

  void _recordActivity() {
    if (_isLoggingOut || !_isLoggedIn) return;
    final now = DateTime.now();
    // Throttle timer resets to at most once per second
    if (_inactivityTimer != null &&
        now.difference(_lastActivityAt).inSeconds < 1) {
      return;
    }
    _lastActivityAt = now;
    _scheduleTimer(widget.inactivityTimeout);
  }

  void _scheduleTimer(Duration delay) {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(delay, _onInactivityTimeout);
  }

  void _stopTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isLoggedIn && !_isLoggingOut) {
      final elapsed = DateTime.now().difference(_lastActivityAt);
      if (elapsed >= widget.inactivityTimeout) {
        _onInactivityTimeout();
      } else {
        _scheduleTimer(widget.inactivityTimeout - elapsed);
      }
    }
  }

  Future<void> _onInactivityTimeout() async {
    if (_isLoggingOut || !_isLoggedIn || !mounted) return;
    _isLoggingOut = true;
    _stopTimer();

    try {
      await ref.read(authProvider.notifier).logout();
    } catch (_) {
      // Ensure local navigation proceeds even if server logout fails
    }

    if (!mounted) return;
    widget.navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(sessionExpired: true),
      ),
      (route) => false,
    );
    _isLoggingOut = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      final wasLoggedIn = previous?.value != null;
      final isNowLoggedIn = next.value != null;
      if (!wasLoggedIn && isNowLoggedIn) {
        _isLoggingOut = false;
        _lastActivityAt = DateTime.now();
        _scheduleTimer(widget.inactivityTimeout);
      } else if (wasLoggedIn && !isNowLoggedIn) {
        _stopTimer();
      }
    });

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _recordActivity(),
      onPointerMove: (_) => _recordActivity(),
      onPointerSignal: (_) => _recordActivity(),
      child: widget.child,
    );
  }
}
