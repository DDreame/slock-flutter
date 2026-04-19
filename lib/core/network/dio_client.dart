import 'package:dio/dio.dart';
import 'package:slock_app/core/network/app_failure_mapper.dart';

class AppDioClient {
  AppDioClient(Dio dio, {AppFailureMapper failureMapper = const AppFailureMapper()})
    : _dio = dio,
      _failureMapper = failureMapper;

  final Dio _dio;
  final AppFailureMapper _failureMapper;

  Dio get rawDio => _dio;

  Future<Response<T>> request<T>(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final requestOptions =
          options?.copyWith(method: method) ?? Options(method: method);
      return await _dio.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: requestOptions,
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      throw _failureMapper.map(error);
    } catch (error) {
      throw _failureMapper.map(error);
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return request<T>(
      path,
      method: 'GET',
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) {
    return request<T>(
      path,
      method: 'POST',
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: options,
    );
  }
}
