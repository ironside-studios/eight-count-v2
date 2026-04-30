import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/custom/models/custom_config.dart';
import '../../features/custom/screens/custom_builder_screen.dart';
import '../../features/custom/screens/custom_preview_screen.dart';
import '../../features/custom/services/custom_preset_service.dart';
import '../../features/custom/services/custom_workout_adapter.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/timer/presentation/timer_screen.dart';
import '../../features/timer/presentation/workout_complete_screen.dart';
import '../../generated/l10n/app_localizations.dart';
import '../navigation/route_observer.dart';

/// App-wide router. Two routes for now; the timer route swaps in the real
/// TimerScreen during Step 3.2 (the placeholder below goes away).
///
/// `observers:` registers the shared [routeObserver] so [RouteAware]
/// widgets (matrix-rain home background) can pause/resume tickers when
/// the user navigates between screens.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  observers: <NavigatorObserver>[routeObserver],
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
    GoRoute(
      path: '/complete',
      builder: (BuildContext context, GoRouterState state) {
        final extra = (state.extra as Map<String, dynamic>?) ?? const {};
        final totalSeconds = (extra['totalSeconds'] as int?) ?? 0;
        final presetId = (extra['presetId'] as String?) ?? '';
        return WorkoutCompleteScreen(
          totalSeconds: totalSeconds,
          presetId: presetId,
        );
      },
    ),
    // /custom and /custom/edit point at the 2026-04-30 Custom-preset
    // rebuild (lib/features/custom/). The legacy custom_preset/
    // directory was deleted in Session B; /timer/custom/:slotIndex
    // now loads from CustomPresetService and adapts via
    // customConfigToWorkoutConfig.
    GoRoute(
      path: '/custom',
      builder: (BuildContext context, GoRouterState state) =>
          const CustomPreviewScreen(),
    ),
    GoRoute(
      path: '/custom/edit',
      builder: (BuildContext context, GoRouterState state) {
        final extra = state.extra;
        if (extra is! CustomConfig) {
          // Defensive: caller must pass a CustomConfig in `extra`.
          // Bounce home rather than render a broken screen.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/');
          });
          return const _TimerLoadingScaffold();
        }
        return CustomBuilderScreen(initialConfig: extra);
      },
    ),
    // Custom workout launch: parse slotIndex (0/1/2) from the path,
    // load the CustomConfig from CustomPresetService (already
    // hydrated in main()), adapt to a Boxing-style WorkoutConfig via
    // customConfigToWorkoutConfig, and pass it + the slot name +
    // workout summary to TimerScreen. The summary string is a
    // pre-formatted M:SS-style line built from the localized
    // customSlotSubtitle ARB key.
    GoRoute(
      path: '/timer/custom/:slotIndex',
      builder: (BuildContext context, GoRouterState state) {
        final String? raw = state.pathParameters['slotIndex'];
        final int? slotIndex = raw == null ? null : int.tryParse(raw);
        if (slotIndex == null || slotIndex < 0 || slotIndex > 2) {
          _scheduleNotFoundBounce(context);
          return const _TimerLoadingScaffold();
        }
        final CustomConfig customConfig =
            CustomPresetService.instance.getSlot(slotIndex);
        if (!customConfig.isSaved) {
          _scheduleNotFoundBounce(context);
          return const _TimerLoadingScaffold();
        }
        final l10n = AppLocalizations.of(context)!;
        final summary = l10n.customSlotSubtitle(
          customConfig.rounds,
          _formatMmSs(customConfig.workSeconds),
          _formatMmSs(customConfig.restSeconds),
        );
        return TimerScreen(
          presetId: 'custom',
          overrideConfig: customConfigToWorkoutConfig(customConfig),
          customHeader: customConfig.name,
          customSubtitle: summary,
        );
      },
    ),
  ],
);

String _formatMmSs(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

void _scheduleNotFoundBounce(BuildContext context) {
  // Capture the messenger + localizations BEFORE the post-frame navigation
  // tears the route down. context.go swaps the route synchronously inside
  // the callback, so any lookup after it would see the new route's tree.
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = AppLocalizations.of(context);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (l10n != null) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.workoutNotFound)),
      );
    }
    if (context.mounted) {
      context.go('/');
    }
  });
}

class _TimerLoadingScaffold extends StatelessWidget {
  const _TimerLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF000000),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFF5C518)),
      ),
    );
  }
}
