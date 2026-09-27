/// MODEL-002 / Q-015：复盘文本按清理后的 Unicode 码点校验。
String? normalizeReviewText(String? value, String field) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.runes.length > 2000) {
    throw ArgumentError.value(
      value,
      field,
      'MODEL-002: Must not exceed 2000 Unicode code points',
    );
  }
  return normalized;
}
