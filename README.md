# InventarioK1

Sistema de gestión para un taller de motos: inventario, punto de venta, órdenes
de servicio, cotizaciones, reservas, cuentas por cobrar y compras a proveedores.
Aplicación de **escritorio** hecha en Flutter, con toda la información en un
único archivo SQLite local.

**Sin servidor, sin nube, sin suscripción y sin internet.** El taller instala un
ejecutable, y los datos viven en su disco.

| | |
|---|---|
| **Plataforma** | Escritorio: Linux · Windows · macOS |
| **Framework** | Flutter 3.44 · Dart 3.12 |
| **Estado** | Riverpod 3 (`AsyncNotifier`) |
| **Persistencia** | SQLite vía Drift 2.32 (tipado y generado en compilación) |
| **Impresión** | `pdf` + `printing` — carta y tirilla térmica |
| **Tamaño** | ~73.000 líneas de Dart · 38 tablas · 92 archivos de test |

---

## Índice

1. [Por qué este proyecto](#por-qué-este-proyecto)
2. [Qué hace](#qué-hace)
3. [Arquitectura](#arquitectura)
4. [Modelo de datos](#modelo-de-datos)
5. [Puesta en marcha](#puesta-en-marcha)
6. [Desarrollo](#desarrollo)
7. [Estado y límites conocidos](#estado-y-límites-conocidos)

---

## Por qué este proyecto

La mayoría de los sistemas de inventario se rompen en el mismo sitio: el número
que sale en pantalla deja de coincidir con la mercancía que hay en el estante, y
nadie puede decir cuándo empezó a pasar. Aquí eso es lo primero que se atacó, y
el resto de las decisiones salen de ahí.

### 1. La base de datos defiende sus propias reglas

No se confía en que el código «se acuerde». El esquema trae, además de sus claves
foráneas con política de borrado explícita:

- **Casi un centenar de restricciones `CHECK`** — que una cantidad no sea
  negativa, que un estado sea uno de los válidos, que un total cuadre con sus
  partes.
- **89 índices declarados**, para las consultas que de verdad se hacen.
- **26 guardas (`triggers`) que *prohíben*.** No derivan datos ni recalculan nada:
  cada una cierra una operación que jamás debe ocurrir, con su mensaje en
  español. Entre ellas:

  | Guarda | Qué impide |
  |---|---|
  | `guarda_movimientos_inmutables` | Editar o borrar un movimiento de inventario: el libro mayor es de solo escritura |
  | `guarda_ventas_sin_borrado` | Borrar una factura — se anula, y la anulación queda |
  | `guarda_ventas_anuladas_inmutables` | Resucitar o retocar una factura ya anulada |
  | `guarda_devolucion_no_excede_vendido` | Devolver más de lo que decía la línea de la factura, aunque sean dos devoluciones seguidas |
  | `guarda_deuda_de_orden_sin_alta` | Anotar a mano un repuesto en la deuda que nació de una orden — era el bug del **descuento doble de inventario** |
  | `guarda_bitacora_sin_borrado` | Borrar los últimos **dos años** de bitácora, ni desde la app ni con un visor de SQLite |
  | `guarda_un_solo_proveedor_principal_*` | Que un producto quede con dos proveedores marcados como principal |

  La diferencia importa: un trigger que *deriva* compite con el repositorio y
  esconde lógica en SQL que el analizador no revisa; un trigger que *prohíbe* es
  una garantía que ningún bug futuro se salta.

### 2. El inventario es un libro mayor, no un número

`productos.stock_actual` existe, pero **es un caché**. La verdad son las filas de
`movimientos_inventario`, cada una con tipo, cantidad, `stock_anterior`,
`stock_nuevo`, el usuario que la causó y el documento que la explica.

Regla que se cumple en todo el backend: **el stock nunca cambia sin escribir su
movimiento en la misma transacción.** Y todo caché lleva su consulta de
verificación —`descuadres()`— que afirma que el acumulado coincide con la suma de
sus partes, con un test que la ejecuta:

| Caché | Suma de | Verifica |
|---|---|---|
| `productos.stock_actual` | movimientos de inventario | `RepositorioInventario.descuadres()` |
| `reservas.pagado_acumulado` | abonos de la reserva | `RepositorioReservas.descuadres()` |
| `reservas.total_reserva` | líneas de la reserva | `RepositorioReservas.descuadresTotal()` |
| `deudores.monto_pagado` | pagos del deudor | `RepositorioDeudores.descuadres()` |

El caché **se recalcula entero**, nunca se le suma un delta: así no puede
desviarse aunque una escritura falle a la mitad.

### 3. Se sabe quién hizo qué — con dos mecanismos, no uno

| Pregunta | Cómo se responde |
|---|---|
| ¿Quién **creó** esta factura o movió este stock? | Columna `usuario_id` en la propia tabla, `NOT NULL` y sin valor por defecto |
| ¿Quién **editó** o **borró** aquello? | Tabla `bitacora`, inmutable |

Que la columna sea obligatoria no es cosmético: el `Companion.insert` que genera
Drift la exige como parámetro, así que **un método de escritura que se olvide del
autor no compila**. La garantía la da el compilador, no la disciplina.

La bitácora se escribe dentro de la transacción del cambio (si se revierte, el
renglón se va con ella), guarda el nombre legible de lo afectado —para que
sobreviva al borrado de la fila— y no se puede editar ni podar por debajo de dos
años.

### 4. Permisos que se configuran, no que se programan

**46 permisos** repartidos en 14 módulos. El catálogo vive en código porque la app
tiene que saber qué compuerta abre cada uno; **cuáles tiene cada cuenta vive en la
base** y lo cambia el administrador desde la app, sin recompilar.

- La compuerta que vale es la del repositorio: `exigir(Permiso.x)` como primera
  línea del método (cerca de **130 llamadas** en el backend). Esconder un botón es orden,
  no control.
- En la interfaz, el widget `SiPuede` recorta lo que no corresponde, y el menú
  lateral se filtra en vivo: quitarle el mostrador a un cajero se nota sin que
  tenga que volver a entrar.
- Un administrador los tiene todos y no se le pueden quitar, por lo mismo que no
  se puede desactivar al último admin: dejaría la app sin nadie capaz de
  arreglarla desde dentro.

### 5. Errores tipados, no cadenas de texto

Las escrituras devuelven un tipo sellado, no un `String?` donde `null` significa
«salió bien»:

```dart
switch (await notifier.crear(producto)) {
  case Exito():
    controlador.cerrar();
  case Fallo(motivo: MotivoFallo.skuDuplicado):
    _resaltarCampoSku();          // el diálogo señala el campo que estorba
  case Fallo(:final mensaje):
    mostrarError(mensaje);
}
```

Así se distingue «SKU duplicado» de «falló la base de datos» sin comparar
mensajes, y el texto de la interfaz lo decide la interfaz.

### 6. Numeración de documentos a prueba de huecos

`FAC-0042`, `COT-2026-0007`, `ORD-0041`… El número sale de la tabla
`consecutivos`, pedido **dentro de la transacción que crea el documento** con un
`UPSERT … RETURNING`. Nunca del `id` autoincremental —que deja huecos con cada
`INSERT` fallido— ni de un `MAX(numero) + 1`, que **reutiliza** el número del
último documento borrado: en facturación, lo peor que puede pasar.

### 7. Un solo motor de impresión para seis documentos

Factura, cotización, orden de servicio, reserva, deuda y compra pasan todas por
`ConstructorPdf`. Cada módulo traduce su modelo a un `DocumentoImprimible` y una
sola clase pinta. **Carta y tirilla térmica de 58 mm son el mismo documento en dos
anchos**, no dos plantillas: con dos, la letra pequeña de una y otra empezarían a
divergir el mismo día.

### 8. El IVA se calcula en un solo sitio

Antes convivían tres constantes con valores distintos y el mismo producto salía
sin IVA por el punto de venta y con 19 % por una cotización. Hoy todo pasa por
`core/iva_app.dart`, con la tasa guardada en configuración y aplicada antes del
primer frame. El precio del catálogo es la base gravable, el descuento se resta
antes del impuesto —como se liquida en Colombia— y el total es
`subtotal − descuento + iva`.

Y lo que ya se facturó no se toca: cada documento guarda el IVA con que se cerró.
Subir la tasa mañana no reescribe la factura de ayer.

El dinero se guarda en **enteros** (pesos, sin decimales) y se formatea en un
único archivo, `core/formato.dart`, con `intl` y locale `es_CO`.

### 9. Rendimiento pensado para catálogos grandes

Objetivo explícito: un frame en ≤ 16 ms con miles de productos.

- **La paginación la resuelve SQLite**, no la interfaz: el `WHERE`, el `COUNT` y
  el `LIMIT` van en el repositorio, que devuelve los ítems **y el total real**
  (`observarPagina` → `PaginaProductos`).
- Conteos y agregados con `COUNT`/`GROUP BY`; los streams cortan con `.distinct`
  comparando contenido para no notificar de más.
- `ListView.builder` con `itemExtent`, `const` agresivo, `setState` lo más abajo
  posible y cálculos derivados en providers —no dentro de `build()`—.
- Las miniaturas se decodifican al tamaño en que se pintan (`cacheWidth`) y el
  caché de imágenes de Flutter baja de 100 MB a 32 MB: el valor de fábrica está
  pensado para fotos a pantalla completa en un teléfono, no para miniaturas de
  44 px en tablas de cientos de filas.
- El *shell* usa un `IndexedStack` perezoso: una pantalla que nadie abrió no se
  construye.

### 10. Una sola biblioteca de widgets, y una sola regla

`lib/frontend/share/` (75 archivos) es la fuente única de verdad de lo visual.
**Todo widget de share es `StatelessWidget`**: recibe datos ya resueltos, avisa
por callbacks, no consulta providers y no conoce el modelo de dominio. Los tokens
son `ColoresApp` y `TipografiaApp`, nunca `Theme.of(context)`.

La regla que manda sobre las demás es *reusar antes de crear*, y extender gana a
duplicar: un botón con un parámetro nuevo es mejor que un botón nuevo. El costo de
no hacerlo no es estético — con tres copias de la misma rejilla, cada una decide
por su cuenta qué le pasa a la tarjeta, y un dato termina apareciendo en dos
pantallas de tres.

### 11. Una sola forma de inyectar dependencias

Todo por **Riverpod**. `get_it` y `provider` salieron del proyecto y no vuelven.
Nada de *service location*: una clase no va a buscar sus dependencias a un
registro global, las recibe por el constructor —incluida la sesión del usuario—.

```dart
final repositorioProductosProvider = Provider(
  (ref) => RepositorioProductosImpl(
    ref.watch(appDatabaseProvider),
    ref.watch(sesionActualProvider),
  ),
);
```

Mirar el constructor basta para saber qué necesita la clase, y un test le pasa lo
que quiera sin montar nada global.

### 12. Tests donde está el riesgo

**92 archivos de test**: repositorios contra Drift en memoria y widgets de la
biblioteca compartida.

Los tests de base de datos corren con `PRAGMA foreign_keys = ON`, igual que
producción. No es un detalle: SQLite lo trae **apagado** por defecto, así que sin
él un test verde no prueba nada sobre las claves foráneas —insertar una venta con
un cliente inexistente pasaría en silencio—.

Además, un test de regresión no cuenta hasta verlo fallar: se rompe el código a
propósito, se confirma que el test se cae, y se restaura.

### 13. Teclado primero

Es una app de uso intensivo: se trabaja con teclado, no con mouse. **Esc** cierra
sin guardar, **Ctrl+Enter** guarda —y no `Enter` a secas, porque hay campos de
varias líneas donde `Enter` debe seguir siendo salto de línea—, **Ctrl+F** enfoca
el buscador. Está resuelto una vez en `AtajosFormulario` y no se reimplementa.

### 14. Lints estrictos y cero avisos

`prefer_const_constructors`, `prefer_const_literals_to_create_immutables`,
`unawaited_futures`, `avoid_print`, `use_build_context_synchronously`. El repo se
mantiene en **cero avisos**: si `flutter analyze` dice algo, salió del cambio en
curso. Una regla que la máquina verifica vale más que una escrita en un documento.

---

## Qué hace

| Módulo | Qué resuelve |
|---|---|
| **Punto de venta** | Catálogo paginado, carrito, descuentos, IVA, cobro por método de pago e impresión inmediata |
| **Productos** | SKU único, código de barras, precio público y precio taller, stock mínimo, ubicación en bodega, imagen, compatibilidad con modelos de moto y **varios proveedores por repuesto** |
| **Inventario** | Libro de entradas y salidas con su documento de origen; ajustes manuales bajo permiso |
| **Órdenes de servicio** | Moto y cliente, tareas con técnico asignado, repuestos que descuentan stock, cargos libres, estados (abierta → lista → entregada) y **cierre a crédito** que pasa la orden a cuentas por cobrar sin volver a mover inventario |
| **Cotizaciones** | Editor tipo POS con autoguardado; se convierte en venta |
| **Reservas** | Apartado con abonos parciales y saldo pendiente |
| **Cuentas por cobrar** | Deudas con sus líneas y sus pagos; las que nacen de una orden quedan selladas |
| **Devoluciones** | Parcial o total contra una factura, con reingreso de stock opcional según si la pieza vuelve vendible |
| **Compras** | Remisión del proveedor en borrador, líneas, cierre que da entrada a la mercancía y anulación que la saca |
| **Clientes y motos** | Fichas con documento, teléfono y las motos de cada uno (marca, modelo, placa) |
| **Técnicos** | Fichas y especialidades; una especialidad muestra su gente |
| **Proveedores** | Fichas y el historial de compras a cada uno |
| **Usuarios** | Cuentas, roles y permisos por cuenta; contraseñas con bcrypt y recuperación por código al correo |
| **Bitácora** | Quién editó o borró qué, cuándo, con el nombre de lo afectado |
| **Configuración** | Datos del negocio para los impresos, tasa de IVA, formato de impresión, catálogos (categorías, unidades, servicios, marcas, especialidades) |

---

## Arquitectura

Separación estricta **backend / frontend** por carpetas, y dentro de cada una,
organización por *feature*.

```
lib/
├── core/                       # transversal y sin dependencias de capa
│   ├── formato.dart            #   único sitio donde se formatea dinero y fechas
│   ├── iva_app.dart            #   única fuente de verdad de la tasa de IVA
│   ├── resultado.dart          #   sealed Resultado / Exito / Fallo
│   └── validaciones.dart
│
├── backend/                    # datos y reglas de negocio — no conoce Flutter
│   ├── features/<modulo>/
│   │   ├── esquema_datos/      #   tablas Drift, CHECK, índices, FKs
│   │   ├── modelo/             #   modelos de dominio
│   │   ├── mapper/             #   fila ↔ modelo
│   │   ├── enum/
│   │   └── repositorio/        #   interfaz abstracta + Impl
│   └── share/
│       ├── database/           #   AppDb, guardas_sql.dart, provider
│       ├── consecutivos/       #   numeración transaccional de documentos
│       ├── dominio/            #   Permiso, RolUsuario, SesionActual, MetodoPago
│       └── servicios/          #   correo y códigos de verificación
│
└── frontend/                   # interfaz — no importa nada de backend/ desde share
    ├── layout/                 # shell: barra lateral filtrada por permisos
    ├── features/<modulo>/
    │   ├── provider/           #   AsyncNotifier + providers derivados
    │   ├── vista/              #   pantallas
    │   └── widgets/            #   piezas que conocen el dominio del módulo
    └── share/                  # biblioteca compartida: StatelessWidget puros
        ├── temas/ botones/ inputs/ filtros/ tablas/ cards/ feedback/ nav/ …
        └── README.md
```

### El camino de una operación

Cobrar una venta, de punta a punta:

1. La vista dispara un callback; el `AsyncNotifier` del módulo llama al
   repositorio (`ref.read` en callbacks, nunca `ref.watch`).
2. El repositorio abre **una transacción** y dentro de ella:
   `exigir(Permiso.posVender)` → pide el consecutivo → inserta la venta y sus
   líneas con `usuario_id` → escribe un movimiento de inventario por línea →
   recalcula el `stock_actual` de cada producto con su valor final.
3. Las guardas de la base vigilan lo que el código no debería poder hacer. Si
   algo falla, la transacción entera se revierte: no queda media venta.
4. Devuelve un `Resultado` tipado.
5. Los `Stream` de Drift reemiten; las pantallas que observan ese dato se
   actualizan solas. La vista decide qué texto mostrar si hubo `Fallo`.

### Reglas de capa

- `frontend/share/` **nunca** importa de `backend/`; para eso están los DTO de
  presentación.
- El notifier depende de la **interfaz** del repositorio, nunca de la `Impl`.
- La lógica de negocio vive en el repositorio — no en el notifier ni en la vista.
- Archivos por debajo de ~300 líneas; pasado eso se parte por responsabilidad.
- Todo en español: nombres, comentarios, docstrings y mensajes de interfaz. Los
  comentarios explican **por qué**, no qué.

---

## Modelo de datos

38 tablas en un solo archivo SQLite, con WAL activado y claves foráneas
encendidas.

| Bloque | Tablas |
|---|---|
| **Identidad** | `personas` (base común), `clientes`, `proveedores`, `tecnicos`, `usuarios`, `usuario_permisos` |
| **Catálogo** | `productos`, `categorias`, `unidades_medida`, `producto_proveedores`, `producto_compatibilidad`, `servicios` |
| **Motos** | `marcas_moto`, `modelos_moto`, `motos` |
| **Movimiento** | `movimientos_inventario`, `compras`, `compra_detalles` |
| **Venta** | `ventas`, `venta_detalles`, `devoluciones`, `devolucion_detalles` |
| **Taller** | `ordenes_servicio`, `ordenes_tareas`, `ordenes_repuestos`, `ordenes_cargos`, `especializaciones` |
| **Crédito** | `deudores`, `deudor_items`, `deudor_pagos`, `reservas`, `reserva_items`, `reserva_abonos` |
| **Documentos** | `cotizaciones`, `cotizacion_items`, `consecutivos` |
| **Sistema** | `configuracion`, `bitacora` |

Decisiones de modelado que conviene conocer antes de tocar el esquema:

- **Un dato vive en una sola tabla.** Cliente, proveedor, técnico y usuario no
  repiten identidad: todos cuelgan de `personas`.
- **Excepción deliberada: el snapshot histórico.** Una línea de factura guarda el
  nombre y el precio con que se vendió. Cambiar el precio del catálogo no puede
  reescribir lo que ya se cobró.
- **Tipos canónicos:** dinero en `int` (pesos), fechas en `DateTime`, cantidades
  en `real`, estados en `TEXT` mayúsculas con su `CHECK`.
- **Baja lógica, no borrado**, en todo lo que algún documento pueda referenciar.
- **`NOT NULL` por defecto**; nulo solo cuando «no se sabe» es un estado real.

---

## Puesta en marcha

### Requisitos

- Flutter (canal estable) con soporte de escritorio habilitado.
- En Linux: `clang`, `cmake`, `ninja-build`, `libgtk-3-dev`.

### Instalación

```bash
git clone git@github.com:Kevin7908/Inventario-K1.git
cd Inventario-K1

flutter pub get
dart run build_runner build --delete-conflicting-outputs   # genera el código de Drift

cp .env.ejemplo .env        # opcional: solo para el envío de correos
flutter run -d linux        # o -d windows / -d macos
```

La base se crea sola en la primera ejecución, en la carpeta de documentos del
usuario (`InventarioK1.sqlite`).

### El archivo `.env`

Las credenciales SMTP —la cuenta desde la que salen los correos de recuperación y
su contraseña de aplicación— van en un `.env` en la raíz del proyecto, o junto al
ejecutable en una instalación real. Está en `.gitignore` y nunca sube al
repositorio; `.env.ejemplo` documenta las claves.

Si el archivo falta, **la app arranca igual**: lo único que deja de funcionar es
el envío de correos, y recuperar la contraseña lo dice en pantalla en vez de
fallar en silencio.

---

## Desarrollo

```bash
# Regenerar el código de Drift tras tocar una tabla
dart run build_runner build --delete-conflicting-outputs

# Verificación antes de integrar (no hay CI: la verificación es local)
flutter analyze        # tiene que quedar en cero avisos
flutter test           # tiene que quedar en verde

# Llenar la base con datos de prueba de volumen realista
SEMBRAR=1 flutter test test/datos/sembrar_datos_test.dart
SEMBRAR=1 BD=/ruta/otra.sqlite flutter test test/datos/sembrar_datos_test.dart

# Volcar el esquema real que crea Drift (para revisarlo o documentarlo)
flutter test test/volcado_esquema_test.dart   # escribe /tmp/esquema.sql
python3 tool/generar_sql_diseno.py            # lo convierte en el .sql de diseño
```

El sembrador siembra el catálogo **una sola vez**: correrlo de nuevo agrega
operación sobre los mismos productos, sin inflar el inventario. Y respeta las
mismas reglas que la app —el stock se escribe con su valor final, nunca sumando
deltas—, así que `descuadres()` tiene que seguir dando vacío después de sembrar.

### Convención de commits

`<tipo>: <resumen>` en minúsculas, sin punto final, máximo 72 caracteres, en
español. Tipos: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`.
Nunca se trabaja directo sobre `main` ni sobre `dev`.

---

## Estado y límites conocidos

Se dicen en voz alta, porque saberlos es parte de evaluar el proyecto:

- **`schemaVersion` está en 1 y la base se recrea.** Mientras el sistema esté en
  desarrollo no hay migraciones: borrar el `.sqlite` es una opción válida. En
  cuanto haya un taller con datos reales, todo cambio de esquema pasa a llevar
  migración *y* test de migración, y eso deja de valer.
- **Los permisos no son seguridad.** El `.sqlite` está en el disco del taller y
  quien tenga el equipo lo abre con cualquier visor. Evitan la equivocación —que
  el cajero no borre un producto sin querer, que no anule la venta de ayer—, no a
  alguien decidido a saltárselos. Se diseñaron con esa vara.
- **Los códigos de verificación viven en memoria.** Un código de diez minutos no
  merece una tabla; cerrar la app a mitad del flujo obliga a pedir otro.
- **Es una app de escritorio.** Las carpetas `android/` e `ios/` vienen de la
  plantilla de Flutter: la interfaz está diseñada para teclado, barra lateral fija
  y tablas anchas.
