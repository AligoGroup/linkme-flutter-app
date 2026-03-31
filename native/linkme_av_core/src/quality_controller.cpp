// native/linkme_av_core/src/quality_controller.cpp
// 作用：质量控制器实现
// 功能：动态调整编码参数以适应网络状况

#include "quality_controller.h"
#include <iostream>
#include <algorithm>
#include <cmath>

namespace linkme {
namespace av {

class QualityController::Impl {
public:
    Impl() : current_quality_(NetworkQuality::EXCELLENT),
             strategy_(QualityStrategy::BALANCED),
             auto_adjust_enabled_(true),
             min_bitrate_(500000),
             max_bitrate_(10000000),
             min_fps_(15),
             max_fps_(30) {}

    ~Impl() = default;

    bool initialize(const QualityControllerConfig& config) {
        initial_params_ = config.initial_params;
        current_params_ = config.initial_params;
        strategy_ = config.strategy;
        min_bitrate_ = config.min_bitrate;
        max_bitrate_ = config.max_bitrate;
        min_fps_ = config.min_fps;
        max_fps_ = config.max_fps;
        auto_adjust_enabled_ = config.enable_auto_adjust;
        
        std::cout << "[QualityController] 初始化成功" << std::endl;
        std::cout << "[QualityController] 初始参数: " 
                  << current_params_.width << "x" << current_params_.height
                  << "@" << current_params_.fps << "fps, "
                  << current_params_.bitrate / 1000 << "kbps" << std::endl;
        
        return true;
    }

    void updateNetworkStats(const NetworkStats& stats) {
        network_stats_ = stats;
        
        // 评估网络质量
        current_quality_ = evaluateNetworkQuality(stats);
        
        // 自动调整质量参数
        if (auto_adjust_enabled_) {
            adjustQualityParams();
        }
        
        if (quality_change_callback_) {
            quality_change_callback_(current_params_);
        }
    }

    QualityParams getRecommendedParams() const {
        return current_params_;
    }

    NetworkQuality getNetworkQuality() const {
        return current_quality_;
    }

    void setStrategy(QualityStrategy strategy) {
        strategy_ = strategy;
        std::cout << "[QualityController] 策略已更新: " 
                  << getStrategyName(strategy) << std::endl;
    }

    void setQualityParams(const QualityParams& params) {
        current_params_ = params;
        
        // 限制参数范围
        current_params_.bitrate = std::max(min_bitrate_, 
                                          std::min(max_bitrate_, params.bitrate));
        current_params_.fps = std::max(min_fps_, 
                                      std::min(max_fps_, params.fps));
        
        std::cout << "[QualityController] 质量参数已手动设置" << std::endl;
        
        if (quality_change_callback_) {
            quality_change_callback_(current_params_);
        }
    }

    void setAutoAdjustEnabled(bool enabled) {
        auto_adjust_enabled_ = enabled;
        std::cout << "[QualityController] 自动调整: " 
                  << (enabled ? "启用" : "禁用") << std::endl;
    }

    void setQualityChangeCallback(std::function<void(const QualityParams&)> callback) {
        quality_change_callback_ = callback;
    }

    void reset() {
        current_params_ = initial_params_;
        current_quality_ = NetworkQuality::EXCELLENT;
        
        std::cout << "[QualityController] 已重置到初始参数" << std::endl;
        
        if (quality_change_callback_) {
            quality_change_callback_(current_params_);
        }
    }

    void release() {
        quality_change_callback_ = nullptr;
    }

private:
    NetworkQuality evaluateNetworkQuality(const NetworkStats& stats) const {
        // 综合评估网络质量
        int score = 100;
        
        // RTT影响（权重30%）
        if (stats.rtt_ms > 300) score -= 30;
        else if (stats.rtt_ms > 200) score -= 20;
        else if (stats.rtt_ms > 100) score -= 10;
        else if (stats.rtt_ms > 50) score -= 5;
        
        // 丢包率影响（权重40%）
        if (stats.packet_loss_rate > 0.1) score -= 40;
        else if (stats.packet_loss_rate > 0.05) score -= 30;
        else if (stats.packet_loss_rate > 0.02) score -= 20;
        else if (stats.packet_loss_rate > 0.01) score -= 10;
        
        // 抖动影响（权重20%）
        if (stats.jitter_ms > 100) score -= 20;
        else if (stats.jitter_ms > 50) score -= 15;
        else if (stats.jitter_ms > 30) score -= 10;
        else if (stats.jitter_ms > 15) score -= 5;
        
        // 带宽影响（权重10%）
        int64_t required_bandwidth = current_params_.bitrate * 1.2; // 留20%余量
        if (stats.bandwidth_bps < required_bandwidth * 0.5) score -= 10;
        else if (stats.bandwidth_bps < required_bandwidth * 0.7) score -= 7;
        else if (stats.bandwidth_bps < required_bandwidth * 0.9) score -= 5;
        
        // 根据分数确定质量等级
        if (score >= 90) return NetworkQuality::EXCELLENT;
        else if (score >= 70) return NetworkQuality::GOOD;
        else if (score >= 50) return NetworkQuality::FAIR;
        else if (score >= 30) return NetworkQuality::POOR;
        else return NetworkQuality::VERY_POOR;
    }

    void adjustQualityParams() {
        QualityParams new_params = current_params_;
        
        switch (current_quality_) {
            case NetworkQuality::EXCELLENT:
                // 恢复到最佳质量
                new_params = initial_params_;
                break;
                
            case NetworkQuality::GOOD:
                // 轻微降低
                new_params.bitrate = initial_params_.bitrate * 0.8;
                break;
                
            case NetworkQuality::FAIR:
                // 中等降低
                if (strategy_ == QualityStrategy::MAINTAIN_RESOLUTION) {
                    new_params.fps = std::max(min_fps_, static_cast<int>(initial_params_.fps * 0.7));
                    new_params.bitrate = initial_params_.bitrate * 0.6;
                } else if (strategy_ == QualityStrategy::MAINTAIN_FRAMERATE) {
                    new_params.width = initial_params_.width * 0.75;
                    new_params.height = initial_params_.height * 0.75;
                    new_params.bitrate = initial_params_.bitrate * 0.5;
                } else {
                    new_params.fps = std::max(min_fps_, static_cast<int>(initial_params_.fps * 0.8));
                    new_params.width = initial_params_.width * 0.85;
                    new_params.height = initial_params_.height * 0.85;
                    new_params.bitrate = initial_params_.bitrate * 0.6;
                }
                break;
                
            case NetworkQuality::POOR:
                // 大幅降低
                if (strategy_ == QualityStrategy::MAINTAIN_RESOLUTION) {
                    new_params.fps = min_fps_;
                    new_params.bitrate = initial_params_.bitrate * 0.4;
                } else if (strategy_ == QualityStrategy::MAINTAIN_FRAMERATE) {
                    new_params.width = initial_params_.width * 0.5;
                    new_params.height = initial_params_.height * 0.5;
                    new_params.bitrate = initial_params_.bitrate * 0.3;
                } else {
                    new_params.fps = std::max(min_fps_, static_cast<int>(initial_params_.fps * 0.6));
                    new_params.width = initial_params_.width * 0.6;
                    new_params.height = initial_params_.height * 0.6;
                    new_params.bitrate = initial_params_.bitrate * 0.4;
                }
                break;
                
            case NetworkQuality::VERY_POOR:
                // 最低质量
                new_params.fps = min_fps_;
                new_params.width = 640;
                new_params.height = 360;
                new_params.bitrate = min_bitrate_;
                break;
        }
        
        // 限制参数范围
        new_params.bitrate = std::max(min_bitrate_, 
                                     std::min(max_bitrate_, new_params.bitrate));
        new_params.fps = std::max(min_fps_, 
                                 std::min(max_fps_, new_params.fps));
        
        // 检查是否需要更新
        if (paramsChanged(current_params_, new_params)) {
            current_params_ = new_params;
            
            std::cout << "[QualityController] 质量参数已调整: " 
                      << current_params_.width << "x" << current_params_.height
                      << "@" << current_params_.fps << "fps, "
                      << current_params_.bitrate / 1000 << "kbps" << std::endl;
        }
    }

    bool paramsChanged(const QualityParams& p1, const QualityParams& p2) const {
        return p1.width != p2.width ||
               p1.height != p2.height ||
               p1.fps != p2.fps ||
               std::abs(p1.bitrate - p2.bitrate) > 100000; // 100kbps差异
    }

    std::string getStrategyName(QualityStrategy strategy) const {
        switch (strategy) {
            case QualityStrategy::MAINTAIN_RESOLUTION: return "保持分辨率";
            case QualityStrategy::MAINTAIN_FRAMERATE: return "保持帧率";
            case QualityStrategy::BALANCED: return "平衡";
            default: return "未知";
        }
    }

    QualityParams initial_params_;
    QualityParams current_params_;
    NetworkStats network_stats_;
    NetworkQuality current_quality_;
    QualityStrategy strategy_;
    bool auto_adjust_enabled_;
    int min_bitrate_;
    int max_bitrate_;
    int min_fps_;
    int max_fps_;
    std::function<void(const QualityParams&)> quality_change_callback_;
};

// QualityController公共接口实现
QualityController::QualityController() : impl_(std::make_unique<Impl>()) {}
QualityController::~QualityController() = default;

bool QualityController::initialize(const QualityControllerConfig& config) {
    return impl_->initialize(config);
}

void QualityController::updateNetworkStats(const NetworkStats& stats) {
    impl_->updateNetworkStats(stats);
}

QualityParams QualityController::getRecommendedParams() const {
    return impl_->getRecommendedParams();
}

NetworkQuality QualityController::getNetworkQuality() const {
    return impl_->getNetworkQuality();
}

void QualityController::setStrategy(QualityStrategy strategy) {
    impl_->setStrategy(strategy);
}

void QualityController::setQualityParams(const QualityParams& params) {
    impl_->setQualityParams(params);
}

void QualityController::setAutoAdjustEnabled(bool enabled) {
    impl_->setAutoAdjustEnabled(enabled);
}

void QualityController::setQualityChangeCallback(
    std::function<void(const QualityParams&)> callback) {
    impl_->setQualityChangeCallback(callback);
}

void QualityController::reset() {
    impl_->reset();
}

void QualityController::release() {
    impl_->release();
}

} // namespace av
} // namespace linkme
