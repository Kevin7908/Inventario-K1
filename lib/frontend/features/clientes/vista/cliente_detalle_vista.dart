import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../../core/formato.dart';
import '../../../share2/share2.dart';
import '../provider/cliente_provider.dart';

/// Ficha de un cliente: identidad, contacto, sus motos y su estado de cuenta.
///
/// Es una página completa dentro del módulo, no un diálogo: igual que en
/// Productos, el contenido no cabe cómodamente en un modal y así se replica el
/// flujo "Volver a clientes → ficha → Editar cliente".
///
/// La raíz no observa nada: las motos y el saldo llegan por sus propios
/// consumers, para que refrescar un saldo no reconstruya la cabecera.
class ClienteDetalleVista extends StatelessWidget {
  const ClienteDetalleVista({
    super.key,
    required this.cliente,
    required this.alVolver,
    required this.alEditar,
    required this.alEliminar,
  });

  final Cliente cliente;
  final VoidCallback alVolver;
  final VoidCallback alEditar;
  final VoidCallback alEliminar;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BotonVolver(etiqueta: 'Volver a clientes', alPresionar: alVolver),
                const Spacer(),
                BotonSecundario(
                  etiqueta: 'Editar cliente',
                  icono: Icons.edit_outlined,
                  alPresionar: alEditar,
                ),
                const SizedBox(width: 12),
                BotonIcono(
                  icono: Icons.delete_outline_rounded,
                  tooltip: 'Eliminar cliente',
                  color: ColoresApp.statusDanger,
                  alPresionar: alEliminar,
                ),
              ],
            ),
            const SizedBox(height: 22),
            _Identidad(cliente: cliente),
            const SizedBox(height: 22),
            _Contacto(cliente: cliente),
            const SizedBox(height: 20),
            _Motos(clienteId: cliente.id),
            const SizedBox(height: 20),
            _EstadoDeCuenta(clienteId: cliente.id),
            if ((cliente.notas ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              PanelSeccion(
                titulo: 'Notas',
                icono: Icons.sticky_note_2_outlined,
                child: Text(cliente.notas!.trim(), style: TipografiaApp.cuerpo),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cabecera de la ficha: el mismo avatar verde de la tarjeta, en grande.
class _Identidad extends StatelessWidget {
  const _Identidad({required this.cliente});

  final Cliente cliente;

  @override
  Widget build(BuildContext context) {
    final telefono = cliente.telefono?.trim() ?? '';
    final email = cliente.email?.trim() ?? '';

    return Row(
      children: [
        MarcadorIdentidad(
          inicial: cliente.iniciales,
          color: ColoresApp.textOnPrimary,
          colorFondo: ColoresApp.goGreen,
          colorFondoFin: ColoresApp.castletonGreen,
          lado: 64,
          radio: 18,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(cliente.nombreCompleto, style: TipografiaApp.heading2),
              const SizedBox(height: 4),
              Text(
                [telefono, email].where((t) => t.isNotEmpty).join(' · '),
                style: TipografiaApp.subtituloPagina,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (!cliente.activo)
          const IndicadorEstado(
            etiqueta: 'Inactivo',
            color: ColoresApp.statusNeutral,
            colorFondo: ColoresApp.statusNeutralBg,
          ),
      ],
    );
  }
}

class _Contacto extends StatelessWidget {
  const _Contacto({required this.cliente});

  final Cliente cliente;

  @override
  Widget build(BuildContext context) {
    final lineas = <({IconData icono, String texto})>[
      if ((cliente.cedula ?? '').trim().isNotEmpty)
        (icono: Icons.badge_outlined, texto: cliente.cedula!.trim()),
      if ((cliente.telefono ?? '').trim().isNotEmpty)
        (icono: Icons.phone_outlined, texto: cliente.telefono!.trim()),
      if ((cliente.email ?? '').trim().isNotEmpty)
        (icono: Icons.mail_outline_rounded, texto: cliente.email!.trim()),
      if ((cliente.direccion ?? '').trim().isNotEmpty)
        (icono: Icons.home_outlined, texto: cliente.direccion!.trim()),
      if ((cliente.ciudad ?? '').trim().isNotEmpty)
        (icono: Icons.location_on_outlined, texto: cliente.ciudad!.trim()),
    ];

    return PanelSeccion(
      titulo: 'Contacto',
      icono: Icons.call_outlined,
      child: lineas.isEmpty
          ? Text(
              'Sin datos de contacto registrados.',
              style: TipografiaApp.caption.copyWith(
                color: ColoresApp.textDisabled,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < lineas.length; i++) ...[
                  if (i > 0) const SizedBox(height: 11),
                  FilaDato(icono: lineas[i].icono, texto: lineas[i].texto),
                ],
              ],
            ),
    );
  }
}

/// Motos del cliente, en vivo: si se agrega una desde la edición, la ficha se
/// actualiza sola al volver.
class _Motos extends ConsumerWidget {
  const _Motos({required this.clienteId});

  final int clienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motos =
        ref.watch(motosDeClienteProvider(clienteId)).value ?? const <Moto>[];

    return PanelSeccion(
      titulo: motos.isEmpty ? 'Motos' : 'Motos (${motos.length})',
      icono: Icons.two_wheeler_outlined,
      child: motos.isEmpty
          ? Text(
              'Este cliente no tiene motos registradas.',
              style: TipografiaApp.caption.copyWith(
                color: ColoresApp.textDisabled,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < motos.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _FichaMoto(moto: motos[i]),
                ],
              ],
            ),
    );
  }
}

class _FichaMoto extends StatelessWidget {
  const _FichaMoto({required this.moto});

  final Moto moto;

  @override
  Widget build(BuildContext context) {
    final detalle = <String>[
      if (moto.anio != null) '${moto.anio}',
      if (moto.cilindraje != null) '${moto.cilindraje} cc',
      if ((moto.color ?? '').trim().isNotEmpty) moto.color!.trim(),
      if (moto.kilometrajeInicial > 0)
        '${formatearCantidad(moto.kilometrajeInicial)} km',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.borderInput),
      ),
      child: Row(
        children: [
          const MarcadorIdentidad(
            icono: Icons.two_wheeler_outlined,
            lado: 40,
            radio: 11,
            tamanoContenido: 20,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${moto.marca} ${moto.modelo}',
                  style: TipografiaApp.cuerpoMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (detalle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    style: TipografiaApp.caption.copyWith(
                      fontSize: 12,
                      color: ColoresApp.textDisabled,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if ((moto.placa ?? '').trim().isNotEmpty)
            Text(
              moto.placa!.trim(),
              style: TipografiaApp.monoespaciada(TipografiaApp.cuerpoMedium),
            ),
        ],
      ),
    );
  }
}

/// Saldo real del cliente, calculado sobre sus deudas vivas.
class _EstadoDeCuenta extends ConsumerWidget {
  const _EstadoDeCuenta({required this.clienteId});

  final int clienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saldo = ref.watch(
      saldosClientesProvider.select((s) => s.value?[clienteId]),
    );
    final debe = (saldo?.pendiente ?? 0) > 0;

    return PanelSeccion(
      titulo: 'Estado de cuenta',
      icono: Icons.account_balance_wallet_outlined,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  debe ? 'Saldo pendiente' : 'Sin deudas pendientes',
                  style: TipografiaApp.cuerpoMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  debe
                      ? (saldo!.deudas == 1
                          ? 'De 1 deuda registrada'
                          : 'De ${saldo.deudas} deudas registradas')
                      : 'El cliente está al día con el taller',
                  style: TipografiaApp.caption.copyWith(
                    color: ColoresApp.textDisabled,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IndicadorEstado(
            etiqueta: debe ? formatearPrecio(saldo!.pendiente) : 'Al día',
            color: debe ? ColoresApp.statusDanger : ColoresApp.statusSuccess,
            colorFondo:
                debe ? ColoresApp.statusDangerBg : ColoresApp.statusSuccessBg,
          ),
        ],
      ),
    );
  }
}
