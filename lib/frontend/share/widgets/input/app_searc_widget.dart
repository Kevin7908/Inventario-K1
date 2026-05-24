import 'package:flutter/material.dart';
import '../../temas/colores_app.dart';

class AppSearch<T> extends StatelessWidget {
  const AppSearch({
    super.key,
    required this.notifier,
    required this.items,
    required this.labelBuilder,
    required this.hint,
    this.label,
    this.validator,
    this.onAgregar,
    this.onChanged,
  });

  /// Notifier externo — el padre lo crea y hace dispose.
  final ValueNotifier<T?> notifier;

  /// Lista completa de ítems disponibles.
  final List<T> items;

  /// Cómo convertir un ítem a texto legible.
  final String Function(T) labelBuilder;

  /// Texto de placeholder cuando no hay selección.
  final String hint;

  /// Etiqueta opcional (si null, el campo no muestra label).
  final String? label;

  /// Validador opcional para Form.
  final String? Function(T?)? validator;

  /// Si se provee, aparece el botón "Agregar nuevo" en el diálogo.
  final VoidCallback? onAgregar;

  /// Callback extra cuando cambia la selección (además de actualizar el notifier).
  final ValueChanged<T?>? onChanged;

  Future<void> _abrirPicker(BuildContext context) async {
    final resultado = await showDialog<T>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _PickerDialog<T>(
        items: items,
        labelBuilder: labelBuilder,
        hint: hint,
        onAgregar: onAgregar,
        seleccionadoActual: notifier.value,
      ),
    );

    // Si resultado es null el usuario cerró sin elegir → no cambiamos nada.
    // Si eligió un ítem (incluso el mismo), actualizamos.
    if (resultado != null) {
      notifier.value = resultado;
      onChanged?.call(resultado);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<T?>(
      valueListenable: notifier,
      builder: (context, seleccionado, _) {
        return FormField<T>(
          initialValue: seleccionado,
          validator: validator != null ? (_) => validator!(notifier.value) : null,
          builder: (fieldState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _abrirPicker(context),
                  child: AbsorbPointer(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: seleccionado != null
                            ? labelBuilder(seleccionado)
                            : hint,
                        hintStyle: TextStyle(
                          // Si hay selección, mostramos en color de texto normal
                          color: seleccionado != null
                              ? ColoresApp.textDark
                              : ColoresApp.textLight,
                          fontSize: 13.5,
                        ),
                        filled: true,
                        fillColor: ColoresApp.bgContent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        suffixIcon: Icon(
                          seleccionado != null
                              ? Icons.arrow_drop_down_rounded
                              : Icons.search_rounded,
                          color: ColoresApp.textLight,
                          size: 22,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: ColoresApp.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: fieldState.hasError
                                ? ColoresApp.statusDebt
                                : ColoresApp.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: ColoresApp.primary,
                            width: 1.5,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: ColoresApp.statusDebt),
                        ),
                        errorText: fieldState.errorText,
                      ),
                      // Campo vacío: el texto real se muestra en hintText.
                      controller: TextEditingController(
                        text: seleccionado != null ? labelBuilder(seleccionado) : '',
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PickerDialog — Diálogo interno de búsqueda. Solo vive mientras está abierto.
// ─────────────────────────────────────────────────────────────────────────────

class _PickerDialog<T> extends StatefulWidget {
  const _PickerDialog({
    super.key,
    required this.items,
    required this.labelBuilder,
    required this.hint,
    required this.seleccionadoActual,
    this.onAgregar,
  });

  final List<T> items;
  final String Function(T) labelBuilder;
  final String hint;
  final T? seleccionadoActual;
  final VoidCallback? onAgregar;

  @override
  State<_PickerDialog<T>> createState() => _PickerDialogState<T>();
}

class _PickerDialogState<T> extends State<_PickerDialog<T>> {
  late final TextEditingController _searchCtrl;
  late List<T> _filtrados;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _filtrados = List.of(widget.items);
    _searchCtrl.addListener(_filtrar);
  }

  void _filtrar() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtrados = query.isEmpty
          ? List.of(widget.items)
          : widget.items
                .where(
                  (i) => widget
                      .labelBuilder(i)
                      .toLowerCase()
                      .contains(query),
                )
                .toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculamos si el botón "agregar" existe para ajustar índices
    final tieneAgregar = widget.onAgregar != null;
    // Total de filas en el ListView (agregar + filtrados)
    final totalItems = _filtrados.length + (tieneAgregar ? 1 : 0);

    return Dialog(
      backgroundColor: ColoresApp.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Barra de búsqueda ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(
                  color: ColoresApp.textDark,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar ${widget.hint.toLowerCase()}...',
                  hintStyle: const TextStyle(
                    color: ColoresApp.textLight,
                    fontSize: 13.5,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: ColoresApp.textLight,
                    size: 20,
                  ),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchCtrl,
                    builder: (context, value, child) => value.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: ColoresApp.textLight,
                            ),
                            onPressed: _searchCtrl.clear,
                          )
                        : const SizedBox.shrink(),
                  ),
                  filled: true,
                  fillColor: ColoresApp.bgContent,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    borderSide:
                        const BorderSide(color: ColoresApp.primary, width: 1.5),
                  ),
                ),
              ),
            ),

            // ── Divider ───────────────────────────────────────────────────
            const Divider(height: 1, color: ColoresApp.border),

            // ── Lista de resultados ───────────────────────────────────────
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: totalItems == 0 ? 1 : totalItems,
                itemBuilder: (context, index) {
                  // Lista vacía: muestra estado vacío (con botón agregar si aplica)
                  if (totalItems == 0) {
                    return _EmptyState(
                      query: _searchCtrl.text,
                      onAgregar: tieneAgregar
                          ? () {
                              Navigator.of(context).pop();
                              widget.onAgregar!();
                            }
                          : null,
                    );
                  }

                  // Fila 0 → botón "Agregar nuevo" (si aplica)
                  if (tieneAgregar && index == 0) {
                    return _FilaAgregar(
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onAgregar!();
                      },
                    );
                  }

                  final itemIndex = tieneAgregar ? index - 1 : index;
                  final item = _filtrados[itemIndex];
                  final esSeleccionado = item == widget.seleccionadoActual;
                  final label = widget.labelBuilder(item);

                  return _FilaItem(
                    label: label,
                    esSeleccionado: esSeleccionado,
                    query: _searchCtrl.text,
                    onTap: () => Navigator.of(context).pop(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subwidgets del diálogo — StatelessWidget para rendimiento
// ─────────────────────────────────────────────────────────────────────────────

class _FilaAgregar extends StatelessWidget {
  const _FilaAgregar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: ColoresApp.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: ColoresApp.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Agregar nuevo',
              style: TextStyle(
                color: ColoresApp.primary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaItem extends StatelessWidget {
  const _FilaItem({
    required this.label,
    required this.esSeleccionado,
    required this.query,
    required this.onTap,
  });

  final String label;
  final bool esSeleccionado;
  final String query;
  final VoidCallback onTap;

  /// Resalta la coincidencia de búsqueda con negrita y color primario.
  List<TextSpan> _buildSpans() {
    if (query.isEmpty) {
      return [
        TextSpan(
          text: label,
          style: TextStyle(
            color: esSeleccionado ? ColoresApp.primary : ColoresApp.textDark,
            fontSize: 13.5,
            fontWeight:
                esSeleccionado ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ];
    }

    final lowerLabel = label.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerLabel.indexOf(lowerQuery);
    if (matchIndex == -1) {
      return [
        TextSpan(
          text: label,
          style: const TextStyle(
            color: ColoresApp.textDark,
            fontSize: 13.5,
          ),
        ),
      ];
    }

    return [
      if (matchIndex > 0)
        TextSpan(
          text: label.substring(0, matchIndex),
          style: TextStyle(
            color: esSeleccionado ? ColoresApp.primary : ColoresApp.textDark,
            fontSize: 13.5,
          ),
        ),
      TextSpan(
        text: label.substring(matchIndex, matchIndex + query.length),
        style: const TextStyle(
          color: ColoresApp.primary,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (matchIndex + query.length < label.length)
        TextSpan(
          text: label.substring(matchIndex + query.length),
          style: TextStyle(
            color: esSeleccionado ? ColoresApp.primary : ColoresApp.textDark,
            fontSize: 13.5,
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: esSeleccionado
            ? ColoresApp.primary.withValues(alpha: 0.07)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: RichText(text: TextSpan(children: _buildSpans())),
            ),
            if (esSeleccionado)
              const Icon(
                Icons.check_rounded,
                color: ColoresApp.primary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query, this.onAgregar});
  final String query;
  final VoidCallback? onAgregar;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                color: ColoresApp.textLight,
                size: 36,
              ),
              const SizedBox(height: 10),
              Text(
                query.isEmpty
                    ? 'No hay elementos disponibles'
                    : 'Sin resultados para "$query"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ColoresApp.textLight,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
        if (onAgregar != null) ...[
          const Divider(height: 1, color: ColoresApp.border),
          _FilaAgregar(onTap: onAgregar!),
        ],
      ],
    );
  }
}