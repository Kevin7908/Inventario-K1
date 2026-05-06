# Plan de Pruebas - InventarioK1 (Desktop)

## 1. Nombre del sistema y descripción breve

**Sistema:** InventarioK1

**Descripción:**  
Aplicación de escritorio multiplataforma (enfocada en Linux) diseñada para la gestión integral de inventarios. El sistema permite el control de existencias, administración de usuarios con seguridad criptográfica (Bcrypt), generación de reportes y persistencia de datos local mediante una arquitectura reactiva proporcionada por Drift y SQLite.

---

## 2. Tecnologías usadas

| Categoría | Tecnología |
|-----------|------------|
| Lenguaje de programación | Dart (^3.11.0) |
| Framework de desarrollo | Flutter Desktop |
| Base de datos | SQLite (Motor local) con el ORM Drift |
| Servidor | No aplica (Arquitectura de escritorio local / Offline-first) |
| Librerías clave | bcrypt (seguridad), get_it (inyección de dependencias), mailer (notificaciones) |

---

## 3. Alcance

### Módulos que se van a probar

| Módulo | Descripción |
|--------|-------------|
| **Seguridad y Acceso** | Validación de inicio de sesión, registro de usuarios y correcto hashing de contraseñas con Bcrypt |
| **Inventario (CRUD)** | Creación, lectura, actualización y eliminación de productos en la base de datos local |
| **Lógica de Negocio** | Cálculos de stock (entradas/salidas) y validaciones de datos (campos obligatorios, formatos de precio) |
| **Persistencia (Drift)** | Integridad de las tablas, relaciones entre datos y cierre seguro de conexiones |
| **Archivos** | Importación y exportación de archivos mediante el selector de archivos del sistema |

### Módulos que NO se van a probar

| Módulo | Motivo |
|--------|--------|
| **Infraestructura de red** | No se probará la disponibilidad de servidores SMTP externos para el envío de correos (se asume que el proveedor funciona) |
| **Drivers de Impresión** | No se probará la compatibilidad con hardware físico de impresión |
| **Desempeño bajo carga extrema** | Al ser una base de datos local para un solo usuario, no se realizarán pruebas de estrés masivo |

---

## 4. Tipos de prueba que se van a ejecutar

| Tipo de prueba | Herramienta | Descripción |
|----------------|-------------|-------------|
| **Pruebas Unitarias** | `flutter_test` | Validación de funciones lógicas aisladas, validadores de texto y lógica de encriptación |
| **Pruebas de Componentes** | `flutter_test` (Widget Tests) | Verificación de que los botones, formularios y tablas de la interfaz de escritorio respondan correctamente a los eventos |
| **Pruebas de Integración** | `integration_test` + Drift | Pruebas de flujo completo sobre la base de datos SQLite utilizando bases de datos en memoria para verificar los DAOs de Drift |
| **Pruebas de Mocks** | Mockito | Simulación de dependencias externas como el sistema de archivos o el servicio de correo para probar casos de éxito y error |

---

## 5. Ambiente de prueba

| Recurso | Especificación |
|---------|----------------|
| **Sistema Operativo** | Linux Ubuntu (Entorno nativo de ejecución) |
| **Navegador** | No aplica (Aplicación nativa de escritorio) |
| **SDK de Dart/Flutter** | Versión ^3.11.0 |
| **Base de Datos** | SQLite versión 3 (Gestionada por Drift) |
| **Entorno de ejecución de tests** | Terminal de Linux / Visual Studio Code Test Runner |
| **Herramientas de Soporte** | `sqlite3_test_utils` para la emulación de la base de datos en memoria |

---

## 6. Riesgos identificados y cómo se van a mitigar

| Riesgo | Impacto | Mitigación |
|--------|---------|-------------|
| Corrupción de la base de datos por apagado repentino del equipo | **Alto** | Implementar transacciones atómicas con Drift para asegurar que los datos no queden a medias |
| Acceso no autorizado al archivo local de base de datos | **Medio** | Uso de hashing Bcrypt para credenciales y recomendación de permisos de carpeta a nivel de sistema operativo |
| Pérdida de integridad en el conteo de stock por concurrencia | **Medio** | Utilizar streams reactivos de Drift para mantener la UI y la base de datos siempre sincronizadas |
| Error en la selección de archivos (formatos no compatibles) | **Bajo** | Implementar pruebas unitarias con Mockito que simulen la carga de archivos corruptos o extensiones no válidas para manejar excepciones |
| Fallo en envío de correos por falta de conexión | **Medio** | Implementar manejo de errores (Try-Catch) y mensajes de alerta al usuario indicando el estado de la conexión |

---

## 7. Aprobaciones

| Rol | Nombre | Fecha | Firma |
|-----|--------|------|-------|
| Líder de QA | [Apellido1] [Apellido2] | 06/05/2026 | - |
| Product Owner | Por definir | - | - |

---

**Versión del documento:** 1.0  
**Fecha de última actualización:** 06/05/2026  
**Estado:** Aprobado