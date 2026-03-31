// Lightweight global server health notifier.
// Emits "error" when HTTP/WebSocket cannot reach backend, and "healthy" when it recovers.
import 'dart:async';

enum ServerStatus { healthy, error }

class ServerHealth {
  static final ServerHealth _instance = ServerHealth._internal();
  factory ServerHealth() => _instance;
  ServerHealth._internal();

  final _controller = StreamController<ServerStatus>.broadcast();
  ServerStatus _status = ServerStatus.healthy;

  Stream<ServerStatus> get stream => _controller.stream;
  ServerStatus get status => _status;

  void setHealthy() {
    if (_status != ServerStatus.healthy) {
      _status = ServerStatus.healthy;
      _controller.add(_status);
    }
  }

  void setError() {
    if (_status != ServerStatus.error) {
      _status = ServerStatus.error;
      _controller.add(_status);
    }
  }
}

