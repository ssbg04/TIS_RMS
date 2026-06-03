/// Shared date/time utilities for TIS RMS.
///
/// The backend stores timestamps in UTC via SQLite (without timezone indicator).
/// These helpers ensure the raw strings are always interpreted as UTC before
/// being converted to the Philippine Standard Time offset (+08:00).
library;

/// Parses a raw UTC timestamp string from the database and returns a
/// [DateTime] adjusted to Philippine Standard Time (UTC+8).
///
/// SQLite stores timestamps as `YYYY-MM-DD HH:MM:SS` without a timezone
/// indicator. Dart's [DateTime.parse] would treat those as local time, causing
/// a double-shift on machines not running at UTC. This function explicitly
/// forces UTC interpretation by appending 'Z' when no indicator is present.
DateTime parseToPht(String raw) {
  final normalised = raw.trim();
  // Already has timezone info – parse directly then convert
  if (normalised.endsWith('Z') ||
      normalised.contains('+') ||
      (normalised.length > 19 && normalised[19] == '-')) {
    return DateTime.parse(normalised).toUtc().add(const Duration(hours: 8));
  }
  // No timezone info → treat as UTC (backend guarantee)
  return DateTime.parse('${normalised}Z').add(const Duration(hours: 8));
}

/// Returns a human-readable relative time string for a raw UTC timestamp.
///
/// Examples: `3m ago`, `2h ago`, `5d ago`, `28/05/2026`
String formatRelative(String raw) {
  if (raw.isEmpty) return '';
  try {
    final dt  = parseToPht(raw);
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final diff = now.difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  } catch (_) {
    return raw.split('T').first;
  }
}

/// Returns a formatted date-time string in `DD/MM/YYYY HH:MM` format
/// adjusted to Philippine Standard Time.
String formatDateTime(String raw) {
  if (raw.isEmpty) return '';
  try {
    final dt = parseToPht(raw);
    final d  = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final h  = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$d/$mo/${dt.year}  $h:$mi';
  } catch (_) {
    return raw.split('T').first;
  }
}
