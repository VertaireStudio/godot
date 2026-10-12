# servers library (mirrors servers/SCsub + servers/*/SCsub).
# Mostly recursive .cpp globs; the renderer_rd shaders are generated in Phase 1
# and included by the rendering server sources, so they're listed as sources
# here to establish the build dependency.

file(GLOB_RECURSE _servers_sources CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/servers/*.cpp")

# Thirdparty pulled in by servers (renderer_rd).
set(_servers_thirdparty
    "${CMAKE_SOURCE_DIR}/thirdparty/amd-fsr2/ffx_assert.cpp"
    "${CMAKE_SOURCE_DIR}/thirdparty/amd-fsr2/ffx_fsr2.cpp"
    "${CMAKE_SOURCE_DIR}/thirdparty/spirv-reflect/spirv_reflect.c"
)

# Generated header (LTC LUT) that servers sources include.
set(_servers_gen_headers
    "${CMAKE_SOURCE_DIR}/servers/rendering/storage/ltc_lut.gen.h"
)

# SMAA lookup textures (generated from bundled PNGs; renderer_rd/effects).
godot_codegen(smaa_area_tex smaa_area_tex
    OUTPUTS "${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/effects/smaa_area_tex.gen.h"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/thirdparty/smaa/AreaTex.png")
godot_codegen(smaa_search_tex smaa_search_tex
    OUTPUTS "${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/effects/smaa_search_tex.gen.h"
    PATH_INPUTS "${CMAKE_SOURCE_DIR}/thirdparty/smaa/SearchTex.png")
list(APPEND _servers_gen_headers
    "${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/effects/smaa_area_tex.gen.h"
    "${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/effects/smaa_search_tex.gen.h"
)
# RD shader headers included by renderer_rd sources. Because generated headers
# don't exist at configure time (glob would miss them), depend on the aggregate
# generator target so all shader headers are produced before compilation.
file(GLOB _rd_shader_headers
    "${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/shaders/*.glsl.gen.h"
    "${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/shaders/*/*.glsl.gen.h"
    "${CMAKE_SOURCE_DIR}/servers/rendering/renderer_rd/shaders/*/*/*.glsl.gen.h"
)

add_library(godot_servers STATIC
    ${_servers_sources}
    ${_servers_thirdparty}
    ${_servers_gen_headers}
    ${_rd_shader_headers}
)
add_library(godot::servers ALIAS godot_servers)

target_link_libraries(godot_servers PRIVATE godot_options godot_thirdparty_options)
target_link_libraries(godot_servers PUBLIC godot_core)
add_dependencies(godot_servers godot_generated)
target_include_directories(godot_servers PRIVATE
    "${CMAKE_SOURCE_DIR}/thirdparty/amd-fsr2"
    "${CMAKE_SOURCE_DIR}/thirdparty/spirv-reflect"
)
target_compile_definitions(godot_servers PRIVATE FFX_GCC)