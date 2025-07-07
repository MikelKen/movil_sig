import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/saved_location.dart';

class AddLocationDialog extends StatefulWidget {
  final LatLng position;
  final Function(SavedLocation) onLocationSaved;

  const AddLocationDialog({
    Key? key,
    required this.position,
    required this.onLocationSaved,
  }) : super(key: key);

  @override
  State<AddLocationDialog> createState() => _AddLocationDialogState();
}

class _AddLocationDialogState extends State<AddLocationDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  LocationType _selectedType = LocationType.other;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _saveLocation() {
    if (_formKey.currentState!.validate()) {
      final location = SavedLocation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        description:
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
        position: widget.position,
        type: _selectedType,
        createdAt: DateTime.now(),
      );

      widget.onLocationSaved(location);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final maxWidth = isTablet ? 600.0 : size.width * 0.9;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
      ),
      backgroundColor: theme.colorScheme.surface,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 28 : 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título responsive
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 12 : 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                      ),
                      child: Icon(
                        Icons.add_location_alt_rounded,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: isTablet ? 32 : 28,
                      ),
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    Expanded(
                      child: Text(
                        'Guardar Ubicación',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: isTablet ? 24 : 20,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isTablet ? 24 : 20),

                // Coordenadas responsive
                Container(
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: isTablet ? 20 : 18,
                          ),
                          SizedBox(width: isTablet ? 8 : 6),
                          Text(
                            'Coordenadas:',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: isTablet ? 16 : 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isTablet ? 8 : 6),
                      Text(
                        '${widget.position.latitude.toStringAsFixed(6)}, ${widget.position.longitude.toStringAsFixed(6)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: isTablet ? 14 : 12,
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(
                            0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isTablet ? 20 : 16),

                // Nombre responsive
                TextFormField(
                  controller: _nameController,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: isTablet ? 18 : 16,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nombre de la ubicación *',
                    hintText: 'Ej: Mi casa, Oficina, etc.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                    ),
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(isTablet ? 16 : 12),
                      child: Icon(Icons.edit_rounded, size: isTablet ? 24 : 20),
                    ),
                    contentPadding: EdgeInsets.all(isTablet ? 20 : 16),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    if (value.trim().length < 2) {
                      return 'El nombre debe tener al menos 2 caracteres';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: isTablet ? 20 : 16),

                // Descripción responsive
                TextFormField(
                  controller: _descriptionController,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: isTablet ? 16 : 14,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Descripción (opcional)',
                    hintText: 'Detalles adicionales sobre este lugar...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                    ),
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(isTablet ? 16 : 12),
                      child: Icon(
                        Icons.description_rounded,
                        size: isTablet ? 24 : 20,
                      ),
                    ),
                    contentPadding: EdgeInsets.all(isTablet ? 20 : 16),
                  ),
                  maxLines: isTablet ? 3 : 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                SizedBox(height: isTablet ? 20 : 16),

                // Tipo de ubicación responsive
                Text(
                  'Tipo de ubicación:',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: isTablet ? 12 : 8),
                Wrap(
                  spacing: isTablet ? 12 : 8,
                  runSpacing: isTablet ? 12 : 8,
                  children:
                      LocationType.values.map((type) {
                        final isSelected = _selectedType == type;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedType = type;
                            });
                          },
                          borderRadius: BorderRadius.circular(
                            isTablet ? 16 : 12,
                          ),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 16 : 12,
                              vertical: isTablet ? 12 : 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.surfaceContainerHigh
                                          .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(
                                isTablet ? 16 : 12,
                              ),
                              border:
                                  isSelected
                                      ? Border.all(
                                        color: theme.colorScheme.primary,
                                        width: 2,
                                      )
                                      : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  type.icon,
                                  style: TextStyle(
                                    fontSize: isTablet ? 20 : 18,
                                  ),
                                ),
                                SizedBox(width: isTablet ? 8 : 6),
                                Text(
                                  type.displayName,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontSize: isTablet ? 16 : 14,
                                    color:
                                        isSelected
                                            ? theme
                                                .colorScheme
                                                .onPrimaryContainer
                                            : theme.colorScheme.onSurface,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
                SizedBox(height: isTablet ? 32 : 24),

                // Botones responsive
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 24 : 20,
                          vertical: isTablet ? 16 : 12,
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(fontSize: isTablet ? 16 : 14),
                      ),
                    ),
                    SizedBox(width: isTablet ? 12 : 8),
                    ElevatedButton(
                      onPressed: _saveLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 28 : 24,
                          vertical: isTablet ? 16 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isTablet ? 16 : 12,
                          ),
                        ),
                      ),
                      child: Text(
                        'Guardar',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
