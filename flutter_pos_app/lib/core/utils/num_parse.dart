/// Safe parsing for API / SQLite / prefs where values may be num, String, or null.
double parseMoney(dynamic value, [double fallback = 0.0]) {
  if (value == null) return fallback;
  if (value is double) {
    return value.isFinite ? value : fallback;
  }
  if (value is int) return value.toDouble();
  if (value is num) {
    final d = value.toDouble();
    return d.isFinite ? d : fallback;
  }
  if (value is String) {
    final t = value.trim();
    if (t.isEmpty) return fallback;
    return double.tryParse(t) ?? fallback;
  }
  return fallback;
}

int parseIntLoose(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final t = value.trim();
    if (t.isEmpty) return fallback;
    return int.tryParse(t) ?? fallback;
  }
  return fallback;
}

double parseDoubleLoose(dynamic value, [double fallback = 0.0]) {
  return parseMoney(value, fallback);
}
