# Code generation rules for the Godot CMake port.
#
# Each rule drives one of Godot's real Python generators through
# cmake/godot_codegen.py (which shims the SCons builder API), so generated
# sources are identical to a SCons build. Generated files are written next to
# their SCons counterparts (into the source tree) so include paths match.

include_guard(GLOBAL)

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
# Each item is a full pre-serialized JSON object.
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
#   CONTENT_INPUTS <string>...      # value nodes whose .read() returns the string
#   JSON_INPUTS <json>...           # value nodes whose .read() returns decoded JSON
#   ENV <json-object>               # contents of the `env` mapping
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
        # Escape for JSON string context.
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

    # Register outputs in a global property so the aggregation target (created
    # in a different scope) can depend on every generator rule.
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

# disabled_classes.gen.h (empty class list by default).
godot_codegen(disabled_class disabled_classes
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/disabled_classes.gen.h"
    ENV "{\"disabled_classes\":[]}")
_cg_track("${CMAKE_SOURCE_DIR}/core/disabled_classes.gen.h")

# Certificates: builder reads ca-bundle.crt (path) + builtin_certs + system path
# (the latter two are synthesized by the driver from the `env` mapping).
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

# core/input: default controller mappings.
godot_codegen(make_default_controller_mappings default_controller_mappings
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/input/default_controller_mappings.gen.cpp"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/core/input/gamecontrollerdb.txt"
               "${CMAKE_SOURCE_DIR}/core/input/godotcontrollerdb.txt")
_cg_track("${CMAKE_SOURCE_DIR}/core/input/default_controller_mappings.gen.cpp")

# core/profiling: profiling.gen.h (no profiler configured by default).
godot_codegen(profiler_gen profiling
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/profiling/profiling.gen.h")
_cg_track("${CMAKE_SOURCE_DIR}/core/profiling/profiling.gen.h")

# core/object: gdvirtual.gen.h
godot_codegen(make_virtuals gdvirtual
    OUTPUTS "${CMAKE_SOURCE_DIR}/core/object/gdvirtual.gen.h"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/core/object/make_virtuals.py")
_cg_track("${CMAKE_SOURCE_DIR}/core/object/gdvirtual.gen.h")

# core/extension
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
# Mirrors the RD_GLSL rules: *_inc.glsl (+ parent) are includes; other .glsl are
# compiled to <shader>.gen.h. With HEADERS_FROM_INCLUDES (the top-level shaders
# dir only), the *_inc.glsl files are ALSO compiled to raw GLSL headers via
# GLSL_HEADER, matching servers/rendering/renderer_rd/shaders/SCsub.
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
# editor (editor-specific generated files needing module lists live in editor.cmake)
# =============================================================================
if(_godot_editor_build)
    # editor fonts
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

    # editor icons (engine svgs; module icons appended by editor.cmake if needed).
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
# platform export icons (SVG -> *_svg.gen.h) — needed by the editor's export
# plugins and by the platform backend, so generate them globally here.
# =============================================================================
set(GODOT_EXPORT_ICON_HEADERS "")
foreach(_p IN ITEMS android ios linuxbsd macos visionos web windows)
    file(GLOB _svgs "${CMAKE_SOURCE_DIR}/platform/${_p}/export/*.svg")
    foreach(_svg IN LISTS _svgs)
        get_filename_component(_base "${_svg}" NAME)
        # SCons names these <icon>_svg.gen.h (path.replace(".svg", "_svg.gen.h")).
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

# Extract the "modules" and "doc_class_path" sub-objects (tolerant of spacing).
string(REGEX MATCH "\"modules\":[ \t]*\\{[^}]*\\}" _mods_obj "${_modules_json_full}")
string(REGEX MATCH "\"doc_class_path\":[ \t]*\\{[^}]*\\}" _docpath_obj "${_modules_json_full}")
string(REGEX REPLACE "^\"modules\":[ \t]*" "" GODOT_MODULES_DETECTED "${_mods_obj}")
string(REGEX REPLACE "^\"doc_class_path\":[ \t]*" "" GODOT_DOC_CLASS_PATH "${_docpath_obj}")

# Expose per-module enabled flags as normal variables, e.g.
# GODOT_MODULE_MBEDTLS_ENABLED, GODOT_MODULE_GDSCRIPT_ENABLED, ...
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
# Generated .cpp files are compiled by their owning subsystem libraries, so this
# target only carries the generated headers (as sources) to establish the
# build-time dependency edges.
# =============================================================================
get_property(_all_codegen_outputs GLOBAL PROPERTY GODOT_CODEGEN_OUTPUTS)
add_custom_target(godot_generated DEPENDS ${_all_codegen_outputs})