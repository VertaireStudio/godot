# CMake port of Godot's SCons build options.
# Each option mirrors a corresponding `opts.Add(...)` in SConstruct /
# platform/*/detect.py so that the CMake build accepts the same knobs.

include_guard(GLOBAL)

# ---- Target build options ----------------------------------------------------
set(GODOT_PLATFORM "linuxbsd" CACHE STRING "Target platform (only linuxbsd is ported so far)")
set(GODOT_TARGET "editor" CACHE STRING "Compilation target (editor|template_release|template_debug)")
set(GODOT_ARCH "x86_64" CACHE STRING "CPU architecture (only x86_64 is ported so far)")
option(GODOT_DEV_BUILD "Developer build with dev-only debugging code (DEV_ENABLED)" OFF)
set(GODOT_OPTIMIZE "auto" CACHE STRING "Optimization level (auto|none|custom|debug|speed|speed_trace|size|size_extra)")
option(GODOT_DEBUG_SYMBOLS "Build with debugging symbols" OFF)
option(GODOT_SEPARATE_DEBUG_SYMBOLS "Extract debugging symbols to a separate file" OFF)
option(GODOT_DEBUG_PATHS_RELATIVE "Make file paths in debug symbols relative (if supported)" OFF)
set(GODOT_LTO "none" CACHE STRING "Link-time optimization (none|auto|thin|full)")
option(GODOT_PRODUCTION "Set defaults to build Godot for use in production" OFF)
option(GODOT_THREADS "Enable threading support" ON)

# ---- Components --------------------------------------------------------------
option(GODOT_DEPRECATED "Enable compatibility code for deprecated and removed features" ON)
set(GODOT_PRECISION "single" CACHE STRING "Set the floating-point precision level (single|double)")
option(GODOT_MINIZIP "Enable ZIP archive support using minizip" ON)
option(GODOT_BROTLI "Enable Brotli for decompression and WOFF2 fonts support" ON)
option(GODOT_VULKAN "Enable the Vulkan rendering driver" ON)
option(GODOT_OPENGL3 "Enable the OpenGL/GLES3 rendering driver" ON)
option(GODOT_D3D12 "Enable the Direct3D 12 rendering driver" OFF)
option(GODOT_METAL "Enable the Metal rendering driver (Apple arm64 only)" OFF)
option(GODOT_USE_VOLK "Use the volk library to load the Vulkan loader dynamically" ON)
option(GODOT_ACCESSKIT "Enable the AccessKit driver for screen reader support" ON)
set(GODOT_ACCESSKIT_SDK_PATH "${CMAKE_BINARY_DIR}/accesskit" CACHE STRING "Path to the AccessKit C SDK")
option(GODOT_ANGLE "Enable the ANGLE rendering driver for OpenGL ES 3.0" ON)
option(GODOT_SDL "Enable the SDL3 input driver" ON)

# ---- Debug / diagnostics -----------------------------------------------------
set(GODOT_WARNINGS "all" CACHE STRING "Level of compilation warnings (extra|all|moderate|no)")
option(GODOT_WERROR "Treat compiler warnings as errors" OFF)
option(GODOT_USE_PRECISE_MATH_CHECKS "Math checks use very precise epsilon (debug option)" OFF)
option(GODOT_STRICT_CHECKS "Enforce stricter checks (debug option)" OFF)
option(GODOT_DISABLE_EXCEPTIONS "Force disabling exception handling code" ON)
option(GODOT_LIMIT_TRANSITIVE_INCLUDES "Attempt to limit transitive includes in system headers" ON)

# ---- Feature trimming --------------------------------------------------------
option(GODOT_DISABLE_3D "Disable 3D nodes for a smaller executable" OFF)
option(GODOT_DISABLE_ADVANCED_GUI "Disable advanced GUI nodes and behaviors" OFF)
option(GODOT_DISABLE_PHYSICS_2D "Disable 2D physics nodes and server" OFF)
option(GODOT_DISABLE_PHYSICS_3D "Disable 3D physics nodes and server" OFF)
option(GODOT_DISABLE_NAVIGATION_2D "Disable 2D navigation features" OFF)
option(GODOT_DISABLE_NAVIGATION_3D "Disable 3D navigation features" OFF)
option(GODOT_DISABLE_XR "Disable XR nodes and server" OFF)
option(GODOT_DISABLE_OVERRIDES "Disable project settings overrides (override.cfg)" OFF)
option(GODOT_DISABLE_PATH_OVERRIDES "Disable CLI path overrides (export template only)" ON)

# ---- Misc --------------------------------------------------------------------
option(GODOT_NO_EDITOR_SPLASH "Don't use the custom splash screen for the editor" ON)
option(GODOT_ENGINE_UPDATE_CHECK "Enable engine update checks in the Project Manager" ON)
option(GODOT_STEAMAPI "Enable minimal SteamAPI integration for usage time tracking" OFF)
option(GODOT_TESTS "Build the unit tests" OFF)
option(GODOT_SCU_BUILD "Use single compilation unit build" OFF)
option(GODOT_MODULES_ENABLED_BY_DEFAULT "If no, disable all modules except ones explicitly enabled" ON)
set(GODOT_BUILD_PROFILE "" CACHE STRING "Path to a file containing a feature build profile")
set(GODOT_SYSTEM_CERTS_PATH "" CACHE STRING "Use this path as TLS certificates default")
set(GODOT_EXTRA_SUFFIX "" CACHE STRING "Custom extra suffix added to the base filename")
set(GODOT_SCRIPT_AES256_ENCRYPTION_KEY "" CACHE STRING "Custom AES256 script encryption key")

# ---- LinuxBSD platform options (platform/linuxbsd/detect.py) ------------------
option(GODOT_ALSA "Use ALSA" ON)
option(GODOT_PULSEAUDIO "Use PulseAudio" ON)
option(GODOT_DBUS "Use D-Bus for screensaver/portal settings" ON)
option(GODOT_SPEECHD "Use Speech Dispatcher for Text-to-Speech support" ON)
option(GODOT_FONTCONFIG "Use fontconfig for system fonts support" ON)
option(GODOT_UDEV "Use udev for gamepad connection callbacks" ON)
option(GODOT_X11 "Enable X11 display" ON)
# NOTE: Wayland is implemented but currently defaults OFF in the CMake port:
# the bundled wayland headers under thirdparty/linuxbsd_headers and the protocol
# XMLs under thirdparty/wayland-protocols are version-mismatched, which breaks
# wayland_thread.h. Enable with -DGODOT_WAYLAND=ON once headers are realigned.
option(GODOT_WAYLAND "Enable Wayland display" OFF)
option(GODOT_LIBDECOR "Enable libdecor support" ON)
option(GODOT_TOUCH "Enable touch events" ON)
option(GODOT_EXECINFO "Use libexecinfo on systems where glibc is not available" OFF)
option(GODOT_USE_SOWRAP "Dynamically load system libraries" ON)
option(GODOT_USE_STATIC_CPP "Link libgcc and libstdc++ statically" OFF)
option(GODOT_USE_LLVM "Use the LLVM compiler" OFF)

# ---- Thirdparty (all builtin by default) -------------------------------------
set(GODOT_BUILTIN_DEFAULTS ON)
foreach(_bt
        brotli certs clipper2 embree enet freetype msdfgen glslang graphite harfbuzz
        sdl icu4c libjpeg_turbo libogg libpng libtheora libvorbis libwebp wslay
        mbedtls miniupnpc openxr pcre2 pcre2_with_jit recastnavigation rvo2_2d
        rvo2_3d xatlas zlib zstd)
    string(TOUPPER "${_bt}" _bt_up)
    option(GODOT_BUILTIN_${_bt_up} "Use the built-in ${_bt} library" ON)
endforeach()

# ---- Derived flags ------------------------------------------------------------
# Mirrors SConstruct editor_build/debug_features/optimize resolution.
if(GODOT_TARGET STREQUAL "editor")
    set(_godot_editor_build ON)
else()
    set(_godot_editor_build OFF)
endif()

if(GODOT_TARGET STREQUAL "editor" OR GODOT_TARGET STREQUAL "template_debug")
    set(_godot_debug_features ON)
else()
    set(_godot_debug_features OFF)
endif()

if(GODOT_OPTIMIZE STREQUAL "auto")
    if(GODOT_DEV_BUILD)
        set(_godot_opt_level "none")
    elseif(_godot_debug_features)
        set(_godot_opt_level "speed_trace")
    else()
        set(_godot_opt_level "speed")
    endif()
else()
    set(_godot_opt_level "${GODOT_OPTIMIZE}")
endif()

if(GODOT_DEV_BUILD)
    set(_godot_debug_symbols ON)
else()
    set(_godot_debug_symbols ${GODOT_DEBUG_SYMBOLS})
endif()

if(GODOT_PRODUCTION)
    set(GODOT_LTO_AUTO ON)
endif()

# AccessKit requires its external SDK; disable the driver when it is absent
# (mirrors detect.py, which warns and turns accesskit off).
if(GODOT_ACCESSKIT AND NOT EXISTS "${GODOT_ACCESSKIT_SDK_PATH}/include/accesskit.h")
    message(STATUS "AccessKit SDK not found at '${GODOT_ACCESSKIT_SDK_PATH}' - disabling the accesskit driver.")
    set(GODOT_ACCESSKIT OFF)
endif()

# Suffix: .<platform>.<target>[.dev][.double].<arch>[.nothreads]
set(GODOT_SUFFIX ".${GODOT_PLATFORM}.${GODOT_TARGET}")
if(GODOT_DEV_BUILD)
    string(APPEND GODOT_SUFFIX ".dev")
endif()
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