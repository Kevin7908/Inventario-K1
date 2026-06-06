-- =====================================================
-- PRUEBAS DE INTEGRIDAD
-- Proyecto Inventario-K1
-- =====================================================

-- =====================================================
-- PASO 1 - INTEGRIDAD REFERENCIAL
-- =====================================================

-- Ventas sin cliente válido
SELECT v.*
FROM ventas v
LEFT JOIN clientes c
ON v.cliente_id = c.id
WHERE v.cliente_id IS NOT NULL
  AND c.id IS NULL;

-- Resultado esperado: 0 filas


-- Detalles de venta sin venta válida
SELECT vd.*
FROM venta_detalles vd
LEFT JOIN ventas v
ON vd.venta_id = v.id
WHERE v.id IS NULL;

-- Resultado esperado: 0 filas


-- Detalles de venta con producto inexistente
SELECT vd.*
FROM venta_detalles vd
LEFT JOIN productos p
ON vd.producto_id = p.id
WHERE vd.producto_id IS NOT NULL
  AND p.id IS NULL;

-- Resultado esperado: 0 filas


-- Motos sin cliente válido
SELECT m.*
FROM motos m
LEFT JOIN clientes c
ON m.cliente_id = c.id
WHERE c.id IS NULL;

-- Resultado esperado: 0 filas


-- Órdenes de servicio sin moto válida
SELECT os.*
FROM ordenes_servicio os
LEFT JOIN motos m
ON os.moto_id = m.id
WHERE m.id IS NULL;

-- Resultado esperado: 0 filas


-- =====================================================
-- PASO 2 - UNICIDAD
-- =====================================================

-- Usuarios duplicados
SELECT usuario, COUNT(*) AS cantidad
FROM tabla_usuario
GROUP BY usuario
HAVING COUNT(*) > 1;

-- Resultado esperado: 0 filas


-- Emails duplicados de usuarios
SELECT email, COUNT(*) AS cantidad
FROM tabla_usuario
GROUP BY email
HAVING COUNT(*) > 1;

-- Resultado esperado: 0 filas


-- Facturas duplicadas
SELECT numero_factura, COUNT(*) AS cantidad
FROM ventas
GROUP BY numero_factura
HAVING COUNT(*) > 1;

-- Resultado esperado: 0 filas


-- SKU duplicados
SELECT sku, COUNT(*) AS cantidad
FROM productos
GROUP BY sku
HAVING COUNT(*) > 1;

-- Resultado esperado: 0 filas


-- =====================================================
-- PASO 3 - CAMPOS OBLIGATORIOS
-- =====================================================

-- Usuarios sin nombre
SELECT *
FROM tabla_usuario
WHERE nombre IS NULL
   OR TRIM(nombre) = '';

-- Resultado esperado: 0 filas


-- Clientes sin nombres
SELECT *
FROM clientes
WHERE nombres IS NULL
   OR TRIM(nombres) = '';

-- Resultado esperado: 0 filas


-- Productos sin nombre
SELECT *
FROM productos
WHERE nombre IS NULL
   OR TRIM(nombre) = '';

-- Resultado esperado: 0 filas


-- Ventas sin factura
SELECT *
FROM ventas
WHERE numero_factura IS NULL
   OR TRIM(numero_factura) = '';

-- Resultado esperado: 0 filas


-- =====================================================
-- PASO 4 - RANGOS DE VALORES
-- =====================================================

-- Productos con stock negativo
SELECT *
FROM productos
WHERE stock_actual < 0;

-- Resultado esperado: 0 filas


-- Productos con precio de venta negativo
SELECT *
FROM productos
WHERE precio_venta < 0;

-- Resultado esperado: 0 filas


-- Ventas con total negativo
SELECT *
FROM ventas
WHERE total < 0;

-- Resultado esperado: 0 filas


-- =====================================================
-- PASO 5 - RESUMEN FINAL
-- =====================================================

SELECT 'Usuarios totales' AS concepto, COUNT(*) AS cantidad
FROM tabla_usuario

UNION ALL

SELECT 'Clientes totales', COUNT(*)
FROM clientes

UNION ALL

SELECT 'Productos totales', COUNT(*)
FROM productos

UNION ALL

SELECT 'Ventas totales', COUNT(*)
FROM ventas

UNION ALL

SELECT 'Detalles de venta', COUNT(*)
FROM venta_detalles

UNION ALL

SELECT 'Motos registradas', COUNT(*)
FROM motos

UNION ALL

SELECT 'Ordenes de servicio', COUNT(*)
FROM ordenes_servicio;