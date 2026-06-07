import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkStatusIndicator extends StatefulWidget {
  const NetworkStatusIndicator({Key? key}) : super(key: key);

  @override
  State<NetworkStatusIndicator> createState() => _NetworkStatusIndicatorState();
}

class _NetworkStatusIndicatorState extends State<NetworkStatusIndicator> {
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
        
    // Vérification active toutes les 3 secondes
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _initConnectivity();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    late List<ConnectivityResult> result;
    try {
      result = await _connectivity.checkConnectivity();
    } catch (e) {
      return;
    }
    if (!mounted) {
      return;
    }
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    setState(() {
      _connectionStatus = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.red; // No connection

    if (_connectionStatus.contains(ConnectivityResult.wifi)) {
      statusColor = Colors.green; // Good connection
    } else if (_connectionStatus.contains(ConnectivityResult.mobile)) {
      statusColor = Colors.orange; // Moderate connection
    } else if (_connectionStatus.contains(ConnectivityResult.ethernet) ||
               _connectionStatus.contains(ConnectivityResult.vpn)) {
      statusColor = Colors.green; 
    }

    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: statusColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
