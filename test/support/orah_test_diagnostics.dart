import 'dart:async';
import 'dart:io';

/// Synchronous lifecycle diagnostics. Logging never awaits or schedules work.
class OrahTestDiagnostics {
  OrahTestDiagnostics._();
  static final String runId = Platform.environment['GITHUB_RUN_ID'] ?? 'local-pid-${pid}';
  static int _cycle = 0;
  static String _testId = 'unassigned';
  static String _phase = 'bootstrap';
  static void beginCycle(String name) { _cycle++; _testId = '$runId-test-$_cycle'; _phase = 'setup'; log('cycle begin name=$name'); }
  static void setPhase(String phase) { _phase = phase; log('phase changed'); }
  static void log(String message) => print('[ORAH-DIAG][utc=${DateTime.now().toUtc().toIso8601String()}][run=$runId][test=$_testId][phase=$_phase] $message');
  static Future<T> bounded<T>(String checkpoint, Future<T> Function() operation, {Duration timeout = const Duration(seconds: 12)}) async {
    log('checkpoint ENTER: $checkpoint');
    try {
      final result = await Zone.root.run(() => operation().timeout(timeout, onTimeout: () => throw TimeoutException('ORAH diagnostic checkpoint timed out after ${timeout.inSeconds}s: $checkpoint')));
      log('checkpoint EXIT: $checkpoint');
      return result;
    } catch (error, stackTrace) {
      log('checkpoint FAILED: $checkpoint error=$error');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
