/************************************/
/*      platform_configs.hpp        */
/*                                  */
/*       RatLab Game Engine         */
/*          2026-Present            */
/*         On MIT License           */
/************************************/

#pragma once

/*All platforms which are considered supported.*/
enum PLATFORMS {
    UNKNOWN_PLATFORM,
    WINDOWS,
    LINUX,
    MACOS,
    IOS,
    ANDROID,
    WEB,
};

/*All Architextures which are considered supported.*/
enum ARCHITEXTURES {
    UNKNOWN_ARCHITEXTURE,
    BIT32,
    BIT64,
    ARM,
    AMD,
};

enum CPP_VERSIONS {
    UNKNOWN_CPP_VERSION,
    CPP_17,
    CPP_20,
    CPP_23,
    CPP_26,
};

// Platform Detection

#if defined(_WIN32)
static constexpr const PLATFORMS CURRENT_PLATFORM = PLATFORMS::WINDOWS;
static constexpr const ARCHITEXTURES CURRENT_PLATFORM_ARCHITEXTURE = ARCHITEXTURES::BIT32;
#define WINDOWS_ENABLED 32
#elif defined(_WIN64)
static constexpr const PLATFORMS CURRENT_PLATFORM = PLATFORMS::WINDOWS;
static constexpr const ARCHITEXTURES CURRENT_PLATFORM_ARCHITEXTURE = ARCHITEXTURES::BIT64;
#define WINDOWS_ENABLED 64
#elif defined(__linux__) || defined(__linux) || defined(linux)
static constexpr const PLATFORMS CURRENT_PLATFORM = PLATFORMS::LINUX;
static constexpr const ARCHITEXTURES CURRENT_PLATFORM_ARCHITEXTURE = ARCHITEXTURES::UNKNOWN_ARCHITEXTURE;
#define LINUX_ENABLED 1
#elif defined(__ANDROID__)
static constexpr const PLATFORMS CURRENT_PLATFORM = PLATFORMS::ANDROID;
static constexpr const ARCHITEXTURES CURRENT_PLATFORM_ARCHITEXTURE = ARCHITEXTURES::UNKNOWN_ARCHITEXTURE;
#define ANDROID_ENABLED 1
#elif defined(__APPLE__) && defined(__MACH__)
static constexpr const PLATFORMS CURRENT_PLATFORM = PLATFORMS::MACOS;
static constexpr const ARCHITEXTURES CURRENT_PLATFORM_ARCHITEXTURE = ARCHITEXTURES::UNKNOWN_ARCHITEXTURE;
#define MACOS_ENABLED 1
#elif defined(__APPLE__) && defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
static constexpr const PLATFORMS CURRENT_PLATFORM = PLATFORMS::IOS;
static constexpr const ARCHITEXTURES CURRENT_PLATFORM_ARCHITEXTURE = ARCHITEXTURES::UNKNOWN_ARCHITEXTURE;
#define IOS_ENABLED 1
#elif defined(__EMSCRIPTEN__) || defined(WASM) || defined(WEBASSEMBLY)
static constexpr const PLATFORMS CURRENT_PLATFORM = PLATFORMS::WEB;
static constexpr const ARCHITEXTURES CURRENT_PLATFORM_ARCHITEXTURE = ARCHITEXTURES::UNKNOWN_ARCHITEXTURE;
#define WEB_ENABLED 1
#endif

// C++ Version Detection
// A new principle lies here: Use 'CPP_VERSION' macro for specific compilations, and use 'CURRENT_CPP_VERSION'
// variable for patches inside functions.

#if defined(CPP_VERSION)
#undef CPP_VERSION
#endif

#if defined(__cplusplus)
    #if __cplusplus >= 202600L
        #define CPP_VERSION 26
        static constexpr const CPP_VERSIONS CURRENT_CPP_VERSION = CPP_VERSIONS::CPP_26;
    #elif __cplusplus >= 202100L
        #define CPP_VERSION 23
        static constexpr const CPP_VERSIONS CURRENT_CPP_VERSION = CPP_VERSIONS::CPP_23;
    #elif __cplusplus >= 202000L
        #define CPP_VERSION 20
        static constexpr const CPP_VERSIONS CURRENT_CPP_VERSION = CPP_VERSIONS::CPP_20;
    #elif __cplusplus >= 201700L
        #define CPP_VERSION 17
        static constexpr const CPP_VERSIONS CURRENT_CPP_VERSION = CPP_VERSIONS::CPP_17;
    #endif
#else
    #define CPP_VERSION 0
    static constexpr const CPP_VERSIONS CURRENT_CPP_VERSION = CPP_VERSIONS::UNKNOWN_CPP_VERSION;
#endif

//

enum COMPILERS {
    UNKNOWN,
    GNUC,
    CLANG,
    MSVC,
};

#if defined(__GNUC__)
    #define GNUC_ENABLED 1
    static constexpr const COMPILERS CURRENT_COMPILER = COMPILERS::GNUC;
#elif defined(__clang__)
    #define CLANG_ENABLED 1
    static constexpr const COMPILERS CURRENT_COMPILER = COMPILERS::CLANG;
#elif defined(_MSC_VER)
    #define MSVC_ENABLED 1
    static constexpr const COMPILERS CURRENT_COMPILER = COMPILERS::MSVC;
#else
    static constexpr const COMPILERS CURRENT_COMPILER = COMPILERS::UNKNOWN;
#endif
