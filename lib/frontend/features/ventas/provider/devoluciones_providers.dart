import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/devoluciones/modelo/devolucion.dart';
import '../../../../backend/features/devoluciones/repositorio/repositorio_devoluciones.dart';
import '../../../../backend/features/devoluciones/repositorio/repositorio_devoluciones_impl.dart';
import '../../../../backend/share/database/app_db_provider.dart';
import '../../autenticacion/provider/auth_providers.dart';

/// Lo que el cliente trae de vuelta de una venta ya cobrada.
///
/// Vive en el módulo de ventas porque es desde el historial de donde se
/// devuelve: la pantalla que muestra la factura es la que ofrece deshacerla.
final repositorioDevolucionesProvider = Provider<RepositorioDevoluciones>(
  name: 'repositorioDevolucionesProvider',
  (ref) => RepositorioDevolucionesImpl(
    ref.watch(appDatabaseProvider),
    // Quién firma lo que este repositorio escriba. Es una dependencia del
    // constructor, no un registro global (`CLAUDE.md` §3).
    ref.watch(sesionActualProvider),
  ),
);

/// Qué queda por devolver de cada línea de una venta.
///
/// `autoDispose` porque solo lo mira el diálogo mientras está abierto, y
/// `family` porque la respuesta es distinta para cada factura.
final lineasDevolviblesProvider =
    FutureProvider.autoDispose.family<List<LineaDevolvible>, int>(
  name: 'lineasDevolviblesProvider',
  (ref, ventaId) =>
      ref.watch(repositorioDevolucionesProvider).lineasDevolvibles(ventaId),
);
