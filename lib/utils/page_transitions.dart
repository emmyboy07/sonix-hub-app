import 'package:flutter/material.dart';

/// Custom page transition for smooth, optimized navigation
class SmoothPageRoute<T> extends MaterialPageRoute<T> {
  SmoothPageRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Faster fade + slide transition
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position:
            Tween<Offset>(
              begin: const Offset(0.0, 0.03),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
    );
  }
}

/// Navigate with smooth page transition
Future<T?> navigateWithTransition<T>(
  BuildContext context,
  Widget page, {
  bool replace = false,
}) {
  final route = SmoothPageRoute<T>(builder: (_) => page);

  if (replace) {
    return Navigator.of(context).pushReplacement(route);
  } else {
    return Navigator.of(context).push(route);
  }
}
