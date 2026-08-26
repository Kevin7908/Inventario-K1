import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../backend/features/clientes/repositorio/repositorio_cliente.dart';
import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../../backend/features/motos/repositorio/repositorio_motos.dart';
import '../../../../core/resultado.dart';
import '../../motos/provider/validacion_moto.dart';
import '../../../../backend/features/persona/repositorio/repositorio_persona.dart';

/// Reglas de negocio del alta y la edición de un cliente y sus motos.
///
/// Vive fuera de la vista para que el formulario de página y el diálogo de
/// alta rápida no puedan saltárselas, y fuera del notifier solo por tamaño:
/// son bastantes reglas y `cliente_provider.dart` ya está en su límite.
///
/// Devuelve `null` si todo está bien, o el [Fallo] que corresponda.
Future<Resultado?> validarCliente({
  required Cliente cliente,
  required List<Moto> motos,
  required RepositorioClientes repoClientes,
  required RepositorioMotos repoMotos,
  required RepositorioPersona repoPersonas,
}) async {
  final identidad = _validarIdentidad(cliente);
  if (identidad != null) return identidad;

  // Que la persona ya exista no es un error: puede estar registrada solo como
  // técnico, y en ese caso el repositorio reutiliza su fila de `personas`. Lo
  // que sí se rechaza es que ya sea cliente.
  final documento = cliente.documento?.trim() ?? '';
  if (documento.isNotEmpty &&
      await repoClientes.existeDocumento(
        documento,
        excluirId: cliente.id == 0 ? null : cliente.id,
      )) {
    return const Fallo(
      MotivoFallo.documentoDuplicado,
      'Ya existe otro cliente con esa cédula.',
    );
  }

  // El teléfono es único en `personas`: el choque puede ser con un técnico o
  // con un proveedor, no solo con otro cliente. Es de cortesía —para dar un
  // mensaje que se entienda—; la que impide de verdad es el `UNIQUE`.
  final telefono = cliente.telefono?.trim() ?? '';
  if (telefono.isNotEmpty) {
    final dueno = await repoPersonas.duenoDeTelefono(
      telefono,
      excluirPersonaId: cliente.personaId,
    );
    if (dueno != null) {
      return Fallo(
        MotivoFallo.telefonoDuplicado,
        'El teléfono $telefono ya está registrado a nombre de $dueno.',
      );
    }
  }

  return _validarMotos(motos, repoMotos);
}

Resultado? _validarIdentidad(Cliente cliente) {
  final nombres = cliente.nombres.trim();
  if (nombres.isEmpty) {
    return const Fallo(
      MotivoFallo.validacion,
      'El nombre no puede estar vacío.',
    );
  }
  if (nombres.length < 2) {
    return const Fallo(
      MotivoFallo.validacion,
      'El nombre debe tener al menos 2 caracteres.',
    );
  }
  return null;
}

/// Comprueba las motos en dos pasadas.
///
/// Primero contra la propia lista —dos filas del formulario con la misma placa
/// nunca llegan a la base, así que el `UNIQUE` no las atraparía con un mensaje
/// útil— y después, delegando en [validarMoto], contra lo ya registrado. Las
/// reglas de una moto suelta viven allí y no aquí: el catálogo de Motos y el
/// diálogo rápido aplican exactamente las mismas.
Future<Resultado?> _validarMotos(
  List<Moto> motos,
  RepositorioMotos repo,
) async {
  final placasVistas = <String>{};

  for (final moto in motos) {
    final placa = moto.placa?.trim() ?? '';
    if (placa.isNotEmpty && !placasVistas.add(placa.toLowerCase())) {
      return Fallo(
        MotivoFallo.placaRegistrada,
        'Repetiste la placa $placa en dos motos de este cliente.',
      );
    }

    // Sin `exigirDueno`: al crear el cliente todavía no hay id, y
    // `guardarConMotos` fuerza el `clienteId` dentro de la transacción.
    final invalida = await validarMoto(moto: moto, repo: repo);
    if (invalida != null) return invalida;
  }

  return null;
}
