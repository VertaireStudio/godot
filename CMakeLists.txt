# CMake port of the Godot 4.7-dev engine build.
# Mirrors the default SCons configuration for a linuxbsd x86_64 editor build.
# Usage:
#   cmake --build cmake-build

cmake_minimum_required(VERSION 3.22)

project(godot
    VERSION 4.7.0
    DESCRIPTION "Godot Engine - CMake"
    LANGUAGES C CXX ASM
)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    # Default to the "speed_trace"-like settings used for editor builds.
    set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "" FORCE)
endif()

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_POSITION_INDEPENDENT_CODE OFF)
set(CMAKE_C_STANDARD 17)
set(CMAKE_CXX_STANDARD 17)

# Godot releases these next to the source tree under bin/, like SCons does.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin")
foreach(_cfg IN LISTS CMAKE_CONFIGURATION_TYPES)
    string(TOUPPER "${_cfg}" _cfg_upper)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${_cfg_upper} "${CMAKE_SOURCE_DIR}/bin")
endforeach()

option(GODOT_DEBUG_BUILD "Build the entire workspace as a self-contained dev/debug executable" OFF)

if(GODOT_DEBUG_BUILD)
    # Self-contained debug build: cmake/debug.cmake defines the codegen rules,
    # every engine library, every module and the final executable on its own.
    include(cmake/debug.cmake)
    return()
endif()

include(cmake/options.cmake)
include(cmake/godot_options.cmake)

message(STATUS "Godot CMake port: platform=${GODOT_PLATFORM} target=${GODOT_TARGET} arch=${GODOT_ARCH} precision=${GODOT_PRECISION}")
message(STATUS "Godot CMake port: optimize=${_godot_opt_level} debug_symbols=${_godot_debug_symbols} program=${GODOT_PROGRAM_NAME}")

# Code generators + generated-source rules (Phase 1).
include(cmake/generated.cmake)

# Engine subsystems (Phases 2-4).
include(cmake/thirdparty/core_thirdparty.cmake)
include(cmake/core.cmake)
include(cmake/servers.cmake)
include(cmake/scene.cmake)
include(cmake/drivers.cmake)
include(cmake/platform.cmake)
if(_godot_editor_build)
    include(cmake/editor.cmake)
endif()
include(cmake/modules.cmake)
include(cmake/main.cmake)
include(cmake/link.cmake)