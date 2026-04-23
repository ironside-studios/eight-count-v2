import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/custom_preset/data/custom_preset_repository.dart';
import '../../features/custom_preset/domain/custom_preset.dart';
import '../../features/custom_preset/presentation/custom_preset_editor_screen.dart';
import '../../features/custom_preset/presentation/custom_preset_list_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/timer/presentation/timer_screen.dart';
import '../../features/timer/presentation/workout_complete_screen.dart';
import '../../generated/l10n/app_localizations.dart';
import '../models/workout_config.dart';

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
    GoRoute(
      path: '/custom',
      builder: (BuildContext context, GoRouterState state) =>
          const CustomPresetListScreen(),
    ),
    GoRoute(
      path: '/custom/edit',
      builder: (BuildContext context, GoRouterState state) {
        final existing = state.extra;
        return CustomPresetEditorScreen(
          existing: existing is CustomPreset ? existing : null,
        );
      },
    ),
    // Step 5.2: Custom-preset timer launch. Async-loads the preset from
    // persistence, then hands a fully-built WorkoutConfig to TimerScreen
    // via its overrideConfig param.
    GoRoute(
      path: '/timer/custom/:presetId',
      builder: (BuildContext context, GoRouterState state) {
        final String? id = state.pathParameters['presetId'];
        if (id == null || id.isEmpty) {
          _scheduleNotFoundBounce(context);
          return const _TimerLoadingScaffold();
        }
        return FutureBuilder<CustomPreset?>(
          future: _findPresetById(id),
          builder: (fbContext, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _TimerLoadingScaffold();
            }
            final CustomPreset? preset = snapshot.data;
            if (preset == null) {
              _scheduleNotFoundBounce(fbContext);
              return const _TimerLoadingScaffold();
            }
            final WorkoutConfig config = WorkoutConfig.custom(
              rounds: preset.rounds,
              workSeconds: preset.workSeconds,
              restSeconds: preset.restSeconds,
              preCountdownSeconds: preset.preCountdownSeconds,
            );
            return TimerScreen(
              presetId: 'custom',
              overrideConfig: config,
            );
          },
        );
      },
    ),
  ],
);

Future<CustomPreset?> _findPresetById(String id) async {
  try {
    final presets = await CustomPresetRepository().loadAll();
    final matches = presets.where((p) => p.id == id);
    return matches.isEmpty ? null : matches.first;
  } catch (_) {
    return null;
  }
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
