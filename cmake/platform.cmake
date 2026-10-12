# platform library + the active platform (linuxbsd) backend.
# Mirrors platform/SCsub and platform/linuxbsd/SCsub (+ x11/wayland subdirs).

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