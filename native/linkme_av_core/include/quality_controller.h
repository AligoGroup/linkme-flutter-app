// native/linkme_av_core/include/quality_controller.h
// 作用：质量控制器头文件，动态调整编码参数以适应网络状况
// 功能：码率自适应、分辨率调整、帧率控制

#ifndef LINKME_QUALITY_CONTROLLER_H
#define LINKME_QUALITY_CONTROLLER_H

#include <cstdint>
#include <memory>
#include <functional>

namespace linkme {
namespace av {

/// 网络质量等级
enum class NetworkQuality {
    EXCELLENT,                     // 优秀
    GOOD,                          // 良好
    FAIR,                          // 一般
    POOR,                          // 较差
    VERY_POOR                      // 很差
};

/// 质量控制策略
enum class QualityStrategy {
    MAINTAIN_RESOLUTION,           // 保持分辨率，降低帧率/码率
    MAINTAIN_FRAMERATE,            // 保持帧率，降低分辨率/码率
    BALANCED                       // 平衡调整
};

/// 网络统计信息
struct NetworkStats {
    int64_t rtt_ms;                // 往返时延（毫秒）
    double packet_loss_rate;       // 丢包率（0.0-1.0）
    int64_t bandwidth_bps;         // 可用带宽（bps）
    int64_t jitter_ms;             // 抖动（毫秒）
};

/// 编码质量参数
struct QualityParams {
    int width;                     // 宽度
    int height;                    // 高度
    int fps;                       // 帧率
    int bitrate;                   // 码率
    int keyframe_interval;         // 关键帧间隔
};

/// 质量控制器配置
struct QualityControllerConfig {
    QualityParams initial_params;  // 初始质量参数
    QualityStrategy strategy = QualityStrategy::BALANCED;
    int min_bitrate = 500000;      // 最小码率（500kbps）
    int max_bitrate = 10000000;    // 最大码率（10Mbps）
    int min_fps = 15;              // 最小帧率
    int max_fps = 30;              // 最大帧率
    bool enable_auto_adjust = true; // 启用自动调整
};

/// 质量控制器
class QualityController {
public:
    QualityController();
    ~QualityController();

    /// 初始化质量控制器
    /// @param config 控制器配置
    /// @return 是否成功
    bool initialize(const QualityControllerConfig& config);

    /// 更新网络统计信息
    /// @param stats 网络统计
    void updateNetworkStats(const NetworkStats& stats);

    /// 获取当前推荐的质量参数
    /// @return 质量参数
    QualityParams getRecommendedParams() const;

    /// 获取当前网络质量等级
    /// @return 网络质量
    NetworkQuality getNetworkQuality() const;

    /// 设置质量控制策略
    /// @param strategy 策略
    void setStrategy(QualityStrategy strategy);

    /// 手动设置质量参数
    /// @param params 质量参数
    void setQualityParams(const QualityParams& params);

    /// 启用/禁用自动调整
    /// @param enabled 是否启用
    void setAutoAdjustEnabled(bool enabled);

    /// 设置质量变化回调
    /// @param callback 回调函数
    void setQualityChangeCallback(
        std::function<void(const QualityParams&)> callback);

    /// 重置到初始参数
    void reset();

    /// 释放资源
    void release();

private:
    class Impl;
    std::unique_ptr<Impl> impl_;

    // 禁止拷贝
    QualityController(const QualityController&) = delete;
    QualityController& operator=(const QualityController&) = delete;
};

} // namespace av
} // namespace linkme

#endif // LINKME_QUALITY_CONTROLLER_H
