# Mapa Interactivo - App de Ubicaciones

Una aplicación interactiva de mapas que permite marcar, guardar y gestionar ubicaciones personalizadas, construida con Flutter y Google Maps API.

## ✨ Características Principales

- **🗺️ Mapa interactivo** con Google Maps integrado
- **📍 Marcado de ubicaciones** tocando en cualquier lugar del mapa
- **💾 Almacenamiento local** de ubicaciones guardadas
- **🎯 Detección de ubicación actual** usando GPS
- **🏷️ Categorización** de ubicaciones (casa, trabajo, restaurante, etc.)
- **✏️ Edición y eliminación** de ubicaciones guardadas
- **📱 Interfaz moderna** con diseño Material 3
- **🎨 Marcadores coloridos** según el tipo de ubicación

## 🚀 Funcionalidades Implementadas

### 🗺️ Mapa Interactivo
- **Integración completa** con Google Maps
- **Detección automática** de ubicación actual mediante GPS
- **Navegación fluida** con controles intuitivos
- **Marcadores personalizados** según el tipo de ubicación

### 📍 Sistema de Marcado
- **Toca para marcar**: Simplemente toca cualquier lugar del mapa
- **Categorías disponibles**: Casa 🏠, Trabajo 🏢, Restaurante 🍽️, Tienda 🛒, Hospital 🏥, Escuela 🏫, Gasolinera ⛽, Otros 📍
- **Información detallada**: Nombre, descripción y coordenadas
- **Marcadores coloridos**: Cada tipo tiene su propio color

### 💾 Gestión de Ubicaciones
- **Almacenamiento local** persistente usando SharedPreferences
- **Lista organizada** de ubicaciones guardadas
- **Búsqueda y navegación** rápida a cualquier ubicación
- **Edición y eliminación** con confirmación

### 📱 Interfaz de Usuario
- **Panel deslizable** en la parte inferior con lista de ubicaciones
- **Diálogos intuitivos** para agregar/editar ubicaciones
- **Botón de ubicación actual** con indicador de carga
- **Diseño Material 3** moderno y responsive

## Configuración y Instalación

### Prerrequisitos
- Flutter SDK instalado
- Android Studio o Xcode (para desarrollo móvil)
- Google Maps API Key configurada

### Instalación

1. **Clonar el repositorio**
   ```bash
   git clone <url-del-repositorio>
   cd sig
   ```

2. **Instalar dependencias**
   ```bash
   flutter pub get
   ```

3. **Configurar API Key**
   - La API Key ya está configurada en el código: `AIzaSyDbpv3i7Tno3aicF4_1GnUUHGQLFo1GOLY`
   - Asegúrate de que las siguientes APIs estén habilitadas en Google Cloud Console:
     - Maps SDK for Android
     - Maps SDK for iOS
     - Directions API

4. **Ejecutar la aplicación**
   ```bash
   flutter run
   ```

## 📁 Estructura del Proyecto

```
lib/
├── main.dart                          # Punto de entrada de la aplicación
├── models/
│   └── saved_location.dart            # Modelo de datos para ubicaciones
├── screens/
│   ├── interactive_map_screen.dart    # Pantalla principal interactiva
│   └── simple_map_screen.dart         # Pantalla simple (deprecada)
├── services/
│   ├── location_service.dart          # Servicio para manejo de GPS
│   ├── directions_service.dart        # Servicio para Google Directions API
│   └── storage_service.dart           # Servicio de almacenamiento local
├── widgets/
│   ├── add_location_dialog.dart       # Diálogo para agregar ubicaciones
│   └── location_list_panel.dart       # Panel de lista de ubicaciones
└── utils/
    └── constants.dart                 # Constantes de la aplicación
```

## 📱 Uso de la Aplicación

### Al Iniciar
1. La app solicitará permisos de ubicación
2. Se mostrará el mapa centrado en tu ubicación actual (o Santa Cruz por defecto)
3. Verás el panel deslizable inferior con "Ubicaciones Guardadas"

### Para Marcar una Ubicación
1. **Toca en cualquier lugar del mapa** 📍
2. Se abrirá un diálogo para agregar la ubicación
3. **Llena los datos**:
   - Nombre (obligatorio)
   - Descripción (opcional)
   - Tipo de ubicación (selecciona una categoría)
4. **Toca "Guardar"** ✅

### Para Gestionar Ubicaciones
- **Ver ubicaciones**: Desliza el panel inferior hacia arriba
- **Ir a una ubicación**: Toca cualquier tarjeta de ubicación
- **Ver detalles**: Toca un marcador en el mapa
- **Editar/Eliminar**: Usa el menú de 3 puntos en cada tarjeta

### Controles Disponibles
- **Botón azul flotante** (🎯): Actualiza y centra en tu ubicación actual
- **Panel deslizable**: Arrastra hacia arriba/abajo para ver más ubicaciones
- **Marcadores en el mapa**: Toca para ver información detallada

## Personalización

### Cambiar Destino
Para cambiar el destino predeterminado, edita el archivo `lib/screens/map_screen.dart`:

```dart
// Línea 65: Cambiar las coordenadas del destino
_setDestination(LatLng(-17.7833, -63.1822)); // Santa Cruz, Bolivia
```

### Personalizar Estilo del Mapa
Puedes modificar los colores y estilo en `lib/screens/map_screen.dart`:

```dart
// Cambiar color de la ruta
color: Colors.blue, // Línea 152

// Cambiar colores de los marcadores
icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
```

## Solución de Problemas

### Error de Instalación en Android
Si obtienes el error "INSTALL_FAILED_USER_RESTRICTED":
1. Habilita las opciones de desarrollador en tu dispositivo
2. Activa "Instalación via USB" o "Instalar apps via USB"
3. Asegúrate de que la depuración USB esté habilitada

### Problemas de Permisos
Si la app no puede acceder a la ubicación:
1. Ve a Configuración > Aplicaciones > Tu App > Permisos
2. Otorga permisos de ubicación
3. Reinicia la aplicación

### API Key Issues
Si el mapa no se carga:
1. Verifica que la API Key esté correctamente configurada
2. Asegúrate de que las APIs necesarias estén habilitadas en Google Cloud Console
3. Revisa los límites de cuota de tu API Key

## Tecnologías Utilizadas

- **Flutter**: Framework de desarrollo
- **Google Maps Flutter**: Plugin para mapas
- **Google Directions API**: Para cálculo de rutas
- **Location**: Plugin para ubicación
- **Geolocator**: Para cálculos geográficos
- **HTTP**: Para peticiones a APIs
- **Flutter Polyline Points**: Para decodificar polylines

## Próximas Mejoras

- [ ] Permitir selección de destino tocando el mapa
- [ ] Agregar múltiples paradas
- [ ] Implementar diferentes tipos de vehículos
- [ ] Añadir estimaciones de costo
- [ ] Integrar con servicios de pago
- [ ] Modo nocturno para el mapa
- [ ] Notificaciones push
- [ ] Historial de viajes

## Contribución

Si deseas contribuir al proyecto:

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## Licencia

Este proyecto está licenciado bajo la Licencia MIT - ver el archivo LICENSE para más detalles.

## Contacto

Para preguntas o sugerencias, puedes contactar al equipo de desarrollo.

---

**¡Disfruta creando tu aplicación de delivery!** 🚀📱
