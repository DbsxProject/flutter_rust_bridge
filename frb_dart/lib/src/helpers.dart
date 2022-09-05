import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_rust_bridge/src/basic.dart';
import 'package:flutter_rust_bridge/src/platform_independent.dart';
import 'package:meta/meta.dart';
export 'ffi.dart';

/// Allow custom setup hooks before ffi can be executed.
/// All other ffi calls will wait (async) until the setup ffi finishes.
///
/// Usage:
///
/// 1. Please call [setupMixinConstructor] inside the constructor of your class.
/// 2. Inside your [setup], please call ffi functions with hint=[kHintSetup].
mixin FlutterRustBridgeSetupMixin<T extends FlutterRustBridgeWireBase> on FlutterRustBridgeBase<T> {
  /// Inside your [setup], please call ffi functions with hint=[kHintSetup].
  static const kHintSetup = _FlutterRustBridgeSetupMixinSkipWaitHint._();

  final _setupCompleter = Completer<void>();

  /// Please call it inside the constructor of your class.
  void setupMixinConstructor() {
    () async {
      try {
        log('FlutterRustBridgeSetupMixin.setupMixinConstructor start setup');
        await setup();
      } finally {
        log('FlutterRustBridgeSetupMixin.setupMixinConstructor complete setup');
        _setupCompleter.complete();
      }
    }();
  }

  @override
  Future<S> executeNormal<S>(FlutterRustBridgeTask<S> task) async {
    await _beforeExecute(task);
    return await super.executeNormal(task);
  }

  @override
  Stream<S> executeStream<S>(FlutterRustBridgeTask<S> task) async* {
    await _beforeExecute(task);
    yield* super.executeStream(task);
  }

  Future<void> _beforeExecute<S>(FlutterRustBridgeTask<S> task) async {
    if (!_setupCompleter.isCompleted && task.hint is! _FlutterRustBridgeSetupMixinSkipWaitHint) {
      log('FlutterRustBridgeSetupMixin.beforeExecute start waiting setup to complete (task=${task.debugName})');
      await _setupCompleter.future;
      log('FlutterRustBridgeSetupMixin.beforeExecute end waiting setup to complete (task=${task.debugName})');
    }
  }

  /// Do your setup logic inside this function.
  @protected
  Future<void> setup();

  /// Configure a logger for error handling.
  @protected
  void log(String message) {}
}

class _FlutterRustBridgeSetupMixinSkipWaitHint {
  const _FlutterRustBridgeSetupMixinSkipWaitHint._();
}

/// Add a timeout to [executeNormal]
mixin FlutterRustBridgeTimeoutMixin<T extends FlutterRustBridgeWireBase> on FlutterRustBridgeBase<T> {
  @override
  Future<S> executeNormal<S>(FlutterRustBridgeTask<S> task) {
    // capture a stack trace at *here*, such that when timeout, can have a good stack trace
    final stackTrace = StackTrace.current;

    final timeLimitForExecuteNormal = this.timeLimitForExecuteNormal;

    var future = super.executeNormal(task);
    if (timeLimitForExecuteNormal != null) {
      future = future.timeout(timeLimitForExecuteNormal,
          onTimeout: () =>
              throw FlutterRustBridgeTimeoutException(timeLimitForExecuteNormal, task.debugName, stackTrace));
    }

    return future;
  }

  /// The time limit for methods using [executeNormal]. Return null means *disable* this functionality.
  @protected
  Duration? get timeLimitForExecuteNormal;
}

/// Thrown when the browser is not run in a [cross-origin isolated] environment.
///
/// [cross-origin isolated]: https://developer.mozilla.org/en-US/docs/Web/API/crossOriginIsolated
class MissingHeaderException implements Exception {
  const MissingHeaderException();
  static const _message = '''
Buffers cannot be shared due to missing cross-origin headers.
Make sure your web server responds with the following headers:
- Cross-Origin-Opener-Policy: same-origin
- Cross-Origin-Embedder-Policy: credentialless OR require-corp

If running from Flutter, consider `flutter build web` and running a custom static-file server.''';

  @override
  String toString() => _message;
}

class PlatformMismatchException implements Exception {
  const PlatformMismatchException();
  static const _wasm = 'Not implemented on non-WASM platforms';

  @override
  String toString() => _wasm;
}

class UnmodifiableTypedListException implements Exception {
  const UnmodifiableTypedListException();

  static const _message = 'Cannot modify the length of typed lists.';

  @override
  String toString() => _message;
}

bool uint8ListToBool(Uint8List raw) {
  final dataView = ByteData.view(raw.buffer);
  return dataView.getUint8(0) != 0;
}
