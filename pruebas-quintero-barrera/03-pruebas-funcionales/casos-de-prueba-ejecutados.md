# Casos de Prueba Funcionales — InventarioK1 (Desktop)

> Completar las columnas **Resultado real** y **Estado** durante la ejecución manual.  
> Estado válido: `Paso` | `Fallo` | `Bloqueado`

---

## Módulo: Login (Autenticación)

| ID | Descripción | Precondición | Pasos | Resultado esperado | Resultado real | Estado |
|----|-------------|--------------|-------|--------------------|----------------|--------|
| CP-001 | Login exitoso | Usuario activo registrado en BD | 1. Abrir la app<br>2. Ingresar usuario válido<br>3. Ingresar contraseña correcta<br>4. Clic en "Iniciar Sesión" | La app navega al Dashboard principal | | |
| CP-002 | Login con contraseña incorrecta | Usuario activo registrado | 1. Ingresar usuario válido<br>2. Ingresar contraseña incorrecta<br>3. Clic en "Iniciar Sesión" | Muestra el mensaje de error. El sistema permanece en la pantalla de login | | |
| CP-003 | Login con usuario inexistente | Ninguna | 1. Ingresar un usuario que no existe<br>2. Ingresar cualquier contraseña<br>3. Clic en "Iniciar Sesión" | Muestra mensaje de error genérico. No revela si el usuario existe | | |
| CP-004 | Login con campos vacíos | Ninguna | 1. Dejar ambos campos vacíos<br>2. Clic en "Iniciar Sesión" (o presionar Enter) | El sistema activa la validación del formulario sin realizar ninguna petición a la BD | | |
| CP-005 | Login con usuario inactivo | Usuario marcado como `estaActivo = false` en BD | 1. Ingresar las credenciales del usuario inactivo<br>2. Clic en "Iniciar Sesión" | El sistema muestra el mensaje de usuario desactivado. No permite el acceso | | |

---

## Módulo: Maestro (Productos)

| ID | Descripción | Precondición | Pasos | Resultado esperado | Resultado real | Estado |
|----|-------------|--------------|-------|--------------------|----------------|--------|
| CP-006 | Crear producto con todos los campos válidos | Sesión activa | 1. Ir al módulo Productos<br>2. Clic en el botón "Nuevo" / "+"<br>3. Completar SKU, nombre, precio compra, precio venta, stock actual, stock mínimo<br>4. Guardar | El producto aparece en el listado con los datos ingresados | | |
| CP-007 | Crear producto con campo obligatorio vacío | Sesión activa | 1. Ir al módulo Productos<br>2. Clic en "Nuevo"<br>3. Dejar el campo "Nombre" vacío<br>4. Clic en Guardar | El sistema resalta el campo vacío. No guarda el registro | | |
| CP-008 | Editar producto existente | Producto creado en CP-006 | 1. Buscar el producto del CP-006<br>2. Clic en el botón Editar (lápiz)<br>3. Cambiar el precio de venta<br>4. Guardar | El precio actualizado se refleja inmediatamente en el listado | | |
| CP-009 | Eliminar producto sin dependencias | Producto sin órdenes ni facturas asociadas | 1. Buscar el producto<br>2. Clic en Eliminar (basurero)<br>3. Confirmar en el diálogo | El producto desaparece del listado | | |
| CP-010 | Intentar eliminar producto con facturas asociadas | Producto que aparece en al menos una factura o una orden | 1. Buscar el producto con dependencias<br>2. Clic en Eliminar<br>3. Confirmar | El sistema muestra un mensaje de error indicando que el producto no puede eliminarse por tener registros asociados | | |

---

## Módulo: Transaccional (Ventas / Facturas)

| ID | Descripción | Precondición | Pasos | Resultado esperado | Resultado real | Estado |
|----|-------------|--------------|-------|--------------------|----------------|--------|
| CP-011 | Registrar factura de venta válida (tipo Mostrador) | Sesión activa. Al menos un producto con stock disponible | 1. Ir al módulo Ventas / Facturas<br>2. Clic en "Nueva Venta"<br>3. Agregar un producto y cantidad válida<br>4. Seleccionar método de pago<br>5. Confirmar | La factura se guarda. El stock del producto se actualiza en la BD | | |
| CP-012 | Registrar factura con cantidad mayor al stock disponible | Sesión activa. Producto con stock = 2 | 1. Ir a Nueva Venta<br>2. Agregar el producto con cantidad = 5 | El sistema impide la acción o muestra advertencia de stock insuficiente | | |
| CP-013 | Acceso directo al módulo sin sesión activa | Ninguna sesión en el sistema | 1. Cerrar sesión<br>2. Intentar navegar directamente al módulo de Ventas desde el sidebar | El sistema no muestra la vista de Ventas sin una sesión activa | | |
| CP-014 | Confirmar factura sin agregar ítems | Sesión activa | 1. Ir a Nueva Venta<br>2. No agregar ningún ítem<br>3. Clic en "Confirmar" / "Guardar" | El sistema muestra validación indicando que no hay ítems en la venta | | |
| CP-015 | Verificar registro de factura en la BD local | Factura creada en CP-011 | 1. Abrir el archivo `InventarioK1.sqlite` con DB Browser for SQLite<br>2. Consultar la tabla `ventas`<br>3. Buscar el registro creado | Existe un registro con los datos correctos y `estado_pago = PAGADO` (o `PENDIENTE` según configuración) | | |

---

## Resumen de Ejecución

| Módulo | Total casos | Paso | Fallo | Bloqueado | % Éxito |
|--------|-------------|------|-------|-----------|---------|
| Login | 5 | | | | |
| Maestro (Productos) | 5 | | | | |
| Transaccional (Ventas) | 5 | | | | |
| **Total** | **15** | | | | |

---

**Fecha de ejecución:** _______________  
**Ejecutado por:** Quintero Barrera  
**Versión de la app:** 0.1.0+1  
**Sistema Operativo:** Linux Ubuntu 24.04
