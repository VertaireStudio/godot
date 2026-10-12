#!/usr/bin/env python3
"""CMake-driven code generator dispatcher for the Godot CMake port.

Reuses Godot's real SCons builder functions by providing a tiny SCons-compatible
shim (Node/Env), so generated files are byte-for-byte identical to a SCons build
while being driven by CMake `add_custom_command`.

Each generator is invoked as:

    python3 cmake/godot_codegen.py <generator> <json-args-file>

where `<json-args-file>` holds a JSON list of arguments describing the output
file(s) and source inputs. Inputs are either:

  {"kind": "path",   "value": "/abs/or/rel/path"}
  {"kind": "content","value": "literal string content"}   # SCons Value() node

Example args file for the version header:
    [{"kind":"path","value":"<builddir>/version_generated.gen.h"},
     {"kind":"content","value":"{\"short_name\":\"godot\", ...}"}]
"""

import importlib.util
import json
import os
import shutil
import sys

# Make the Godot source root importable so the builder modules resolve
# (methods, glsl_builders, etc. live at the repo root).
GODOT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, GODOT_ROOT)


def _load_module(dotted_name: str, rel_path: str):
    """Load a Godot builder module by file path under a stable module name."""
    full = os.path.join(GODOT_ROOT, rel_path)
    spec = importlib.util.spec_from_file_location(dotted_name, full)
    module = importlib.util.module_from_spec(spec)
    sys.modules[dotted_name] = module
    spec.loader.exec_module(module)
    return module


# Pre-load the shared helper modules under the names Godot's code expects, so
# that `import methods` inside builder modules resolves to our loaded instance.
methods = _load_module("methods", "methods.py")
version = _load_module("version", "version.py")


# --- Inline builders replicated from servers/rendering/renderer_rd/effects/SCsub
def _areatex_builder(target, source, env):
    buffer = methods.get_buffer(str(source[0]))
    with methods.generated_wrapper(str(target[0])) as file:
        file.write(f"""\
#define AREATEX_WIDTH 160
#define AREATEX_HEIGHT 560
#define AREATEX_PITCH (AREATEX_WIDTH * 2)
#define AREATEX_SIZE (AREATEX_HEIGHT * AREATEX_PITCH)

inline constexpr const unsigned char area_tex_png[] = {{
{methods.format_buffer(buffer, 1)}
}};
""")


def _searchtex_builder(target, source, env):
    buffer = methods.get_buffer(str(source[0]))
    with methods.generated_wrapper(str(target[0])) as file:
        file.write(f"""\
#define SEARCHTEX_WIDTH 64
#define SEARCHTEX_HEIGHT 16
#define SEARCHTEX_PITCH SEARCHTEX_WIDTH
#define SEARCHTEX_SIZE (SEARCHTEX_HEIGHT * SEARCHTEX_PITCH)

inline constexpr const unsigned char search_tex_png[] = {{
{methods.format_buffer(buffer, 1)}
}};
""")


class Node:
    """Minimal stand-in for an SCons File/Value node."""

    def __init__(self, spec: dict, base_dir: str):
        self.kind = spec.get("kind", "path")
        if self.kind == "path":
            raw = spec["value"]
            self.path = raw if os.path.isabs(raw) else os.path.normpath(os.path.join(base_dir, raw))
            self._value = None
        elif self.kind == "json":
            # A "Value" node whose read() returns a decoded JSON object (dict/list).
            self.path = ""
            self._value = spec.get("value")
        else:
            # A "Value" node whose read() returns a plain string.
            self.path = ""
            self._value = spec.get("value", "")
        self.base_dir = base_dir

    def read(self):
        if self.kind == "path":
            with open(self.path, "r", encoding="utf-8") as f:
                return f.read()
        return self._value

    # SCons nodes support str() and .abspath; provide both.
    @property
    def abspath(self) -> str:
        return self.path

    @property
    def name(self) -> str:
        return os.path.basename(self.path) if self.path else ""

    def __str__(self) -> str:
        return self.path

    def __fspath__(self) -> str:
        return self.path


class Env:
    """Minimal stand-in for a SCons Environment, exposing only what builders use."""

    def __init__(self, base_dir: str, args: dict):
        self.base_dir = base_dir
        self.args = args

    def NoCache(self, target):
        # CMake manages its own caching; nothing to do.
        return None

    def Detect(self, prog):
        return shutil.which(prog)

    def __getitem__(self, key):
        return self.args.get(key)


def _make_nodes(entries, base_dir):
    return [Node(spec, base_dir) for spec in entries]


# ---------------------------------------------------------------------------
# Config-dependent synthetic content nodes.
# These reproduce the SCons `env.Value(...)` inputs that the SConstruct/SCsub
# compute from build configuration, so CMake doesn't have to serialize them.
# Each returns a list of Node specs (i.e. the *content* inputs the builder
# expects as `source`, prepended before any real file inputs).
# ---------------------------------------------------------------------------
def _synthetic_inputs(gen_name, env_spec):
    # Returns (nodes, mode) where mode is "prepend" or "append".
    if gen_name == "make_certs_header":
        # builder reads source[0] (certs path) + source[1] builtin_certs +
        # source[2] system_certs_path, so these synthetic content nodes must
        # come AFTER the real path input.
        return (
            [
                {"kind": "content", "value": "1" if env_spec.get("builtin_certs") else ""},
                {"kind": "content", "value": env_spec.get("system_certs_path", "") or ""},
            ],
            "append",
        )
    if gen_name == "version_info":
        return ([{"kind": "json", "value": methods.get_version_info(env_spec.get("module_version_string", ""))}], "prepend")
    if gen_name == "version_hash":
        return ([{"kind": "json", "value": methods.get_git_info()}], "prepend")
    if gen_name == "encryption_key":
        key = env_spec.get("encryption_key", "")
        return ([{"kind": "content", "value": key or "0" * 64}], "prepend")
    if gen_name == "disabled_class":
        # Builder iterates the source node, so it must yield whole class names
        # (a list), not a concatenated string.
        return ([{"kind": "json", "value": list(env_spec.get("disabled_classes", []))}], "prepend")
    if gen_name == "doc_data_class_path":
        return ([{"kind": "json", "value": env_spec.get("doc_class_path", {})}], "prepend")
    if gen_name == "register_exporters":
        return ([{"kind": "json", "value": env_spec.get("platform_exporters", [])}], "prepend")
    if gen_name == "register_platform_apis":
        return ([{"kind": "json", "value": env_spec.get("platform_apis", [])}], "prepend")
    if gen_name == "modules_enabled":
        detected = env_spec.get("modules_detected", {})
        names = list(detected.keys()) if isinstance(detected, dict) else detected
        return ([{"kind": "json", "value": sorted(names)}], "prepend")
    if gen_name == "register_module_types":
        detected = env_spec.get("modules_detected", {})
        return (
            [
                {"kind": "json", "value": detected},
                {"kind": "json", "value": sorted(detected.keys()) if isinstance(detected, dict) else []},
            ],
            "prepend",
        )
    return ([], "prepend")


# ---------------------------------------------------------------------------
# Generator registry: name -> (loader_path, attr_name)
# ---------------------------------------------------------------------------
GENERATORS = {
    # --- core ---
    "disabled_class": ("core/core_builders.py", "disabled_class_builder"),
    "version_info": ("core/core_builders.py", "version_info_builder"),
    "version_hash": ("core/core_builders.py", "version_hash_builder"),
    "encryption_key": ("core/core_builders.py", "encryption_key_builder"),
    "make_certs_header": ("core/core_builders.py", "make_certs_header"),
    "make_authors_header": ("core/core_builders.py", "make_authors_header"),
    "make_donors_header": ("core/core_builders.py", "make_donors_header"),
    "make_license_header": ("core/core_builders.py", "make_license_header"),
    # --- core input / profiling ---
    "make_default_controller_mappings": ("core/input/input_builders.py", "make_default_controller_mappings"),
    "profiler_gen": ("core/profiling/profiling_builders.py", "profiler_gen_builder"),
    # --- core extension / object (these use `run()`) ---
    "make_wrappers": ("core/extension/make_wrappers.py", "run"),
    "make_virtuals": ("core/object/make_virtuals.py", "run"),
    "make_interface_header": ("core/extension/make_interface_header.py", "run"),
    "make_interface_dumper": ("core/extension/make_interface_dumper.py", "run"),
    "make_ltc_lut": ("servers/rendering/storage/make_ltc_lut.py", "run"),
    "make_templates": ("editor/template_builders.py", "make_templates"),
    "make_icu_data": ("modules/text_server_adv/text_server_adv_builders.py", "make_icu_data"),
    # Inline builders defined in renderer_rd/effects/SCsub (no separate module).
    "smaa_area_tex": (None, "_areatex_builder"),
    "smaa_search_tex": (None, "_searchtex_builder"),
    # --- shaders ---
    "rd_glsl": ("glsl_builders.py", "build_rd_headers"),
    "raw_glsl": ("glsl_builders.py", "build_raw_headers"),
    "gles3_glsl": ("gles3_builders.py", "build_gles3_headers"),
    # --- scene theme ---
    "scene_theme_fonts": ("scene/theme/default_theme_builders.py", "make_fonts_header"),
    "default_theme_icons": (
        "scene/theme/icons/default_theme_icons_builders.py",
        "make_default_theme_icons_action",
    ),
    # --- editor ---
    "doc_data_class_path": ("editor/editor_builders.py", "doc_data_class_path_builder"),
    "register_exporters": ("editor/editor_builders.py", "register_exporters_builder"),
    "make_doc_header": ("editor/editor_builders.py", "make_doc_header"),
    "make_translations": ("editor/editor_builders.py", "make_translations"),
    "editor_icons": ("editor/icons/editor_icons_builders.py", "make_editor_icons_action"),
    "editor_fonts": ("editor/themes/editor_theme_builders.py", "make_fonts_header"),
    # --- platform ---
    "export_icon": ("platform/platform_builders.py", "export_icon_builder"),
    "register_platform_apis": ("platform/platform_builders.py", "register_platform_apis_builder"),
    # --- modules ---
    "modules_enabled": ("modules/modules_builders.py", "modules_enabled_builder"),
    "register_module_types": ("modules/modules_builders.py", "register_module_types_builder"),
    "modules_tests": ("modules/modules_builders.py", "modules_tests_builder"),
    # --- main ---
    "make_splash": ("main/main_builders.py", "make_splash"),
    "make_splash_editor": ("main/main_builders.py", "make_splash_editor"),
    "make_app_icon": ("main/main_builders.py", "make_app_icon"),
}


def main(argv):
    if len(argv) != 3:
        print("usage: godot_codegen.py <generator> <args-json-file>", file=sys.stderr)
        return 2

    gen_name, args_file = argv[1], argv[2]

    if gen_name not in GENERATORS:
        print(f"error: unknown generator '{gen_name}'", file=sys.stderr)
        return 2

    rel_path, func_name = GENERATORS[gen_name]

    with open(args_file, "r", encoding="utf-8") as f:
        payload = json.load(f)

    env_spec = payload.get("env", {})
    base_dir = payload.get("base_dir", GODOT_ROOT)

    # Ensure the parent directories of generated outputs exist.
    outputs = payload["outputs"]
    for out in outputs:
        parent = os.path.dirname(out["value"])
        if parent and not os.path.isdir(parent):
            os.makedirs(parent, exist_ok=True)

    target = _make_nodes(outputs, base_dir)
    _synth, _mode = _synthetic_inputs(gen_name, env_spec)
    _file_inputs = _make_nodes(payload.get("inputs", []), base_dir)
    if _mode == "append":
        source = _file_inputs + _make_nodes(_synth, base_dir)
    else:
        source = _make_nodes(_synth, base_dir) + _file_inputs

    if rel_path is None:
        builder = globals()[func_name]
    else:
        module = _load_module("_gen_" + gen_name, rel_path)
        builder = getattr(module, func_name)

    env = Env(base_dir, env_spec)

    builder(target, source, env)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))