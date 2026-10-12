# main library (mirrors main/SCsub).

file(GLOB _main_sources CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/main/*.cpp")

# main/steam_tracker.cpp is only meaningful with STEAMAPI_ENABLED; the SCons
# build compiles it always but the body is guarded, so keep parity by including
# it only for non-steamid builds is unnecessary — include it.
add_library(godot_main STATIC
    ${_main_sources}
)
add_library(godot::main ALIAS godot_main)
target_link_libraries(godot_main PRIVATE godot_options)
target_link_libraries(godot_main PUBLIC godot_core godot_scene godot_servers godot_drivers)
add_dependencies(godot_main godot_generated)