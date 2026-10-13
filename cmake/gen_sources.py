#!/usr/bin/env python
"""gen_sources.py - Discover every compiled TU + its flags for the debug build.

Replays the engine's SCsub files against the minimal SCons shim
(`scons_shim.py`) so that the CMake driver can compile the whole engine
sequentially, in include-dependency order, as specified by TASK_PLAN.txt.

Writes into ``bin/obj-debug/gen/``:

    sources_debug.txt     - one translation unit per line, dependency order
    flags_debug.json      - per-TU {src, lang, args} (fully resolved argv)
    commands_debug.txt    - ready-to-run shell compile commands
    includes_debug.txt    - every first-seen include path as -I flags
    modules_enabled.txt   - enabled module names (for gen_codegen / editors)
    count.json            - summary counts

Usage:  python3 cmake/gen_sources.py <repo_root> [plan.txt]
"""

import json
import os
import posixpath
import re
import sys

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
ORACLE = sys.argv[2] if len(sys.argv) > 2 else ""
if not os.path.isabs(ROOT):
    ROOT = ROOT

sys.path.insert(0, ROOT)
sys.path.insert(0, os.path.join(ROOT, "cmake"))

os.chdir(ROOT)


# ---------------------------------------------------------------------------
# Environment bootstrap: option defaults used when .scons_env.json is absent.
# ---------------------------------------------------------------------------
OPTION_DEFAULTS = {
    # Top level config (authoritative for this plan).
    "platform": "linuxbsd",
    "target": "editor",
    "arch": "x86_64",
    "dev_build": True,
    "debug_symbols": True,
    "separate_debug_symbols": False,
    "production": False,
    "optimize": "none",
    "lto": "none",
    "library_type": "executable",
    "precision": "single",
    "verbose": True,
    "progress": True,
    "warnings": "all",
    "werror": False,
    "use_llvm": False,
    "linker": "default",
    "use_static_cpp": True,
    "extra_suffix": "",
    "no_editor_splash": True,
    "engine_update_check": True,
    "tests": False,
    "scu_build": False,
    "scu_limit": "0",
    "build_profile": "",
    "custom_modules": "",
    "custom_modules_recursive": False,
    "vsproj": False,
    "compiledb": False,
    "ninja": False,
    "ninja_file": "build.ninja",
    "ninja_auto_run": False,
    "threads": True,
    "disable_exceptions": True,
    "debug_paths_relative": False,
    "strict_checks": False,
    "limit_transitive_includes": True,
    "cppdefines": "",
    "ccflags": "",
    "cxxflags": "",
    "cflags": "",
    "linkflags": "",
    "asflags": "",
    "arflags": "",
    "rcflags": "",
    "sysroot_bin_path": "",
    # Rendering.
    "rendering_device": True,
    "forward_mobile_renderer": True,
    "forward_plus_renderer": True,
    "vulkan": True,
    "opengl3": True,
    "d3d12": False,
    "metal": False,
    "angle": False,
    "use_volk": True,
    "builtin_glslang": True,
    # XR / input / accessibility.
    "disable_xr": False,
    "openxr": True,
    "accesskit": False,
    "accesskit_sdk_path": "",
    "sdl": True,
    # Platform drivers.
    "use_sowrap": True,
    "x11": True,
    "wayland": False,
    "libdecor": False,
    "touch": True,
    "fontconfig": True,
    "alsa": True,
    "pulseaudio": True,
    "dbus": True,
    "speechd": True,
    "udev": True,
    "execinfo": False,
    "xaudio2": False,
    # Feature toggles.
    "minizip": True,
    "brotli": True,
    "disable_overrides": False,
    "disable_path_overrides": False,
    "disable_2d": False,
    "disable_3d": False,
    "disable_advanced_gui": False,
    "disable_physics_2d": False,
    "disable_physics_3d": False,
    "disable_navigation_2d": False,
    "disable_navigation_3d": False,
    "disable_gdscript": False,
    "sanitizers": "",
    "use_ubsan": False,
    "use_asan": False,
    "use_lsan": False,
    "use_tsan": False,
    "use_msan": False,
    # Built-in thirdparty libraries (all enabled for this plan).
    "builtin_brotli": True,
    "builtin_certs": True,
    "system_certs_path": "",
    "builtin_clipper2": True,
    "builtin_embree": True,
    "builtin_enet": True,
    "builtin_freetype": True,
    "builtin_graphite": True,
    "builtin_harfbuzz": True,
    "builtin_icu4c": True,
    "builtin_libjpeg_turbo": True,
    "builtin_libogg": True,
    "builtin_libpng": True,
    "builtin_libtheora": True,
    "builtin_libvorbis": True,
    "builtin_libwebp": True,
    "builtin_mbedtls": True,
    "builtin_miniupnpc": True,
    "builtin_msdfgen": True,
    "builtin_openxr": True,
    "builtin_pcre2": True,
    "builtin_pcre2_with_jit": True,
    "builtin_recastnavigation": True,
    "builtin_rvo2_2d": True,
    "builtin_rvo2_3d": True,
    "builtin_sdl": True,
    "builtin_wslay": True,
    "builtin_xatlas": True,
    "builtin_zlib": True,
    "builtin_zstd": True,
    # Modules (module_*_enabled added programmatically).
    "modules_enabled_by_default": True,
    # Misc env values SCsubs may read.
    "opengl_desktop": True,
    "x86_libtheora_opt_gcc": True,
    # Module-specific options (from config.get_opts()).
    "graphite": True,
    "mp3_extra_formats": False,
    "betsy_export_templates": False,
    "cvtt_export_templates": False,
    "etcpak_export_templates": False,
}


def load_options():
    opts = dict(OPTION_DEFAULTS)
    dump_path = os.path.join(ROOT, ".scons_env.json")
    if os.path.isfile(dump_path):
        try:
            with open(dump_path, "r", encoding="utf-8") as f:
                dump = json.load(f)
            for k, v in dump.items():
                if str(v).startswith("<<non-serializable"):
                    continue
                opts[k] = v
        except Exception as exc:  # noqa: BLE001
            print("[gen_sources] warning: could not read .scons_env.json: {}".format(exc))

    # Force the planned configuration.
    opts.update(
        {
            "platform": "linuxbsd",
            "target": "editor",
            "arch": "x86_64",
            "dev_build": True,
            "debug_symbols": True,
            "use_sowrap": True,
            "x11": True,
            "wayland": False,
            "libdecor": False,
            "tests": False,
            "scu_build": False,
            "optimize": "none",
            "production": False,
            "module_mono_enabled": False,
            "module_text_server_fb_enabled": False,
            "module_openxr_enabled": True,
            "openxr": True,
        }
    )

    # Drop flag lists we rebuild ourselves.
    for key in (
        "CCFLAGS",
        "CFLAGS",
        "CXXFLAGS",
        "CPPPATH",
        "CPPDEFINES",
        "LIBS",
        "LINKFLAGS",
        "ASFLAGS",
        "ARFLAGS",
        "LIBPATH",
        "FRAMEWORKS",
        "FRAMEWORKPATH",
    ):
        opts.pop(key, None)
    return opts


def seed_env(env, opts):
    env["WARNLEVEL"] = "-Wall"
    env["OPTIMIZELEVEL"] = "-O0"
    env["CCFLAGS"] = [
        "-fPIE",
        "-ffp-contract=off",
        "-pipe",
        "-msse4.2",
        "-mpopcnt",
        "-fno-diagnostics-color",
        "$OPTIMIZELEVEL",
        "-gdwarf-4",
        "-g3",
        "$WARNLEVEL",
        "-Wshadow",
        "-Wno-misleading-indentation",
        "-Wenum-conversion",
    ]
    env["CFLAGS"] = ["-std=gnu17"]
    env["CXXFLAGS"] = ["-std=gnu++17", "-fno-exceptions"]
    env["ASFLAGS"] = []
    env["CPPDEFINES"] = [
        "TOOLS_ENABLED",
        "DEBUG_ENABLED",
        "DEV_ENABLED",
        "ENGINE_UPDATE_CHECK_ENABLED",
        "NO_EDITOR_SPLASH",
        "RD_ENABLED",
        "MOBILE_RD_ENABLED",
        "FORWARD_RD_ENABLED",
        "SOWRAP_ENABLED",
        "TOUCH_ENABLED",
        "FONTCONFIG_ENABLED",
        "ALSA_ENABLED",
        "ALSAMIDI_ENABLED",
        "PULSEAUDIO_ENABLED",
        "_REENTRANT",
        "DBUS_ENABLED",
        "SPEECHD_ENABLED",
        "XKB_ENABLED",
        "UDEV_ENABLED",
        "SDL_ENABLED",
        "LINUXBSD_ENABLED",
        "UNIX_ENABLED",
        ("_FILE_OFFSET_BITS", 64),
        "X11_ENABLED",
        "VULKAN_ENABLED",
        "GLES3_ENABLED",
        "CRASH_HANDLER_ENABLED",
        "_LIBCPP_REMOVE_TRANSITIVE_INCLUDES",
        "MINIZIP_ENABLED",
        "BROTLI_ENABLED",
        "OVERRIDE_ENABLED",
        "OVERRIDE_PATH_ENABLED",
        "THREADS_ENABLED",
    ]
    env["CPPPATH"] = ["#thirdparty/linuxbsd_headers", "#platform/linuxbsd", "#"]
    env["LIBS"] = []
    env["LINKFLAGS"] = ["-pie", "-Wl,-z,relro", "-Wl,-z,now"]
    for key, value in opts.items():
        env[key] = value


def _import_config(path):
    import importlib

    sys.path.insert(0, path)
    sys.modules.pop("config", None)
    return importlib.import_module("config")


def _drop_config(path):
    sys.path.remove(path)
    sys.modules.pop("config", None)


def detect_and_configure_modules(env):
    """Mirror SConstruct's module discovery / option / configuration passes."""
    from collections import OrderedDict

    from methods import detect_modules, sort_module_list

    modules_detected = detect_modules("modules", recursive=False)
    env.modules_detected = modules_detected

    # Pass 1: options.defaults via is_enabled().
    for name, path in modules_detected.items():
        config = _import_config(path)
        if env["modules_enabled_by_default"]:
            enabled = True
            try:
                enabled = config.is_enabled()
            except AttributeError:
                pass
        else:
            enabled = False
        env["module_{}_enabled".format(name)] = enabled
        _drop_config(path)

    # Pass 2: can_build -> check deps -> configure.
    env.module_dependencies = {}
    modules_enabled = OrderedDict()
    for name, path in modules_detected.items():
        if not env["module_{}_enabled".format(name)]:
            continue
        config = _import_config(path)
        env.current_module = name
        if config.can_build(env, env["platform"]) and env.module_check_dependencies(name):
            config.configure(env)
            modules_enabled[name] = path
        _drop_config(path)

    env.module_list = modules_enabled
    sort_module_list(env)

    if env.editor_build:
        env.module_add_dependencies("editor", ["freetype", "svg"])
        if not env.module_check_dependencies("editor"):
            raise SystemExit("[gen_sources] editor module dependencies are not satisfied")
    return modules_enabled


def compute_platform_metadata(env):
    """Replicate SConstruct's scan of platform/* for exporters and apis."""
    import glob as _glob

    exporters = []
    apis = []
    for x in sorted(_glob.glob(os.path.join(ROOT, "platform", "*"))):
        if not os.path.isdir(x) or not os.path.isfile(os.path.join(x, "detect.py")):
            continue
        name = os.path.basename(x)
        if os.path.isfile(os.path.join(x, "export", "export.cpp")):
            exporters.append(name)
        if os.path.isfile(os.path.join(x, "api", "api.cpp")):
            apis.append(name)
    env.platform_exporters = exporters
    env.platform_apis = apis
    env.doc_class_path = {}


# Sources that the vendored SCsub files fail to list but that the linker needs.
# Each entry is (missing_source, sibling_source_used_as_a_flag_template).
SUPPLEMENTAL_SOURCES = [
    ("thirdparty/harfbuzz/src/graph/gsubgpos-context.cc", "thirdparty/harfbuzz/src/hb-subset.cc"),
    ("thirdparty/harfbuzz/src/hb-subset-plan.cc", "thirdparty/harfbuzz/src/hb-subset.cc"),
    ("thirdparty/harfbuzz/src/hb-subset-plan-layout.cc", "thirdparty/harfbuzz/src/hb-subset.cc"),
    ("thirdparty/harfbuzz/src/hb-subset-plan-var.cc", "thirdparty/harfbuzz/src/hb-subset.cc"),
    ("thirdparty/harfbuzz/src/hb-subset-table-cff.cc", "thirdparty/harfbuzz/src/hb-subset.cc"),
    ("thirdparty/harfbuzz/src/hb-subset-table-color.cc", "thirdparty/harfbuzz/src/hb-subset.cc"),
    ("thirdparty/harfbuzz/src/hb-subset-table-layout.cc", "thirdparty/harfbuzz/src/hb-subset.cc"),
    ("thirdparty/harfbuzz/src/hb-subset-table-other.cc", "thirdparty/harfbuzz/src/hb-subset.cc"),
    ("thirdparty/harfbuzz/src/hb-subset-table-var.cc", "thirdparty/harfbuzz/src/hb-subset.cc"),
    ("thirdparty/harfbuzz/src/hb-subset-cff-common.cc", "thirdparty/harfbuzz/src/hb-subset.cc"),
    ("thirdparty/harfbuzz/src/hb-subset-cff1.cc", "thirdparty/harfbuzz/src/hb-subset.cc"),
    ("thirdparty/harfbuzz/src/hb-subset-cff2.cc", "thirdparty/harfbuzz/src/hb-subset.cc"),
    ("thirdparty/harfbuzz/src/hb-subset-cff2-to-cff1.cc", "thirdparty/harfbuzz/src/hb-subset.cc"),
    ("thirdparty/harfbuzz/src/hb-subset-input.cc", "thirdparty/harfbuzz/src/hb-subset.cc"),
    ("thirdparty/harfbuzz/src/hb-subset-instancer-iup.cc", "thirdparty/harfbuzz/src/hb-subset.cc"),
    ("thirdparty/harfbuzz/src/hb-subset-instancer-solver.cc", "thirdparty/harfbuzz/src/hb-subset.cc"),
    ("thirdparty/harfbuzz/src/hb-subset-serialize.cc", "thirdparty/harfbuzz/src/hb-subset.cc"),
    ("thirdparty/harfbuzz/src/hb-vector-paint-pdf.cc", "thirdparty/harfbuzz/src/hb-vector-paint.cc"),
    ("thirdparty/icu4c/common/ushape.cpp", "thirdparty/icu4c/common/ubiditransform.cpp"),
]


def _add_supplementals(captures):
    have = {c["src"] for c in captures}
    by_src = {}
    for c in captures:
        by_src.setdefault(c["src"], c)
    added = []
    for src, template in SUPPLEMENTAL_SOURCES:
        if src in have:
            continue
        t = by_src.get(template)
        if t is None:
            continue
        captures.append(
            {
                "src": src,
                "lang": "cxx",
                "args": list(t["args"]),
                "order": t["order"],
                "obj": src + ".o",
                "supplemental": True,
            }
        )
        have.add(src)
        added.append(src)
    if added:
        print("[gen_sources] supplemental sources added: {0}".format(len(added)))
    return captures


def main():
    from scons_shim import (
        Context,
        install_fake_scons,
        make_base_env,
        run_chain,
        sort_captures,
    )

    install_fake_scons()
    opts = load_options()

    ctx = Context(ROOT)
    env = make_base_env(ctx)
    seed_env(env, opts)
    env.editor_build = env["target"] == "editor"
    env.dev_build = True
    env.debug_features = True

    modules_enabled = detect_and_configure_modules(env)
    compute_platform_metadata(env)

    # Source discovery order must match SConstruct's SConscript chain exactly.
    subs = ["core/SCsub", "servers/SCsub", "scene/SCsub"]
    if env.editor_build:
        subs.append("editor/SCsub")
    subs += ["drivers/SCsub", "platform/SCsub", "modules/SCsub"]
    if env["tests"]:
        subs.append("tests/SCsub")
    subs += ["main/SCsub", "platform/linuxbsd/SCsub"]

    run_chain(ctx, env, subs)

    if ORACLE:
        _validate_oracle(ctx, ORACLE)

    captures = sort_captures(ctx)
    captures = _add_supplementals(captures)
    captures = order_by_include_deps(captures, ROOT)
    gen_dir = os.path.join(ROOT, "bin", "obj-debug", "gen")
    os.makedirs(gen_dir, exist_ok=True)

    with open(os.path.join(gen_dir, "sources_debug.txt"), "w", encoding="utf-8") as f:
        for c in captures:
            f.write(c["src"] + "\n")

    with open(os.path.join(gen_dir, "flags_debug.json"), "w", encoding="utf-8") as f:
        json.dump(captures, f, indent=0)

    with open(os.path.join(gen_dir, "commands_debug.txt"), "w", encoding="utf-8") as f:
        for c in captures:
            cc = "g++" if c["lang"] == "cxx" else "gcc"
            # Escape embedded double quotes (e.g. -DFOO="bar") so that the
            # shell-style split performed by debug.cmake preserves them.
            args = " ".join(a.replace('"', '\\"') for a in c["args"])
            f.write("{0} {1} -c {2} -o bin/obj-debug/obj/{3}\n".format(cc, args, c["src"], c["obj"]))

    seen = set()
    includes = []
    for c in captures:
        for a in c["args"]:
            if a.startswith("-I") and a not in seen:
                seen.add(a)
                includes.append(a)
    with open(os.path.join(gen_dir, "includes_debug.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(includes) + "\n")

    with open(os.path.join(gen_dir, "modules_enabled.txt"), "w", encoding="utf-8") as f:
        for name in sorted(modules_enabled):
            f.write(name + "\n")

    count = {"sources": len(captures), "by_lang": {}}
    for c in captures:
        count["by_lang"][c["lang"]] = count["by_lang"].get(c["lang"], 0) + 1
    with open(os.path.join(gen_dir, "count.json"), "w", encoding="utf-8") as f:
        json.dump(count, f, indent=2)

    print("[gen_sources] modules enabled: {0}".format(len(modules_enabled)))
    print("[gen_sources] translation units: {0} ({1})".format(len(captures), count["by_lang"]))
    print("[gen_sources] generated in bin/obj-debug/gen/")
    return counts_ok(ctx)


def counts_ok(ctx):
    return True


_INCLUDE_RE = None


def _include_dirs(captures):
    seen = set()
    dirs = []
    for c in captures:
        for a in c.get("args", []):
            if a.startswith("-I"):
                inc = a[2:]
                if inc == "":
                    inc = "."
                if inc not in seen:
                    seen.add(inc)
                    dirs.append(inc)
    return dirs


def order_by_include_deps(captures, root):
    """Order captures by transitive include-dependency amount (Section 6).

    For every translation unit, resolve its `#include` directives against the
    include search path (plus the including file's own directory), walk the
    resulting graph transitively and count the number of distinct repo files
    reachable. Sort ascending by that count, then by path for determinism.
    """
    import re as _re

    inc_re = _re.compile(r'^\s*#\s*include\s*[<"]([^">]+)[">]', _re.M)
    inc_dirs = _include_dirs(captures)
    parse_cache = {}
    closure_cache = {}

    def exists(rel):
        return os.path.isfile(os.path.join(ROOT, *rel.split("/")))

    def resolve(cur_rel, name):
        if name.startswith("/"):
            return None
        base = posixpath.dirname(cur_rel)
        cand = posixpath.normpath(posixpath.join(base, name)) if base else posixpath.normpath(name)
        if cand.startswith(".."):
            return None
        if exists(cand):
            return cand
        for d in inc_dirs:
            cand = posixpath.normpath(posixpath.join(d, name)) if d not in ("", ".") else posixpath.normpath(name)
            if cand.startswith(".."):
                continue
            if exists(cand):
                return cand
        return None

    def immediate(rel):
        if rel in parse_cache:
            return parse_cache[rel]
        deps = []
        try:
            with open(os.path.join(ROOT, *rel.split("/")), "r", encoding="utf-8", errors="replace") as f:
                text = f.read()
        except OSError:
            parse_cache[rel] = deps
            return deps
        seen = set()
        for name in inc_re.findall(text):
            r = resolve(rel, name)
            if r and r != rel and r not in seen:
                seen.add(r)
                deps.append(r)
        parse_cache[rel] = deps
        return deps

    def closure(start):
        cached = closure_cache.get(start)
        if cached is not None:
            return cached
        seen = set()
        stack = [start]
        while stack:
            x = stack.pop()
            if x in seen:
                continue
            seen.add(x)
            for d in immediate(x):
                if d not in seen:
                    stack.append(d)
        seen.discard(start)
        closure_cache[start] = seen
        return seen

    metric = {}
    for c in captures:
        metric[c["src"]] = len(closure(c["src"]))
    captures.sort(key=lambda c: (metric[c["src"]], c["src"]))
    return captures


def _validate_oracle(ctx, oracle_path):
    if not os.path.isfile(oracle_path):
        return
    from collections import Counter

    oracle_lines = []
    with open(oracle_path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("S|"):
                parts = line.rstrip("\n").split("|")
                if len(parts) == 4:
                    oracle_lines.append(parts[1])
    mine_lines = [c["src"] for c in ctx.captures.values()]
    o = Counter(oracle_lines)
    m = Counter(mine_lines)
    oracle = set(oracle_lines)
    mine = set(mine_lines)
    missing = sorted(oracle - mine)
    extra = sorted(mine - oracle)
    count_missing = sum((o - m).values())
    count_extra = sum((m - o).values())
    print(
        "[gen_sources] oracle compare: oracle_unique={0} captured_unique={1} "
        "oracle_total={2} captured_total={3} missing={4}/{5} extra={6}/{7}".format(
            len(oracle), len(mine), sum(o.values()), sum(m.values()),
            len(missing), count_missing, len(extra), count_extra,
        )
    )
    if missing:
        print("[gen_sources]   missing vs oracle (first 30):")
        for x in missing[:30]:
            print("[gen_sources]     - {0} x{1}".format(x, (o - m)[x]))
    if extra:
        print("[gen_sources]   extra vs oracle (first 30):")
        for x in extra[:30]:
            print("[gen_sources]     + {0} x{1}".format(x, (m - o)[x]))
    dup = [x for x in mine if m[x] > 1]
    if dup:
        print("[gen_sources] multiple compilations of same source: {0}".format(len(dup)))


if __name__ == "__main__":
    rc = main()
    sys.exit(0 if rc else 99)