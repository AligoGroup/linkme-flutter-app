// native/linkme_av_core/src/jni_bridge.cpp
// 作用：JNI桥接层，连接Flutter和C++ Native层
// 功能：提供Java/Kotlin可调用的接口

#include <jni.h>
#include <string>
#include <memory>
#include <map>
#include "video_encoder.h"
#include "video_decoder.h"
#include "audio_processor.h"
#include "codec_factory.h"
#include "frame_buffer.h"
#include "quality_controller.h"

using namespace linkme::av;

// 全局对象管理
static std::map<jlong, std::shared_ptr<VideoEncoder>> g_encoders;
static std::map<jlong, std::shared_ptr<VideoDecoder>> g_decoders;
static std::map<jlong, std::shared_ptr<AudioProcessor>> g_audio_processors;
static std::map<jlong, std::shared_ptr<FrameBuffer>> g_frame_buffers;
static std::map<jlong, std::shared_ptr<QualityController>> g_quality_controllers;
static jlong g_next_handle = 1;

extern "C" {

// ==================== 视频编码器接口 ====================

JNIEXPORT jlong JNICALL
Java_com_linkme_av_VideoEncoder_nativeCreate(JNIEnv* env, jobject thiz) {
    auto encoder = std::make_shared<VideoEncoder>();
    jlong handle = g_next_handle++;
    g_encoders[handle] = encoder;
    return handle;
}

JNIEXPORT jboolean JNICALL
Java_com_linkme_av_VideoEncoder_nativeInitialize(
    JNIEnv* env, jobject thiz, jlong handle,
    jint width, jint height, jint fps, jint bitrate,
    jint keyframe_interval, jint threads, jboolean use_hardware) {
    
    auto it = g_encoders.find(handle);
    if (it == g_encoders.end()) return JNI_FALSE;
    
    VideoEncoderConfig config;
    config.width = width;
    config.height = height;
    config.fps = fps;
    config.bitrate = bitrate;
    config.keyframe_interval = keyframe_interval;
    config.threads = threads;
    config.use_hardware = use_hardware;
    config.quality_preset = 2;
    
    return it->second->initialize(config) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jbyteArray JNICALL
Java_com_linkme_av_VideoEncoder_nativeEncode(
    JNIEnv* env, jobject thiz, jlong handle,
    jbyteArray y_plane, jbyteArray u_plane, jbyteArray v_plane,
    jint width, jint height, jlong timestamp) {
    
    auto it = g_encoders.find(handle);
    if (it == g_encoders.end()) return nullptr;
    
    // 获取YUV数据
    jbyte* y_data = env->GetByteArrayElements(y_plane, nullptr);
    jbyte* u_data = env->GetByteArrayElements(u_plane, nullptr);
    jbyte* v_data = env->GetByteArrayElements(v_plane, nullptr);
    
    // 准备输入帧
    RawVideoFrame frame;
    frame.y_plane = reinterpret_cast<uint8_t*>(y_data);
    frame.u_plane = reinterpret_cast<uint8_t*>(u_data);
    frame.v_plane = reinterpret_cast<uint8_t*>(v_data);
    frame.y_stride = width;
    frame.u_stride = width / 2;
    frame.v_stride = width / 2;
    frame.width = width;
    frame.height = height;
    frame.timestamp = timestamp;
    
    // 编码
    EncodedFrame encoded_frame;
    bool success = it->second->encode(frame, encoded_frame);
    
    // 释放输入数据
    env->ReleaseByteArrayElements(y_plane, y_data, JNI_ABORT);
    env->ReleaseByteArrayElements(u_plane, u_data, JNI_ABORT);
    env->ReleaseByteArrayElements(v_plane, v_data, JNI_ABORT);
    
    if (!success) return nullptr;
    
    // 返回编码数据
    jbyteArray result = env->NewByteArray(encoded_frame.data.size());
    env->SetByteArrayRegion(result, 0, encoded_frame.data.size(),
                           reinterpret_cast<const jbyte*>(encoded_frame.data.data()));
    return result;
}

JNIEXPORT void JNICALL
Java_com_linkme_av_VideoEncoder_nativeForceKeyFrame(
    JNIEnv* env, jobject thiz, jlong handle) {
    
    auto it = g_encoders.find(handle);
    if (it != g_encoders.end()) {
        it->second->forceKeyFrame();
    }
}

JNIEXPORT void JNICALL
Java_com_linkme_av_VideoEncoder_nativeUpdateBitrate(
    JNIEnv* env, jobject thiz, jlong handle, jint bitrate) {
    
    auto it = g_encoders.find(handle);
    if (it != g_encoders.end()) {
        it->second->updateBitrate(bitrate);
    }
}

JNIEXPORT void JNICALL
Java_com_linkme_av_VideoEncoder_nativeRelease(
    JNIEnv* env, jobject thiz, jlong handle) {
    
    auto it = g_encoders.find(handle);
    if (it != g_encoders.end()) {
        it->second->release();
        g_encoders.erase(it);
    }
}

// ==================== 视频解码器接口 ====================

JNIEXPORT jlong JNICALL
Java_com_linkme_av_VideoDecoder_nativeCreate(JNIEnv* env, jobject thiz) {
    auto decoder = std::make_shared<VideoDecoder>();
    jlong handle = g_next_handle++;
    g_decoders[handle] = decoder;
    return handle;
}

JNIEXPORT jboolean JNICALL
Java_com_linkme_av_VideoDecoder_nativeInitialize(
    JNIEnv* env, jobject thiz, jlong handle,
    jint max_width, jint max_height, jint threads, jboolean use_hardware) {
    
    auto it = g_decoders.find(handle);
    if (it == g_decoders.end()) return JNI_FALSE;
    
    VideoDecoderConfig config;
    config.max_width = max_width;
    config.max_height = max_height;
    config.threads = threads;
    config.use_hardware = use_hardware;
    config.buffer_size = 5;
    
    return it->second->initialize(config) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jobject JNICALL
Java_com_linkme_av_VideoDecoder_nativeDecode(
    JNIEnv* env, jobject thiz, jlong handle,
    jbyteArray encoded_data, jlong timestamp) {
    
    auto it = g_decoders.find(handle);
    if (it == g_decoders.end()) return nullptr;
    
    // 获取编码数据
    jsize data_size = env->GetArrayLength(encoded_data);
    jbyte* data = env->GetByteArrayElements(encoded_data, nullptr);
    
    // 准备输入
    EncodedVideoFrame encoded_frame;
    encoded_frame.data = reinterpret_cast<const uint8_t*>(data);
    encoded_frame.size = data_size;
    encoded_frame.timestamp = timestamp;
    
    // 解码
    DecodedFrame decoded_frame;
    bool success = it->second->decode(encoded_frame, decoded_frame);
    
    env->ReleaseByteArrayElements(encoded_data, data, JNI_ABORT);
    
    if (!success) return nullptr;
    
    // 创建返回对象（包含YUV数据）
    jclass frame_class = env->FindClass("com/linkme/av/DecodedFrame");
    jmethodID constructor = env->GetMethodID(frame_class, "<init>", "([B[B[BIIJ)V");
    
    // 创建YUV字节数组
    size_t y_size = decoded_frame.width * decoded_frame.height;
    size_t uv_size = y_size / 4;
    
    jbyteArray y_array = env->NewByteArray(y_size);
    jbyteArray u_array = env->NewByteArray(uv_size);
    jbyteArray v_array = env->NewByteArray(uv_size);
    
    env->SetByteArrayRegion(y_array, 0, y_size,
                           reinterpret_cast<const jbyte*>(decoded_frame.y_plane));
    env->SetByteArrayRegion(u_array, 0, uv_size,
                           reinterpret_cast<const jbyte*>(decoded_frame.u_plane));
    env->SetByteArrayRegion(v_array, 0, uv_size,
                           reinterpret_cast<const jbyte*>(decoded_frame.v_plane));
    
    jobject result = env->NewObject(frame_class, constructor,
                                   y_array, u_array, v_array,
                                   decoded_frame.width, decoded_frame.height,
                                   decoded_frame.timestamp);
    
    // 释放解码帧
    it->second->releaseFrame(decoded_frame);
    
    return result;
}

JNIEXPORT void JNICALL
Java_com_linkme_av_VideoDecoder_nativeRelease(
    JNIEnv* env, jobject thiz, jlong handle) {
    
    auto it = g_decoders.find(handle);
    if (it != g_decoders.end()) {
        it->second->release();
        g_decoders.erase(it);
    }
}

// ==================== 音频处理器接口 ====================

JNIEXPORT jlong JNICALL
Java_com_linkme_av_AudioProcessor_nativeCreate(JNIEnv* env, jobject thiz) {
    auto processor = std::make_shared<AudioProcessor>();
    jlong handle = g_next_handle++;
    g_audio_processors[handle] = processor;
    return handle;
}

JNIEXPORT jboolean JNICALL
Java_com_linkme_av_AudioProcessor_nativeInitialize(
    JNIEnv* env, jobject thiz, jlong handle,
    jint sample_rate, jint channels, jboolean enable_aec,
    jboolean enable_ns, jboolean enable_agc) {
    
    auto it = g_audio_processors.find(handle);
    if (it == g_audio_processors.end()) return JNI_FALSE;
    
    AudioProcessorConfig config;
    config.sample_rate = sample_rate;
    config.channels = channels;
    config.bits_per_sample = 16;
    config.format = AudioFormat::PCM_S16LE;
    config.enable_aec = enable_aec;
    config.enable_ns = enable_ns;
    config.enable_agc = enable_agc;
    config.bitrate = 128000;
    
    return it->second->initialize(config) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jbyteArray JNICALL
Java_com_linkme_av_AudioProcessor_nativeProcess(
    JNIEnv* env, jobject thiz, jlong handle,
    jbyteArray input_data, jlong timestamp) {
    
    auto it = g_audio_processors.find(handle);
    if (it == g_audio_processors.end()) return nullptr;
    
    // 获取输入数据
    jsize data_size = env->GetArrayLength(input_data);
    jbyte* data = env->GetByteArrayElements(input_data, nullptr);
    
    // 准备输入帧
    AudioFrame input_frame;
    input_frame.data.assign(reinterpret_cast<uint8_t*>(data),
                           reinterpret_cast<uint8_t*>(data) + data_size);
    input_frame.timestamp = timestamp;
    input_frame.format = AudioFormat::PCM_S16LE;
    
    // 处理
    AudioFrame output_frame;
    bool success = it->second->process(input_frame, output_frame);
    
    env->ReleaseByteArrayElements(input_data, data, JNI_ABORT);
    
    if (!success) return nullptr;
    
    // 返回处理后的数据
    jbyteArray result = env->NewByteArray(output_frame.data.size());
    env->SetByteArrayRegion(result, 0, output_frame.data.size(),
                           reinterpret_cast<const jbyte*>(output_frame.data.data()));
    return result;
}

JNIEXPORT void JNICALL
Java_com_linkme_av_AudioProcessor_nativeSetVolume(
    JNIEnv* env, jobject thiz, jlong handle, jfloat volume) {
    
    auto it = g_audio_processors.find(handle);
    if (it != g_audio_processors.end()) {
        it->second->setVolume(volume);
    }
}

JNIEXPORT void JNICALL
Java_com_linkme_av_AudioProcessor_nativeRelease(
    JNIEnv* env, jobject thiz, jlong handle) {
    
    auto it = g_audio_processors.find(handle);
    if (it != g_audio_processors.end()) {
        it->second->release();
        g_audio_processors.erase(it);
    }
}

// ==================== 编解码器工厂接口 ====================

JNIEXPORT jboolean JNICALL
Java_com_linkme_av_CodecFactory_nativeIsHardwareSupported(
    JNIEnv* env, jclass clazz) {
    
    return CodecFactory::getInstance().isHardwareAccelerated(
        CodecType::H265_ENCODER) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_com_linkme_av_CodecFactory_nativeWarmup(
    JNIEnv* env, jclass clazz) {
    
    CodecFactory::getInstance().warmup();
}

// ==================== 质量控制器接口 ====================

JNIEXPORT jlong JNICALL
Java_com_linkme_av_QualityController_nativeCreate(JNIEnv* env, jobject thiz) {
    auto controller = std::make_shared<QualityController>();
    jlong handle = g_next_handle++;
    g_quality_controllers[handle] = controller;
    return handle;
}

JNIEXPORT jboolean JNICALL
Java_com_linkme_av_QualityController_nativeInitialize(
    JNIEnv* env, jobject thiz, jlong handle,
    jint width, jint height, jint fps, jint bitrate) {
    
    auto it = g_quality_controllers.find(handle);
    if (it == g_quality_controllers.end()) return JNI_FALSE;
    
    QualityControllerConfig config;
    config.initial_params.width = width;
    config.initial_params.height = height;
    config.initial_params.fps = fps;
    config.initial_params.bitrate = bitrate;
    config.strategy = QualityStrategy::BALANCED;
    config.enable_auto_adjust = true;
    
    return it->second->initialize(config) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_com_linkme_av_QualityController_nativeUpdateNetworkStats(
    JNIEnv* env, jobject thiz, jlong handle,
    jlong rtt_ms, jdouble packet_loss_rate,
    jlong bandwidth_bps, jlong jitter_ms) {
    
    auto it = g_quality_controllers.find(handle);
    if (it == g_quality_controllers.end()) return;
    
    NetworkStats stats;
    stats.rtt_ms = rtt_ms;
    stats.packet_loss_rate = packet_loss_rate;
    stats.bandwidth_bps = bandwidth_bps;
    stats.jitter_ms = jitter_ms;
    
    it->second->updateNetworkStats(stats);
}

JNIEXPORT void JNICALL
Java_com_linkme_av_QualityController_nativeRelease(
    JNIEnv* env, jobject thiz, jlong handle) {
    
    auto it = g_quality_controllers.find(handle);
    if (it != g_quality_controllers.end()) {
        it->second->release();
        g_quality_controllers.erase(it);
    }
}

} // extern "C"
