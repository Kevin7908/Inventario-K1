# Criterios de Aceptación - InventarioK1 (Desktop)

## Documento de Especificación de Criterios de Aceptación

| Versión | Fecha | Autor | Descripción |
|---------|-------|-------|-------------|
| 1.0 | 06/05/2026 | Quintero Barrera | Creación inicial del documento |

---

## Módulo de Autenticación

| ID | Módulo | Prioridad | Criterio de Aceptación |
|----|--------|-----------|------------------------|
| CA-001 | Autenticación | **Alta** | Dado un usuario registrado, cuando ingresa credenciales válidas, entonces el sistema redirige al Dashboard principal en menos de 2 segundos. |
| CA-002 | Autenticación | **Alta** | Dado un usuario con contraseña incorrecta, cuando intenta iniciar sesión, entonces el sistema muestra el mensaje "Usuario o contraseña incorrectos" y permanece en el login. |
| CA-003 | Autenticación | **Alta** | Dado el formulario de registro, cuando se ingresan datos válidos, entonces el sistema aplica hash con Bcrypt a la contraseña y guarda el usuario en la base de datos SQLite. |
| CA-004 | Autenticación | **Media** | Dado un nombre de usuario que ya existe en la base de datos, cuando se intenta registrar, entonces el sistema muestra un error de "Usuario duplicado". |
| CA-005 | Autenticación | **Alta** | Dado un intento de registro, cuando los campos de "Contraseña" y "Confirmar Contraseña" no coinciden, entonces el sistema impide la creación y muestra una advertencia. |
| CA-006 | Autenticación | **Media** | Dado el campo de contraseña en el registro, cuando se ingresa una clave menor a 6 caracteres, entonces el sistema activa una validación visual de longitud mínima. |
| CA-007 | Autenticación | **Alta** | Dado un usuario autenticado, cuando presiona el botón de "Cerrar Sesión", entonces el sistema limpia la sesión de GetIt/Provider y redirige a la pantalla de Login. |

---

## Módulo Maestro (Gestión de Productos)

| ID | Módulo | Prioridad | Criterio de Aceptación |
|----|--------|-----------|------------------------|
| CA-008 | Maestro | **Alta** | Dado un nuevo producto, cuando se completan todos los campos obligatorios (nombre, precio, stock), entonces el registro se persiste correctamente mediante Drift. |
| CA-009 | Maestro | **Alta** | Dado un producto sin nombre o sin precio, cuando se intenta guardar, entonces el sistema resalta los campos vacíos en rojo y no ejecuta la inserción. |
| CA-010 | Maestro | **Alta** | Dado un producto existente, cuando se modifica su precio o descripción, entonces el cambio se refleja inmediatamente en el listado principal de la aplicación. |
| CA-011 | Maestro | **Media** | Dado un producto en el listado, cuando el usuario presiona el botón de eliminar, entonces el sistema solicita una confirmación mediante un diálogo antes de borrar de SQLite. |
| CA-012 | Maestro | **Media** | Dado un código de producto (SKU) ya existente, cuando se intenta crear uno nuevo con el mismo código, entonces el sistema muestra un error de integridad de datos. |
| CA-013 | Maestro | **Baja** | Dado el buscador de productos, cuando se ingresa el nombre de un artículo, entonces el listado se filtra en tiempo real mostrando solo las coincidencias encontradas. |
| CA-014 | Maestro | **Media** | Dado el selector de archivos, cuando se selecciona una imagen para un producto, entonces el sistema guarda la ruta local de la imagen y la muestra en la vista previa. |

---

## Módulo Transaccional (Ventas / Movimientos de Stock)

| ID | Módulo | Prioridad | Criterio de Aceptación |
|----|--------|-----------|------------------------|
| CA-015 | Transaccional | **Alta** | Dado un producto seleccionado en el módulo de ventas, cuando se agrega al carrito, entonces el sistema calcula el subtotal multiplicando la cantidad por el precio unitario. |
| CA-016 | Transaccional | **Alta** | Dado un producto con stock insuficiente, cuando se intenta agregar a la venta una cantidad mayor a la disponible, entonces el sistema impide la acción y notifica al usuario. |
| CA-017 | Transaccional | **Alta** | Dado un carrito con múltiples artículos, cuando se confirma la venta, entonces el sistema genera un registro en la tabla de ventas y resta automáticamente el stock en la tabla de productos. |
| CA-018 | Transaccional | **Media** | Dado el proceso de venta, cuando se elimina un ítem del carrito antes de finalizar, entonces el total de la venta se recalcula automáticamente eliminando el costo de dicho ítem. |
| CA-019 | Transaccional | **Media** | Dado un intento de finalizar una venta con el carrito vacío, cuando se presiona "Confirmar", entonces el sistema muestra un mensaje de validación indicando que debe agregar productos. |
| CA-020 | Transaccional | **Alta** | Dado el cierre de una venta exitosa, cuando se guarda la transacción, entonces el sistema limpia el carrito y queda listo para una nueva operación de venta. |

---

## Resumen de Criterios por Módulo

| Módulo | Total de Criterios | Alta | Media | Baja |
|--------|-------------------|------|-------|------|
| Autenticación | 7 | 5 | 2 | 0 |
| Maestro | 7 | 3 | 3 | 1 |
| Transaccional | 6 | 4 | 2 | 0 |
| **Total** | **20** | **12** | **7** | **1** |

---

**Versión del documento:** 1.0  
**Fecha de última actualización:** 06/05/2026  
**Estado:** Aprobado para ejecución de pruebas
