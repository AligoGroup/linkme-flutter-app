import 'package:json_annotation/json_annotation.dart';

part 'api_response.g.dart';

@JsonSerializable(genericArgumentFactories: true)
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? code;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.code,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) =>
      _$ApiResponseFromJson(json, fromJsonT);

  Map<String, dynamic> toJson(Object Function(T value) toJsonT) =>
      _$ApiResponseToJson(this, toJsonT);

  // 便捷构造函数
  factory ApiResponse.success(String message, [T? data]) {
    return ApiResponse(
      success: true,
      message: message,
      data: data,
      code: 200,
    );
  }

  factory ApiResponse.error(String message, [int? code]) {
    return ApiResponse(
      success: false,
      message: message,
      data: null,
      code: code ?? 400,
    );
  }

  bool get isSuccess => success;
  bool get isError => !success;
}