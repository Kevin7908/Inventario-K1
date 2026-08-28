import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../../core/resultado.dart';
import '../../../share/share.dart';
import '../provider/motos_provider.dart';
import '../widgets/dialogo_motos.dart';
import '../widgets/grilla_motos.dart';

/// Pestaña "Motos" de Configuración: parque de motos del taller en grilla.
///
/// Es una pestaña y no una sección propia del sidebar porque el día a día pasa
/// por el cliente —una moto se da de alta desde su ficha— y esta pantalla es
/// el maestro donde se corrige y se consulta, junto a los demás catálogos base.
///
/// Sigue el patrón de Clientes y Técnicos: buscador con Ctrl+F, chips de
/// estado, grilla de tarjetas y paginación real contra SQLite. El alta y la
/// edición van en diálogo, como en las pestañas hermanas de Configuración.
class MotosVista extends ConsumerStatefulWidget {
  const MotosVista({super.key});

  @override
  ConsumerState<MotosVista> createState() => _MotosVistaState();
}

class _MotosVistaState extends ConsumerState<MotosVista> {
  final _busquedaController = TextEditingController();
  final _focoBusqueda = FocusNode();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaController.dispose();
    _focoBusqueda.dispose();
    super.dispose();
  }

  void _alBuscar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      ref.read(motosProvider.notifier).buscar(texto);
    });
  }

  Future<void> _eliminar(Moto moto) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: '¿Eliminar la ${moto.marca} ${moto.modelo}?',
      mensaje: 'Esta acción no se puede deshacer. Si la moto ya pasó por el '
          'taller, conviene marcarla como inactiva en vez de borrarla.',
    );
    if (confirmado != true || !mounted) return;

    final resultado = await ref.read(motosProvider.notifier).eliminar(moto.id);
    if (!mounted) return;

    final esError = resultado is Fallo;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          switch (resultado) {
            Fallo(:final mensaje) => mensaje,
            Exito() => 'Moto eliminada.',
          },
          style: TipografiaApp.sobrePrimario(TipografiaApp.cuerpo),
        ),
        backgroundColor:
            esError ? ColoresApp.statusDanger : ColoresApp.statusSuccess,
      ),
    );
  }

  /// La raíz no observa ningún provider: cada bloque se suscribe al suyo, así
  /// que escribir en el buscador no reconstruye el resumen ni los chips.
  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _focoBusqueda.requestFocus(),
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ResumenMotos(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: BarraBusqueda(
                  controlador: _busquedaController,
                  focoTeclado: _focoBusqueda,
                  placeholder:
                      'Buscar por marca, modelo, placa, chasis o dueño...',
                  alCambiar: _alBuscar,
                ),
              ),
              const SizedBox(width: 20),
              BotonPrimario(
                etiqueta: 'Nueva moto',
                icono: Icons.add,
                alPresionar: () => DialogoMoto.mostrar(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _ChipsEstado(),
          const SizedBox(height: 16),
          Expanded(
            child: GrillaMotos(
              alEditar: (moto) => DialogoMoto.mostrar(context, moto: moto),
              alEliminar: _eliminar,
            ),
          ),
        ],
      ),
    );
  }
}

/// Línea de conteos del catálogo.
///
/// La pestaña no lleva encabezado propio —ya lo pone Configuración—, así que
/// los totales van en una línea suelta. "Sin placa" es un aviso de calidad de
/// dato: esas motos no se pueden buscar por placa ni identificar en una orden.
class _ResumenMotos extends ConsumerWidget {
  const _ResumenMotos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(motosResumenProvider).value;
    final total = resumen?.total ?? 0;

    final buffer = StringBuffer(
      'Parque de motos del taller. Cada moto pertenece a un cliente',
    );
    if (total > 0) {
      buffer.write(total == 1 ? ' · 1 moto' : ' · $total motos');
      final activas = resumen?.activas ?? 0;
      if (activas < total) buffer.write(' · $activas activas');
      final sinPlaca = resumen?.sinPlaca ?? 0;
      if (sinPlaca > 0) buffer.write(' · $sinPlaca sin placa');
    }

    return Text(buffer.toString(), style: TipografiaApp.subtituloPagina);
  }
}

/// Chips de filtro por estado (sigue en servicio o se dio de baja).
class _ChipsEstado extends ConsumerWidget {
  const _ChipsEstado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activo = ref.watch(
      motosProvider.select((s) => s.value?.filtroActivo),
    );

    void filtrar(bool? valor) =>
        ref.read(motosProvider.notifier).filtrarPorActivo(valor);

    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        ChipFiltro(
          etiqueta: 'Todas',
          seleccionado: activo == null,
          alPresionar: () => filtrar(null),
        ),
        ChipFiltro(
          etiqueta: 'Activas',
          seleccionado: activo == true,
          colorActivo: ColoresApp.statusSuccess,
          alPresionar: () => filtrar(true),
        ),
        ChipFiltro(
          etiqueta: 'Inactivas',
          seleccionado: activo == false,
          colorActivo: ColoresApp.statusNeutral,
          alPresionar: () => filtrar(false),
        ),
      ],
    );
  }
}
