# cmake/release.cmake
#
# Hand-written CMake *script* (run as: cmake -P cmake/release.cmake --build).
#
# Drives an optimized "editor" (release) build of the Godot workspace:
#   1. run the Python code generators for target=editor,
#   2. rewrite the discovered per-translation-unit commands into a Makefile and
#      append the aggressive release optimization flags,
#   3. compile every TU in parallel with `make -jN` (incremental on re-runs),
#   4. verify every object exists,
#   5. link the final optimized executable.
#
# This is the single CMake file required for the release build. It relies on the
# (already present) cmake/gen_sources.py + cmake/gen_codegen.py helpers, which
# are parameterized to also describe an optimized editor configuration.
#
# Like debug.cmake this file intentionally does NOT create CMake targets: script
# mode is used, and there must be no CMakeLists.txt anywhere.

cmake_minimum_required(VERSION 3.20)

# ---------------------------------------------------------------------------
# 1. Argument parsing (CMAKE_ARGV0..N holds the raw command line)
# ---------------------------------------------------------------------------
set(_action "build")
set(_jobs "")

set(_n ${CMAKE_ARGC})
set(_i 0)
while(_i LESS _n)
    set(_arg "${CMAKE_ARGV${_i}}")
    if(_arg STREQUAL "--build")
        set(_action "build")
    elseif(_arg STREQUAL "--clean")
        set(_action "clean")
    elseif(_arg STREQUAL "--jobs")
        math(EXPR _j "${_i} + 1")
        set(_jobs "${CMAKE_ARGV${_j}}")
    endif()
    math(EXPR _i "${_i} + 1")
endwhile()

# ---------------------------------------------------------------------------
# 2. Paths
# ---------------------------------------------------------------------------
get_filename_component(CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}" ABSOLUTE)
get_filename_component(ROOT "${CMAKE_DIR}" DIRECTORY)
set(BUILD    "${ROOT}/bin/obj-release")
set(OBJ      "${BUILD}/obj")
set(GEN      "${BUILD}/gen")
set(MAKEFILE "${BUILD}/Makefile")
set(OUT      "${ROOT}/bin/godot.linuxbsd.editor.x86_64")

message(STATUS "[godot-release] root   = ${ROOT}")
message(STATUS "[godot-release] build  = ${BUILD}")
message(STATUS "[godot-release] output = ${OUT}")
message(STATUS "[godot-release] action = ${_action}")

if(_action STREQUAL "clean")
    message(STATUS "[godot-release] removing ${BUILD}")
    file(REMOVE_RECURSE "${BUILD}")
    message(STATUS "[godot-release] clean done")
    return()
endif()

if(_jobs STREQUAL "")
    execute_process(COMMAND nproc OUTPUT_VARIABLE _jobs OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(_jobs STREQUAL "")
        set(_jobs 1)
    endif()
endif()

file(MAKE_DIRECTORY "${OBJ}")
file(MAKE_DIRECTORY "${GEN}")

# ---------------------------------------------------------------------------
# 3. Release optimization flags appended to every translation unit.
#
#    -O3/-march=native/-mtune=native : peak code generation for this machine.
#    -ffunction-sections/-fdata-sections + link --gc-sections : drop dead code.
#    -fno-plt / -fno-semantic-interposition : cheaper external calls.
#    -fno-math-errno : allow errno-free math (determinism preserved because the
#                      engine's own -ffp-contract=off is left untouched; we do
#                      NOT enable -ffast-math).
#    NDEBUG is already emitted by gen_sources.py for non-dev builds.
#    No LTO: full GCC LTO on ~2.5k TUs would exhaust this machine's RAM.
# ---------------------------------------------------------------------------
set(_PERF
    "-O3"
    "-march=native"
    "-mtune=native"
    "-ffunction-sections"
    "-fdata-sections"
    "-fno-plt"
    "-fno-semantic-interposition"
    "-fomit-frame-pointer"
    "-funroll-loops"
    "-fno-math-errno"
    "-pipe"
)
string(REPLACE ";" " " _PERF_STR "${_PERF}")

# ---------------------------------------------------------------------------
# 4. Code generation
# ---------------------------------------------------------------------------
message(STATUS "[godot-release] step 1/4: code generation")
execute_process(
    COMMAND python3 "${ROOT}/cmake/gen_sources.py" "${ROOT}" ""
            --target editor
            --dev-build no
            --debug-symbols no
            --optimize speed
            --production yes
            --build-dir bin/obj-release
            --suffix release
    WORKING_DIRECTORY "${ROOT}"
    RESULT_VARIABLE _rc
)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "[godot-release] gen_sources.py failed (${_rc})")
endif()

execute_process(
    COMMAND python3 "${ROOT}/cmake/gen_codegen.py" "${ROOT}" "${GEN}/modules_enabled.txt"
    WORKING_DIRECTORY "${ROOT}"
    RESULT_VARIABLE _rc
)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "[godot-release] gen_codegen.py failed (${_rc})")
endif()

# ---------------------------------------------------------------------------
# 5. Turn the discovered commands into a Makefile (parallel + incremental),
#    appending the release optimization flags to every recipe.
#
#    The command lines are already shell-escaped by gen_sources.py (embedded
#    double quotes are written as \"), so they can be used verbatim as make
#    recipes.
# ---------------------------------------------------------------------------
message(STATUS "[godot-release] step 2/4: generating Makefile")
set(_commands_file "${GEN}/commands_release.txt")
if(NOT EXISTS "${_commands_file}")
    message(FATAL_ERROR "[godot-release] missing ${_commands_file}")
endif()
file(STRINGS "${_commands_file}" _commands)

set(_rules "")
set(_objects "")
foreach(_line IN LISTS _commands)
    if(_line STREQUAL "")
        continue()
    endif()

    string(REGEX MATCH "-c ([^ ]+)" _mc "${_line}")
    set(_src "${CMAKE_MATCH_1}")
    string(REGEX MATCH "-o ([^ ]+)" _mo "${_line}")
    set(_obj "${CMAKE_MATCH_1}")
    if(_src STREQUAL "" OR _obj STREQUAL "")
        message(FATAL_ERROR "[godot-release] malformed command: ${_line}")
    endif()

    get_filename_component(_odir "${_obj}" DIRECTORY)
    string(APPEND _rules "${_obj}: ${_src}\n")
    string(APPEND _rules "\t@mkdir -p ${_odir}\n")

    # Embree selects its SIMD namespace from the compiler's ISA macros. Giving
    # it -march=native makes it emit avx2-namespace symbols that its own
    # non-avx2 kernels cannot resolve. Leave Embree exactly as discovered
    # (it already builds at -O3 via force_optimization_on_debug).
    if(_src MATCHES "^thirdparty/embree/")
        string(APPEND _rules "\t${_line}\n")
    else()
        # Baseline SSE flags are superseded by -march=native.
        string(REPLACE " -msse4.2" "" _line "${_line}")
        string(REPLACE " -mpopcnt" "" _line "${_line}")
        string(APPEND _rules "\t${_line} ${_PERF_STR}\n")
    endif()

    list(APPEND _objects "${_obj}")
endforeach()

list(LENGTH _objects _total)
if(_total EQUAL 0)
    message(FATAL_ERROR "[godot-release] no translation units were discovered")
endif()

string(REPLACE ";" " " _all_objs "${_objects}")
file(WRITE "${MAKEFILE}" "all: ${_all_objs}\n\n${_rules}")

# ---------------------------------------------------------------------------
# 6. Compile in parallel (make stops on the first failure).
# ---------------------------------------------------------------------------
message(STATUS "[godot-release] step 3/4: compiling ${_total} translation units (make -j${_jobs})")
execute_process(
    COMMAND make -j${_jobs} -f "${MAKEFILE}" all
    WORKING_DIRECTORY "${ROOT}"
    RESULT_VARIABLE _rc
)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "[godot-release] COMPILE FAILED (${_rc})")
endif()

# ---------------------------------------------------------------------------
# 7. Verify all objects were produced
# ---------------------------------------------------------------------------
set(_missing 0)
foreach(_obj IN LISTS _objects)
    if(NOT EXISTS "${ROOT}/${_obj}")
        message(SEND_ERROR "[godot-release] missing object: ${_obj}")
        math(EXPR _missing "${_missing} + 1")
    endif()
endforeach()
if(NOT _missing EQUAL 0)
    message(FATAL_ERROR "[godot-release] ${_missing} object file(s) missing; aborting before link")
endif()

# ---------------------------------------------------------------------------
# 8. Link (response file keeps the command line within limits)
# ---------------------------------------------------------------------------
message(STATUS "[godot-release] step 4/4: linking ${OUT}")
set(_rsp "${BUILD}/link.rsp")
file(WRITE "${_rsp}" "")
foreach(_obj IN LISTS _objects)
    file(APPEND "${_rsp}" "${ROOT}/${_obj}\n")
endforeach()

# Only request gold if it is actually available to the active toolchain.
# Editor/kit environments sometimes expose a compiler whose search path has
# `ld`/`as` but no `ld.gold`; hardcoding -fuse-ld=gold then dies with
# "collect2: fatal error: cannot find 'ld'". Because the linker is resolved
# by name, point the compiler at the directory that holds it with -B.
find_program(GOLD_LD NAMES ld.gold)
set(_ld_flags "")
if(GOLD_LD)
    get_filename_component(_gold_dir "${GOLD_LD}" DIRECTORY)
    list(APPEND _ld_flags "-B${_gold_dir}" "-fuse-ld=gold")
    message(STATUS "[godot-release] linker: gold (${GOLD_LD})")
else()
    message(STATUS "[godot-release] linker: default (ld.gold not found)")
endif()

execute_process(
    COMMAND g++ -o "${OUT}" -pie
            -O3 -march=native -mtune=native
            ${_ld_flags}
            -Wl,-O2 -Wl,--as-needed -Wl,--gc-sections
            -Wl,-z,relro -Wl,-z,now
            -static-libgcc -static-libstdc++
            -s "@${_rsp}" -lrt -lpthread -ldl
    WORKING_DIRECTORY "${ROOT}"
    RESULT_VARIABLE _rc
)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "[godot-release] LINK FAILED (${_rc})")
endif()

if(NOT EXISTS "${OUT}")
    message(FATAL_ERROR "[godot-release] link reported success but ${OUT} does not exist")
endif()

message(STATUS "[godot-release] built ${OUT}")
