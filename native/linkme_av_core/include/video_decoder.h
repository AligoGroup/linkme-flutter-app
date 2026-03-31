// native/linkme_av_core/include/video_decoder.h
// 作用：H.265视频解码器头文件，支持2K画质解码
// 功能：硬件加速解码、多线程解码、帧缓冲管理

#ifndef LINKME_VIDEO_DECODER_H
#define LINKME_VIDEO_DECODER_H

#include <cstdint>
#include <memory>
#include <vector>
#include <functional>

namespace linkme {
namespace av {

/// 解码器配置
struct VideoDecoderConfig {
    int max_width = 2560;          // 最大宽度
    int max_height = 1440;         // 最大高度
    int threads = 4;               // 解码线程数
    bool use_hardware = true;      // 是否使用硬件加速
    int buffer_size = 5;           // 帧缓冲大小
};

/// 解码后的帧数据
struct DecodedFrame {
    uint8_t* y_plane;              // Y平面数据
    uint8_t* u_plane;              // U平面数据
    uint8_t* v_plane;              // V平面数据
    int y_stride;                  // Y平面步长
    int u_stride;                  // U平面步长
    int v_stride;                  // V平面步长
    int width;                     // 宽度
    int height;                    // 高度
    int64_t timestamp;             // 时间戳（微秒）
    bool is_keyframe;              // 是否为关键帧
};

/// 编码帧数据（输入）
struct EncodedVideoFrame {
    const uint8_t* data;           // 编码数据
    size_t size;                   // 数据大小
    int64_t timestamp;             // 时间戳（微秒）
};

/// 解码器状态
enum class DecoderState {
    UNINITIALIZED,                 // 未初始化
    INITIALIZED,                   // 已初始化
    DECODING,                      // 解码中
    ERROR                          // 错误状态
};

/// H.265视频解码器
class VideoDecoder {
public:
    VideoDecoder();
    ~VideoDecoder();

    /// 初始化解码器
    /// @param config 解码器配置
    /// @return 是否成功
    bool initialize(const VideoDecoderConfig& config);

    /// 解码一帧视频
    /// @param encoded_frame 编码帧数据
    /// @param decoded_frame 解码后的帧（输出）
    /// @return 是否成功
    bool decode(const EncodedVideoFrame& encoded_frame, DecodedFrame& decoded_frame);

    /// 刷新解码器（获取缓冲的帧）
    /// @param decoded_frames 解码后的帧列表（输出）
    /// @return 获取到的帧数量
    int flush(std::vector<DecodedFrame>& decoded_frames);

    /// 获取解码器状态
    DecoderState getState() const;

    /// 获取解码器信息
    std::string getDecoderInfo() const;

    /// 重置解码器
    void reset();

    /// 释放资源
    void release();

    /// 设置解码回调（异步解码）
    void setDecodeCallback(std::function<void(const DecodedFrame&)> callback);

    /// 释放解码帧（由解码器分配的内存）
    void releaseFrame(DecodedFrame& frame);

private:
    class Impl;
    std::unique_ptr<Impl> impl_;

    // 禁止拷贝
    VideoDecoder(const VideoDecoder&) = delete;
    VideoDecoder& operator=(const VideoDecoder&) = delete;
};

} // namespace av
} // namespace linkme

#endif // LINKME_VIDEO_DECODER_H
