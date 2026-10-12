# Modules (mirrors modules/SCsub).
#
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