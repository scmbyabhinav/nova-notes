import 'dart:async';

/// A timeout guard whose timers are cancelled when the owning State is disposed.
///
/// Future.timeout leaves its timer alive until the timeout or source future
/// completes. Widget screens can be disposed while a repository operation is
/// still pending, so this helper also completes its waiters on disposal.
class LifecycleTimeout {
  final Set<Timer> _timers = <Timer>{};
  final Set<Completer<dynamic>> _pending = <Completer<dynamic>>{};
  bool _disposed = false;

  Future<T> run<T>(Future<T> operation, Duration duration) {
    if (_disposed) {
      return Future<T>.error(StateError('LifecycleTimeout is disposed'));
    }

    final completer = Completer<T>();
    _pending.add(completer);
    late final Timer timer;
    timer = Timer(duration, () {
      _timers.remove(timer);
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Operation exceeded $duration', duration),
        );
      }
    });
    _timers.add(timer);

    operation.then<void>(
      (value) {
        if (!completer.isCompleted) completer.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
    );

    return completer.future.whenComplete(() {
      timer.cancel();
      _timers.remove(timer);
      _pending.remove(completer);
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    for (final completer in _pending.toList()) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Owner disposed during operation'));
      }
    }
    _pending.clear();
  }
}
