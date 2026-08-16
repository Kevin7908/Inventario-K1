import 'package:flutter/material.dart';

import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../share2/share2.dart';
import 'dialogo_moto_cliente.dart';

/// Bloque del formulario donde se administran **las motos de un cliente**.
///
/// Un cliente puede tener varias, así que la sección es una lista editable y
/// no un juego de campos sueltos: cada fila abre [DialogoMotoCliente] para sus
/// datos. No guarda nada por su cuenta —el estado vive en el formulario del
/// cliente, que persiste cliente y motos en una sola transacción.
///
/// Que una placa ya tenga dueño **no** se comprueba aquí: hace falta consultar
/// el repositorio, y eso lo hace `validarCliente` al guardar. Aquí solo se
/// evita lo que se ve sin ir a la base — repetir una placa dentro de la propia
/// lista.
///
/// Parámetros:
/// - [motos]: motos actuales del cliente, en orden de captura.
/// - [alCambiar]: recibe la lista nueva tras agregar, editar o quitar una.
///
/// Ejemplo:
/// ```dart
/// EditorMotosCliente(
///   motos: _motos,
///   alCambiar: (lista) => setState(() => _motos = lista),
/// )
/// ```
class EditorMotosCliente extends StatelessWidget {
  const EditorMotosCliente({
    super.key,
    required this.motos,
    required this.alCambiar,
  });

  final List<Moto> motos;
  final ValueChanged<List<Moto>> alCambiar;

  Future<void> _agregar(BuildContext context) async {
    final moto = await DialogoMotoCliente.mostrar(context);
    if (moto == null) return;
    alCambiar([...motos, moto]);
  }

  Future<void> _editar(BuildContext context, int indice) async {
    final moto = await DialogoMotoCliente.mostrar(
      context,
      motoAEditar: motos[indice],
    );
    if (moto == null) return;
    alCambiar([...motos]..[indice] = moto);
  }

  void _quitar(int indice) => alCambiar([...motos]..removeAt(indice));

  @override
  Widget build(BuildContext context) {
    return PanelSeccion(
      titulo: 'Motos',
      icono: Icons.two_wheeler_outlined,
      accion: BotonSecundario(
        etiqueta: 'Agregar moto',
        icono: Icons.add,
        alPresionar: () => _agregar(context),
      ),
      child: motos.isEmpty
          ? const _SinMotos()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lista concreta y no `ListView.builder`: un cliente tiene
                // dos o tres motos, y un builder aquí exigiría acotar el alto
                // dentro de un formulario que ya scrollea.
                for (var i = 0; i < motos.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _FilaMoto(
                    key: ValueKey('${motos[i].id}-${motos[i].placa}-$i'),
                    moto: motos[i],
                    alEditar: () => _editar(context, i),
                    alQuitar: () => _quitar(i),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Estado vacío del bloque: explica qué hacer en vez de dejar el panel mudo.
class _SinMotos extends StatelessWidget {
  const _SinMotos();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.borderInput),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.two_wheeler_outlined,
            size: 30,
            color: ColoresApp.textDisabled,
          ),
          const SizedBox(height: 10),
          Text(
            'Este cliente todavía no tiene motos',
            style: TipografiaApp.caption.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Puedes agregar todas las que tenga con "Agregar moto".',
            style: TipografiaApp.caption.copyWith(
              color: ColoresApp.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

/// Una moto de la lista: identidad a la izquierda, acciones a la derecha.
class _FilaMoto extends StatelessWidget {
  const _FilaMoto({
    super.key,
    required this.moto,
    required this.alEditar,
    required this.alQuitar,
  });

  final Moto moto;
  final VoidCallback alEditar;
  final VoidCallback alQuitar;

  /// Segunda línea: solo los datos que la moto tiene de verdad, para no
  /// mostrar separadores sueltos.
  String get _detalle {
    final partes = <String>[
      if (moto.anio != null) '${moto.anio}',
      if (moto.cilindraje != null) '${moto.cilindraje} cc',
      if ((moto.color ?? '').trim().isNotEmpty) moto.color!.trim(),
    ];
    return partes.isEmpty ? 'Sin datos adicionales' : partes.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final placa = moto.placa?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
      decoration: BoxDecoration(
        color: ColoresApp.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.borderInput),
      ),
      child: Row(
        children: [
          const MarcadorIdentidad(
            icono: Icons.two_wheeler_outlined,
            lado: 38,
            radio: 10,
            tamanoContenido: 19,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${moto.marca} ${moto.modelo}',
                  style: TipografiaApp.cuerpoMedium.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _detalle,
                  style: TipografiaApp.caption.copyWith(
                    fontSize: 11.5,
                    color: ColoresApp.textDisabled,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (placa.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              placa,
              style: TipografiaApp.monoespaciada(
                TipografiaApp.cuerpoMedium.copyWith(fontSize: 12.5),
              ),
            ),
          ],
          const SizedBox(width: 6),
          BotonIcono(
            icono: Icons.edit_outlined,
            tooltip: 'Editar moto',
            alPresionar: alEditar,
          ),
          BotonIcono(
            icono: Icons.close_rounded,
            tooltip: 'Quitar moto',
            color: ColoresApp.statusDanger,
            alPresionar: alQuitar,
          ),
        ],
      ),
    );
  }
}
