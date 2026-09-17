import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/bitacora/repositorio/repositorio_bitacora.dart';
import '../../../../backend/features/configuracion/modelo/clave_configuracion.dart';
import '../../../../core/formato.dart';
import '../../../share/share.dart';
import '../../configuracion/provider/configuracion_provider.dart';
import '../provider/bitacora_providers.dart';

/// «Podar la bitácora»: elige cuánto conserva el taller y borra lo anterior.
///
/// La bitácora crece un renglón por cada alta, edición y borrado de catálogo,
/// para siempre. Esto es lo único que la recorta, y viene con dos candados que
/// hacen que recortarla no sirva para tapar nada:
///
/// - **el piso son [mesesMinimos]**, que la guarda de la base impone con un
///   `RAISE(ABORT)` sobre cualquier `DELETE` de lo reciente; el desplegable
///   por eso no ofrece menos;
/// - **la poda deja su propio renglón**, así que en la tabla queda dicho quién
///   podó, cuándo y cuántas anotaciones se llevó.
///
/// Los meses elegidos se guardan en `ClaveConfiguracion.mesesBitacora`, que es
/// lo que se propone la próxima vez.
///
/// Ejemplo:
/// ```dart
/// await DialogoPodar.mostrar(context);
/// ```
class DialogoPodar extends ConsumerStatefulWidget {
  const DialogoPodar({super.key});

  /// Lo abre y devuelve cuántas anotaciones se podaron, o `null` si se cerró
  /// sin hacer nada.
  static Future<int?> mostrar(BuildContext context) => showDialog<int>(
        context: context,
        builder: (_) => const DialogoPodar(),
      );

  @override
  ConsumerState<DialogoPodar> createState() => _DialogoPodarState();
}

class _DialogoPodarState extends ConsumerState<DialogoPodar> {
  /// Lo que se ofrece conservar. Ninguno baja de [mesesMinimos]: por debajo la
  /// guarda de la base rechaza el borrado y la poda no haría nada.
  static const _opciones = [24, 36, 48, 60];

  int _meses = mesesMinimos;
  int? _cuantas;
  bool _cargando = true;
  bool _podando = false;

  @override
  void initState() {
    super.initState();
    unawaited(_cargarPreferencia());
  }

  Future<void> _cargarPreferencia() async {
    final guardado = await ref
        .read(repositorioConfiguracionProvider)
        .leer(ClaveConfiguracion.mesesBitacora);

    if (!mounted) return;
    final meses = int.tryParse(guardado) ?? mesesMinimos;
    setState(() => _meses = _opciones.contains(meses) ? meses : mesesMinimos);
    await _contar();
  }

  /// Cuántas se irían con lo elegido. Se pregunta antes de borrar nada: es la
  /// diferencia entre confirmar un número y confirmar a ciegas.
  Future<void> _contar() async {
    setState(() => _cargando = true);
    final cuantas =
        await ref.read(repositorioBitacoraProvider).cuantasPodaria(meses: _meses);

    if (!mounted) return;
    setState(() {
      _cuantas = cuantas;
      _cargando = false;
    });
  }

  Future<void> _podar() async {
    setState(() => _podando = true);
    try {
      final podadas =
          await ref.read(repositorioBitacoraProvider).podar(meses: _meses);

      // La preferencia se guarda después de que la poda saliera bien: si
      // falló, no tiene sentido dejar apuntado un plazo que no se aplicó.
      await ref
          .read(repositorioConfiguracionProvider)
          .guardar(ClaveConfiguracion.mesesBitacora, '$_meses');

      ref.invalidate(bitacoraListaProvider);
      if (!mounted) return;
      Navigator.of(context).pop(podadas);
    } catch (e) {
      if (!mounted) return;
      setState(() => _podando = false);
      MensajeApp.error(context, 'No se pudo podar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cuantas = _cuantas;

    return AlertDialog(
      backgroundColor: ColoresApp.bgCard,
      title: const Text('Podar la bitácora', style: TipografiaApp.heading3),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectorWidget<int>(
              etiqueta: 'Conservar',
              valor: _meses,
              opciones: _opciones,
              constructorEtiqueta: (m) =>
                  m % 12 == 0 ? '${m ~/ 12} años' : '$m meses',
              alCambiar: (m) {
                if (_podando) return;
                setState(() => _meses = m);
                unawaited(_contar());
              },
            ),
            const SizedBox(height: 14),
            if (_cargando)
              const PanelSinDatos.cargando()
            else
              AvisoEnLinea(
                tono: cuantas == 0 ? TonoAviso.informacion : TonoAviso.alerta,
                mensaje: cuantas == 0
                    ? 'No hay nada tan viejo: la bitácora se queda como está.'
                    : 'Se borran $cuantas anotaciones anteriores al '
                        '${formatearFecha(_corte)}. No se pueden recuperar, y '
                        'la poda queda anotada a tu nombre.',
              ),
            const SizedBox(height: 12),
            const Text(
              'Los últimos dos años no se pueden podar: los protege la propia '
              'base de datos, para que recortar la bitácora no sirva para '
              'tapar nada.',
              style: TipografiaApp.caption,
            ),
          ],
        ),
      ),
      actions: [
        BotonSecundario(
          etiqueta: 'Cancelar',
          alPresionar: _podando ? null : () => Navigator.of(context).pop(),
        ),
        BotonDestructivo(
          etiqueta: 'Podar',
          alPresionar: (_podando || _cargando || cuantas == 0) ? null : _podar,
        ),
      ],
    );
  }

  /// La fecha de corte que se le enseña al usuario. La de verdad la calcula el
  /// repositorio con el mismo recorte; ésta es la misma cuenta para el texto.
  DateTime get _corte {
    final ahora = DateTime.now();
    return DateTime(ahora.year, ahora.month - _meses, ahora.day);
  }
}
