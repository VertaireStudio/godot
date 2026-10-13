import glob
import importlib.util
import os
import subprocess
import sys

# ROOT defaults to the repository root (parent directory of this file's cmake/).
_THIS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(_THIS))
os.chdir(ROOT)
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

# The enabled-module list may be given either inline (comma separated) or as a
# path to the file written by gen_sources.py (bin/obj-debug/gen/modules_enabled.txt).
ENABLED_MODULES = []
if len(sys.argv) > 2 and sys.argv[2]:
    arg = sys.argv[2]
    if os.path.isfile(arg):
        with open(arg, "r", encoding="utf-8") as _f:
            ENABLED_MODULES = [ln.strip() for ln in _f if ln.strip()]
    else:
        ENABLED_MODULES = [m for m in arg.split(",") if m]


def _load(name, relpath):
    spec = importlib.util.spec_from_file_location(name, os.path.join(ROOT, relpath))
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


import methods

core_builders = _load("core_builders", "core/core_builders.py")
main_builders = _load("main_builders", "main/main_builders.py")
modules_builders = _load("modules_builders", "modules/modules_builders.py")
platform_builders = _load("platform_builders", "platform/platform_builders.py")
editor_builders = _load("editor_builders", "editor/editor_builders.py")
template_builders = _load("template_builders", "editor/template_builders.py")
glsl_builders = _load("glsl_builders", "glsl_builders.py")
gles3_builders = _load("gles3_builders", "gles3_builders.py")
default_theme_builders = _load("default_theme_builders", "scene/theme/default_theme_builders.py")
default_theme_icons_builders = _load(
    "default_theme_icons_builders", "scene/theme/icons/default_theme_icons_builders.py"
)
input_builders = _load("input_builders", "core/input/input_builders.py")
profiling_builders = _load("profiling_builders", "core/profiling/profiling_builders.py")
editor_icons_builders = _load("editor_icons_builders", "editor/icons/editor_icons_builders.py")
editor_theme_builders = _load("editor_theme_builders", "editor/themes/editor_theme_builders.py")
make_virtuals = _load("make_virtuals", "core/object/make_virtuals.py")
make_wrappers = _load("make_wrappers", "core/extension/make_wrappers.py")
make_interface_dumper = _load("make_interface_dumper", "core/extension/make_interface_dumper.py")
make_interface_header = _load("make_interface_header", "core/extension/make_interface_header.py")
make_ltc_lut = _load("make_ltc_lut", "servers/rendering/storage/make_ltc_lut.py")
text_server_adv_builders = _load("text_server_adv_builders", "modules/text_server_adv/text_server_adv_builders.py")


class File:
    """Stand-in for an SCons source File node."""

    def __init__(self, path):
        self.path = os.path.abspath(path)
        self.name = os.path.basename(self.path)

    def __str__(self):
        return self.path

    def __fspath__(self):
        return self.path

    @property
    def abspath(self):
        return self.path

    @property
    def srcnode(self):
        return self

    def get_abspath(self):
        return self.path

    def get_path(self):
        return self.path

    def read(self):
        with open(self.path, "r", encoding="utf-8", newline="\n") as f:
            return f.read()

    def get_text_contents(self):
        return self.read()

    def get_contents(self):
        with open(self.path, "rb") as f:
            return f.read()


class Value:
    """Stand-in for env.Value(...): the builders only call .read()."""

    def __init__(self, value):
        self.value = value

    def read(self):
        return self.value

    def __str__(self):
        return str(self.value)


class Target:
    """Stand-in for an SCons target node passed to builders."""

    def __init__(self, path):
        self.path = os.path.abspath(path)

    def __str__(self):
        return self.path


class Env(dict):
    """Minimal SCons Environment surrogate exposing the handful of members used."""

    def __getitem__(self, key):
        if key in self:
            return dict.__getitem__(self, key)
        return ""

    def Detect(self, name):
        import shutil

        return shutil.which(name)

    def NoCache(self, target):
        return target

    def Value(self, value):
        return Value(value)


def R(*parts):
    return os.path.join(ROOT, *parts)


def Targets(*rels):
    nodes = [Target(R(*rel.split("/"))) for rel in rels]
    for n in nodes:
        _STEP_TARGETS.append(n.path)
    return nodes


def Files(*rels):
    return [File(R(*rel.split("/"))) for rel in rels]


FAILED = []
_STEP_TARGETS = []


def step(label, fn):
    start = len(_STEP_TARGETS)
    try:
        fn()
        print("  [gen] ok   " + label)
        return
    except Exception as exc:  # noqa: BLE001 - report and verify below
        created = _STEP_TARGETS[start:]
        missing = [p for p in created if not os.path.isfile(p)]
        if created and not missing:
            print("  [gen] ok   " + label + " (outputs already present)")
            return
        FAILED.append(label)
        print("  [gen] FAIL " + label + ": " + repr(exc))
        for p in (missing or ["<unknown target>"]):
            print("        missing: " + p)


# ---------------------------------------------------------------------------
#  Module / platform discovery helpers
# ---------------------------------------------------------------------------
def enabled_module_names():
    if ENABLED_MODULES:
        return list(ENABLED_MODULES)
    names = []
    path = R("modules/modules_enabled.gen.h")
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("#define MODULE_") and line.endswith("_ENABLED"):
                    names.append(line[len("#define MODULE_") : -len("_ENABLED")].lower())
    return names


def platform_apis():
    out = []
    for name in sorted(os.listdir(R("platform"))):
        if os.path.isfile(R("platform", name, "api", "api.cpp")):
            out.append(name)
    return out


def platform_exporters():
    out = []
    for name in sorted(os.listdir(R("platform"))):
        if os.path.isfile(R("platform", name, "export", "export.cpp")):
            out.append(name)
    return out


def doc_class_path():
    paths = {}
    for xml in glob.glob(R("doc", "classes", "*.xml")):
        paths[os.path.splitext(os.path.basename(xml))[0]] = "doc/classes"
    for name in sorted(enabled_module_names()):
        for sub in sorted(glob.glob(R("modules", name, "**", "doc_classes"), recursive=True)):
            rel = os.path.relpath(sub, ROOT).replace("\\", "/")
            for xml in glob.glob(os.path.join(sub, "*.xml")):
                paths[os.path.splitext(os.path.basename(xml))[0]] = rel
    for sub in sorted(glob.glob(R("platform", "*", "doc_classes"))):
        rel = os.path.relpath(sub, ROOT).replace("\\", "/")
        for xml in glob.glob(os.path.join(sub, "*.xml")):
            paths[os.path.splitext(os.path.basename(xml))[0]] = rel
    return paths


def doc_sources():
    docs = sorted(glob.glob(R("doc", "classes", "*.xml")))
    for d in sorted(set(doc_class_path().values())):
        docs += sorted(glob.glob(os.path.join(ROOT, d, "*.xml")))
    return docs


# ---------------------------------------------------------------------------
#  Core
# ---------------------------------------------------------------------------
def s_version():
    info = methods.get_version_info("", silent=True)
    core_builders.version_info_builder(Targets("core/version_generated.gen.h"), [Value(info)], Env())


def s_version_hash():
    # NOTE: Reading the git history is forbidden for this task, so the hash is
    # intentionally left empty (the engine tolerates an empty/unknown hash).
    core_builders.version_hash_builder(
        Targets("core/version_hash.gen.cpp"), [Value({"git_hash": "", "git_timestamp": 0})], Env()
    )


def s_disabled_classes():
    core_builders.disabled_class_builder(Targets("core/disabled_classes.gen.h"), [Value([])], Env())


def s_encryption_key():
    core_builders.encryption_key_builder(
        Targets("core/script_encryption_key.gen.cpp"),
        [Value(os.environ.get("SCRIPT_AES256_ENCRYPTION_KEY", ""))],
        Env(),
    )


def s_certs():
    core_builders.make_certs_header(
        Targets("core/io/certs_compressed.gen.h"),
        [File(R("thirdparty", "certs", "ca-bundle.crt")), Value(True), Value("")],
        Env(),
    )


def s_authors():
    core_builders.make_authors_header(Targets("core/authors.gen.h"), Files("AUTHORS.md"), Env())


def s_donors():
    core_builders.make_donors_header(Targets("core/donors.gen.h"), Files("DONORS.md"), Env())


def s_license():
    core_builders.make_license_header(Targets("core/license.gen.h"), Files("COPYRIGHT.txt", "LICENSE.txt"), Env())


def s_gdvirtual():
    make_virtuals.run(Targets("core/object/gdvirtual.gen.h"), [], Env())


def s_ext_wrappers():
    make_wrappers.run(Targets("core/extension/ext_wrappers.gen.h"), Files("core/extension/make_wrappers.py"), Env())


def s_interface_dump():
    make_interface_dumper.run(
        Targets("core/extension/gdextension_interface_dump.gen.h"),
        Files("core/extension/gdextension_interface.json"),
        Env(),
    )


def s_interface_header():
    make_interface_header.run(
        Targets("core/extension/gdextension_interface.gen.h"),
        Files("core/extension/gdextension_interface.json"),
        Env(),
    )


def s_profiling():
    profiling_builders.profiler_gen_builder(Targets("core/profiling/profiling.gen.h"), [], Env({"profiler": ""}))


def s_controller_mappings():
    input_builders.make_default_controller_mappings(
        Targets("core/input/default_controller_mappings.gen.cpp"),
        Files("core/input/gamecontrollerdb.txt", "core/input/godotcontrollerdb.txt"),
        Env(),
    )


# ---------------------------------------------------------------------------
#  Main
# ---------------------------------------------------------------------------
def s_splash():
    main_builders.make_splash(Targets("main/splash.gen.h"), Files("main/splash.png"), Env())


def s_splash_editor():
    if os.path.exists(R("main", "splash_editor.png")):
        main_builders.make_splash_editor(Targets("main/splash_editor.gen.h"), Files("main/splash_editor.png"), Env())


def s_app_icon():
    main_builders.make_app_icon(Targets("main/app_icon.gen.h"), Files("main/app_icon.png"), Env())


# ---------------------------------------------------------------------------
#  Modules
# ---------------------------------------------------------------------------
def s_modules_enabled():
    modules_builders.modules_enabled_builder(
        Targets("modules/modules_enabled.gen.h"), [Value(enabled_module_names())], Env()
    )


def s_register_module_types():
    detected = methods.detect_modules("modules")
    modules_builders.register_module_types_builder(
        Targets("modules/register_module_types.gen.cpp"), [Value(detected)], Env()
    )


# ---------------------------------------------------------------------------
#  Platform
# ---------------------------------------------------------------------------
def s_platform_apis():
    platform_builders.register_platform_apis_builder(
        Targets("platform/register_platform_apis.gen.cpp"), [Value(platform_apis())], Env()
    )


def s_export_icons():
    for plat in platform_exporters():
        for svg in sorted(glob.glob(R("platform", plat, "export", "*.svg"))):
            platform_builders.export_icon_builder([Target(svg.replace(".svg", "_svg.gen.h"))], [File(svg)], Env())


# ---------------------------------------------------------------------------
#  Editor
# ---------------------------------------------------------------------------
def s_doc_class_path():
    editor_builders.doc_data_class_path_builder(
        Targets("editor/doc/doc_data_class_path.gen.h"), [Value(doc_class_path())], Env()
    )


def s_doc_data():
    editor_builders.make_doc_header(
        Targets("editor/doc/doc_data_compressed.gen.h"), [File(x) for x in doc_sources()], Env()
    )


def s_register_exporters():
    editor_builders.register_exporters_builder(
        Targets("editor/export/register_exporters.gen.cpp"), [Value(platform_exporters())], Env()
    )


def s_translations():
    groups = {
        "editor": "editor/translations/editor_translations.gen",
        "property": "editor/translations/property_translations.gen",
        "doc": "editor/translations/doc_translations.gen",
        "extractable": "editor/translations/extractable_translations.gen",
    }
    src_dirs = {
        "editor": "editor/translations/editor",
        "property": "editor/translations/properties",
        "doc": "doc/translations",
        "extractable": "editor/translations/extractable",
    }
    for category, tgt in groups.items():
        sources = [File(p) for p in sorted(glob.glob(os.path.join(ROOT, src_dirs[category], "*")))]
        if not sources:
            continue
        editor_builders.make_translations([Target(R(tgt + ".h")), Target(R(tgt + ".cpp"))], sources, Env())


def s_editor_icons():
    srcs = sorted(glob.glob(R("editor", "icons", "*.svg")))
    for name in sorted(enabled_module_names()):
        srcs += sorted(glob.glob(R("modules", name, "icons", "*.svg")))
    editor_icons_builders.make_editor_icons_action(
        Targets("editor/themes/editor_icons.gen.h"), [File(x) for x in srcs], Env()
    )


def s_editor_fonts():
    fonts = []
    for ext in ("ttf", "otf", "woff", "woff2"):
        fonts += glob.glob(R("thirdparty", "fonts", "*." + ext))
    editor_theme_builders.make_fonts_header(
        Targets("editor/themes/builtin_fonts.gen.h"), [File(x) for x in sorted(fonts)], Env()
    )


# ---------------------------------------------------------------------------
#  Scene
# ---------------------------------------------------------------------------
def s_theme_icons():
    srcs = sorted(glob.glob(R("scene", "theme", "icons", "*.svg")))
    srcs += sorted(glob.glob(R("scene", "theme", "icons", "debug_icons", "*.svg")))
    default_theme_icons_builders.make_default_theme_icons_action(
        Targets("scene/theme/default_theme_icons.gen.h"), [File(x) for x in srcs], Env()
    )


def s_theme_font():
    default_theme_builders.make_fonts_header(
        Targets("scene/theme/default_font.gen.h"), Files("thirdparty/fonts/OpenSans_SemiBold.woff2"), Env()
    )


# ---------------------------------------------------------------------------
#  Servers
# ---------------------------------------------------------------------------
def s_smaa():
    def areatex_builder(target, source, env):
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

    def searchtex_builder(target, source, env):
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

    areatex_builder(Targets("servers/rendering/renderer_rd/effects/smaa_area_tex.gen.h"), Files("thirdparty/smaa/AreaTex.png"), Env())
    searchtex_builder(Targets("servers/rendering/renderer_rd/effects/smaa_search_tex.gen.h"), Files("thirdparty/smaa/SearchTex.png"), Env())


def s_ltc():
    make_ltc_lut.run(
        Targets("servers/rendering/storage/ltc_lut.gen.h"),
        Files(
            "servers/rendering/storage/make_ltc_lut.py",
            "servers/rendering/storage/ltc/ltc_lut1.dds",
            "servers/rendering/storage/ltc/ltc_lut2.dds",
        ),
        Env(),
    )


# ---------------------------------------------------------------------------
#  Shaders
# ---------------------------------------------------------------------------
def s_rd_shaders():
    base = R("servers", "rendering", "renderer_rd", "shaders")
    for dirpath, _dirs, files in os.walk(base):
        for fn in sorted(files):
            if not fn.endswith(".glsl"):
                continue
            full = os.path.join(dirpath, fn)
            if fn.endswith("_inc.glsl"):
                glsl_builders.build_raw_header(full + ".gen.h", full)
            else:
                glsl_builders.build_rd_header(full + ".gen.h", full)


def s_module_glsl():
    for name, files in (
        ("betsy", ["bc6h.glsl", "bc1.glsl", "bc4.glsl", "alpha_stitch.glsl", "rgb_to_rgba.glsl"]),
        ("lightmapper_rd", ["lm_raster.glsl", "lm_compute.glsl", "lm_blendseams.glsl"]),
    ):
        for fn in files:
            full = R("modules", name, fn)
            glsl_builders.build_raw_header(full + ".gen.h", full)


def s_gles3_shaders():
    base = R("drivers", "gles3", "shaders")
    for fn in (
        "canvas.glsl",
        "feed.glsl",
        "scene.glsl",
        "sky.glsl",
        "canvas_occlusion.glsl",
        "canvas_sdf.glsl",
        "particles.glsl",
        "particles_copy.glsl",
        "skeleton.glsl",
        "tex_blit.glsl",
    ):
        full = os.path.join(base, fn)
        gles3_builders.build_gles3_header(full + ".gen.h", full)
    for full in sorted(glob.glob(os.path.join(base, "effects", "*.glsl"))):
        if full.endswith("_inc.glsl"):
            continue
        gles3_builders.build_gles3_header(full + ".gen.h", full)


# ---------------------------------------------------------------------------
#  GDScript templates / ICU data
# ---------------------------------------------------------------------------
def s_gdscript_templates():
    tdir = R("modules", "gdscript", "editor", "script_templates")
    srcs = [File(p) for p in sorted(glob.glob(os.path.join(tdir, "*", "*")))]
    template_builders.make_templates(
        Targets("modules/gdscript/editor/script_templates/templates.gen.h"), srcs, Env()
    )


def s_icu():
    text_server_adv_builders.make_icu_data(
        Targets("thirdparty/icu4c/icudata.gen.h"), Files("thirdparty/icu4c/icudt_godot.dat"), Env()
    )


STEPS = [
    ("core/version", s_version),
    ("core/version_hash", s_version_hash),
    ("core/disabled_classes", s_disabled_classes),
    ("core/script_encryption_key", s_encryption_key),
    ("core/certs", s_certs),
    ("core/authors", s_authors),
    ("core/donors", s_donors),
    ("core/license", s_license),
    ("core/object/gdvirtual", s_gdvirtual),
    ("core/extension/ext_wrappers", s_ext_wrappers),
    ("core/extension/interface_dump", s_interface_dump),
    ("core/extension/interface_header", s_interface_header),
    ("core/profiling", s_profiling),
    ("core/input/mappings", s_controller_mappings),
    ("main/splash", s_splash),
    ("main/splash_editor", s_splash_editor),
    ("main/app_icon", s_app_icon),
    ("modules/modules_enabled", s_modules_enabled),
    ("modules/register_module_types", s_register_module_types),
    ("platform/register_platform_apis", s_platform_apis),
    ("platform/export_icons", s_export_icons),
    ("editor/doc_class_path", s_doc_class_path),
    ("editor/doc_data", s_doc_data),
    ("editor/register_exporters", s_register_exporters),
    ("editor/translations", s_translations),
    ("editor/icons", s_editor_icons),
    ("editor/fonts", s_editor_fonts),
    ("scene/theme_icons", s_theme_icons),
    ("scene/theme_font", s_theme_font),
    ("servers/smaa", s_smaa),
    ("servers/ltc", s_ltc),
    ("servers/rd_shaders", s_rd_shaders),
    ("modules/glsl", s_module_glsl),
    ("drivers/gles3_shaders", s_gles3_shaders),
    ("modules/gdscript_templates", s_gdscript_templates),
    ("text_server_adv/icu_data", s_icu),
]


def main():
    for label, fn in STEPS:
        step(label, fn)
    if FAILED:
        print("[gen] ERROR: " + str(len(FAILED)) + " codegen step(s) failed: " + ", ".join(FAILED))
        print("[gen] Aborting; required generated files are missing.")
        sys.exit(1)
    print("[gen] all " + str(len(STEPS)) + " codegen steps completed.")


main()
