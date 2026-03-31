// native/linkme_av_core/src/frame_buffer.cpp
// 作用：帧缓冲管理器实现
// 功能：循环缓冲、时间戳同步、丢帧策略

#include "frame_buffer.h"
#include <iostream>
#include <deque>
#include <chrono>

namespace linkme {
namespace av {

class FrameBuffer::Impl {
public:
    Impl() : max_size_(30),
             strategy_(BufferStrategy::DROP_OLDEST),
             enable_timestamp_sync_(true),
             max_timestamp_diff_(100000),
             total_pushed_(0),
             total_popped_(0),
             total_dropped_(0),
             avg_latency_(0),
             max_latency_(0) {}

    ~Impl() {
        release();
    }

    bool initialize(const FrameBufferConfig& config) {
        std::lock_guard<std::mutex> lock(mutex_);
        
        max_size_ = config.max_size;
        strategy_ = config.strategy;
        enable_timestamp_sync_ = config.enable_timestamp_sync;
        max_timestamp_diff_ = config.max_timestamp_diff;
        
        std::cout << "[FrameBuffer] 初始化成功，最大缓冲: " << max_size_ << std::endl;
        return true;
    }

    bool push(const Frame& frame) {
        std::unique_lock<std::mutex> lock(mutex_);
        
        // 检查是否已满
        if (buffer_.size() >= static_cast<size_t>(max_size_)) {
            handleFullBuffer(frame);
        }
        
        // 时间戳同步检查
        if (enable_timestamp_sync_ && !buffer_.empty()) {
            int64_t timestamp_diff = std::abs(frame.timestamp - buffer_.back().timestamp);
            if (timestamp_diff > max_timestamp_diff_) {
                std::cerr << "[FrameBuffer] 时间戳差异过大: " << timestamp_diff << "us" << std::endl;
            }
        }
        
        buffer_.push_back(frame);
        total_pushed_++;
        
        // 通知等待的线程
        cv_.notify_one();
        
        return true;
    }

    bool pop(Frame& frame, int timeout_ms) {
        std::unique_lock<std::mutex> lock(mutex_);
        
        if (timeout_ms > 0) {
            // 等待直到有数据或超时
            if (!cv_.wait_for(lock, std::chrono::milliseconds(timeout_ms),
                             [this] { return !buffer_.empty(); })) {
                return false; // 超时
            }
        } else if (buffer_.empty()) {
            return false; // 无数据且不等待
        }
        
        frame = buffer_.front();
        buffer_.pop_front();
        total_popped_++;
        
        // 计算延迟
        auto now = std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::system_clock::now().time_since_epoch()).count();
        int64_t latency = now - frame.timestamp;
        
        if (latency > max_latency_) {
            max_latency_ = latency;
        }
        
        // 更新平均延迟
        avg_latency_ = (avg_latency_ * (total_popped_ - 1) + latency) / total_popped_;
        
        return true;
    }

    bool peek(Frame& frame) const {
        std::lock_guard<std::mutex> lock(mutex_);
        
        if (buffer_.empty()) {
            return false;
        }
        
        frame = buffer_.front();
        return true;
    }

    void clear() {
        std::lock_guard<std::mutex> lock(mutex_);
        buffer_.clear();
        std::cout << "[FrameBuffer] 缓冲区已清空" << std::endl;
    }

    int size() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return buffer_.size();
    }

    bool empty() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return buffer_.empty();
    }

    bool full() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return buffer_.size() >= static_cast<size_t>(max_size_);
    }

    FrameBufferStats getStats() const {
        std::lock_guard<std::mutex> lock(mutex_);
        
        FrameBufferStats stats;
        stats.current_size = buffer_.size();
        stats.total_pushed = total_pushed_;
        stats.total_popped = total_popped_;
        stats.total_dropped = total_dropped_;
        stats.avg_latency = avg_latency_;
        stats.max_latency = max_latency_;
        
        return stats;
    }

    void resetStats() {
        std::lock_guard<std::mutex> lock(mutex_);
        
        total_pushed_ = 0;
        total_popped_ = 0;
        total_dropped_ = 0;
        avg_latency_ = 0;
        max_latency_ = 0;
        
        std::cout << "[FrameBuffer] 统计信息已重置" << std::endl;
    }

    void setStrategy(BufferStrategy strategy) {
        std::lock_guard<std::mutex> lock(mutex_);
        strategy_ = strategy;
        std::cout << "[FrameBuffer] 缓冲策略已更新" << std::endl;
    }

    void setMaxSize(int max_size) {
        std::lock_guard<std::mutex> lock(mutex_);
        max_size_ = max_size;
        
        // 如果当前缓冲超过新的最大值，删除多余的帧
        while (buffer_.size() > static_cast<size_t>(max_size_)) {
            buffer_.pop_front();
            total_dropped_++;
        }
        
        std::cout << "[FrameBuffer] 最大缓冲大小已更新: " << max_size_ << std::endl;
    }

    void release() {
        std::lock_guard<std::mutex> lock(mutex_);
        buffer_.clear();
    }

private:
    void handleFullBuffer(const Frame& new_frame) {
        switch (strategy_) {
            case BufferStrategy::DROP_OLDEST:
                buffer_.pop_front();
                total_dropped_++;
                break;
                
            case BufferStrategy::DROP_NEWEST:
                // 不添加新帧
                total_dropped_++;
                break;
                
            case BufferStrategy::DROP_NON_KEYFRAMES:
                // 尝试删除非关键帧
                {
                    bool dropped = false;
                    for (auto it = buffer_.begin(); it != buffer_.end(); ++it) {
                        if (!it->is_keyframe) {
                            buffer_.erase(it);
                            total_dropped_++;
                            dropped = true;
                            break;
                        }
                    }
                    
                    // 如果没有非关键帧，删除最旧的帧
                    if (!dropped) {
                        buffer_.pop_front();
                        total_dropped_++;
                    }
                }
                break;
                
            case BufferStrategy::BLOCK_UNTIL_SPACE:
                // 等待空间（在push中处理）
                break;
        }
    }

    mutable std::mutex mutex_;
    std::condition_variable cv_;
    std::deque<Frame> buffer_;
    
    int max_size_;
    BufferStrategy strategy_;
    bool enable_timestamp_sync_;
    int64_t max_timestamp_diff_;
    
    // 统计信息
    int total_pushed_;
    int total_popped_;
    int total_dropped_;
    int64_t avg_latency_;
    int64_t max_latency_;
};

// FrameBuffer公共接口实现
FrameBuffer::FrameBuffer() : impl_(std::make_unique<Impl>()) {}
FrameBuffer::~FrameBuffer() = default;

bool FrameBuffer::initialize(const FrameBufferConfig& config) {
    return impl_->initialize(config);
}

bool FrameBuffer::push(const Frame& frame) {
    return impl_->push(frame);
}

bool FrameBuffer::pop(Frame& frame, int timeout_ms) {
    return impl_->pop(frame, timeout_ms);
}

bool FrameBuffer::peek(Frame& frame) const {
    return impl_->peek(frame);
}

void FrameBuffer::clear() {
    impl_->clear();
}

int FrameBuffer::size() const {
    return impl_->size();
}

bool FrameBuffer::empty() const {
    return impl_->empty();
}

bool FrameBuffer::full() const {
    return impl_->full();
}

FrameBufferStats FrameBuffer::getStats() const {
    return impl_->getStats();
}

void FrameBuffer::resetStats() {
    impl_->resetStats();
}

void FrameBuffer::setStrategy(BufferStrategy strategy) {
    impl_->setStrategy(strategy);
}

void FrameBuffer::setMaxSize(int max_size) {
    impl_->setMaxSize(max_size);
}

void FrameBuffer::release() {
    impl_->release();
}

} // namespace av
} // namespace linkme
