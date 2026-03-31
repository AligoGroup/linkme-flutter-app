import 'package:json_annotation/json_annotation.dart';

part 'register_request.g.dart';

@JsonSerializable()
class RegisterRequest {
  final String username;
  final String password;
  final String email;
  final String? nickname;
  final String? phone;

  RegisterRequest({
    required this.username,
    required this.password,
    required this.email,
    this.nickname,
    this.phone,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}