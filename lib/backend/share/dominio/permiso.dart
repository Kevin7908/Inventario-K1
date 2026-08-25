/// Los módulos de la app, para agrupar los permisos en la pantalla que los
/// configura. Es el orden en que se pintan.
enum ModuloPermiso {
  puntoVenta('Punto de venta'),
  productos('Productos'),
  categorias('Categorías'),
  proveedores('Proveedores'),
  ordenes('Órdenes de servicio'),
  cotizaciones('Cotizaciones'),
  reservas('Reservas'),
  deudores('Cuentas por cobrar'),
  clientes('Clientes'),
  tecnicos('Técnicos'),
  configuracion('Configuración'),
  administracion('Administración');

  const ModuloPermiso(this.etiqueta);

  final String etiqueta;
}

/// Lo que una cuenta puede hacer. **Se configura, no se programa.**
///
/// El catálogo vive aquí porque la app necesita saber qué compuerta abre cada
/// permiso —eso es código—; **cuáles tiene cada cuenta vive en la base**, en
/// `usuario_permisos`, y lo cambia el administrador desde Configuración →
/// Usuarios sin recompilar nada.
///
/// Un administrador los tiene todos y eso no se puede editar, por lo mismo que
/// no se puede desactivar al último admin: dejaría la app sin nadie capaz de
/// devolverle el permiso a nadie.
///
/// **Qué protege esto y qué no.** Es una app de escritorio con su `.sqlite` en
/// el disco: quien tenga el equipo puede abrir el archivo con cualquier visor.
/// Los permisos no son una barrera contra alguien que quiera saltárselos, son
/// una barrera contra la equivocación —que el cajero no borre un producto sin
/// querer, que no anule la venta de ayer—. Se diseñan con esa vara.
///
/// [codigo] es lo que viaja a la base y lo que valida el `CHECK`; [etiqueta] y
/// [descripcion] son lo que se lee en la pantalla de configuración.
enum Permiso {
  // Punto de venta
  posVer('POS_VER', ModuloPermiso.puntoVenta, 'Entrar al mostrador',
      'Abrir el punto de venta y consultar el catálogo.'),
  posVender('POS_VENDER', ModuloPermiso.puntoVenta, 'Cobrar ventas',
      'Cerrar una venta y recibir el pago.'),
  posDescuento('POS_DESCUENTO', ModuloPermiso.puntoVenta, 'Aplicar descuentos',
      'Bajar el total de una venta antes de cobrarla.'),
  posAnular('POS_ANULAR', ModuloPermiso.puntoVenta, 'Anular ventas',
      'Deshacer una venta ya cobrada y devolver su mercancía al inventario.'),

  // Productos
  productosVer('PRODUCTOS_VER', ModuloPermiso.productos, 'Ver el inventario',
      'Consultar productos, precios y existencias.'),
  productosCrear('PRODUCTOS_CREAR', ModuloPermiso.productos, 'Crear productos',
      'Dar de alta un producto nuevo en el catálogo.'),
  productosEditar('PRODUCTOS_EDITAR', ModuloPermiso.productos,
      'Editar productos', 'Cambiar nombre, precio, costo o datos de un producto.'),
  productosEliminar('PRODUCTOS_ELIMINAR', ModuloPermiso.productos,
      'Eliminar productos', 'Sacar un producto del catálogo.'),
  productosStock('PRODUCTOS_STOCK', ModuloPermiso.productos,
      'Ajustar stock a mano',
      'Corregir existencias sin que medie una venta o una compra.'),

  // Categorías
  categoriasVer('CATEGORIAS_VER', ModuloPermiso.categorias, 'Ver categorías',
      'Consultar las categorías del catálogo.'),
  categoriasEditar('CATEGORIAS_EDITAR', ModuloPermiso.categorias,
      'Crear y editar categorías', 'Dar de alta o cambiar una categoría.'),
  categoriasEliminar('CATEGORIAS_ELIMINAR', ModuloPermiso.categorias,
      'Eliminar categorías', 'Sacar una categoría del catálogo.'),

  // Proveedores
  proveedoresVer('PROVEEDORES_VER', ModuloPermiso.proveedores,
      'Ver proveedores', 'Consultar la lista de proveedores.'),
  proveedoresEditar('PROVEEDORES_EDITAR', ModuloPermiso.proveedores,
      'Crear y editar proveedores', 'Dar de alta o cambiar un proveedor.'),
  proveedoresEliminar('PROVEEDORES_ELIMINAR', ModuloPermiso.proveedores,
      'Eliminar proveedores', 'Sacar un proveedor de la lista.'),

  // Órdenes de servicio
  ordenesVer('ORDENES_VER', ModuloPermiso.ordenes, 'Ver órdenes',
      'Consultar las órdenes del taller y su detalle.'),
  ordenesCrear('ORDENES_CREAR', ModuloPermiso.ordenes, 'Abrir órdenes',
      'Registrar una orden de servicio nueva.'),
  ordenesEditar('ORDENES_EDITAR', ModuloPermiso.ordenes, 'Trabajar la orden',
      'Anotar tareas, repuestos y cargos, y cambiar su estado.'),
  ordenesEliminar('ORDENES_ELIMINAR', ModuloPermiso.ordenes,
      'Eliminar órdenes', 'Borrar una orden y devolver sus repuestos.'),

  // Cotizaciones
  cotizacionesVer('COTIZACIONES_VER', ModuloPermiso.cotizaciones,
      'Ver cotizaciones', 'Consultar las cotizaciones emitidas.'),
  cotizacionesCrear('COTIZACIONES_CREAR', ModuloPermiso.cotizaciones,
      'Crear cotizaciones', 'Armar una cotización nueva.'),
  cotizacionesEditar('COTIZACIONES_EDITAR', ModuloPermiso.cotizaciones,
      'Editar cotizaciones', 'Cambiar las líneas de una cotización.'),
  cotizacionesEliminar('COTIZACIONES_ELIMINAR', ModuloPermiso.cotizaciones,
      'Eliminar cotizaciones', 'Borrar una cotización.'),

  // Reservas
  reservasVer('RESERVAS_VER', ModuloPermiso.reservas, 'Ver reservas',
      'Consultar lo apartado y sus abonos.'),
  reservasCrear('RESERVAS_CREAR', ModuloPermiso.reservas, 'Apartar mercancía',
      'Abrir una reserva y anotarle repuestos.'),
  reservasAbonar('RESERVAS_ABONAR', ModuloPermiso.reservas, 'Recibir abonos',
      'Registrar un abono contra una reserva.'),
  reservasEliminar('RESERVAS_ELIMINAR', ModuloPermiso.reservas,
      'Cancelar reservas',
      'Cancelar una reserva y devolver su mercancía a la bodega.'),

  // Cuentas por cobrar
  deudoresVer('DEUDORES_VER', ModuloPermiso.deudores, 'Ver la cartera',
      'Consultar quién debe y cuánto.'),
  deudoresCrear('DEUDORES_CREAR', ModuloPermiso.deudores, 'Fiar',
      'Abrir una deuda y sacar la mercancía del taller.'),
  deudoresCobrar('DEUDORES_COBRAR', ModuloPermiso.deudores, 'Recibir pagos',
      'Registrar un abono contra una deuda.'),
  deudoresEliminar('DEUDORES_ELIMINAR', ModuloPermiso.deudores,
      'Eliminar deudas', 'Borrar una deuda de la cartera.'),

  // Clientes
  clientesVer('CLIENTES_VER', ModuloPermiso.clientes, 'Ver clientes',
      'Consultar clientes y sus motos.'),
  clientesEditar('CLIENTES_EDITAR', ModuloPermiso.clientes,
      'Crear y editar clientes', 'Dar de alta o cambiar un cliente o su moto.'),
  clientesEliminar('CLIENTES_ELIMINAR', ModuloPermiso.clientes,
      'Eliminar clientes', 'Sacar un cliente del registro.'),

  // Técnicos
  tecnicosVer('TECNICOS_VER', ModuloPermiso.tecnicos, 'Ver técnicos',
      'Consultar los técnicos del taller.'),
  tecnicosEditar('TECNICOS_EDITAR', ModuloPermiso.tecnicos,
      'Crear y editar técnicos', 'Dar de alta o cambiar un técnico.'),
  tecnicosEliminar('TECNICOS_ELIMINAR', ModuloPermiso.tecnicos,
      'Eliminar técnicos', 'Sacar un técnico del registro.'),

  // Configuración
  configuracionVer('CONFIGURACION_VER', ModuloPermiso.configuracion,
      'Entrar a Configuración',
      'Ver los datos del negocio y los catálogos base.'),
  configuracionEditar('CONFIGURACION_EDITAR', ModuloPermiso.configuracion,
      'Editar la configuración',
      'Cambiar datos del negocio, unidades, especializaciones, servicios y motos.'),

  // Administración
  usuariosAdministrar('USUARIOS_ADMINISTRAR', ModuloPermiso.administracion,
      'Administrar cuentas',
      'Crear cuentas, activarlas, cambiar roles y permisos.'),
  bitacoraVer('BITACORA_VER', ModuloPermiso.administracion, 'Ver la bitácora',
      'Consultar quién hizo qué y cuándo.');

  const Permiso(this.codigo, this.modulo, this.etiqueta, this.descripcion);

  final String codigo;
  final ModuloPermiso modulo;
  final String etiqueta;
  final String descripcion;

  /// Fragmento `IN (...)` para el `CHECK` de `usuario_permisos`. Sale del enum
  /// para que agregar un permiso no obligue a acordarse de la tabla.
  static String get listaSql => values.map((p) => "'${p.codigo}'").join(', ');

  /// Traduce lo guardado. Devuelve `null` si el código no existe: un permiso
  /// que se quitó del catálogo y quedó en filas viejas se ignora en vez de
  /// convertirse en otro por accidente.
  static Permiso? desdeCodigo(String codigo) {
    for (final permiso in values) {
      if (permiso.codigo == codigo) return permiso;
    }
    return null;
  }

  /// Los permisos de un módulo, en el orden en que están declarados.
  static List<Permiso> delModulo(ModuloPermiso modulo) =>
      values.where((p) => p.modulo == modulo).toList();
}
