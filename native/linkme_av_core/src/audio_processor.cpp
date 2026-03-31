// native/linkme_av_core/src/audio_processor.cpp
// 作用：音频处理器实现
// 功能：音频编解码、回声消除、降噪、自动增益

#include "audio_processor.h"
#include <cstring>
#include <iostream>
#include <algorithm>

namespace linkme {
namespace av {

class AudioProcessor::Impl {
public:
    Impl() : state_(AudioProcessorState::UNINITIALIZED),
             volume_(1.0f),
             aec_enabled_(true),
             ns_enabled_(true),
             agc_enabled_(true) {}

    ~Impl() {
        release();
    }

    bool initialize(const AudioProcessorConfig& config) {
        config_ = config;
        
        // 初始化音频处理模块
        // 实际项目中应该使用WebRTC的音频处理模块或其他专业库
        
        aec_enabled_ = config.enable_aec;
        ns_enabled_ = config.enable_ns;
        agc_enabled_ = config.enable_agc;
        
        state_ = AudioProcessorState::INITIALIZED;
        std::cout << "[AudioProcessor] 音频处理器初始化成功" << std::endl;
        std::cout << "[AudioProcessor] 采样率: " << config.sample_rate 
                  << ", 声道数: " << config.channels << std::endl;
        
        return true;
    }

    bool process(const AudioFrame& input_frame, AudioFrame& output_frame) {
        if (state_ != AudioProcessorState::INITIALIZED && 
            state_ != AudioProcessorState::PROCESSING) {
            std::cerr << "[AudioProcessor] 处理器未初始化" << std::endl;
            return false;
        }
        
        state_ = AudioProcessorState::PROCESSING;
        
        // 拷贝输入到输出
        output_frame = input_frame;
        output_frame.data = input_frame.data;
        
        // 应用音量
        applyVolume(output_frame);
        
        // 回声消除
        if (aec_enabled_) {
            applyAEC(output_frame);
        }
        
        // 降噪
        if (ns_enabled_) {
            applyNS(output_frame);
        }
        
        // 自动增益
        if (agc_enabled_) {
            applyAGC(output_frame);
        }
        
        if (process_callback_) {
            process_callback_(output_frame);
        }
        
        return true;
    }

    bool encode(const AudioFrame& pcm_frame, AudioFrame& encoded_frame) {
        // 音频编码（PCM -> Opus/AAC）
        // 实际项目中应该使用libopus或fdk-aac
        
        encoded_frame.timestamp = pcm_frame.timestamp;
        encoded_frame.sample_rate = pcm_frame.sample_rate;
        encoded_frame.channels = pcm_frame.channels;
        encoded_frame.samples = pcm_frame.samples;
        encoded_frame.format = config_.format;
        
        if (config_.format == AudioFormat::OPUS) {
            // Opus编码
            // 这里应该调用libopus的编码函数
            encoded_frame.data = pcm_frame.data; // 暂时直接拷贝
            std::cout << "[AudioProcessor] Opus编码" << std::endl;
        } else if (config_.format == AudioFormat::AAC) {
            // AAC编码
            // 这里应该调用fdk-aac的编码函数
            encoded_frame.data = pcm_frame.data; // 暂时直接拷贝
            std::cout << "[AudioProcessor] AAC编码" << std::endl;
        } else {
            encoded_frame.data = pcm_frame.data;
        }
        
        return true;
    }

    bool decode(const AudioFrame& encoded_frame, AudioFrame& pcm_frame) {
        // 音频解码（Opus/AAC -> PCM）
        // 实际项目中应该使用libopus或fdk-aac
        
        pcm_frame.timestamp = encoded_frame.timestamp;
        pcm_frame.sample_rate = encoded_frame.sample_rate;
        pcm_frame.channels = encoded_frame.channels;
        pcm_frame.samples = encoded_frame.samples;
        pcm_frame.format = AudioFormat::PCM_S16LE;
        
        if (encoded_frame.format == AudioFormat::OPUS) {
            // Opus解码
            pcm_frame.data = encoded_frame.data; // 暂时直接拷贝
            std::cout << "[AudioProcessor] Opus解码" << std::endl;
        } else if (encoded_frame.format == AudioFormat::AAC) {
            // AAC解码
            pcm_frame.data = encoded_frame.data; // 暂时直接拷贝
            std::cout << "[AudioProcessor] AAC解码" << std::endl;
        } else {
            pcm_frame.data = encoded_frame.data;
        }
        
        return true;
    }

    void setVolume(float volume) {
        volume_ = std::max(0.0f, std::min(2.0f, volume));
        std::cout << "[AudioProcessor] 音量设置为: " << volume_ << std::endl;
    }

    float getVolume() const {
        return volume_;
    }

    void setAECEnabled(bool enabled) {
        aec_enabled_ = enabled;
        std::cout << "[AudioProcessor] 回声消除: " << (enabled ? "启用" : "禁用") << std::endl;
    }

    void setNSEnabled(bool enabled) {
        ns_enabled_ = enabled;
        std::cout << "[AudioProcessor] 降噪: " << (enabled ? "启用" : "禁用") << std::endl;
    }

    void setAGCEnabled(bool enabled) {
        agc_enabled_ = enabled;
        std::cout << "[AudioProcessor] 自动增益: " << (enabled ? "启用" : "禁用") << std::endl;
    }

    AudioProcessorState getState() const {
        return state_;
    }

    std::string getProcessorInfo() const {
        return "LinkMe Audio Processor v1.0";
    }

    void reset() {
        state_ = AudioProcessorState::INITIALIZED;
        std::cout << "[AudioProcessor] 处理器已重置" << std::endl;
    }

    void release() {
        // 释放音频处理资源
        state_ = AudioProcessorState::UNINITIALIZED;
        std::cout << "[AudioProcessor] 处理器已释放" << std::endl;
    }

    void setProcessCallback(std::function<void(const AudioFrame&)> callback) {
        process_callback_ = callback;
    }

private:
    void applyVolume(AudioFrame& frame) {
        if (volume_ == 1.0f) return;
        
        // 应用音量（假设是16位PCM）
        if (frame.format == AudioFormat::PCM_S16LE) {
            int16_t* samples = reinterpret_cast<int16_t*>(frame.data.data());
            size_t sample_count = frame.data.size() / sizeof(int16_t);
            
            for (size_t i = 0; i < sample_count; i++) {
                float sample = samples[i] * volume_;
                samples[i] = static_cast<int16_t>(
                    std::max(-32768.0f, std::min(32767.0f, sample)));
            }
        }
    }

    void applyAEC(AudioFrame& frame) {
        // 回声消除实现
        // 实际项目中应该使用WebRTC的AEC模块
        // 这里仅作为占位符
    }

    void applyNS(AudioFrame& frame) {
        // 降噪实现
        // 实际项目中应该使用WebRTC的NS模块
        // 这里仅作为占位符
    }

    void applyAGC(AudioFrame& frame) {
        // 自动增益实现
        // 实际项目中应该使用WebRTC的AGC模块
        // 这里仅作为占位符
    }

    AudioProcessorConfig config_;
    AudioProcessorState state_;
    float volume_;
    bool aec_enabled_;
    bool ns_enabled_;
    bool agc_enabled_;
    std::function<void(const AudioFrame&)> process_callback_;
};

// AudioProcessor公共接口实现
AudioProcessor::AudioProcessor() : impl_(std::make_unique<Impl>()) {}
AudioProcessor::~AudioProcessor() = default;

bool AudioProcessor::initialize(const AudioProcessorConfig& config) {
    return impl_->initialize(config);
}

bool AudioProcessor::process(const AudioFrame& input_frame, AudioFrame& output_frame) {
    return impl_->process(input_frame, output_frame);
}

bool AudioProcessor::encode(const AudioFrame& pcm_frame, AudioFrame& encoded_frame) {
    return impl_->encode(pcm_frame, encoded_frame);
}

bool AudioProcessor::decode(const AudioFrame& encoded_frame, AudioFrame& pcm_frame) {
    return impl_->decode(encoded_frame, pcm_frame);
}

void AudioProcessor::setVolume(float volume) {
    impl_->setVolume(volume);
}

float AudioProcessor::getVolume() const {
    return impl_->getVolume();
}

void AudioProcessor::setAECEnabled(bool enabled) {
    impl_->setAECEnabled(enabled);
}

void AudioProcessor::setNSEnabled(bool enabled) {
    impl_->setNSEnabled(enabled);
}

void AudioProcessor::setAGCEnabled(bool enabled) {
    impl_->setAGCEnabled(enabled);
}

AudioProcessorState AudioProcessor::getState() const {
    return impl_->getState();
}

std::string AudioProcessor::getProcessorInfo() const {
    return impl_->getProcessorInfo();
}

void AudioProcessor::reset() {
    impl_->reset();
}

void AudioProcessor::release() {
    impl_->release();
}

void AudioProcessor::setProcessCallback(std::function<void(const AudioFrame&)> callback) {
    impl_->setProcessCallback(callback);
}

} // namespace av
} // namespace linkme
