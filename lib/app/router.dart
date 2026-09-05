import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/analytics/analytics_screen.dart';
import '../features/goals/goals_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import 'shell.dart';

/// Four tabs, one persistent shell. Transitions are a short fade + rise rather
/// than the platform push, so switching tabs feels like the content is swapping
/// underneath a fixed chrome instead of navigating away.
final router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(
        location: state.uri.path,
        child: child,
      ),
      routes: [
        GoRoute(path: '/', pageBuilder: _fade(const HomeScreen())),
        GoRoute(
          path: '/analytics',
          pageBuilder: _fade(const AnalyticsScreen()),
        ),
        GoRoute(path: '/history', pageBuilder: _fade(const HistoryScreen())),
        GoRoute(path: '/goals', pageBuilder: _fade(const GoalsScreen())),
      ],
    ),
  ],
);

Page<Object?> Function(BuildContext, GoRouterState) _fade(Widget child) {
  return (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        child: child,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.035),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
}
