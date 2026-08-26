import 'package:flutter/material.dart';

import '../../../../backend/features/clientes/modelo/cliente.dart';
import '../../../../backend/features/motos/modelo/moto.dart';
import '../../../share2/share2.dart';

/// Campos de una moto, sin decidir dónde se guardan.
///
/// Es el **único** sitio donde vive el formulario de moto. Sigue el patrón de
/// `FormularioCliente`: el diálogo que lo hospeda pone el marco y decide qué
/// hacer con el resultado, y este widget resuelve campos y validación de
/// formato. Lo reutilizan el catálogo de Motos (que persiste) y el editor de
/// motos del cliente (que solo acumula en memoria hasta guardar el cliente).
///
/// No comprueba si la placa ya tiene dueño: eso necesita el repositorio y vive
/// en `validarMoto`, que corre al guardar.
///
/// Parámetros:
/// - [motoAEditar]: moto a modificar. Si es `null`, crea una nueva.
/// - [clientes]: catálogo entre el que elegir dueño. Si es `null` no se muestra
///   el selector, porque el dueño ya está decidido por el contexto (la ficha
///   del cliente).
/// - [clienteInicial]: dueño preseleccionado al abrir.
/// - [mostrarEstado]: muestra el interruptor de moto activa. El catálogo lo
///   activa para poder dar de baja sin borrar el historial.
/// - [alGuardar]: recibe la moto ya armada cuando el formato es válido.
/// - [alCancelar]: se llama al presionar "Cancelar".
/// - [alAgregarCliente]: si se pasa, el selector de dueño ofrece crear un
///   cliente sin salir del formulario.
/// - [guardando]: deshabilita los botones mientras se persiste.
class FormularioMoto extends StatefulWidget {
  const FormularioMoto({
    super.key,
    this.motoAEditar,
    this.clientes,
    this.clienteInicial,
    this.mostrarEstado = false,
    required this.alGuardar,
    required this.alCancelar,
    this.alAgregarCliente,
    this.guardando = false,
  });

  final Moto? motoAEditar;
  final List<Cliente>? clientes;
  final Cliente? clienteInicial;
  final bool mostrarEstado;
  final ValueChanged<Moto> alGuardar;
  final VoidCallback alCancelar;
  final VoidCallback? alAgregarCliente;
  final bool guardando;

  bool get esEdicion => motoAEditar != null;

  @override
  State<FormularioMoto> createState() => _FormularioMotoState();
}

class _FormularioMotoState extends State<FormularioMoto> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _marcaCtrl;
  late final TextEditingController _modeloCtrl;
  late final TextEditingController _placaCtrl;
  late final TextEditingController _anioCtrl;
  late final TextEditingController _cilindrajeCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _notasCtrl;

  Cliente? _dueno;
  late bool _activa;

  @override
  void initState() {
    super.initState();
    final m = widget.motoAEditar;

    _marcaCtrl = TextEditingController(text: m?.marca ?? '');
    _modeloCtrl = TextEditingController(text: m?.modelo ?? '');
    _placaCtrl = TextEditingController(text: m?.placa ?? '');
    _anioCtrl = TextEditingController(text: m?.anio?.toString() ?? '');
    _cilindrajeCtrl =
        TextEditingController(text: m?.cilindraje?.toString() ?? '');
    _colorCtrl = TextEditingController(text: m?.color ?? '');
    _notasCtrl = TextEditingController(text: m?.notas ?? '');
    _dueno = widget.clienteInicial;
    _activa = m?.activo ?? true;
  }

  @override
  void dispose() {
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _placaCtrl.dispose();
    _anioCtrl.dispose();
    _cilindrajeCtrl.dispose();
    _colorCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  /// Texto vacío = campo sin dato. Guardar `''` en vez de `NULL` rompería el
  /// índice único de placa y VIN en cuanto hubiera dos motos sin ese dato.
  String? _opcional(TextEditingController c) {
    final texto = c.text.trim();
    return texto.isEmpty ? null : texto;
  }

  String? _entero(String? valor, {int? minimo, int? maximo}) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return null;
    final numero = int.tryParse(texto);
    if (numero == null) return 'Ingresa un número.';
    if (minimo != null && numero < minimo) return 'Mínimo $minimo.';
    if (maximo != null && numero > maximo) return 'Máximo $maximo.';
    return null;
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;

    final previa = widget.motoAEditar;

    widget.alGuardar(
      Moto(
        // `id == 0` marca a la moto como nueva: el repositorio la insertará en
        // vez de actualizarla.
        id: previa?.id ?? 0,
        clienteId: _dueno?.id ?? previa?.clienteId ?? 0,
        nombreCliente: _dueno?.nombreCompleto ?? previa?.nombreCliente,
        marca: _marcaCtrl.text.trim(),
        modelo: _modeloCtrl.text.trim(),
        placa: _opcional(_placaCtrl)?.toUpperCase(),
        anio: int.tryParse(_anioCtrl.text.trim()),
        cilindraje: int.tryParse(_cilindrajeCtrl.text.trim()),
        color: _opcional(_colorCtrl),
        notas: _opcional(_notasCtrl),
        activo: widget.mostrarEstado ? _activa : previa?.activo ?? true,
        creadoEn: previa?.creadoEn ?? DateTime.now(),
        actualizadoEn: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anioMaximo = DateTime.now().year + 1;
    final clientes = widget.clientes;

    return AtajosFormulario(
      alGuardar: widget.guardando ? null : _guardar,
      alCancelar: widget.guardando ? null : widget.alCancelar,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (clientes != null) ...[
              CampoBusqueda<Cliente>(
                etiqueta: 'Dueño *',
                valor: _dueno,
                opciones: clientes,
                constructorEtiqueta: (c) => c.nombreCompleto,
                constructorDetalle: (c) => c.telefono ?? c.documento,
                placeholder: 'Elegir cliente…',
                placeholderBusqueda: 'Buscar por nombre, teléfono o cédula…',
                alCambiar: (c) => setState(() => _dueno = c),
                validador: (c) => c == null ? 'Elige un cliente.' : null,
                alAgregar: widget.alAgregarCliente,
                etiquetaAgregar: 'Crear cliente nuevo',
              ),
              const SizedBox(height: 16),
            ],
            FilaCampos(
              anchoMinimo: 520,
              hijos: [
                CampoTexto(
                  etiqueta: 'Marca *',
                  controlador: _marcaCtrl,
                  placeholder: 'Ej: Bajaj',
                  autofocus: clientes == null,
                  validador: (v) => (v?.trim().isEmpty ?? true)
                      ? 'La marca es obligatoria.'
                      : null,
                ),
                CampoTexto(
                  etiqueta: 'Modelo *',
                  controlador: _modeloCtrl,
                  placeholder: 'Ej: Pulsar NS200',
                  validador: (v) => (v?.trim().isEmpty ?? true)
                      ? 'El modelo es obligatorio.'
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilaCampos(
              anchoMinimo: 520,
              hijos: [
                CampoTexto(
                  etiqueta: 'Placa',
                  controlador: _placaCtrl,
                  placeholder: 'Ej: KMN12C',
                  monoespaciado: true,
                ),
                CampoTexto(
                  etiqueta: 'Año',
                  controlador: _anioCtrl,
                  placeholder: 'Ej: 2022',
                  validador: (v) => _entero(v, minimo: 1900, maximo: anioMaximo),
                ),
                CampoTexto(
                  etiqueta: 'Cilindraje (cc)',
                  controlador: _cilindrajeCtrl,
                  placeholder: 'Ej: 200',
                  validador: (v) => _entero(v, minimo: 1),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilaCampos(
              anchoMinimo: 520,
              hijos: [
                CampoTexto(
                  etiqueta: 'Color',
                  controlador: _colorCtrl,
                  placeholder: 'Ej: Rojo',
                ),
              ],
            ),
            const SizedBox(height: 16),
            CampoTexto(
              etiqueta: 'Notas',
              controlador: _notasCtrl,
              placeholder: 'Detalles a recordar de esta moto…',
              lineas: 2,
            ),
            if (widget.mostrarEstado) ...[
              const SizedBox(height: 16),
              InterruptorCampo(
                etiqueta: 'Moto activa',
                detalle: _activa
                    ? 'Sigue en servicio'
                    : 'Se vendió o se dio de baja, pero conserva su historial',
                valor: _activa,
                alCambiar: (v) => setState(() => _activa = v),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BotonSecundario(
                  etiqueta: 'Cancelar',
                  alPresionar: widget.guardando ? null : widget.alCancelar,
                ),
                const SizedBox(width: 12),
                BotonPrimario(
                  etiqueta: widget.guardando
                      ? 'Guardando...'
                      : widget.esEdicion
                          ? 'Guardar moto'
                          : 'Agregar moto',
                  icono: Icons.check,
                  alPresionar: widget.guardando ? null : _guardar,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
