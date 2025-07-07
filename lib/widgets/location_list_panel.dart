import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/saved_location.dart';

class LocationListPanel extends StatelessWidget {
  final List<SavedLocation> locations;
  final Function(SavedLocation) onLocationTap;
  final Function(SavedLocation) onLocationEdit;
  final Function(SavedLocation) onLocationDelete;

  const LocationListPanel({
    Key? key,
    required this.locations,
    required this.onLocationTap,
    required this.onLocationEdit,
    required this.onLocationDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return DraggableScrollableSheet(
      initialChildSize: isTablet ? 0.4 : 0.3,
      minChildSize: isTablet ? 0.15 : 0.1,
      maxChildSize: isTablet ? 0.85 : 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(isTablet ? 28 : 24),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, -4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle para arrastrar - responsive
              Container(
                margin: EdgeInsets.symmetric(vertical: isTablet ? 12 : 8),
                height: isTablet ? 5 : 4,
                width: isTablet ? 50 : 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(isTablet ? 2.5 : 2),
                ),
              ),

              // Encabezado responsive
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 28 : 20,
                  vertical: isTablet ? 16 : 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 12 : 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(
                          0.8,
                        ),
                        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                      ),
                      child: Icon(
                        Icons.bookmarks_rounded,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: isTablet ? 28 : 24,
                      ),
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    Expanded(
                      child: Text(
                        'Ubicaciones Guardadas',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: isTablet ? 22 : 18,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 12 : 8,
                        vertical: isTablet ? 6 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                      ),
                      child: Text(
                        '${locations.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 14 : 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),

              // Lista de ubicaciones responsive
              Expanded(
                child:
                    locations.isEmpty
                        ? _buildEmptyState(context, isTablet)
                        : ListView.separated(
                          controller: scrollController,
                          padding: EdgeInsets.all(isTablet ? 24 : 16),
                          itemCount: locations.length,
                          separatorBuilder:
                              (context, index) =>
                                  SizedBox(height: isTablet ? 12 : 8),
                          itemBuilder: (context, index) {
                            final location = locations[index];
                            return _buildLocationCard(
                              context,
                              location,
                              isTablet,
                            );
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isTablet) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 32 : 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off_rounded,
              size: isTablet ? 64 : 48,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
            SizedBox(height: isTablet ? 16 : 12),
            Text(
              'No hay ubicaciones guardadas',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: isTablet ? 8 : 6),
            Text(
              'Toca en el mapa para guardar ubicaciones',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: isTablet ? 14 : 12,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(
    BuildContext context,
    SavedLocation location,
    bool isTablet,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: isTablet ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: () => onLocationTap(location),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Ícono del tipo - responsive
                  Container(
                    padding: EdgeInsets.all(isTablet ? 12 : 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(
                        0.7,
                      ),
                      borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                    ),
                    child: Text(
                      location.type.icon,
                      style: TextStyle(fontSize: isTablet ? 24 : 20),
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),

                  // Información principal - responsive
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isTablet ? 4 : 2),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 8 : 6,
                            vertical: isTablet ? 4 : 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer
                                .withOpacity(0.6),
                            borderRadius: BorderRadius.circular(
                              isTablet ? 8 : 6,
                            ),
                          ),
                          child: Text(
                            location.type.displayName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: isTablet ? 12 : 10,
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Menú de opciones - responsive
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: isTablet ? 24 : 20,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onLocationEdit(location);
                          break;
                        case 'delete':
                          _showDeleteConfirmation(context, location);
                          break;
                      }
                    },
                    itemBuilder:
                        (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_rounded,
                                  size: isTablet ? 22 : 20,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                SizedBox(width: isTablet ? 12 : 8),
                                Text(
                                  'Editar',
                                  style: TextStyle(
                                    fontSize: isTablet ? 16 : 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_rounded,
                                  size: isTablet ? 22 : 20,
                                  color: theme.colorScheme.error,
                                ),
                                SizedBox(width: isTablet ? 12 : 8),
                                Text(
                                  'Eliminar',
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontSize: isTablet ? 16 : 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                  ),
                ],
              ),

              if (location.description != null) ...[
                SizedBox(height: isTablet ? 12 : 8),
                Container(
                  padding: EdgeInsets.all(isTablet ? 12 : 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                  ),
                  child: Text(
                    location.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: isTablet ? 15 : 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              SizedBox(height: isTablet ? 16 : 12),

              // Información adicional - responsive
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: isTablet ? 18 : 16,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                  SizedBox(width: isTablet ? 6 : 4),
                  Expanded(
                    child: Text(
                      '${location.position.latitude.toStringAsFixed(4)}, ${location.position.longitude.toStringAsFixed(4)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: isTablet ? 13 : 12,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(
                          0.7,
                        ),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 8 : 6,
                      vertical: isTablet ? 4 : 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(isTablet ? 8 : 6),
                    ),
                    child: Text(
                      _formatDate(location.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: isTablet ? 12 : 10,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(
                          0.8,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, SavedLocation location) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar Ubicación'),
            content: Text(
              '¿Estás seguro de que quieres eliminar "${location.name}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onLocationDelete(location);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
