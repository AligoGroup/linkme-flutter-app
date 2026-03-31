# native/linkme_av_core/CMakeLists.txt
# 作用：LinkMe音视频核心库的CMake配置文件
#
# x265：由 Android Gradle 传入 -DLINKME_ENABLE_X265=ON|OFF；未定义时默认 ON。
# 设为 OFF 时不链 x265，软件 H.265 路径不可用，用于快速验证构建。

cmake_minimum_required(VERSION 3.10)

if(NOT DEFINED LINKME_ENABLE_X265)
    set(LINKME_ENABLE_X265 ON)
endif()

project(linkme_av_core)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 编译选项
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -DNDEBUG")
else()
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g -O0")
endif()

# 平台特定配置
if(ANDROID)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC")
    # Android硬件加速
    find_library(MEDIA_NDK mediandk)
    find_library(LOG_LIB log)
elseif(IOS)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC -fobjc-arc")
    # iOS硬件加速
    find_library(VIDEO_TOOLBOX VideoToolbox)
    find_library(CORE_MEDIA CoreMedia)
    find_library(CORE_VIDEO CoreVideo)
endif()

# 源文件
set(SOURCES
    src/video_encoder.cpp
    src/video_decoder.cpp
    src/audio_processor.cpp
    src/frame_buffer.cpp
    src/codec_factory.cpp
    src/hardware_accelerator.cpp
    src/quality_controller.cpp
)

# Android平台添加JNI桥接
if(ANDROID)
    list(APPEND SOURCES src/jni_bridge.cpp)
endif()

# 添加 x265 子项目（可关）
if(LINKME_ENABLE_X265)
    add_subdirectory(third_party/x265)
endif()

# 头文件目录
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)
if(LINKME_ENABLE_X265)
    include_directories(${CMAKE_CURRENT_SOURCE_DIR}/third_party/x265/include)
endif()

# 创建共享库
add_library(linkme_av_core SHARED ${SOURCES})

if(NOT LINKME_ENABLE_X265)
    target_compile_definitions(linkme_av_core PRIVATE LINKME_WITHOUT_X265=1)
endif()

# 链接库（同一 target 的 target_link_libraries 须全程用关键字或全程不用，不可混用）
if(ANDROID)
    if(LINKME_ENABLE_X265)
        if(X265_LIB_IS_SHARED)
            target_link_libraries(linkme_av_core PRIVATE
                ${MEDIA_NDK}
                ${LOG_LIB}
                x265
            )
        else()
            target_link_libraries(linkme_av_core PRIVATE
                ${MEDIA_NDK}
                ${LOG_LIB}
                "-Wl,--whole-archive"
                x265
                "-Wl,--no-whole-archive"
            )
        endif()
    else()
        target_link_libraries(linkme_av_core PRIVATE
            ${MEDIA_NDK}
            ${LOG_LIB}
        )
    endif()
elseif(IOS)
    target_link_libraries(linkme_av_core PRIVATE
        ${VIDEO_TOOLBOX}
        ${CORE_MEDIA}
        ${CORE_VIDEO}
    )
    if(LINKME_ENABLE_X265)
        target_link_libraries(linkme_av_core PRIVATE x265)
    endif()
endif()

# 安装配置
install(TARGETS linkme_av_core
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
)

install(DIRECTORY include/
    DESTINATION include
    FILES_MATCHING PATTERN "*.h"
)
