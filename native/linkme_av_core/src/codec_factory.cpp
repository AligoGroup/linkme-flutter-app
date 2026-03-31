// native/linkme_av_core/src/codec_factory.cpp
// 作用：编解码器工厂实现
// 功能：统一创建和管理编解码器

#include "codec_factory.h"
#include "hardware_accelerator.h"
#include <iostream>
#include <map>

namespace linkme {
namespace av {

class CodecFactory::Impl {
public:
    Impl() {
        // 初始化硬件加速器
        hw_accelerator_ = std::make_unique<HardwareAccelerator>();
        hw_accelerator_->initialize();
        
        // 检测硬件加速能力
        detectCapabilities();
    }

    ~Impl() = default;

    std::unique_ptr<VideoEncoder> createVideoEncoder(const VideoEncoderConfig& config) {
        auto encoder = std::make_unique<VideoEncoder>();
        
        if (!encoder->initialize(config)) {
            std::cerr << "[CodecFactory] 创建视频编码器失败" << std::endl;
            return nullptr;
        }
        
        std::cout << "[CodecFactory] 视频编码器创建成功: " 
                  << encoder->getEncoderInfo() << std::endl;
        
        return encoder;
    }

    std::unique_ptr<VideoDecoder> createVideoDecoder(const VideoDecoderConfig& config) {
        auto decoder = std::make_unique<VideoDecoder>();
        
        if (!decoder->initialize(config)) {
            std::cerr << "[CodecFactory] 创建视频解码器失败" << std::endl;
            return nullptr;
        }
        
        std::cout << "[CodecFactory] 视频解码器创建成功: " 
                  << decoder->getDecoderInfo() << std::endl;
        
        return decoder;
    }

    std::unique_ptr<AudioProcessor> createAudioProcessor(const AudioProcessorConfig& config) {
        auto processor = std::make_unique<AudioProcessor>();
        
        if (!processor->initialize(config)) {
            std::cerr << "[CodecFactory] 创建音频处理器失败" << std::endl;
            return nullptr;
        }
        
        std::cout << "[CodecFactory] 音频处理器创建成功: " 
                  << processor->getProcessorInfo() << std::endl;
        
        return processor;
    }

    CodecCapability queryCapability(CodecType type) const {
        auto it = capabilities_.find(type);
        if (it != capabilities_.end()) {
            return it->second;
        }
        
        // 返回默认能力
        CodecCapability cap;
        cap.type = type;
        cap.hardware_supported = false;
        return cap;
    }

    std::vector<CodecType> getSupportedCodecs() const {
        std::vector<CodecType> codecs;
        for (const auto& pair : capabilities_) {
            codecs.push_back(pair.first);
        }
        return codecs;
    }

    bool isHardwareAccelerated(CodecType type) const {
        auto it = capabilities_.find(type);
        return it != capabilities_.end() && it->second.hardware_supported;
    }

    VideoEncoderConfig getRecommendedEncoderConfig(int width, int height, int fps) const {
        VideoEncoderConfig config;
        config.width = width;
        config.height = height;
        config.fps = fps;
        
        // 根据分辨率推荐码率
        int pixels = width * height;
        if (pixels >= 2560 * 1440) {
            // 2K
            config.bitrate = 8000000; // 8Mbps
            config.quality_preset = 2;
        } else if (pixels >= 1920 * 1080) {
            // 1080p
            config.bitrate = 4000000; // 4Mbps
            config.quality_preset = 3;
        } else if (pixels >= 1280 * 720) {
            // 720p
            config.bitrate = 2000000; // 2Mbps
            config.quality_preset = 3;
        } else {
            // 低分辨率
            config.bitrate = 1000000; // 1Mbps
            config.quality_preset = 4;
        }
        
        config.keyframe_interval = fps * 2; // 2秒一个关键帧
        config.threads = 4;
        config.use_hardware = isHardwareAccelerated(CodecType::H265_ENCODER);
        
        return config;
    }

    VideoDecoderConfig getRecommendedDecoderConfig(int max_width, int max_height) const {
        VideoDecoderConfig config;
        config.max_width = max_width;
        config.max_height = max_height;
        config.threads = 4;
        config.use_hardware = isHardwareAccelerated(CodecType::H265_DECODER);
        config.buffer_size = 5;
        
        return config;
    }

    AudioProcessorConfig getRecommendedAudioConfig(int sample_rate, int channels) const {
        AudioProcessorConfig config;
        config.sample_rate = sample_rate;
        config.channels = channels;
        config.bits_per_sample = 16;
        config.format = AudioFormat::OPUS; // 推荐使用Opus
        config.enable_aec = true;
        config.enable_ns = true;
        config.enable_agc = true;
        config.bitrate = 128000; // 128kbps
        
        return config;
    }

    void warmup() {
        std::cout << "[CodecFactory] 预热编解码器..." << std::endl;
        
        // 创建并立即释放编解码器以预热
        auto encoder_config = getRecommendedEncoderConfig(1280, 720, 30);
        auto encoder = createVideoEncoder(encoder_config);
        
        auto decoder_config = getRecommendedDecoderConfig(2560, 1440);
        auto decoder = createVideoDecoder(decoder_config);
        
        auto audio_config = getRecommendedAudioConfig(48000, 2);
        auto processor = createAudioProcessor(audio_config);
        
        std::cout << "[CodecFactory] 预热完成" << std::endl;
    }

    void release() {
        capabilities_.clear();
        hw_accelerator_.reset();
        std::cout << "[CodecFactory] 资源已释放" << std::endl;
    }

private:
    void detectCapabilities() {
        // H.265编码器能力
        CodecCapability h265_encoder;
        h265_encoder.type = CodecType::H265_ENCODER;
        h265_encoder.name = "H.265/HEVC Encoder";
        h265_encoder.hardware_supported = hw_accelerator_->isSupported();
        h265_encoder.max_width = 3840;
        h265_encoder.max_height = 2160;
        h265_encoder.max_fps = 60;
        h265_encoder.max_bitrate = 20000000;
        h265_encoder.profiles = {"main", "main10"};
        capabilities_[CodecType::H265_ENCODER] = h265_encoder;
        
        // H.265解码器能力
        CodecCapability h265_decoder;
        h265_decoder.type = CodecType::H265_DECODER;
        h265_decoder.name = "H.265/HEVC Decoder";
        h265_decoder.hardware_supported = hw_accelerator_->isSupported();
        h265_decoder.max_width = 3840;
        h265_decoder.max_height = 2160;
        h265_decoder.max_fps = 60;
        h265_decoder.max_bitrate = 20000000;
        h265_decoder.profiles = {"main", "main10"};
        capabilities_[CodecType::H265_DECODER] = h265_decoder;
        
        // Opus编码器能力
        CodecCapability opus_encoder;
        opus_encoder.type = CodecType::OPUS_ENCODER;
        opus_encoder.name = "Opus Audio Encoder";
        opus_encoder.hardware_supported = false;
        opus_encoder.max_bitrate = 510000;
        capabilities_[CodecType::OPUS_ENCODER] = opus_encoder;
        
        // Opus解码器能力
        CodecCapability opus_decoder;
        opus_decoder.type = CodecType::OPUS_DECODER;
        opus_decoder.name = "Opus Audio Decoder";
        opus_decoder.hardware_supported = false;
        opus_decoder.max_bitrate = 510000;
        capabilities_[CodecType::OPUS_DECODER] = opus_decoder;
        
        std::cout << "[CodecFactory] 编解码器能力检测完成" << std::endl;
        std::cout << "[CodecFactory] H.265硬件加速: " 
                  << (h265_encoder.hardware_supported ? "支持" : "不支持") << std::endl;
    }

    std::map<CodecType, CodecCapability> capabilities_;
    std::unique_ptr<HardwareAccelerator> hw_accelerator_;
};

// CodecFactory单例实现
CodecFactory& CodecFactory::getInstance() {
    static CodecFactory instance;
    return instance;
}

CodecFactory::CodecFactory() : impl_(std::make_unique<Impl>()) {}
CodecFactory::~CodecFactory() = default;

std::unique_ptr<VideoEncoder> CodecFactory::createVideoEncoder(const VideoEncoderConfig& config) {
    return impl_->createVideoEncoder(config);
}

std::unique_ptr<VideoDecoder> CodecFactory::createVideoDecoder(const VideoDecoderConfig& config) {
    return impl_->createVideoDecoder(config);
}

std::unique_ptr<AudioProcessor> CodecFactory::createAudioProcessor(const AudioProcessorConfig& config) {
    return impl_->createAudioProcessor(config);
}

CodecCapability CodecFactory::queryCapability(CodecType type) const {
    return impl_->queryCapability(type);
}

std::vector<CodecType> CodecFactory::getSupportedCodecs() const {
    return impl_->getSupportedCodecs();
}

bool CodecFactory::isHardwareAccelerated(CodecType type) const {
    return impl_->isHardwareAccelerated(type);
}

VideoEncoderConfig CodecFactory::getRecommendedEncoderConfig(int width, int height, int fps) const {
    return impl_->getRecommendedEncoderConfig(width, height, fps);
}

VideoDecoderConfig CodecFactory::getRecommendedDecoderConfig(int max_width, int max_height) const {
    return impl_->getRecommendedDecoderConfig(max_width, max_height);
}

AudioProcessorConfig CodecFactory::getRecommendedAudioConfig(int sample_rate, int channels) const {
    return impl_->getRecommendedAudioConfig(sample_rate, channels);
}

void CodecFactory::warmup() {
    impl_->warmup();
}

void CodecFactory::release() {
    impl_->release();
}

} // namespace av
} // namespace linkme
