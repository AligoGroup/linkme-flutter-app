// native/linkme_av_core/src/hardware_accelerator.cpp
// 作用：硬件加速器实现
// 功能：封装Android MediaCodec和iOS VideoToolbox

#include "hardware_accelerator.h"
#include <iostream>
#include <cstring>

#ifdef __ANDROID__
#include <media/NdkMediaCodec.h>
#include <media/NdkMediaFormat.h>
#elif defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_IOS
#include <VideoToolbox/VideoToolbox.h>
#include <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>
#endif
#endif

namespace linkme {
namespace av {

class HardwareAccelerator::Impl {
public:
    Impl() : accelerator_type_(AcceleratorType::NONE),
             last_error_("") {}

    ~Impl() {
        release();
    }

    bool initialize() {
        accelerator_type_ = detectAcceleratorType();
        
        if (accelerator_type_ == AcceleratorType::NONE) {
            last_error_ = "未检测到硬件加速支持";
            std::cout << "[HardwareAccelerator] " << last_error_ << std::endl;
            return false;
        }
        
        std::cout << "[HardwareAccelerator] 初始化成功，类型: " 
                  << getAcceleratorTypeName(accelerator_type_) << std::endl;
        return true;
    }

    AcceleratorType detectAcceleratorType() const {
#ifdef __ANDROID__
        return AcceleratorType::ANDROID_MEDIACODEC;
#elif defined(__APPLE__)
#if TARGET_OS_IOS
        return AcceleratorType::IOS_VIDEOTOOLBOX;
#endif
#elif defined(__linux__)
        return AcceleratorType::LINUX_VAAPI;
#elif defined(_WIN32)
        return AcceleratorType::WINDOWS_D3D11;
#endif
        return AcceleratorType::NONE;
    }

    AcceleratorCapability queryCapability(AcceleratorType type) const {
        AcceleratorCapability cap;
        cap.type = type;
        
        switch (type) {
            case AcceleratorType::ANDROID_MEDIACODEC:
                cap.name = "Android MediaCodec";
                cap.encode_supported = true;
                cap.decode_supported = true;
                cap.max_width = 3840;
                cap.max_height = 2160;
                cap.max_instances = 16;
                cap.supported_codecs = {"H.264", "H.265", "VP8", "VP9"};
                break;
                
            case AcceleratorType::IOS_VIDEOTOOLBOX:
                cap.name = "iOS VideoToolbox";
                cap.encode_supported = true;
                cap.decode_supported = true;
                cap.max_width = 3840;
                cap.max_height = 2160;
                cap.max_instances = 8;
                cap.supported_codecs = {"H.264", "H.265"};
                break;
                
            default:
                cap.name = "None";
                cap.encode_supported = false;
                cap.decode_supported = false;
                break;
        }
        
        return cap;
    }

    void* createHardwareEncoder(const HardwareEncoderConfig& config) {
#ifdef __ANDROID__
        return createAndroidEncoder(config);
#elif defined(__APPLE__) && TARGET_OS_IOS
        return createIOSEncoder(config);
#else
        last_error_ = "当前平台不支持硬件编码";
        return nullptr;
#endif
    }

    void* createHardwareDecoder(const HardwareDecoderConfig& config) {
#ifdef __ANDROID__
        return createAndroidDecoder(config);
#elif defined(__APPLE__) && TARGET_OS_IOS
        return createIOSDecoder(config);
#else
        last_error_ = "当前平台不支持硬件解码";
        return nullptr;
#endif
    }

    bool encodeFrame(void* encoder_handle, 
                     const uint8_t* input_data, 
                     size_t input_size,
                     uint8_t** output_data, 
                     size_t* output_size,
                     bool* is_keyframe) {
#ifdef __ANDROID__
        return encodeFrameAndroid(encoder_handle, input_data, input_size, 
                                 output_data, output_size, is_keyframe);
#elif defined(__APPLE__) && TARGET_OS_IOS
        return encodeFrameIOS(encoder_handle, input_data, input_size,
                             output_data, output_size, is_keyframe);
#else
        last_error_ = "当前平台不支持硬件编码";
        return false;
#endif
    }

    bool decodeFrame(void* decoder_handle,
                     const uint8_t* input_data,
                     size_t input_size,
                     uint8_t** output_data,
                     size_t* output_size) {
#ifdef __ANDROID__
        return decodeFrameAndroid(decoder_handle, input_data, input_size,
                                 output_data, output_size);
#elif defined(__APPLE__) && TARGET_OS_IOS
        return decodeFrameIOS(decoder_handle, input_data, input_size,
                             output_data, output_size);
#else
        last_error_ = "当前平台不支持硬件解码";
        return false;
#endif
    }

    void releaseHardwareEncoder(void* encoder_handle) {
#ifdef __ANDROID__
        if (encoder_handle) {
            AMediaCodec* codec = static_cast<AMediaCodec*>(encoder_handle);
            AMediaCodec_stop(codec);
            AMediaCodec_delete(codec);
        }
#elif defined(__APPLE__) && TARGET_OS_IOS
        if (encoder_handle) {
            VTCompressionSessionRef session = 
                static_cast<VTCompressionSessionRef>(encoder_handle);
            VTCompressionSessionInvalidate(session);
            CFRelease(session);
        }
#endif
    }

    void releaseHardwareDecoder(void* decoder_handle) {
#ifdef __ANDROID__
        if (decoder_handle) {
            AMediaCodec* codec = static_cast<AMediaCodec*>(decoder_handle);
            AMediaCodec_stop(codec);
            AMediaCodec_delete(codec);
        }
#elif defined(__APPLE__) && TARGET_OS_IOS
        if (decoder_handle) {
            VTDecompressionSessionRef session = 
                static_cast<VTDecompressionSessionRef>(decoder_handle);
            VTDecompressionSessionInvalidate(session);
            CFRelease(session);
        }
#endif
    }

    bool isSupported() const {
        return accelerator_type_ != AcceleratorType::NONE;
    }

    std::string getLastError() const {
        return last_error_;
    }

    void release() {
        // 清理资源
    }

private:
#ifdef __ANDROID__
    void* createAndroidEncoder(const HardwareEncoderConfig& config) {
        AMediaCodec* codec = AMediaCodec_createEncoderByType("video/hevc");
        if (!codec) {
            last_error_ = "创建Android编码器失败";
            return nullptr;
        }
        
        AMediaFormat* format = AMediaFormat_new();
        AMediaFormat_setString(format, AMEDIAFORMAT_KEY_MIME, "video/hevc");
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_WIDTH, config.width);
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_HEIGHT, config.height);
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_BIT_RATE, config.bitrate);
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_FRAME_RATE, config.fps);
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_COLOR_FORMAT, 21); // YUV420
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_I_FRAME_INTERVAL, 
                             config.keyframe_interval / config.fps);
        
        media_status_t status = AMediaCodec_configure(codec, format, nullptr, nullptr, 
                                                      AMEDIACODEC_CONFIGURE_FLAG_ENCODE);
        AMediaFormat_delete(format);
        
        if (status != AMEDIA_OK) {
            last_error_ = "配置Android编码器失败";
            AMediaCodec_delete(codec);
            return nullptr;
        }
        
        status = AMediaCodec_start(codec);
        if (status != AMEDIA_OK) {
            last_error_ = "启动Android编码器失败";
            AMediaCodec_delete(codec);
            return nullptr;
        }
        
        std::cout << "[HardwareAccelerator] Android编码器创建成功" << std::endl;
        return codec;
    }

    void* createAndroidDecoder(const HardwareDecoderConfig& config) {
        AMediaCodec* codec = AMediaCodec_createDecoderByType("video/hevc");
        if (!codec) {
            last_error_ = "创建Android解码器失败";
            return nullptr;
        }
        
        AMediaFormat* format = AMediaFormat_new();
        AMediaFormat_setString(format, AMEDIAFORMAT_KEY_MIME, "video/hevc");
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_WIDTH, config.max_width);
        AMediaFormat_setInt32(format, AMEDIAFORMAT_KEY_HEIGHT, config.max_height);
        
        media_status_t status = AMediaCodec_configure(codec, format, nullptr, nullptr, 0);
        AMediaFormat_delete(format);
        
        if (status != AMEDIA_OK) {
            last_error_ = "配置Android解码器失败";
            AMediaCodec_delete(codec);
            return nullptr;
        }
        
        status = AMediaCodec_start(codec);
        if (status != AMEDIA_OK) {
            last_error_ = "启动Android解码器失败";
            AMediaCodec_delete(codec);
            return nullptr;
        }
        
        std::cout << "[HardwareAccelerator] Android解码器创建成功" << std::endl;
        return codec;
    }

    bool encodeFrameAndroid(void* encoder_handle,
                           const uint8_t* input_data,
                           size_t input_size,
                           uint8_t** output_data,
                           size_t* output_size,
                           bool* is_keyframe) {
        AMediaCodec* codec = static_cast<AMediaCodec*>(encoder_handle);
        
        // 获取输入缓冲区
        ssize_t input_index = AMediaCodec_dequeueInputBuffer(codec, 10000);
        if (input_index < 0) {
            last_error_ = "获取输入缓冲区失败";
            return false;
        }
        
        size_t buffer_size;
        uint8_t* buffer = AMediaCodec_getInputBuffer(codec, input_index, &buffer_size);
        if (!buffer || buffer_size < input_size) {
            last_error_ = "输入缓冲区大小不足";
            return false;
        }
        
        std::memcpy(buffer, input_data, input_size);
        
        media_status_t status = AMediaCodec_queueInputBuffer(codec, input_index, 0, 
                                                             input_size, 0, 0);
        if (status != AMEDIA_OK) {
            last_error_ = "提交输入缓冲区失败";
            return false;
        }
        
        // 获取输出缓冲区
        AMediaCodecBufferInfo info;
        ssize_t output_index = AMediaCodec_dequeueOutputBuffer(codec, &info, 10000);
        if (output_index < 0) {
            last_error_ = "获取输出缓冲区失败";
            return false;
        }
        
        *output_data = AMediaCodec_getOutputBuffer(codec, output_index, output_size);
        *output_size = info.size;
        *is_keyframe = (info.flags & AMEDIACODEC_BUFFER_FLAG_KEY_FRAME) != 0;
        
        AMediaCodec_releaseOutputBuffer(codec, output_index, false);
        
        return true;
    }

    bool decodeFrameAndroid(void* decoder_handle,
                           const uint8_t* input_data,
                           size_t input_size,
                           uint8_t** output_data,
                           size_t* output_size) {
        AMediaCodec* codec = static_cast<AMediaCodec*>(decoder_handle);
        
        // 获取输入缓冲区
        ssize_t input_index = AMediaCodec_dequeueInputBuffer(codec, 10000);
        if (input_index < 0) {
            last_error_ = "获取输入缓冲区失败";
            return false;
        }
        
        size_t buffer_size;
        uint8_t* buffer = AMediaCodec_getInputBuffer(codec, input_index, &buffer_size);
        if (!buffer || buffer_size < input_size) {
            last_error_ = "输入缓冲区大小不足";
            return false;
        }
        
        std::memcpy(buffer, input_data, input_size);
        
        media_status_t status = AMediaCodec_queueInputBuffer(codec, input_index, 0,
                                                             input_size, 0, 0);
        if (status != AMEDIA_OK) {
            last_error_ = "提交输入缓冲区失败";
            return false;
        }
        
        // 获取输出缓冲区
        AMediaCodecBufferInfo info;
        ssize_t output_index = AMediaCodec_dequeueOutputBuffer(codec, &info, 10000);
        if (output_index < 0) {
            last_error_ = "获取输出缓冲区失败";
            return false;
        }
        
        *output_data = AMediaCodec_getOutputBuffer(codec, output_index, output_size);
        *output_size = info.size;
        
        AMediaCodec_releaseOutputBuffer(codec, output_index, false);
        
        return true;
    }
#endif

#if defined(__APPLE__) && TARGET_OS_IOS
    void* createIOSEncoder(const HardwareEncoderConfig& config) {
        VTCompressionSessionRef session = nullptr;
        
        // 创建压缩会话
        OSStatus status = VTCompressionSessionCreate(
            kCFAllocatorDefault,
            config.width,
            config.height,
            kCMVideoCodecType_HEVC,
            nullptr,
            nullptr,
            nullptr,
            nullptr,
            nullptr,
            &session
        );
        
        if (status != noErr || !session) {
            last_error_ = "创建iOS编码器失败";
            return nullptr;
        }
        
        // 设置属性
        VTSessionSetProperty(session, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(session, kVTCompressionPropertyKey_ProfileLevel,
                           kVTProfileLevel_HEVC_Main_AutoLevel);
        
        CFNumberRef bitrate_num = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, 
                                                &config.bitrate);
        VTSessionSetProperty(session, kVTCompressionPropertyKey_AverageBitRate, bitrate_num);
        CFRelease(bitrate_num);
        
        CFNumberRef fps_num = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, 
                                            &config.fps);
        VTSessionSetProperty(session, kVTCompressionPropertyKey_ExpectedFrameRate, fps_num);
        CFRelease(fps_num);
        
        VTCompressionSessionPrepareToEncodeFrames(session);
        
        std::cout << "[HardwareAccelerator] iOS编码器创建成功" << std::endl;
        return session;
    }

    void* createIOSDecoder(const HardwareDecoderConfig& config) {
        // iOS解码器创建（使用VTDecompressionSession）
        // 实际实现需要更多配置
        std::cout << "[HardwareAccelerator] iOS解码器创建" << std::endl;
        return nullptr; // 简化实现
    }

    bool encodeFrameIOS(void* encoder_handle,
                       const uint8_t* input_data,
                       size_t input_size,
                       uint8_t** output_data,
                       size_t* output_size,
                       bool* is_keyframe) {
        // iOS编码实现
        // 需要将YUV数据转换为CVPixelBuffer，然后调用VTCompressionSessionEncodeFrame
        return false; // 简化实现
    }

    bool decodeFrameIOS(void* decoder_handle,
                       const uint8_t* input_data,
                       size_t input_size,
                       uint8_t** output_data,
                       size_t* output_size) {
        // iOS解码实现
        return false; // 简化实现
    }
#endif

    std::string getAcceleratorTypeName(AcceleratorType type) const {
        switch (type) {
            case AcceleratorType::ANDROID_MEDIACODEC: return "Android MediaCodec";
            case AcceleratorType::IOS_VIDEOTOOLBOX: return "iOS VideoToolbox";
            case AcceleratorType::LINUX_VAAPI: return "Linux VA-API";
            case AcceleratorType::WINDOWS_D3D11: return "Windows D3D11";
            default: return "None";
        }
    }

    AcceleratorType accelerator_type_;
    std::string last_error_;
};

// HardwareAccelerator公共接口实现
HardwareAccelerator::HardwareAccelerator() : impl_(std::make_unique<Impl>()) {}
HardwareAccelerator::~HardwareAccelerator() = default;

bool HardwareAccelerator::initialize() {
    return impl_->initialize();
}

AcceleratorType HardwareAccelerator::detectAcceleratorType() const {
    return impl_->detectAcceleratorType();
}

AcceleratorCapability HardwareAccelerator::queryCapability(AcceleratorType type) const {
    return impl_->queryCapability(type);
}

void* HardwareAccelerator::createHardwareEncoder(const HardwareEncoderConfig& config) {
    return impl_->createHardwareEncoder(config);
}

void* HardwareAccelerator::createHardwareDecoder(const HardwareDecoderConfig& config) {
    return impl_->createHardwareDecoder(config);
}

bool HardwareAccelerator::encodeFrame(void* encoder_handle,
                                     const uint8_t* input_data,
                                     size_t input_size,
                                     uint8_t** output_data,
                                     size_t* output_size,
                                     bool* is_keyframe) {
    return impl_->encodeFrame(encoder_handle, input_data, input_size,
                             output_data, output_size, is_keyframe);
}

bool HardwareAccelerator::decodeFrame(void* decoder_handle,
                                     const uint8_t* input_data,
                                     size_t input_size,
                                     uint8_t** output_data,
                                     size_t* output_size) {
    return impl_->decodeFrame(decoder_handle, input_data, input_size,
                             output_data, output_size);
}

void HardwareAccelerator::releaseHardwareEncoder(void* encoder_handle) {
    impl_->releaseHardwareEncoder(encoder_handle);
}

void HardwareAccelerator::releaseHardwareDecoder(void* decoder_handle) {
    impl_->releaseHardwareDecoder(decoder_handle);
}

bool HardwareAccelerator::isSupported() const {
    return impl_->isSupported();
}

std::string HardwareAccelerator::getLastError() const {
    return impl_->getLastError();
}

void HardwareAccelerator::release() {
    impl_->release();
}

} // namespace av
} // namespace linkme
