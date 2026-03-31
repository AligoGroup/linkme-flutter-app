import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'dart:convert';
import '../../core/network/api_config.dart';
import 'auth_service.dart';

class ImageUploadService {
  static final ImageUploadService _instance = ImageUploadService._internal();
  factory ImageUploadService() => _instance;
  ImageUploadService._internal();

  final AuthService _authService = AuthService();

  /// 压缩图片
  /// [file] 原始图片文件
  /// [quality] 压缩质量 0-100
  /// [maxWidth] 最大宽度
  /// [maxHeight] 最大高度
  Future<File?> compressImage(
    File file, {
    int quality = 85,
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async {
    try {
      final filePath = file.absolute.path;
      final lastIndex = filePath.lastIndexOf('.');
      final outPath = '${filePath.substring(0, lastIndex)}_compressed.jpg';

      // 尝试压缩图片
      final result = await FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        return File(result.path);
      }
      
      // 如果压缩失败，直接返回原文件
      print('图片压缩失败，使用原文件');
      return file;
    } catch (e) {
      print('图片压缩异常: $e，使用原文件');
      // 压缩失败时返回原文件
      return file;
    }
  }

  /// 上传图片到服务器
  /// [file] 要上传的图片文件
  /// 返回上传后的图片URL
  Future<String?> uploadAvatar(File file) async {
    try {
      // 先压缩图片
      final compressedFile = await compressImage(file);
      if (compressedFile == null) {
        print('图片处理失败');
        return null;
      }

      // 获取当前token
      final token = _authService.getCurrentToken();
      if (token == null) {
        print('未登录，无法上传图片');
        return null;
      }

      // 创建multipart请求
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.uploadAvatar}');
      final request = http.MultipartRequest('POST', uri);

      // 添加认证头
      request.headers['Authorization'] = 'Bearer $token';

      // 添加文件，明确指定 MIME 类型为 image/jpeg
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        compressedFile.path,
        contentType: http_parser.MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);

      // 发送请求
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // 清理压缩后的临时文件（如果不是原文件）
      if (compressedFile.path != file.path) {
        try {
          await compressedFile.delete();
        } catch (e) {
          print('删除临时文件失败: $e');
        }
      }

      print('上传头像响应状态码: ${response.statusCode}');
      print('上传头像响应内容: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('解析后的JSON数据: $jsonData');
        
        // 根据后端返回格式解析（后端使用 success 字段，不是 code）
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final avatarUrl = jsonData['data']['url'] as String?;
          print('成功获取头像URL: $avatarUrl');
          return avatarUrl;
        } else {
          print('上传失败: ${jsonData['message']}');
          return null;
        }
      } else {
        print('上传失败，状态码: ${response.statusCode}，响应: ${response.body}');
        return null;
      }
    } catch (e) {
      print('上传图片异常: $e');
      return null;
    }
  }
  
  /// 上传聊天图片
  /// [file] 要上传的图片文件
  /// [onProgress] 上传进度回调 (0.0 - 1.0)
  /// 返回上传后的图片URL
  Future<String?> uploadChatImage(File file, {Function(double)? onProgress}) async {
    try {
      // 先压缩图片
      onProgress?.call(0.1); // 10% - 开始压缩
      final compressedFile = await compressImage(file);
      if (compressedFile == null) {
        print('图片处理失败');
        return null;
      }

      onProgress?.call(0.2); // 20% - 压缩完成
      
      // 获取当前token
      final token = _authService.getCurrentToken();
      if (token == null) {
        print('未登录，无法上传图片');
        return null;
      }

      // 创建multipart请求
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.uploadChatImage}');
      final request = http.MultipartRequest('POST', uri);

      // 添加认证头
      request.headers['Authorization'] = 'Bearer $token';

      // 添加文件，明确指定 MIME 类型为 image/jpeg
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        compressedFile.path,
        contentType: http_parser.MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);

      onProgress?.call(0.3); // 30% - 开始上传
      
      // 发送请求并模拟平滑进度
      final responseFuture = request.send();
      
      // 模拟上传进度（因为 http 包不支持真实进度）
      // 使用更平滑的进度更新
      for (int i = 4; i <= 9; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        onProgress?.call(i / 10.0);
      }
      
      final streamedResponse = await responseFuture;
      final response = await http.Response.fromStream(streamedResponse);

      // 清理压缩后的临时文件（如果不是原文件）
      if (compressedFile.path != file.path) {
        try {
          await compressedFile.delete();
        } catch (e) {
          print('删除临时文件失败: $e');
        }
      }

      print('上传聊天图片响应状态码: ${response.statusCode}');
      print('上传聊天图片响应内容: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('解析后的JSON数据: $jsonData');
        
        // 根据后端返回格式解析（后端使用 success 字段，不是 code）
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final imageUrl = jsonData['data']['url'] as String?;
          print('成功获取图片URL: $imageUrl');
          onProgress?.call(1.0); // 100% - 完成
          return imageUrl;
        } else {
          print('上传失败: ${jsonData['message']}');
          return null;
        }
      } else {
        print('上传失败，状态码: ${response.statusCode}，响应: ${response.body}');
        return null;
      }
    } catch (e) {
      print('上传图片异常: $e');
      print('异常堆栈: ${StackTrace.current}');
      return null;
    }
  }
}
