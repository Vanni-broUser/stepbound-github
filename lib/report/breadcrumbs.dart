import 'dart:collection';

/// One thing the game did, and when.
final class Breadcrumb {
  const Breadcrumb(this.at, this.text);

  final DateTime at;
  final String text;

  /// `HH:mm:ss.SSS  text`, one per line in the report.
  @override
  String toString() {
    String two(int n) => n.toString().padLeft(2, '0');
    final ms = at.millisecond.toString().padLeft(3, '0');
    return '${two(at.hour)}:${two(at.minute)}:${two(at.second)}.$ms  $text';
  }
}

/// The last things the game did, in order, so that an error report says
/// how the player got there: the worst bugs, a script that never lets go
/// of Mario, throw nothing, and only the trail tells where he was stuck.
/// Steps and bumps into walls are left out (see `StepboundGame`): they
/// would push everything else out in a few seconds.
final class Breadcrumbs {
  Breadcrumbs({this.capacity = 150, this._clock = DateTime.now});

  /// The trail the whole app writes to.
  static final Breadcrumbs shared = Breadcrumbs();

  /// How many are kept: the oldest goes when one more comes.
  final int capacity;
  final DateTime Function() _clock;
  final Queue<Breadcrumb> _entries = Queue<Breadcrumb>();

  void add(String text) {
    _entries.addLast(Breadcrumb(_clock(), text));
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
  }

  /// Oldest first.
  List<Breadcrumb> get entries => List<Breadcrumb>.unmodifiable(_entries);

  void clear() => _entries.clear();
}
