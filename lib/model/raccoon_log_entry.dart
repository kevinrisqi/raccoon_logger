/// Severity of a [RaccoonLogEntry].
enum RaccoonLogLevel { debug, info, warning, error }

/// A free-form log message recorded by the host app through `Raccoon().log`.
class RaccoonLogEntry {
  RaccoonLogEntry({
    required this.message,
    this.tag,
    this.level = RaccoonLogLevel.info,
    this.error,
    this.stackTrace,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  final DateTime time;
  final String message;
  final String? tag;
  final RaccoonLogLevel level;
  final Object? error;
  final StackTrace? stackTrace;

  /// Plain-text form used for copying.
  String toText() {
    final buffer = StringBuffer()
      ..write(time.toIso8601String())
      ..write(' [${level.name.toUpperCase()}]');
    if (tag != null && tag!.isNotEmpty) buffer.write(' [$tag]');
    buffer.write(' $message');
    if (error != null) buffer.write('\nError: $error');
    if (stackTrace != null) buffer.write('\n$stackTrace');
    return buffer.toString();
  }
}
