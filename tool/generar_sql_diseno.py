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
   'usuario_permisos', 'especializaciones']),

 ('2. CATÁLOGO', """Lo que el taller vende y con qué lo mide. Los catálogos no se borran: llevan
`activo` porque los documentos emitidos los referencian.

`productos.codigo_barras` es APARTE del sku: el sku lo inventa el taller con el
prefijo de la categoría y siempre está; el código de barras viene impreso de
fábrica y falta en todo lo que llega a granel. Por eso es nullable, y UNIQUE
acepta varios NULL sin estorbar. Se guarda normalizado —sin espacios ni
guiones— porque un lector puede mandar «7 702001 234567» y otro
«7702001234567», y los dos tienen que dar en el mismo producto.

producto_compatibilidades responde «¿esta pastilla le sirve a una Pulsar?»,
que antes caía dentro de `descripcion` como texto libre. Una línea vale por una
MARCA ENTERA o por un MODELO, nunca por las dos —el aceite sirve para cualquier
Yamaha, la pastilla solo para la FZ—, y eso lo cierra un CHECK: obligar a
listar los modelos uno por uno para el primer caso llenaría la tabla de filas
que dicen lo mismo. Son dos columnas nulables y no el par
referencia_tipo/referencia_id, por lo mismo que en movimientos_inventario: una
FK polimórfica no la puede verificar la base.""",
  ['categorias', 'unidades_medida', 'productos', 'producto_compatibilidades',
   'servicios']),

 ('3. INVENTARIO', """El libro mayor del stock. `productos.stock_actual` es un CACHÉ de
SUM(movimientos_inventario.cantidad): se guarda porque la app lo consulta cien
veces por pantalla, pero la verdad son los movimientos, y hay una consulta que
comprueba que cuadran.

La cantidad lleva SIGNO —positivo entra, negativo sale— para que reconstruir
el stock sea un SUM y no un CASE de diez ramas. El origen son tres columnas
nulables con FK real en vez del típico par referencia_tipo/referencia_id: una
FK polimórfica no la puede verificar la base.""",
  ['movimientos_inventario']),

 ('4. TALLER', """La moto del cliente y su paso por el taller.

La marca y el modelo son CATÁLOGO, no texto libre en `motos`: con texto entran
«Yamaha», «yamaha» y «YAMAHA» como tres marcas y ningún informe puede
cruzarlas. El cilindraje vive en `modelos_moto` y no en cada moto porque es del
modelo, no del ejemplar: todas las Boxer CT100 son de 100 cc, y repetirlo por
moto era el mismo dato una vez por cliente.

`motos.modelo_id` es nullable y `marca_id` no: en el mostrador la marca siempre
se sabe y el modelo exacto a veces no está catalogado todavía. Parar la
atención al cliente para dar de alta un modelo sería peor que registrar la moto
con lo que se sabe.

Las líneas de las tres tablas hijas llevan su propio usuario_id: una orden pasa
de un turno a otro, así que quien anota un repuesto no siempre es quien la
abrió.""",
  ['marcas_moto', 'modelos_moto', 'motos', 'ordenes_servicio',
   'ordenes_tareas', 'ordenes_repuestos', 'ordenes_cargos']),

 ('5. DOCUMENTOS DE VENTA', """La factura es un documento contable: no se borra, se anula (ver las guardas
del final). Sus líneas congelan descripción, precio y costo a propósito: si
mañana sube el precio del catálogo, la factura de ayer no puede cambiar.""",
  ['ventas', 'venta_detalles']),

 ('6. DEVOLUCIONES', """Lo que el cliente trae de vuelta. NO ES LO MISMO QUE ANULAR: anular deshace la
venta entera y la deja en ANULADA; una devolución le quita una parte y la
factura sigue viva, con su número y su estado. Por eso es un documento aparte
y no una columna en ventas: se pueden devolver dos piezas hoy y otra la semana
que viene, y cada una tiene su fecha, su motivo y su autor.

devolucion_detalles apunta a venta_detalles, no a productos: lo que se
devuelve es ESA línea de ESA venta. El producto y la descripción congelada se
leen por JOIN desde allá; el único snapshot propio es precio_unitario, porque
una segunda devolución de la misma línea tiene que valer lo mismo que la
primera.

Que la suma devuelta no pase de lo vendido NO CABE EN UN CHECK —necesita un
agregado sobre las demás filas—: lo cierra una guarda, al final del archivo.

devoluciones.total es caché de SUM(cantidad * precio_unitario) de sus líneas,
como el stock y como monto_pagado.""",
  ['devoluciones', 'devolucion_detalles']),

 ('7. COTIZACIONES Y RESERVAS', """La cotización no guarda `total` (es subtotal + iva, dos columnas de su misma
fila) ni `estado` (depende de la fecha de hoy). Los dos se calculan.

`reservas.pagado_acumulado` es caché de SUM(reserva_abonos.monto), como el
stock.""",
  ['cotizaciones', 'cotizacion_items', 'reservas', 'reserva_items',
   'reserva_abonos']),

 ('8. CARTERA', """Lo que queda por cobrar. `monto_pagado` es caché de SUM(deudor_pagos.monto).

La deuda NACE EN CUENTAS POR COBRAR, no en una factura. Hubo una columna
venta_id que apuntaba a la venta que la originó; se quitó cuando el mostrador
dejó de fiar —toda venta se cobra completa— y nadie volvió a escribirla. Si
algún día se vuelve a fiar desde el POS, es una FK nueva, no una columna que
llevaba años en NULL.

FIAR SACA LA MERCANCÍA DEL TALLER, y ahí está la diferencia con una reserva:
lo apartado sigue en la bodega y cancelarlo lo devuelve; lo fiado se fue
montado en una moto. Cada deudor_items tiene su renglón en
movimientos_inventario con tipo SALIDA_FIADO, y dar una deuda por INCOBRABLE
NO devuelve nada: si el cliente no paga, el taller pierde la plata, no
recupera la pieza. La única entrada (DEVOLUCION_FIADO) es corregir una línea
que se anotó mal.

monto_total es caché de SUM(deudor_items.cantidad * precio_unitario), como
total_reserva. Un monto negativo en deudor_pagos es una devolución: aparece
cuando quitar una línea deja el total por debajo de lo ya abonado.

VENCIDA es un estado guardado y a la vez calculable desde fecha_vencimiento:
se guarda porque el usuario puede marcarla antes de tiempo, así que no es una
función de la fecha sino una decisión. Quien pregunta "¿cuáles hay que ir a
cobrar?" necesita las dos cosas a la vez, y esa es la condición que aplican
RepositorioDeudores en SQL y DeudorResumen.estaVencida en Dart.""",
  ['deudores', 'deudor_items', 'deudor_pagos']),

 ('9. SOPORTE', """Datos del negocio y numeración de documentos.

El número de un documento sale de `consecutivos`, pedido DENTRO de la
transacción que lo crea. Nunca del id autoincremental (deja huecos) ni de
MAX(numero)+1 (reutiliza el número del último documento borrado, que en
facturación es lo peor que puede pasar).""",
  ['configuracion', 'consecutivos']),

 ('10. AUDITORÍA', """Quién editó o borró qué. Es el complemento de las columnas usuario_id: una
columna no puede contar un borrado, porque cuando la fila se va se lleva su
columna. Y una bitácora no debería ser el único sitio donde consta el autor de
una venta, porque es un renglón paralelo que un método nuevo puede olvidar
escribir.

entidad_id NO ES UNA FK, y es la única excepción del esquema: es polimórfica
—apunta a productos o a clientes según `entidad`— y las dos políticas posibles
rompen lo que la tabla existe para conservar (RESTRICT impediría el borrado,
CASCADE se llevaría el renglón que lo cuenta). `descripcion` guarda el nombre
de lo afectado como snapshot: es la parte legible que sobrevive al borrado.

Es de SOLO ESCRITURA, con su guarda: una bitácora que se puede corregir no
prueba nada, porque quien quisiera tapar algo empezaría por su propio
renglón.""",
  ['bitacora']),
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
--   {{CONTEO}}
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

# El documento no puede desincronizarse de la base EN SILENCIO, que es justo
# lo que decía evitar: `bitacora`, `usuario_permisos` y `ordenes_cargos`
# llevaban tiempo fuera del .sql porque nadie las metió en SECCIONES y el
# generador las descartaba sin decir nada. Ahora revienta.
_declaradas = {t for _, _, tablas in SECCIONES for t in tablas}
_reales = {n for n in objetos['table'] if n != 'sqlite_sequence'}
_huerfanas = _reales - _declaradas
if _huerfanas:
    raise SystemExit(
        'Estas tablas están en la base y en ninguna sección de SECCIONES, '
        'así que el documento las perdería: ' + ', '.join(sorted(_huerfanas)) +
        '.\nAgrégalas a la sección que les toque en tool/generar_sql_diseno.py.')
_sobrantes = _declaradas - _reales
if _sobrantes:
    raise SystemExit(
        'SECCIONES nombra tablas que ya no existen en la base: ' +
        ', '.join(sorted(_sobrantes)) + '.')

salida.append(f"\n-- {L}\n--  11. GUARDAS\n-- {L}\n--")
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

# El conteo se cuenta, no se escribe: la línea del encabezado decía «26 tablas
# · 44 índices» mientras el volcado ya traía 46 índices, porque nadie se
# acuerda de subirla al agregar una tabla.
conteo = (f"{texto.count(chr(10) + 'CREATE TABLE')} tablas · "
          f"{texto.count(chr(10) + 'CREATE INDEX') + texto.count(chr(10) + 'CREATE UNIQUE INDEX')} índices · "
          f"{texto.count(chr(10) + 'CREATE TRIGGER')} guardas (triggers).")
texto = texto.replace('{CONTEO}', conteo)

open('/tmp/InventarioK1.sql', 'w').write(texto)
print(f"{len(texto.splitlines())} líneas · {conteo}")
