import 'package:equatable/equatable.dart';

/// Sobre qué se actuó. El [codigo] viaja a `bitacora.entidad` y lo valida su
/// `CHECK`; [etiqueta] es lo que se lee en la pantalla.
enum EntidadAuditada {
  producto('PRODUCTO', 'Producto'),
  categoria('CATEGORIA', 'Categoría'),
  proveedor('PROVEEDOR', 'Proveedor'),
  cliente('CLIENTE', 'Cliente'),
  moto('MOTO', 'Moto'),
  marcaMoto('MARCA_MOTO', 'Marca de moto'),
  modeloMoto('MODELO_MOTO', 'Modelo de moto'),
  tecnico('TECNICO', 'Técnico'),
  servicio('SERVICIO', 'Servicio'),
  unidadMedida('UNIDAD_MEDIDA', 'Unidad de medida'),
  especializacion('ESPECIALIZACION', 'Especialización'),
  usuario('USUARIO', 'Cuenta de usuario'),
  venta('VENTA', 'Venta'),
  orden('ORDEN', 'Orden de servicio'),
  cotizacion('COTIZACION', 'Cotización'),
  reserva('RESERVA', 'Reserva'),
  deuda('DEUDA', 'Deuda'),
  configuracion('CONFIGURACION', 'Configuración');

  const EntidadAuditada(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static String get listaSql => values.map((e) => "'${e.codigo}'").join(', ');

  static EntidadAuditada desdeCodigo(String codigo) => values.firstWhere(
        (e) => e.codigo == codigo,
        orElse: () => EntidadAuditada.configuracion,
      );
}

/// Qué se hizo.
enum AccionAuditada {
  creo('CREO', 'Creó'),
  modifico('MODIFICO', 'Modificó'),
  elimino('ELIMINO', 'Eliminó'),
  anulo('ANULO', 'Anuló'),

  /// Aparte de [anulo] a propósito: anular deshace la venta entera y la deja
  /// sin valor; devolver le quita una parte y la deja viva. Quien revisa la
  /// caja necesita distinguirlas de un vistazo.
  devolvio('DEVOLVIO', 'Devolvió');

  const AccionAuditada(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static String get listaSql => values.map((a) => "'${a.codigo}'").join(', ');

  static AccionAuditada desdeCodigo(String codigo) => values.firstWhere(
        (a) => a.codigo == codigo,
        orElse: () => AccionAuditada.modifico,
      );
}

/// Un renglón de la bitácora, con el nombre de quien lo hizo ya resuelto.
final class EntradaBitacora extends Equatable {
  const EntradaBitacora({
    required this.id,
    required this.usuarioId,
    required this.nombreUsuario,
    required this.usuario,
    required this.entidad,
    this.entidadId,
    required this.accion,
    required this.descripcion,
    this.detalle,
    required this.creadoEn,
  });

  final int id;
  final int usuarioId;

  /// Nombre de la persona, del `JOIN` con `personas`.
  final String nombreUsuario;

  /// Con qué usuario entró.
  final String usuario;

  final EntidadAuditada entidad;

  /// Id de la fila afectada, o `null` cuando ya no existe o no aplica.
  final int? entidadId;

  final AccionAuditada accion;

  /// Cómo se llamaba lo afectado **en el momento del hecho**. Es la única
  /// forma de leer un borrado: la fila ya no está para preguntarle su nombre.
  final String descripcion;

  /// Qué cambió, si se anotó. Texto libre y opcional.
  final String? detalle;

  final DateTime creadoEn;

  @override
  List<Object?> get props =>
      [id, usuarioId, entidad, entidadId, accion, descripcion, creadoEn];
}

/// Lo que se le pide al repositorio para dejar el renglón. Todavía no tiene id
/// ni fecha: los pone la base.
final class Anotacion {
  const Anotacion({
    required this.entidad,
    required this.accion,
    required this.descripcion,
    this.entidadId,
    this.detalle,
  });

  final EntidadAuditada entidad;
  final AccionAuditada accion;
  final String descripcion;
  final int? entidadId;
  final String? detalle;
}
