# Final executable (mirrors the SCons link order in SConstruct + detect.py).
#
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