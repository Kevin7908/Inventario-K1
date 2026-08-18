import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../backend/features/cotizaciones/modelo/cotizacion_resumen.dart';
import '../../../../../backend/features/reservas/enum/enum_reserva.dart';
import '../../../../../backend/features/reservas/repositorio/repositorio_reservas.dart';
import '../../../../../core/formato.dart';
import '../../../../share2/share2.dart';
import '../provider/cotizar_a_reserva_provider.dart';
import 'partes_dialogo_reserva.dart';

/// Pide lo único que falta para convertir una cotización en reserva —fecha
/// límite y abono inicial— y delega en [CotizarAReservaUseCase].
///
/// Devuelve `true` si la reserva se creó.
///
/// Ejemplo:
/// ```dart
/// final creada = await DialogoReservarCotizacion.mostrar(
///   context,
///   cotizacion: cotizacion,
///   items: items,
///   totalReserva: estado.total,
/// );
/// ```
class DialogoReservarCotizacion extends ConsumerStatefulWidget {
  const DialogoReservarCotizacion._({
    required this.cotizacion,
    required this.items,
    required this.totalReserva,
  });

  final CotizacionResumen cotizacion;
  final List<ItemReservaDraft> items;
  final int totalReserva;

  static Future<bool> mostrar(
    BuildContext context, {
    required CotizacionResumen cotizacion,
    required List<ItemReservaDraft> items,
    required int totalReserva,
  }) async {
    final creada = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoReservarCotizacion._(
        cotizacion: cotizacion,
        items: items,
        totalReserva: totalReserva,
      ),
    );
    return creada == true;
  }

  @override
  ConsumerState<DialogoReservarCotizacion> createState() =>
      _DialogoReservarCotizacionState();
}

class _DialogoReservarCotizacionState
    extends ConsumerState<DialogoReservarCotizacion> {
  final _abono = TextEditingController();
  late DateTime _fechaLimite =
      DateTime.tryParse(widget.cotizacion.vigenciaHasta) ??
          DateTime.now().add(const Duration(days: 30));
  String _metodoPago = kMetodosPago.first;
  bool _creando = false;

  @override
  void dispose() {
    _abono.dispose();
    super.dispose();
  }

  void _error(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: TipografiaApp.sobrePrimario(TipografiaApp.cuerpo),
        ),
        backgroundColor: ColoresApp.statusDanger,
      ),
    );
  }

  Future<void> _confirmar() async {
    final abono = int.tryParse(_abono.text) ?? 0;
    if (abono > widget.totalReserva) {
      _error('El abono inicial no puede superar el total.');
      return;
    }

    setState(() => _creando = true);
    final error = await ref.read(cotizarAReservaProvider).ejecutar(
          clienteId: widget.cotizacion.clienteId!,
          motoId: widget.cotizacion.motoId,
          cotizacionId: widget.cotizacion.id,
          totalReserva: widget.totalReserva,
          items: widget.items,
          fechaLimite: _comoTexto(_fechaLimite),
          abonoInicial: abono,
          metodoPago: _metodoPago,
        );
    if (!mounted) return;

    setState(() => _creando = false);
    if (error != null) {
      _error(error);
      return;
    }
    Navigator.of(context).pop(true);
  }

  static String _comoTexto(DateTime fecha) =>
      '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AtajosFormulario(
      alGuardar: _creando ? null : _confirmar,
      alCancelar: () => Navigator.of(context).pop(false),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 480,
          decoration: BoxDecoration(
            color: ColoresApp.bgCard,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: ColoresApp.shadowMedium,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EncabezadoReserva(
                numero: widget.cotizacion.numero,
                alCerrar:
                    _creando ? null : () => Navigator.of(context).pop(false),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ResumenReserva(
                      cotizacion: widget.cotizacion,
                      productos: widget.items.length,
                      totalReserva: widget.totalReserva,
                    ),
                    const SizedBox(height: 18),
                    CampoFecha(
                      etiqueta: 'Fecha límite de reserva *',
                      valor: _fechaLimite,
                      formatear: formatearFecha,
                      alCambiar: _creando
                          ? null
                          : (fecha) => setState(() => _fechaLimite = fecha),
                    ),
                    const SizedBox(height: 14),
                    FilaCampos(
                      hijos: [
                        CampoTexto(
                          etiqueta: 'Abono inicial (opcional)',
                          controlador: _abono,
                          placeholder: '0',
                          soloEnteros: true,
                        ),
                        SelectorWidget<String>(
                          etiqueta: 'Método de pago',
                          valor: _metodoPago,
                          opciones: kMetodosPago,
                          constructorEtiqueta: (m) => m,
                          alCambiar: (m) => setState(() => _metodoPago = m),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        BotonSecundario(
                          etiqueta: 'Cancelar',
                          alPresionar: _creando
                              ? null
                              : () => Navigator.of(context).pop(false),
                        ),
                        const SizedBox(width: 12),
                        BotonPrimario(
                          etiqueta:
                              _creando ? 'Creando…' : 'Crear reserva',
                          icono: Icons.bookmark_add_outlined,
                          alPresionar: _creando ? null : _confirmar,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
