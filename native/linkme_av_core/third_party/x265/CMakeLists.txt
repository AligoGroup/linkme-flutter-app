# x265 third-party library CMake configuration
cmake_minimum_required(VERSION 3.10)
project(x265_third_party)

set(CMAKE_CXX_STANDARD 17)

set(X265_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include CACHE PATH "x265 include directory")

if(ANDROID)
    set(X265_LIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/lib/${ANDROID_ABI})
elseif(IOS)
    set(X265_LIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/lib/ios)
else()
    set(X265_LIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/lib)
endif()

set(_X265_SO "${X265_LIB_DIR}/libx265.so")
set(_X265_A "${X265_LIB_DIR}/libx265.a")

# Android：优先共享库。部分预编译 .a 未导出 x265_api_get / x265_encoder_open（仅 .so 含完整符号）。
if(ANDROID AND EXISTS "${_X265_SO}")
    add_library(x265 SHARED IMPORTED GLOBAL)
    set_target_properties(x265 PROPERTIES
        IMPORTED_LOCATION ${_X265_SO}
        INTERFACE_INCLUDE_DIRECTORIES ${X265_INCLUDE_DIR}
    )
    set(X265_LIB_IS_SHARED TRUE PARENT_SCOPE)
    message(STATUS "x265: using SHARED library ${_X265_SO}")
elseif(EXISTS "${_X265_A}")
    add_library(x265 STATIC IMPORTED GLOBAL)
    set_target_properties(x265 PROPERTIES
        IMPORTED_LOCATION ${_X265_A}
        INTERFACE_INCLUDE_DIRECTORIES ${X265_INCLUDE_DIR}
    )
    set(X265_LIB_IS_SHARED FALSE PARENT_SCOPE)
    message(STATUS "x265: using STATIC library ${_X265_A}")
else()
    find_library(X265_LIBRARY NAMES x265 libx265 PATHS ${X265_LIB_DIR} NO_DEFAULT_PATH)
    if(X265_LIBRARY)
        get_filename_component(_X265_BNAME "${X265_LIBRARY}" NAME)
        if(_X265_BNAME MATCHES "\\.so$")
            add_library(x265 SHARED IMPORTED GLOBAL)
            set(X265_LIB_IS_SHARED TRUE PARENT_SCOPE)
        else()
            add_library(x265 STATIC IMPORTED GLOBAL)
            set(X265_LIB_IS_SHARED FALSE PARENT_SCOPE)
        endif()
        set_target_properties(x265 PROPERTIES
            IMPORTED_LOCATION ${X265_LIBRARY}
            INTERFACE_INCLUDE_DIRECTORIES ${X265_INCLUDE_DIR}
        )
        message(STATUS "x265: find_library -> ${X265_LIBRARY}")
    else()
        message(FATAL_ERROR
            "x265 not found in ${X265_LIB_DIR}. Place libx265.so (recommended) or libx265.a. "
            "See third_party/x265/README.md and Gradle :app:ensureX265.")
    endif()
endif()

set(X265_INCLUDE_DIRS ${X265_INCLUDE_DIR} PARENT_SCOPE)
set(X265_LIBRARIES x265 PARENT_SCOPE)
