import 'dart:convert';

ResponseApi responseApiFromJson(String str) =>
    ResponseApi.fromJson(json.decode(str));

String responseApiToJson(ResponseApi data) => json.encode(data.toJson());

class ResponseApi {
  bool? success;
  String? message;
  dynamic data;
  int? statusCode;
  String? error;
  int? remainingAttempts;
  bool? codeRenewed;

  ResponseApi({
    this.success,
    this.message,
    this.data,
    this.statusCode,
    this.error,
    this.remainingAttempts,
    this.codeRenewed,
  });

  factory ResponseApi.fromJson(Map<String, dynamic> json) => ResponseApi(
    success: json["success"],
    message: json["message"],
    data: json["data"],
    statusCode: json["statusCode"],
    error: json["error"],
    remainingAttempts: json["remainingAttempts"],
    codeRenewed: json["codeRenewed"],
  );

  Map<String, dynamic> toJson() => {
    "success": success,
    "message": message,
    "data": data,
    "statusCode": statusCode,
    "error": error,
    "remainingAttempts": remainingAttempts,
    "codeRenewed": codeRenewed,
  };
}
