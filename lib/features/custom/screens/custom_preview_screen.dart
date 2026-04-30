import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../generated/l10n/app_localizations.dart';
import '../models/custom_config.dart';
import '../services/custom_preset_service.dart';
import '../widgets/custom_slot_card.dart';

/// Slots-list screen for the Custom feature. Lists the user's 3 saved
/// configs (or empty placeholders) and routes to either the timer
/// screen (run workout) or the builder screen (edit / create).
class CustomPreviewScreen extends StatefulWidget {
  const CustomPreviewScreen({super.key});

  @override
  State<CustomPreviewScreen> createState() => _CustomPreviewScreenState();
}

class _CustomPreviewScreenState extends State<CustomPreviewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD4A017)),
        title: Text(
          AppLocalizations.of(context)!.customPreviewTitle,
          style: GoogleFonts.bebasNeue(
            fontSize: 22,
            color: const Color(0xFFD4A017),
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StreamBuilder<List<CustomConfig>>(
            stream: CustomPresetService.instance.slotsStream,
            initialData: CustomPresetService.instance.getAllSlots(),
            builder: (context, snapshot) {
              final slots = snapshot.data ??
                  CustomPresetService.instance.getAllSlots();
              return ListView.builder(
                itemCount: slots.length,
                itemBuilder: (context, i) {
                  final config = slots[i];
                  return CustomSlotCard(
                    config: config,
                    onRunWorkout: () => _runWorkout(context, config),
                    onEdit: () => _editSlot(context, config),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _runWorkout(BuildContext context, CustomConfig config) {
    // Session B: route to the existing TimerScreen via the
    // /timer/custom/:slotIndex path. The router handler loads the
    // CustomConfig from CustomPresetService, adapts to WorkoutConfig
    // via the customConfigToWorkoutConfig adapter, and passes it to
    // TimerScreen along with the slot name + workout summary so the
    // preCountdown phase shows them above GET READY.
    context.push('/timer/custom/${config.slotIndex}');
  }

  void _editSlot(BuildContext context, CustomConfig config) {
    context.push('/custom/edit', extra: config);
  }
}
