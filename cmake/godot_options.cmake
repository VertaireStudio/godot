# Global compile options for the CMake port of Godot.
# Mirrors the shared flag/define setup done in SConstruct for a linuxbsd
# x86_64 editor build. Everything flows through the `godot_options` INTERFACE
# target so subsystems only need to link against it.

include_guard(GLOBAL)

find_package(PkgConfig REQUIRED)
find_package(Python3 REQUIRED COMPONENTS Interpreter)
find_package(Threads REQUIRED)

# Sanity checks (only the ported configuration is supported right now).
if(NOT GODOT_PLATFORM STREQUAL "linuxbsd")
    message(FATAL_ERROR "Only GODOT_PLATFORM=linuxbsd is ported at this time.")
endif()
if(NOT GODOT_ARCH STREQUAL "x86_64")
    message(FATAL_ERROR "Only GODOT_ARCH=x86_64 is ported at this time.")
endif()

# ``godot_options`` carries the common flags for all engine translation units.
add_library(godot_options INTERFACE)
add_library(godot::options ALIAS godot_options)

target_include_directories(godot_options INTERFACE
    "${CMAKE_SOURCE_DIR}"
    "${CMAKE_BINARY_DIR}"
)

# Platform include path (detect.py: env.Prepend(CPPPATH=["#platform/linuxbsd"])).
target_include_directories(godot_options INTERFACE
    "${CMAKE_SOURCE_DIR}/platform/linuxbsd"
)

if(GODOT_OPENGL3)
    # glad loader headers are included as <thirdparty/glad/glad/egl.h>.
    target_include_directories(godot_options INTERFACE
        "${CMAKE_SOURCE_DIR}/thirdparty/glad"
    )
endif()
if(GODOT_VULKAN)
    target_include_directories(godot_options INTERFACE
        "${CMAKE_SOURCE_DIR}/thirdparty/vulkan/include"
    )
endif()

# libpng / zlib are put on the *global* include path by drivers/png/SCsub, and
# several modules (e.g. harfbuzz in text_server_adv) rely on that.
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

# Bundled so_wrap system headers (detect.py: use_sowrap adds
# #thirdparty/linuxbsd_headers plus the wayland/ and libdecor-0/ subdirs).
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

# Core platform defines (detect.py ~444).
target_compile_definitions(godot_options INTERFACE
    LINUXBSD_ENABLED
    UNIX_ENABLED
    _FILE_OFFSET_BITS=64
)

if(GODOT_OPENGL3)
    target_compile_definitions(godot_options INTERFACE GLES3_ENABLED)
    # GLAD / EGL loader (drivers/gl_context/SCsub sets these on the main env).
    target_compile_definitions(godot_options INTERFACE GLAD_ENABLED EGL_ENABLED GLAD_GLES2)
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
    CXX_EXTENSIONS ON # GNU extensions (gnu++17), matches SCons -std=gnu++17
)

# --- Preprocessor defines ----------------------------------------------------
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
    list(APPEND _godot_defines TOOLS_ENABLED)
    list(APPEND _godot_defines ENGINE_UPDATE_CHECK_ENABLED)
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

# --- Compiler flags ----------------------------------------------------------
set(_godot_cflags
    -pipe
    -ffp-contract=off
    -fno-diagnostics-color
)

# x86_64 SSE/AVX tuning (SConstruct ~796).
list(APPEND _godot_cflags -msse4.2 -mpopcnt)

# Optimization level -> -O flag.
if(_godot_opt_level STREQUAL "speed")
    set(_godot_opt_flags -O3)
elseif(_godot_opt_level STREQUAL "speed_trace")
    set(_godot_opt_flags -O2)
elseif(_godot_opt_level STREQUAL "size" OR _godot_opt_level STREQUAL "size_extra")
    set(_godot_opt_flags -Os)
elseif(_godot_opt_level STREQUAL "debug")
    set(_godot_opt_flags -Og)
elseif(_godot_opt_level STREQUAL "none")
    set(_godot_opt_flags -O0)
else() # custom
    set(_godot_opt_flags "")
endif()

# Debug symbols.
if(_godot_debug_symbols)
    if(GODOT_DEV_BUILD)
        list(APPEND _godot_cflags -g3)
    else()
        list(APPEND _godot_cflags -gdwarf-4 -g2)
    endif()
    if(GODOT_DEBUG_PATHS_RELATIVE)
        list(APPEND _godot_cflags "-ffile-prefix-map=${CMAKE_SOURCE_DIR}=.")
    endif()
endif()

# Exceptions.
if(GODOT_DISABLE_EXCEPTIONS)
    list(APPEND _godot_cxxflags -fno-exceptions)
endif()

# Warnings (GCC/Clang path in SConstruct).
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
else() # no
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

# --- Link flags --------------------------------------------------------------
set(_godot_linkflags "")
if(NOT _godot_debug_symbols)
    list(APPEND _godot_linkflags -s) # strip
endif()
list(APPEND _godot_linkflags ${_godot_opt_flags})

if(GODOT_LTO STREQUAL "full")
    list(APPEND _godot_cflags -flto)
    list(APPEND _godot_linkflags -flto)
endif()

target_link_options(godot_options INTERFACE ${_godot_linkflags})

# Thirdparty code compiles with warnings disabled.
add_library(godot_thirdparty_options INTERFACE)
add_library(godot::thirdparty_options ALIAS godot_thirdparty_options)
target_link_libraries(godot_thirdparty_options INTERFACE godot_options)
target_compile_options(godot_thirdparty_options INTERFACE -w)