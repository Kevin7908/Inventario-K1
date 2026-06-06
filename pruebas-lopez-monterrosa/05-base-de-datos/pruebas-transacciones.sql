-- =====================================================
-- PRUEBAS DE TRANSACCIONES
-- Proyecto Inventario-K1
-- =====================================================

-- =====================================================
-- LIMPIEZA PREVIA
-- =====================================================

DELETE FROM ventas
WHERE numero_factura IN (
    'PRUEBA_COMMIT',
    'PRUEBA_ROLLBACK'
);

-- =====================================================
-- PRUEBA 1 - COMMIT
-- =====================================================

SELECT COUNT(*) AS total_antes
FROM ventas;

BEGIN TRANSACTION;

INSERT INTO ventas (
    numero_factura,
    tipo,
    cliente_id,
    subtotal,
    iva,
    descuento,
    total,
    total_pagado,
    metodo_pago,
    estado_pago
)
VALUES (
    'PRUEBA_COMMIT',
    'SERVICIO',
    1,
    100,
    19,
    0,
    119,
    119,
    'EFECTIVO',
    'PAGADO'
);

SELECT *
FROM ventas
WHERE numero_factura = 'PRUEBA_COMMIT';

COMMIT;

SELECT COUNT(*) AS total_despues
FROM ventas;

SELECT *
FROM ventas
WHERE numero_factura = 'PRUEBA_COMMIT';


-- =====================================================
-- PRUEBA 2 - ROLLBACK
-- =====================================================

SELECT COUNT(*) AS total_antes
FROM ventas;

BEGIN TRANSACTION;

INSERT INTO ventas (
    numero_factura,
    tipo,
    cliente_id,
    subtotal,
    iva,
    descuento,
    total,
    total_pagado,
    metodo_pago,
    estado_pago
)
VALUES (
    'PRUEBA_ROLLBACK',
    'SERVICIO',
    5,
    200,
    38,
    0,
    238,
    0,
    'EFECTIVO',
    'PENDIENTE'
);

SELECT *
FROM ventas
WHERE numero_factura = 'PRUEBA_ROLLBACK';

ROLLBACK;

SELECT COUNT(*) AS total_despues
FROM ventas;

SELECT *
FROM ventas
WHERE numero_factura = 'PRUEBA_ROLLBACK';


-- -- =====================================================
-- -- LIMPIEZA FINAL
-- -- =====================================================

-- DELETE FROM ventas
-- WHERE numero_factura IN (
--     'PRUEBA_COMMIT',
--     'PRUEBA_ROLLBACK'
-- );

-- SELECT COUNT(*) AS datos_prueba_restantes
-- FROM ventas
-- WHERE numero_factura LIKE 'PRUEBA_%';