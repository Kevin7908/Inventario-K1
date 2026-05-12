import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../backend/features/categorias/modelo/categoria.dart';
import '../../../../backend/features/proveedores/modelo/proveedor.dart';
import '../../../../backend/features/unidades_medida/modelo/unidad_medida.dart';
import '../../../share/temas/colores_app.dart';
import '../../../share/widgets/input/app_searc_widget.dart';
import '../../categorias/view_model/categorias_view_model.dart';
import '../../categorias/widgets/dialogo_categorias_widget.dart';
import '../../proveedores/view_model/proveedores_view_model.dart';
import '../../proveedores/widgets/dialogo_proveedor_widget.dart';
import '../../unidades_medida/view_model/unidad_medida_view_model.dart';
import '../../unidades_medida/widgets/dialogo_unidad_medida_widget.dart';
import 'selector_imagen_widget.dart';

Widget _etiqueta(String texto) => Text(
      texto,
      style: const TextStyle(
        color: ColoresApp.textDark,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );

Widget _campo({required String label, required Widget child}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_etiqueta(label), const SizedBox(height: 6), child],
      ),
    );

Widget _fila(List<Widget> children) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [children[0], const SizedBox(width: 12), children[1]],
    );

InputDecoration _deco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: ColoresApp.textLight, fontSize: 13.5),
      filled: true,
      fillColor: ColoresApp.bgContent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ColoresApp.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ColoresApp.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ColoresApp.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ColoresApp.statusDebt),
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// _SeccionTitulo — Separador visual entre secciones
// ─────────────────────────────────────────────────────────────────────────────

class SeccionTitulo extends StatelessWidget {
  const SeccionTitulo({super.key, required this.titulo, required this.icono});

  final String titulo;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Icon(icono, size: 15, color: ColoresApp.primary),
          const SizedBox(width: 6),
          Text(
            titulo,
            style: const TextStyle(
              color: ColoresApp.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: ColoresApp.border, height: 1)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SeccionBasica — SKU, Nombre, Descripción
// ─────────────────────────────────────────────────────────────────────────────

class SeccionBasica extends StatelessWidget {
  const SeccionBasica({
    super.key,
    required this.skuCtrl,
    required this.nombreCtrl,
    required this.descripcionCtrl,
  });

  final TextEditingController skuCtrl;
  final TextEditingController nombreCtrl;
  final TextEditingController descripcionCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SeccionTitulo(
          titulo: 'INFORMACIÓN BÁSICA',
          icono: Icons.info_outline_rounded,
        ),

        // SKU + Nombre
        _fila([
          _campo(
            label: 'SKU *',
            child: TextFormField(
              controller: skuCtrl,
              decoration: _deco('Ej: YAM-FA-001'),
              textCapitalization: TextCapitalization.characters,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
          ),
          _campo(
            label: 'Nombre *',
            child: TextFormField(
              controller: nombreCtrl,
              decoration: _deco('Ej: Filtro de aire Yamaha FZ'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                return null;
              },
            ),
          ),
        ]),

        const SizedBox(height: 12),

        // Descripción
        _etiqueta('Descripción'),
        const SizedBox(height: 6),
        TextFormField(
          controller: descripcionCtrl,
          maxLines: 2,
          decoration: _deco('Características, especificaciones, referencia cruzada...'),
        ),
      ],
    );
  }
}


class SeccionClasificacion extends StatelessWidget {
  const SeccionClasificacion({
    super.key,
    required this.categoriaNotifier,
    required this.proveedorNotifier,
    required this.unidadNotifier,
    required this.ubicacionCtrl,
    required this.imagenRutaNotifier,
  });

  final ValueNotifier<Categoria?> categoriaNotifier;
  final ValueNotifier<Proveedor?> proveedorNotifier;
  final ValueNotifier<UnidadMedida?> unidadNotifier;
  final TextEditingController ubicacionCtrl;
  final ValueNotifier<String?> imagenRutaNotifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SeccionTitulo(
          titulo: 'CLASIFICACIÓN',
          icono: Icons.category_outlined,
        ),

        // Categoría + Proveedor
        _fila([
          _campo(
            label: 'Categoría',
            // Agregamos Consumer para que escuche cambios en tiempo real
            child: Consumer<CategoriasViewModel>(
              builder: (context, vm, _) => AppSearch<Categoria>(
                notifier: categoriaNotifier,
                items: vm.categorias, // Ahora usa la lista actualizada del VM
                labelBuilder: (c) => c.nombre,
                hint: 'Seleccionar categoría',
                onAgregar: () => DialogoCategoria.mostrar(
                  context,
                  viewModel: vm,
                ),
              ),
            ),
          ),
          _campo(
            label: 'Proveedor',
            // Agregamos Consumer para Proveedores
            child: Consumer<ProveedoresViewModel>(
              builder: (context, vm, _) => AppSearch<Proveedor>(
                notifier: proveedorNotifier,
                items: vm.proveedores,
                labelBuilder: (p) => p.nombre,
                hint: 'Seleccionar proveedor',
                onAgregar: () => DialogoProveedor.mostrar(
                  context,
                  viewModel: vm,
                ),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 12),

        // Unidad de medida + Ubicación en bodega
        _fila([
          _campo(
            label: 'Unidad de medida',
            // Agregamos Consumer para Unidades de Medida
            child: Consumer<UnidadesMedidaViewModel>(
              builder: (context, vm, _) => AppSearch<UnidadMedida>(
                notifier: unidadNotifier,
                items: vm.unidades,
                labelBuilder: (u) => '${u.nombre} (${u.abreviatura})',
                hint: 'Seleccionar unidad',
                onAgregar: () => DialogoUnidadMedida.mostrar(
                  context,
                  viewModel: vm,
                ),
              ),
            ),
          ),
          _campo(
            label: 'Ubicación en bodega',
            child: TextFormField(
              controller: ubicacionCtrl,
              decoration: _deco('Ej: Estante A-3'),
              textCapitalization: TextCapitalization.characters,
            ),
          ),
        ]),

        const SizedBox(height: 12),

        // Imagen del producto (esta ya estaba bien porque usa ValueListenableBuilder)
        _etiqueta('Imagen del producto'),
        const SizedBox(height: 8),
        ValueListenableBuilder<String?>(
          valueListenable: imagenRutaNotifier,
          builder: (_, ruta, __) => SelectorImagenWidget(
            rutaActual: ruta,
            onRutaSeleccionada: (nuevaRuta) =>
                imagenRutaNotifier.value = nuevaRuta,
          ),
        ),
      ],
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// _SeccionPrecios — Precio compra, venta, taller y aplica IVA
// ─────────────────────────────────────────────────────────────────────────────

class SeccionPrecios extends StatelessWidget {
  const SeccionPrecios({
    super.key,
    required this.precioCompraCtrl,
    required this.precioVentaCtrl,
    required this.precioTallerCtrl,
    required this.aplicaIvaNotifier,
  });

  final TextEditingController precioCompraCtrl;
  final TextEditingController precioVentaCtrl;
  final TextEditingController precioTallerCtrl;
  final ValueNotifier<bool> aplicaIvaNotifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SeccionTitulo(
          titulo: 'PRECIOS',
          icono: Icons.attach_money_rounded,
        ),

        // Precio compra + Precio venta
        _fila([
          _campo(
            label: 'Precio compra *',
            child: TextFormField(
              controller: precioCompraCtrl,
              decoration: _deco('0'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
          ),
          _campo(
            label: 'Precio venta *',
            child: TextFormField(
              controller: precioVentaCtrl,
              decoration: _deco('0'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
          ),
        ]),

        const SizedBox(height: 12),

        // Precio taller + Aplica IVA
        _fila([
          _campo(
            label: 'Precio taller (opcional)',
            child: TextFormField(
              controller: precioTallerCtrl,
              decoration: _deco('Precio interno / mayorista'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
          // Aplica IVA — columna alineada con el layout de 2 columnas
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _etiqueta('Aplica IVA'),
                const SizedBox(height: 6),
                ValueListenableBuilder<bool>(
                  valueListenable: aplicaIvaNotifier,
                  builder: (_, value, __) => Row(
                    children: [
                      Switch(
                        value: value,
                        onChanged: (v) => aplicaIvaNotifier.value = v,
                        activeColor: ColoresApp.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        value ? 'Incluye IVA' : 'Sin IVA',
                        style: TextStyle(
                          color: value
                              ? ColoresApp.primary
                              : ColoresApp.textLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SeccionInventario — Stock actual, stock mínimo y estado activo
// ─────────────────────────────────────────────────────────────────────────────

class SeccionInventario extends StatelessWidget {
  const SeccionInventario({
    super.key,
    required this.stockCtrl,
    required this.stockMinimoCtrl,
    required this.activoNotifier,
  });

  final TextEditingController stockCtrl;
  final TextEditingController stockMinimoCtrl;
  final ValueNotifier<bool> activoNotifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SeccionTitulo(
          titulo: 'INVENTARIO',
          icono: Icons.inventory_2_outlined,
        ),

        // Stock actual + Stock mínimo
        _fila([
          _campo(
            label: 'Stock actual',
            child: TextFormField(
              controller: stockCtrl,
              decoration: _deco('0'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
          _campo(
            label: 'Stock mínimo (alerta)',
            child: TextFormField(
              controller: stockMinimoCtrl,
              decoration: _deco('0'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
        ]),

        const SizedBox(height: 12),

        // Estado activo
        Row(
          children: [
            _etiqueta('Estado del producto'),
            const SizedBox(width: 10),
            ValueListenableBuilder<bool>(
              valueListenable: activoNotifier,
              builder: (_, activo, __) => Row(
                children: [
                  Switch(
                    value: activo,
                    onChanged: (v) => activoNotifier.value = v,
                    activeThumbColor: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      activo ? 'Activo' : 'Inactivo',
                      key: ValueKey(activo),
                      style: TextStyle(
                        color: activo
                            ? const Color(0xFF10B981)
                            : ColoresApp.textLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}