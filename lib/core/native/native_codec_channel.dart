// core/native/native_codec_channel.dart
// 作用：Platform Channel桥接层，连接Flutter和Android/iOS Native层
// 功能：通过MethodChannel调用Native编解码器

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// core/native/native_codec_channel.dart | NativeCodecChannel | Native编解码器通道
/// 作用：封装Platform Channel调用
class NativeCodecChannel {
  static const MethodChannel _channel = MethodChannel('com.linkme.av/codec');
  static NativeCodecChannel? _instance;

  /// 获取单例
  static NativeCodecChannel get instance {
    _instance ??= NativeCodecChannel._();
    return _instance!;
  }

  NativeCodecChannel._();

  /// core/native/native_codec_channel.dart | initialize | 初始化
  /// 作用：初始化Native编解码器模块
  Future<bool> initialize() async {
    try {
      final result = await _channel.invokeMethod<bool>('initialize');
      if (kDebugMode) {
        print('[NativeCodecChannel] 初始化: ${result == true ? "成功" : "失败"}');
      }
      return result == true;
    } catch (e) {
      if (kDebugMode) {
        print('[NativeCodecChannel] 初始化失败: $e');
      }
      return false;
    }
  }

  /// core/native/native_codec_channel.dart | isHardwareSupported | 检查硬件加速支持
  Future<bool> isHardwareSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>('isHardwareSupported');
      return result == true;
    } catch (e) {
      if (kDebugMode) {
        print('[NativeCodecChannel] 查询硬件支持失败: $e');
      }
      return false;
    }
  }

  /// core/native/native_codec_channel.dart | warmup | 预热编解码器
  Future<void> warmup() async {
    try {
      await _channel.invokeMethod('warmup');
      if (kDebugMode) {
        print('[NativeCodecChannel] 预热完成');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NativeCodecChannel] 预热失败: $e');
      }
    }
  }

  /// core/native/native_codec_channel.dart | createVideoEncoder | 创建视频编码器
  Future<int?> createVideoEncoder({
    required int width,
    required int height,
    required int fps,
    required int bitrate,
    int keyframeInterval = 60,
    int threads = 4,
    bool useHardware = true,
  }) async {
    try {
      final handle = await _channel.invokeMethod<int>('createVideoEncoder', {
        'width': width,
        'height': height,
        'fps': fps,
        'bitrate': bitrate,
        'keyframeInterval': keyframeInterval,
        'threads': threads,
        'useHardware': useHardware,
      });
      
      if (kDebugMode) {
        print('[NativeCodecChannel] 视频编码器创建成功: handle=$handle');
      }
      
      return handle;
    } catch (e) {
      if (kDebugMode) {
        print('[NativeCodecChannel] 创建视频编码器失败: $e');
      }
      return null;
    }
  }

  /// core/native/native_codec_channel.dart | encodeVideoFrame | 编码视频帧
  Future<Uint8List?> encodeVideoFrame({
    required int handle,
    required Uint8List yPlane,
    required Uint8List uPlane,
    required Uint8List vPlane,
    required int width,
    required int height,
    required int timestamp,
  }) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('encodeVideoFrame', {
        'handle': handle,
        'yPlane': yPlane,
        'uPlane': uPlane,
        'vPlane': vPlane,
        'width': width,
        'height': height,
        'timestamp': timestamp,
      });
      
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('[NativeCodecChannel] 编码视频帧失败: $e');
      }
      return null;
    }
  }

  /// core/native/native_codec_channel.dart | forceKeyFrame | 强制关键帧
  Future<void> forceKeyFrame(int handle) async {
    try {
      await _channel.invokeMethod('forceKeyFrame', {'handle': handle});
    } catch (e) {
      if (kDebugMode) {
        print('[NativeCodecChannel] 强制关键帧失败: $e');
      }
    }
  }

  /// core/native/native_codec_channel.dart | updateBitrate | 更新码率
  Future<void> updateBitrate(int handle, int bitrate) async {
    try {
      await _channel.invokeMethod('updateBitrate', {
        'handle': handle,
        'bitrate': bitrate,
      });
    } catch (e) {
      if (kDebugMode) {
        print('[NativeCodecChannel] 更新码率失败: $e');
      }
    }
  }

  /// core/native/native_codec_channel.dart | releaseVideoEncoder | 释放视频编码器
  Future<void> releaseVideoEncoder(int handle) async {
    try {
      await _channel.invokeMethod('releaseVideoEncoder', {'handle': handle});
      if (kDebugMode) {
        print('[NativeCodecChannel] 视频编码器已释放: handle=$handle');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NativeCodecChannel] 释放视频编码器失败: $e');
      }
    }
  }

  /// core/native/native_codec_channel.dart | createVideoDecoder | 创建视频解码器
  Future<int?> createVideoDecoder({
    required int maxWidth,
    required int maxHeight,
    int threads = 4,
    bool useHardware = true,
  }) async {
    try {
      final handle = await _channel.invokeMethod<int>('createVideoDecoder', {
        'maxWidth': maxWidth,
        'maxHeight': maxHeight,
        'threads': threads,
        'useHardware': useHardware,
      });
      
      if (kDebugMode) {
        print('[NativeCodecChannel] 视频解码器创建成功: handle=$handle');
      }
      
      return handle;
    } catch (e) {
      if (kDebugMode) {
        print('[NativeCodecChannel] 创建视频解码器失败: $e');
      }
      return null;
    }
  }

  /// core/native/native_codec_channel.dart | decodeVideoFrame | 解码视频帧
  Future<Map<String, dynamic>?> decodeVideoFrame({
    required int handle,
    required Uint8List encodedData,
    required int timestamp,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map>('decodeVideoFrame', {
        'handle': handle,
        'encodedData': encodedData,
        'timestamp': timestamp,
      });
      
      return result?.cast<String, dynamic>();
    } catch (e) {
      if (kDebugMode) {
        print('[NativeCodecChannel] 解码视频帧失败: $e');
      }
      return null;
    }
  }

  /// core/native/native_codec_channel.dart | releaseVideoDecoder | 释放视频解码器
  Future<void> releaseVideoDecoder(int handle) async {
    try {
      await _channel.invokeMethod('releaseVideoDecoder', {'handle': handle});
      if (kDebugMode) {
        print('[NativeCodecChannel] 视频解码器已释放: handle=$handle');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NativeCodecChannel] 释放视频解码器失败: $e');
      }
    }
  }

  /// core/native/native_codec_channel.dart | createAudioProcessor | 创建音频处理器
  Future<int?> createAudioProcessor({
    required int sampleRate,
    required int channels,
    bool enableAEC = true,
    bool enableNS = true,
    bool enableAGC = true,
  }) async {
    try {
      final handle = await _channel.invokeMethod<int>('createAudioProcessor', {
        'sampleRate': sampleRate,
        'channels': channels,
        'enableAEC': enableAEC,
        'enableNS': enableNS,
        'enableAGC': enableAGC,
      });
      
      if (kDebugMode) {
        print('[NativeCodecChannel] 音频处理器创建成功: handle=$handle');
      }
      
      return handle;
    } catch (e) {
      if (kDebugMode) {
        print('[NativeCodecChannel] 创建音频处理器失败: $e');
      }
      return null;
    }
  }

  /// core/native/native_codec_channel.dart | processAudio | 处理音频
  Future<Uint8List?> processAudio({
    required int handle,
    required Uint8List inputData,
    required int timestamp,
  }) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('processAudio', {
        'handle': handle,
        'inputData': inputData,
        'timestamp': timestamp,
      });
      
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('[NativeCodecChannel] 处理音频失败: $e');
      }
      return null;
    }
  }

  /// core/native/native_codec_channel.dart | setVolume | 设置音量
  Future<void> setVolume(int handle, double volume) async {
    try {
      await _channel.invokeMethod('setVolume', {
        'handle': handle,
        'volume': volume,
      });
    } catch (e) {
      if (kDebugMode) {
        print('[NativeCodecChannel] 设置音量失败: $e');
      }
    }
  }

  /// core/native/native_codec_channel.dart | releaseAudioProcessor | 释放音频处理器
  Future<void> releaseAudioProcessor(int handle) async {
    try {
      await _channel.invokeMethod('releaseAudioProcessor', {'handle': handle});
      if (kDebugMode) {
        print('[NativeCodecChannel] 音频处理器已释放: handle=$handle');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NativeCodecChannel] 释放音频处理器失败: $e');
      }
    }
  }
}
