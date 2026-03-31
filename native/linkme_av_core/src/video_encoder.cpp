// native/linkme_av_core/src/video_encoder.cpp
// 作用：H.265视频编码器实现
// 功能：使用x265库进行H.265编码，支持硬件加速

#include "video_encoder.h"
#include "hardware_accelerator.h"
#ifndef LINKME_WITHOUT_X265
#include <x265.h>
#endif
#include <cstring>
#include <iostream>

namespace linkme {
namespace av {

class VideoEncoder::Impl {
public:
    Impl() : state_(EncoderState::UNINITIALIZED),
             encoder_(nullptr),
             param_(nullptr),
             picture_(nullptr),
             api_(nullptr),
             use_hardware_(false),
             hw_accelerator_(nullptr),
             hw_encoder_handle_(nullptr),
             frame_count_(0),
             force_keyframe_(false) {}

    ~Impl() {
        release();
    }

    bool initialize(const VideoEncoderConfig& config) {
        config_ = config;
        
        // 尝试使用硬件加速
        if (config.use_hardware) {
            hw_accelerator_ = std::make_unique<HardwareAccelerator>();
            if (hw_accelerator_->initialize() && hw_accelerator_->isSupported()) {
                HardwareEncoderConfig hw_config;
                hw_config.width = config.width;
                hw_config.height = config.height;
                hw_config.fps = config.fps;
                hw_config.bitrate = config.bitrate;
                hw_config.keyframe_interval = config.keyframe_interval;
                hw_config.quality = 80;
                
                hw_encoder_handle_ = hw_accelerator_->createHardwareEncoder(hw_config);
                if (hw_encoder_handle_ != nullptr) {
                    use_hardware_ = true;
                    state_ = EncoderState::INITIALIZED;
                    std::cout << "[VideoEncoder] 硬件加速编码器初始化成功" << std::endl;
                    return true;
                }
            }
        }
        
        // 回退到软件编码
        return initializeSoftwareEncoder();
    }

    bool initializeSoftwareEncoder() {
#ifdef LINKME_WITHOUT_X265
        std::cerr << "[VideoEncoder] x265 已关闭（LINKME_WITHOUT_X265），软件编码不可用" << std::endl;
        return false;
#else
        // 部分 Android 预编译 libx265.a 不导出 x265_encoder_open 等 C 符号，仅提供 x265_api_get
        api_ = x265_api_get(8);
        if (!api_) {
            std::cerr << "[VideoEncoder] x265_api_get(8) 失败" << std::endl;
            return false;
        }

        param_ = api_->param_alloc();
        if (!param_) {
            std::cerr << "[VideoEncoder] 分配参数失败" << std::endl;
            return false;
        }

        // 设置预设
        const char* preset = "medium";
        if (config_.quality_preset == 0) preset = "ultrafast";
        else if (config_.quality_preset == 1) preset = "superfast";
        else if (config_.quality_preset == 2) preset = "veryfast";
        else if (config_.quality_preset == 3) preset = "faster";
        else if (config_.quality_preset == 4) preset = "fast";
        else if (config_.quality_preset == 5) preset = "medium";
        
        if (api_->param_default_preset(param_, preset, "zerolatency") < 0) {
            std::cerr << "[VideoEncoder] 设置预设失败" << std::endl;
            api_->param_free(param_);
            param_ = nullptr;
            return false;
        }
        
        // 配置参数
        param_->sourceWidth = config_.width;
        param_->sourceHeight = config_.height;
        param_->fpsNum = config_.fps;
        param_->fpsDenom = 1;
        param_->internalCsp = X265_CSP_I420;
        param_->bRepeatHeaders = 1;
        param_->bAnnexB = 1;
        
        // 码率控制
        param_->rc.rateControlMode = X265_RC_ABR;
        param_->rc.bitrate = config_.bitrate / 1000; // kbps
        param_->rc.vbvMaxBitrate = config_.bitrate / 1000;
        param_->rc.vbvBufferSize = config_.bitrate / 1000;
        
        // 关键帧间隔
        param_->keyframeMax = config_.keyframe_interval;
        param_->keyframeMin = 1;
        
        // 线程数
        param_->poolNumThreads = config_.threads;
        
        // 低延迟优化
        param_->bFrameAdaptive = 0;
        param_->bframes = 0;
        param_->scenecutThreshold = 0;
        param_->lookaheadDepth = 0;
        
        // 应用配置
        if (api_->param_apply_profile(param_, "main") < 0) {
            std::cerr << "[VideoEncoder] 应用配置失败" << std::endl;
            api_->param_free(param_);
            param_ = nullptr;
            return false;
        }
        
        // 创建编码器
        encoder_ = api_->encoder_open(param_);
        if (!encoder_) {
            std::cerr << "[VideoEncoder] 创建编码器失败" << std::endl;
            api_->param_free(param_);
            param_ = nullptr;
            return false;
        }
        
        // 分配图像
        picture_ = api_->picture_alloc();
        if (!picture_) {
            std::cerr << "[VideoEncoder] 分配图像失败" << std::endl;
            api_->encoder_close(encoder_);
            api_->param_free(param_);
            encoder_ = nullptr;
            param_ = nullptr;
            return false;
        }
        
        api_->picture_init(param_, picture_);
        
        state_ = EncoderState::INITIALIZED;
        std::cout << "[VideoEncoder] 软件编码器初始化成功" << std::endl;
        return true;
#endif
    }

    bool encode(const RawVideoFrame& frame, EncodedFrame& encoded_frame) {
        if (state_ != EncoderState::INITIALIZED && state_ != EncoderState::ENCODING) {
            std::cerr << "[VideoEncoder] 编码器未初始化" << std::endl;
            return false;
        }
        
        state_ = EncoderState::ENCODING;
        
        if (use_hardware_) {
            return encodeHardware(frame, encoded_frame);
        } else {
            return encodeSoftware(frame, encoded_frame);
        }
    }

    bool encodeHardware(const RawVideoFrame& frame, EncodedFrame& encoded_frame) {
        // 准备输入数据（YUV420）
        size_t y_size = frame.width * frame.height;
        size_t uv_size = y_size / 4;
        size_t total_size = y_size + uv_size * 2;
        
        std::vector<uint8_t> input_data(total_size);
        std::memcpy(input_data.data(), frame.y_plane, y_size);
        std::memcpy(input_data.data() + y_size, frame.u_plane, uv_size);
        std::memcpy(input_data.data() + y_size + uv_size, frame.v_plane, uv_size);
        
        // 硬件编码
        uint8_t* output_data = nullptr;
        size_t output_size = 0;
        bool is_keyframe = false;
        
        if (!hw_accelerator_->encodeFrame(hw_encoder_handle_,
                                          input_data.data(),
                                          input_data.size(),
                                          &output_data,
                                          &output_size,
                                          &is_keyframe)) {
            std::cerr << "[VideoEncoder] 硬件编码失败" << std::endl;
            return false;
        }
        
        // 填充输出
        encoded_frame.data.assign(output_data, output_data + output_size);
        encoded_frame.timestamp = frame.timestamp;
        encoded_frame.is_keyframe = is_keyframe;
        encoded_frame.width = frame.width;
        encoded_frame.height = frame.height;
        
        frame_count_++;
        return true;
    }

    bool encodeSoftware(const RawVideoFrame& frame, EncodedFrame& encoded_frame) {
#ifdef LINKME_WITHOUT_X265
        (void)frame;
        (void)encoded_frame;
        return false;
#else
        if (!api_ || !encoder_) {
            return false;
        }
        // 填充图像数据
        picture_->planes[0] = frame.y_plane;
        picture_->planes[1] = frame.u_plane;
        picture_->planes[2] = frame.v_plane;
        picture_->stride[0] = frame.y_stride;
        picture_->stride[1] = frame.u_stride;
        picture_->stride[2] = frame.v_stride;
        picture_->pts = frame.timestamp;
        
        // 强制关键帧
        if (force_keyframe_) {
            picture_->sliceType = X265_TYPE_IDR;
            force_keyframe_ = false;
        } else {
            picture_->sliceType = X265_TYPE_AUTO;
        }
        
        // 编码
        x265_nal* nals = nullptr;
        uint32_t nal_count = 0;
        int frame_size = api_->encoder_encode(encoder_, &nals, &nal_count, picture_, nullptr);
        
        if (frame_size < 0) {
            std::cerr << "[VideoEncoder] 编码失败" << std::endl;
            return false;
        }
        
        if (frame_size == 0) {
            // 没有输出（延迟帧）
            return false;
        }
        
        // 合并NAL单元
        encoded_frame.data.clear();
        bool is_keyframe = false;
        
        for (uint32_t i = 0; i < nal_count; i++) {
            encoded_frame.data.insert(encoded_frame.data.end(),
                                     nals[i].payload,
                                     nals[i].payload + nals[i].sizeBytes);
            
            if (nals[i].type == NAL_UNIT_CODED_SLICE_IDR_W_RADL ||
                nals[i].type == NAL_UNIT_CODED_SLICE_IDR_N_LP) {
                is_keyframe = true;
            }
        }
        
        encoded_frame.timestamp = frame.timestamp;
        encoded_frame.is_keyframe = is_keyframe;
        encoded_frame.width = frame.width;
        encoded_frame.height = frame.height;
        
        frame_count_++;
        
        if (encode_callback_) {
            encode_callback_(encoded_frame);
        }
        
        return true;
#endif
    }

    void forceKeyFrame() {
        force_keyframe_ = true;
    }

    void updateBitrate(int bitrate) {
        config_.bitrate = bitrate;
        
        if (use_hardware_) {
            // 硬件编码器动态码率调整（平台相关）
            std::cout << "[VideoEncoder] 硬件编码器码率更新: " << bitrate << std::endl;
        }
#ifndef LINKME_WITHOUT_X265
        else if (encoder_ && param_ && api_) {
            param_->rc.bitrate = bitrate / 1000;
            api_->encoder_reconfig(encoder_, param_);
            std::cout << "[VideoEncoder] 软件编码器码率更新: " << bitrate << std::endl;
        }
#endif
    }

    void updateFrameRate(int fps) {
        config_.fps = fps;
        
#ifndef LINKME_WITHOUT_X265
        if (!use_hardware_ && encoder_ && param_ && api_) {
            param_->fpsNum = fps;
            api_->encoder_reconfig(encoder_, param_);
            std::cout << "[VideoEncoder] 帧率更新: " << fps << std::endl;
        }
#endif
    }

    EncoderState getState() const {
        return state_;
    }

    std::string getEncoderInfo() const {
        if (use_hardware_) {
            return "Hardware H.265 Encoder";
        }
#ifdef LINKME_WITHOUT_X265
        return "Software encoder disabled (no x265)";
#else
        return "x265 Software Encoder";
#endif
    }

    void reset() {
        if (use_hardware_) {
            // 硬件编码器重置
            if (hw_accelerator_ && hw_encoder_handle_) {
                hw_accelerator_->releaseHardwareEncoder(hw_encoder_handle_);
                HardwareEncoderConfig hw_config;
                hw_config.width = config_.width;
                hw_config.height = config_.height;
                hw_config.fps = config_.fps;
                hw_config.bitrate = config_.bitrate;
                hw_config.keyframe_interval = config_.keyframe_interval;
                hw_config.quality = 80;
                hw_encoder_handle_ = hw_accelerator_->createHardwareEncoder(hw_config);
            }
        }
#ifndef LINKME_WITHOUT_X265
        else if (encoder_ && api_) {
            api_->encoder_close(encoder_);
            encoder_ = api_->encoder_open(param_);
        }
#endif

        frame_count_ = 0;
        force_keyframe_ = false;
        state_ = EncoderState::INITIALIZED;
    }

    void release() {
        if (use_hardware_) {
            if (hw_accelerator_ && hw_encoder_handle_) {
                hw_accelerator_->releaseHardwareEncoder(hw_encoder_handle_);
                hw_encoder_handle_ = nullptr;
            }
            hw_accelerator_.reset();
        } else {
#ifndef LINKME_WITHOUT_X265
            if (picture_ && api_) {
                api_->picture_free(picture_);
                picture_ = nullptr;
            }

            if (encoder_ && api_) {
                api_->encoder_close(encoder_);
                encoder_ = nullptr;
            }

            if (param_ && api_) {
                api_->param_free(param_);
                param_ = nullptr;
            }
            api_ = nullptr;
#endif
        }
        
        state_ = EncoderState::UNINITIALIZED;
    }

    void setEncodeCallback(std::function<void(const EncodedFrame&)> callback) {
        encode_callback_ = callback;
    }

private:
    VideoEncoderConfig config_;
    EncoderState state_;
    
    // 软件编码（经 x265_api 函数指针，兼容仅导出 x265_api_get 的静态库）
#ifndef LINKME_WITHOUT_X265
    const x265_api* api_;
    x265_encoder* encoder_;
    x265_param* param_;
    x265_picture* picture_;
#else
    void* api_;
    void* encoder_;
    void* param_;
    void* picture_;
#endif
    
    // 硬件编码
    bool use_hardware_;
    std::unique_ptr<HardwareAccelerator> hw_accelerator_;
    void* hw_encoder_handle_;
    
    // 状态
    int64_t frame_count_;
    bool force_keyframe_;
    
    // 回调
    std::function<void(const EncodedFrame&)> encode_callback_;
};

// VideoEncoder公共接口实现
VideoEncoder::VideoEncoder() : impl_(std::make_unique<Impl>()) {}
VideoEncoder::~VideoEncoder() = default;

bool VideoEncoder::initialize(const VideoEncoderConfig& config) {
    return impl_->initialize(config);
}

bool VideoEncoder::encode(const RawVideoFrame& frame, EncodedFrame& encoded_frame) {
    return impl_->encode(frame, encoded_frame);
}

void VideoEncoder::forceKeyFrame() {
    impl_->forceKeyFrame();
}

void VideoEncoder::updateBitrate(int bitrate) {
    impl_->updateBitrate(bitrate);
}

void VideoEncoder::updateFrameRate(int fps) {
    impl_->updateFrameRate(fps);
}

EncoderState VideoEncoder::getState() const {
    return impl_->getState();
}

std::string VideoEncoder::getEncoderInfo() const {
    return impl_->getEncoderInfo();
}

void VideoEncoder::reset() {
    impl_->reset();
}

void VideoEncoder::release() {
    impl_->release();
}

void VideoEncoder::setEncodeCallback(std::function<void(const EncodedFrame&)> callback) {
    impl_->setEncodeCallback(callback);
}

} // namespace av
} // namespace linkme
