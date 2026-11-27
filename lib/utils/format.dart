/// Formats milliseconds as m:ss (or h:mm:ss for long tracks).
String formatMs(int ms) {
  final int totalSeconds = (ms / 1000).round();
  final int minutes = totalSeconds ~/ 60;
  final int seconds = totalSeconds % 60;
  final int hours = minutes ~/ 60;
  final String ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    final String mm = (minutes % 60).toString().padLeft(2, '0');
    return '$hours:$mm:$ss';
  }
  return '$minutes:$ss';
}

String formatDuration(Duration duration) => formatMs(duration.inMilliseconds);
