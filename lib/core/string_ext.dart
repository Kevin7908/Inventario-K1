extension StringExt on String {
  // Retorna null si el string esta vacío de lo contrario retorna this.
  String? get nullIfEmpty => trim().isEmpty ? null : trim();
}