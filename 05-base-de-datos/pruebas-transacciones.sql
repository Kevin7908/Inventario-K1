-- =========================================
-- PRUEBAS DE TRANSACCIONES
-- INVENTARIO K1
-- =========================================

-- =========================================
-- 1. PRUEBA COMMIT
-- =========================================

-- Conteo inicial
SELECT COUNT(*) AS total_antes
FROM productos;

-- Iniciar transaccion
BEGIN TRANSACTION;

INSERT INTO productos
(
    sku,
    nombre,
    descripcion,
    categoria_id,
    unidad_medida_id,
    proveedor_id,
    precio_compra,
    precio_venta,
    stock_actual,
    stock_minimo,
    ubicacion_bodega,
    aplica_iva,
    activo
)
VALUES
(
    'COMMIT-001',
    'PRUEBA_COMMIT',
    'Producto prueba commit',
    1,
    1,
    1,
    1000,
    1500,
    5,
    1,
    'TEST',
    1,
    1
);

-- Verificar dentro de la transaccion
SELECT *
FROM productos
WHERE nombre = 'PRUEBA_COMMIT';

-- Confirmar transaccion
COMMIT;

-- Conteo despues
SELECT COUNT(*) AS total_despues
FROM productos;

-- Verificar persistencia
SELECT *
FROM productos
WHERE nombre = 'PRUEBA_COMMIT';

-- =========================================
-- 2. PRUEBA ROLLBACK
-- =========================================

-- Conteo inicial rollback
SELECT COUNT(*) AS total_antes
FROM productos;

-- Iniciar transaccion
BEGIN TRANSACTION;

INSERT INTO productos
(
    sku,
    nombre,
    descripcion,
    categoria_id,
    unidad_medida_id,
    proveedor_id,
    precio_compra,
    precio_venta,
    stock_actual,
    stock_minimo,
    ubicacion_bodega,
    aplica_iva,
    activo
)
VALUES
(
    'ROLLBACK-001',
    'PRUEBA_ROLLBACK',
    'Producto prueba rollback',
    1,
    1,
    1,
    1000,
    1500,
    5,
    1,
    'TEST',
    1,
    1
);

-- Verificar dentro de transaccion
SELECT *
FROM productos
WHERE nombre = 'PRUEBA_ROLLBACK';

-- Revertir
ROLLBACK;

-- Conteo despues rollback
SELECT COUNT(*) AS total_despues
FROM productos;

-- Verificar que NO existe
SELECT *
FROM productos
WHERE nombre = 'PRUEBA_ROLLBACK';