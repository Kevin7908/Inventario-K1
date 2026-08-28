import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/devoluciones/enum/enum_devoluciones.dart';
import '../../../../backend/features/devoluciones/modelo/devolucion.dart';
import '../../../../backend/features/pos/modelo/venta_resumen.dart';
import '../../../../backend/share/dominio/sesion_actual.dart';
import '../../../../core/formato.dart';
import '../../../../core/resultado.dart';
import '../../../share2/share2.dart';
import '../provider/devoluciones_providers.dart';

/// Recibe una devolución parcial de una venta ya cobrada.
///
/// Enseña las líneas de la factura con lo que **todavía** se puede devolver
/// —la cuenta la hizo SQL, no esta pantalla— y deja teclear cuánto vuelve de
/// cada una. Al guardar, el repositorio escribe el documento, sus líneas y las
/// entradas de inventario en una sola transacción.
///
/// **No es anular.** Anular deshace la factura entera; esto le quita una parte
/// y la deja viva con su número.
///
/// Parámetros:
/// - [venta]: la factura contra la que se devuelve.
///
/// Ejemplo:
/// ```dart
/// await DialogoDevolucion.mostrar(context, venta: venta);
/// ```
class DialogoDevolucion extends ConsumerStatefulWidget {
  const DialogoDevolucion({super.key, required this.venta});

  final VentaResumen venta;

  static Future<bool?> mostrar(
    BuildContext context, {
    required VentaResumen venta,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => DialogoDevolucion(venta: venta),
    );
  }

  @override
  ConsumerState<DialogoDevolucion> createState() => _DialogoDevolucionState();
}

class _DialogoDevolucionState extends ConsumerState<DialogoDevolucion> {
  final _notas = TextEditingController();

  /// Cuánto se devuelve de cada línea, por `venta_detalles.id`. Lo que no
  /// está aquí no se devuelve.
  final Map<int, double> _cantidades = {};

  MotivoDevolucion _motivo = MotivoDevolucion.defectuoso;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  /// Lo que se le regresa al cliente, con el precio al que se vendió.
  int _total(List<LineaDevolvible> lineas) {
    var total = 0;
    for (final linea in lineas) {
      final cantidad = _cantidades[linea.ventaDetalleId] ?? 0;
      total += (cantidad * linea.precioUnitario).round();
    }
    return total;
  }

  Future<void> _guardar(List<LineaDevolvible> lineas) async {
    final elegidas = [
      for (final linea in lineas)
        if ((_cantidades[linea.ventaDetalleId] ?? 0) > 0)
          LineaADevolver(
            ventaDetalleId: linea.ventaDetalleId,
            cantidad: _cantidades[linea.ventaDetalleId]!,
          ),
    ];

    if (elegidas.isEmpty) {
      setState(() => _error = 'Elige al menos una línea y su cantidad.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final resultado =
          await ref.read(repositorioDevolucionesProvider).registrar(
                ventaId: widget.venta.id,
                motivo: _motivo,
                lineas: elegidas,
                notas: _notas.text,
              );

      if (!mounted) return;

      switch (resultado) {
        case Exito():
          Navigator.of(context).pop(true);
          MensajeApp.exito(
            context,
            'Devolución registrada. La mercancía volvió al inventario.',
          );
        case Fallo(:final mensaje):
          setState(() {
            _guardando = false;
            _error = mensaje;
          });
      }
    } on PermisoDenegado catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e.mensaje;
      });
    }
  }

  void _cerrar() => Navigator.of(context).pop(false);


  /// El cuerpo del diálogo. Es un método y no un widget aparte porque se
  /// construye una vez por apertura y necesita el estado de esta misma clase
  /// (`CLAUDE.md` §2).
  Widget _contenido(List<LineaDevolvible> lineas) {
    final pendientes =
        lineas.where((l) => l.disponible > 0).toList(growable: false);
    final total = _total(lineas);

    if (pendientes.isEmpty) {
      return _Aviso(
        texto: 'De esta factura ya se devolvió todo lo que se podía.',
        alCerrar: _cerrar,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Recibir devolución', style: TipografiaApp.heading3),
        const SizedBox(height: 4),
        Text(
          'Factura ${widget.venta.numeroFactura} · la mercancía vuelve al '
          'inventario y la factura sigue viva.',
          style: TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
        ),
        const SizedBox(height: 18),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: pendientes.length,
            itemBuilder: (_, indice) {
              final linea = pendientes[indice];
              return _Linea(
                key: ValueKey(linea.ventaDetalleId),
                linea: linea,
                cantidad: _cantidades[linea.ventaDetalleId] ?? 0,
                alCambiar: (valor) => setState(() {
                  _cantidades[linea.ventaDetalleId] = valor;
                  _error = null;
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        SelectorWidget<String>(
          etiqueta: 'Por qué la devuelve',
          valor: _motivo.codigo,
          opciones: [for (final m in MotivoDevolucion.values) m.codigo],
          constructorEtiqueta: (codigo) =>
              MotivoDevolucion.desdeCodigo(codigo).etiqueta,
          alCambiar: (codigo) =>
              setState(() => _motivo = MotivoDevolucion.desdeCodigo(codigo)),
        ),
        const SizedBox(height: 14),
        CampoTexto(
          etiqueta: 'Nota (opcional)',
          controlador: _notas,
          placeholder: 'Lo que haya que recordar de esta devolución',
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          AvisoEnLinea(mensaje: _error!, tono: TonoAviso.error),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              'Se le regresan ',
              style:
                  TipografiaApp.caption.copyWith(color: ColoresApp.textMuted),
            ),
            Text(
              formatearPrecio(total),
              style: TipografiaApp.tituloTarjeta.copyWith(
                color: total > 0
                    ? ColoresApp.statusDanger
                    : ColoresApp.textDisabled,
              ),
            ),
            const Spacer(),
            BotonSecundario(
              etiqueta: 'Cancelar',
              alPresionar: _guardando ? null : _cerrar,
            ),
            const SizedBox(width: 12),
            BotonPrimario(
              etiqueta: _guardando ? 'Guardando…' : 'Registrar',
              icono: Icons.keyboard_return_rounded,
              alPresionar: _guardando ? null : () => _guardar(lineas),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lineas = ref.watch(lineasDevolviblesProvider(widget.venta.id));

    return AtajosFormulario(
      alCancelar: _cerrar,
      alGuardar: _guardando
          ? null
          : () {
              final valor = lineas.value;
              if (valor != null) _guardar(valor);
            },
      child: Dialog(
        backgroundColor: ColoresApp.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: switch (lineas) {
              AsyncData(value: final valor) => _contenido(valor),
              AsyncError(:final error) => _Aviso(
                  texto: 'No se pudieron leer las líneas de la factura: '
                      '$error',
                  alCerrar: _cerrar,
                ),
              _ => const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
            },
          ),
        ),
      ),
    );
  }
}

/// Una línea de la factura con su tope: nunca deja pedir más de lo que queda.
class _Linea extends StatelessWidget {
  const _Linea({
    super.key,
    required this.linea,
    required this.cantidad,
    required this.alCambiar,
  });

  final LineaDevolvible linea;
  final double cantidad;
  final ValueChanged<double> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  linea.descripcion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TipografiaApp.cuerpoMedium,
                ),
                Text(
                  '${formatearPrecio(linea.precioUnitario)} c/u · quedan '
                  '${formatearCantidad(linea.disponible)} de '
                  '${formatearCantidad(linea.cantidadVendida)}'
                  '${linea.esProducto ? '' : ' · servicio, no vuelve a bodega'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TipografiaApp.caption
                      .copyWith(color: ColoresApp.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          ControlCantidad(
            cantidad: cantidad,
            minimo: 0,
            maximo: linea.disponible,
            alCambiar: alCambiar,
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, required this.alCerrar});

  final String texto;
  final VoidCallback alCerrar;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AvisoEnLinea(mensaje: texto, tono: TonoAviso.informacion),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: BotonSecundario(etiqueta: 'Cerrar', alPresionar: alCerrar),
        ),
      ],
    );
  }
}
