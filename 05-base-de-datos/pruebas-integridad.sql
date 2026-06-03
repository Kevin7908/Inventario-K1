-- =========================================
-- PRUEBAS DE INTEGRIDAD
-- INVENTARIO K1
-- =========================================

-- =========================================
-- 1. PRODUCTOS SIN CATEGORIA VALIDA
-- =========================================

SELECT p.id, p.nombre
FROM productos p
LEFT JOIN categorias c
ON p.categoria_id = c.id
WHERE c.id IS NULL;

-- Resultado esperado: 0 filas

-- =========================================
-- 2. PRODUCTOS SIN PROVEEDOR VALIDO
-- =========================================

SELECT p.id, p.nombre
FROM productos p
LEFT JOIN proveedores pr
ON p.proveedor_id = pr.id
WHERE pr.id IS NULL;

-- Resultado esperado: 0 filas

-- =========================================
-- 3. PRODUCTOS SIN UNIDAD VALIDA
-- =========================================

SELECT p.id, p.nombre
FROM productos p
LEFT JOIN unidades_medida u
ON p.unidad_medida_id = u.id
WHERE u.id IS NULL;

-- Resultado esperado: 0 filas

-- =========================================
-- 4. PRODUCTOS CON PRECIO INVALIDO
-- =========================================

SELECT *
FROM productos
WHERE precio_compra < 0
OR precio_venta < 0;

-- Resultado esperado: 0 filas

-- =========================================
-- 5. PRODUCTOS CON STOCK NEGATIVO
-- =========================================

SELECT *
FROM productos
WHERE stock_actual < 0;

-- Resultado esperado: 0 filas

-- =========================================
-- 6. PRODUCTOS SIN NOMBRE
-- =========================================

SELECT *
FROM productos
WHERE nombre IS NULL
OR nombre = '';

-- Resultado esperado: 0 filas

-- =========================================
-- 7. CATEGORIAS DUPLICADAS
-- =========================================

SELECT nombre, COUNT(*) as cantidad
FROM categorias
GROUP BY nombre
HAVING COUNT(*) > 1;

-- Resultado esperado: 0 filas

-- =========================================
-- 8. USUARIOS DUPLICADOS
-- =========================================

SELECT usuario, COUNT(*) as cantidad
FROM tabla_usuario
GROUP BY usuario
HAVING COUNT(*) > 1;

-- Resultado esperado: 0 filas

-- =========================================
-- 9. RESUMEN GENERAL
-- =========================================

SELECT 'Total categorias' as concepto, COUNT(*) as cantidad
FROM categorias

UNION ALL

SELECT 'Total proveedores', COUNT(*)
FROM proveedores

UNION ALL

SELECT 'Total productos', COUNT(*)
FROM productos

UNION ALL

SELECT 'Total usuarios', COUNT(*)
FROM tabla_usuario

UNION ALL

SELECT 'Productos activos', COUNT(*)
FROM productos
WHERE activo = 1;