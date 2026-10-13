"""scons_shim.py - Minimal SCons emulation for the CMake debug build.

This module lets the engine's own `SCsub` files run to *discover* every
compiled translation unit together with the exact per-TU compile flags,
without ever invoking the real SCons build system.

It implements just enough of the SCons API surface that the linuxbsd debug
build's SCsub tree touches:

  * a fake `SCons.*` package (Script, Builder, Action, Variables, ...)
  * an `Env` object (Append/Prepend/Clone/... list semantics)
  * `Glob`/`File`/`Dir`/`Value` node types
  * `Import`/`Export`/`SConscript`/`Return` execution model
  * a capture hook in `add_source_files` that snapshots the flag environment
    for every translation unit at the moment SCons would schedule its compile.

Nothing is actually executed at build time by this module; the produced
`flags_debug.json`/`sources_debug.txt` are consumed by `cmake/debug.cmake`.
"""

import copy
import glob as _py_glob
import os
import posixpath
import re
import sys
import types

SRC_EXT = (".c", ".cc", ".cpp", ".S")


# ---------------------------------------------------------------------------
# Fake SCons package
# ---------------------------------------------------------------------------
class _ModuleStub(types.ModuleType):
    """Module whose attribute lookups return no-op callables."""

    def __getattr__(self, name):
        def _noop(*a, **k):
            return None

        return _noop


def _install_fake_scons():
    """Register a fake `SCons` package so engine modules import cleanly."""
    if "SCons.Script" in sys.modules:
        return
    top = types.ModuleType("SCons")

    modules = {}
    names_to_create = [
        "SCons",
        "SCons.Script",
        "SCons.Script.SConscript",
        "SCons.Script.Main",
        "SCons.Build",
        "SCons.Builder",
        "SCons.Action",
        "SCons.Defaults",
        "SCons.Subst",
        "SCons.Variables",
        "SCons.Errors",
        "SCons.Environment",
        "SCons.Util",
        "SCons.Node",
        "SCons.Node.FS",
        "SCons.Platform",
        "SCons.Platform.virtualenv",
        "SCons.Scanner",
        "SCons.Tool",
        "SCons.Tool.compilation_db",
        "SCons.Executor",
        "SCons.SConf",
        "SCons.Configure",
        "SCons.StrictMethodWrapper",
        "SCons.Warnings",
    ]
    for name in names_to_create:
        mod = _ModuleStub(name)
        modules[name] = mod
        sys.modules[name] = mod
    top.__path__ = []
    sys.modules.setdefault("SCons", top)

    # Concrete symbols that the engine tree imports / uses at runtime.
    script = modules["SCons.Script"]
    script.ARGUMENTS = {}
    script.ARGLIST = []
    script.BUILD_TARGETS = ["bin/godot"]
    script.GetOption = lambda name, default=False: False
    script.SetOption = lambda name, value: None
    script.AddOption = lambda *a, **k: None
    script.Help = lambda *a, **k: None

    variables = modules["SCons.Variables"]

    def _boolvar(*a, **k):
        return ("bool", a[0] if a else None)

    def _enumvar(*a, **k):
        return ("enum", a[0] if a else None)

    def _listvar(*a, **k):
        return ("list", a[0] if a else None)

    def _packagevar(*a, **k):
        return ("package", a[0] if a else None)

    def _pathvar(*a, **k):
        return ("path", a[0] if a else None)

    class _Variables(_ModuleStub):
        def __init__(self, *a, **k):
            super().__init__("SCons.Variables.Variables")
            self._opts = []

        def Add(self, *a, **k):
            return None

        def AddVariables(self, *a, **k):
            return None

        def Update(self, env, args=None):
            return None

        def GenerateHelpText(self, env=None, sort=None):
            return ""

    variables.BoolVariable = _boolvar
    variables.EnumVariable = _enumvar
    variables.ListVariable = _listvar
    variables.PackageVariable = _packagevar
    variables.PathVariable = _pathvar
    variables.Variables = _Variables
    variables.PackageVariable = variables.PackageVariable  # noqa: F841

    builder = modules["SCons.Builder"]

    class _Builder:
        def __init__(self, *a, **k):
            self.action = k.pop("action", None) or (a[0] if a else None)
            self.kwargs = k

    builder.Builder = _Builder
    modules["SCons.Script"].Builder = _Builder

    action = modules["SCons.Action"]

    def _action(*a, **k):
        return _ActionLegacy(a[0] if a else None, k.get("cmdstr"))

    class _ActionLegacy:
        def __init__(self, fn, cmdstr=None):
            self.fn = fn
            self.cmdstr = cmdstr

    action.Action = _action
    sys.modules.setdefault("SCons.DDefaults", _ModuleStub("SCons.DDefaults"))

    util = modules["SCons.Util"]
    util.AddMethod = lambda *a, **k: None
    util.WhereIs = lambda prog, *a, **k: None
    util.Unique = lambda xs: xs
    util.flatten = lambda s: s

    defaults = modules["SCons.Defaults"]
    defaults.CCopy = lambda *a, **k: None
    defaults.CScan = lambda *a, **k: None


def install_fake_scons():
    """Public entry point: idempotently register the fake `SCons` package."""
    _install_fake_scons()


# ---------------------------------------------------------------------------
# SConscript execution context
# ---------------------------------------------------------------------------
class _Return(Exception):
    """Raised by the `Return` helper to bubble a value out of a SCsub."""

    def __init__(self, value):
        super().__init__("return")
        self.value = value


class Context:
    """Shared state for one full SCsub traversal."""

    def __init__(self, root):
        self.root = root  # absolute repo root
        self.cwd = root  # directory of the SCsub currently executing
        self.exports = {}  # name -> value (SCons Export/Import table)
        self.captures = {}  # (src, obj_suffix) -> capture dict (ordered)
        self.capture_order = 0
        self.obj_counts = {}  # src -> number of captured compilations
        self.gen = {}  # rel(target) -> {'sources': [...], 'kind': 'CommandNoCache'}
        self.glob_stack = []  # exec() globals of the currently running SCsub
        self.checked = 0

    def resolve(self, p):
        """Resolve a path to a repo-relative posix path.

        Understands the ``#`` root marker, absolute paths and paths relative
        to the currently executing SCsub.
        """
        if isinstance(p, Node):
            return p.rel
        s = str(p)
        if s.startswith("#"):
            rel = os.path.relpath(os.path.normpath(os.path.join(self.root, s[1:])), self.root)
            return posixpath.normpath(rel.replace(os.sep, "/"))
        if s.startswith("/"):
            rel = os.path.relpath(os.path.abspath(s), self.root)
        else:
            rel = os.path.relpath(os.path.join(self.cwd, s), self.root)
        return posixpath.normpath(rel.replace(os.sep, "/"))


class Node:
    """Stand-in for a SCons source/target node."""

    def __init__(self, ctx, rel, is_dir=False):
        self.ctx = ctx
        self.rel = rel
        self.is_dir = is_dir
        self.is_object = False
        self.obj = None

    @property
    def abspath(self):
        return os.path.join(self.ctx.root, *self.rel.split("/"))

    @property
    def name(self):
        return self.rel.rsplit("/", 1)[-1]

    @property
    def srcnode(self):
        return self

    @property
    def rstr(self):
        return self.rel

    @property
    def tpath(self):
        return self.rel

    def get_abspath(self):
        return self.abspath

    def get_path(self):
        return self.rel

    def get_suffix(self):
        _, ext = os.path.splitext(self.rel)
        return ext

    def read(self):
        with open(self.abspath, "r", encoding="utf-8", newline="\n") as f:
            return f.read()

    def get_text_contents(self):
        return self.read()

    def get_contents(self):
        with open(self.abspath, "rb") as f:
            return f.read()

    def __str__(self):
        return self.rel

    def __fspath__(self):
        return self.abspath

    def __eq__(self, other):
        return isinstance(other, Node) and self.rel == other.rel

    def __lt__(self, other):
        return self.rel < other.rel

    def __hash__(self):
        return hash(("node", self.rel))


class ValueNode(Node):
    """Env.Value() node: the builders only call .read()."""

    def __init__(self, ctx, value):
        super().__init__(ctx, "value")
        self.value = value

    def read(self):
        return self.value

    def get_string_value(self):
        return str(self.value)

    def __str__(self):
        return str(self.value)


class DirNode(Node):
    @property
    def path(self):
        return self.rel


# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
def _flatten_args(kind, env):
    """Return the argv for a translation unit of `kind` (c/cxx/S)."""
    ccflags = list(env.get("CCFLAGS", []))
    ccflags = [_expand_var(x, env) for x in ccflags]
    out = []
    if kind == "c":
        out += [_expand_var(x, env) for x in env.get("CFLAGS", [])]
        out += ccflags
    elif kind == "cxx":
        out += [_expand_var(x, env) for x in env.get("CXXFLAGS", [])]
        out += ccflags
    # .S files are preprocessed+assembled: defines and includes only.
    out += [_define_flag(x) for x in env.get("CPPDEFINES", [])]
    out += [_include_flag(p) for p in env.get("CPPPATH", [])]
    return out


def _expand_var(flag, env):
    flag = flag.replace("$WARNLEVEL", str(env.get("WARNLEVEL", "")))
    flag = flag.replace("$OPTIMIZELEVEL", str(env.get("OPTIMIZELEVEL", "")))
    cur = env.get("WARNLEVEL", "")
    if flag == "$WARNLEVEL":
        return cur
    cur = env.get("OPTIMIZELEVEL", "")
    if flag == "$OPTIMIZELEVEL":
        return cur
    return flag


def _define_flag(entry):
    if isinstance(entry, (tuple, list)):
        return "-D{0}={1}".format(entry[0], entry[1])
    return "-D{0}".format(entry)


def _include_flag(entry, ctx=None):
    if isinstance(entry, Node):
        s = entry.rel
    else:
        s = str(entry)
    if s.startswith("#"):
        s = s[1:]
    if s.startswith("/"):
        return "-I{0}".format(s.rstrip("/") or "/")
    s = re.sub(r"/{2,}", "/", s).rstrip("/")
    return "-I." if s in ("", ".") else "-I{0}".format(s)


def _as_list(v):
    """SCons treats a bare string as a single list element, not a char seq."""
    if isinstance(v, (str, bytes, os.PathLike)):
        return [v]
    return list(v)


def _clone_value(v):
    """Structural copy of SCons list/dict values, sharing leaf objects.

    Deliberately avoids ``copy.deepcopy`` so that Node/Env/Builder/function
    leaves are shared instead of recursively cloned (which is the correct
    SCons behaviour and avoids infinite recursion through the context).
    """
    if isinstance(v, list):
        return [_clone_value(x) for x in v]
    if isinstance(v, dict):
        return {k: _clone_value(x) for k, x in v.items()}
    if isinstance(v, tuple):
        return tuple(_clone_value(x) for x in v)
    if isinstance(v, set):
        return set(v)
    return v


class Env:
    """SCons Environment surrogate with list-append semantics."""

    _UNDEF = object()

    def __init__(self, ctx=None, data=None):
        object.__setattr__(self, "_ctx", ctx)
        object.__setattr__(self, "_data", dict(data) if data else {})

    # -- dict / attribute access ----------------------------------------
    def __getattr__(self, name):
        d = object.__getattribute__(self, "_data")
        if name in d:
            return d[name]
        raws = d.get("BUILDERS", {})
        if name in raws:
            return _builder_callable(self, name)
        raise AttributeError(name)

    def __setattr__(self, name, value):
        if name.startswith("_"):
            object.__setattr__(self, name, value)
        else:
            self._data[name] = value

    def __getitem__(self, key):
        d = self._data
        if key in d:
            return d[key]
        return ""

    def __setitem__(self, key, value):
        self._data[key] = value

    def __contains__(self, key):
        return key in self._data

    def get(self, key, default=_UNDEF):
        if default is Env._UNDEF:
            return self._data.get(key)
        return self._data.get(key, default)

    def Dictionary(self):
        return self._data

    def dict(self):
        return self._data

    def __copy__(self):
        return self.Clone()

    def __deepcopy__(self, memo):
        return self.Clone()

    # -- builders --------------------------------------------------------
    def Clone(self, **kw):
        data = {}
        for k, v in self._data.items():
            data[k] = _clone_value(v)
        data.update(kw)
        return Env(self._ctx, data)

    def _norm_values(self, key, vals):
        """Resolve relative CPPPATH entries the way SCons does (against the
        directory of the SCsub that performs the Append/Prepend)."""
        if key != "CPPPATH":
            return vals
        if isinstance(vals, (str, bytes, os.PathLike)) or isinstance(vals, Node):
            return vals
        out = []
        for v in vals:
            if isinstance(v, Node):
                out.append(v)
                continue
            s = str(v)
            if s.startswith("#") or s.startswith("/"):
                out.append(s)
                continue
            out.append("#" + self._ctx.resolve(s))
        return out

    def Append(self, **kwargs):
        for key, vals in kwargs.items():
            vals = self._norm_values(key, vals)
            if key not in self._data:
                self._data[key] = _clone_value(vals)
                continue
            cur = self._data[key]
            if isinstance(cur, list):
                cur.extend(_as_list(vals))
            elif isinstance(cur, dict) and isinstance(vals, dict):
                cur.update(vals)
            elif isinstance(cur, str) and isinstance(vals, str):
                self._data[key] = cur + vals
            else:
                self._data[key] = vals

    def AppendUnique(self, **kwargs):
        for key, vals in kwargs.items():
            vals = self._norm_values(key, vals)
            if key not in self._data:
                self._data[key] = _clone_value(vals)
                continue
            cur = self._data[key]
            if isinstance(cur, list):
                for v in _as_list(vals):
                    if v not in cur:
                        cur.append(v)
            else:
                self.Append(**{key: vals})

    def Prepend(self, **kwargs):
        for key, vals in kwargs.items():
            vals = self._norm_values(key, vals)
            if key not in self._data:
                self._data[key] = _clone_value(vals)
                continue
            cur = self._data[key]
            if isinstance(cur, list):
                self._data[key] = list(_as_list(vals)) + cur
            elif isinstance(cur, dict) and isinstance(vals, dict):
                cur.update(vals)
            elif isinstance(cur, str) and isinstance(vals, str):
                self._data[key] = vals + cur
            else:
                self._data[key] = vals

    def PrependUnique(self, **kwargs):
        for key, vals in kwargs.items():
            vals = self._norm_values(key, vals)
            if key not in self._data:
                self._data[key] = _clone_value(vals)
                continue
            cur = self._data[key]
            if isinstance(cur, list):
                merged = list(cur)
                for v in _as_list(vals):
                    if v not in merged:
                        merged.insert(0, v)
                self._data[key] = merged
            else:
                self.Prepend(**{key: vals})

    def Replace(self, **kwargs):
        for key, vals in kwargs.items():
            self._data[key] = vals

    def SetDefault(self, **kwargs):
        for key, vals in kwargs.items():
            if key not in self._data:
                self._data[key] = vals

    def disable_warnings(self):
        self._data["WARNLEVEL"] = "-w"

    def force_optimization_on_debug(self):
        self._data["OPTIMIZELEVEL"] = "-O3"

    # -- node construction -----------------------------------------------
    def File(self, *paths):
        ctx = self._ctx
        rels = [ctx.resolve(p) for p in paths]
        return Node(ctx, rels[0]) if len(rels) == 1 else [Node(ctx, r) for r in rels]

    def Dir(self, *paths):
        ctx = self._ctx
        rels = [ctx.resolve(p) for p in paths]
        if len(rels) == 1:
            return DirNode(ctx, rels[0])
        return [DirNode(ctx, r) for r in rels]

    def Value(self, value):
        return ValueNode(self._ctx, value)

    def Glob(self, pattern):
        ctx = self._ctx
        pat = str(pattern)
        if pat.startswith("#"):
            base = os.path.join(ctx.root, pat[1:])
        elif os.path.isabs(pat):
            base = pat
        else:
            base = os.path.join(ctx.cwd, pat)
        matches = [m.replace(os.sep, "/") for m in _py_glob.glob(base)]
        matches.sort()
        nodes = []
        for m in matches:
            absm = os.path.join(ctx.root, m) if not os.path.isabs(m) else m
            rel = os.path.relpath(absm, ctx.root).replace(os.sep, "/")
            if os.path.isdir(absm):
                continue
            nodes.append(Node(ctx, rel))
        return nodes

    # -- build scheduling --------------------------------------------------
    def Run(self, function, comstr="$GENCOMSTR"):
        return function

    def Object(self, *args):
        srcs = [x for x in args if isinstance(x, (str, bytes, os.PathLike)) or isinstance(x, Node)]
        if not srcs:
            return Node(self._ctx, "object")
        nodes = []
        for s in srcs:
            rel = self._ctx.resolve(s)
            ext = os.path.splitext(rel)[1]
            if ext in SRC_EXT:
                self._capture_add(rel)
            nodes.append(Node(self._ctx, rel))
        return nodes[0] if len(nodes) == 1 else nodes

    def CommandNoCache(self, target, source, action, **kw):
        ctx = self._ctx
        if isinstance(target, (list, tuple)):
            targets = [self.File(t) if not isinstance(t, Node) else t for t in target]
        else:
            targets = [self.File(target) if not isinstance(target, Node) else target]
        for t in targets:
            srcs = []
            if isinstance(source, (list, tuple)):
                for s in source:
                    if isinstance(s, Node):
                        srcs.append(s.rel)
                    else:
                        srcs.append(self.File(s).rel)
            elif isinstance(source, Node):
                srcs.append(source.rel)
            else:
                srcs.append(self.File(source).rel)
            ctx.gen[t.rel] = {"sources": srcs, "kind": "CommandNoCache"}
        return targets[0] if len(targets) == 1 else targets

    def Command(self, target, source, action, **kw):
        return self.CommandNoCache(target, source, action, **kw)

    def Depends(self, target, dependency, **kw):
        return target

    def NoCache(self, target, *args, **kw):
        return target

    def AlwaysBuild(self, target, *args, **kw):
        return target

    def Precious(self, target, *args, **kw):
        return target

    def AddPostAction(self, target, action):
        return target

    def Module(self, *a, **k):
        return None

    def Builder(self, **kw):
        return _Builder(**kw)

    def Detect(self, name):
        import shutil

        return shutil.which(name)

    def WhereIs(self, name, *a, **k):
        import shutil

        found = shutil.which(str(name))
        return found

    def GetOption(self, name, default=False):
        return default

    def SetOption(self, name, value):
        return None

    def ParseConfig(self, command, *a, **k):
        return ""

    def Flatten(self, s, *a, **k):
        if isinstance(s, (list, tuple)):
            out = []
            for i in s:
                out.extend(self.Flatten(i))
            return out
        return [s]

    def PrependENVPath(self, key, value, **k):
        return None

    def AppendENVPath(self, key, value, **k):
        return None

    def AddMethod(self, fn, name=None):
        method_name = name or getattr(fn, "__name__", "method")
        self._data[method_name] = lambda *a, **k: fn(self, *a, **k)
        return None

    # -- libraries / programs ----------------------------------------------
    def add_source_files(self, sources, files, allow_gen=False):
        if isinstance(files, str):
            skip_gen_cpp = "*" in files
            nodes = self.Glob(files)
            if not nodes and not skip_gen_cpp:
                rel = self._ctx.resolve(files)
                if self._source_available(rel):
                    self._emit(sources, rel)
                return
            for n in nodes:
                if skip_gen_cpp and not allow_gen and str(n).endswith(".gen.cpp"):
                    continue
                self._emit(sources, n.rel)
        elif isinstance(files, Node):
            if getattr(files, "is_object", False):
                if isinstance(sources, list) and files not in sources:
                    sources.append(files)
                return
            self._emit(sources, files.rel)
        elif isinstance(files, bytes) or isinstance(files, os.PathLike):
            rel = self._ctx.resolve(os.fspath(files))
            if self._source_available(rel):
                self._emit(sources, rel)
        elif hasattr(files, "__iter__"):
            for f in files:
                self.add_source_files(sources, f, allow_gen=allow_gen)
        else:
            rel = self._ctx.resolve(files)
            if self._source_available(rel):
                self._emit(sources, rel)

    def _emit(self, sources, rel):
        node = self._obj_node(rel)
        if node is not None and isinstance(sources, list) and node not in sources:
            sources.append(node)

    def _source_available(self, rel):
        """True if `rel` is an existing file or a known generated target."""
        if rel in self._ctx.gen:
            return True
        return os.path.isfile(os.path.join(self._ctx.root, *rel.split("/")))

    def _capture_add(self, rel):
        ctx = self._ctx
        ext = os.path.splitext(rel)[1]
        if ext not in SRC_EXT:
            return None
        obj_suffix = str(self.get("OBJSUFFIX", "") or "")
        key = (rel, obj_suffix)
        if key in ctx.captures:
            return ctx.captures[key]
        if ext in (".c",):
            lang = "c"
        elif ext in (".cc", ".cpp"):
            lang = "cxx"
        else:
            lang = "S"
        n = ctx.obj_counts.get(rel, 0)
        ctx.obj_counts[rel] = n + 1
        obj = rel + ("" if n == 0 else "_{0}".format(n)) + ".o"
        cap = {
            "src": rel,
            "lang": lang,
            "env": self,
            "order": ctx.capture_order,
            "obj": obj,
        }
        ctx.captures[key] = cap
        ctx.capture_order += 1
        return cap

    def _obj_node(self, rel):
        cap = self._capture_add(rel)
        if cap is None:
            return None
        node = Node(self._ctx, rel)
        node.is_object = True
        node.obj = cap["obj"]
        return node

    def add_library(self, name, sources, **kw):
        return self._collect_lib(name, sources)

    def add_shared_library(self, name, sources, **kw):
        return self._collect_lib(name, sources)

    def add_program(self, name, sources, **kw):
        self._data.setdefault("program_sources", [])
        if isinstance(sources, (list, tuple)):
            for s in sources:
                self.add_source_files(self._data["program_sources"], s)
        else:
            self.add_source_files(self._data["program_sources"], sources)
        return [Node(self._ctx, self._ctx.resolve(name))]

    def _collect_lib(self, name, sources):
        self._data.setdefault("lib_sources", [])
        if isinstance(sources, (list, tuple)):
            for s in sources:
                self.add_source_files(self._data["lib_sources"], s)
        else:
            self.add_source_files(self._data["lib_sources"], sources)
        return [Node(self._ctx, self._ctx.resolve(name))]

    # -- module bookkeeping (mirrors methods.py hooks) ----------------------
    def module_add_dependencies(self, module, dependencies, optional=False):
        deps = self._data.setdefault("module_dependencies", {})
        if module not in deps:
            deps[module] = [[], []]
        if optional:
            deps[module][1].extend(dependencies)
        else:
            deps[module][0].extend(dependencies)

    def module_check_dependencies(self, module):
        from methods import module_check_dependencies as _check

        return _check(self, module)


def _builder_callable(env, name):
    def _build(target=None, *a, **k):
        ctx = env._ctx
        if target is None:
            return None
        if isinstance(target, (list, tuple)):
            ts = [t if isinstance(t, Node) else env.File(t) for t in target]
        else:
            ts = [target if isinstance(target, Node) else env.File(target)]
        for t in ts:
            ctx.gen[t.rel] = ctx.gen.get(t.rel, {"sources": [], "kind": name})
        return ts[0] if len(ts) == 1 else ts

    return _build


# ---------------------------------------------------------------------------
# SConscript runner
# ---------------------------------------------------------------------------
def build_sources(root, subs):
    """Run the SCsub chain with a fresh base environment."""
    ctx = Context(root)
    env = make_base_env(ctx)
    return run_chain(ctx, env, subs)


def run_chain(ctx, env, subs):
    """Run the SCsub chain using an already prepared ctx/env. Returns (ctx, env)."""
    _install_fake_scons()
    runner = _Runner(ctx, env)
    runner.run_top(subs)
    return ctx, env


def make_base_env(ctx):
    """Create the base environment with the key flag lists empty (seeded by caller)."""
    env = Env(ctx)
    env["CC"] = "gcc"
    env["CXX"] = "g++"
    env["AS"] = "gcc"
    env["ENV"] = {"PATH": os.getenv("PATH", "")}
    env["CPPDEFINES"] = []
    env["CPPPATH"] = []
    env["CFLAGS"] = []
    env["CXXFLAGS"] = []
    env["CCFLAGS"] = []
    env["ASFLAGS"] = []
    env["LIBS"] = []
    env["LINKFLAGS"] = []
    env["WARNLEVEL"] = "-Wall"
    env["OPTIMIZELEVEL"] = "-O0"
    env["BUILDERS"] = {}
    env["module_dependencies"] = {}
    env["module_list"] = __import__("collections").OrderedDict()
    env.disabled_modules = set()
    env.module_version_string = ""
    env.msvc = False
    env.extra_suffix = ""
    env.editor_build = False
    env.dev_build = False
    env.debug_features = True
    env.disabled_classes = []
    env.module_icons_paths = []
    env.doc_class_path = {}
    env.platform_exporters = []
    env.platform_apis = []
    return env


class _Runner:
    def __init__(self, ctx, env):
        self.ctx = ctx
        self.env = env
        self.stack = []
        self.builtins = __builtins__ if isinstance(__builtins__, dict) else __builtins__.__dict__

    # -- top level --------------------------------------------------------
    def run_top(self, subs):
        self.ctx.exports["env"] = self.env
        for rel in subs:
            self.run(rel)

    # -- file execution ------------------------------------------------------
    def run(self, relpath):
        ctx = self.ctx
        full = os.path.join(ctx.root, *relpath.split("/"))
        dirname = os.path.dirname(full)
        prev_cwd = ctx.cwd
        ctx.cwd = dirname
        os.chdir(dirname)
        inserted = dirname not in sys.path
        if inserted:
            sys.path.insert(0, dirname)
        try:
            globs = {
                "Import": self._import,
                "Export": self._export,
                "SConscript": self.sconscript,
                "Return": self._return,
                "Glob": self._glob,
                "File": self._file,
                "Dir": self._dir,
                "Value": self._value,
                "Split": lambda s: s.split(),
                "Builder": self._builder,
                "Environment": lambda *a, **k: self.env,
                "Alias": lambda *a, **k: None,
                "Default": lambda *a, **k: None,
                "Exit": self._exit,
                "AddOption": lambda *a, **k: None,
                "Help": lambda *a, **k: None,
                "ARGUMENTS": {},
                "__name__": relpath,
            }
            ctx.glob_stack.append(globs)
            try:
                with open(full, "r", encoding="utf-8") as f:
                    code = f.read()
                exec(compile(code, full, "exec"), globs)
            except _Return as ret:
                globs["__return__"] = ret.value
            finally:
                ctx.glob_stack.pop()
            return globs.get("__return__")
        finally:
            if inserted and dirname in sys.path:
                sys.path.remove(dirname)
            os.chdir(prev_cwd)
            ctx.cwd = prev_cwd

    # -- SConscript API ------------------------------------------------------
    def sconscript(self, path):
        ctx = self.ctx
        p = str(path)
        if p.startswith("#"):
            rel = posixpath.normpath(p[1:])
        elif os.path.isabs(p):
            rel = os.path.relpath(os.path.abspath(p), ctx.root).replace(os.sep, "/")
        else:
            rel = posixpath.normpath(os.path.join(os.path.relpath(ctx.cwd, ctx.root), p))
        return self.run(rel)

    def _import(self, names):
        ctx = self.ctx
        globs = ctx.glob_stack[-1]
        if isinstance(names, str):
            names = names.replace(",", " ").split()
        for name in names:
            key = name.strip()
            if key in ctx.exports:
                value = ctx.exports[key]
            elif key in globs:
                value = globs[key]
            elif key in dir(self.env):
                value = getattr(self.env, key)
            else:
                value = ctx.exports.get(key)
            globs[key] = value
        return None

    def _export(self, names):
        ctx = self.ctx
        globs = ctx.glob_stack[-1]
        if isinstance(names, str):
            names = names.replace(",", " ").split()
        for name in names:
            key = name.strip()
            if key in globs:
                value = globs[key]
            elif hasattr(self.env, key):
                value = getattr(self.env, key)
            else:
                value = None
            ctx.exports[key] = value
        return None

    def _return(self, *args):
        ctx = self.ctx
        globs = ctx.glob_stack[-1]
        if not args:
            raise _Return(None)
        values = []
        for a in args:
            a = str(a)
            key = a.strip()
            if key in globs:
                values.append(globs[key])
            else:
                values.append(a)
        if len(values) == 1:
            raise _Return(values[0])
        raise _Return(values)

    def _glob(self, pattern, *a, **k):
        return self.env.Glob(pattern)

    def _file(self, *a, **k):
        return self.env.File(*a)

    def _dir(self, *a, **k):
        return self.env.Dir(*a)

    def _value(self, v):
        return self.env.Value(v)

    def _builder(self, *a, **k):
        return _Builder(*a, **k)

    def _exit(self, code=0, *a, **k):
        sys.exit(code)


# ---------------------------------------------------------------------------
# Output helpers (used by gen_sources.py)
# ---------------------------------------------------------------------------
def include_deps(relpath):
    """Number of `#include` directives in a source (the dependency metric)."""
    try:
        with open(os.path.join(relpath), "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
    except OSError:
        return 0
    return len(re.findall(r"^\s*#\s*include\b", text, flags=re.M))


def sort_captures(ctx):
    """Order captures by include-dependency amount (stable, ascending).

    Flags are resolved lazily here, after the whole SCsub chain has run, so
    that in-place mutations of a shared environment (Append/Prepend performed
    by later SCsubs) are reflected exactly like real SCons does at build time.
    """
    items = list(ctx.captures.values())
    for c in items:
        args = _flatten_args(c["lang"], c["env"])
        c["args"] = [a.replace('\\"', '"') for a in args]
        c.pop("env", None)
    items.sort(key=lambda c: (include_deps(c["src"]), c["order"]))
    return items