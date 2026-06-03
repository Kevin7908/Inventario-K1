# Criterios de Aceptación - InventarioK1 (Desktop)

## Documento de Especificación de Criterios de Aceptación

| Versión | Fecha | Autor | Descripción |
|---------|-------|-------|-------------|
| 1.0 | 06/05/2026 | Quintero Barrera | Creación inicial |
| 2.0 | 03/06/2026 | Quintero Barrera | Módulo Transaccional actualizado a Ventas/Facturas; se agregan CA-021 a CA-023 |

---

## Módulo: Login (Autenticación)

| ID | Módulo | Prioridad | Criterio de Aceptación |
|----|--------|-----------|------------------------|
| CA-001 | Login | **Alta** | Dado un usuario registrado y activo, cuando ingresa credenciales válidas (usuario + contraseña correcta), entonces el sistema navega al Dashboard principal en menos de 3 segundos. |
| CA-002 | Login | **Alta** | Dado un usuario con contraseña incorrecta, cuando intenta iniciar sesión, entonces el sistema muestra el mensaje "Usuario o contraseña incorrectos" y permanece en la pantalla de login. |
| CA-003 | Login | **Alta** | Dado el formulario de registro, cuando se ingresan datos válidos (nombre, usuario, correo, contraseña), entonces el sistema aplica hash BCrypt a la contraseña antes de guardarla en SQLite — el campo `passwordHash` no es igual al texto plano ingresado. |
| CA-004 | Login | **Media** | Dado un nombre de usuario que ya existe en la base de datos, cuando se intenta registrar otro con el mismo nombre de usuario, entonces el sistema lanza `UsuarioYaExisteException` y muestra un mensaje de error. |
| CA-005 | Login | **Alta** | Dado un intento de registro, cuando los campos "Contraseña" y "Confirmar Contraseña" no coinciden, entonces el sistema impide la creación y muestra una advertencia visual en el formulario. |
| CA-006 | Login | **Media** | Dado el campo de contraseña en el registro, cuando se ingresa una clave con menos de 6 caracteres, entonces el sistema activa una validación visual de longitud mínima sin enviar la petición. |
| CA-007 | Login | **Alta** | Dado un usuario autenticado, cuando presiona el botón de cerrar sesión, entonces el sistema limpia el estado del ViewModel y redirige a la pantalla de inicio de sesión. |

---

## Módulo: Maestro (Productos)

| ID | Módulo | Prioridad | Criterio de Aceptación |
|----|--------|-----------|------------------------|
| CA-008 | Maestro | **Alta** | Dado un nuevo producto, cuando se completan todos los campos obligatorios (SKU, nombre, precio de compra, precio de venta, stock actual, stock mínimo), entonces el registro se persiste correctamente mediante Drift y aparece en el listado. |
| CA-009 | Maestro | **Alta** | Dado un producto sin nombre o sin precio de venta, cuando se intenta guardar, entonces el sistema resalta los campos vacíos y no ejecuta la inserción en la base de datos. |
| CA-010 | Maestro | **Alta** | Dado un producto existente, cuando se modifica su precio de venta o descripción y se guarda, entonces el cambio se refleja inmediatamente en el listado reactivo de la aplicación. |
| CA-011 | Maestro | **Media** | Dado un producto en el listado, cuando el usuario presiona el botón de eliminar, entonces el sistema muestra un diálogo de confirmación antes de borrar el registro de SQLite. |
| CA-012 | Maestro | **Media** | Dado un SKU de producto ya existente, cuando se intenta crear otro con el mismo SKU, entonces el sistema lanza un error de integridad y muestra un mensaje de "SKU duplicado". |
| CA-013 | Maestro | **Baja** | Dado el buscador de productos, cuando se ingresa el nombre o SKU de un artículo, entonces el listado se filtra en tiempo real mostrando solo las coincidencias encontradas. |
| CA-014 | Maestro | **Alta** | Dado un producto con `aplicaIva = true` y precio de venta de 200, cuando se consulta el getter `precioVentaConIva`, entonces el resultado es 238.0 (200 × 1.19). |

---

## Módulo: Transaccional (Ventas / Facturas)

| ID | Módulo | Prioridad | Criterio de Aceptación |
|----|--------|-----------|------------------------|
| CA-015 | Ventas | **Alta** | Dado el formulario de nueva factura, cuando se selecciona un producto y se especifica una cantidad válida, entonces el sistema calcula el subtotal multiplicando `cantidad × precioUnitario` y lo muestra en pantalla. |
| CA-016 | Ventas | **Alta** | Dado un producto con stock insuficiente, cuando se intenta registrar en una factura una cantidad mayor a la disponible, entonces el sistema impide la acción y notifica al usuario con un mensaje de stock insuficiente. |
| CA-017 | Ventas | **Alta** | Dado el detalle de una factura con ítems de tipo producto y de tipo servicio, cuando se consultan los getters `itemsProducto` e `itemsServicio`, entonces cada lista retorna únicamente los ítems del tipo correspondiente. |
| CA-018 | Ventas | **Media** | Dado el proceso de facturación, cuando se elimina un ítem antes de confirmar, entonces el total de la factura se recalcula automáticamente restando el valor de ese ítem. |
| CA-019 | Ventas | **Media** | Dado un intento de finalizar una factura sin haber agregado ítems, cuando se presiona "Confirmar", entonces el sistema muestra un mensaje de validación indicando que debe agregar al menos un ítem. |
| CA-020 | Ventas | **Alta** | Dado el cierre exitoso de una factura, cuando se confirma y guarda, entonces el sistema genera un registro en la tabla `ventas` con `estadoPago = PAGADO` y actualiza el stock de los productos incluidos. |
| CA-021 | Ventas | **Alta** | Dado el modelo `FacturaDetalle`, cuando `totalPagado` es menor a `total`, entonces el getter `saldoPendiente` retorna la diferencia correcta (`total - totalPagado`). |
| CA-022 | Ventas | **Media** | Dado el parser `MetodoPago.desdeTexto`, cuando se le pasa la cadena `'TRANSFERENCIA'` (mayúsculas), entonces retorna el valor `MetodoPago.transferencia` correctamente. |
| CA-023 | Ventas | **Media** | Dado el parser `EstadoPago.desdeTexto`, cuando se le pasa un texto no reconocido, entonces retorna el valor por defecto `EstadoPago.pendiente` sin lanzar excepción. |

---

## Resumen de Criterios por Módulo

| Módulo | Total | Alta | Media | Baja |
|--------|-------|------|-------|------|
| Login (Autenticación) | 7 | 5 | 2 | 0 |
| Maestro (Productos) | 7 | 4 | 2 | 1 |
| Transaccional (Ventas/Facturas) | 9 | 4 | 5 | 0 |
| **Total** | **23** | **13** | **9** | **1** |

---

**Versión del documento:** 2.0  
**Fecha de última actualización:** 03/06/2026  
**Estado:** Aprobado para ejecución de pruebas
