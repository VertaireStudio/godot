# core library (mirrors core/SCsub + core/*/SCsub).

# All engine .cpp under core/ (each dir with .cpp has an SCsub in SCons).
file(GLOB_RECURSE _core_sources CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/core/*.cpp")
# Generated .gen.cpp produced by Phase 1 (version_hash, encryption key, mappings).
set(_core_gen_sources
    "${CMAKE_SOURCE_DIR}/core/version_hash.gen.cpp"
    "${CMAKE_SOURCE_DIR}/core/script_encryption_key.gen.cpp"
    "${CMAKE_SOURCE_DIR}/core/input/default_controller_mappings.gen.cpp"
)

# Generated headers that core translation units include (so they build first).
set(_core_gen_headers
    "${CMAKE_SOURCE_DIR}/core/version_generated.gen.h"
    "${CMAKE_SOURCE_DIR}/core/disabled_classes.gen.h"
    "${CMAKE_SOURCE_DIR}/core/io/certs_compressed.gen.h"
    "${CMAKE_SOURCE_DIR}/core/authors.gen.h"
    "${CMAKE_SOURCE_DIR}/core/donors.gen.h"
    "${CMAKE_SOURCE_DIR}/core/license.gen.h"
    "${CMAKE_SOURCE_DIR}/core/profiling/profiling.gen.h"
    "${CMAKE_SOURCE_DIR}/core/object/gdvirtual.gen.h"
    "${CMAKE_SOURCE_DIR}/core/extension/ext_wrappers.gen.h"
    "${CMAKE_SOURCE_DIR}/core/extension/gdextension_interface_dump.gen.h"
    "${CMAKE_SOURCE_DIR}/core/extension/gdextension_interface.gen.h"
    # core/config includes the module-enabled header, so make core depend on it.
    "${CMAKE_SOURCE_DIR}/modules/modules_enabled.gen.h"
)

add_library(godot_core STATIC
    ${_core_sources}
    ${_core_gen_sources}
    ${_core_gen_headers}
    ${GODOT_CORE_THIRDPARTY_SOURCES}
)
add_library(godot::core ALIAS godot_core)

target_link_libraries(godot_core
    PRIVATE godot_options godot_thirdparty_options
)

# Thirdparty include dirs (core/SCsub + core/crypto/SCsub).
target_include_directories(godot_core PUBLIC
    "${CMAKE_SOURCE_DIR}/thirdparty/brotli/include"
    "${CMAKE_SOURCE_DIR}/thirdparty/clipper2/include"
    "${CMAKE_SOURCE_DIR}/thirdparty/zlib"
    "${CMAKE_SOURCE_DIR}/thirdparty/zstd"
    "${CMAKE_SOURCE_DIR}/thirdparty/zstd/common"
    "${CMAKE_SOURCE_DIR}/thirdparty/mbedtls/include"
)

# mbedTLS config for core/crypto when the mbedtls module is enabled.
if(GODOT_MODULE_MBEDTLS_ENABLED)
    target_compile_definitions(godot_core PRIVATE
        "MBEDTLS_CONFIG_FILE=\"thirdparty/mbedtls/include/godot_module_mbedtls_config.h\"")
endif()