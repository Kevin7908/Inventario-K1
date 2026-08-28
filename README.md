# Inventario K1

Aplicación de gestión de inventarios desarrollada con **Flutter** y **SQLite** mediante **Drift** como ORM.

## Descripción

Inventario K1 es una app móvil que permite gestionar productos, movimientos de inventario, categorías y reportes. Toda la información se almacena localmente en SQLite, sin necesidad de conexión a internet.

## Arquitectura

El proyecto mantiene una **separación clara entre frontend y backend** por carpetas, cada uno con su propia organización por **features**.

### Flujo de alto nivel

Usuario → Frontend (UI + Estado) → Capa de Servicio → Backend (Lógica + Datos) → SQLite

### Flujo paso a paso

| Paso | Descripción |
|------|-------------|
| 1 | El usuario interactúa con la interfaz de Flutter |
| 2 | El frontend procesa el evento y prepara una solicitud |
| 3 | La capa de servicio comunica la solicitud al backend |
| 4 | El backend ejecuta la lógica de negocio (validaciones, cálculos) |
| 5 | Drift ORM ejecuta la operación en SQLite |
| 6 | El backend construye y devuelve una respuesta estructurada |
| 7 | El frontend actualiza la UI basada en la respuesta |

## Estructura de carpetas
´´´bash
lib/
├── frontend/                           # UI y presentación
│   ├── features/                       # Features del frontend
│   │   ├── products/                   # Pantallas de productos
│   │   │   ├── pages/
│   │   │   ├── widgets/
│   │   │   └── blocs/
│   │   ├── inventory/                  # Pantallas de inventario
│   │   ├── reports/                    # Pantallas de reportes
│   │   └── settings/                   # Pantallas de configuración
│   │
│   └── shared/                         # Compartido del frontend
│       ├── widgets/
│       ├── theme/
│       └── utils/
│
├── backend/                            # Lógica de negocio y datos
│   ├── features/                       # Features del backend
│   │   ├── products/                   # Lógica de productos
│   │   │   ├── controllers/
│   │   │   ├── services/
│   │   │   ├── repositories/
│   │   │   └── models/
│   │   ├── inventory/                  # Lógica de movimientos
│   │   ├── categories/                 # Lógica de categorías
│   │   └── reports/                    # Lógica de reportes
│   │
│   └── core/                           # Núcleo del backend
│       ├── database/                   # Drift + SQLite
│       │   ├── app_database.dart
│       │   └── migrations/
│       ├── di/                         # Inyección de dependencias
│       └── utils/
│
├── shared/                             # Compartido entre frontend y backend
│   ├── models/                         # Entidades comunes
│   ├── constants/
│   └── exceptions/
│
└── main.dart                           # Punto de entrada
´´´
## Stack tecnológico

| Capa | Tecnología |
|------|------------|
| Frontend | Flutter |
| Estado | Bloc / Riverpod |
| Backend local | Dart |
| ORM | Drift |
| Base de datos | SQLite |

## Buenas prácticas

- Separar frontend y backend por carpetas
- Cada feature tiene su propia estructura tanto en frontend como en backend
- Usar Drift para evitar SQL manual y errores de tipos
- Inyección de dependencias con Riverpod, un solo mecanismo para toda la app
- Validar datos en el backend, no solo en la UI
- Manejar errores y mostrar mensajes amigables
- Escribir pruebas unitarias para servicios y repositorios
- Usar `Streams` de Drift para datos reactivos en tiempo real

## Requisitos previos

- Flutter SDK (última versión estable)
- Dart SDK
- Editor de código (VS Code / Android Studio)

## Instalación

1. Clonar el repositorio
2. Ejecutar `flutter pub get`
3. Ejecutar `dart run build_runner build` (para generar el código de Drift)
4. Copiar `.env.ejemplo` como `.env` y llenar las credenciales de correo
5. Ejecutar `flutter run`

### El archivo `.env`

Las credenciales del servidor SMTP —la cuenta desde la que salen los correos y
su contraseña de aplicación— viven en un `.env` en la raíz del proyecto, o
junto al ejecutable en una instalación real. **Está en `.gitignore` y no sube
al repositorio.** `.env.ejemplo` documenta las claves.

Si el archivo falta, la app arranca igual: lo único que deja de funcionar es el
envío de correos, y recuperar la contraseña lo dice en pantalla en vez de
fallar en silencio.

## Características principales

- CRUD de productos
- Control de entradas y salidas de inventario
- Gestión de categorías
- Reportes básicos
- Búsqueda y filtros
- Almacenamiento local sin internet

