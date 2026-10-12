# drivers library (mirrors drivers/SCsub + the linuxbsd-relevant sub-SCsubs).
# Only the driver directories that drivers/SCsub enables for a linuxbsd editor
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