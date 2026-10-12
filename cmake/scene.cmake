# scene library (mirrors scene/SCsub + scene/*/SCsub).

file(GLOB_RECURSE _scene_sources CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/scene/*.cpp")

# Thirdparty pulled in by scene (scene/resources/SCsub).
set(_scene_thirdparty
    "${CMAKE_SOURCE_DIR}/thirdparty/misc/mikktspace.c"
    "${CMAKE_SOURCE_DIR}/thirdparty/misc/qoa.c"
)

# Generated headers included by scene sources (theme font + icons).
set(_scene_gen_headers
    "${CMAKE_SOURCE_DIR}/scene/theme/default_font.gen.h"
    "${CMAKE_SOURCE_DIR}/scene/theme/default_theme_icons.gen.h"
)

add_library(godot_scene STATIC
    ${_scene_sources}
    ${_scene_thirdparty}
    ${_scene_gen_headers}
)
add_library(godot::scene ALIAS godot_scene)

target_link_libraries(godot_scene PRIVATE godot_options godot_thirdparty_options)
target_link_libraries(godot_scene PUBLIC godot_core)