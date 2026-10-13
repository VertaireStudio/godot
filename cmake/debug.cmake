# cmake/debug.cmake
#
# Hand-written CMake *script* (run as: cmake -P cmake/debug.cmake --build).
#
# It drives the whole editor/dev (debug) build of the Godot workspace:
#   1. run the Python code generators,
#   2. run the pure-Python SCons shim to (re)generate the ordered source list and
#      the per-translation-unit compile commands,
#   3. compile every translation unit SEQUENTIALLY (hard-failing on any error),
#   4. verify every object exists,
#   5. link the final executable.
#
# This file intentionally does NOT create CMake targets: script mode is required
# by the task (and there must be no CMakeLists.txt anywhere).

cmake_minimum_required(VERSION 3.20)

# ---------------------------------------------------------------------------
# 1. Argument parsing (CMAKE_ARGV0..N holds the raw command line)
# ---------------------------------------------------------------------------
set(_action "build")
set(_jobs 1)

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
set(BUILD "${ROOT}/bin/obj-debug")
set(OBJ   "${BUILD}/obj")
set(GEN   "${BUILD}/gen")
set(OUT   "${ROOT}/bin/godot.linuxbsd.editor.dev.x86_64")

message(STATUS "[godot-cmake] root   = ${ROOT}")
message(STATUS "[godot-cmake] build  = ${BUILD}")
message(STATUS "[godot-cmake] action = ${_action}")

if(_action STREQUAL "clean")
    message(STATUS "[godot-cmake] removing ${BUILD}")
    file(REMOVE_RECURSE "${BUILD}")
    message(STATUS "[godot-cmake] clean done")
    return()
endif()

file(MAKE_DIRECTORY "${OBJ}")
file(MAKE_DIRECTORY "${GEN}")

# ---------------------------------------------------------------------------
# 3. Code generation
# ---------------------------------------------------------------------------
message(STATUS "[godot-cmake] step 1/4: code generation")
execute_process(
    COMMAND python3 "${ROOT}/cmake/gen_sources.py" "${ROOT}" "${BUILD}/plan.txt"
    WORKING_DIRECTORY "${ROOT}"
    RESULT_VARIABLE _rc
)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "[godot-cmake] gen_sources.py failed (${_rc})")
endif()

execute_process(
    COMMAND python3 "${ROOT}/cmake/gen_codegen.py" "${ROOT}" "${GEN}/modules_enabled.txt"
    WORKING_DIRECTORY "${ROOT}"
    RESULT_VARIABLE _rc
)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "[godot-cmake] gen_codegen.py failed (${_rc})")
endif()

# ---------------------------------------------------------------------------
# 4. Compile every translation unit, sequentially, in list order
# ---------------------------------------------------------------------------
if(NOT EXISTS "${GEN}/commands_debug.txt")
    message(FATAL_ERROR "[godot-cmake] missing ${GEN}/commands_debug.txt")
endif()
file(STRINGS "${GEN}/commands_debug.txt" _commands)

list(LENGTH _commands _total)
message(STATUS "[godot-cmake] step 2/4: compiling ${_total} translation units (sequential)")

set(_objects "")
set(_index 0)
foreach(_line IN LISTS _commands)
    math(EXPR _index "${_index} + 1")
    if(_line STREQUAL "")
        continue()
    endif()

    separate_arguments(_cmd UNIX_COMMAND "${_line}")

    # Locate the object (-o) and source (-c) operands for incremental checks.
    list(FIND _cmd "-o" _oi)
    list(FIND _cmd "-c" _si)
    if(_oi EQUAL -1 OR _si EQUAL -1)
        message(FATAL_ERROR "[godot-cmake] malformed command: ${_line}")
    endif()
    math(EXPR _oj "${_oi} + 1")
    math(EXPR _sj "${_si} + 1")
    list(GET _cmd ${_oj} _obj)
    list(GET _cmd ${_sj} _src)

    list(APPEND _objects "${_obj}")

    get_filename_component(_odir "${_obj}" DIRECTORY)
    if(_odir)
        file(MAKE_DIRECTORY "${ROOT}/${_odir}")
    endif()

    if(EXISTS "${ROOT}/${_obj}" AND EXISTS "${ROOT}/${_src}")
        file(TIMESTAMP "${ROOT}/${_obj}" _ot)
        file(TIMESTAMP "${ROOT}/${_src}" _st)
        if(_ot STRGREATER _st)
            continue()
        endif()
    endif()

    execute_process(
        COMMAND ${_cmd}
        WORKING_DIRECTORY "${ROOT}"
        RESULT_VARIABLE _rc
    )
    if(NOT _rc EQUAL 0)
        message(FATAL_ERROR "[godot-cmake] COMPILE FAILED (${_rc}) for ${_src}")
    endif()
endforeach()

# ---------------------------------------------------------------------------
# 5. Verify all objects were produced
# ---------------------------------------------------------------------------
message(STATUS "[godot-cmake] step 3/4: verifying objects")
set(_missing 0)
foreach(_obj IN LISTS _objects)
    if(NOT EXISTS "${ROOT}/${_obj}")
        message(SEND_ERROR "[godot-cmake] missing object: ${_obj}")
        math(EXPR _missing "${_missing} + 1")
    endif()
endforeach()
if(NOT _missing EQUAL 0)
    message(FATAL_ERROR "[godot-cmake] ${_missing} object file(s) missing; aborting before link")
endif()

# ---------------------------------------------------------------------------
# 6. Link (response file keeps the command line within limits)
# ---------------------------------------------------------------------------
message(STATUS "[godot-cmake] step 4/4: linking ${OUT}")
set(_rsp "${BUILD}/link.rsp")
file(WRITE "${_rsp}" "")
foreach(_obj IN LISTS _objects)
    file(APPEND "${_rsp}" "${ROOT}/${_obj}\n")
endforeach()

execute_process(
    COMMAND g++ -o "${OUT}" -pie -Wl,-z,relro -Wl,-z,now
            -static-libgcc -static-libstdc++ -O0
            "@${_rsp}" -lrt -lpthread -ldl
    WORKING_DIRECTORY "${ROOT}"
    RESULT_VARIABLE _rc
)
if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "[godot-cmake] LINK FAILED (${_rc})")
endif()

if(NOT EXISTS "${OUT}")
    message(FATAL_ERROR "[godot-cmake] link reported success but ${OUT} does not exist")
endif()

message(STATUS "[godot-cmake] built ${OUT}")
