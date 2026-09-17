import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/configuracion/modelo/clave_configuracion.dart';
import '../../../../backend/features/configuracion/repositorio/repositorio_configuracion.dart';
import '../../../../backend/features/configuracion/repositorio/repositorio_configuracion_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../autenticacion/provider/auth_providers.dart';

/// Los datos del negocio, leídos y escritos de verdad.
///
/// La pestaña «General» de Configuración era una maqueta: sus campos tenían el
/// texto quemado y «Guardar cambios» no hacía nada, aunque la tabla
/// `configuracion` y su repositorio existían desde el principio. Esto los
/// conecta, y con eso el encabezado de las facturas deja de decir el valor por
/// defecto y pasa a decir el nombre real del taller.
///
/// Recibe la sesión **para las compuertas, no para firmar**: los ajustes del
/// negocio no son documentos y no llevan `usuario_id`. Lo que la sesión decide
/// aquí es quién puede abrir el formulario entero (`CONFIGURACION_VER`) y
/// quién puede guardarlo (`CONFIGURACION_EDITAR`).
final repositorioConfiguracionProvider = Provider<RepositorioConfiguracion>(
  name: 'repositorioConfiguracionProvider',
  (ref) => RepositorioConfiguracionImpl(
    ref.watch(appDatabaseProvider),
    ref.watch(sesionActualProvider),
  ),
);

/// Todas las claves con su valor efectivo. Nunca falta ninguna: el repositorio
/// parte de los valores por defecto y encima pisa lo guardado.
final configuracionProvider = StreamProvider<Map<ClaveConfiguracion, String>>(
  name: 'configuracionProvider',
  (ref) => ref.watch(repositorioConfiguracionProvider).observarTodas(),
);
