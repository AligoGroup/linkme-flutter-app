// native/linkme_av_core/include/hardware_accelerator.h
// 作用：硬件加速器头文件，封装平台相关的硬件加速API
// 功能：Android MediaCodec、iOS VideoToolbox硬件加速

#ifndef LINKME_HARDWARE_ACCELERATOR_H
#define LINKME_HARDWARE_ACCELERATOR_H

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace linkme {
namespace av {

/// 硬件加速类型
enum class AcceleratorType {
    NONE,                          // 无硬件加速
    ANDROID_MEDIACODEC,            // Android MediaCodec
    IOS_VIDEOTOOLBOX,              // iOS VideoToolbox
    LINUX_VAAPI,                   // Linux VA-API
    WINDOWS_D3D11                  // Windows D3D11
};

/// 硬件加速能力
struct AcceleratorCapability {
    AcceleratorType type;          // 加速器类型
    std::string name;              // 名称
    bool encode_supported;         // 是否支持编码
    bool decode_supported;         // 是否支持解码
    int max_width;                 // 最大宽度
    int max_height;                // 最大高度
    int max_instances;             // 最大实例数
    std::vector<std::string> supported_codecs; // 支持的编解码器
};

/// 硬件编码器配置
struct HardwareEncoderConfig {
    int width;                     // 宽度
    int height;                    // 高度
    int fps;                       // 帧率
    int bitrate;                   // 码率
    int keyframe_interval;         // 关键帧间隔
    int quality;                   // 质量（0-100）
};

/// 硬件解码器配置
struct HardwareDecoderConfig {
    int max_width;                 // 最大宽度
    int max_height;                // 最大高度
    int buffer_count;              // 缓冲数量
};

/// 硬件加速器
class HardwareAccelerator {
public:
    HardwareAccelerator();
    ~HardwareAccelerator();

    /// 初始化硬件加速器
    /// @return 是否成功
    bool initialize();

    /// 检测可用的硬件加速类型
    /// @return 加速器类型
    AcceleratorType detectAcceleratorType() const;

    /// 查询硬件加速能力
    /// @param type 加速器类型
    /// @return 能力信息
    AcceleratorCapability queryCapability(AcceleratorType type) const;

    /// 创建硬件编码器
    /// @param config 编码器配置
    /// @return 编码器句柄（平台相关）
    void* createHardwareEncoder(const HardwareEncoderConfig& config);

    /// 创建硬件解码器
    /// @param config 解码器配置
    /// @return 解码器句柄（平台相关）
    void* createHardwareDecoder(const HardwareDecoderConfig& config);

    /// 硬件编码一帧
    /// @param encoder_handle 编码器句柄
    /// @param input_data 输入数据（YUV）
    /// @param input_size 输入大小
    /// @param output_data 输出数据（H.265）
    /// @param output_size 输出大小
    /// @param is_keyframe 是否为关键帧（输出）
    /// @return 是否成功
    bool encodeFrame(void* encoder_handle, 
                     const uint8_t* input_data, 
                     size_t input_size,
                     uint8_t** output_data, 
                     size_t* output_size,
                     bool* is_keyframe);

    /// 硬件解码一帧
    /// @param decoder_handle 解码器句柄
    /// @param input_data 输入数据（H.265）
    /// @param input_size 输入大小
    /// @param output_data 输出数据（YUV）
    /// @param output_size 输出大小
    /// @return 是否成功
    bool decodeFrame(void* decoder_handle,
                     const uint8_t* input_data,
                     size_t input_size,
                     uint8_t** output_data,
                     size_t* output_size);

    /// 释放硬件编码器
    /// @param encoder_handle 编码器句柄
    void releaseHardwareEncoder(void* encoder_handle);

    /// 释放硬件解码器
    /// @param decoder_handle 解码器句柄
    void releaseHardwareDecoder(void* decoder_handle);

    /// 是否支持硬件加速
    /// @return 是否支持
    bool isSupported() const;

    /// 获取错误信息
    /// @return 错误信息
    std::string getLastError() const;

    /// 释放资源
    void release();

private:
    class Impl;
    std::unique_ptr<Impl> impl_;

    // 禁止拷贝
    HardwareAccelerator(const HardwareAccelerator&) = delete;
    HardwareAccelerator& operator=(const HardwareAccelerator&) = delete;
};

} // namespace av
} // namespace linkme

#endif // LINKME_HARDWARE_ACCELERATOR_H
