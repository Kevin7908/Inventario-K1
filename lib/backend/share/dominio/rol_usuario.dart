import 'permiso.dart';

/// Qué puede hacer quien inicia sesión. **Uno solo para todo el sistema.**
///
/// Son dos y con eso alcanza para un taller: quien manda y quien atiende el
/// mostrador. Antes esto era `usuarios.es_admin`, un booleano: preguntar
/// «¿es admin?» respondía bien mientras hubiera dos papeles, pero agregar un
/// tercero —un bodeguero, un mecánico con acceso— obligaba a inventar un
/// segundo booleano y a decidir qué significa tener los dos en `true`.
///
/// [codigo] es lo que viaja a la base y lo que valida el `CHECK` de
/// `usuarios`; [etiqueta] es lo único que ve el usuario.
enum RolUsuario {
  admin('ADMIN', 'Administrador'),
  cajero('CAJERO', 'Cajero');

  const RolUsuario(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  /// Un administrador tiene **todos** los permisos y no se le pueden quitar.
  ///
  /// Es la misma razón por la que no se puede desactivar al último admin: una
  /// app donde nadie puede devolver un permiso es una app que hay que arreglar
  /// abriendo el `.sqlite` a mano.
  bool get administraUsuarios => this == RolUsuario.admin;

  /// Con qué permisos nace una cuenta de este rol.
  ///
  /// Son un **punto de partida, no una regla**: desde Configuración → Usuarios
  /// se le cambian uno por uno a cada cuenta. Lo que decide qué puede hacer
  /// alguien es su fila en `usuario_permisos`, no su rol.
  ///
  /// El cajero nace pudiendo atender el mostrador y el taller, y **sin poder
  /// borrar nada, ajustar stock a mano, anular una venta ni fiar**: son las
  /// cuatro cosas que cuestan plata y no se deshacen solas.
  Set<Permiso> get permisosPorDefecto => switch (this) {
        RolUsuario.admin => Permiso.values.toSet(),
        RolUsuario.cajero => const {
            Permiso.posVer,
            Permiso.posVender,
            Permiso.posDescuento,
            Permiso.productosVer,
            Permiso.categoriasVer,
            Permiso.proveedoresVer,
            Permiso.ordenesVer,
            Permiso.ordenesCrear,
            Permiso.ordenesEditar,
            Permiso.cotizacionesVer,
            Permiso.cotizacionesCrear,
            Permiso.cotizacionesEditar,
            Permiso.reservasVer,
            Permiso.reservasCrear,
            Permiso.reservasAbonar,
            Permiso.deudoresVer,
            Permiso.deudoresCobrar,
            Permiso.clientesVer,
            Permiso.clientesEditar,
            Permiso.tecnicosVer,
          },
      };

  /// Fragmento `IN (...)` para el `CHECK` del esquema.
  ///
  /// Se genera desde el enum para que agregar un rol no obligue a acordarse de
  /// dos sitios.
  static String get listaSql => values.map((r) => "'${r.codigo}'").join(', ');

  /// Traduce lo guardado en la base. Cae en [cajero], que es el rol sin
  /// privilegios: ante un valor que no se reconoce, lo seguro es dar de menos.
  static RolUsuario desdeCodigo(String? codigo) => values.firstWhere(
        (r) => r.codigo == (codigo ?? '').toUpperCase(),
        orElse: () => RolUsuario.cajero,
      );
}
