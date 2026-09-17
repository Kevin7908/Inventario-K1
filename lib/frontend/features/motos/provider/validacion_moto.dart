import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../../backend/features/motos/repositorio/repositorio_motos.dart';
import '../../../../core/resultado.dart';

/// Reglas de negocio de **una** moto: datos mínimos y unicidad de placa y
/// chasis.
///
/// Vive fuera de la vista para que los tres sitios que dan de alta motos —el
/// catálogo de Configuración, el formulario de cliente y el diálogo rápido que
/// abren órdenes, reservas y cotizaciones— no puedan saltárselas. `validarMoto`
/// es la única implementación de estas reglas: `validacion_cliente.dart` la
/// llama para cada moto de su lista en vez de repetirlas.
///
/// Parámetros:
/// - [moto]: la moto a comprobar. Con `id == 0` se trata como nueva.
/// - [repo]: repositorio con el que se consulta quién tiene ya la placa.
/// - [exigirDueno]: obliga a que la moto tenga cliente asignado. El catálogo lo
///   activa —ahí el dueño se elige a mano—; el formulario de cliente no, porque
///   al crear todavía no existe el id y el `clienteId` se fuerza al guardar.
///
/// Devuelve `null` si todo está bien, o el [Fallo] que corresponda.
Future<Resultado?> validarMoto({
  required Moto moto,
  required RepositorioMotos repo,
  bool exigirDueno = false,
}) async {
  // El modelo dejó de ser obligatorio al pasar al catálogo: en el mostrador la
  // marca siempre se sabe y el modelo exacto a veces no, y parar la atención al
  // cliente por eso sería peor que registrar la moto con lo que se sabe.
  if (moto.marca.trim().isEmpty) {
    return const Fallo(
      MotivoFallo.validacion,
      'Cada moto necesita al menos su marca.',
    );
  }

  if (exigirDueno && moto.clienteId <= 0) {
    return const Fallo(
      MotivoFallo.validacion,
      'Elige a qué cliente pertenece la moto.',
    );
  }

  // Una moto nueva (`id == 0`) todavía no existe en la base, así que no hay
  // nada que excluir; una que se está editando sí debe excluirse a sí misma.
  final excluir = moto.id == 0 ? null : moto.id;

  final placa = moto.placa?.trim() ?? '';
  if (placa.isNotEmpty) {
    final dueno = await _dueno(
      () => repo.duenoDePlaca(placa, excluirMotoId: excluir),
    );
    if (dueno != null) {
      return Fallo(
        MotivoFallo.placaRegistrada,
        'La moto con placa $placa ya está registrada a nombre de $dueno.',
      );
    }
  }

  return null;
}

/// Nombre del dueño actual, o `null` si el campo está libre.
Future<String?> _dueno(Future<Moto?> Function() consulta) async {
  final moto = await consulta();
  if (moto == null) return null;
  final dueno = moto.nombreCliente?.trim() ?? '';
  return dueno.isEmpty ? 'otro cliente' : dueno;
}
