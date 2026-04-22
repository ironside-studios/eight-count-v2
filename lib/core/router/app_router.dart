import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/timer/presentation/timer_screen.dart';

/// App-wide router. Two routes for now; the timer route swaps in the real
/// TimerScreen during Step 3.2 (the placeholder below goes away).
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const HomeScreen(),
    ),
    GoRoute(
      path: '/timer/:presetId',
      builder: (BuildContext context, GoRouterState state) {
        final String? presetId = state.pathParameters['presetId'];
        return TimerScreen(presetId: presetId ?? 'boxing');
      },
    ),
  ],
);
