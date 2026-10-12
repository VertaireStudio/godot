# Self-contained dev/debug build definition for the entire Godot workspace.
#
# Selected by the root CMakeLists.txt when -DGODOT_DEBUG_BUILD=ON. It is fully
# self-contained: it defines the codegen rules, every engine library, every
# module target, and the final executable on its own, without including the
# split release configuration files in this directory.
#
# The semantics mirror a Godot `dev_build=yes` SCons build:
#   * DEV_ENABLED + DEBUG_ENABLED + TOOLS_ENABLED (editor target)
#   * -O0 optimization and -g3 debug symbols
#   * the executable is NOT stripped and keeps full DWARF info
#   * output name gains the `.dev` suffix
#
# Only the ported configuration is supported: platform=linuxbsd, arch=x86_64.

# This file is a build-definition *module*: it is included by the top-level
# CMakeLists.txt after project(). Running it on its own (`cmake -P`, or a CMake
# script-debugging launch config) puts CMake in script mode, where no compiler
# is enabled, so fail with an actionable message instead of a confusing
# "FindThreads only works if either C or CXX language is enabled" from the
# find_package(Threads) call further down.
if(NOT CMAKE_C_COMPILER_LOADED AND NOT CMAKE_CXX_COMPILER_LOADED)
    message(FATAL_ERROR
        "cmake/debug.cmake is an included build module and cannot be run directly.\n"
        "Configure the project instead:\n"
        "    cmake -S . -B build-debug -DGODOT_DEBUG_BUILD=ON\n"
        "    cmake --build build-debug\n"
        "Running this file standalone (cmake -P, or CMake script debugging) uses\n"
        "script mode, where no compiler is enabled and configuring cannot proceed.")
endif()

# =============================================================================
# Debug options (hard-coded dev_build semantics)
# =============================================================================
set(GODOT_PLATFORM "linuxbsd" CACHE STRING "Target platform (debug build only)")
set(GODOT_TARGET "editor" CACHE STRING "Compilation target (debug build only)")
set(GODOT_ARCH "x86_64" CACHE STRING "CPU architecture (debug build only)")
set(GODOT_PRECISION "single" CACHE STRING "Floating-point precision (single|double)")
set(GODOT_LTO "none" CACHE STRING "Link-time optimization (debug builds never use LTO)")
set(GODOT_EXTRA_SUFFIX "" CACHE STRING "Custom extra suffix added to the base filename")

# Force a genuine debug build regardless of any user-supplied build type.
set(GODOT_DEV_BUILD ON CACHE BOOL "Developer build with dev-only debugging code")
set(GODOT_DEBUG_SYMBOLS ON CACHE BOOL "Build with debugging symbols")
set(GODOT_OPTIMIZE "none" CACHE STRING "Optimization level (debug builds use none)")
set(GODOT_SEPARATE_DEBUG_SYMBOLS OFF CACHE BOOL "Extract debugging symbols to a separate file")
set(GODOT_DEBUG_PATHS_RELATIVE OFF CACHE BOOL "Make file paths in debug symbols relative")
set(GODOT_PRODUCTION OFF CACHE BOOL "Set defaults to build Godot for use in production")
set(GODOT_THREADS ON CACHE BOOL "Enable threading support")
set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)

# Component / trimming defaults (identical to the release configuration so the
# same set of sources is compiled, only the debug flags change).
option(GODOT_DEPRECATED "Enable compatibility code for deprecated features" ON)
option(GODOT_MINIZIP "Enable ZIP archive support using minizip" ON)
option(GODOT_BROTLI "Enable Brotli decompression and WOFF2 fonts" ON)
option(GODOT_VULKAN "Enable the Vulkan rendering driver" ON)
option(GODOT_OPENGL3 "Enable the OpenGL/GLES3 rendering driver" ON)
option(GODOT_D3D12 "Enable the Direct3D 12 rendering driver" OFF)
option(GODOT_METAL "Enable the Metal rendering driver" OFF)
option(GODOT_USE_VOLK "Use the volk library to load Vulkan dynamically" ON)
option(GODOT_ANGLE "Enable the ANGLE rendering driver" ON)
option(GODOT_SDL "Enable the SDL3 input driver" ON)
option(GODOT_ACCESSKIT "Enable the AccessKit driver" ON)
set(GODOT_ACCESSKIT_SDK_PATH "${CMAKE_BINARY_DIR}/accesskit" CACHE STRING "Path to the AccessKit C SDK")

# Debug / diagnostics.
option(GODOT_WERROR "Treat compiler warnings as errors" OFF)
option(GODOT_USE_PRECISE_MATH_CHECKS "Math checks use very precise epsilon" OFF)
option(GODOT_STRICT_CHECKS "Enforce stricter checks" OFF)
option(GODOT_DISABLE_EXCEPTIONS "Force disabling exception handling code" ON)
set(GODOT_WARNINGS "all" CACHE STRING "Level of compilation warnings (extra|all|moderate|no)")

# Feature trimming (all defaults match the release build).
option(GODOT_DISABLE_3D "Disable 3D nodes" OFF)
option(GODOT_DISABLE_ADVANCED_GUI "Disable advanced GUI nodes" OFF)
option(GODOT_DISABLE_PHYSICS_2D "Disable 2D physics" OFF)
option(GODOT_DISABLE_PHYSICS_3D "Disable 3D physics" OFF)
option(GODOT_DISABLE_NAVIGATION_2D "Disable 2D navigation" OFF)
option(GODOT_DISABLE_NAVIGATION_3D "Disable 3D navigation" OFF)
option(GODOT_DISABLE_XR "Disable XR" OFF)
option(GODOT_DISABLE_OVERRIDES "Disable project settings overrides" OFF)

# Misc.
option(GODOT_NO_EDITOR_SPLASH "Don't use the custom splash screen for the editor" ON)
option(GODOT_ENGINE_UPDATE_CHECK "Enable engine update checks" ON)
option(GODOT_TESTS "Build the unit tests" OFF)
set(GODOT_SCRIPT_AES256_ENCRYPTION_KEY "" CACHE STRING "Custom AES256 script encryption key")

# LinuxBSD platform options (matches platform/linuxbsd/detect.py defaults).
option(GODOT_ALSA "Use ALSA" ON)
option(GODOT_PULSEAUDIO "Use PulseAudio" ON)
option(GODOT_DBUS "Use D-Bus for screensaver/portal settings" ON)
option(GODOT_SPEECHD "Use Speech Dispatcher for Text-to-Speech" ON)
option(GODOT_FONTCONFIG "Use fontconfig for system fonts" ON)
option(GODOT_UDEV "Use udev for gamepad connection callbacks" ON)
option(GODOT_X11 "Enable X11 display" ON)
option(GODOT_WAYLAND "Enable Wayland display" OFF)
option(GODOT_LIBDECOR "Enable libdecor support" ON)
option(GODOT_TOUCH "Enable touch events" ON)
option(GODOT_EXECINFO "Use libexecinfo where glibc is unavailable" OFF)
option(GODOT_USE_SOWRAP "Dynamically load system libraries" ON)
option(GODOT_USE_STATIC_CPP "Link libgcc and libstdc++ statically" OFF)
option(GODOT_USE_LLVM "Use the LLVM compiler" OFF)

# Thirdparty (all builtin by default).
set(GODOT_BUILTIN_DEFAULTS ON)
foreach(_bt
        brotli certs clipper2 embree enet freetype msdfgen glslang graphite harfbuzz
        sdl icu4c libjpeg_turbo libogg libpng libtheora libvorbis libwebp wslay
        mbedtls miniupnpc openxr pcre2 pcre2_with_jit recastnavigation rvo2_2d
        rvo2_3d xatlas zlib zstd)
    string(TOUPPER "${_bt}" _bt_up)
    option(GODOT_BUILTIN_${_bt_up} "Use the built-in ${_bt} library" ON)
endforeach()

# Derived flags (mirrors options.cmake).
set(_godot_editor_build ON)
set(_godot_debug_features ON)
set(_godot_opt_level "none")       # GODOT_DEV_BUILD => -O0
set(_godot_debug_symbols ON)       # GODOT_DEV_BUILD => debug symbols on
set(_godot_lto_auto OFF)

# AccessKit requires its external SDK; disable the driver when it is absent.
if(GODOT_ACCESSKIT AND NOT EXISTS "${GODOT_ACCESSKIT_SDK_PATH}/include/accesskit.h")
    message(STATUS "AccessKit SDK not found - disabling the accesskit driver.")
    set(GODOT_ACCESSKIT OFF)
endif()

# Output suffix: .<platform>.<target>[.dev][.double].<arch>.bin
set(GODOT_SUFFIX ".${GODOT_PLATFORM}.${GODOT_TARGET}")
string(APPEND GODOT_SUFFIX ".dev")
if(GODOT_PRECISION STREQUAL "double")
    string(APPEND GODOT_SUFFIX ".double")
endif()
string(APPEND GODOT_SUFFIX ".${GODOT_ARCH}")
if(NOT GODOT_THREADS)
    string(APPEND GODOT_SUFFIX ".nothreads")
endif()
if(GODOT_EXTRA_SUFFIX)
    string(APPEND GODOT_SUFFIX ".${GODOT_EXTRA_SUFFIX}")
endif()
set(GODOT_PROGRAM_NAME "godot${GODOT_SUFFIX}")

# Sanity checks (only the ported configuration is supported right now).
if(NOT GODOT_PLATFORM STREQUAL "linuxbsd")
    message(FATAL_ERROR "Only GODOT_PLATFORM=linuxbsd is ported at this time.")
endif()
if(NOT GODOT_ARCH STREQUAL "x86_64")
    message(FATAL_ERROR "Only GODOT_ARCH=x86_64 is ported at this time.")
endif()

find_package(PkgConfig REQUIRED)
find_package(Python3 REQUIRED COMPONENTS Interpreter)
find_package(Threads REQUIRED)

message(STATUS "Godot DEBUG build: platform=${GODOT_PLATFORM} target=${GODOT_TARGET} arch=${GODOT_ARCH}")
message(STATUS "Godot DEBUG build: optimize=${_godot_opt_level} debug_symbols=${_godot_debug_symbols} program=${GODOT_PROGRAM_NAME}")

# =============================================================================
# Global compile options (mirrors godot_options.cmake with dev_build active)
# =============================================================================
add_library(godot_options INTERFACE)
add_library(godot::options ALIAS godot_options)

target_include_directories(godot_options INTERFACE
    "${CMAKE_SOURCE_DIR}"
    "${CMAKE_BINARY_DIR}"
    "${CMAKE_SOURCE_DIR}/platform/linuxbsd"
)

if(GODOT_OPENGL3)
    target_include_directories(godot_options INTERFACE
        "${CMAKE_SOURCE_DIR}/thirdparty/glad"
    )
endif()
if(GODOT_VULKAN)
    target_include_directories(godot_options INTERFACE
        "${CMAKE_SOURCE_DIR}/thirdparty/vulkan/include"
    )
endif()

if(GODOT_BUILTIN_LIBPNG)
    target_include_directories(godot_options INTERFACE
        "${CMAKE_SOURCE_DIR}/thirdparty/libpng"
    )
endif()
if(GODOT_BUILTIN_ZLIB)
    target_include_directories(godot_options INTERFACE
        "${CMAKE_SOURCE_DIR}/thirdparty/zlib"
    )
endif()

if(GODOT_USE_SOWRAP)
    target_include_directories(godot_options INTERFACE
        "${CMAKE_SOURCE_DIR}/thirdparty/linuxbsd_headers"
    )
    if(GODOT_WAYLAND)
        target_include_directories(godot_options INTERFACE
            "${CMAKE_SOURCE_DIR}/thirdparty/linuxbsd_headers/wayland"
        )
        if(GODOT_LIBDECOR)
            target_include_directories(godot_options INTERFACE
                "${CMAKE_SOURCE_DIR}/thirdparty/linuxbsd_headers/libdecor-0"
            )
        endif()
    endif()
endif()

# Core platform defines.
target_compile_definitions(godot_options INTERFACE
    LINUXBSD_ENABLED
    UNIX_ENABLED
    _FILE_OFFSET_BITS=64
)

if(GODOT_OPENGL3)
    target_compile_definitions(godot_options INTERFACE GLES3_ENABLED GLAD_ENABLED EGL_ENABLED GLAD_GLES2)
endif()
if(GODOT_VULKAN)
    target_compile_definitions(godot_options INTERFACE VULKAN_ENABLED RD_ENABLED)
endif()
if(GODOT_TOUCH)
    target_compile_definitions(godot_options INTERFACE TOUCH_ENABLED)
endif()
if(GODOT_USE_SOWRAP)
    target_compile_definitions(godot_options INTERFACE SOWRAP_ENABLED)
endif()
if(GODOT_X11)
    target_compile_definitions(godot_options INTERFACE X11_ENABLED)
endif()
if(GODOT_WAYLAND)
    target_compile_definitions(godot_options INTERFACE WAYLAND_ENABLED)
    target_link_libraries(godot_options INTERFACE rt)
endif()
if(GODOT_ACCESSKIT)
    target_include_directories(godot_options INTERFACE
        "${GODOT_ACCESSKIT_SDK_PATH}/include"
    )
    target_link_directories(godot_options INTERFACE
        "${GODOT_ACCESSKIT_SDK_PATH}/lib/linux/x86_64/static"
    )
    target_compile_definitions(godot_options INTERFACE ACCESSKIT_ENABLED)
endif()
if(GODOT_ALSA AND GODOT_USE_SOWRAP)
    target_compile_definitions(godot_options INTERFACE ALSA_ENABLED ALSAMIDI_ENABLED)
endif()
if(GODOT_PULSEAUDIO AND GODOT_USE_SOWRAP)
    target_compile_definitions(godot_options INTERFACE PULSEAUDIO_ENABLED _REENTRANT)
endif()
if(GODOT_FONTCONFIG AND GODOT_USE_SOWRAP)
    target_compile_definitions(godot_options INTERFACE FONTCONFIG_ENABLED)
endif()
if(GODOT_DBUS AND GODOT_USE_SOWRAP)
    target_compile_definitions(godot_options INTERFACE DBUS_ENABLED)
endif()
if(GODOT_SPEECHD AND GODOT_USE_SOWRAP)
    target_compile_definitions(godot_options INTERFACE SPEECHD_ENABLED)
endif()

target_compile_features(godot_options INTERFACE c_std_17 cxx_std_17)
set_target_properties(godot_options PROPERTIES
    C_STANDARD 17
    C_STANDARD_REQUIRED ON
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
    CXX_EXTENSIONS ON
)

# --- Preprocessor defines (debug build: DEV_ENABLED + DEBUG_ENABLED) ---
set(_godot_defines
    THREADS_ENABLED
    MINIZIP_ENABLED
    BROTLI_ENABLED
    OVERRIDE_ENABLED
    OVERRIDE_PATH_ENABLED
    NDEBUG
    ZSTD_STATIC_LINKING_ONLY
    CLIPPER2_ENABLED
    _LIBCPP_REMOVE_TRANSITIVE_INCLUDES
)

if(_godot_editor_build)
    list(APPEND _godot_defines TOOLS_ENABLED ENGINE_UPDATE_CHECK_ENABLED)
    if(GODOT_NO_EDITOR_SPLASH)
        list(APPEND _godot_defines NO_EDITOR_SPLASH)
    endif()
endif()

if(_godot_debug_features)
    list(APPEND _godot_defines DEBUG_ENABLED)
endif()

if(GODOT_DEV_BUILD)
    list(APPEND _godot_defines DEV_ENABLED)
endif()

if(NOT GODOT_DEPRECATED)
    list(APPEND _godot_defines DISABLE_DEPRECATED)
endif()

if(GODOT_PRECISION STREQUAL "double")
    list(APPEND _godot_defines REAL_T_IS_DOUBLE)
endif()

if(GODOT_STRICT_CHECKS)
    list(APPEND _godot_defines STRICT_CHECKS)
endif()

if(GODOT_USE_PRECISE_MATH_CHECKS)
    list(APPEND _godot_defines PRECISE_MATH_CHECKS)
endif()

if(GODOT_SDL)
    list(APPEND _godot_defines SDL_ENABLED)
endif()

if(NOT GODOT_DISABLE_OVERRIDES)
    list(APPEND _godot_defines OVERRIDE_ENABLED)
endif()

if(GODOT_DISABLE_3D)
    list(APPEND _godot_defines _3D_DISABLED)
endif()
if(GODOT_DISABLE_ADVANCED_GUI)
    list(APPEND _godot_defines ADVANCED_GUI_DISABLED)
endif()
if(GODOT_DISABLE_PHYSICS_2D)
    list(APPEND _godot_defines PHYSICS_2D_DISABLED)
endif()
if(GODOT_DISABLE_PHYSICS_3D)
    list(APPEND _godot_defines PHYSICS_3D_DISABLED)
endif()
if(GODOT_DISABLE_NAVIGATION_2D)
    list(APPEND _godot_defines NAVIGATION_2D_DISABLED)
endif()
if(GODOT_DISABLE_NAVIGATION_3D)
    list(APPEND _godot_defines NAVIGATION_3D_DISABLED)
endif()
if(GODOT_DISABLE_XR)
    list(APPEND _godot_defines XR_DISABLED)
endif()

target_compile_definitions(godot_options INTERFACE ${_godot_defines})

# --- Compiler flags (debug build: -O0, -g3) ---
set(_godot_cflags
    -pipe
    -ffp-contract=off
    -fno-diagnostics-color
)
list(APPEND _godot_cflags -msse4.2 -mpopcnt)

# Dev builds always use -O0.
set(_godot_opt_flags -O0)

# Debug symbols: -g3 for dev builds.
list(APPEND _godot_cflags -g3)
if(GODOT_DEBUG_PATHS_RELATIVE)
    list(APPEND _godot_cflags "-ffile-prefix-map=${CMAKE_SOURCE_DIR}=.")
endif()

# Exceptions.
if(GODOT_DISABLE_EXCEPTIONS)
    set(_godot_cxxflags -fno-exceptions)
endif()

# Warnings.
set(_godot_warn_cflags "")
if(GODOT_WARNINGS STREQUAL "extra")
    set(_godot_warn_cflags
        -Wall -Wextra -Wwrite-strings -Wno-unused-parameter
        -Wshadow -Wno-misleading-indentation -Wenum-conversion
    )
elseif(GODOT_WARNINGS STREQUAL "all")
    set(_godot_warn_cflags
        -Wall -Wshadow -Wno-misleading-indentation -Wenum-conversion
    )
elseif(GODOT_WARNINGS STREQUAL "moderate")
    set(_godot_warn_cflags
        -Wall -Wno-unused -Wshadow -Wno-misleading-indentation -Wenum-conversion
    )
else()
    set(_godot_warn_cflags -w)
endif()

if(GODOT_WERROR)
    list(APPEND _godot_warn_cflags -Werror)
endif()

target_compile_options(godot_options INTERFACE
    ${_godot_cflags}
    ${_godot_opt_flags}
    ${_godot_warn_cflags}
    $<$<COMPILE_LANGUAGE:CXX>:${_godot_cxxflags}>
)

# --- Link flags (debug build: keep symbols, never strip) ---
set(_godot_linkflags "")
list(APPEND _godot_linkflags ${_godot_opt_flags})

target_link_options(godot_options INTERFACE ${_godot_linkflags})

# Thirdparty code compiles with warnings disabled.
add_library(godot_thirdparty_options INTERFACE)
add_library(godot::thirdparty_options ALIAS godot_thirdparty_options)
target_link_libraries(godot_thirdparty_options INTERFACE godot_options)
target_compile_options(godot_thirdparty_options INTERFACE -w)

# =============================================================================
# Code generation rules (mirrors cmake/generated.cmake)
# =============================================================================

set(_CODEGEN_DRIVER "${CMAKE_SOURCE_DIR}/cmake/godot_codegen.py")
set(_CODEGEN_JSON_DIR "${CMAKE_BINARY_DIR}/cmake_codegen")
file(MAKE_DIRECTORY "${_CODEGEN_JSON_DIR}")

set(GODOT_GENERATED_SOURCES "")
set(GODOT_GENERATED_HEADERS "")

# Accumulator for all generated .cpp (compiled) and .gen.h (headers).
function(_cg_track out)
    if(out MATCHES "\\.gen\\.cpp$")
        set(GODOT_GENERATED_SOURCES ${GODOT_GENERATED_SOURCES} "${out}" PARENT_SCOPE)
    else()
        set(GODOT_GENERATED_HEADERS ${GODOT_GENERATED_HEADERS} "${out}" PARENT_SCOPE)
    endif()
endfunction()

# Serialize a list of items into a JSON array of {"kind":..., "value":...}.
function(_cg_json_array out_var)
    set(_joined "")
    set(_first TRUE)
    foreach(item IN LISTS ARGN)
        if(NOT _first)
            string(APPEND _joined ",")
        endif()
        string(APPEND _joined "${item}")
        set(_first FALSE)
    endforeach()
    set(${out_var} "[${_joined}]" PARENT_SCOPE)
endfunction()

# godot_codegen(<generator> <json_tag>
#   OUTPUTS <path>...
#   PATH_INPUTS <path>...
#   CONTENT_INPUTS <string>...
#   JSON_INPUTS <json>...
#   ENV <json-object>
# )
function(godot_codegen generator json_tag)
    set(options "")
    set(oneValueArgs "")
    set(multiValueArgs OUTPUTS PATH_INPUTS CONTENT_INPUTS JSON_INPUTS EXTRA_DEPS ENV)
    cmake_parse_arguments(CG "" "" "${multiValueArgs}" ${ARGN})

    set(_out_items "")
    foreach(o IN LISTS CG_OUTPUTS)
        list(APPEND _out_items "{\"kind\":\"path\",\"value\":\"${o}\"}")
    endforeach()
    _cg_json_array(_out_json ${_out_items})

    set(_in_items "")
    foreach(i IN LISTS CG_PATH_INPUTS)
        list(APPEND _in_items "{\"kind\":\"path\",\"value\":\"${i}\"}")
    endforeach()
    foreach(i IN LISTS CG_CONTENT_INPUTS)
        string(REPLACE "\\" "\\\\" _esc "${i}")
        string(REPLACE "\"" "\\\"" _esc "${_esc}")
        list(APPEND _in_items "{\"kind\":\"content\",\"value\":\"${_esc}\"}")
    endforeach()
    foreach(i IN LISTS CG_JSON_INPUTS)
        list(APPEND _in_items "{\"kind\":\"json\",\"value\":${i}}")
    endforeach()
    _cg_json_array(_in_json ${_in_items})

    if(NOT CG_ENV)
        set(CG_ENV "{}")
    endif()

    set(_json "${_CODEGEN_JSON_DIR}/${json_tag}.json")
    file(WRITE "${_json}"
        "{\"outputs\":${_out_json},\"inputs\":${_in_json},\"env\":${CG_ENV},\"base_dir\":\"${CMAKE_SOURCE_DIR}\"}\n")

    add_custom_command(
        OUTPUT ${CG_OUTPUTS}
        COMMAND ${Python3_EXECUTABLE} "${_CODEGEN_DRIVER}" ${generator} "${_json}"
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        DEPENDS ${CG_PATH_INPUTS} ${CG_EXTRA_DEPS} "${_CODEGEN_DRIVER}" "${CMAKE_SOURCE_DIR}/methods.py"
        COMMENT "Generating ${json_tag}"
        VERBATIM
    )

    get_property(_reg GLOBAL PROPERTY GODOT_CODEGEN_OUTPUTS)
    foreach(_o IN LISTS CG_OUTPUTS)
        list(APPEND _reg "${_o}")
    endforeach()
    set_property(GLOBAL PROPERTY GODOT_CODEGEN_OUTPUTS "${_reg}")
endfunction()

# =============================================================================
# core/
# =============================================================================
godot_codegen(version_info version_generated
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/version_generated.gen.h")
_cg_track("${CMAKE_SOURCE_DIR}/core/version_generated.gen.h")

godot_codegen(version_hash version_hash
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/version_hash.gen.cpp")
_cg_track("${CMAKE_SOURCE_DIR}/core/version_hash.gen.cpp")

godot_codegen(encryption_key script_encryption_key
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/script_encryption_key.gen.cpp"
    ENV "{\"encryption_key\":\"${GODOT_SCRIPT_AES256_ENCRYPTION_KEY}\"}")
_cg_track("${CMAKE_SOURCE_DIR}/core/script_encryption_key.gen.cpp")

godot_codegen(disabled_class disabled_classes
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/disabled_classes.gen.h"
    ENV "{\"disabled_classes\":[]}")
_cg_track("${CMAKE_SOURCE_DIR}/core/disabled_classes.gen.h")

if(GODOT_BUILTIN_CERTS)
    set(_builtin_certs_json "true")
else()
    set(_builtin_certs_json "false")
endif()
godot_codegen(make_certs_header certs_compressed
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/io/certs_compressed.gen.h"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/thirdparty/certs/ca-bundle.crt"
    ENV "{\"builtin_certs\":${_builtin_certs_json},\"system_certs_path\":\"${GODOT_SYSTEM_CERTS_PATH}\"}")
_cg_track("${CMAKE_SOURCE_DIR}/core/io/certs_compressed.gen.h")

godot_codegen(make_authors_header authors
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/authors.gen.h"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/AUTHORS.md")
_cg_track("${CMAKE_SOURCE_DIR}/core/authors.gen.h")

godot_codegen(make_donors_header donors
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/donors.gen.h"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/DONORS.md")
_cg_track("${CMAKE_SOURCE_DIR}/core/donors.gen.h")

godot_codegen(make_license_header license
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/license.gen.h"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/COPYRIGHT.txt" "${CMAKE_SOURCE_DIR}/LICENSE.txt")
_cg_track("${CMAKE_SOURCE_DIR}/core/license.gen.h")

godot_codegen(make_default_controller_mappings default_controller_mappings
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/input/default_controller_mappings.gen.cpp"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/core/input/gamecontrollerdb.txt"
               "${CMAKE_SOURCE_DIR}/core/input/godotcontrollerdb.txt")
_cg_track("${CMAKE_SOURCE_DIR}/core/input/default_controller_mappings.gen.cpp")

godot_codegen(profiler_gen profiling
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/profiling/profiling.gen.h")
_cg_track("${CMAKE_SOURCE_DIR}/core/profiling/profiling.gen.h")

godot_codegen(make_virtuals gdvirtual
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/object/gdvirtual.gen.h"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/core/object/make_virtuals.py")
_cg_track("${CMAKE_SOURCE_DIR}/core/object/gdvirtual.gen.h")

godot_codegen(make_wrappers ext_wrappers
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/extension/ext_wrappers.gen.h"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/core/extension/make_wrappers.py")
_cg_track("${CMAKE_SOURCE_DIR}/core/extension/ext_wrappers.gen.h")

godot_codegen(make_interface_dumper gdextension_interface_dump
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/extension/gdextension_interface_dump.gen.h"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/core/extension/gdextension_interface.json"
               "${CMAKE_SOURCE_DIR}/core/extension/make_interface_dumper.py")
_cg_track("${CMAKE_SOURCE_DIR}/core/extension/gdextension_interface_dump.gen.h")

godot_codegen(make_interface_header gdextension_interface
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/extension/gdextension_interface.gen.h"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/core/extension/gdextension_interface.json"
               "${CMAKE_SOURCE_DIR}/core/extension/make_interface_header.py")
_cg_track("${CMAKE_SOURCE_DIR}/core/extension/gdextension_interface.gen.h")

# =============================================================================
# shaders (RD + GLES3)
# =============================================================================

# godot_rd_shaders(<dir> [EXTRA_INCLUDES <f>...] [HEADERS_FROM_INCLUDES])
function(godot_rd_shaders dir)
    cmake_parse_arguments(RS "HEADERS_FROM_INCLUDES" "" "EXTRA_INCLUDES" ${ARGN})
    file(GLOB _all "${dir}/*.glsl")
    set(_inc "")
    set(_shaders "")
    foreach(f IN LISTS _all)
        get_filename_component(_name "${f}" NAME)
        if(_name MATCHES "_inc\\.glsl$")
            list(APPEND _inc "${f}")
        else()
            list(APPEND _shaders "${f}")
        endif()
    endforeach()
    # Top-level shaders also emit raw headers for their include files.
    if(RS_HEADERS_FROM_INCLUDES)
        foreach(f IN LISTS _inc)
            get_filename_component(_base "${f}" NAME)
            set(_out "${f}.gen.h")
            godot_codegen(raw_glsl "raw_${_base}"
                OUTPUTS "${_out}"
                PATH_INPUTS "${f}"
                EXTRA_DEPS "${CMAKE_SOURCE_DIR}/glsl_builders.py")
            set(GODOT_GENERATED_HEADERS ${GODOT_GENERATED_HEADERS} "${_out}" PARENT_SCOPE)
        endforeach()
    endif()
    # Parent-directory includes.
    get_filename_component(_parent "${dir}" DIRECTORY)
    file(GLOB _pinc "${_parent}/*_inc.glsl")
    list(APPEND _inc ${_pinc})
    if(RS_EXTRA_INCLUDES)
        list(APPEND _inc ${RS_EXTRA_INCLUDES})
    endif()

    foreach(f IN LISTS _shaders)
        get_filename_component(_base "${f}" NAME)
        set(_out "${f}.gen.h")
        godot_codegen(rd_glsl "rd_${_base}"
            OUTPUTS "${_out}"
            PATH_INPUTS "${f}"
            EXTRA_DEPS ${_inc} "${CMAKE_SOURCE_DIR}/glsl_builders.py")
        set(GODOT_GENERATED_HEADERS ${GODOT_GENERATED_HEADERS} "${_out}" PARENT_SCOPE)
    endforeach()
endfunction()

# godot_gles3_shaders(<dir> [SHADER_LIST <name>...])
function(godot_gles3_shaders dir)
    cmake_parse_arguments(GS "" "" "SHADER_LIST" ${ARGN})
    file(GLOB _inc "${dir}/*_inc.glsl")
    set(_names ${GS_SHADER_LIST})
    if(NOT _names)
        file(GLOB _all "${dir}/*.glsl")
        foreach(f IN LISTS _all)
            get_filename_component(_name "${f}" NAME)
            if(NOT _name MATCHES "_inc\\.glsl$")
                list(APPEND _names "${_name}")
            endif()
        endforeach()
    endif()
    foreach(_name IN LISTS _names)
        set(_f "${dir}/${_name}")
        set(_out "${_f}.gen.h")
        godot_codegen(gles3_glsl "gles3_${_name}"
            OUTPUTS "${_out}"
            PATH_INPUTS "${_f}"
            EXTRA_DEPS ${_inc} "${CMAKE_SOURCE_DIR}/gles3_builders.py")
        set(GODOT_GENERATED_HEADERS ${GODOT_GENERATED_HEADERS} "${_out}" PARENT_SCOPE)
    endforeach()
endfunction()

if(GODOT_VULKAN)
    godot_rd_shaders("${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/shaders" HEADERS_FROM_INCLUDES)
    godot_rd_shaders("${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/shaders/environment")
    godot_rd_shaders("${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/shaders/forward_clustered")
    godot_rd_shaders("${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/shaders/forward_mobile")
    godot_rd_shaders("${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/shaders/effects")
    file(GLOB _fsr2_inc "${CMAKE_SOURCE_DIR}/thirdparty/amd-fsr2/shaders/*.h"
                       "${CMAKE_SOURCE_DIR}/thirdparty/amd-fsr2/shaders/*.glsl")
    godot_rd_shaders("${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/shaders/effects/fsr2" EXTRA_INCLUDES ${_fsr2_inc})
endif()

if(GODOT_OPENGL3)
    godot_gles3_shaders("${CMAKE_SOURCE_DIR}/drivers/gles3/shaders" SHADER_LIST
        canvas.glsl feed.glsl scene.glsl sky.glsl canvas_occlusion.glsl
        canvas_sdf.glsl particles.glsl particles_copy.glsl skeleton.glsl tex_blit.glsl)
    godot_gles3_shaders("${CMAKE_SOURCE_DIR}/drivers/gles3/shaders/effects")
endif()

# =============================================================================
# scene/theme
# =============================================================================
godot_codegen(scene_theme_fonts default_font
    OUTPUTS "${CMAKE_SOURCE_DIR}/scene/theme/default_font.gen.h"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/thirdparty/fonts/OpenSans_SemiBold.woff2")
_cg_track("${CMAKE_SOURCE_DIR}/scene/theme/default_font.gen.h")

file(GLOB _theme_icons "${CMAKE_SOURCE_DIR}/scene/theme/icons/*.svg")
godot_codegen(default_theme_icons default_theme_icons
    OUTPUTS "${CMAKE_SOURCE_DIR}/scene/theme/default_theme_icons.gen.h"
    PATH_INPUTS ${_theme_icons})
_cg_track("${CMAKE_SOURCE_DIR}/scene/theme/default_theme_icons.gen.h")

# =============================================================================
# editor (editor-specific generated files needing module lists live further down)
# =============================================================================
if(_godot_editor_build)
    file(GLOB _fonts
        "${CMAKE_SOURCE_DIR}/thirdparty/fonts/*.ttf"
        "${CMAKE_SOURCE_DIR}/thirdparty/fonts/*.otf"
        "${CMAKE_SOURCE_DIR}/thirdparty/fonts/*.woff"
        "${CMAKE_SOURCE_DIR}/thirdparty/fonts/*.woff2")
    list(SORT _fonts)
    godot_codegen(editor_fonts builtin_fonts
        OUTPUTS "${CMAKE_SOURCE_DIR}/editor/themes/builtin_fonts.gen.h"
        PATH_INPUTS ${_fonts})
    _cg_track("${CMAKE_SOURCE_DIR}/editor/themes/builtin_fonts.gen.h")

    file(GLOB _editor_icons "${CMAKE_SOURCE_DIR}/editor/icons/*.svg")
    godot_codegen(editor_icons editor_icons
        OUTPUTS "${CMAKE_SOURCE_DIR}/editor/themes/editor_icons.gen.h"
        PATH_INPUTS ${_editor_icons})
    _cg_track("${CMAKE_SOURCE_DIR}/editor/themes/editor_icons.gen.h")
endif()

# =============================================================================
# main
# =============================================================================
godot_codegen(make_splash splash
    OUTPUTS "${CMAKE_SOURCE_DIR}/main/splash.gen.h"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/main/splash.png")
_cg_track("${CMAKE_SOURCE_DIR}/main/splash.gen.h")

if(_godot_editor_build AND NOT GODOT_NO_EDITOR_SPLASH)
    godot_codegen(make_splash_editor splash_editor
        OUTPUTS "${CMAKE_SOURCE_DIR}/main/splash_editor.gen.h"
        PATH_INPUTS "${CMAKE_SOURCE_DIR}/main/splash_editor.png")
    _cg_track("${CMAKE_SOURCE_DIR}/main/splash_editor.gen.h")
endif()

godot_codegen(make_app_icon app_icon
    OUTPUTS "${CMAKE_SOURCE_DIR}/main/app_icon.gen.h"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/main/app_icon.png")
_cg_track("${CMAKE_SOURCE_DIR}/main/app_icon.gen.h")

# =============================================================================
# servers/rendering: LTC lookup table
# =============================================================================
godot_codegen(make_ltc_lut ltc_lut
    OUTPUTS "${CMAKE_SOURCE_DIR}/servers/rendering/storage/ltc_lut.gen.h"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/servers/rendering/storage/make_ltc_lut.py"
               "${CMAKE_SOURCE_DIR}/servers/rendering/storage/ltc/ltc_lut1.dds"
               "${CMAKE_SOURCE_DIR}/servers/rendering/storage/ltc/ltc_lut2.dds")
_cg_track("${CMAKE_SOURCE_DIR}/servers/rendering/storage/ltc_lut.gen.h")

# =============================================================================
# platform export icons (SVG -> *_svg.gen.h)
# =============================================================================
set(GODOT_EXPORT_ICON_HEADERS "")
foreach(_p IN ITEMS android ios linuxbsd macos visionos web windows)
    file(GLOB _svgs "${CMAKE_SOURCE_DIR}/platform/${_p}/export/*.svg")
    foreach(_svg IN LISTS _svgs)
        get_filename_component(_base "${_svg}" NAME)
        string(REGEX REPLACE "\\.svg$" "_svg.gen.h" _out "${_svg}")
        godot_codegen(export_icon "export_icon_${_p}_${_base}"
            OUTPUTS "${_out}"
            PATH_INPUTS "${_svg}")
        list(APPEND GODOT_EXPORT_ICON_HEADERS "${_out}")
    endforeach()
endforeach()

# =============================================================================
# modules: enabled list + registration (needs the detected module set)
# =============================================================================
execute_process(
    COMMAND ${Python3_EXECUTABLE} "${CMAKE_SOURCE_DIR}/cmake/detect_modules.py"
    OUTPUT_VARIABLE _modules_json
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE _modules_rc
)
if(NOT _modules_rc EQUAL 0)
    message(FATAL_ERROR "detect_modules.py failed with code ${_modules_rc}")
endif()
set(_modules_json_full "${_modules_json}")

string(REGEX MATCH "\"modules\":[ \t]*\\{[^}]*\\}" _mods_obj "${_modules_json_full}")
string(REGEX MATCH "\"doc_class_path\":[ \t]*\\{[^}]*\\}" _docpath_obj "${_modules_json_full}")
string(REGEX REPLACE "^\"modules\":[ \t]*" "" GODOT_MODULES_DETECTED "${_mods_obj}")
string(REGEX REPLACE "^\"doc_class_path\":[ \t]*" "" GODOT_DOC_CLASS_PATH "${_docpath_obj}")

# Expose per-module enabled flags, e.g. GODOT_MODULE_GDSCRIPT_ENABLED.
string(REGEX MATCHALL "\"([A-Za-z0-9_]+)\":" _mod_keys "${GODOT_MODULES_DETECTED}")
foreach(_k IN LISTS _mod_keys)
    string(REGEX REPLACE "\":$" "" _name "${_k}")
    string(REGEX REPLACE "^\"" "" _name "${_name}")
    string(TOUPPER "${_name}" _up)
    set(GODOT_MODULE_${_up}_ENABLED ON)
    list(APPEND GODOT_MODULES_DETECTED_NAMES "${_name}")
endforeach()

godot_codegen(modules_enabled modules_enabled
    OUTPUTS "${CMAKE_SOURCE_DIR}/modules/modules_enabled.gen.h"
    ENV "{\"modules_detected\":${GODOT_MODULES_DETECTED}}")
_cg_track("${CMAKE_SOURCE_DIR}/modules/modules_enabled.gen.h")

godot_codegen(register_module_types register_module_types
    OUTPUTS "${CMAKE_SOURCE_DIR}/modules/register_module_types.gen.cpp"
    ENV "{\"modules_detected\":${GODOT_MODULES_DETECTED}}")
_cg_track("${CMAKE_SOURCE_DIR}/modules/register_module_types.gen.cpp")

# =============================================================================
# Aggregation target: forces generation of every tracked generated file.
# =============================================================================
get_property(_all_codegen_outputs GLOBAL PROPERTY GODOT_CODEGEN_OUTPUTS)
add_custom_target(godot_generated DEPENDS ${_all_codegen_outputs})

# =============================================================================
# Core thirdparty sources (mirrors cmake/thirdparty/core_thirdparty.cmake)
# Compiled into the core library with warnings disabled.
# =============================================================================

# Misc thirdparty.
set(_misc_sources
    thirdparty/misc/fastlz.c
    thirdparty/misc/r128.c
    thirdparty/misc/smaz.c
    thirdparty/misc/pcg.cpp
    thirdparty/misc/polypartition.cpp
    thirdparty/misc/smolv.cpp
)

# Brotli
set(_brotli_sources "")
if(GODOT_BROTLI AND GODOT_BUILTIN_BROTLI)
    set(_brotli_sources
        thirdparty/brotli/common/constants.c
        thirdparty/brotli/common/context.c
        thirdparty/brotli/common/dictionary.c
        thirdparty/brotli/common/platform.c
        thirdparty/brotli/common/shared_dictionary.c
        thirdparty/brotli/common/transform.c
        thirdparty/brotli/dec/bit_reader.c
        thirdparty/brotli/dec/decode.c
        thirdparty/brotli/dec/huffman.c
        thirdparty/brotli/dec/prefix.c
        thirdparty/brotli/dec/state.c
        thirdparty/brotli/dec/static_init.c
    )
endif()

# Clipper2
set(_clipper2_sources "")
if(GODOT_BUILTIN_CLIPPER2)
    set(_clipper2_sources
        thirdparty/clipper2/src/clipper.engine.cpp
        thirdparty/clipper2/src/clipper.offset.cpp
        thirdparty/clipper2/src/clipper.rectclip.cpp
    )
endif()

# zlib
set(_zlib_sources "")
if(GODOT_BUILTIN_ZLIB)
    set(_zlib_sources
        thirdparty/zlib/adler32.c
        thirdparty/zlib/compress.c
        thirdparty/zlib/crc32.c
        thirdparty/zlib/deflate.c
        thirdparty/zlib/inffast.c
        thirdparty/zlib/inflate.c
        thirdparty/zlib/inftrees.c
        thirdparty/zlib/trees.c
        thirdparty/zlib/uncompr.c
        thirdparty/zlib/zutil.c
    )
endif()

# minizip (always built from source; Godot-modified)
set(_minizip_sources
    thirdparty/minizip/ioapi.c
    thirdparty/minizip/unzip.c
    thirdparty/minizip/zip.c
)

# zstd
set(_zstd_sources "")
if(GODOT_BUILTIN_ZSTD)
    set(_zstd_sources
        thirdparty/zstd/common/debug.c
        thirdparty/zstd/common/entropy_common.c
        thirdparty/zstd/common/error_private.c
        thirdparty/zstd/common/fse_decompress.c
        thirdparty/zstd/common/pool.c
        thirdparty/zstd/common/threading.c
        thirdparty/zstd/common/xxhash.c
        thirdparty/zstd/common/zstd_common.c
        thirdparty/zstd/compress/fse_compress.c
        thirdparty/zstd/compress/hist.c
        thirdparty/zstd/compress/huf_compress.c
        thirdparty/zstd/compress/zstd_double_fast.c
        thirdparty/zstd/compress/zstd_fast.c
        thirdparty/zstd/compress/zstd_lazy.c
        thirdparty/zstd/compress/zstd_ldm.c
        thirdparty/zstd/compress/zstd_opt.c
        thirdparty/zstd/compress/zstd_preSplit.c
        thirdparty/zstd/compress/zstdmt_compress.c
        thirdparty/zstd/compress/zstd_compress.c
        thirdparty/zstd/compress/zstd_compress_literals.c
        thirdparty/zstd/compress/zstd_compress_sequences.c
        thirdparty/zstd/compress/zstd_compress_superblock.c
        thirdparty/zstd/decompress/huf_decompress.c
        thirdparty/zstd/decompress/zstd_ddict.c
        thirdparty/zstd/decompress/zstd_decompress_block.c
        thirdparty/zstd/decompress/zstd_decompress.c
    )
    # x86_64 uses the AMD64 assembly decompressor (matches SCU platforms list).
    if(GODOT_ARCH STREQUAL "x86_64" AND NOT MSVC)
        list(APPEND _zstd_sources thirdparty/zstd/decompress/huf_decompress_amd64.S)
    endif()
endif()

set(GODOT_CORE_THIRDPARTY_SOURCES
    ${_misc_sources}
    ${_brotli_sources}
    ${_clipper2_sources}
    ${_zlib_sources}
    ${_minizip_sources}
    ${_zstd_sources}
)

# Absolute source paths.
set(_abs "")
foreach(f IN LISTS GODOT_CORE_THIRDPARTY_SOURCES)
    list(APPEND _abs "${CMAKE_SOURCE_DIR}/${f}")
endforeach()
set(GODOT_CORE_THIRDPARTY_SOURCES ${_abs})

# =============================================================================
# core library (mirrors core/SCsub + core/*/SCsub)
# =============================================================================
file(GLOB_RECURSE _core_sources CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/core/*.cpp")
set(_core_gen_sources
    "${CMAKE_SOURCE_DIR}/core/version_hash.gen.cpp"
    "${CMAKE_SOURCE_DIR}/core/script_encryption_key.gen.cpp"
    "${CMAKE_SOURCE_DIR}/core/input/default_controller_mappings.gen.cpp"
)
set(_core_gen_headers
    "${CMAKE_SOURCE_DIR}/core/version_generated.gen.h"
    "${CMAKE_SOURCE_DIR}/core/disabled_classes.gen.h"
    "${CMAKE_SOURCE_DIR}/core/io/certs_compressed.gen.h"
    "${CMAKE_SOURCE_DIR}/core/authors.gen.h"
    "${CMAKE_SOURCE_DIR}/core/donors.gen.h"
    "${CMAKE_SOURCE_DIR}/core/license.gen.h"
    "${CMAKE_SOURCE_DIR}/core/profiling/profiling.gen.h"
    "${CMAKE_SOURCE_DIR}/core/object/gdvirtual.gen.h"
    "${CMAKE_SOURCE_DIR}/core/extension/ext_wrappers.gen.h"
    "${CMAKE_SOURCE_DIR}/core/extension/gdextension_interface_dump.gen.h"
    "${CMAKE_SOURCE_DIR}/core/extension/gdextension_interface.gen.h"
    "${CMAKE_SOURCE_DIR}/modules/modules_enabled.gen.h"
)

add_library(godot_core STATIC
    ${_core_sources}
    ${_core_gen_sources}
    ${_core_gen_headers}
    ${GODOT_CORE_THIRDPARTY_SOURCES}
)
add_library(godot::core ALIAS godot_core)

target_link_libraries(godot_core
    PRIVATE godot_options godot_thirdparty_options
)

# Thirdparty include dirs (core/SCsub + core/crypto/SCsub).
target_include_directories(godot_core PUBLIC
    "${CMAKE_SOURCE_DIR}/thirdparty/brotli/include"
    "${CMAKE_SOURCE_DIR}/thirdparty/clipper2/include"
    "${CMAKE_SOURCE_DIR}/thirdparty/zlib"
    "${CMAKE_SOURCE_DIR}/thirdparty/zstd"
    "${CMAKE_SOURCE_DIR}/thirdparty/zstd/common"
    "${CMAKE_SOURCE_DIR}/thirdparty/mbedtls/include"
)

# mbedTLS config for core/crypto when the mbedtls module is enabled.
if(GODOT_MODULE_MBEDTLS_ENABLED)
    target_compile_definitions(godot_core PRIVATE
        "MBEDTLS_CONFIG_FILE=\"thirdparty/mbedtls/include/godot_module_mbedtls_config.h\"")
endif()

# =============================================================================
# servers library (mirrors servers/SCsub + servers/*/SCsub)
# =============================================================================
file(GLOB_RECURSE _servers_sources CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/servers/*.cpp")

set(_servers_thirdparty
    "${CMAKE_SOURCE_DIR}/thirdparty/amd-fsr2/ffx_assert.cpp"
    "${CMAKE_SOURCE_DIR}/thirdparty/amd-fsr2/ffx_fsr2.cpp"
    "${CMAKE_SOURCE_DIR}/thirdparty/spirv-reflect/spirv_reflect.c"
)

set(_servers_gen_headers
    "${CMAKE_SOURCE_DIR}/servers/rendering/storage/ltc_lut.gen.h"
)

# SMAA lookup textures (generated from bundled PNGs; renderer_rd/effects).
godot_codegen(smaa_area_tex smaa_area_tex
    OUTPUTS "${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/effects/smaa_area_tex.gen.h"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/thirdparty/smaa/AreaTex.png")
godot_codegen(smaa_search_tex smaa_search_tex
    OUTPUTS "${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/effects/smaa_search_tex.gen.h"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/thirdparty/smaa/SearchTex.png")
list(APPEND _servers_gen_headers
    "${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/effects/smaa_area_tex.gen.h"
    "${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/effects/smaa_search_tex.gen.h"
)
file(GLOB _rd_shader_headers
    "${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/shaders/*.glsl.gen.h"
    "${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/shaders/*/*.glsl.gen.h"
    "${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/shaders/*/*/*.glsl.gen.h"
)

add_library(godot_servers STATIC
    ${_servers_sources}
    ${_servers_thirdparty}
    ${_servers_gen_headers}
    ${_rd_shader_headers}
)
add_library(godot::servers ALIAS godot_servers)

target_link_libraries(godot_servers PRIVATE godot_options godot_thirdparty_options)
target_link_libraries(godot_servers PUBLIC godot_core)
add_dependencies(godot_servers godot_generated)
target_include_directories(godot_servers PRIVATE
    "${CMAKE_SOURCE_DIR}/thirdparty/amd-fsr2"
    "${CMAKE_SOURCE_DIR}/thirdparty/spirv-reflect"
)
target_compile_definitions(godot_servers PRIVATE FFX_GCC)

# =============================================================================
# scene library (mirrors scene/SCsub + scene/*/SCsub)
# =============================================================================
file(GLOB_RECURSE _scene_sources CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/scene/*.cpp")

set(_scene_thirdparty
    "${CMAKE_SOURCE_DIR}/thirdparty/misc/mikktspace.c"
    "${CMAKE_SOURCE_DIR}/thirdparty/misc/qoa.c"
)

set(_scene_gen_headers
    "${CMAKE_SOURCE_DIR}/scene/theme/default_font.gen.h"
    "${CMAKE_SOURCE_DIR}/scene/theme/default_theme_icons.gen.h"
)

add_library(godot_scene STATIC
    ${_scene_sources}
    ${_scene_thirdparty}
    ${_scene_gen_headers}
)
add_library(godot::scene ALIAS godot_scene)

target_link_libraries(godot_scene PRIVATE godot_options godot_thirdparty_options)
target_link_libraries(godot_scene PUBLIC godot_core)

# =============================================================================
# drivers library (mirrors drivers/SCsub + the linuxbsd-relevant sub-SCsubs)
# =============================================================================
# build are included (metal/d3d12/wasapi/xaudio2/apple are excluded).

set(_drivers_dirs
    unix
    windows
    alsa
    pulseaudio
    alsamidi
    winmidi
    png
)

if(GODOT_VULKAN)
    list(APPEND _drivers_dirs vulkan)
endif()
if(GODOT_OPENGL3)
    list(APPEND _drivers_dirs gl_context gles3 egl)
endif()
if(GODOT_SDL)
    list(APPEND _drivers_dirs sdl)
endif()
if(GODOT_ACCESSKIT)
    list(APPEND _drivers_dirs accesskit)
endif()

set(_drivers_sources "")
# Top-level drivers/*.cpp (drivers/SCsub adds "*.cpp" in the drivers root).
file(GLOB _drivers_root_sources CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/drivers/*.cpp")
list(APPEND _drivers_sources ${_drivers_root_sources})
foreach(_d IN LISTS _drivers_dirs)
    file(GLOB_RECURSE _d_sources CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/drivers/${_d}/*.cpp")
    list(APPEND _drivers_sources ${_d_sources})
endforeach()

# --- so_wrap sources (dynamically dlopened system libraries) ---
set(_drivers_wrap "")
if(GODOT_USE_SOWRAP)
    list(APPEND _drivers_wrap
        "${CMAKE_SOURCE_DIR}/drivers/alsa/asound-so_wrap.c"
        "${CMAKE_SOURCE_DIR}/drivers/pulseaudio/pulse-so_wrap.c"
    )
endif()

# --- thirdparty: libpng (x86_64 uses Intel SSE2 intrinsics) ---
set(_png_sources "")
if(GODOT_BUILTIN_LIBPNG)
    set(_png_sources
        thirdparty/libpng/png.c
        thirdparty/libpng/pngerror.c
        thirdparty/libpng/pngget.c
        thirdparty/libpng/pngmem.c
        thirdparty/libpng/pngpread.c
        thirdparty/libpng/pngread.c
        thirdparty/libpng/pngrio.c
        thirdparty/libpng/pngrtran.c
        thirdparty/libpng/pngrutil.c
        thirdparty/libpng/pngset.c
        thirdparty/libpng/pngtrans.c
        thirdparty/libpng/pngwio.c
        thirdparty/libpng/pngwrite.c
        thirdparty/libpng/pngwtran.c
        thirdparty/libpng/pngwutil.c
        thirdparty/libpng/intel/intel_init.c
        thirdparty/libpng/intel/filter_sse2_intrinsics.c
    )
endif()

# --- thirdparty: glad (gl_context) ---
set(_glad_sources "")
if(GODOT_OPENGL3)
    set(_glad_sources
        thirdparty/glad/gl.c
        thirdparty/glad/egl.c
    )
endif()

# --- thirdparty: Vulkan memory allocator + volk + re-spirv ---
set(_vulkan_thirdparty "")
if(GODOT_VULKAN)
    set(_vulkan_thirdparty
        thirdparty/vulkan/vk_mem_alloc.cpp
        thirdparty/volk/volk.c
        thirdparty/re-spirv/re-spirv.cpp
    )
endif()

# --- thirdparty: SDL3 (builtin) ---
set(_sdl_sources "")
if(GODOT_SDL AND GODOT_BUILTIN_SDL)
    set(_sdl_sources
        thirdparty/sdl/SDL.c
        thirdparty/sdl/SDL_assert.c
        thirdparty/sdl/SDL_error.c
        thirdparty/sdl/SDL_guid.c
        thirdparty/sdl/SDL_hashtable.c
        thirdparty/sdl/SDL_hints.c
        thirdparty/sdl/SDL_list.c
        thirdparty/sdl/SDL_log.c
        thirdparty/sdl/SDL_properties.c
        thirdparty/sdl/SDL_utils.c
        thirdparty/sdl/atomic/SDL_atomic.c
        thirdparty/sdl/atomic/SDL_spinlock.c
        thirdparty/sdl/events/SDL_events.c
        thirdparty/sdl/events/SDL_eventwatch.c
        thirdparty/sdl/haptic/SDL_haptic.c
        thirdparty/sdl/io/SDL_iostream.c
        thirdparty/sdl/joystick/SDL_gamepad.c
        thirdparty/sdl/joystick/SDL_joystick.c
        thirdparty/sdl/joystick/SDL_steam_virtual_gamepad.c
        thirdparty/sdl/joystick/controller_type.c
        thirdparty/sdl/libm/e_atan2.c
        thirdparty/sdl/libm/e_exp.c
        thirdparty/sdl/libm/e_fmod.c
        thirdparty/sdl/libm/e_log.c
        thirdparty/sdl/libm/e_log10.c
        thirdparty/sdl/libm/e_pow.c
        thirdparty/sdl/libm/e_rem_pio2.c
        thirdparty/sdl/libm/e_sqrt.c
        thirdparty/sdl/libm/k_cos.c
        thirdparty/sdl/libm/k_rem_pio2.c
        thirdparty/sdl/libm/k_sin.c
        thirdparty/sdl/libm/k_tan.c
        thirdparty/sdl/libm/s_atan.c
        thirdparty/sdl/libm/s_copysign.c
        thirdparty/sdl/libm/s_cos.c
        thirdparty/sdl/libm/s_fabs.c
        thirdparty/sdl/libm/s_floor.c
        thirdparty/sdl/libm/s_isinf.c
        thirdparty/sdl/libm/s_isinff.c
        thirdparty/sdl/libm/s_isnan.c
        thirdparty/sdl/libm/s_isnanf.c
        thirdparty/sdl/libm/s_modf.c
        thirdparty/sdl/libm/s_scalbn.c
        thirdparty/sdl/libm/s_sin.c
        thirdparty/sdl/libm/s_tan.c
        thirdparty/sdl/sensor/SDL_sensor.c
        thirdparty/sdl/sensor/dummy/SDL_dummysensor.c
        thirdparty/sdl/stdlib/SDL_crc16.c
        thirdparty/sdl/stdlib/SDL_crc32.c
        thirdparty/sdl/stdlib/SDL_getenv.c
        thirdparty/sdl/stdlib/SDL_iconv.c
        thirdparty/sdl/stdlib/SDL_malloc.c
        thirdparty/sdl/stdlib/SDL_memcpy.c
        thirdparty/sdl/stdlib/SDL_memmove.c
        thirdparty/sdl/stdlib/SDL_memset.c
        thirdparty/sdl/stdlib/SDL_mslibc.c
        thirdparty/sdl/stdlib/SDL_murmur3.c
        thirdparty/sdl/stdlib/SDL_qsort.c
        thirdparty/sdl/stdlib/SDL_random.c
        thirdparty/sdl/stdlib/SDL_stdlib.c
        thirdparty/sdl/stdlib/SDL_string.c
        thirdparty/sdl/stdlib/SDL_strtokr.c
        thirdparty/sdl/thread/SDL_thread.c
        thirdparty/sdl/timer/SDL_timer.c
        thirdparty/sdl/hidapi/SDL_hidapi.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapi_combined.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapi_gamecube.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapijoystick.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapi_luna.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapi_ps3.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapi_ps4.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapi_ps5.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapi_rumble.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapi_shield.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapi_stadia.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapi_steam.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapi_steamdeck.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapi_steam_hori.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapi_switch.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapi_wii.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapi_xbox360.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapi_xbox360w.c
        thirdparty/sdl/joystick/hidapi/SDL_hidapi_xboxone.c
        thirdparty/sdl/core/linux/SDL_dbus.c
        thirdparty/sdl/core/linux/SDL_evdev.c
        thirdparty/sdl/core/linux/SDL_evdev_capabilities.c
        thirdparty/sdl/core/linux/SDL_evdev_kbd.c
        thirdparty/sdl/core/linux/SDL_threadprio.c
        thirdparty/sdl/core/linux/SDL_udev.c
        thirdparty/sdl/core/unix/SDL_appid.c
        thirdparty/sdl/core/unix/SDL_poll.c
        thirdparty/sdl/haptic/linux/SDL_syshaptic.c
        thirdparty/sdl/joystick/linux/SDL_sysjoystick.c
        thirdparty/sdl/loadso/dlopen/SDL_sysloadso.c
        thirdparty/sdl/thread/pthread/SDL_syscond.c
        thirdparty/sdl/thread/pthread/SDL_sysmutex.c
        thirdparty/sdl/thread/pthread/SDL_sysrwlock.c
        thirdparty/sdl/thread/pthread/SDL_syssem.c
        thirdparty/sdl/thread/pthread/SDL_systhread.c
        thirdparty/sdl/thread/pthread/SDL_systls.c
        thirdparty/sdl/timer/unix/SDL_systimer.c
    )
endif()

# Make thirdparty source paths absolute.
set(_tp "")
foreach(f IN LISTS _png_sources _glad_sources _vulkan_thirdparty _sdl_sources)
    list(APPEND _tp "${CMAKE_SOURCE_DIR}/${f}")
endforeach()

add_library(godot_drivers STATIC
    ${_drivers_sources}
    ${_drivers_wrap}
    ${_tp}
)
add_library(godot::drivers ALIAS godot_drivers)

target_link_libraries(godot_drivers PRIVATE godot_options godot_thirdparty_options)
target_link_libraries(godot_drivers PUBLIC godot_core)
add_dependencies(godot_drivers godot_generated)

target_include_directories(godot_drivers PUBLIC
    "${CMAKE_SOURCE_DIR}/thirdparty/libpng"
    "${CMAKE_SOURCE_DIR}/thirdparty/glad"
    "${CMAKE_SOURCE_DIR}/thirdparty/vulkan"
    "${CMAKE_SOURCE_DIR}/thirdparty/vulkan/include"
    "${CMAKE_SOURCE_DIR}/thirdparty/volk"
    "${CMAKE_SOURCE_DIR}/thirdparty/spirv-headers/include"
    "${CMAKE_SOURCE_DIR}/thirdparty/re-spirv"
)

# Feature defines for the enabled drivers.
if(GODOT_VULKAN)
    target_compile_definitions(godot_drivers PRIVATE
        USE_VOLK
        VMA_EXTERNAL_MEMORY_WIN32=0
        VMA_STATIC_VULKAN_FUNCTIONS=1
    )
    if(GODOT_X11)
        target_compile_definitions(godot_drivers PRIVATE VK_USE_PLATFORM_XLIB_KHR)
    endif()
    if(GODOT_WAYLAND)
        target_compile_definitions(godot_drivers PRIVATE VK_USE_PLATFORM_WAYLAND_KHR)
    endif()
endif()

if(GODOT_OPENGL3)
    # GLAD_ENABLED/EGL_ENABLED/GLAD_GLES2 come from godot_options.
endif()

if(GODOT_ALSA)
    target_compile_definitions(godot_drivers PRIVATE ALSA_ENABLED ALSAMIDI_ENABLED)
endif()
if(GODOT_PULSEAUDIO)
    target_compile_definitions(godot_drivers PRIVATE PULSEAUDIO_ENABLED)
endif()

if(GODOT_SDL AND GODOT_BUILTIN_SDL)
    target_compile_definitions(godot_drivers PRIVATE SDL_ENABLED SDL_PLATFORM_PRIVATE SDL_PLATFORM_LINUX)
    target_include_directories(godot_drivers PRIVATE
        "${CMAKE_SOURCE_DIR}/thirdparty/sdl"
        "${CMAKE_SOURCE_DIR}/thirdparty/sdl/include"
        "${CMAKE_SOURCE_DIR}/thirdparty/sdl/include/build_config"
        "${CMAKE_SOURCE_DIR}/thirdparty/sdl/core/linux"
        "${CMAKE_SOURCE_DIR}/drivers/sdl"
    )
endif()

# libpng SSE2 intrinsics path.
if(GODOT_BUILTIN_LIBPNG AND GODOT_ARCH STREQUAL "x86_64")
    target_compile_definitions(godot_drivers PRIVATE PNG_INTEL_SSE)
endif()
# =============================================================================
# platform library + the active platform (linuxbsd) backend (mirrors platform/SCsub)
# =============================================================================

# --- platform export icons: generated in generated.cmake (GODOT_EXPORT_ICON_HEADERS) ---

# --- register platform APIs (all platforms with api/api.cpp) ---
set(_platform_apis android ios visionos web)
set(_apis_json "")
foreach(_p IN LISTS _platform_apis)
    if(_apis_json)
        string(APPEND _apis_json ", ")
    endif()
    string(APPEND _apis_json "\"${_p}\"")
endforeach()
godot_codegen(register_platform_apis register_platform_apis
    OUTPUTS "${CMAKE_SOURCE_DIR}/platform/register_platform_apis.gen.cpp"
    ENV "{\"platform_apis\":[${_apis_json}]}")

# The platform library aggregates the API sources + generated registration.
set(_platform_sources
    "${CMAKE_SOURCE_DIR}/platform/register_platform_apis.gen.cpp"
)
foreach(_p IN LISTS _platform_apis)
    file(GLOB_RECURSE _api_src "${CMAKE_SOURCE_DIR}/platform/${_p}/api/*.cpp")
    list(APPEND _platform_sources ${_api_src})
endforeach()

add_library(godot_platform STATIC
    ${_platform_sources}
    ${GODOT_EXPORT_ICON_HEADERS}
)
add_library(godot::platform ALIAS godot_platform)
target_link_libraries(godot_platform PRIVATE godot_options)
target_link_libraries(godot_platform PUBLIC godot_core)
add_dependencies(godot_platform godot_generated)

# =============================================================================
# linuxbsd platform backend
# =============================================================================
set(_linuxbsd_sources
    "${CMAKE_SOURCE_DIR}/platform/linuxbsd/crash_handler_linuxbsd.cpp"
    "${CMAKE_SOURCE_DIR}/platform/linuxbsd/os_linuxbsd.cpp"
    "${CMAKE_SOURCE_DIR}/platform/linuxbsd/freedesktop_portal_desktop.cpp"
    "${CMAKE_SOURCE_DIR}/platform/linuxbsd/freedesktop_screensaver.cpp"
    "${CMAKE_SOURCE_DIR}/platform/linuxbsd/freedesktop_at_spi_monitor.cpp"
    "${CMAKE_SOURCE_DIR}/platform/linuxbsd/godot_linuxbsd.cpp"
)
if(GODOT_SPEECHD)
    list(APPEND _linuxbsd_sources "${CMAKE_SOURCE_DIR}/platform/linuxbsd/tts_linux.cpp")
endif()

# so_wrap shims.
set(_linuxbsd_wrap "")
if(GODOT_USE_SOWRAP)
    list(APPEND _linuxbsd_wrap
        "${CMAKE_SOURCE_DIR}/platform/linuxbsd/xkbcommon-so_wrap.c"
    )
    if(GODOT_SPEECHD)
        list(APPEND _linuxbsd_wrap "${CMAKE_SOURCE_DIR}/platform/linuxbsd/speechd-so_wrap.c")
    endif()
    if(GODOT_FONTCONFIG)
        list(APPEND _linuxbsd_wrap "${CMAKE_SOURCE_DIR}/platform/linuxbsd/fontconfig-so_wrap.c")
    endif()
    if(GODOT_DBUS)
        list(APPEND _linuxbsd_wrap "${CMAKE_SOURCE_DIR}/platform/linuxbsd/dbus-so_wrap.c")
    endif()
endif()

# --- X11 backend ---
if(GODOT_X11)
    set(_x11_dir "${CMAKE_SOURCE_DIR}/platform/linuxbsd/x11")
    list(APPEND _linuxbsd_sources
        "${_x11_dir}/display_server_x11.cpp"
        "${_x11_dir}/key_mapping_x11.cpp"
    )
    if(GODOT_VULKAN)
        list(APPEND _linuxbsd_sources "${_x11_dir}/rendering_context_driver_vulkan_x11.cpp")
    endif()
    if(GODOT_OPENGL3)
        list(APPEND _linuxbsd_sources
            "${_x11_dir}/gl_manager_x11_egl.cpp"
            "${_x11_dir}/gl_manager_x11.cpp"
            "${_x11_dir}/detect_prime_x11.cpp"
        )
        list(APPEND _linuxbsd_sources "${CMAKE_SOURCE_DIR}/thirdparty/glad/glx.c")
    endif()
    if(GODOT_USE_SOWRAP)
        list(APPEND _linuxbsd_sources
            "${_x11_dir}/dynwrappers/xlib-so_wrap.c"
            "${_x11_dir}/dynwrappers/xcursor-so_wrap.c"
            "${_x11_dir}/dynwrappers/xinerama-so_wrap.c"
            "${_x11_dir}/dynwrappers/xinput2-so_wrap.c"
            "${_x11_dir}/dynwrappers/xrandr-so_wrap.c"
            "${_x11_dir}/dynwrappers/xrender-so_wrap.c"
            "${_x11_dir}/dynwrappers/xext-so_wrap.c"
        )
    endif()
endif()

# --- Wayland backend (with wayland-scanner protocol generation) ---
if(GODOT_WAYLAND)
    find_program(WAYLAND_SCANNER_EXECUTABLE wayland-scanner)
    if(NOT WAYLAND_SCANNER_EXECUTABLE)
        message(FATAL_ERROR "wayland-scanner not found but GODOT_WAYLAND=ON. Install wayland-protocols tools or disable Wayland.")
    endif()

    set(_wl_dir "${CMAKE_SOURCE_DIR}/platform/linuxbsd/wayland")
    file(MAKE_DIRECTORY "${_wl_dir}/protocol")
    list(APPEND _linuxbsd_sources
        "${_wl_dir}/detect_prime_egl.cpp"
        "${_wl_dir}/display_server_wayland.cpp"
        "${_wl_dir}/key_mapping_xkb.cpp"
        "${_wl_dir}/wayland_thread.cpp"
        "${_wl_dir}/wayland_embedder.cpp"
    )
    if(GODOT_VULKAN)
        list(APPEND _linuxbsd_sources "${_wl_dir}/rendering_context_driver_vulkan_wayland.cpp")
    endif()
    if(GODOT_OPENGL3)
        list(APPEND _linuxbsd_sources
            "${_wl_dir}/egl_manager_wayland.cpp"
            "${_wl_dir}/egl_manager_wayland_gles.cpp"
        )
    endif()
    if(GODOT_USE_SOWRAP)
        list(APPEND _linuxbsd_sources
            "${_wl_dir}/dynwrappers/wayland-cursor-so_wrap.c"
            "${_wl_dir}/dynwrappers/wayland-client-core-so_wrap.c"
            "${_wl_dir}/dynwrappers/wayland-egl-core-so_wrap.c"
        )
        if(GODOT_LIBDECOR)
            list(APPEND _linuxbsd_sources "${_wl_dir}/dynwrappers/libdecor-so_wrap.c")
        endif()
    endif()

    # Wayland protocol XMLs -> client-header/private-code via wayland-scanner.
    set(_wl_protocols
        "wayland|thirdparty/wayland/protocol/wayland.xml"
        "tablet|thirdparty/wayland-protocols/stable/tablet/tablet-v2.xml"
        "viewporter|thirdparty/wayland-protocols/stable/viewporter/viewporter.xml"
        "xdg_shell|thirdparty/wayland-protocols/stable/xdg-shell/xdg-shell.xml"
        "color_management|thirdparty/wayland-protocols/staging/color-management/color-management-v1.xml"
        "cursor_shape|thirdparty/wayland-protocols/staging/cursor-shape/cursor-shape-v1.xml"
        "fractional_scale|thirdparty/wayland-protocols/staging/fractional-scale/fractional-scale-v1.xml"
        "xdg_activation|thirdparty/wayland-protocols/staging/xdg-activation/xdg-activation-v1.xml"
        "xdg_system_bell|thirdparty/wayland-protocols/staging/xdg-system-bell/xdg-system-bell-v1.xml"
        "xdg_toplevel_icon|thirdparty/wayland-protocols/staging/xdg-toplevel-icon/xdg-toplevel-icon-v1.xml"
        "pointer_warp|thirdparty/wayland-protocols/staging/pointer-warp/pointer-warp-v1.xml"
        "idle_inhibit|thirdparty/wayland-protocols/unstable/idle-inhibit/idle-inhibit-unstable-v1.xml"
        "pointer_constraints|thirdparty/wayland-protocols/unstable/pointer-constraints/pointer-constraints-unstable-v1.xml"
        "pointer_gestures|thirdparty/wayland-protocols/unstable/pointer-gestures/pointer-gestures-unstable-v1.xml"
        "primary_selection|thirdparty/wayland-protocols/unstable/primary-selection/primary-selection-unstable-v1.xml"
        "relative_pointer|thirdparty/wayland-protocols/unstable/relative-pointer/relative-pointer-unstable-v1.xml"
        "text_input|thirdparty/wayland-protocols/unstable/text-input/text-input-unstable-v3.xml"
        "xdg_decoration|thirdparty/wayland-protocols/unstable/xdg-decoration/xdg-decoration-unstable-v1.xml"
        "xdg_foreign_v1|thirdparty/wayland-protocols/unstable/xdg-foreign/xdg-foreign-unstable-v1.xml"
        "xdg_foreign_v2|thirdparty/wayland-protocols/unstable/xdg-foreign/xdg-foreign-unstable-v2.xml"
        "linux_dmabuf_v1|thirdparty/wayland-protocols/stable/linux-dmabuf/linux-dmabuf-v1.xml"
        "linux_explicit_synchronization_unstable_v1|thirdparty/wayland-protocols/unstable/linux-explicit-synchronization/linux-explicit-synchronization-unstable-v1.xml"
        "fifo_v1|thirdparty/wayland-protocols/staging/fifo/fifo-v1.xml"
        "commit_timing_v1|thirdparty/wayland-protocols/staging/commit-timing/commit-timing-v1.xml"
        "linux_drm_syncobj_v1|thirdparty/wayland-protocols/staging/linux-drm-syncobj/linux-drm-syncobj-v1.xml"
        "tearing_control_v1|thirdparty/wayland-protocols/staging/tearing-control/tearing-control-v1.xml"
        "wayland-drm|thirdparty/wayland-protocols/mesa/wayland-drm.xml"
        "godot_embedding_compositor|platform/linuxbsd/wayland/godot-embedding-compositor.xml"
    )

    set(_wl_gen "")
    foreach(_entry IN LISTS _wl_protocols)
        string(REPLACE "|" ";" _parts "${_entry}")
        list(GET _parts 0 _name)
        list(GET _parts 1 _xml)
        set(_xml_abs "${CMAKE_SOURCE_DIR}/${_xml}")
        set(_hdr "${_wl_dir}/protocol/${_name}.gen.h")
        set(_src "${_wl_dir}/protocol/${_name}.gen.c")

        # so_wrap variants rewrite the wayland headers to the dynwrappers ones.
        # wayland-scanner takes <mode> <input> <output> (no stdout redirection).
        if(GODOT_USE_SOWRAP)
            add_custom_command(
                OUTPUT "${_hdr}"
                COMMAND ${WAYLAND_SCANNER_EXECUTABLE} client-header "${_xml_abs}" "${_hdr}"
                COMMAND sed -i "s:wayland-client-core\\.h:../dynwrappers/wayland-client-core-so_wrap\\.h:" "${_hdr}"
                DEPENDS "${_xml_abs}"
                COMMENT "Wayland protocol header ${_name}"
                VERBATIM
            )
            add_custom_command(
                OUTPUT "${_src}"
                COMMAND ${WAYLAND_SCANNER_EXECUTABLE} private-code "${_xml_abs}" "${_src}"
                COMMAND sed -i "s:wayland-util\\.h:../dynwrappers/wayland-client-core-so_wrap\\.h:" "${_src}"
                DEPENDS "${_xml_abs}"
                COMMENT "Wayland protocol code ${_name}"
                VERBATIM
            )
        else()
            add_custom_command(
                OUTPUT "${_hdr}"
                COMMAND ${WAYLAND_SCANNER_EXECUTABLE} client-header "${_xml_abs}" "${_hdr}"
                DEPENDS "${_xml_abs}"
                COMMENT "Wayland protocol header ${_name}"
                VERBATIM
            )
            add_custom_command(
                OUTPUT "${_src}"
                COMMAND ${WAYLAND_SCANNER_EXECUTABLE} private-code "${_xml_abs}" "${_src}"
                DEPENDS "${_xml_abs}"
                COMMENT "Wayland protocol code ${_name}"
                VERBATIM
            )
        endif()
        list(APPEND _wl_gen "${_hdr}" "${_src}")
    endforeach()
    list(APPEND _linuxbsd_sources ${_wl_gen})
endif()

add_library(godot_linuxbsd STATIC
    ${_linuxbsd_sources}
    ${_linuxbsd_wrap}
)
add_library(godot::linuxbsd ALIAS godot_linuxbsd)
target_link_libraries(godot_linuxbsd PRIVATE godot_options godot_thirdparty_options)
target_link_libraries(godot_linuxbsd PUBLIC godot_core godot_platform)
add_dependencies(godot_linuxbsd godot_generated)

target_include_directories(godot_linuxbsd PRIVATE
    "${CMAKE_SOURCE_DIR}/platform/linuxbsd/x11"
    "${CMAKE_SOURCE_DIR}/platform/linuxbsd/wayland"
    "${CMAKE_SOURCE_DIR}/platform/linuxbsd/wayland/dynwrappers"
    "${CMAKE_SOURCE_DIR}/platform/linuxbsd/x11/dynwrappers"
    "${CMAKE_SOURCE_DIR}/thirdparty/glad"
)

if(GODOT_X11 AND GODOT_OPENGL3)
    target_compile_definitions(godot_linuxbsd PRIVATE GLAD_GLX_NO_X11)
endif()

if(GODOT_VULKAN)
    target_include_directories(godot_linuxbsd PRIVATE
        "${CMAKE_SOURCE_DIR}/thirdparty/vulkan/include"
        "${CMAKE_SOURCE_DIR}/thirdparty/volk")
    target_compile_definitions(godot_linuxbsd PRIVATE USE_VOLK)
    if(GODOT_X11)
        target_compile_definitions(godot_linuxbsd PRIVATE VK_USE_PLATFORM_XLIB_KHR)
    endif()
    if(GODOT_WAYLAND)
        target_compile_definitions(godot_linuxbsd PRIVATE VK_USE_PLATFORM_WAYLAND_KHR)
    endif()
endif()
# =============================================================================
# editor library (mirrors editor/SCsub + editor/*/SCsub)
# Debug builds always target the editor, so this section is unconditional.
# =============================================================================
file(GLOB_RECURSE _editor_sources CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/editor/*.cpp")

# Platform-specific shader baker plugins are gated by build options
# (editor/shader/shader_baker/SCsub), unlike the rest of the editor tree.
if(NOT GODOT_VULKAN)
    list(FILTER _editor_sources EXCLUDE REGEX "shader_baker_export_plugin_platform_vulkan\\.cpp$")
endif()
if(NOT GODOT_D3D12)
    list(FILTER _editor_sources EXCLUDE REGEX "shader_baker_export_plugin_platform_d3d12\\.cpp$")
endif()
if(NOT GODOT_METAL)
    list(FILTER _editor_sources EXCLUDE REGEX "shader_baker_export_plugin_platform_metal\\.cpp$")
endif()

# --- doc data class path ---
godot_codegen(doc_data_class_path doc_data_class_path
    OUTPUTS "${CMAKE_SOURCE_DIR}/editor/doc/doc_data_class_path.gen.h"
    ENV "{\"doc_class_path\":${GODOT_DOC_CLASS_PATH}}")

# --- register exporters (all platforms that ship an exporter) ---
set(_exporters android ios linuxbsd macos visionos web windows)
set(_exporters_json "")
foreach(_p IN LISTS _exporters)
    if(_exporters_json)
        string(APPEND _exporters_json ", ")
    endif()
    string(APPEND _exporters_json "\"${_p}\"")
endforeach()
godot_codegen(register_exporters register_exporters
    OUTPUTS "${CMAKE_SOURCE_DIR}/editor/export/register_exporters.gen.cpp"
    ENV "{\"platform_exporters\":[${_exporters_json}]}")

# --- compressed class reference (all doc/classes XML + module/platform XML) ---
file(GLOB _doc_xml "${CMAKE_SOURCE_DIR}/doc/classes/*.xml")
foreach(_m IN LISTS GODOT_MODULES_DETECTED_NAMES)
    file(GLOB _mod_xml "${CMAKE_SOURCE_DIR}/${_m}/*.xml")
    list(APPEND _doc_xml ${_mod_xml})
endforeach()
list(SORT _doc_xml)
godot_codegen(make_doc_header doc_data_compressed
    OUTPUTS "${CMAKE_SOURCE_DIR}/editor/doc/doc_data_compressed.gen.h"
    PATH_INPUTS ${_doc_xml})

# --- translations (editor UI, properties, class reference, extractable) ---
function(_godot_add_translations category out_h out_cpp dir)
    file(GLOB _po "${CMAKE_SOURCE_DIR}/${dir}/*.po")
    godot_codegen(make_translations "translations_${category}"
        OUTPUTS "${CMAKE_SOURCE_DIR}/${out_h}" "${CMAKE_SOURCE_DIR}/${out_cpp}"
        PATH_INPUTS ${_po})
endfunction()

_godot_add_translations(editor
    "editor/translations/editor_translations.gen.h"
    "editor/translations/editor_translations.gen.cpp"
    "editor/translations/editor")
_godot_add_translations(property
    "editor/translations/property_translations.gen.h"
    "editor/translations/property_translations.gen.cpp"
    "editor/translations/properties")
_godot_add_translations(doc
    "editor/translations/doc_translations.gen.h"
    "editor/translations/doc_translations.gen.cpp"
    "doc/translations")
_godot_add_translations(extractable
    "editor/translations/extractable_translations.gen.h"
    "editor/translations/extractable_translations.gen.cpp"
    "editor/translations/extractable")

# Generated headers/sources that editor translation units include.
set(_editor_gen
    "${CMAKE_SOURCE_DIR}/editor/doc/doc_data_class_path.gen.h"
    "${CMAKE_SOURCE_DIR}/editor/doc/doc_data_compressed.gen.h"
    "${CMAKE_SOURCE_DIR}/editor/export/register_exporters.gen.cpp"
    "${CMAKE_SOURCE_DIR}/editor/translations/editor_translations.gen.cpp"
    "${CMAKE_SOURCE_DIR}/editor/translations/property_translations.gen.cpp"
    "${CMAKE_SOURCE_DIR}/editor/translations/doc_translations.gen.cpp"
    "${CMAKE_SOURCE_DIR}/editor/translations/extractable_translations.gen.cpp"
    "${CMAKE_SOURCE_DIR}/editor/themes/builtin_fonts.gen.h"
    "${CMAKE_SOURCE_DIR}/editor/themes/editor_icons.gen.h"
)

# The editor compiles every platform's export plugin sources (editor/SCsub adds
# all of platform/<p>/export/*.cpp). Their *_svg.gen.h icons are generated by
# generated.cmake and listed as sources so they exist first.
set(_export_plugin_sources "")
foreach(_p IN LISTS _exporters)
    file(GLOB _p_export_src "${CMAKE_SOURCE_DIR}/platform/${_p}/export/*.cpp")
    list(APPEND _export_plugin_sources ${_p_export_src})
endforeach()

add_library(godot_editor STATIC
    ${_editor_sources}
    ${_editor_gen}
    ${_export_plugin_sources}
    ${GODOT_EXPORT_ICON_HEADERS}
)
add_library(godot::editor ALIAS godot_editor)

target_link_libraries(godot_editor PRIVATE godot_options)
target_link_libraries(godot_editor PUBLIC godot_core godot_servers godot_scene)
add_dependencies(godot_editor godot_generated)
# =============================================================================
# main library (mirrors main/SCsub)
# =============================================================================
file(GLOB _main_sources CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/main/*.cpp")

# main/steam_tracker.cpp is only meaningful with STEAMAPI_ENABLED; the SCons
# build compiles it always but the body is guarded, so keep parity by including
# it only for non-steamid builds is unnecessary — include it.
add_library(godot_main STATIC
    ${_main_sources}
)
add_library(godot::main ALIAS godot_main)
target_link_libraries(godot_main PRIVATE godot_options)
target_link_libraries(godot_main PUBLIC godot_core godot_scene godot_servers godot_drivers)
add_dependencies(godot_main godot_generated)
# =============================================================================
# Modules (mirrors modules/SCsub)
# =============================================================================
# Module build rules are NOT hand-written: cmake/godot_module_probe.py executes
# each module's real SCsub against a recording stub environment and emits, as
# JSON Lines, the exact source lists / include dirs / defines that SCons would
# use. This file turns each line into a CMake target, so module parity with the
# SCons build is structural rather than manual.

execute_process(
    COMMAND ${Python3_EXECUTABLE} "${CMAKE_SOURCE_DIR}/cmake/godot_module_probe.py" "${CMAKE_SOURCE_DIR}"
    OUTPUT_VARIABLE _modules_probe_jsonl
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE _modules_probe_rc
)
if(NOT _modules_probe_rc EQUAL 0)
    message(FATAL_ERROR "godot_module_probe.py failed (${_modules_probe_rc})")
endif()
file(WRITE "${CMAKE_BINARY_DIR}/cmake_codegen/modules_probe.jsonl" "${_modules_probe_jsonl}")

string(REPLACE "\n" ";" _lines "${_modules_probe_jsonl}")

# _json_array(<json> <member> <out_var>)
# Reads a JSON array member into a CMake list (string(JSON) otherwise returns the
# array as a single bracketed string).
function(_json_array json member out_var)
    set(_arr "")
    set(_i 0)
    set(_len 0)
    string(JSON _len LENGTH "${json}" "${member}")
    while(_i LESS _len)
        string(JSON _v GET "${json}" "${member}" ${_i})
        list(APPEND _arr "${_v}")
        math(EXPR _i "${_i} + 1")
    endwhile()
    set(${out_var} "${_arr}" PARENT_SCOPE)
endfunction()

# _json_array_cmd(<json> "commands" <index> <member> <out_var>)
# Same as _json_array but indexes into a nested object of a JSON array.
function(_json_array_cmd json array_member index member out_var)
    set(_arr "")
    set(_i 0)
    set(_len 0)
    string(JSON _len LENGTH "${json}" "${array_member}" ${index} "${member}")
    while(_i LESS _len)
        string(JSON _v GET "${json}" "${array_member}" ${index} "${member}" ${_i})
        list(APPEND _arr "${_v}")
        math(EXPR _i "${_i} + 1")
    endwhile()
    set(${out_var} "${_arr}" PARENT_SCOPE)
endfunction()

set(GODOT_MODULE_TARGETS "")

# _godot_build_jpg_module(<json-line>)
# libjpeg-turbo's bit-dependent sources must be compiled once per sample depth
# (SCons does this via OBJSUFFIX). Mirror it with one OBJECT library per depth.
function(_godot_build_jpg_module json)
    set(_dir "${CMAKE_SOURCE_DIR}/thirdparty/libjpeg-turbo/src")
    set(_common
        jaricom.c jcapimin.c jcarith.c jchuff.c jcicc.c jcinit.c jcmarker.c
        jcmaster.c jcomapi.c jcparam.c jcphuff.c jctrans.c jdapimin.c jdarith.c
        jdatadst.c jdatadst-tj.c jdatasrc.c jdatasrc-tj.c jdhuff.c jdicc.c
        jdinput.c jdmarker.c jdmaster.c jdphuff.c jdtrans.c jerror.c jfdctflt.c
        jmemmgr.c jmemnobs.c jpeg_nbits.c transupp.c turbojpeg.c)
    set(_bit_dependent
        jcapistd.c jccoefct.c jccolor.c jcdctmgr.c jcmainct.c jcprepct.c
        jcsample.c jdcoefct.c jdcolor.c jdapistd.c jddctmgr.c jdmainct.c
        jdmerge.c jdpostct.c jdsample.c jfdctfst.c jfdctint.c jidctflt.c
        jidctfst.c jidctint.c jidctred.c jutils.c jquant1.c jquant2.c)

    set(_common_abs "")
    foreach(_f IN LISTS _common)
        list(APPEND _common_abs "${_dir}/${_f}")
    endforeach()
    set(_bit_abs "")
    foreach(_f IN LISTS _bit_dependent)
        list(APPEND _bit_abs "${_dir}/${_f}")
    endforeach()

    # Godot's own module sources (from the probe).
    _json_array("${json}" sources _mod_src)
    _json_array("${json}" includes _inc)

    foreach(_bits IN ITEMS 8 12)
        add_library(godot_jpg_turbo_${_bits} OBJECT ${_bit_abs})
        target_link_libraries(godot_jpg_turbo_${_bits} PRIVATE godot_options godot_thirdparty_options)
        target_include_directories(godot_jpg_turbo_${_bits} PRIVATE "${_dir}")
        target_compile_definitions(godot_jpg_turbo_${_bits} PRIVATE BITS_IN_JSAMPLE=${_bits})
        set_target_properties(godot_jpg_turbo_${_bits} PROPERTIES POSITION_INDEPENDENT_CODE ON)
    endforeach()

    add_library(godot_module_jpg STATIC ${_common_abs} ${_mod_src})
    target_link_libraries(godot_module_jpg
        PRIVATE godot_options godot_thirdparty_options godot_jpg_turbo_8 godot_jpg_turbo_12)
    target_link_libraries(godot_module_jpg PUBLIC godot_core)
    target_include_directories(godot_module_jpg PRIVATE "${_dir}" ${_inc})
    target_compile_definitions(godot_module_jpg PUBLIC GODOT_MODULE)
endfunction()

foreach(_line IN LISTS _lines)
    if(_line STREQUAL "")
        continue()
    endif()

    string(JSON _name GET "${_line}" name)
    string(JSON _err GET "${_line}" error)
    if(NOT _err STREQUAL "")
        message(STATUS "godot module probe: ${_name} -> ${_err}")
    endif()

    # Only build modules enabled for this configuration.
    string(TOUPPER "${_name}" _up)
    if(NOT GODOT_MODULE_${_up}_ENABLED)
        continue()
    endif()

    _json_array("${_line}" sources _src)
    _json_array("${_line}" thirdparty _tp)
    _json_array("${_line}" includes _inc)
    _json_array("${_line}" tp_includes _tpinc)
    _json_array("${_line}" generated _gen)

    # Defines are either "NAME" or ["NAME", value]; normalize to NAME / NAME=value.
    string(JSON _deflen LENGTH "${_line}" defines)
    set(_def "")
    set(_di 0)
    while(_di LESS _deflen)
        string(JSON _dval GET "${_line}" defines ${_di})
        if(_dval MATCHES "^\\[")
            string(JSON _dname GET "${_line}" defines ${_di} 0)
            string(JSON _dval2 GET "${_line}" defines ${_di} 1)
            string(REPLACE "\\\"" "\"" _dval2 "${_dval2}")
            list(APPEND _def "${_dname}=${_dval2}")
        else()
            # Strip surrounding quotes from the JSON string.
            string(REGEX REPLACE "^\"(.*)\"$" "\\1" _dname "${_dval}")
            list(APPEND _def "${_dname}")
        endif()
        math(EXPR _di "${_di} + 1")
    endwhile()

    string(JSON _tplen LENGTH "${_line}" tp_defines)
    set(_tpdef "")
    set(_ti 0)
    while(_ti LESS _tplen)
        string(JSON _dval GET "${_line}" tp_defines ${_ti})
        if(_dval MATCHES "^\\[")
            string(JSON _dname GET "${_line}" tp_defines ${_ti} 0)
            string(JSON _dval2 GET "${_line}" tp_defines ${_ti} 1)
            list(APPEND _tpdef "${_dname}=${_dval2}")
        else()
            string(REGEX REPLACE "^\"(.*)\"$" "\\1" _dname "${_dval}")
            list(APPEND _tpdef "${_dname}")
        endif()
        math(EXPR _ti "${_ti} + 1")
    endwhile()

    # Register any shader headers the module asked for (raw GLSL_HEADER), and split
# the generated list into compilable sources vs. headers.
set(_gen_sources "")
    set(_gen_headers "")
    # Wire any CommandNoCache generators the module's SCsub declared.
    string(JSON _ncmd LENGTH "${_line}" commands)
    set(_ci 0)
    while(_ci LESS _ncmd)
        string(JSON _cfunc GET "${_line}" commands ${_ci} func)
        if(_cfunc STREQUAL "make_templates")
            _json_array_cmd("${_line}" commands ${_ci} outputs _couts)
            _json_array_cmd("${_line}" commands ${_ci} sources _cins)
            get_filename_component(_cbase "${_couts}" NAME_WE)
            godot_codegen(make_templates "mod_${_name}_${_cbase}"
                OUTPUTS ${_couts}
                PATH_INPUTS ${_cins})
            list(APPEND _gen_headers ${_couts})
        elseif(_cfunc STREQUAL "make_icu_data")
            _json_array_cmd("${_line}" commands ${_ci} outputs _couts)
            _json_array_cmd("${_line}" commands ${_ci} sources _cins)
            get_filename_component(_cbase "${_couts}" NAME_WE)
            godot_codegen(make_icu_data "mod_${_name}_${_cbase}"
                OUTPUTS ${_couts}
                PATH_INPUTS ${_cins})
            list(APPEND _gen_headers ${_couts})
        endif()
        math(EXPR _ci "${_ci} + 1")
    endwhile()

    foreach(_g IN LISTS _gen)
        get_filename_component(_gname "${_g}" NAME)
        if(_gname MATCHES "\\.glsl\\.gen\\.h$")
            # The shader source is the same path minus the ".gen.h" suffix.
            string(REGEX REPLACE "\\.gen\\.h$" "" _gsrc "${_g}")
            godot_codegen(raw_glsl "mod_${_name}_${_gname}"
                OUTPUTS "${_g}"
                PATH_INPUTS "${_gsrc}")
            list(APPEND _gen_headers "${_g}")
        elseif(_gname MATCHES "\\.(c|cpp|cc|cxx)$")
            list(APPEND _gen_sources "${_g}")
        endif()
    endforeach()

    set(_all_sources ${_src} ${_tp} ${_gen_sources} ${_gen_headers})
    if(NOT _all_sources)
        # Header-only module (e.g. freetype): the thirdparty library is compiled
        # into this target, so it is not actually empty, but be defensive.
        if(NOT _tp)
            continue()
        endif()
    endif()

    set(_target "godot_module_${_name}")

    # libjpeg-turbo is compiled twice (8- and 12-bit samples) with a per-build
    # BITS_IN_JSAMPLE define, which the flat source list above cannot express.
    if(_name STREQUAL "jpg" AND GODOT_BUILTIN_LIBJPEG_TURBO)
        _godot_build_jpg_module("${_line}")
        list(APPEND GODOT_MODULE_TARGETS godot_module_jpg)
        continue()
    endif()

    add_library(${_target} STATIC ${_all_sources})
    target_link_libraries(${_target} PRIVATE godot_options godot_thirdparty_options)
    target_link_libraries(${_target} PUBLIC godot_core)
    add_dependencies(${_target} godot_generated)

    # Godot marks every module translation unit with GODOT_MODULE.
    target_compile_definitions(${_target} PUBLIC GODOT_MODULE)
    if(_inc)
        target_include_directories(${_target} PRIVATE ${_inc})
    endif()
    # Define that carries a quoted string value (e.g. MBEDTLS_CONFIG_FILE="...").
# target_compile_definitions would re-quote/escape the inner quotes, so pass it
# as a raw compile option with SHELL: to preserve the literal.
if(_def)
    set(_plain_defs "")
    set(_raw_defs "")
    foreach(_d IN LISTS _def)
        if(_d MATCHES "^([A-Za-z_][A-Za-z0-9_]*)=(.*\"[^\"]*\")$")
            list(APPEND _raw_defs "SHELL:-D${CMAKE_MATCH_1}=${CMAKE_MATCH_2}")
        else()
            list(APPEND _plain_defs "${_d}")
        endif()
    endforeach()
    if(_plain_defs)
        target_compile_definitions(${_target} PRIVATE ${_plain_defs})
    endif()
    if(_raw_defs)
        target_compile_options(${_target} PRIVATE ${_raw_defs})
    endif()
endif()
    if(_tpinc)
        target_include_directories(${_target} PRIVATE ${_tpinc})
    endif()
    if(_tpdef)
        target_compile_definitions(${_target} PRIVATE ${_tpdef})
    endif()

    list(APPEND GODOT_MODULE_TARGETS ${_target})
endforeach()

list(LENGTH GODOT_MODULE_TARGETS _module_target_count)
message(STATUS "Godot CMake port: configured ${_module_target_count} module target(s).")

# The `modules` aggregator library contains only register_module_types.gen.cpp,
# mirroring modules/SCsub's final libmodules.a. It must come last on the link
# line so every libmodule_<name>.a precedes it.
add_library(godot_modules STATIC
    "${CMAKE_SOURCE_DIR}/modules/register_module_types.gen.cpp")
target_link_libraries(godot_modules PRIVATE godot_options)
add_dependencies(godot_modules godot_generated)
# =============================================================================
# Final executable (mirrors the SCons link order; debug build, not stripped)
# =============================================================================
# Link order mirrors SCons: core, servers, scene, editor, drivers, platform,
# each libmodule_<name>.a, libmodules.a, main, then the platform backend.

# main() lives in the platform backend (platform/linuxbsd/godot_linuxbsd.cpp),
# which is compiled into godot_linuxbsd; list it here so CMake has a source.
add_executable(godot_exe
    "${CMAKE_SOURCE_DIR}/platform/linuxbsd/godot_linuxbsd.cpp"
)
set_target_properties(godot_exe PROPERTIES
    OUTPUT_NAME "${GODOT_PROGRAM_NAME}"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin"
    LINKER_LANGUAGE CXX
)

# Link order mirrors SCons: core, servers, scene, editor, drivers, platform,
# each libmodule_<name>.a, libmodules.a, main, then the platform backend.
# Godot's static libraries have cyclic dependencies (modules reference editor
# symbols such as the 3->4 renames map; editor references module symbols), so
# the archives must be resolved as a group rather than in a single pass.
target_link_libraries(godot_exe PRIVATE
    "-Wl,--start-group"
    godot_core
    godot_servers
    godot_scene
    $<$<BOOL:${_godot_editor_build}>:godot_editor>
    godot_drivers
    godot_platform
    ${GODOT_MODULE_TARGETS}
    godot_modules
    godot_main
    godot_linuxbsd
    "-Wl,--end-group"
    godot_options
)

# System libraries (detect.py, with use_sowrap the dev headers are bundled and
# the real libraries are resolved by the dynamic loader at runtime).
find_package(Threads REQUIRED)
target_link_libraries(godot_exe PRIVATE
    Threads::Threads
    ${CMAKE_DL_LIBS}
    m
)

if(GODOT_WAYLAND)
    target_link_libraries(godot_exe PRIVATE rt)
endif()

# --- pkg-config based system dependencies ---
# Only needed when the corresponding builtin_* is turned off.
if(NOT GODOT_BUILTIN_FREETYPE)
    pkg_check_modules(FREETYPE REQUIRED freetype2)
    target_link_libraries(godot_exe PRIVATE ${FREETYPE_LIBRARIES})
    target_include_directories(godot_exe PRIVATE ${FREETYPE_INCLUDE_DIRS})
endif()
if(NOT GODOT_BUILTIN_ICU4C)
    pkg_check_modules(ICU REQUIRED icu-i18n icu-uc)
    target_link_libraries(godot_exe PRIVATE ${ICU_LIBRARIES})
    target_include_directories(godot_exe PRIVATE ${ICU_INCLUDE_DIRS})
endif()
if(NOT GODOT_BUILTIN_HARFBUZZ)
    pkg_check_modules(HARFBUZZ REQUIRED harfbuzz harfbuzz-icu)
    target_link_libraries(godot_exe PRIVATE ${HARFBUZZ_LIBRARIES})
    target_include_directories(godot_exe PRIVATE ${HARFBUZZ_INCLUDE_DIRS})
endif()
if(NOT GODOT_BUILTIN_LIBPNG)
    pkg_check_modules(PNG REQUIRED libpng16)
    target_link_libraries(godot_exe PRIVATE ${PNG_LIBRARIES})
endif()
if(NOT GODOT_BUILTIN_ZLIB)
    pkg_check_modules(ZLIB REQUIRED zlib)
    target_link_libraries(godot_exe PRIVATE ${ZLIB_LIBRARIES})
endif()

# Static libstdc++/libgcc for portable binaries (detect.py use_static_cpp).
if(GODOT_USE_STATIC_CPP)
    target_link_options(godot_exe PRIVATE -static-libgcc -static-libstdc++)
endif()

add_dependencies(godot_exe godot_generated)