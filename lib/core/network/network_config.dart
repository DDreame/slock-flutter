import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkConfig {
  const NetworkConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.sendTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 30),
    this.defaultHeaders = const <String, String>{'Accept': 'application/json'},
  });

  final String baseUrl;
  final Duration connectTimeout;
  final Duration sendTimeout;
  final Duration receiveTimeout;
  final Map<String, String> defaultHeaders;

  BaseOptions toBaseOptions() {
    return BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      headers: Map<String, Object>.from(defaultHeaders),
    );
  }
}

final networkConfigProvider = Provider<NetworkConfig>((ref) {
  return const NetworkConfig(baseUrl: 'https://api.slock.invalid');
});
