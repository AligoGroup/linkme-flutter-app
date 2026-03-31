// native/linkme_av_core/include/video_encoder.h
// 作用：H.265视频编码器头文件，支持2K画质编码
// 功能：硬件加速编码、码率控制、关键帧控制、编码参数配置

#ifndef LINKME_VIDEO_ENCODER_H
#define LINKME_VIDEO_ENCODER_H

#include <cstdint>
#include <memory>
#include <vector>
#include <functional>

namespace linkme {
namespace av {

/// 编码器配置
struct VideoEncoderConfig {
    int width = 2560;              // 宽度（2K）
    int height = 1440;             // 高度（2K）
    int fps = 30;                  // 帧率
    int bitrate = 8000000;         // 码率（8Mbps）
    int keyframe_interval = 60;    // 关键帧间隔
    int threads = 4;               // 编码线程数
    bool use_hardware = true;      // 是否使用硬件加速
    int quality_preset = 2;        // 质量预设（0=最快，5=最慢最高质量）
};

/// 编码后的帧数据
struct EncodedFrame {
    std::vector<uint8_t> data;     // 编码数据
    int64_t timestamp;             // 时间戳（微秒）
    bool is_keyframe;              // 是否为关键帧
    int width;                     // 宽度
    int height;                    // 高度
};

/// 原始视频帧
struct RawVideoFrame {
    uint8_t* y_plane;              // Y平面数据
    uint8_t* u_plane;              // U平面数据
    uint8_t* v_plane;              // V平面数据
    int y_stride;                  // Y平面步长
    int u_stride;                  // U平面步长
    int v_stride;                  // V平面步长
    int width;                     // 宽度
    int height;                    // 高度
    int64_t timestamp;             // 时间戳（微秒）
};

/// 编码器状态
enum class EncoderState {
    UNINITIALIZED,                 // 未初始化
    INITIALIZED,                   // 已初始化
    ENCODING,                      // 编码中
    ERROR                          // 错误状态
};

/// H.265视频编码器
class VideoEncoder {
public:
    VideoEncoder();
    ~VideoEncoder();

    /// 初始化编码器
    /// @param config 编码器配置
    /// @return 是否成功
    bool initialize(const VideoEncoderConfig& config);

    /// 编码一帧视频
    /// @param frame 原始视频帧
    /// @param encoded_frame 编码后的帧（输出）
    /// @return 是否成功
    bool encode(const RawVideoFrame& frame, EncodedFrame& encoded_frame);

    /// 强制生成关键帧
    void forceKeyFrame();

    /// 更新码率
    /// @param bitrate 新的码率
    void updateBitrate(int bitrate);

    /// 更新帧率
    /// @param fps 新的帧率
    void updateFrameRate(int fps);

    /// 获取编码器状态
    EncoderState getState() const;

    /// 获取编码器信息
    std::string getEncoderInfo() const;

    /// 重置编码器
    void reset();

    /// 释放资源
    void release();

    /// 设置编码回调（异步编码）
    void setEncodeCallback(std::function<void(const EncodedFrame&)> callback);

private:
    class Impl;
    std::unique_ptr<Impl> impl_;

    // 禁止拷贝
    VideoEncoder(const VideoEncoder&) = delete;
    VideoEncoder& operator=(const VideoEncoder&) = delete;
};

} // namespace av
} // namespace linkme

#endif // LINKME_VIDEO_ENCODER_H
