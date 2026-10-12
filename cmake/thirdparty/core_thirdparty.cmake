# Core thirdparty sources (mirrors core/SCsub).
# These are compiled into the core library with warnings disabled, matching
# SCons's env_thirdparty.

# Misc thirdparty (header paths hardcoded in Godot; no extra include needed).
set(_misc_sources
    thirdparty/misc/fastlz.c
    thirdparty/misc/r128.c
    thirdparty/misc/smaz.c
    thirdparty/misc/pcg.cpp
    thirdparty/misc/polypartition.cpp
    thirdparty/misc/smolv.cpp
)

# Brotli
set(_brotli_sources "")
if(GODOT_BROTLI AND GODOT_BUILTIN_BROTLI)
    set(_brotli_sources
        thirdparty/brotli/common/constants.c
        thirdparty/brotli/common/context.c
        thirdparty/brotli/common/dictionary.c
        thirdparty/brotli/common/platform.c
        thirdparty/brotli/common/shared_dictionary.c
        thirdparty/brotli/common/transform.c
        thirdparty/brotli/dec/bit_reader.c
        thirdparty/brotli/dec/decode.c
        thirdparty/brotli/dec/huffman.c
        thirdparty/brotli/dec/prefix.c
        thirdparty/brotli/dec/state.c
        thirdparty/brotli/dec/static_init.c
    )
endif()

# Clipper2
set(_clipper2_sources "")
if(GODOT_BUILTIN_CLIPPER2)
    set(_clipper2_sources
        thirdparty/clipper2/src/clipper.engine.cpp
        thirdparty/clipper2/src/clipper.offset.cpp
        thirdparty/clipper2/src/clipper.rectclip.cpp
    )
endif()

# zlib
set(_zlib_sources "")
if(GODOT_BUILTIN_ZLIB)
    set(_zlib_sources
        thirdparty/zlib/adler32.c
        thirdparty/zlib/compress.c
        thirdparty/zlib/crc32.c
        thirdparty/zlib/deflate.c
        thirdparty/zlib/inffast.c
        thirdparty/zlib/inflate.c
        thirdparty/zlib/inftrees.c
        thirdparty/zlib/trees.c
        thirdparty/zlib/uncompr.c
        thirdparty/zlib/zutil.c
    )
endif()

# minizip (always built from source; Godot-modified)
set(_minizip_sources
    thirdparty/minizip/ioapi.c
    thirdparty/minizip/unzip.c
    thirdparty/minizip/zip.c
)

# zstd
set(_zstd_sources "")
if(GODOT_BUILTIN_ZSTD)
    set(_zstd_sources
        thirdparty/zstd/common/debug.c
        thirdparty/zstd/common/entropy_common.c
        thirdparty/zstd/common/error_private.c
        thirdparty/zstd/common/fse_decompress.c
        thirdparty/zstd/common/pool.c
        thirdparty/zstd/common/threading.c
        thirdparty/zstd/common/xxhash.c
        thirdparty/zstd/common/zstd_common.c
        thirdparty/zstd/compress/fse_compress.c
        thirdparty/zstd/compress/hist.c
        thirdparty/zstd/compress/huf_compress.c
        thirdparty/zstd/compress/zstd_compress.c
        thirdparty/zstd/compress/zstd_double_fast.c
        thirdparty/zstd/compress/zstd_fast.c
        thirdparty/zstd/compress/zstd_lazy.c
        thirdparty/zstd/compress/zstd_ldm.c
        thirdparty/zstd/compress/zstd_opt.c
        thirdparty/zstd/compress/zstd_preSplit.c
        thirdparty/zstd/compress/zstdmt_compress.c
        thirdparty/zstd/compress/zstd_compress_literals.c
        thirdparty/zstd/compress/zstd_compress_sequences.c
        thirdparty/zstd/compress/zstd_compress_superblock.c
        thirdparty/zstd/decompress/huf_decompress.c
        thirdparty/zstd/decompress/zstd_ddict.c
        thirdparty/zstd/decompress/zstd_decompress_block.c
        thirdparty/zstd/decompress/zstd_decompress.c
    )
    # x86_64 uses the AMD64 assembly decompressor (matches SCU platforms list).
    if(GODOT_ARCH STREQUAL "x86_64" AND NOT MSVC)
        list(APPEND _zstd_sources thirdparty/zstd/decompress/huf_decompress_amd64.S)
    endif()
endif()

set(GODOT_CORE_THIRDPARTY_SOURCES
    ${_misc_sources}
    ${_brotli_sources}
    ${_clipper2_sources}
    ${_zlib_sources}
    ${_minizip_sources}
    ${_zstd_sources}
)

# Absolute source paths.
set(_abs "")
foreach(f IN LISTS GODOT_CORE_THIRDPARTY_SOURCES)
    list(APPEND _abs "${CMAKE_SOURCE_DIR}/${f}")
endforeach()
set(GODOT_CORE_THIRDPARTY_SOURCES ${_abs})