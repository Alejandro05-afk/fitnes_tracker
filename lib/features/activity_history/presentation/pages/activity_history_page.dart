import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/activity_history_bloc.dart';
import '../../domain/entities/activity_record.dart';

class ActivityHistoryPage extends StatefulWidget {
  const ActivityHistoryPage({super.key});

  @override
  State<ActivityHistoryPage> createState() => _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends State<ActivityHistoryPage> {
  @override
  void initState() {
    super.initState();
    context.read<ActivityHistoryBloc>().add(LoadActivityHistory());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Actividad'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocBuilder<ActivityHistoryBloc, ActivityHistoryState>(
        builder: (context, state) {
          if (state is ActivityHistoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ActivityHistoryError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${state.message}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<ActivityHistoryBloc>().add(LoadActivityHistory()),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (state is ActivityHistoryLoaded) {
            if (state.records.isEmpty) {
              return const Center(
                child: Text(
                  'No hay registros de actividad',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.records.length,
              itemBuilder: (context, index) {
                final record = state.records[index];
                return Dismissible(
                  key: ValueKey(record.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    context
                        .read<ActivityHistoryBloc>()
                        .add(DeleteActivityHistory(record.id!));
                  },
                  child: _ActivityRecordCard(
                    record: record,
                    onTap: () => _showEditDialog(context, record),
                  ),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    _showFormDialog(context);
  }

  void _showEditDialog(BuildContext context, ActivityRecord record) {
    _showFormDialog(context, record: record);
  }

  void _showFormDialog(BuildContext context, {ActivityRecord? record}) {
    final activityTypes = ['stationary', 'walking', 'running'];
    String selectedType = record?.activityType ?? 'walking';
    final stepController =
        TextEditingController(text: record?.stepCount.toString() ?? '0');
    final distController =
        TextEditingController(text: record?.distanceKm.toStringAsFixed(2) ?? '0');
    final durController = TextEditingController(
        text: record?.durationSeconds.toString() ?? '0');
    final calController =
        TextEditingController(text: record?.calories.toStringAsFixed(1) ?? '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(record == null ? 'Nuevo registro' : 'Editar registro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: activityTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
                TextField(
                  controller: stepController,
                  decoration: const InputDecoration(labelText: 'Pasos'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: distController,
                  decoration: const InputDecoration(labelText: 'Distancia (km)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: durController,
                  decoration: const InputDecoration(labelText: 'Duración (seg)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: calController,
                  decoration: const InputDecoration(labelText: 'Calorías'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final now = DateTime.now();
                final newRecord = ActivityRecord(
                  id: record?.id,
                  activityType: selectedType,
                  stepCount: int.tryParse(stepController.text) ?? 0,
                  distanceKm: double.tryParse(distController.text) ?? 0,
                  durationSeconds: int.tryParse(durController.text) ?? 0,
                  calories: double.tryParse(calController.text) ?? 0,
                  startTime: record?.startTime ?? now,
                  endTime: record?.endTime ?? now,
                  createdAt: record?.createdAt ?? now,
                );
                if (record == null) {
                  context
                      .read<ActivityHistoryBloc>()
                      .add(CreateActivityHistory(newRecord));
                } else {
                  context
                      .read<ActivityHistoryBloc>()
                      .add(UpdateActivityHistory(newRecord));
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRecordCard extends StatelessWidget {
  final ActivityRecord record;
  final VoidCallback onTap;

  const _ActivityRecordCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: _colorForType(record.activityType),
          child: Icon(
            _iconForType(record.activityType),
            color: Colors.white,
          ),
        ),
        title: Text(
          record.activityType == 'walking'
              ? 'Caminata'
              : record.activityType == 'running'
                  ? 'Carrera'
                  : 'Sin movimiento',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${record.stepCount} pasos  ·  ${record.distanceKm.toStringAsFixed(2)} km  ·  ${record.calories.toStringAsFixed(0)} cal',
        ),
        trailing: Text(
          '${record.durationSeconds ~/ 60} min',
          style: const TextStyle(color: Colors.grey),
        ),
        onTap: onTap,
      ),
    );
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'running':
        return Colors.red;
      case 'walking':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'running':
        return Icons.directions_run;
      case 'walking':
        return Icons.directions_walk;
      default:
        return Icons.accessibility_new;
    }
  }
}
