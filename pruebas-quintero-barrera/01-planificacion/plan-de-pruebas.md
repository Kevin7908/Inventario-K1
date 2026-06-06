# Plan de Pruebas - InventarioK1 (Desktop)

## 1. Nombre del sistema y descripción breve

**Sistema:** InventarioK1

**Descripción:**  
Aplicación de escritorio multiplataforma (Linux/Windows/Mac) para la gestión integral de un taller de motos. Cubre inicio de sesión con hashing BCrypt, gestión de inventario de productos (módulo maestro), registro de ventas/facturas (módulo transaccional) y demás entidades de apoyo. Toda la persistencia es local mediante SQLite gestionado por el ORM Drift.

---

## 2. Tecnologías usadas

| Categoría | Tecnología |
|-----------|------------|
| Lenguaje de programación | Dart (^3.11.0) |
| Framework de desarrollo | Flutter Desktop |
| Base de datos | SQLite (motor local) con el ORM Drift v2.32 |
| Servidor | No aplica — arquitectura offline-first, sin backend remoto |
| Librerías clave | bcrypt (seguridad), get_it (inyección de dependencias), flutter_riverpod (estado), equatable (comparación de modelos) |

---

## 3. Alcance

### Módulos que se van a probar

| Módulo | Descripción |
|--------|-------------|
| **Login (Autenticación)** | Validación de credenciales, hashing con BCrypt, bloqueo de usuarios inactivos, manejo de excepciones de acceso |
| **Maestro (Productos)** | CRUD completo de productos: creación con campos obligatorios, edición, eliminación con validación de dependencias, cálculos de precio con IVA y margen de ganancia, control de stock |
| **Transaccional (Ventas / Facturas)** | Registro de facturas de venta directa y ventas ligadas a órdenes de servicio, cálculo de totales, filtros por tipo de ítem (producto/servicio), verificación en base de datos |

### Módulos que NO se van a probar

| Módulo | Motivo |
|--------|--------|
| **Cotizaciones** | Módulo en desarrollo activo en la rama `feature/cotizaciones`; inestable para pruebas |
| **Infraestructura de red (SMTP)** | No se prueba disponibilidad de servidores de correo externos |
| **Drivers de impresión** | Sin hardware físico disponible en ambiente de prueba |
| **Órdenes de servicio** | Complejidad de dependencias (moto, cliente, técnico, repuestos); se prioriza Ventas directas |

---

## 4. Tipos de prueba que se van a ejecutar

| Tipo | Herramienta | Módulo | Descripción |
|------|-------------|--------|-------------|
| **Pruebas Unitarias** | `flutter_test` | Login, Productos, Ventas | Validación de lógica pura de modelos (IVA, margen, estado de stock) y excepciones de autenticación (BCrypt) |
| **Pruebas Funcionales (Casos de prueba)** | Ejecución manual + `flutter_test` (widget tests) | Login, Productos, Ventas | Flujos de usuario completos: login exitoso/fallido, CRUD de productos, registro de factura |
| **Pruebas de Repositorio** | `flutter_test` + Drift in-memory | Login, Productos, Ventas | Pruebas del acceso a datos reales mediante una base de datos SQLite en memoria; equivalente a las pruebas de API para apps web |

> **Nota de adaptación:** Al ser una app de escritorio local sin REST API, la **Fase 4 (Pruebas de API con Postman)** se reemplaza por **pruebas del repositorio Drift** usando una base de datos en memoria (`NativeDatabase.memory()`). Este enfoque prueba la misma capa — la capa de datos — con la misma rigurosidad.

---

## 5. Ambiente de prueba

| Recurso | Especificación |
|---------|----------------|
| **Sistema Operativo** | Linux Ubuntu 24.04 (entorno nativo) |
| **Navegador** | No aplica — aplicación de escritorio nativa |
| **SDK de Dart / Flutter** | ^3.11.0 |
| **Base de datos** | SQLite 3 (gestionada por Drift; en memoria para pruebas) |
| **Entorno de ejecución** | Terminal Linux — `flutter test <ruta_del_archivo>` desde la raíz del proyecto |
| **IDE** | Visual Studio Code con extensión Flutter/Dart |

---

## 6. Riesgos identificados y mitigación

| Riesgo | Impacto | Mitigación |
|--------|---------|------------|
| Modelo Producto permite `precioVenta < precioCompra` sin validación | **Alto** | Documentado como BUG-001; agregar validación en la capa de ViewModel antes de persistir |
| Mensaje de excepción incorrecto al duplicar nombre de usuario | **Medio** | Documentado como BUG-002; corregir el mensaje por defecto de `UsuarioYaExisteException` |
| Stock puede volverse negativo sin bloqueo explícito en el modelo | **Medio** | Documentado como BUG-003; agregar validación en `ajustarStock` del repositorio |
| Corrupción de la BD por apagado abrupto | **Alto** | Drift usa WAL mode (`PRAGMA journal_mode = WAL`) — protección ya implementada |
| Acceso no autorizado al archivo `.sqlite` local | **Medio** | Hashing BCrypt para contraseñas; acceso físico al equipo queda fuera del alcance |

---

## 7. Aprobaciones

| Rol | Nombre | Fecha | Firma |
|-----|--------|------|-------|
| Líder de QA | Quintero Barrera | 03/06/2026 | — |
| Product Owner | Por definir | — | — |

---

**Versión del documento:** 2.0  
**Fecha de última actualización:** 03/06/2026  
**Estado:** Aprobado para ejecución de pruebas
