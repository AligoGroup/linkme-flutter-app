// native/linkme_av_core/include/frame_buffer.h
// 作用：帧缓冲管理器头文件，管理音视频帧的缓冲和同步
// 功能：循环缓冲、时间戳同步、丢帧策略

#ifndef LINKME_FRAME_BUFFER_H
#define LINKME_FRAME_BUFFER_H

#include <cstdint>
#include <memory>
#include <vector>
#include <functional>
#include <mutex>
#include <condition_variable>

namespace linkme {
namespace av {

/// 帧类型
enum class FrameType {
    VIDEO,                         // 视频帧
    AUDIO                          // 音频帧
};

/// 通用帧数据
struct Frame {
    std::vector<uint8_t> data;     // 帧数据
    int64_t timestamp;             // 时间戳（微秒）
    FrameType type;                // 帧类型
    bool is_keyframe;              // 是否为关键帧（仅视频）
    int width;                     // 宽度（仅视频）
    int height;                    // 高度（仅视频）
    int sequence;                  // 序列号
};

/// 缓冲策略
enum class BufferStrategy {
    DROP_OLDEST,                   // 丢弃最旧的帧
    DROP_NEWEST,                   // 丢弃最新的帧
    BLOCK_UNTIL_SPACE,             // 阻塞直到有空间
    DROP_NON_KEYFRAMES             // 丢弃非关键帧
};

/// 帧缓冲配置
struct FrameBufferConfig {
    int max_size = 30;             // 最大缓冲帧数
    BufferStrategy strategy = BufferStrategy::DROP_OLDEST;
    bool enable_timestamp_sync = true;  // 启用时间戳同步
    int64_t max_timestamp_diff = 100000; // 最大时间戳差异（微秒）
};

/// 帧缓冲统计
struct FrameBufferStats {
    int current_size;              // 当前缓冲帧数
    int total_pushed;              // 总推入帧数
    int total_popped;              // 总弹出帧数
    int total_dropped;             // 总丢弃帧数
    int64_t avg_latency;           // 平均延迟（微秒）
    int64_t max_latency;           // 最大延迟（微秒）
};

/// 帧缓冲管理器
class FrameBuffer {
public:
    FrameBuffer();
    ~FrameBuffer();

    /// 初始化缓冲区
    /// @param config 缓冲配置
    /// @return 是否成功
    bool initialize(const FrameBufferConfig& config);

    /// 推入一帧
    /// @param frame 帧数据
    /// @return 是否成功
    bool push(const Frame& frame);

    /// 弹出一帧
    /// @param frame 帧数据（输出）
    /// @param timeout_ms 超时时间（毫秒，0表示不阻塞）
    /// @return 是否成功
    bool pop(Frame& frame, int timeout_ms = 0);

    /// 查看下一帧（不移除）
    /// @param frame 帧数据（输出）
    /// @return 是否成功
    bool peek(Frame& frame) const;

    /// 清空缓冲区
    void clear();

    /// 获取当前缓冲帧数
    int size() const;

    /// 是否为空
    bool empty() const;

    /// 是否已满
    bool full() const;

    /// 获取统计信息
    FrameBufferStats getStats() const;

    /// 重置统计信息
    void resetStats();

    /// 设置缓冲策略
    void setStrategy(BufferStrategy strategy);

    /// 设置最大缓冲大小
    void setMaxSize(int max_size);

    /// 释放资源
    void release();

private:
    class Impl;
    std::unique_ptr<Impl> impl_;

    // 禁止拷贝
    FrameBuffer(const FrameBuffer&) = delete;
    FrameBuffer& operator=(const FrameBuffer&) = delete;
};

} // namespace av
} // namespace linkme

#endif // LINKME_FRAME_BUFFER_H
