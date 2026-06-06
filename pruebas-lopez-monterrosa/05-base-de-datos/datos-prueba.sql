-- ==========================================
-- datos-prueba.sql
-- Proyecto Inventario K1
-- Fase 5 - Pruebas de Base de Datos
-- ==========================================

-- PASO 1
-- SQLite no utiliza USE nombre_bd

-- PASO 2
-- Verificar tablas existentes

SELECT name
FROM sqlite_master
WHERE type='table';

PRAGMA table_info(tabla_usuario);
PRAGMA table_info(clientes);
PRAGMA table_info(ventas);

-- PASO 3
-- Limpiar datos de prueba anteriores

DELETE FROM ventas
WHERE numero_factura LIKE 'PRUEBA_%';

DELETE FROM clientes
WHERE cedula LIKE 'TEST_%';

DELETE FROM tabla_usuario
WHERE usuario LIKE 'test_%';

-- PASO 4
-- Insertar usuarios de prueba

INSERT INTO tabla_usuario
(
nombre,
usuario,
email,
password_hash,
es_admin,
esta_activo
)
VALUES
(
'Administrador Prueba',
'test_admin',
'[test_admin@test.com](mailto:test_admin@test.com)',
'HASH_TEST_ADMIN',
1,
1
),
(
'Usuario Prueba',
'test_user',
'[test_user@test.com](mailto:test_user@test.com)',
'HASH_TEST_USER',
0,
1
),
(
'Usuario Inactivo',
'test_inactivo',
'[test_inactivo@test.com](mailto:test_inactivo@test.com)',
'HASH_TEST_INACTIVO',
0,
0
);

SELECT
id,
usuario,
nombre,
es_admin,
esta_activo
FROM tabla_usuario
WHERE usuario LIKE 'test_%';

-- PASO 5
-- Insertar clientes de prueba

INSERT INTO clientes
(
cedula,
nombres,
apellidos,
telefono,
email,
ciudad,
activo
)
VALUES
(
'TEST_001',
'Cliente',
'Prueba Uno',
'300000001',
'[cliente1@test.com](mailto:cliente1@test.com)',
'Manizales',
1
),
(
'TEST_002',
'Cliente',
'Prueba Dos',
'300000002',
'[cliente2@test.com](mailto:cliente2@test.com)',
'Manizales',
1
),
(
'TEST_003',
'Cliente',
'Prueba Tres',
'300000003',
'[cliente3@test.com](mailto:cliente3@test.com)',
'Manizales',
1
);

SELECT *
FROM clientes
WHERE cedula LIKE 'TEST_%';

-- PASO 6
-- Insertar ventas de prueba

INSERT INTO ventas
(
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
VALUES
(
'PRUEBA_TRX_001',
'SERVICIO',
1,
100,
19,
0,
119,
119,
'EFECTIVO',
'COMPLETADA'
),
(
'PRUEBA_TRX_002',
'SERVICIO',
2,
250,
47.5,
0,
297.5,
297.5,
'EFECTIVO',
'COMPLETADA'
),
(
'PRUEBA_TRX_003',
'SERVICIO',
3,
75,
14.25,
0,
89.25,
0,
'EFECTIVO',
'PENDIENTE'
);

SELECT *
FROM ventas
WHERE numero_factura LIKE 'PRUEBA_%';
