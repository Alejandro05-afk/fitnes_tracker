import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/motion_state.dart';
import '../cubit/activity_detection_cubit.dart';

class ActivityStatusWidget extends StatelessWidget {
  const ActivityStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityDetectionCubit, ActivityDetectionState>(
      builder: (context, state) {
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Actividad detectada',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Icon(_iconFor(state.currentType), size: 56, color: const Color(0xFF6366F1)),
                const SizedBox(height: 8),
                Text(
                  _labelFor(state.currentType),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconFor(MotionType type) {
    switch (type) {
      case MotionType.walking:
        return Icons.directions_walk;
      case MotionType.running:
        return Icons.directions_run;
      case MotionType.stationary:
        return Icons.accessibility_new;
    }
  }

  String _labelFor(MotionType type) {
    switch (type) {
      case MotionType.walking:
        return 'Caminando';
      case MotionType.running:
        return 'Corriendo';
      case MotionType.stationary:
        return 'Quieto';
    }
  }
}
