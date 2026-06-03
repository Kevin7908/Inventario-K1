-- =========================================
-- DATOS DE PRUEBA - INVENTARIO K1
-- =========================================

-- =========================================
-- VER TABLAS
-- =========================================

SELECT name
FROM sqlite_master
WHERE type='table';

-- =========================================
-- LIMPIAR DATOS DE PRUEBA ANTERIORES
-- =========================================

DELETE FROM productos
WHERE nombre LIKE 'PRUEBA_%';

DELETE FROM categorias
WHERE nombre LIKE 'TEST_%';

DELETE FROM tabla_usuario
WHERE usuario LIKE 'test_%';

-- =========================================
-- INSERTAR USUARIO DE PRUEBA
-- =========================================

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
    'Usuario Prueba',
    'test_user',
    'test@test.com',
    'hash_prueba',
    0,
    1
);

-- =========================================
-- VERIFICAR USUARIO
-- =========================================

SELECT *
FROM tabla_usuario
WHERE usuario LIKE 'test_%';

-- =========================================
-- INSERTAR CATEGORIA DE PRUEBA
-- =========================================

INSERT INTO categorias
(
    nombre,
    descripcion,
    color_hex,
    icono
)
VALUES
(
    'TEST_CATEGORIA',
    'Categoria de prueba',
    '#FF0000',
    'test'
);

-- =========================================
-- VERIFICAR CATEGORIA
-- =========================================

SELECT *
FROM categorias
WHERE nombre LIKE 'TEST_%';

-- =========================================
-- INSERTAR PRODUCTO DE PRUEBA
-- =========================================

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
    'TEST-001',
    'PRUEBA_PRODUCTO',
    'Producto de prueba SQL',
    1,
    1,
    1,
    1000,
    1500,
    10,
    2,
    'BODEGA_TEST',
    1,
    1
);

-- =========================================
-- VERIFICAR PRODUCTO
-- =========================================

SELECT *
FROM productos
WHERE nombre LIKE 'PRUEBA_%';


-- =========================================
-- CATEGORIAS ADICIONALES
-- =========================================

INSERT INTO categorias (nombre, descripcion, color_hex, icono)
VALUES
('Aceites', 'Aceites automotrices', '#F59E0B', 'oil_barrel'),
('Frenos', 'Sistema de frenos', '#EF4444', 'car_repair'),
('Suspension', 'Partes de suspension', '#10B981', 'build'),
('Baterias', 'Baterias automotrices', '#6366F1', 'battery_charging_full');

-- =========================================
-- PROVEEDORES ADICIONALES
-- =========================================

INSERT INTO proveedores
(
    nombre,
    nit_cedula,
    contacto,
    telefono,
    email,
    direccion,
    ciudad,
    activo,
    color_hex,
    icono
)
VALUES
(
    'AutoPartes Colombia',
    '900123456',
    'Carlos Ramirez',
    '3001112233',
    'ventas@autopartes.com',
    'Calle 10 #20-30',
    'Bogota',
    1,
    '#3B82F6',
    'local_shipping'
),
(
    'Importadora Motor',
    '800456789',
    'Laura Perez',
    '3015557788',
    'info@importmotor.com',
    'Carrera 15 #40-20',
    'Medellin',
    1,
    '#10B981',
    'warehouse'
);

-- =========================================
-- UNIDADES ADICIONALES
-- =========================================

INSERT INTO unidades_medida
(
    nombre,
    abreviatura,
    descripcion
)
VALUES
(
    'Caja',
    'cj',
    'Caja completa'
),
(
    'Litro',
    'lt',
    'Unidad liquida'
);

-- =========================================
-- PRODUCTOS ADICIONALES
-- =========================================

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
    'ACE-001',
    'Aceite Mobil 20W50',
    'Aceite para motor',
    2,
    3,
    2,
    25000,
    38000,
    20,
    5,
    'A-01',
    1,
    1
),
(
    'FRE-001',
    'Pastillas de freno',
    'Pastillas delanteras',
    3,
    1,
    2,
    45000,
    70000,
    15,
    4,
    'B-10',
    1,
    1
),
(
    'BAT-001',
    'Bateria Bosch 900A',
    'Bateria automotriz',
    5,
    1,
    3,
    180000,
    250000,
    8,
    2,
    'C-05',
    1,
    1
),
(
    'SUS-001',
    'Amortiguador delantero',
    'Suspension delantera',
    4,
    1,
    2,
    95000,
    140000,
    12,
    3,
    'D-02',
    1,
    1
);

-- =========================================
-- VERIFICAR PRODUCTOS
-- =========================================

SELECT id, sku, nombre, stock_actual
FROM productos;