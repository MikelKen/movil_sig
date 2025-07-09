// widgets/navigation_completion_dialog.dart
import 'package:flutter/material.dart';

class NavigationCompletionDialog extends StatelessWidget {
  final int totalDeliveries;
  final int completedDeliveries;
  final String totalTime;
  final String totalDistance;

  const NavigationCompletionDialog({
    super.key,
    required this.totalDeliveries,
    required this.completedDeliveries,
    required this.totalTime,
    required this.totalDistance,
  });

  @override
  Widget build(BuildContext context) {
    final isAllCompleted = completedDeliveries == totalDeliveries;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Column(
        children: [
          Icon(
            isAllCompleted ? Icons.celebration : Icons.check_circle,
            color: Colors.green,
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            isAllCompleted ? '¡Felicitaciones!' : 'Navegación Finalizada',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAllCompleted)
            const Text(
              'Has completado todas las entregas exitosamente',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            )
          else
            Text(
              'Navegación detenida con $completedDeliveries de $totalDeliveries entregas completadas',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Entregas completadas:'),
                    Text(
                      '$completedDeliveries/$totalDeliveries',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tiempo total:'),
                    Text(
                      totalTime,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Distancia recorrida:'),
                    Text(
                      totalDistance,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (!isAllCompleted) ...[
            const SizedBox(height: 16),
            const Text(
              'Puedes continuar las entregas restantes más tarde.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
        if (isAllCompleted)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Aquí podrías agregar funcionalidad adicional como:
              // - Generar reporte de entregas
              // - Compartir resumen
              // - etc.
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ver Resumen'),
          ),
      ],
    );
  }
}

// Función helper para mostrar el diálogo
Future<void> showNavigationCompletionDialog(
    BuildContext context, {
      required int totalDeliveries,
      required int completedDeliveries,
      required String totalTime,
      required String totalDistance,
    }) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => NavigationCompletionDialog(
      totalDeliveries: totalDeliveries,
      completedDeliveries: completedDeliveries,
      totalTime: totalTime,
      totalDistance: totalDistance,
    ),
  );
}