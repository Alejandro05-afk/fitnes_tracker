import 'dart:async';
import 'package:flutter/material.dart';

class FallConfirmationDialog extends StatefulWidget {
  const FallConfirmationDialog({super.key, required this.onResolved});

  final VoidCallback onResolved;

  static Future<void> show(BuildContext context, VoidCallback onResolved) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => FallConfirmationDialog(onResolved: onResolved),
    );
  }

  @override
  State<FallConfirmationDialog> createState() => _FallConfirmationDialogState();
}

class _FallConfirmationDialogState extends State<FallConfirmationDialog> {
  Timer? _reinforceTimer;
  bool _showReinforcement = false;

  @override
  void initState() {
    super.initState();
    // Si no hay respuesta en 15s, refuerza el mensaje (enunciado punto 1.3).
    _reinforceTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() => _showReinforcement = true);
    });
  }

  void _resolve() {
    _reinforceTimer?.cancel();
    widget.onResolved();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _reinforceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
      title: const Text('¿Estás bien?'),
      content: Text(
        _showReinforcement
            ? 'Detectamos que no has respondido. Por favor confirma si estás bien o '
              'busca ayuda si la necesitas.'
            : 'Detectamos un posible impacto fuerte. Confirma que estás bien.',
      ),
      actions: [
        TextButton(
          onPressed: _resolve,
          child: const Text('Estoy bien'),
        ),
      ],
    );
  }
}
