import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
          'Custom Workouts',
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
    // TODO(session-b): wire to timer engine in Session B. For now,
    // this is a no-op (Session A is UI + persistence only).
  }

  void _editSlot(BuildContext context, CustomConfig config) {
    context.push('/custom/edit', extra: config);
  }
}
