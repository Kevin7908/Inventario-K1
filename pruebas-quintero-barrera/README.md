# Repositorio de Pruebas - InventarioK1 (Desktop)

Este repositorio contiene la documentación y evidencias del proceso de QA para la aplicación de escritorio **InventarioK1**, desarrollada con Flutter y Drift (SQLite). El enfoque de pruebas es local y offline-first.

**Estudiante:** Quintero Barrera 
**Plataforma:** Windows / Linux Desktop  
**Tecnologías de Pruebas:** `flutter_test`, `mockito`, `integration_test`, `drift_dev`

---

## 📂 Estructura del Repositorio

pruebas-quintero-barrera/
|
|-- README.md
|
|-- 01-planificacion/
| |-- plan-de-pruebas.md
| |-- criterios-aceptacion.md
|
|-- 02-pruebas-unitarias/
| |-- src/test/dart/database/
| | |-- database_test.dart
| | |-- auth_test.dart
| | |-- mocks.dart
| |-- evidencias/
| |-- resultado-flutter-test-20260506.png
|
|-- 03-pruebas-funcionales/
| |-- casos-de-prueba-ejecutados.docx
| |-- integration-suite.dart
| |-- evidencias/
| |-- CP-001-registro-producto.png
| |-- CP-002-login-exitoso.png
|
|-- 04-pruebas-api/
| |-- internal-services-mock.json
| |-- reporte-logic-test.html
| |-- evidencias/
| |-- logic-mailer-test.png
|
|-- 05-base-de-datos/
| |-- datos-prueba.sql
| |-- pruebas-integridad.sql
| |-- evidencias/
| |-- drift-inspector-result.png
| |-- integridad-relacional.png
|
|-- 06-seguridad/
| |-- reporte-seguridad-local.html
| |-- evidencias/
| |-- bcrypt-verification.png
| |-- local-file-permissions.png
|
|-- 07-entrega-final/
| |-- reporte-final.docx
| |-- video-screencast.mp4
| |-- video-presentacion.mp4

---

## Descripción de cada carpeta

### 01-planificacion/
Documentación estratégica de las pruebas:
- **plan-de-pruebas.md:** Estrategia orientada a una app de escritorio con persistencia local.
- **criterios-aceptacion.md:** Reglas de negocio (Ej: validación de stock, encriptación de claves con bcrypt).

### 02-pruebas-unitarias/
Pruebas de lógica pura y DAOs de Drift usando **Base de Datos en Memoria**:

| Archivo | Descripción |
|---------|-------------|
| `database_test.dart` | CRUD de productos con Drift (crear, leer, actualizar, eliminar) |
| `auth_test.dart` | Validación de hashes con Bcrypt (encriptación y verificación) |
| `mocks.dart` | Uso de Mockito para simular el envío de correos con mailer |

**Evidencia:** `resultado-flutter-test-[fecha].png` (Captura de la terminal con todos los tests en verde)

### 03-pruebas-funcionales/
Validación de la interfaz de usuario (UI) en entorno Desktop:

| Archivo | Descripción |
|---------|-------------|
| `casos-de-prueba-ejecutados.docx` | Listado de flujos manuales (Ej: "Crear producto con imagen") |
| `integration-suite.dart` | Scripts de `integration_test` para automatizar clics en la app de escritorio |

**Evidencias:**
- `CP-001-registro-producto.png`
- `CP-002-login-exitoso.png`

### 04-pruebas-api/
> **Nota:** Al ser una app local, este módulo se enfoca en la comunicación entre la lógica de negocio y los servicios internos.

| Archivo | Descripción |
|---------|-------------|
| `internal-services-mock.json` | Simulación de respuestas de servicios (Mocking) |
| `reporte-logic-test.html` | Resultado de las pruebas de los servicios de importación/exportación de archivos |

**Evidencia:** `logic-mailer-test.png` (Prueba de que el servicio de correo se integra correctamente)

### 05-base-de-datos/
Pruebas directas sobre el archivo `.sqlite` generado por Drift:

| Archivo | Descripción |
|---------|-------------|
| `datos-prueba.sql` | Script para insertar datos iniciales en la base local |
| `pruebas-integridad.sql` | Queries de verificación (Ej: que no existan productos sin categoría) |

**Evidencias:**
- `drift-inspector-result.png` (Captura usando Drift Inspector o SQLite Browser)
- `integridad-relacional.png`

### 06-seguridad/
Análisis de la seguridad de la base de datos y cifrado:

| Archivo | Descripción |
|---------|-------------|
| `reporte-seguridad-local.html` | Análisis de seguridad de la base de datos local |

**Evidencias:**
- `bcrypt-verification.png` (Prueba de que la clave no es legible en la DB)
- `local-file-permissions.png`

### 07-entrega-final/
Entregables finales del proyecto de pruebas:

| Archivo | Descripción |
|---------|-------------|
| `reporte-final.docx` | Resumen de la calidad del software |
| `video-screencast.mp4` | Demostración de la app funcionando en el escritorio (Linux/Windows) |
| `video-presentacion.mp4` | Explicación de los hallazgos de las pruebas |

---

## Herramientas de Pruebas Utilizadas

| Herramienta | Propósito |
|-------------|-----------|
| `flutter_test` | Core para pruebas unitarias y de widgets |
| `Drift (Native Database en memoria)` | Probar la persistencia sin ensuciar el disco |
| `Mockito` | Crear objetos simulados del servicio de correo (`mailer`) y de selección de archivos (`file_picker`) |
| `Integration Test` | Simular interacciones de usuario reales en la versión de escritorio |

---