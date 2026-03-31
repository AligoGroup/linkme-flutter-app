// native/linkme_av_core/include/audio_processor.h
// 作用：音频处理器头文件，支持回声消除、降噪、自动增益
// 功能：音频编解码、音频增强、音量控制

#ifndef LINKME_AUDIO_PROCESSOR_H
#define LINKME_AUDIO_PROCESSOR_H

#include <cstdint>
#include <memory>
#include <vector>
#include <functional>

namespace linkme {
namespace av {

/// 音频格式
enum class AudioFormat {
    PCM_S16LE,                     // 16位有符号小端PCM
    PCM_F32LE,                     // 32位浮点小端PCM
    OPUS,                          // Opus编码
    AAC                            // AAC编码
};

/// 音频处理配置
struct AudioProcessorConfig {
    int sample_rate = 48000;       // 采样率
    int channels = 2;              // 声道数
    int bits_per_sample = 16;      // 位深度
    AudioFormat format = AudioFormat::PCM_S16LE;
    bool enable_aec = true;        // 启用回声消除
    bool enable_ns = true;         // 启用降噪
    bool enable_agc = true;        // 启用自动增益
    int bitrate = 128000;          // 编码码率（用于Opus/AAC）
};

/// 音频帧
struct AudioFrame {
    std::vector<uint8_t> data;     // 音频数据
    int64_t timestamp;             // 时间戳（微秒）
    int sample_rate;               // 采样率
    int channels;                  // 声道数
    int samples;                   // 采样点数
    AudioFormat format;            // 音频格式
};

/// 音频处理器状态
enum class AudioProcessorState {
    UNINITIALIZED,                 // 未初始化
    INITIALIZED,                   // 已初始化
    PROCESSING,                    // 处理中
    ERROR                          // 错误状态
};

/// 音频处理器
class AudioProcessor {
public:
    AudioProcessor();
    ~AudioProcessor();

    /// 初始化音频处理器
    /// @param config 处理器配置
    /// @return 是否成功
    bool initialize(const AudioProcessorConfig& config);

    /// 处理音频帧（降噪、回声消除等）
    /// @param input_frame 输入音频帧
    /// @param output_frame 输出音频帧
    /// @return 是否成功
    bool process(const AudioFrame& input_frame, AudioFrame& output_frame);

    /// 编码音频（PCM -> Opus/AAC）
    /// @param pcm_frame PCM音频帧
    /// @param encoded_frame 编码后的音频帧
    /// @return 是否成功
    bool encode(const AudioFrame& pcm_frame, AudioFrame& encoded_frame);

    /// 解码音频（Opus/AAC -> PCM）
    /// @param encoded_frame 编码的音频帧
    /// @param pcm_frame PCM音频帧
    /// @return 是否成功
    bool decode(const AudioFrame& encoded_frame, AudioFrame& pcm_frame);

    /// 设置音量
    /// @param volume 音量（0.0 - 2.0，1.0为原始音量）
    void setVolume(float volume);

    /// 获取音量
    float getVolume() const;

    /// 启用/禁用回声消除
    void setAECEnabled(bool enabled);

    /// 启用/禁用降噪
    void setNSEnabled(bool enabled);

    /// 启用/禁用自动增益
    void setAGCEnabled(bool enabled);

    /// 获取处理器状态
    AudioProcessorState getState() const;

    /// 获取处理器信息
    std::string getProcessorInfo() const;

    /// 重置处理器
    void reset();

    /// 释放资源
    void release();

    /// 设置处理回调（异步处理）
    void setProcessCallback(std::function<void(const AudioFrame&)> callback);

private:
    class Impl;
    std::unique_ptr<Impl> impl_;

    // 禁止拷贝
    AudioProcessor(const AudioProcessor&) = delete;
    AudioProcessor& operator=(const AudioProcessor&) = delete;
};

} // namespace av
} // namespace linkme

#endif // LINKME_AUDIO_PROCESSOR_H
