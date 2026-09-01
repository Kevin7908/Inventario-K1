import '../../../../core/resultado.dart';
import '../modelo/marca_moto.dart';

/// El catálogo de marcas y modelos de moto.
///
/// Es un repositorio y no dos porque las dos tablas se consultan siempre
/// juntas: ninguna pantalla pide modelos sin saber de qué marca, y separarlas
/// obligaría a la vista a componer dos llamadas para una sola pregunta
/// (`REGLAS_BD.md` §6).
abstract interface class RepositorioMarcasMoto {
  /// Las marcas con cuántos modelos cuelgan de cada una.
  ///
  /// [soloActivas] filtra en SQL, no en Dart.
  Stream<List<MarcaMoto>> observarMarcas({bool soloActivas = false});

  Future<List<MarcaMoto>> obtenerMarcas({bool soloActivas = true});

  /// Los modelos de una marca, o **todos** si [marcaId] es nulo —que es lo que
  /// pide el selector de compatibilidades, donde se elige de todo el catálogo—.
  Stream<List<ModeloMoto>> observarModelos({
    int? marcaId,
    bool soloActivos = false,
  });

  Future<List<ModeloMoto>> obtenerModelos({
    int? marcaId,
    bool soloActivos = true,
  });

  Future<Resultado> crearMarca(String nombre);

  Future<Resultado> renombrarMarca(int id, String nombre);

  /// Da de baja o reactiva. **No borra**: una marca la referencian motos y
  /// compatibilidades, y borrarla rompería el historial (§1.4).
  Future<Resultado> cambiarEstadoMarca(int id, {required bool activa});

  Future<Resultado> crearModelo({
    required int marcaId,
    required String nombre,
    int? cilindraje,
  });

  Future<Resultado> actualizarModelo({
    required int id,
    required String nombre,
    int? cilindraje,
  });

  Future<Resultado> cambiarEstadoModelo(int id, {required bool activo});

  /// Devuelve el id de la marca con ese nombre, creándola si no está.
  ///
  /// Es lo que deja registrar una moto sin parar a dar de alta la marca en
  /// otra pantalla: el mostrador teclea «Bajaj» y sigue. Devuelve el id en vez
  /// de un `Resultado` porque quien la llama está a mitad de guardar una moto
  /// y necesita el valor, no un aviso.
  Future<int> asegurarMarca(String nombre);

  /// Lo mismo para un modelo dentro de una marca. `null` si [nombre] viene
  /// vacío: el modelo es opcional.
  Future<int?> asegurarModelo({
    required int marcaId,
    required String? nombre,
    int? cilindraje,
  });
}
