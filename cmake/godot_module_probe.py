#!/usr/bin/env python3
"""Mini-SCons interpreter that records what each module's SCsub builds.

Instead of hand-porting ~54 modules (and their 32 thirdparty rule sets) into
CMake, this executes the real `modules/<name>/SCsub` files against a recording
stub environment and dumps the resulting source lists, include dirs, defines
and libraries as JSON. `cmake/modules.cmake` then turns that JSON into CMake
targets, so the module rules stay identical to what SCons would build.

Usage:  godot_module_probe.py <godot_root>            # -> all modules JSON
        godot_module_probe.py <godot_root> <module>    # -> single module JSON
"""

import glob as globmod
import json
import os
import sys
import types

GODOT_ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")

sys.path.insert(0, GODOT_ROOT)
sys.path.insert(0, os.path.join(GODOT_ROOT, "misc", "utility"))

PLATFORM = "linuxbsd"
ARCH = "x86_64"
TARGET = "editor"


# ---------------------------------------------------------------------------
# Recording stubs
# ---------------------------------------------------------------------------
class Recorder:
    """Captures sources/includes/defines/libs produced by an SCsub tree."""

    def __init__(self):
        self.sources = []          # engine module sources (compile into the module lib)
        self.thirdparty = []       # thirdparty sources (compile into the module lib)
        self.includes = []         # extra include dirs for the module
        self.defines = []          # extra defines for the module
        self.tp_includes = []      # include dirs needed only by thirdparty sources
        self.tp_defines = []       # defines needed only by thirdparty sources
        self.generated = []        # generated files the SCsub asks for
        self.commands = []         # generator rules (outputs + generator fn)

    def to_json(self):
        def _s(x):
            return sorted(set(x), key=lambda v: str(v))
        return {
            "sources": _s(self.sources),
            "thirdparty": _s(self.thirdparty),
            "includes": _s(self.includes),
            "defines": _s(self.defines),
            "tp_includes": _s(self.tp_includes),
            "tp_defines": _s(self.tp_defines),
            "generated": _s(self.generated),
            "commands": self.commands,
        }


class Node:
    """Stands in for an SCons Node / File."""

    def __init__(self, path):
        self.path = os.path.normpath(path)
        self.abspath = self.path
        self.name = os.path.basename(self.path)

    def __str__(self):
        return self.path

    def __fspath__(self):
        return self.path

    def __iter__(self):
        # SCons library nodes can be spliced into source lists; treat a single
        # library node as a one-element iterable of its path.
        return iter([self.path])

    def __add__(self, other):
        return [self.path] + list(other)

    def read(self):
        with open(self.path, "r", encoding="utf-8") as f:
            return f.read()


class Env:
    """Recording stand-in for a SCons Environment."""

    def __init__(self, rec, name="env", cwd="."):
        self._rec = rec
        self._name = name
        self._cwd = cwd
        self._is_thirdparty = name.endswith("thirdparty")
        self._cpppath = []
        self._cppdefines = []
        self._libs = []
        # SCons exposes a per-module mutable source list.
        self.modules_sources = []
        self.module_dependencies = {}

    # SCons helpers exposed as methods by Godot's methods.py.
    def module_add_dependencies(self, module, deps, optional=False):
        self.module_dependencies.setdefault(module, ([], []))
        if not optional:
            self.module_dependencies[module][0].extend(deps)

    def module_check_dependencies(self, module):
        return True

    # -- identity ----------------------------------------------------------
    @property
    def msvc(self):
        return False

    @property
    def dev_build(self):
        return False

    @property
    def editor_build(self):
        return TARGET == "editor"

    @property
    def debug_features(self):
        return True

    @property
    def module_list(self):
        return _MODULE_LIST._store

    # -- helpers -----------------------------------------------------------
    def _abspath(self, p):
        p = str(p)
        if p.startswith("#"):
            # SCons: '#' means the repository root.
            return os.path.normpath(os.path.join(GODOT_ROOT, p[1:].lstrip("/")))
        if os.path.isabs(p):
            return p
        cwd = _CUR["cwd_stack"][-1] if _CUR.get("cwd_stack") else self._cwd
        return os.path.normpath(os.path.join(cwd, p))

    def _is_tp(self):
        return self._is_thirdparty

    def Clone(self):
        e = Env(self._rec, self._name, self._cwd)
        e._cpppath = list(self._cpppath)
        e._cppdefines = list(self._cppdefines)
        e._libs = list(self._libs)
        e._is_thirdparty = self._is_thirdparty
        return e

    def disable_warnings(self):
        # In Godot's SCsub files this marks an environment as "thirdparty".
        self._is_thirdparty = True
        return self

    def force_optimization_on_debug(self):
        return self

    def use_windows_spawn_fix(self):
        return self

    # -- flags -------------------------------------------------------------
    def _normalize_defines(self, values):
        """Normalize a SCons CPPDEFINES value into a list of strings.

        SCons accepts "NAME" or ("NAME", value); the latter becomes NAME=value.
        """
        out = []
        if values is None:
            return out
        items = values if isinstance(values, (list, tuple)) else [values]
        for it in items:
            if isinstance(it, (list, tuple)) and len(it) == 2:
                out.append(f"{it[0]}={it[1]}")
            else:
                out.append(it)
        return out

    def _apply(self, kind, key, values, unique=False):
        if key == "CPPDEFINES":
            values = self._normalize_defines(values)
        else:
            values = _flatten(values)
        if key == "CPPPATH":
            cur = self._cpppath
        elif key == "CPPDEFINES":
            cur = self._cppdefines
        elif key == "LIBS":
            cur = self._libs
        else:
            return
        for v in values:
            if unique and v in cur:
                continue
            cur.append(v)
        if key == "CPPPATH":
            rec = self._rec.tp_includes if self._is_tp() else self._rec.includes
            for v in values:
                rec.append(self._abspath(v))
        elif key == "CPPDEFINES":
            rec = self._rec.tp_defines if self._is_tp() else self._rec.defines
            for v in values:
                rec.append(v)

    def Append(self, **kw):
        for k, v in kw.items():
            self._apply("Append", k, v)
        return self

    def AppendUnique(self, **kw):
        for k, v in kw.items():
            self._apply("Append", k, v, unique=True)
        return self

    def Prepend(self, **kw):
        for k, v in kw.items():
            if k == "CPPDEFINES":
                vals = self._normalize_defines(v)
            else:
                vals = _flatten(v)
            if k == "CPPPATH":
                self._cpppath = [self._abspath(x) for x in vals] + self._cpppath
                rec = self._rec.tp_includes if self._is_tp() else self._rec.includes
                for x in vals:
                    rec.append(self._abspath(x))
            elif k == "CPPDEFINES":
                self._cppdefines = list(vals) + self._cppdefines
                rec = self._rec.tp_defines if self._is_tp() else self._rec.defines
                for x in vals:
                    rec.append(x)
            elif k == "LIBS":
                self._libs = list(vals) + self._libs
        return self

    def ParseConfig(self, *a, **k):
        return None

    # -- sources -----------------------------------------------------------
    def add_source_files(self, sources, files, allow_gen=False):
        """SCons env.add_source_files: append matching files to `sources`.

        Globs resolve against the directory of the SCsub currently executing
        (SCons evaluates each SConscript in its own directory).
        """
        cwd = _CUR["cwd_stack"][-1] if _CUR.get("cwd_stack") else self._cwd
        if isinstance(files, str):
            if "*" in files or "?" in files:
                skip_gen = "*" in files
                pat = self._resolve_out(files, cwd)
                matches = sorted(globmod.glob(pat))
                if skip_gen and not allow_gen:
                    matches = [m for m in matches if not m.endswith(".gen.cpp")]
                files = matches
            else:
                # Literal file (possibly '#'-prefixed): add directly.
                files = [self._resolve_out(files, cwd)]
        for f in files:
            path = self._abspath(f)
            srcs = self._rec.thirdparty if self._is_tp() else self._rec.sources
            srcs.append(path)
        return True

    def add_library(self, name, sources, **kw):
        # SCons builds a static library from `sources`; record them so CMake can
        # compile the same set into the module target.
        srcs = self._rec.thirdparty if self._is_tp() else self._rec.sources
        for s in _flatten(sources):
            if isinstance(s, str) and s:
                srcs.append(self._abspath(s))
        return Node(self._abspath(name))

    def Object(self, target, source=None, **kw):
        if source is None:
            source, target = target, None
        return Node(self._abspath(source))

    def Depends(self, *a, **k):
        return None

    def _resolve_out(self, target, cwd):
        """Resolve a CommandNoCache target path ('#' = repo root, else SCsub dir)."""
        ts = str(target)
        if ts.startswith("#"):
            return os.path.normpath(os.path.join(GODOT_ROOT, ts[1:].lstrip("/")))
        if os.path.isabs(ts):
            return os.path.normpath(ts)
        return os.path.normpath(os.path.join(cwd, ts))

    def CommandNoCache(self, target, source, command, **kw):
        tgt = _flatten(target)
        # Targets are relative to the SCsub currently executing, not the module
        # root (e.g. editor/script_templates/SCsub -> editor/script_templates/x.gen.h)
        cwd = _CUR["cwd_stack"][-1] if _CUR.get("cwd_stack") else self._cwd
        for t in tgt:
            self._rec.generated.append(self._resolve_out(t, cwd))
        # Record the generator so CMake can wire the same rule. `command` is
        # the bound builder function returned by env.Run().
        fn = getattr(command, "__name__", None)
        if fn:
            mod = getattr(command, "__module__", "")
            self._rec.commands.append(
                {
                    "outputs": [self._resolve_out(t, cwd) for t in tgt],
                    "sources": [self._abspath(s) for s in _flatten(source)],
                    "func": fn,
                    "module": mod,
                }
            )
        return [Node(self._abspath(t)) for t in tgt]

    def Run(self, fn, comstr=""):
        return fn

    # -- builders (shader codegen) ----------------------------------------
    def _shader(self, src, kind):
        out = self._abspath(src) + ".gen.h"
        self._rec.generated.append(out)
        return Node(out)

    def GLSL_HEADER(self, src):
        return self._shader(src, "raw_glsl")

    def RD_GLSL(self, src):
        return self._shader(src, "rd_glsl")

    def GLES3_GLSL(self, src):
        return self._shader(src, "gles3_glsl")

    # -- misc --------------------------------------------------------------
    def File(self, path):
        return Node(self._abspath(path))

    def Dir(self, path):
        return self._abspath(path)

    def Glob(self, pattern, **kw):
        pat = pattern if os.path.isabs(str(pattern)) else os.path.join(self._cwd, str(pattern))
        return [Node(p) for p in sorted(globmod.glob(pat))]

    def Entry(self, path):
        return Node(self._abspath(path))

    def Value(self, v):
        return v

    def Exit(self, code=0):
        raise SystemExit(code)

    def Detect(self, prog):
        return None

    def AddMethod(self, *a, **k):
        return None

    def AddJSLibraries(self, *a, **k):
        return None

    def AddJSExterns(self, *a, **k):
        return None

    def __getitem__(self, key):
        if key in ("LIBS", "LIBPATH", "CPPPATH", "CPPDEFINES", "CCFLAGS", "CXXFLAGS", "LINKFLAGS"):
            return _ENV_VALUES.setdefault(key, [])
        return _ENV_VALUES.get(key)

    def __setitem__(self, key, value):
        _ENV_VALUES[key] = value

    def __contains__(self, key):
        return key in _ENV_VALUES


class _ModuleList:
    """env.module_list() -> dict of module name -> path."""

    def get(self):
        return _MODULE_LIST.get()


_MODULE_LIST = _ModuleList()

# Shared per-module execution context (env / env_modules) for nested SCsubs.
_CUR = {}

# Build options visible to the SCsub code, mirroring a linuxbsd editor build.
_ENV_VALUES = {
    "platform": PLATFORM,
    "arch": ARCH,
    "target": TARGET,
    "editor_build": True,
    "dev_build": False,
    "debug_features": True,
    "vulkan": True,
    "opengl3": True,
    "d3d12": False,
    "metal": False,
    "sdl": True,
    "use_sowrap": True,
    "use_llvm": False,
    "use_static_cpp": False,
    "minizip": True,
    "brotli": True,
    "x11": True,
    "wayland": False,
    "alsa": True,
    "pulseaudio": True,
    "dbus": True,
    "speechd": True,
    "fontconfig": True,
    "udev": True,
    "accesskit": False,
    "libdecor": True,
    "touch": True,
    "disable_3d": False,
    "disable_advanced_gui": False,
    "disable_physics_2d": False,
    "disable_physics_3d": False,
    "disable_navigation_2d": False,
    "disable_navigation_3d": False,
    "disable_xr": False,
    "profiler": "",
    "profiler_path": "",
    "scu_build": False,
    "tests": False,
    "disable_exceptions": True,
    "disable_overrides": False,
    "limit_transitive_includes": True,
    "graphite": True,
    "precision": "single",
    "library_type": "executable",
    "msvc": False,
    "BUILDERS": {"GLSL_HEADER": 1, "RD_GLSL": 1, "GLES3_GLSL": 1},
    "modules_sources": [],
}

# builtin_* defaults.
for _b in (
    "brotli certs clipper2 embree enet freetype msdfgen glslang graphite harfbuzz sdl "
    "icu4c libjpeg_turbo libogg libpng libtheora libvorbis libwebp wslay mbedtls "
    "miniupnpc openxr pcre2 pcre2_with_jit recastnavigation rvo2_2d rvo2_3d "
    "xatlas zlib zstd"
).split():
    _ENV_VALUES["builtin_" + _b] = True


def _flatten(v):
    out = []
    if isinstance(v, (list, tuple)):
        for x in v:
            out.extend(_flatten(x))
    elif isinstance(v, Node):
        out.append(str(v))
    elif v is not None:
        out.append(v)
    return out


# ---------------------------------------------------------------------------
# SCons module stubs + SCsub execution
# ---------------------------------------------------------------------------
_MODULE_LIST._store = {}


def _make_scons_hints(cwd):
    """Build the `misc.utility.scons_hints` module with a recording SConscript.

    `cwd` is the directory of the SCsub currently executing; SConscript paths are
    resolved relative to it (SCons semantics).
    """
    hints = types.ModuleType("misc.utility.scons_hints")

    def SConscript(path, **kw):
        # Resolve relative to the SCsub currently on top of the cwd stack.
        base = _CUR["cwd_stack"][-1] if _CUR.get("cwd_stack") else cwd
        p = path if os.path.isabs(str(path)) else os.path.join(base, str(path))
        if str(p).endswith("SCsub"):
            run_scsub(p)
        return []

    def GLOB(pattern, **kw):
        base = _CUR["cwd_stack"][-1] if _CUR.get("cwd_stack") else cwd
        pat = pattern if os.path.isabs(str(pattern)) else os.path.join(base, str(pattern))
        return [Node(p) for p in sorted(globmod.glob(pat))]

    hints.SConscript = SConscript
    hints.Import = lambda *a, **k: None
    hints.Export = lambda *a, **k: None
    hints.GLOB = GLOB
    hints.Command = lambda *a, **k: None
    hints.Default = lambda *a, **k: None
    hints.Value = lambda v: v
    hints.Dir = lambda p: Env._dummy.Dir(p)
    hints.Environment = lambda *a, **k: Env._dummy
    hints.Glob = GLOB

    sys.modules["misc.utility.scons_hints"] = hints
    # Also bind as an attribute so `from misc.utility.scons_hints import *`
    # resolves through the real (namespace) misc.utility package.
    try:
        import misc.utility as _mu

        _mu.scons_hints = hints
    except Exception:
        pass
    return hints


def run_scsub(path):
    """Execute an SCsub file with the shared module context in scope.

    The shared `_CUR` dict doubles as the globals mapping so names defined by a
    parent SCsub (e.g. `env_openxr`) are visible to nested SConscript() calls,
    mirroring SCons's Export/Import semantics.
    """
    path = os.path.abspath(path)
    cwd = os.path.dirname(path)
    # Some SCsubs import sibling helper modules (e.g. *_builders.py).
    if cwd not in sys.path:
        sys.path.insert(0, cwd)
    _make_scons_hints(cwd)
    with open(path, "r", encoding="utf-8") as f:
        src = f.read()
    _CUR.setdefault("cwd_stack", [])
    _CUR["cwd_stack"].append(cwd)
    _CUR["__name__"] = "__main__"
    _CUR["__file__"] = path
    _CUR["__builtins__"] = __builtins__
    # Make the scons_hints names available as bare globals for the exec.
    _hints = _make_scons_hints(cwd)
    for _nm in ("SConscript", "GLOB", "Glob", "Command", "Default", "Value", "Dir", "Environment", "Import", "Export"):
        _CUR[_nm] = getattr(_hints, _nm)
    try:
        exec(compile(src, path, "exec"), _CUR)
    except SystemExit:
        pass
    finally:
        _CUR["cwd_stack"].pop()


def probe_module(name):
    rec = Recorder()
    mod_dir = os.path.join(GODOT_ROOT, "modules", name)
    env = Env(rec, "env", mod_dir)
    env_modules = Env(rec, "env_modules", mod_dir)

    _CUR["env"] = env
    _CUR["env_modules"] = env_modules
    Env._dummy = env

    scsub_path = os.path.join(mod_dir, "SCsub")
    if not os.path.isfile(scsub_path):
        return rec.to_json()

    try:
        run_scsub(scsub_path)
    except Exception as e:  # noqa
        return {"error": f"{type(e).__name__}: {e}", **rec.to_json()}
    return rec.to_json()


def main():
    if len(sys.argv) > 2:
        names = [sys.argv[2]]
    else:
        names = sorted(
            d for d in os.listdir(os.path.join(GODOT_ROOT, "modules"))
            if os.path.isfile(os.path.join(GODOT_ROOT, "modules", d, "SCsub"))
        )

    # Populate module_list with all detected modules so deps resolve.
    _MODULE_LIST._store = {n: f"modules/{n}" for n in names}
    for n in names:
        _ENV_VALUES[f"module_{n}_enabled"] = True

    # Emit JSON Lines: one {"name": ..., ...} object per module, so consumers
    # (CMake) can parse each entry independently. `error` is always present
    # (empty when the module parsed cleanly).
    out = sys.stdout
    for n in names:
        try:
            res = probe_module(n)
        except Exception as e:  # noqa
            res = {"error": f"{type(e).__name__}: {e}"}
        err = res.pop("error", "")
        rec = {"name": n, "error": err}
        rec.update(res)
        out.write(json.dumps(rec) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())