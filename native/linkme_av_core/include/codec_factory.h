// native/linkme_av_core/include/codec_factory.h
// 作用：编解码器工厂头文件，统一创建和管理编解码器
// 功能：编解码器创建、能力查询、资源池管理

#ifndef LINKME_CODEC_FACTORY_H
#define LINKME_CODEC_FACTORY_H

#include <memory>
#include <string>
#include <vector>
#include "video_encoder.h"
#include "video_decoder.h"
#include "audio_processor.h"

namespace linkme {
namespace av {

/// 编解码器类型
enum class CodecType {
    H265_ENCODER,                  // H.265编码器
    H265_DECODER,                  // H.265解码器
    OPUS_ENCODER,                  // Opus编码器
    OPUS_DECODER,                  // Opus解码器
    AAC_ENCODER,                   // AAC编码器
    AAC_DECODER                    // AAC解码器
};

/// 编解码器能力
struct CodecCapability {
    CodecType type;                // 编解码器类型
    std::string name;              // 名称
    bool hardware_supported;       // 是否支持硬件加速
    int max_width;                 // 最大宽度（视频）
    int max_height;                // 最大高度（视频）
    int max_fps;                   // 最大帧率（视频）
    int max_bitrate;               // 最大码率
    std::vector<std::string> profiles; // 支持的配置文件
};

/// 编解码器工厂
class CodecFactory {
public:
    /// 获取单例实例
    static CodecFactory& getInstance();

    /// 创建视频编码器
    /// @param config 编码器配置
    /// @return 编码器实例
    std::unique_ptr<VideoEncoder> createVideoEncoder(const VideoEncoderConfig& config);

    /// 创建视频解码器
    /// @param config 解码器配置
    /// @return 解码器实例
    std::unique_ptr<VideoDecoder> createVideoDecoder(const VideoDecoderConfig& config);

    /// 创建音频处理器
    /// @param config 处理器配置
    /// @return 处理器实例
    std::unique_ptr<AudioProcessor> createAudioProcessor(const AudioProcessorConfig& config);

    /// 查询编解码器能力
    /// @param type 编解码器类型
    /// @return 能力信息
    CodecCapability queryCapability(CodecType type) const;

    /// 获取所有支持的编解码器
    /// @return 编解码器类型列表
    std::vector<CodecType> getSupportedCodecs() const;

    /// 检查是否支持硬件加速
    /// @param type 编解码器类型
    /// @return 是否支持
    bool isHardwareAccelerated(CodecType type) const;

    /// 获取推荐的编码器配置
    /// @param width 视频宽度
    /// @param height 视频高度
    /// @param fps 帧率
    /// @return 推荐配置
    VideoEncoderConfig getRecommendedEncoderConfig(int width, int height, int fps) const;

    /// 获取推荐的解码器配置
    /// @param max_width 最大宽度
    /// @param max_height 最大高度
    /// @return 推荐配置
    VideoDecoderConfig getRecommendedDecoderConfig(int max_width, int max_height) const;

    /// 获取推荐的音频处理器配置
    /// @param sample_rate 采样率
    /// @param channels 声道数
    /// @return 推荐配置
    AudioProcessorConfig getRecommendedAudioConfig(int sample_rate, int channels) const;

    /// 预热编解码器（提前初始化以减少首帧延迟）
    void warmup();

    /// 释放所有资源
    void release();

private:
    CodecFactory();
    ~CodecFactory();

    class Impl;
    std::unique_ptr<Impl> impl_;

    // 禁止拷贝
    CodecFactory(const CodecFactory&) = delete;
    CodecFactory& operator=(const CodecFactory&) = delete;
};

} // namespace av
} // namespace linkme

#endif // LINKME_CODEC_FACTORY_H
