/// COP currency formatting helpers, centralizes all money display logic.
extension CurrencyFormatting on num {
  /// Full COP with dot separators: 1234567 → $1.234.567
  String toCopString() {
    final v = round().toString();
    return '\$${v.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}';
  }

  /// Compact for cards/charts: 1500000 → $1.5M | 12000 → $12K | 800 → $800
  String toCompactCop() {
    if (this >= 1_000_000) return '\$${(this / 1_000_000).toStringAsFixed(1)}M';
    if (this >= 1_000) return '\$${(this / 1_000).toStringAsFixed(0)}K';
    return '\$$this';
  }
}
