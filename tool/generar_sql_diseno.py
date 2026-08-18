#!/usr/bin/env python3
"""Convierte el volcado de `sqlite_master` en el .sql de diseño.

Uso:
    flutter test test/volcado_esquema_test.dart   # escribe /tmp/esquema.sql
    python3 tool/generar_sql_diseno.py            # escribe /tmp/InventarioK1.sql

El .sql de diseño **no se escribe a mano**: si se toca una tabla en
`lib/backend/**/esquema_datos/`, se regenera. Así el documento y la base no
pueden desincronizarse, que es lo que le pasaba al anterior.
"""
import re, textwrap
from collections import OrderedDict

bruto = open('/tmp/esquema.sql').read().split('---8<---')
objetos = {'table': OrderedDict(), 'index': OrderedDict(), 'trigger': OrderedDict()}
for bloque in bruto:
    bloque = bloque.strip()
    if not bloque:
        continue
    cabecera, sql = bloque.split('\n', 1)
    tipo, nombre = cabecera.split('\t')
    objetos[tipo][nombre] = sql.strip()

def partes(cuerpo):
    """Corta por las comas de nivel cero."""
    salida, nivel, actual = [], 0, ''
    en_texto = False
    for c in cuerpo:
        if c == "'":
            en_texto = not en_texto
        if not en_texto:
            if c == '(':
                nivel += 1
            elif c == ')':
                nivel -= 1
            elif c == ',' and nivel == 0:
                salida.append(actual.strip()); actual = ''; continue
        actual += c
    if actual.strip():
        salida.append(actual.strip())
    return salida

def formatear_tabla(nombre, sql):
    cuerpo = sql[sql.index('(') + 1:sql.rindex(')')]
    lineas = partes(cuerpo)
    columnas = [l for l in lineas if l.startswith('"')]
    restricciones = [l for l in lineas if not l.startswith('"')]
    ancho = max((len(l.split(' ')[0]) for l in columnas), default=0)
    out = [f'CREATE TABLE IF NOT EXISTS {nombre} (']
    cuerpo_lineas = []
    for l in columnas:
        col, resto = l.split(' ', 1)
        cuerpo_lineas.append(f'    {col.ljust(ancho)}  {resto}')
    for r in restricciones:
        cuerpo_lineas.append(f'    {r}')
    out.append(',\n'.join(cuerpo_lineas))
    out.append(');')
    return '\n'.join(out)

def indices_de(tabla):
    return [sql.replace('CREATE INDEX ', 'CREATE INDEX IF NOT EXISTS ') + ';'
            for n, sql in objetos['index'].items()
            if re.search(r'\bON ' + tabla + r'\b', sql)]

SECCIONES = [
 ('1. IDENTIDAD', """Una sola tabla guarda quién es alguien. Cliente, técnico, proveedor y usuario
son ROLES: apuntan aquí con persona_id y solo guardan lo suyo. Antes las
cuatro repetían documento, nombres, apellidos, teléfono y email, y el mismo
señor registrado dos veces tenía dos teléfonos que se desincronizaban solos.""",
  ['personas', 'clientes', 'tecnicos', 'proveedores', 'usuarios',
   'especializaciones']),

 ('2. CATÁLOGO', """Lo que el taller vende y con qué lo mide. Los catálogos no se borran: llevan
`activo` porque los documentos emitidos los referencian.""",
  ['categorias', 'unidades_medida', 'productos', 'servicios']),

 ('3. INVENTARIO', """El libro mayor del stock. `productos.stock_actual` es un CACHÉ de
SUM(movimientos_inventario.cantidad): se guarda porque la app lo consulta cien
veces por pantalla, pero la verdad son los movimientos, y hay una consulta que
comprueba que cuadran.

La cantidad lleva SIGNO —positivo entra, negativo sale— para que reconstruir
el stock sea un SUM y no un CASE de diez ramas. El origen son tres columnas
nulables con FK real en vez del típico par referencia_tipo/referencia_id: una
FK polimórfica no la puede verificar la base.""",
  ['movimientos_inventario']),

 ('4. TALLER', """La moto del cliente y su paso por el taller.""",
  ['motos', 'ordenes_servicio', 'ordenes_tareas', 'ordenes_repuestos']),

 ('5. DOCUMENTOS DE VENTA', """La factura es un documento contable: no se borra, se anula (ver las guardas
del final). Sus líneas congelan descripción, precio y costo a propósito: si
mañana sube el precio del catálogo, la factura de ayer no puede cambiar.""",
  ['ventas', 'venta_detalles']),

 ('6. COTIZACIONES Y RESERVAS', """La cotización no guarda `total` (es subtotal + iva, dos columnas de su misma
fila) ni `estado` (depende de la fecha de hoy). Los dos se calculan.

`reservas.pagado_acumulado` es caché de SUM(reserva_abonos.monto), como el
stock.""",
  ['cotizaciones', 'cotizacion_items', 'reservas', 'reserva_items',
   'reserva_abonos']),

 ('7. CARTERA', """Lo que queda por cobrar. `monto_pagado` es caché de SUM(deudor_pagos.monto).

VENCIDA es un estado guardado y a la vez calculable desde fecha_vencimiento:
se guarda porque el usuario puede marcarla antes de tiempo, así que no es una
función de la fecha sino una decisión.""",
  ['deudores', 'deudor_pagos']),

 ('8. SOPORTE', """Datos del negocio y numeración de documentos.

El número de un documento sale de `consecutivos`, pedido DENTRO de la
transacción que lo crea. Nunca del id autoincremental (deja huecos) ni de
MAX(numero)+1 (reutiliza el número del último documento borrado, que en
facturación es lo peor que puede pasar).""",
  ['configuracion', 'consecutivos']),
]

L = '=' * 76
salida = [f"""-- {L}
--   TALLER DE MOTOS — BASE DE DATOS SQLite
--   Sistema de Inventario, Ventas y Gestión de Taller
-- {L}
--
--   Este archivo es el ESQUEMA REAL, volcado desde la base que crea la
--   aplicación (Drift). No se escribe a mano: se regenera ejecutando
--   `flutter test test/volcado_esquema_test.dart` y pasando el resultado
--   por `tool/generar_sql_diseno.py`.
--
--   26 tablas · 44 índices · 9 guardas (triggers).
--
--   Convenciones que valen en todo el esquema:
--
--     · DINERO en INTEGER, en pesos enteros. El peso colombiano no tiene
--       decimales y REAL arrastra error de coma flotante.
--     · CANTIDAD en REAL: hay repuestos por litro y por metro.
--     · FECHAS en INTEGER (segundos desde la época), que es como Drift
--       guarda un DateTime. Nunca texto.
--     · BOOLEANOS en INTEGER 0/1 con su CHECK, generado por Drift.
--     · ENUMS en TEXTO EN MAYÚSCULAS, siempre con CHECK.
--     · Toda FK declara ON DELETE. CASCADE de documento a sus líneas;
--       RESTRICT hacia catálogo e histórico; SET NULL en lo informativo.
--       Nunca CASCADE hacia un documento contable.
--
-- {L}

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
"""]

for titulo, nota, tablas in SECCIONES:
    salida.append(f"\n-- {L}\n--  {titulo}\n-- {L}\n--")
    for linea in nota.strip().split('\n'):
        salida.append(f"--  {linea}".rstrip())
    salida.append('--\n')
    for t in tablas:
        if t not in objetos['table']:
            raise SystemExit(f'falta la tabla {t}')
        salida.append(formatear_tabla(t, objetos['table'][t]))
        idx = indices_de(t)
        if idx:
            salida.append('')
            salida.extend(idx)
        salida.append('')

salida.append(f"\n-- {L}\n--  9. GUARDAS\n-- {L}\n--")
for linea in """Lo que la aplicación NO PUEDE hacer, ni siquiera por error.

Son triggers que solo PROHÍBEN. Ninguno deriva ni mantiene datos: un trigger
que mantuviera el stock competiría con el repositorio que ya lo hace y viviría
en SQL que el analizador no revisa. RAISE(ABORT) sobre una operación que nunca
debe ocurrir no duplica lógica, la clausura.""".split('\n'):
    salida.append(f"--  {linea}".rstrip())
salida.append('--\n')
for nombre, sql in objetos['trigger'].items():
    salida.append(sql.strip().rstrip(';') + ';\n')

texto = '\n'.join(salida).rstrip() + '\n'
open('/tmp/InventarioK1.sql', 'w').write(texto)
print(f"{len(texto.splitlines())} líneas")
