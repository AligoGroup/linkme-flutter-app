/*
 * x265_config.h - Build configuration
 * Auto-generated configuration header
 */

#ifndef X265_CONFIG_H
#define X265_CONFIG_H

/* x265 version */
#define X265_VERSION "3.5"
#define X265_BUILD 210
#define X265_POINTVER "3.5"

/* Build options */
#define X265_ARCH_X86 0
#define X265_ARCH_X86_64 0
#define X265_ARCH_ARM 1
#define X265_ARCH_AARCH64 1

/* Bit depth */
#define HIGH_BIT_DEPTH 0
#define X265_DEPTH 8

/* Features */
#define HAVE_INT_TYPES_H 1
#define HAVE_STDINT_H 1
#define HAVE_STRTOK_R 1
#define HAVE_LIBNUMA 0
#define HAVE_NEON 1

/* Threading */
#define ENABLE_PPA 0
#define ENABLE_VTUNE 0

/* Assembly */
#define ENABLE_ASSEMBLY 1

/* Shared library */
#define EXPORT_C_API 1

/* Platform */
#if defined(__ANDROID__)
    #define X265_PLATFORM "Android"
#elif defined(__APPLE__)
    #define X265_PLATFORM "iOS"
#else
    #define X265_PLATFORM "Unknown"
#endif

/* Compiler */
#if defined(__clang__)
    #define X265_COMPILER "Clang"
#elif defined(__GNUC__)
    #define X265_COMPILER "GCC"
#else
    #define X265_COMPILER "Unknown"
#endif

#endif /* X265_CONFIG_H */
