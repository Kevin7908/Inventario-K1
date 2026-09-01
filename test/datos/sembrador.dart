// Genera datos de prueba con volumen realista sobre una base ya creada.
//
// **No prueba nada**: es la utilidad que usa `sembrar_datos_test.dart`. Los dos
// viven en `test/datos/`, aparte de `test/soporte/` —que son ayudantes de los
// tests de verdad— porque esto no prueba nada: llena la base real. Y separado
// del test porque con nueve módulos no cabe en un archivo que se lea de una
// sentada.
//
// Dos reglas que se cumplen en todo el archivo, y que son la razón de que esto
// sirva para medir:
//
//   · **El stock se lleva en memoria y se escribe al final** con el valor
//     exacto que quedó. Nunca se le suma un delta al caché: así no puede
//     desviarse del libro mayor, y `descuadres()` tiene que dar vacío.
//   · **Nada se inserta contra una orden ya cerrada.** Las guardas de la base
//     lo impiden, así que la orden nace ABIERTA, recibe sus tareas y repuestos,
//     y solo entonces se le pone el estado final.
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart';
import 'package:inventario_k1/backend/features/inventario/modelo/movimiento_inventario.dart';
import 'package:inventario_k1/backend/share/consecutivos/documento_consecutivo.dart';
import 'package:inventario_k1/backend/share/database/app_db.dart';
import 'package:inventario_k1/backend/share/dominio/permiso.dart';
import 'package:inventario_k1/backend/share/dominio/rol_usuario.dart';

/// Cuánto de cada cosa. El catálogo solo se siembra si la base está vacía; la
/// operación se agrega siempre, así que correr esto dos veces duplica los
/// documentos sin tocar los productos.
class VolumenSiembra {
  const VolumenSiembra({
    this.categorias = 2000,
    this.proveedores = 300,
    this.clientes = 1500,
    this.productos = 5000,
    this.tecnicos = 40,
    this.servicios = 60,
    this.cajeros = 4,
    this.ventas = 3000,
    this.ordenes = 2500,
    this.cotizaciones = 2000,
    this.reservas = 1200,
    this.deudores = 1000,
    this.compras = 900,
  });

  final int categorias;
  final int proveedores;
  final int clientes;
  final int productos;
  final int tecnicos;
  final int servicios;
  final int cajeros;
  final int ventas;
  final int ordenes;
  final int cotizaciones;
  final int reservas;
  final int deudores;

  /// Remisiones del proveedor. Van **antes** que los documentos que sacan
  /// mercancía: lo que entra por una compra es lo que después se vende.
  final int compras;
}

const _marcas = ['Bajaj', 'Yamaha', 'Honda', 'Suzuki', 'AKT', 'TVS', 'KTM'];
const _lineas = ['Pulsar', 'FZ', 'CB', 'Gixxer', 'NKD', 'Apache', 'Duke'];
const _familias = [
  'Frenos', 'Aceites', 'Filtros', 'Llantas', 'Cadenas', 'Bujías',
  'Amortiguadores', 'Baterías', 'Espejos', 'Farolas', 'Guayas', 'Empaques',
  'Rodamientos', 'Piñones', 'Carburadores', 'Escapes', 'Manubrios',
  'Cascos', 'Guantes', 'Aditivos',
];
const _nombres = [
  'Carlos', 'María', 'Jorge', 'Ana', 'Luis', 'Sofía', 'Andrés', 'Paula',
  'Diego', 'Camila', 'Julián', 'Valentina', 'Óscar', 'Daniela', 'Fabián',
];
const _apellidos = [
  'Ramírez', 'Gómez', 'Rodríguez', 'Martínez', 'López', 'Hernández',
  'Torres', 'Vargas', 'Castro', 'Rojas', 'Moreno', 'Jiménez', 'Ruiz',
];
const _trabajos = [
  'Cambio de aceite', 'Sincronización', 'Ajuste de frenos', 'Cambio de guaya',
  'Revisión eléctrica', 'Cambio de kit de arrastre', 'Lavado de carburador',
  'Alineación', 'Cambio de llanta', 'Ajuste de válvulas', 'Cambio de batería',
  'Revisión general',
];
const _especialidades = [
  'Motor', 'Electricidad', 'Frenos', 'Suspensión', 'Transmisión',
  'Latonería', 'Pintura', 'Diagnóstico',
];
const _metodosAbono = ['EFECTIVO', 'TRANSFERENCIA', 'TARJETA', 'NEQUI', 'DAVIPLATA'];

/// Lo que un cajero puede hacer. Menos que un administrador a propósito: es lo
/// que hace realista la bitácora y las compuertas.
const _permisosCajero = [
  Permiso.posVer, Permiso.posVender, Permiso.posDescuento,
  Permiso.productosVer, Permiso.inventarioMovimientosVer,
  Permiso.clientesVer, Permiso.clientesEditar,
  Permiso.ordenesVer, Permiso.ordenesCrear, Permiso.ordenesEditar,
  Permiso.cotizacionesVer, Permiso.cotizacionesCrear,
  Permiso.reservasVer, Permiso.reservasCrear, Permiso.reservasAbonar,
  Permiso.deudoresVer, Permiso.deudoresCrear, Permiso.deudoresCobrar,
  Permiso.categoriasVer, Permiso.proveedoresVer,
];

class Sembrador {
  Sembrador(this.db, {this.volumen = const VolumenSiembra(), int semilla = 20260826})
      : _rnd = Random(semilla);

  final AppDb db;
  final VolumenSiembra volumen;

  /// Semilla fija: dos corridas dan los mismos datos, que es lo que hace
  /// comparable una medición de rendimiento contra otra.
  final Random _rnd;

  final _ahora = DateTime.now();

  /// Quiénes pueden firmar. El primero es el administrador que ya existía.
  final _autores = <int>[];

  /// El stock que va quedando por producto. Se escribe al caché al final.
  final _stock = <int, double>{};

  /// Contadores de documento, por serie y periodo. Se vuelcan a `consecutivos`
  /// al terminar: si no, la app repetiría números y chocaría con el UNIQUE.
  final _contadores = <String, int>{};

  List<int> _categorias = [];
  List<int> _proveedores = [];
  List<int> _clientes = [];
  List<int> _motos = [];
  List<int> _marcasMoto = [];
  List<int> _modelosMoto = [];
  List<int> _productos = [];
  List<int> _unidades = [];
  List<int> _servicios = [];
  List<int> _tecnicos = [];

  final _precios = <int, ({int venta, int compra, String nombre})>{};

  T _uno<T>(List<T> lista) => lista[_rnd.nextInt(lista.length)];
  int _autor() => _uno(_autores);

  /// Un importe en pesos enteros, redondeado a los cien más cercanos para que
  /// se parezca a un precio de verdad.
  int _precio(int desde, int hasta) =>
      ((desde + _rnd.nextInt(hasta - desde)) ~/ 100) * 100;

  /// Una fecha repartida en los últimos [dias], para que los filtros de rango
  /// del historial y del kardex tengan algo real que filtrar.
  DateTime _fecha({int dias = 365}) =>
      _ahora.subtract(Duration(minutes: _rnd.nextInt(dias * 24 * 60)));

  /// El siguiente número de una serie, llevando la cuenta por periodo como lo
  /// hace `RepositorioConsecutivos`.
  String _numero(DocumentoConsecutivo doc, DateTime fecha) {
    final periodo = doc.periodoDe(fecha);
    final clave = '${doc.codigo}|$periodo';
    final siguiente = (_contadores[clave] ?? 0) + 1;
    _contadores[clave] = siguiente;
    return doc.formatear(siguiente, periodo: periodo);
  }

  Future<int> _maxId(String tabla) => db
      .customSelect('SELECT COALESCE(MAX(id), 0) AS m FROM $tabla')
      .getSingle()
      .then((f) => f.read<int>('m'));

  Future<List<int>> _ids(String tabla, [String orden = 'id']) => db
      .customSelect('SELECT id FROM $tabla ORDER BY $orden')
      .get()
      .then((filas) => filas.map((f) => f.read<int>('id')).toList());

  // ═══════════════════════════════════════════════════════════════════════
  //  Entrada
  // ═══════════════════════════════════════════════════════════════════════

  /// Sitúa los contadores donde los dejó una corrida anterior, para que los
  /// números de documento sigan sin repetirse.
  Future<void> _cargarContadores() async {
    for (final fila in await db.customSelect(
      'SELECT documento, periodo, ultimo FROM consecutivos',
    ).get()) {
      _contadores['${fila.read<String>('documento')}|'
          '${fila.read<int>('periodo')}'] = fila.read<int>('ultimo');
    }
  }

  Future<void> _guardarContadores() async {
    for (final entrada in _contadores.entries) {
      final partes = entrada.key.split('|');
      await db.customStatement(
        'INSERT INTO consecutivos (documento, periodo, ultimo) '
        'VALUES (?1, ?2, ?3) '
        'ON CONFLICT (documento, periodo) DO UPDATE SET ultimo = ?3',
        [partes[0], int.parse(partes[1]), entrada.value],
      );
    }
  }

  Future<Map<String, int>> sembrar() async {
    await _cargarContadores();
    await _cuentas();

    // El catálogo solo se siembra una vez: correr esto de nuevo agrega
    // documentos sobre los mismos productos, que es lo que se quiere para
    // subir el volumen sin inflar el inventario.
    final yaHayCatalogo = (await _maxId('productos')) > 0;
    if (!yaHayCatalogo) {
      await _catalogo();
      await _personas();
      await _inventarioInicial();
    } else {
      await _cargarCatalogoExistente();
    }

    await _tecnicosYServicios();
    await _compatibilidades();
    await _compras();
    await _ventas();
    await _ordenes();
    await _cotizaciones();
    await _reservas();
    await _cuentasPorCobrar();
    await _deshacer();

    await _escribirCacheStock();
    await _guardarContadores();

    return _conteos();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Cuentas: el administrador que ya estaba, más los cajeros
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _cuentas() async {
    _autores.addAll(await _ids('usuarios'));

    if (_autores.isEmpty) {
      final personaId = await db.into(db.tablaPersona).insert(
            TablaPersonaCompanion.insert(
              nombres: 'Administrador',
              apellidos: const Value('del taller'),
            ),
          );
      _autores.add(
        await db.into(db.tablaUsuario).insert(
              TablaUsuarioCompanion.insert(
                personaId: personaId,
                usuario: 'admin',
                passwordHash:
                    BCrypt.hashpw('admin1234', BCrypt.gensalt(logRounds: 12)),
                rol: Value(RolUsuario.admin.codigo),
              ),
            ),
      );
    }

    // Los cajeros solo se crean si no están: el `usuario` es UNIQUE.
    final existentes = (await db
            .customSelect("SELECT usuario FROM usuarios WHERE usuario LIKE 'cajero%'")
            .get())
        .map((f) => f.read<String>('usuario'))
        .toSet();

    // Un hash para los cuatro: bcrypt con 12 rondas cuesta un cuarto de
    // segundo cada uno y aquí no se está probando el hash.
    final hash = BCrypt.hashpw('cajero1234', BCrypt.gensalt(logRounds: 10));

    for (var i = 1; i <= volumen.cajeros; i++) {
      final usuario = 'cajero$i';
      if (existentes.contains(usuario)) continue;

      final personaId = await db.into(db.tablaPersona).insert(
            TablaPersonaCompanion.insert(
              nombres: _uno(_nombres),
              apellidos: Value(_uno(_apellidos)),
              documento: Value('${1000000 + i}'),
              telefono: Value('30000000$i'),
            ),
          );

      final usuarioId = await db.into(db.tablaUsuario).insert(
            TablaUsuarioCompanion.insert(
              personaId: personaId,
              usuario: usuario,
              passwordHash: hash,
              rol: Value(RolUsuario.cajero.codigo),
            ),
          );

      // Un cajero no es administrador, así que sus permisos son filas. Solo
      // el primero puede anular y devolver: es lo realista, y hace que las
      // compuertas del historial de ventas se puedan probar de verdad.
      final suyos = [
        ..._permisosCajero,
        if (i == 1) Permiso.posAnular,
      ];
      await db.batch((b) {
        for (final permiso in suyos) {
          b.insert(
            db.tablaUsuarioPermiso,
            TablaUsuarioPermisoCompanion.insert(
              usuarioId: usuarioId,
              permiso: permiso.codigo,
            ),
          );
        }
      });

      _autores.add(usuarioId);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Catálogo
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _catalogo() async {
    const unidades = [
      ('Unidad', 'und'), ('Litro', 'L'), ('Galón', 'gal'), ('Metro', 'm'),
      ('Juego', 'jgo'), ('Par', 'par'), ('Caja', 'cja'), ('Kilogramo', 'kg'),
    ];
    for (final (nombre, abrev) in unidades) {
      final existe = await (db.select(db.tablaUnidadesMedida)
            ..where((u) => u.nombre.equals(nombre)))
          .getSingleOrNull();
      _unidades.add(existe?.id ??
          await db.into(db.tablaUnidadesMedida).insert(
                TablaUnidadesMedidaCompanion.insert(
                  nombre: nombre,
                  abreviatura: abrev,
                ),
              ));
    }

    await db.batch((b) {
      for (var i = 1; i <= volumen.categorias; i++) {
        b.insert(
          db.tablaCategoria,
          TablaCategoriaCompanion.insert(
            nombre: '${_uno(_familias)} ${_uno(_lineas)} '
                '${i.toString().padLeft(4, '0')}',
            descripcion: const Value('Categoría de prueba'),
          ),
        );
      }
    });
    _categorias = await _ids('categorias');
  }

  /// Personas, proveedores, clientes y motos.
  ///
  /// `documento` y `telefono` son UNIQUE en `personas`, así que llevan el
  /// índice dentro. El desfase evita chocar con lo que ya hubiera cargado.
  Future<void> _personas() async {
    for (var i = 0; i < volumen.proveedores + volumen.clientes; i++) {
      final esProveedor = i < volumen.proveedores;
      final personaId = await db.into(db.tablaPersona).insert(
            TablaPersonaCompanion.insert(
              tipoDocumento: Value(esProveedor ? 'NIT' : 'CC'),
              documento: Value('${900000000 + i}'),
              nombres: esProveedor
                  ? 'Repuestos ${_uno(_familias)} ${i + 1}'
                  : _uno(_nombres),
              apellidos: Value(esProveedor ? null : _uno(_apellidos)),
              telefono: Value('3${100000000 + i}'),
              ciudad: const Value('Bucaramanga'),
            ),
          );

      if (esProveedor) {
        _proveedores.add(await db
            .into(db.tablaProveedor)
            .insert(TablaProveedorCompanion.insert(personaId: personaId)));
      } else {
        _clientes.add(await db
            .into(db.tablaCliente)
            .insert(TablaClienteCompanion.insert(personaId: personaId)));
      }
    }

    // El catálogo primero: la marca y el modelo son FK, no texto (§1.3). Se
    // siembra el producto cartesiano de las dos listas para que cualquier
    // combinación que salga sorteada exista.
    final marcaPorNombre = <String, int>{};
    for (final marca in _marcas) {
      marcaPorNombre[marca] = await db
          .into(db.tablaMarcaMoto)
          .insert(TablaMarcaMotoCompanion.insert(nombre: marca));
    }
    final modeloPorClave = <String, int>{};
    for (final marca in _marcas) {
      for (final linea in _lineas) {
        modeloPorClave['$marca|$linea'] = await db.into(db.tablaModeloMoto).insert(
              TablaModeloMotoCompanion.insert(
                marcaId: marcaPorNombre[marca]!,
                nombre: linea,
                cilindraje:
                    Value(_uno(const [100, 125, 150, 180, 200, 250])),
              ),
            );
      }
    }

    await db.batch((b) {
      for (var i = 0; i < _clientes.length; i++) {
        final marca = _uno(_marcas);
        final linea = _uno(_lineas);
        // Una de cada diez entra sin modelo: es el caso que la columna admite
        // —en el mostrador la marca siempre se sabe y el modelo exacto a veces
        // no está catalogado— y sin sembrarlo no habría con qué probar que las
        // consultas lo aguantan.
        final sinModelo = _rnd.nextInt(10) == 0;
        b.insert(
          db.tablaMoto,
          TablaMotoCompanion.insert(
            clienteId: _clientes[i],
            placa: Value('S${100000 + i}'),
            marcaId: marcaPorNombre[marca]!,
            modeloId: sinModelo
                ? const Value.absent()
                : Value(modeloPorClave['$marca|$linea']!),
            anio: Value(2010 + _rnd.nextInt(16)),
          ),
        );
      }
    });
    _motos = await _ids('motos');
    _marcasMoto = marcaPorNombre.values.toList(growable: false);
    _modelosMoto = modeloPorClave.values.toList(growable: false);
  }

  /// Los productos nacen con stock 0: el inventario inicial entra como
  /// movimiento, que es la única forma de que el caché y el libro mayor
  /// arranquen cuadrados (`REGLAS_BD.md` §7).
  Future<void> _inventarioInicial() async {
    final desde = await _maxId('productos');

    await db.batch((b) {
      for (var i = 1; i <= volumen.productos; i++) {
        final compra = _precio(3000, 180000);
        final venta = ((compra * (1.25 + _rnd.nextDouble() * 0.35)) ~/ 100) * 100;
        final nombre = '${_uno(_familias)} ${_uno(_marcas)} '
            '${_uno(_lineas)} ${i.toString().padLeft(4, '0')}';

        _precios[desde + i] = (venta: venta, compra: compra, nombre: nombre);

        b.insert(
          db.tablaProducto,
          TablaProductoCompanion.insert(
            id: Value(desde + i),
            // Seis dígitos: `formatearSku` rellena a tres, así que este
            // formato no lo puede generar la app y nunca chocan.
            sku: 'SEED-${i.toString().padLeft(6, '0')}',
            // Solo a dos de cada tres: el código de barras viene impreso de
            // fábrica y falta en todo lo que llega a granel. Sembrarlo en
            // todos escondería justo el caso que la columna admite —varios
            // NULL bajo el mismo UNIQUE—.
            codigoBarras: Value(
              _rnd.nextInt(3) == 0
                  ? null
                  : '77${(10000000000 + desde + i).toString().substring(0, 11)}',
            ),
            nombre: nombre,
            descripcion: const Value('Producto de prueba'),
            categoriaId: Value(_uno(_categorias)),
            unidadMedidaId: Value(_uno(_unidades)),
            proveedorId: Value(_uno(_proveedores)),
            precioCompra: Value(compra),
            precioVenta: Value(venta),
            stockMinimo: Value(_rnd.nextInt(6).toDouble()),
            ubicacionBodega: Value(
              'Estante ${String.fromCharCode(65 + _rnd.nextInt(8))}-'
              '${1 + _rnd.nextInt(20)}',
            ),
          ),
        );
      }
    });

    _productos = [for (var i = 1; i <= volumen.productos; i++) desde + i];

    await db.batch((b) {
      for (final id in _productos) {
        // Holgado a propósito: por encima hay ~16.000 líneas de documento que
        // van a ir descontando, y el stock no puede llegar a cero o los
        // documentos de después saldrían vacíos.
        final inicial = (60 + _rnd.nextInt(240)).toDouble();
        _stock[id] = inicial;
        b.insert(
          db.tablaMovimientoInventario,
          TablaMovimientoInventarioCompanion.insert(
            productoId: id,
            tipo: TipoMovimiento.ajusteInicial.codigo,
            cantidad: inicial,
            usuarioId: _autores.first,
            notas: const Value('Carga inicial de prueba'),
          ),
        );
      }
    });
  }

  /// Cuando el catálogo ya está sembrado, se lee en vez de crearse.
  Future<void> _cargarCatalogoExistente() async {
    _categorias = await _ids('categorias');
    _proveedores = await _ids('proveedores');
    _clientes = await _ids('clientes');
    _motos = await _ids('motos');
    _marcasMoto = await _ids('marcas_moto');
    _modelosMoto = await _ids('modelos_moto');
    _unidades = await _ids('unidades_medida');

    for (final fila in await db
        .customSelect(
          'SELECT id, nombre, precio_venta, precio_compra, stock_actual '
          'FROM productos',
        )
        .get()) {
      final id = fila.read<int>('id');
      _productos.add(id);
      _stock[id] = fila.read<double>('stock_actual');
      _precios[id] = (
        venta: fila.read<int>('precio_venta'),
        compra: fila.read<int>('precio_compra'),
        nombre: fila.read<String>('nombre'),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Técnicos y servicios
  // ═══════════════════════════════════════════════════════════════════════

  /// A qué motos le sirve cada repuesto.
  ///
  /// **Es acumulativa como el resto**: solo declara lo que falta, así que
  /// correr el sembrador dos veces no duplica líneas —y no podría, porque la
  /// comprobación de repetido vive en el repositorio y aquí se inserta a
  /// pelo—.
  ///
  /// Reparte a propósito los dos niveles que la tabla admite: una de cada
  /// cuatro es de marca —«sirve para cualquier Yamaha», el caso del aceite— y
  /// el resto de modelo. Sembrar solo uno de los dos dejaría sin datos justo
  /// la mitad que hay que probar.
  ///
  /// Tampoco los declara todos: un catálogo donde **todo** es compatible con
  /// **todo** hace que el filtro «solo para esta moto» no se note.
  Future<void> _compatibilidades() async {
    if (_marcasMoto.isEmpty || _productos.isEmpty) return;

    final yaHay = await _maxId('producto_compatibilidades');
    if (yaHay > 0) return;

    // Un `Set` por producto para no repetir la misma línea: la `UNIQUE` de la
    // tabla no la cierra, porque SQLite trata cada NULL como distinto.
    var puestas = 0;
    await db.batch((b) {
      for (final productoId in _productos) {
        // Dos de cada tres repuestos declaran algo; el resto se queda sin
        // compatibilidad, que es lo normal en un catálogo real.
        if (_rnd.nextInt(3) == 0) continue;

        final deMarca = <int>{};
        final deModelo = <int>{};
        for (var i = 0; i < 1 + _rnd.nextInt(3); i++) {
          if (_rnd.nextInt(4) == 0) {
            deMarca.add(_uno(_marcasMoto));
          } else if (_modelosMoto.isNotEmpty) {
            deModelo.add(_uno(_modelosMoto));
          }
        }

        for (final marcaId in deMarca) {
          b.insert(
            db.tablaProductoCompatibilidad,
            TablaProductoCompatibilidadCompanion.insert(
              productoId: productoId,
              marcaId: Value(marcaId),
            ),
          );
          puestas++;
        }
        for (final modeloId in deModelo) {
          b.insert(
            db.tablaProductoCompatibilidad,
            TablaProductoCompatibilidadCompanion.insert(
              productoId: productoId,
              modeloId: Value(modeloId),
            ),
          );
          puestas++;
        }
      }
    });
    assert(puestas >= 0);
  }

  Future<void> _tecnicosYServicios() async {
    _tecnicos = await _ids('tecnicos');
    _servicios = await _ids('servicios');
    if (_tecnicos.isNotEmpty && _servicios.isNotEmpty) return;

    final especializaciones = <int>[];
    for (final nombre in _especialidades) {
      final existe = await (db.select(db.tablaEspecializacion)
            ..where((e) => e.nombre.equals(nombre)))
          .getSingleOrNull();
      especializaciones.add(existe?.id ??
          await db
              .into(db.tablaEspecializacion)
              .insert(TablaEspecializacionCompanion.insert(nombre: nombre)));
    }

    for (var i = 0; i < volumen.tecnicos; i++) {
      final personaId = await db.into(db.tablaPersona).insert(
            TablaPersonaCompanion.insert(
              documento: Value('${800000000 + i}'),
              nombres: _uno(_nombres),
              apellidos: Value(_uno(_apellidos)),
              telefono: Value('32${10000000 + i}'),
              ciudad: const Value('Bucaramanga'),
            ),
          );
      _tecnicos.add(
        await db.into(db.tablaTecnico).insert(
              TablaTecnicoCompanion.insert(
                personaId: personaId,
                especializacionId: Value(_uno(especializaciones)),
                salarioBase: Value((1300000 + _rnd.nextInt(900000)).toDouble()),
              ),
            ),
      );
    }

    await db.batch((b) {
      for (var i = 0; i < volumen.servicios; i++) {
        b.insert(
          db.tablaServicio,
          TablaServicioCompanion.insert(
            nombre: '${_uno(_trabajos)} ${_uno(_lineas)} '
                '${(i + 1).toString().padLeft(3, '0')}',
            precioSugerido: Value(_precio(15000, 220000)),
          ),
        );
      }
    });
    _servicios = await _ids('servicios');
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Documentos
  // ═══════════════════════════════════════════════════════════════════════

  /// Cuánto se puede sacar de [productoId] sin dejarlo en negativo.
  double? _tomar(int productoId, int maximo) {
    final hay = _stock[productoId] ?? 0;
    if (hay < 1) return null;
    final cantidad = (1 + _rnd.nextInt(maximo)).clamp(1, hay.toInt()).toDouble();
    _stock[productoId] = hay - cantidad;
    return cantidad;
  }

  /// [cuantos] productos distintos que todavía tengan existencias.
  Set<int> _conStock(int cuantos) {
    final elegidos = <int>{};
    var intentos = 0;
    while (elegidos.length < cuantos && intentos < cuantos * 20) {
      intentos++;
      final id = _uno(_productos);
      if ((_stock[id] ?? 0) >= 1) elegidos.add(id);
    }
    return elegidos;
  }

  /// Remisiones del proveedor: **lo único que mete mercancía** además de la
  /// carga inicial.
  ///
  /// Va antes que ventas, órdenes, reservas y cartera porque es de donde sale
  /// lo que todos ellos descuentan. Cada línea deja su entrada en el libro
  /// mayor y su costo en `productos.precio_compra`, igual que
  /// `RepositorioCompras.registrar`: si el sembrador escribiera una cosa y el
  /// repositorio otra, medir contra estos datos no diría nada.
  ///
  /// Una de cada veinte se anula, con su salida en negativo: sin eso el filtro
  /// de estado del listado no tendría qué filtrar.
  Future<void> _compras() async {
    for (var c = 0; c < volumen.compras; c++) {
      final fecha = _fecha(dias: 300);
      final autor = _autor();
      final proveedorId = _uno(_proveedores);
      final elegidos = _algunos(2 + _rnd.nextInt(6));
      if (elegidos.isEmpty) continue;

      final compraId = await db.into(db.tablaCompra).insert(
            TablaCompraCompanion.insert(
              numero: _numero(DocumentoConsecutivo.compra, fecha),
              proveedorId: proveedorId,
              // Una de cada cinco llega sin papel: es el caso que el UNIQUE
              // compuesto admite con NULL y el que más se ve en el mostrador.
              numeroFactura: Value(
                _rnd.nextInt(5) == 0
                    ? null
                    : 'FV-${(100000 + _rnd.nextInt(899999))}',
              ),
              fecha: Value(fecha),
              usuarioId: autor,
              creadoEn: Value(fecha),
              actualizadoEn: Value(fecha),
            ),
          );

      var total = 0;
      final entradas = <int, double>{};
      for (final productoId in elegidos) {
        final precio = _precios[productoId]!;
        final cantidad = (5 + _rnd.nextInt(40)).toDouble();
        // El proveedor sube y baja: sin variación no habría con qué probar el
        // «¿nos subieron el precio?» que el módulo existe para responder.
        final costo = (precio.compra * (0.9 + _rnd.nextDouble() * 0.3)).round();
        total += (cantidad * costo).round();
        entradas[productoId] = cantidad;

        await db.into(db.tablaCompraDetalle).insert(
              TablaCompraDetalleCompanion.insert(
                compraId: compraId,
                productoId: productoId,
                descripcion: precio.nombre,
                cantidad: cantidad,
                costoUnitario: costo,
              ),
            );

        await db.into(db.tablaMovimientoInventario).insert(
              TablaMovimientoInventarioCompanion.insert(
                productoId: productoId,
                tipo: TipoMovimiento.entradaCompra.codigo,
                cantidad: cantidad,
                compraId: Value(compraId),
                usuarioId: autor,
                creadoEn: Value(fecha),
              ),
            );

        _stock[productoId] = (_stock[productoId] ?? 0) + cantidad;
        _precios[productoId] = (
          venta: precio.venta,
          compra: costo,
          nombre: precio.nombre,
        );
      }

      // Las sembradas son historia: ya se contaron y se archivaron. Un
      // borrador es lo que está a medio teclear ahora mismo, y de eso no hay
      // en un histórico.
      await (db.update(db.tablaCompra)..where((t) => t.id.equals(compraId)))
          .write(TablaCompraCompanion(
        total: Value(total),
        estado: const Value('REGISTRADA'),
      ));

      // El costo de referencia queda en el último pagado, como hace el
      // repositorio.
      await db.batch((b) {
        for (final productoId in entradas.keys) {
          b.update(
            db.tablaProducto,
            TablaProductoCompanion(
              precioCompra: Value(_precios[productoId]!.compra),
            ),
            where: (p) => p.id.equals(productoId),
          );
        }
      });

      if (_rnd.nextInt(20) != 0) continue;

      // Anulada: sale lo que había entrado, y solo si todavía está.
      for (final entrada in entradas.entries) {
        final hay = _stock[entrada.key] ?? 0;
        if (hay < entrada.value) continue;
        _stock[entrada.key] = hay - entrada.value;
        await db.into(db.tablaMovimientoInventario).insert(
              TablaMovimientoInventarioCompanion.insert(
                productoId: entrada.key,
                tipo: TipoMovimiento.ajusteNegativo.codigo,
                cantidad: -entrada.value,
                compraId: Value(compraId),
                usuarioId: autor,
                notas: const Value('Anulación de la compra'),
                creadoEn: Value(fecha),
              ),
            );
      }
      await (db.update(db.tablaCompra)..where((t) => t.id.equals(compraId)))
          .write(const TablaCompraCompanion(estado: Value('ANULADA')));
    }
  }

  /// [cuantos] productos distintos, tengan existencias o no: una compra los
  /// **trae**, así que no hace falta que quede algo en el estante.
  Set<int> _algunos(int cuantos) {
    final elegidos = <int>{};
    while (elegidos.length < cuantos && _productos.isNotEmpty) {
      elegidos.add(_uno(_productos));
      if (elegidos.length >= _productos.length) break;
    }
    return elegidos;
  }

  Future<void> _ventas() async {
    for (var v = 0; v < volumen.ventas; v++) {
      final fecha = _fecha();
      final autor = _autor();
      final elegidos = _conStock(1 + _rnd.nextInt(4));
      if (elegidos.isEmpty) continue;

      final ventaId = await db.into(db.tablaVentas).insert(
            TablaVentasCompanion.insert(
              numeroFactura: _numero(DocumentoConsecutivo.factura, fecha),
              tipo: const Value('MOSTRADOR'),
              clienteId:
                  Value(_rnd.nextInt(10) < 7 ? _uno(_clientes) : null),
              estadoPago: const Value('PAGADO'),
              metodoPago: Value(_uno(_metodosAbono)),
              usuarioId: autor,
              creadoEn: Value(fecha),
              actualizadoEn: Value(fecha),
            ),
          );

      var subtotal = 0;
      for (final productoId in elegidos) {
        final cantidad = _tomar(productoId, 3);
        if (cantidad == null) continue;
        final precio = _precios[productoId]!;
        final linea = (cantidad * precio.venta).round();
        subtotal += linea;

        await db.into(db.tablaVentaDetalles).insert(
              TablaVentaDetallesCompanion.insert(
                ventaId: ventaId,
                tipoItem: 'PRODUCTO',
                productoId: Value(productoId),
                descripcion: precio.nombre,
                cantidad: Value(cantidad),
                precioUnitario: precio.venta,
                costoUnitario: Value(precio.compra),
                subtotal: linea,
              ),
            );

        await db.into(db.tablaMovimientoInventario).insert(
              TablaMovimientoInventarioCompanion.insert(
                productoId: productoId,
                tipo: TipoMovimiento.salidaVenta.codigo,
                cantidad: -cantidad,
                ventaId: Value(ventaId),
                usuarioId: autor,
                creadoEn: Value(fecha),
              ),
            );
      }

      await (db.update(db.tablaVentas)..where((t) => t.id.equals(ventaId)))
          .write(TablaVentasCompanion(
        subtotal: Value(subtotal),
        total: Value(subtotal),
        totalPagado: Value(subtotal),
      ));
    }
  }

  /// Órdenes con sus tareas, repuestos y cargos.
  ///
  /// **La orden nace ABIERTA y se cierra al final.** Las guardas
  /// `guarda_repuestos_orden_cerrada` y `guarda_tareas_orden_cerrada` rechazan
  /// cualquier inserción contra una orden ENTREGADA o ANULADA, así que el
  /// estado definitivo se pone después de colgarle todo.
  Future<void> _ordenes() async {
    const estados = ['ABIERTA', 'LISTA', 'ENTREGADA', 'ENTREGADA', 'ANULADA'];

    for (var o = 0; o < volumen.ordenes; o++) {
      final fecha = _fecha();
      final autor = _autor();
      final clienteId = _uno(_clientes);
      final motoId = _uno(_motos);

      final ordenId = await db.into(db.tablaOrdenesServicio).insert(
            TablaOrdenesServicioCompanion.insert(
              numero: _numero(DocumentoConsecutivo.orden, fecha),
              motoId: motoId,
              clienteId: clienteId,
              kilometrajeEntrada: 5000 + _rnd.nextInt(90000),
              diagnostico: Value(_uno(_trabajos)),
              usuarioId: autor,
              fechaIngreso: Value(fecha),
              actualizadoEn: Value(fecha),
            ),
          );

      await db.batch((b) {
        for (var t = 0; t < 1 + _rnd.nextInt(2); t++) {
          b.insert(
            db.tablaOrdenesTarea,
            TablaOrdenesTareaCompanion.insert(
              usuarioId: autor,
              ordenId: ordenId,
              servicioId: _uno(_servicios),
              tecnicoId: _uno(_tecnicos),
              precioPactado: Value(_precio(15000, 220000)),
              completado: Value(_rnd.nextBool()),
              creadoEn: Value(fecha),
            ),
          );
        }
        if (_rnd.nextInt(10) < 5) {
          b.insert(
            db.tablaOrdenesCargo,
            TablaOrdenesCargoCompanion.insert(
              usuarioId: autor,
              ordenId: ordenId,
              descripcion: _uno(const [
                'Lavado', 'Insumos varios', 'Domicilio', 'Grúa', 'Diagnóstico',
              ]),
              precio: Value(_precio(5000, 60000)),
              creadoEn: Value(fecha),
            ),
          );
        }
      });

      // Los repuestos descuentan stock al anotarlos, con su movimiento.
      for (final productoId in _conStock(1 + _rnd.nextInt(2))) {
        final cantidad = _tomar(productoId, 2);
        if (cantidad == null) continue;
        final precio = _precios[productoId]!;

        await db.into(db.tablaOrdenesRepuesto).insert(
              TablaOrdenesRepuestoCompanion.insert(
                usuarioId: autor,
                ordenId: ordenId,
                productoId: productoId,
                cantidad: Value(cantidad),
                precioUnitario: Value(precio.venta),
                creadoEn: Value(fecha),
              ),
            );

        await db.into(db.tablaMovimientoInventario).insert(
              TablaMovimientoInventarioCompanion.insert(
                productoId: productoId,
                tipo: TipoMovimiento.salidaServicio.codigo,
                cantidad: -cantidad,
                ordenId: Value(ordenId),
                usuarioId: autor,
                creadoEn: Value(fecha),
              ),
            );
      }

      // Ahora sí: el estado final. Antes de esto la orden tenía que estar
      // abierta o las guardas habrían rechazado todo lo de arriba.
      final estado = _uno(estados);
      if (estado != 'ABIERTA') {
        await (db.update(db.tablaOrdenesServicio)
              ..where((t) => t.id.equals(ordenId)))
            .write(TablaOrdenesServicioCompanion(
          estado: Value(estado),
          fechaSalida: Value(
            estado == 'ENTREGADA'
                ? fecha.add(Duration(hours: 4 + _rnd.nextInt(72)))
                : null,
          ),
        ));
      }

      // Una de cada cinco entregadas se fía. **Sin tocar el inventario**: los
      // repuestos salieron del estante arriba, al anotarlos. Sembrarlo con un
      // movimiento más sería reproducir el bug que el cierre a crédito vino a
      // cerrar, y `descuadres()` lo cantaría.
      if (estado == 'ENTREGADA' && _rnd.nextInt(5) == 0) {
        await _fiarOrden(
          ordenId: ordenId,
          clienteId: clienteId,
          motoId: motoId,
          numeroOrden: await _numeroDeOrden(ordenId),
          fecha: fecha,
          autor: autor,
        );
      }
    }
  }

  Future<String> _numeroDeOrden(int ordenId) => db
      .customSelect(
        'SELECT numero FROM ordenes_servicio WHERE id = ?',
        variables: [Variable.withInt(ordenId)],
      )
      .getSingle()
      .then((f) => f.read<String>('numero'));

  /// La deuda que nace de cerrar una orden a crédito.
  ///
  /// Copia las tres clases de línea —repuestos, mano de obra y cargos— con su
  /// descripción congelada, y **no registra un solo movimiento**. El enlace
  /// `orden_id` se escribe **al final**, después de las líneas: la guarda de
  /// `guardas_sql.dart` cierra a la edición las líneas de toda deuda que ya lo
  /// tenga, así que ponerlo antes rechazaría estos mismos `INSERT`.
  Future<void> _fiarOrden({
    required int ordenId,
    required int clienteId,
    required int motoId,
    required String numeroOrden,
    required DateTime fecha,
    required int autor,
  }) async {
    final repuestos = await db.customSelect(
      'SELECT orp.producto_id, orp.cantidad, orp.precio_unitario, p.nombre '
      'FROM ordenes_repuestos orp JOIN productos p ON p.id = orp.producto_id '
      'WHERE orp.orden_id = ?',
      variables: [Variable.withInt(ordenId)],
    ).get();
    final tareas = await db.customSelect(
      'SELECT ot.precio_pactado, s.nombre FROM ordenes_tareas ot '
      'JOIN servicios s ON s.id = ot.servicio_id WHERE ot.orden_id = ?',
      variables: [Variable.withInt(ordenId)],
    ).get();
    final cargos = await db.customSelect(
      'SELECT descripcion, precio FROM ordenes_cargos WHERE orden_id = ?',
      variables: [Variable.withInt(ordenId)],
    ).get();

    if (repuestos.isEmpty && tareas.isEmpty && cargos.isEmpty) return;

    final deudorId = await db.into(db.tablaDeudor).insert(
          TablaDeudorCompanion.insert(
            numero: _numero(DocumentoConsecutivo.deuda, fecha),
            clienteId: clienteId,
            motoId: Value(motoId),
            concepto: Value('Orden $numeroOrden'),
            fechaVencimiento:
                Value(fecha.add(Duration(days: 15 + _rnd.nextInt(30)))),
            usuarioId: autor,
            creadoEn: Value(fecha),
            actualizadoEn: Value(fecha),
          ),
        );

    var total = 0;
    Future<void> linea({
      int? productoId,
      required String descripcion,
      required double cantidad,
      required int precio,
    }) async {
      total += (cantidad * precio).round();
      await db.into(db.tablaDeudorItem).insert(
            TablaDeudorItemCompanion.insert(
              usuarioId: autor,
              deudorId: deudorId,
              productoId: Value(productoId),
              descripcion: descripcion,
              cantidad: cantidad,
              precioUnitario: precio,
            ),
          );
    }

    for (final r in repuestos) {
      await linea(
        productoId: r.read<int>('producto_id'),
        descripcion: r.read<String>('nombre'),
        cantidad: r.read<double>('cantidad'),
        precio: r.read<int>('precio_unitario'),
      );
    }
    for (final t in tareas) {
      await linea(
        descripcion: t.read<String>('nombre'),
        cantidad: 1,
        precio: t.read<int>('precio_pactado'),
      );
    }
    for (final c in cargos) {
      await linea(
        descripcion: c.read<String>('descripcion'),
        cantidad: 1,
        precio: c.read<int>('precio'),
      );
    }

    // Una de cada tres ya abonó algo: la cartera necesita fiados de orden en
    // los dos estados para que el filtro tenga qué mostrar.
    final pagado = _rnd.nextInt(3) == 0
        ? (total * (0.2 + _rnd.nextDouble() * 0.5)).round()
        : 0;
    if (pagado > 0) {
      await db.into(db.tablaDeudorPago).insert(
            TablaDeudorPagoCompanion.insert(
              deudorId: deudorId,
              monto: pagado,
              metodoPago: _uno(_metodosAbono),
              fechaPago: Value(fecha.add(const Duration(days: 8))),
              usuarioId: _autor(),
            ),
          );
    }

    await (db.update(db.tablaDeudor)..where((t) => t.id.equals(deudorId)))
        .write(TablaDeudorCompanion(
      ordenId: Value(ordenId),
      montoTotal: Value(total),
      montoPagado: Value(pagado),
    ));
  }

  /// Cotizaciones: **no mueven stock**. Cotizar no es apartar.
  Future<void> _cotizaciones() async {
    for (var c = 0; c < volumen.cotizaciones; c++) {
      final fecha = _fecha();
      final autor = _autor();

      final cotizacionId = await db.into(db.tablaCotizacion).insert(
            TablaCotizacionCompanion.insert(
              numero: _numero(DocumentoConsecutivo.cotizacion, fecha),
              clienteId: Value(_uno(_clientes)),
              motoId: Value(_rnd.nextBool() ? _uno(_motos) : null),
              vigenciaHasta: fecha.add(const Duration(days: 15)),
              usuarioId: autor,
              creadoEn: Value(fecha),
              actualizadoEn: Value(fecha),
            ),
          );

      var subtotal = 0;
      for (var i = 0; i < 1 + _rnd.nextInt(4); i++) {
        // Una línea de producto o una de servicio; el `CHECK` de la tabla
        // exige que la referencia case con el tipo.
        final esProducto = _rnd.nextInt(10) < 7;
        final cantidad = (1 + _rnd.nextInt(3)).toDouble();

        final (descripcion, unitario, productoId, servicioId) = esProducto
            ? (() {
                final id = _uno(_productos);
                final p = _precios[id]!;
                return (p.nombre, p.venta, id, null as int?);
              })()
            : (_uno(_trabajos), _precio(15000, 220000), null as int?, _uno(_servicios));

        final linea = (cantidad * unitario).round();
        subtotal += linea;

        await db.into(db.tablaCotizacionItem).insert(
              TablaCotizacionItemCompanion.insert(
                usuarioId: autor,
                cotizacionId: cotizacionId,
                tipoItem: esProducto ? 'PRODUCTO' : 'SERVICIO',
                productoId: Value(productoId),
                servicioId: Value(servicioId),
                descripcion: descripcion,
                cantidad: cantidad,
                precioUnitario: unitario,
                subtotal: linea,
              ),
            );
      }

      await (db.update(db.tablaCotizacion)
            ..where((t) => t.id.equals(cotizacionId)))
          .write(TablaCotizacionCompanion(subtotal: Value(subtotal)));
    }
  }

  /// Reservas: la mercancía **sale del inventario** aunque siga en la bodega.
  /// `total_reserva` es caché de sus ítems y `pagado_acumulado` de sus abonos.
  Future<void> _reservas() async {
    for (var r = 0; r < volumen.reservas; r++) {
      final fecha = _fecha(dias: 180);
      final autor = _autor();
      final elegidos = _conStock(1 + _rnd.nextInt(3));
      if (elegidos.isEmpty) continue;

      final reservaId = await db.into(db.tablaReserva).insert(
            TablaReservaCompanion.insert(
              numero: _numero(DocumentoConsecutivo.reserva, fecha),
              clienteId: _uno(_clientes),
              motoId: Value(_rnd.nextBool() ? _uno(_motos) : null),
              totalReserva: 0,
              fechaLimite: Value(fecha.add(const Duration(days: 30))),
              usuarioId: autor,
              creadoEn: Value(fecha),
              actualizadoEn: Value(fecha),
            ),
          );

      var total = 0;
      for (final productoId in elegidos) {
        final cantidad = _tomar(productoId, 2);
        if (cantidad == null) continue;
        final precio = _precios[productoId]!;
        total += (cantidad * precio.venta).round();

        await db.into(db.tablaReservaItem).insert(
              TablaReservaItemCompanion.insert(
                usuarioId: autor,
                reservaId: reservaId,
                productoId: productoId,
                cantidad: cantidad,
                precioUnitario: precio.venta,
              ),
            );

        await db.into(db.tablaMovimientoInventario).insert(
              TablaMovimientoInventarioCompanion.insert(
                productoId: productoId,
                tipo: TipoMovimiento.salidaReserva.codigo,
                cantidad: -cantidad,
                reservaId: Value(reservaId),
                usuarioId: autor,
                creadoEn: Value(fecha),
              ),
            );
      }

      // Los abonos nunca pasan del total: lo impide un `CHECK`.
      var pagado = 0;
      for (var a = 0; a < 1 + _rnd.nextInt(3); a++) {
        final falta = total - pagado;
        if (falta <= 0) break;
        final monto = a == 0 ? (total * 0.3).round().clamp(1, falta) : falta;
        if (monto <= 0) break;
        pagado += monto;

        await db.into(db.tablaReservaAbono).insert(
              TablaReservaAbonoCompanion.insert(
                reservaId: reservaId,
                monto: monto,
                metodoPago: _uno(_metodosAbono),
                fechaPago: Value(fecha.add(Duration(days: a * 7))),
                usuarioId: _autor(),
              ),
            );
        if (_rnd.nextBool()) break;
      }

      await (db.update(db.tablaReserva)..where((t) => t.id.equals(reservaId)))
          .write(TablaReservaCompanion(
        totalReserva: Value(total),
        pagadoAcumulado: Value(pagado),
        estado: Value(pagado >= total && total > 0 ? 'COMPLETADA' : 'ACTIVA'),
      ));
    }
  }

  /// Cuentas por cobrar. **Fiar saca la mercancía del taller**: el cliente se
  /// la llevó puesta en la moto, así que el movimiento es SALIDA_FIADO y no
  /// vuelve.
  Future<void> _cuentasPorCobrar() async {
    for (var d = 0; d < volumen.deudores; d++) {
      final fecha = _fecha(dias: 240);
      final autor = _autor();
      final elegidos = _conStock(1 + _rnd.nextInt(3));
      if (elegidos.isEmpty) continue;

      final deudorId = await db.into(db.tablaDeudor).insert(
            TablaDeudorCompanion.insert(
              numero: _numero(DocumentoConsecutivo.deuda, fecha),
              clienteId: _uno(_clientes),
              motoId: Value(_rnd.nextBool() ? _uno(_motos) : null),
              concepto: Value(_uno(_trabajos)),
              fechaVencimiento:
                  Value(fecha.add(Duration(days: 15 + _rnd.nextInt(45)))),
              usuarioId: autor,
              creadoEn: Value(fecha),
              actualizadoEn: Value(fecha),
            ),
          );

      var total = 0;
      // `_conStock` ya devuelve un conjunto, así que ningún producto se
      // repite: en una deuda de mostrador el repositorio le sumaría cantidad
      // a la línea que ya está, en vez de abrir otra.
      for (final productoId in elegidos) {
        final cantidad = _tomar(productoId, 2);
        if (cantidad == null) continue;
        final precio = _precios[productoId]!;
        total += (cantidad * precio.venta).round();

        await db.into(db.tablaDeudorItem).insert(
              TablaDeudorItemCompanion.insert(
                usuarioId: autor,
                deudorId: deudorId,
                productoId: Value(productoId),
                descripcion: precio.nombre,
                cantidad: cantidad,
                precioUnitario: precio.venta,
              ),
            );

        await db.into(db.tablaMovimientoInventario).insert(
              TablaMovimientoInventarioCompanion.insert(
                productoId: productoId,
                tipo: TipoMovimiento.salidaFiado.codigo,
                cantidad: -cantidad,
                deudorId: Value(deudorId),
                usuarioId: autor,
                creadoEn: Value(fecha),
              ),
            );
      }

      // Una de cada cuatro se paga entera: sin eso ninguna llegaría nunca a
      // PAGADA y el filtro de estado de la cartera no tendría qué filtrar.
      final saldaCompleta = _rnd.nextInt(4) == 0;

      var pagado = 0;
      for (var p = 0; p < 1 + _rnd.nextInt(3); p++) {
        final falta = total - pagado;
        if (falta <= 0) break;
        final ultima = saldaCompleta && p >= 1;
        final monto = ultima
            ? falta
            : (falta * (0.3 + _rnd.nextDouble() * 0.5)).round().clamp(1, falta);
        pagado += monto;

        await db.into(db.tablaDeudorPago).insert(
              TablaDeudorPagoCompanion.insert(
                deudorId: deudorId,
                monto: monto,
                metodoPago: _uno(_metodosAbono),
                fechaPago: Value(fecha.add(Duration(days: (p + 1) * 10))),
                usuarioId: _autor(),
              ),
            );
      }

      final vencida = fecha
          .add(Duration(days: 15 + _rnd.nextInt(45)))
          .isBefore(_ahora);

      await (db.update(db.tablaDeudor)..where((t) => t.id.equals(deudorId)))
          .write(TablaDeudorCompanion(
        montoTotal: Value(total),
        montoPagado: Value(pagado),
        estado: Value(
          pagado >= total && total > 0
              ? 'PAGADA'
              : vencida
                  ? 'VENCIDA'
                  : 'ACTIVA',
        ),
      ));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Lo que se deshace
  // ═══════════════════════════════════════════════════════════════════════

  /// Devoluciones parciales, ventas anuladas y reservas canceladas.
  ///
  /// Sin esta fase el libro mayor solo tendría entradas de carga y salidas, y
  /// las cuatro pantallas que deshacen algo —el kardex filtrado por
  /// devolución, el historial de ventas, la cartera y las reservas— quedarían
  /// sin un solo caso que mostrar.
  Future<void> _deshacer() async {
    // ── Devolución parcial de una venta ────────────────────────────────
    //
    // Una de cada doce. Se devuelve **una** línea y solo una parte de ella,
    // que es lo que hace la pantalla: la factura sigue viva.
    final ventas = await db
        .customSelect(
          'SELECT id, numero_factura, creado_en FROM ventas '
          "WHERE estado_pago = 'PAGADO' ORDER BY id",
        )
        .get();

    final devueltas = <int>{};

    for (final venta in ventas) {
      if (_rnd.nextInt(12) != 0) continue;

      final ventaId = venta.read<int>('id');
      final lineas = await db
          .customSelect(
            'SELECT id, producto_id, cantidad, precio_unitario '
            'FROM venta_detalles WHERE venta_id = ? AND producto_id IS NOT NULL',
            variables: [Variable.withInt(ventaId)],
          )
          .get();
      if (lineas.isEmpty) continue;

      final linea = lineas[_rnd.nextInt(lineas.length)];
      final vendida = linea.read<double>('cantidad');
      // Al menos una unidad, y nunca toda la línea: es una devolución
      // parcial, no una anulación encubierta.
      final cantidad = vendida <= 1 ? 1.0 : (vendida - 1).floorToDouble();
      final precio = linea.read<int>('precio_unitario');
      final productoId = linea.read<int>('producto_id');
      final fecha = _fechaDe(venta.data['creado_en'])
          .add(Duration(days: 1 + _rnd.nextInt(20)));
      final autor = _autor();

      final numero = _numero(DocumentoConsecutivo.devolucion, fecha);

      final devolucionId = await db.into(db.tablaDevolucion).insert(
            TablaDevolucionCompanion.insert(
              numero: numero,
              ventaId: ventaId,
              motivo: _uno(const [
                'DEFECTUOSO', 'EQUIVOCADO', 'GARANTIA',
                'ARREPENTIMIENTO', 'ERROR_CAPTURA',
              ]),
              total: (cantidad * precio).round(),
              usuarioId: autor,
              creadoEn: Value(fecha),
            ),
          );

      await db.into(db.tablaDevolucionDetalle).insert(
            TablaDevolucionDetalleCompanion.insert(
              devolucionId: devolucionId,
              ventaDetalleId: linea.read<int>('id'),
              cantidad: cantidad,
              precioUnitario: precio,
            ),
          );

      // La mercancía vuelve al inventario.
      _stock[productoId] = (_stock[productoId] ?? 0) + cantidad;
      await db.into(db.tablaMovimientoInventario).insert(
            TablaMovimientoInventarioCompanion.insert(
              productoId: productoId,
              tipo: TipoMovimiento.devolucionVenta.codigo,
              cantidad: cantidad,
              ventaId: Value(ventaId),
              usuarioId: autor,
              notas: Value('Devolución $numero'),
              creadoEn: Value(fecha),
            ),
          );

      devueltas.add(ventaId);
    }

    // ── Ventas anuladas ────────────────────────────────────────────────
    //
    // Solo de las que no tienen devolución: mezclar las dos exigiría
    // descontar lo ya devuelto, que es lo que hace el repositorio de verdad
    // y aquí solo enturbiaría los datos.
    for (final venta in ventas) {
      final ventaId = venta.read<int>('id');
      if (devueltas.contains(ventaId) || _rnd.nextInt(25) != 0) continue;

      final fecha = _fechaDe(venta.data['creado_en'])
          .add(Duration(days: 1 + _rnd.nextInt(10)));
      final autor = _autor();

      for (final linea in await db
          .customSelect(
            'SELECT producto_id, cantidad FROM venta_detalles '
            'WHERE venta_id = ? AND producto_id IS NOT NULL',
            variables: [Variable.withInt(ventaId)],
          )
          .get()) {
        final productoId = linea.read<int>('producto_id');
        final cantidad = linea.read<double>('cantidad');
        _stock[productoId] = (_stock[productoId] ?? 0) + cantidad;

        await db.into(db.tablaMovimientoInventario).insert(
              TablaMovimientoInventarioCompanion.insert(
                productoId: productoId,
                tipo: TipoMovimiento.devolucionVenta.codigo,
                cantidad: cantidad,
                ventaId: Value(ventaId),
                usuarioId: autor,
                notas: const Value('Venta anulada'),
                creadoEn: Value(fecha),
              ),
            );
      }

      // El estado va al final: la guarda `guarda_ventas_anuladas_inmutables`
      // rechaza cualquier UPDATE posterior sobre una factura ya anulada.
      await (db.update(db.tablaVentas)..where((t) => t.id.equals(ventaId)))
          .write(TablaVentasCompanion(
        estadoPago: const Value('ANULADA'),
        actualizadoEn: Value(fecha),
      ));
    }

    // ── Reservas canceladas ────────────────────────────────────────────
    //
    // Cancelar una reserva **sí** devuelve la mercancía: nunca salió de la
    // bodega, la salida era contable. Es lo que la distingue de fiar.
    for (final reserva in await db
        .customSelect(
          "SELECT id, creado_en FROM reservas WHERE estado = 'ACTIVA'",
        )
        .get()) {
      if (_rnd.nextInt(7) != 0) continue;

      final reservaId = reserva.read<int>('id');
      final fecha = _fechaDe(reserva.data['creado_en'])
          .add(Duration(days: 5 + _rnd.nextInt(40)));
      final autor = _autor();

      for (final item in await db
          .customSelect(
            'SELECT producto_id, cantidad FROM reserva_items WHERE reserva_id = ?',
            variables: [Variable.withInt(reservaId)],
          )
          .get()) {
        final productoId = item.read<int>('producto_id');
        final cantidad = item.read<double>('cantidad');
        _stock[productoId] = (_stock[productoId] ?? 0) + cantidad;

        await db.into(db.tablaMovimientoInventario).insert(
              TablaMovimientoInventarioCompanion.insert(
                productoId: productoId,
                tipo: TipoMovimiento.devolucionReserva.codigo,
                cantidad: cantidad,
                reservaId: Value(reservaId),
                usuarioId: autor,
                notas: const Value('Reserva cancelada'),
                creadoEn: Value(fecha),
              ),
            );
      }

      await (db.update(db.tablaReserva)..where((t) => t.id.equals(reservaId)))
          .write(TablaReservaCompanion(
        estado: const Value('CANCELADA'),
        actualizadoEn: Value(fecha),
      ));
    }
  }

  /// Drift guarda las fechas como segundos desde la época; un `customSelect`
  /// las devuelve así de crudas.
  DateTime _fechaDe(Object? valor) => switch (valor) {
        final int segundos =>
          DateTime.fromMillisecondsSinceEpoch(segundos * 1000),
        final DateTime fecha => fecha,
        _ => _ahora,
      };

  // ═══════════════════════════════════════════════════════════════════════
  //  Cierre
  // ═══════════════════════════════════════════════════════════════════════

  /// El caché se escribe entero con el valor que quedó, nunca sumando deltas:
  /// así no puede desviarse del libro mayor aunque algo de arriba falle.
  Future<void> _escribirCacheStock() async {
    await db.batch((b) {
      _stock.forEach((id, cantidad) {
        b.update(
          db.tablaProducto,
          TablaProductoCompanion(stockActual: Value(cantidad)),
          where: (p) => p.id.equals(id),
        );
      });
    });
  }

  static const tablas = [
    'categorias', 'unidades_medida', 'especializaciones', 'servicios',
    'personas', 'usuarios', 'usuario_permisos', 'proveedores', 'clientes',
    'tecnicos', 'marcas_moto', 'modelos_moto', 'motos',
    'productos', 'producto_compatibilidades', 'movimientos_inventario',
    'compras', 'compra_detalles',
    'ventas', 'venta_detalles',
    'ordenes_servicio', 'ordenes_tareas', 'ordenes_repuestos', 'ordenes_cargos',
    'cotizaciones', 'cotizacion_items',
    'reservas', 'reserva_items', 'reserva_abonos',
    'deudores', 'deudor_items', 'deudor_pagos',
    'devoluciones', 'devolucion_detalles',
  ];

  Future<Map<String, int>> _conteos() async {
    final conteos = <String, int>{};
    for (final tabla in tablas) {
      conteos[tabla] = await db
          .customSelect('SELECT COUNT(*) AS n FROM $tabla')
          .getSingle()
          .then((f) => f.read<int>('n'));
    }
    return conteos;
  }
}
