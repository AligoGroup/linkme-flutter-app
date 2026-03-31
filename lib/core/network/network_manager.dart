import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum NetworkStatus {
  online,
  offline,
  unknown,
}

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  NetworkStatus _networkStatus = NetworkStatus.unknown;
  final StreamController<NetworkStatus> _networkStatusController =
      StreamController<NetworkStatus>.broadcast();

  NetworkStatus get networkStatus => _networkStatus;
  Stream<NetworkStatus> get networkStatusStream => _networkStatusController.stream;
  bool get isOnline => _networkStatus == NetworkStatus.online;
  bool get isOffline => _networkStatus == NetworkStatus.offline;

  void initialize() {
    _checkInitialConnectivity();
    _listenToConnectivityChanges();
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateNetworkStatus(results);
    } catch (e) {
      if (kDebugMode) {
        print('检查网络连接失败: $e');
      }
      _updateNetworkStatus([ConnectivityResult.none]);
    }
  }

  void _listenToConnectivityChanges() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) => _updateNetworkStatus(results),
      onError: (error) {
        if (kDebugMode) {
          print('网络状态监听错误: $error');
        }
      },
    );
  }

  void _updateNetworkStatus(List<ConnectivityResult> results) {
    NetworkStatus newStatus;
    
    if (results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      newStatus = NetworkStatus.online;
    } else if (results.contains(ConnectivityResult.none)) {
      newStatus = NetworkStatus.offline;
    } else {
      newStatus = NetworkStatus.unknown;
    }

    if (_networkStatus != newStatus) {
      _networkStatus = newStatus;
      _networkStatusController.add(_networkStatus);
      
      if (kDebugMode) {
        print('网络状态变化: ${_getStatusText(newStatus)}');
      }
    }
  }

  String _getStatusText(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.online:
        return '在线';
      case NetworkStatus.offline:
        return '离线';
      case NetworkStatus.unknown:
        return '未知';
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _networkStatusController.close();
  }
}