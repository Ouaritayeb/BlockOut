class InstalledApp {
  const InstalledApp({required this.name, required this.packageName});

  final String name;
  final String packageName;

  String get monogram {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    final first = words.first.substring(0, 1).toUpperCase();
    if (words.length == 1) return first;
    return '$first${words.last.substring(0, 1).toUpperCase()}';
  }
}

class FocusSession {
  const FocusSession({
    required this.active,
    required this.endsAt,
    required this.packageNames,
  });

  final bool active;
  final DateTime? endsAt;
  final Set<String> packageNames;
}
